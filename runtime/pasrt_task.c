/* Afterschool Pascal -- the concurrency runtime: a task and a channel.
 *
 * AP 6.4.16 and AP 6.9.3.12 (ADR-0268). This is the fourth translation unit of
 * the runtime and the second bounded by its **headers** rather than by a list
 * of names: `runtime/pasrt.c` is ISO C but for five catalogued functions,
 * `runtime/pasrt_unicode.c` is ISO C with none, `runtime/pasrt_posix.c` is
 * POSIX and holds only what a *program* may bind, and this is POSIX threads
 * and holds only what the *compiler emits*. One header beyond ISO C:
 *
 *     <pthread.h>
 *
 * A system without it loses the concurrency construct and not the language,
 * which is `pasrt_posix.c`'s own bargain (ADR-0186).
 *
 * **Why the runtime holds this at all.** A task's body cannot be handed to C:
 * §6.6.3.1's procedural parameter is a code-and-link pair (ADR-0030) and a
 * foreign routine takes one word, so `pthread_create` cannot be bound by a
 * library. What crosses here is a plain `void (*)(void *)` the **compiler
 * emits** -- a wrapper that unpacks an argument block and calls the task's
 * body -- so no Pascal procedure ever becomes a C function pointer. That is
 * ADR-0201's finding 4 turned into a shape.
 *
 * **Share-nothing.** Nothing below shares a Pascal variable between two
 * threads. A task is given a copy of every value parameter, ownership of every
 * handle it is handed by `take`, and a *lent* channel -- and a channel is the
 * one object two threads touch, which is why it is the one thing here with a
 * mutex in it. ADR-0201 chose that shape and the reason is that anything else
 * reintroduces the escaping alias this language has never had.
 */

#include <limits.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#include "pasrt.h"

void pas_runtime_error(const char *msg);

/* --- a channel -----------------------------------------------------------
 *
 * A bounded queue of fixed-size elements, with the two condition variables a
 * bounded queue needs. `esize` and `cap` come from the type, so every element
 * is the same size and the storage is one allocation.
 *
 * **Reference counted, and the count is not about lifetime.** The join at the
 * end of a block already guarantees no task outlives what it was lent
 * (AP 6.9.3.12) -- so nothing here would dangle without a count. What the
 * count buys is the other pattern: a program that **closes** a channel while
 * its tasks are still draining it, which is how a worker pool is told there is
 * no more work. Closing and freeing had to be two things for that, and once
 * they are, a count is what says when the second may happen.
 */
struct pas_chan {
  pthread_mutex_t m;
  pthread_cond_t notempty, notfull;
  long long esize, cap;
  long long head, tail, n;
  int refs;
  int closed;
  unsigned char *buf;
};

void *pas_chan_new(long long esize, long long cap) {
  struct pas_chan *c;
  if (esize <= 0 || cap <= 0)
    pas_runtime_error("a channel needs a positive capacity");
  /* Both factors come from the *type* and never from a value, so a program
     cannot reach this with input -- it takes a channel whose elements are
     gigabytes. It is checked anyway for the reason every arithmetic in this
     language is checked: it traps rather than wrapping (ADR-0014), and a
     wrapped product here would be a small allocation with a large index into
     it, which is the one shape a bounds check cannot catch. */
  if (esize > LLONG_MAX / cap)
    pas_runtime_error("a channel that large cannot be allocated");
  c = malloc(sizeof *c);
  if (!c)
    pas_runtime_error("out of memory making a channel");
  c->buf = malloc((size_t)(esize * cap));
  if (!c->buf)
    pas_runtime_error("out of memory making a channel");
  pthread_mutex_init(&c->m, NULL);
  pthread_cond_init(&c->notempty, NULL);
  pthread_cond_init(&c->notfull, NULL);
  c->esize = esize;
  c->cap = cap;
  c->head = 0;
  c->tail = 0;
  c->n = 0;
  c->refs = 1;
  c->closed = 0;
  return c;
}

/* A task is lent the owner's channel, so the count goes up where the task is
 * spawned and down where it ends. Both are the compiler's, at the two ends of
 * one construct. */
void pas_chan_ref(void *p) {
  struct pas_chan *c = p;
  if (!c)
    return;
  pthread_mutex_lock(&c->m);
  c->refs++;
  pthread_mutex_unlock(&c->m);
}

static void pas_chan_drop(struct pas_chan *c) {
  int last;
  pthread_mutex_lock(&c->m);
  c->refs--;
  last = c->refs == 0;
  pthread_mutex_unlock(&c->m);
  if (last) {
    pthread_mutex_destroy(&c->m);
    pthread_cond_destroy(&c->notempty);
    pthread_cond_destroy(&c->notfull);
    free(c->buf);
    free(c);
  }
}

/* The closer of a **shared** channel variable -- a task's parameter -- which
 * drops the reference and does not close. A worker that has finished must not
 * close the channel its colleagues are still draining, and which of the two
 * closers a variable was initialised with is the whole of what says whether it
 * owns the channel or shares it. Answers 0 because a closer answers an int
 * (AP 6.4.12.1) and there is nothing here for one to report. */
int pas_chan_unref(void *p) {
  if (p)
    pas_chan_drop(p);
  return 0;
}

/* The handle-type's closer (AP 6.4.12.1), so a channel is released by the
 * block that declared it and by `release` before that. It marks the channel
 * closed *and* drops the owner's reference: every reader waiting is woken and
 * told there will be no more, which is what makes a worker loop terminate. */
int pas_chan_close(void *p) {
  struct pas_chan *c = p;
  if (!c)
    return 0;
  pthread_mutex_lock(&c->m);
  c->closed = 1;
  pthread_cond_broadcast(&c->notempty);
  pthread_cond_broadcast(&c->notfull);
  pthread_mutex_unlock(&c->m);
  pas_chan_drop(c);
  return 0;
}

/* AP 6.9.3.13's send. Blocks while the channel is full.
 *
 * Sending to a closed channel **stops the program**, and that is this
 * language's own discipline rather than a choice made here: a subscript out of
 * range, a `case` with no matching label and an integer overflow all stop
 * (ADR-0014, ADR-0017, ADR-0018). A value with nowhere to go is the same kind
 * of fault -- the program has lost track of who is still listening -- and
 * answering a code would make every send a statement a caller had to check.
 */
void pas_chan_send(void *p, const void *v) {
  struct pas_chan *c = p;
  if (!c)
    pas_runtime_error("send on an empty channel variable");
  pthread_mutex_lock(&c->m);
  while (c->n == c->cap && !c->closed)
    pthread_cond_wait(&c->notfull, &c->m);
  if (c->closed) {
    pthread_mutex_unlock(&c->m);
    pas_runtime_error("send on a channel that has been closed");
  }
  memcpy(c->buf + c->tail * c->esize, v, (size_t)c->esize);
  c->tail = (c->tail + 1) % c->cap;
  c->n++;
  pthread_cond_signal(&c->notempty);
  pthread_mutex_unlock(&c->m);
}

/* AP 6.9.3.13's receive, which is a *function*: 1 with a value in `v`, 0 when
 * the channel is closed and drained.
 *
 * Draining before reporting the close is the decision. A reader that stopped
 * the moment the channel closed would lose whatever was still queued, and a
 * worker pool closes its job channel precisely when the jobs are all sent --
 * so the values still in flight are the ones that matter most.
 */
int pas_chan_receive(void *p, void *v) {
  struct pas_chan *c = p;
  if (!c)
    pas_runtime_error("receive on an empty channel variable");
  pthread_mutex_lock(&c->m);
  while (c->n == 0 && !c->closed)
    pthread_cond_wait(&c->notempty, &c->m);
  if (c->n == 0) {
    pthread_mutex_unlock(&c->m);
    return 0;
  }
  memcpy(v, c->buf + c->head * c->esize, (size_t)c->esize);
  c->head = (c->head + 1) % c->cap;
  c->n--;
  pthread_cond_signal(&c->notfull);
  pthread_mutex_unlock(&c->m);
  return 1;
}

/* --- a task set ----------------------------------------------------------
 *
 * One slot per *block* that spawns, not one per task, which is the defer
 * record's shape (ADR-0175) and is why a block spawning in a loop needs no
 * more storage than one spawning once.
 *
 * AP 6.9.3.12 joins every task of a block before the block's activation ends,
 * and the compiler emits that join **before** it releases the block's handles.
 * That ordering is the whole safety argument: a task's body is a nested
 * routine reached through a static link into this frame, and it is lent
 * whatever channels it was given, so it must not outlive either.
 */
struct pas_taskset {
  pthread_t *tids;
  int n, cap;
};

_Static_assert(sizeof(struct pas_taskset) <= PAS_TASKSET_SIZE,
               "PAS_TASKSET_SIZE is smaller than struct pas_taskset");

void pas_tasks_init(void *slot) {
  struct pas_taskset *s = slot;
  s->tids = NULL;
  s->n = 0;
  s->cap = 0;
}

/* What the thread actually starts in. The argument block is a copy the spawn
 * made, so the spawning statement may go out of scope, run again in a loop, or
 * be a different iteration's -- and the copy is freed here rather than by the
 * body, which has no way to name it. */
struct pas_taskarg {
  void (*fn)(void *);
  void *args;
};

static void *pas_task_start(void *p) {
  struct pas_taskarg *t = p;
  t->fn(t->args);
  free(t->args);
  free(t);
  return NULL;
}

/* Where a spawn's argument block comes from.
 *
 * The compiler could not use an `alloca` for it: a spawn inside a loop would
 * claim one per iteration, which is ADR-0102's rule -- an alloca is only safe
 * where the emitter reaches it once per activation. And a frame slot would
 * have to be sized to the largest argument block in the block, which is a
 * number the frame type is emitted too early to know. So the runtime hands out
 * the storage and the thread frees it, and the spawn site is three
 * instructions with no storage decision in it at all. */
void *pas_tasks_alloc(long long size) {
  void *p = malloc(size > 0 ? (size_t)size : 1);
  if (!p)
    pas_runtime_error("out of memory spawning a task");
  return p;
}

void pas_tasks_spawn(void *slot, void *fn, void *args) {
  struct pas_taskset *s = slot;
  struct pas_taskarg *t;
  if (s->n == s->cap) {
    int want;
    /* Doubling is the growth, and the double is what overflows. Unreachable
       with real threads -- it wants 2^30 of them live in one block -- but the
       wrap would be negative and `(size_t)want` then enormous. */
    if (s->cap > INT_MAX / 2)
      pas_runtime_error("too many tasks spawned by one block");
    want = s->cap ? s->cap * 2 : 8;
    pthread_t *grown = realloc(s->tids, (size_t)want * sizeof *grown);
    if (!grown)
      pas_runtime_error("out of memory spawning a task");
    s->tids = grown;
    s->cap = want;
  }
  t = malloc(sizeof *t);
  if (!t)
    pas_runtime_error("out of memory spawning a task");
  t->fn = (void (*)(void *))fn;
  t->args = args;
  if (pthread_create(&s->tids[s->n], NULL, pas_task_start, t) != 0)
    pas_runtime_error("a task could not be started");
  s->n++;
}

void pas_tasks_join(void *slot) {
  struct pas_taskset *s = slot;
  int i;
  for (i = 0; i < s->n; i++)
    pthread_join(s->tids[i], NULL);
  free(s->tids);
  s->tids = NULL;
  s->n = 0;
  s->cap = 0;
}
