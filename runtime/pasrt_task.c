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

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "pasrt.h"

void pas_runtime_error(const char *msg);

/* Defined with the select machinery below, and called by every operation
 * above it that changes a channel: a selector waits on one process-wide
 * condition variable and has to be told that *something* moved. */
static void pas_activity_signal(void);

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
  pas_activity_signal();
  pas_chan_drop(c);
  return 0;
}

/* AP 6.4.16.4 (ADR-0302): close the channel and leave the count alone.
 *
 * The two closers above answer the question *whose variable is going away*;
 * this answers a different one, *the program said close*. A release the
 * program wrote -- `release(c)`, or `c := nil` -- means the same thing
 * wherever it stands, so the compiler emits this before the release and the
 * closer that follows then does what it always did: the owner's drops its
 * reference, a task's drops its own.
 *
 * A task closing a channel it was lent cannot free it. The block that spawned
 * it holds a reference until it joins (AP 6.9.3.12.1), and the join is before
 * that block releases anything -- so the count cannot reach zero in a task
 * whose spawner still holds the variable, and where it does reach zero the
 * task is the last user and freeing is right. Nothing here has to know which.
 *
 * Idempotent, and null-safe because an empty handle-variable may be released.
 */
void pas_chan_shut(void *p) {
  struct pas_chan *c = p;
  if (!c)
    return;
  pthread_mutex_lock(&c->m);
  c->closed = 1;
  pthread_cond_broadcast(&c->notempty);
  pthread_cond_broadcast(&c->notfull);
  pthread_mutex_unlock(&c->m);
  pas_activity_signal();
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
  pas_activity_signal();
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
  pas_activity_signal();
  return 1;
}

/* --- selecting over several channels ------------------------------------
 *
 * AP 6.9.3.15 (ADR-0313). A select waits until one of several channels can
 * proceed, and there is no way to wait on several condition variables at
 * once -- so what a selector waits on is a **single process-wide condition
 * variable** that every channel operation signals after it has changed
 * something. A selector polls its own channels, and where none can proceed it
 * waits to be told that *some* channel changed and polls again.
 *
 * The cost is a spurious wakeup for every unrelated channel, which is the
 * honest trade: the alternative is a list of waiting selectors on every
 * channel, which is more state in the one object two threads already share
 * and buys nothing until a program has many channels and many selectors.
 *
 * **The lock order is the whole of the correctness argument**, and it is
 * stated as an invariant rather than as an ordering: *no thread ever holds a
 * channel's mutex and the activity mutex at the same time.* A sender changes
 * its channel, releases it, and only then takes the activity mutex to
 * broadcast; a selector holds the activity mutex and takes channel mutexes
 * one at a time beneath it. So the cycle that would deadlock -- one thread
 * holding a channel and wanting activity while another holds activity and
 * wants that channel -- has no first half.
 *
 * That the selector holds the activity mutex *across* its poll is what makes
 * the wakeup impossible to lose: a sender that changes a channel after the
 * selector has looked at it cannot broadcast until the selector is inside
 * `pthread_cond_wait` and has released the mutex.
 */
static pthread_mutex_t pas_activity = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pas_activity_c = PTHREAD_COND_INITIALIZER;

/* Every operation that could make some select's arm ready calls this, and it
 * is called with no channel mutex held. */
static void pas_activity_signal(void) {
  pthread_mutex_lock(&pas_activity);
  pthread_cond_broadcast(&pas_activity_c);
  pthread_mutex_unlock(&pas_activity);
}

struct pas_select_arm {
  int kind; /* 0 = receive, 1 = send */
  int got;  /* a receive that fired: 1 delivered a value, 0 reported the close */
  void *chan;
  void *val;
};

_Static_assert(sizeof(struct pas_select_arm) <= PAS_SELECT_ARM_SIZE,
               "PAS_SELECT_ARM_SIZE is smaller than struct pas_select_arm");

/* One arm, tried without waiting. 1 where it proceeded, 0 where it could not.
 *
 * A receive proceeds when a value is available *and* when the channel has been
 * closed and drained -- the second reporting the close through `got`, which is
 * what `receive`'s own boolean reports and is why a select over channels that
 * have all closed terminates rather than waiting for something that cannot
 * arrive. A send on a closed channel is AP 6.9.3.13.1's error wherever it is
 * written, so it is raised here rather than reported as unready.
 */
static int pas_select_try(struct pas_select_arm *a) {
  struct pas_chan *c = a->chan;
  int done = 0;
  if (!c)
    pas_runtime_error("a select arm names an empty channel variable");
  pthread_mutex_lock(&c->m);
  if (a->kind == 0) {
    if (c->n > 0) {
      memcpy(a->val, c->buf + c->head * c->esize, (size_t)c->esize);
      c->head = (c->head + 1) % c->cap;
      c->n--;
      pthread_cond_signal(&c->notfull);
      a->got = 1;
      done = 1;
    } else if (c->closed) {
      a->got = 0;
      done = 1;
    }
  } else {
    if (c->closed) {
      pthread_mutex_unlock(&c->m);
      pas_runtime_error("send on a channel that has been closed");
    }
    if (c->n < c->cap) {
      memcpy(c->buf + c->tail * c->esize, a->val, (size_t)c->esize);
      c->tail = (c->tail + 1) % c->cap;
      c->n++;
      pthread_cond_signal(&c->notempty);
      done = 1;
    }
  }
  pthread_mutex_unlock(&c->m);
  return done;
}

/* Where a select starts looking, and it is not always the first arm.
 *
 * Trying the arms in the order they are written would let a channel that is
 * always ready starve every arm below it -- a worker servicing a busy job
 * queue would never see its shutdown channel, which is exactly the program
 * this construct exists for. The start rotates, so over n executions every arm
 * is looked at first once. It is a *thread-local* counter, so two tasks
 * selecting do not perturb one another's order and a program's output stays
 * reproducible.
 */
_Thread_local static unsigned pas_select_turn;

/* AP 6.9.3.15. Returns the index of the arm that proceeded, or `n` where the
 * select gave up -- which is a timeout that expired, and is also the answer
 * for `otherwise` when nothing was ready, that being a deadline of zero.
 *
 * `wait_ms` is read only when `bounded` is non-zero; an unbounded select waits
 * for as long as it takes, which is the ordinary blocking receive's contract
 * one construct up.
 */
int pas_select(void *arms, int n, int bounded, long long wait_ms) {
  struct pas_select_arm *a = arms;
  struct timespec deadline;
  int i, k;
  if (n <= 0)
    pas_runtime_error("a select statement needs at least one channel arm");
  if (bounded && wait_ms < 0)
    pas_runtime_error("a select statement cannot wait for a negative time");
  if (bounded) {
    /* C11 7.27.2.5's `timespec_get` and not POSIX's `clock_gettime`: this
       unit's bargain is that one header beyond ISO C buys the whole
       construct (ADR-0186), and TIME_UTC is the same epoch
       `pthread_cond_timedwait` measures its absolute deadline against. */
    timespec_get(&deadline, TIME_UTC);
    deadline.tv_sec += (time_t)(wait_ms / 1000);
    deadline.tv_nsec += (long)(wait_ms % 1000) * 1000000L;
    if (deadline.tv_nsec >= 1000000000L) {
      deadline.tv_sec += 1;
      deadline.tv_nsec -= 1000000000L;
    }
  }
  pthread_mutex_lock(&pas_activity);
  for (;;) {
    unsigned turn = pas_select_turn++;
    for (k = 0; k < n; k++) {
      i = (int)((turn + (unsigned)k) % (unsigned)n);
      if (pas_select_try(&a[i])) {
        /* This select has itself changed a channel -- taken a value out or
           put one in -- so another selector may now proceed. The mutex is
           already held here, which is why this is a broadcast and not a call
           to `pas_activity_signal`, that one taking the mutex it is under. */
        pthread_cond_broadcast(&pas_activity_c);
        pthread_mutex_unlock(&pas_activity);
        return i;
      }
    }
    if (bounded) {
      /* A deadline already past is how `otherwise` and `after 0` are spelled:
         the poll above has happened once, which is the whole of what they
         ask for. */
      if (pthread_cond_timedwait(&pas_activity_c, &pas_activity, &deadline) ==
          ETIMEDOUT) {
        pthread_mutex_unlock(&pas_activity);
        return n;
      }
    } else
      pthread_cond_wait(&pas_activity_c, &pas_activity);
  }
}

/* --- a task -------------------------------------------------------------
 *
 * AP 6.4.17 (ADR-0312). One activation, and the record that says whether it
 * has been joined. It exists because a *name* for one activation does, and it
 * is reference counted for the channel's reason and not for a lifetime one:
 * the block that spawned the task always holds a reference until it joins
 * (AP 6.9.3.12.1), so nothing here can dangle. What the count buys is that a
 * task-variable may be released, overwritten in a loop, or moved into another
 * task, and the set the block joins goes on naming the same activation.
 *
 * **The join is claimed, not repeated.** `pthread_join` may be called once for
 * a thread and this record may be reached from two places -- `wait` on the
 * variable and the block's own join -- so the first to arrive takes `claimed`
 * and the others wait on `done`. That is what makes the second `wait(t)` a
 * statement with no effect rather than undefined behaviour, and it is the
 * whole of the concurrency in this type.
 */
struct pas_task {
  pthread_mutex_t m;
  pthread_cond_t donec;
  pthread_t tid;
  int refs;
  int claimed, done;
};

static void pas_task_drop_ref(struct pas_task *t) {
  int last;
  pthread_mutex_lock(&t->m);
  t->refs--;
  last = t->refs == 0;
  pthread_mutex_unlock(&t->m);
  if (last) {
    pthread_mutex_destroy(&t->m);
    pthread_cond_destroy(&t->donec);
    free(t);
  }
}

/* Wait for the activation to be complete. Claiming the join under the mutex
 * and releasing it *before* `pthread_join` is what keeps a second waiter from
 * holding the lock for the whole of the task's remaining run. */
static void pas_task_join(struct pas_task *t) {
  pthread_mutex_lock(&t->m);
  if (!t->claimed) {
    t->claimed = 1;
    pthread_mutex_unlock(&t->m);
    pthread_join(t->tid, NULL);
    pthread_mutex_lock(&t->m);
    t->done = 1;
    pthread_cond_broadcast(&t->donec);
  } else
    while (!t->done)
      pthread_cond_wait(&t->donec, &t->m);
  pthread_mutex_unlock(&t->m);
}

/* AP 6.9.3.14's wait. The compiler has already lent the handle, so an empty
 * task-variable trapped before this was reached. */
void pas_task_wait(void *p) {
  pas_task_join(p);
}

/* The task-type's closer (AP 6.4.12.1), so a task-variable is released by the
 * block that declared it and by `release` before that. It drops the reference
 * and does **not** join: the block's own set holds a reference too and joins
 * every activation it commenced before it releases anything of its own
 * (AP 6.9.3.12.1), so the join has a place already and this is not it.
 * Answers 0 because a closer answers an int and there is nothing to report. */
int pas_task_drop(void *p) {
  if (p)
    pas_task_drop_ref(p);
  return 0;
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
 *
 * It holds `struct pas_task *` rather than a `pthread_t` since ADR-0312: a
 * named task is joined by whichever of the two arrives first, and a bare
 * thread identifier has nowhere to record that.
 */
struct pas_taskset {
  struct pas_task **tasks;
  int n, cap;
};

_Static_assert(sizeof(struct pas_taskset) <= PAS_TASKSET_SIZE,
               "PAS_TASKSET_SIZE is smaller than struct pas_taskset");

void pas_tasks_init(void *slot) {
  struct pas_taskset *s = slot;
  s->tasks = NULL;
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

/* The spawn, in the two forms AP 6.9.3.12 admits. The unnamed one leaves the
 * set holding the only reference; the named one answers the record with a
 * second reference, for the task-variable that is about to hold it.
 *
 * The record is created and linked into the set *before* the thread exists,
 * so a task that finishes immediately cannot be joined by a set that has not
 * yet heard of it. */
static struct pas_task *pas_tasks_start(void *slot, void *fn, void *args,
                                        int refs) {
  struct pas_taskset *s = slot;
  struct pas_taskarg *a;
  struct pas_task *t;
  if (s->n == s->cap) {
    int want;
    /* Doubling is the growth, and the double is what overflows. Unreachable
       with real threads -- it wants 2^30 of them live in one block -- but the
       wrap would be negative and `(size_t)want` then enormous. */
    if (s->cap > INT_MAX / 2)
      pas_runtime_error("too many tasks spawned by one block");
    want = s->cap ? s->cap * 2 : 8;
    struct pas_task **grown = realloc(s->tasks, (size_t)want * sizeof *grown);
    if (!grown)
      pas_runtime_error("out of memory spawning a task");
    s->tasks = grown;
    s->cap = want;
  }
  t = malloc(sizeof *t);
  if (!t)
    pas_runtime_error("out of memory spawning a task");
  pthread_mutex_init(&t->m, NULL);
  pthread_cond_init(&t->donec, NULL);
  t->refs = refs;
  t->claimed = 0;
  t->done = 0;
  a = malloc(sizeof *a);
  if (!a)
    pas_runtime_error("out of memory spawning a task");
  a->fn = (void (*)(void *))fn;
  a->args = args;
  s->tasks[s->n] = t;
  if (pthread_create(&t->tid, NULL, pas_task_start, a) != 0)
    pas_runtime_error("a task could not be started");
  s->n++;
  return t;
}

void pas_tasks_spawn(void *slot, void *fn, void *args) {
  pas_tasks_start(slot, fn, args, 1);
}

/* AP 6.9.3.12's `spawn t := P(...)` (ADR-0312). Two references: the set's,
 * which the join drops, and this one, which the task-variable's closer does. */
void *pas_tasks_spawn_named(void *slot, void *fn, void *args) {
  return pas_tasks_start(slot, fn, args, 2);
}

/* AP 6.9.3.12.1's join, and it is where a block's activation ends. A task
 * `wait` has already joined is complete, so `pas_task_join` returns at once
 * and the reference this set holds is dropped exactly as any other's is --
 * which is what makes waiting for one task and joining all of them the same
 * statement asked twice rather than two mechanisms. */
void pas_tasks_join(void *slot) {
  struct pas_taskset *s = slot;
  int i;
  for (i = 0; i < s->n; i++) {
    pas_task_join(s->tasks[i]);
    pas_task_drop_ref(s->tasks[i]);
  }
  free(s->tasks);
  s->tasks = NULL;
  s->n = 0;
  s->cap = 0;
}
