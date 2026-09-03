# A tour of Afterschool Pascal

You know Turbo Pascal, or Free Pascal, or you learned Pascal once and can still
read it. You want a program running this evening — something that fetches a
URL, walks a directory, counts words. This document is for that, and it is the
only document here written that way: the
[specification](afterschool-pascal-spec.md) is an amendment in ISO clause
numbering, `doc/adr/` is an audit trail of decisions, and `README.md`'s
language section is a feature list. None of them tells you what an owned
pointer is *for*.

It is a tour and not a reference. Everything below is true, nothing below is
complete, and where a section stops the specification carries on. The programs
in `examples/` are the other half of this document: twelve complete programs of
a page each, every one of them a test case with a golden, so an example that
stops working fails the build. This text points at them constantly.

## 1. Getting a compiler, and compiling something

Every release from v3.5.0 carries a binary archive for `x86_64-linux` and for
`aarch64-linux`, each with a `.sha256` beside it. Unpack it anywhere and put
its `bin` on `PATH`:

```sh
tar -xzf afterschool-pascal-v3.5.0-x86_64-linux.tar.gz
export PATH=$PWD/afterschool-pascal-v3.5.0-x86_64-linux/bin:$PATH
```

Or build from a checkout — you need `cmake`, a `make` and `clang`, and
**nothing of LLVM's**:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Either way, write a program and compile it:

```pascal
program hello(output);
begin
  writeln('Hello, world.')
end.
```

```sh
pascalcc hello.pas -o hello && ./hello
```

**There are two commands and you almost always want `pascalcc`.** `pascalc` is
the compiler: it reads Pascal and writes LLVM IR, and stops. It does not
assemble and it does not link — not because that half was left out, but
because the compiler is itself written in this language, and no Pascal program
can start another process. `pascalcc` is the shell script that hands the IR to
`clang` and links the runtime. So `clang` is a dependency at *use* time, not
just at build time; that is the price of a compiler written in its own
language, and it is stated rather than hidden.

`pascalcc` takes `-o`, `-c`, `-S`, `-O0` through `-O3`, and passes any
`--dump-` flag straight through to the compiler. Diagnostics look like every
other compiler's:

```
prog.pas:12:7: error: 'total' is not declared in this block
```

Warnings look the same with `warning:` in the middle, and do **not** fail the
compilation. There are four of them and each is about a program that is legal
and probably not what you meant: an unused local, a statement after one that
cannot fall through, a function that writes its result on one path but not
another, and a `var` parameter nothing ever writes through.

## 2. What you already know

**This language contains Extended Pascal** (ISO/IEC 10206:1991), which
contains almost all of ISO 7185. If you can write it in standard Pascal you
can write it here and it means the same thing: `record`, `case`, `set of`,
`file of`, nested procedures, `with`, variant records, `packed`, `new` and
`dispose`, `read`/`readln`/`write`/`writeln` with the field-width syntax
(`x:6`, `y:0:3`).

From Extended Pascal you also get, without doing anything: modules and
separate compilation, `otherwise` on a `case`, `string(n)` with `+` and
substrings, `readstr`/`writestr`, `complex`, `bind`/`unbind` for attaching a
file variable to a name at run time, and `for x in s` over a set.

Three things are *not* the same as Turbo Pascal and will bite in the first
hour:

- **Every word-symbol is reserved** — all 45, ISO 7185's 35 and the ten
  Extended Pascal adds: `otherwise`, `pow`, `protected`, `value`, `bindable`,
  `module`, `export`, `import`, `only`, `qualified`. A record field called
  `value` is a syntax error here. Rename it; that is the whole of the fix.
- **Integer overflow traps.** `a + b` past `maxint` stops the program with a
  message and a source position, it does not wrap. So do a bad subscript, a
  `div` by zero, a `case` matching no label, and a `nil` dereference.
- **There is no `uses` and no unit file.** Modules are §6.11's, and section 3
  is about them.

For anything this tour does not cover, the specification
[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md) is the
statement of what the language is, written as an amendment to
ISO/IEC 10206:1991 in that standard's own clause numbering.

## 3. Modules: the heading is the interface

A module is written in two halves. The **heading** says what the module
exports and declares the types, constants, variables and routine headings that
cross the boundary. The **block** implements them. Both can live in one file:

```pascal
module Greeting;

export Greeting = (Greet, Punctuation);

const Punctuation = '.';

function Greet(who: string): string(80);
end;

function Greet;
begin
  Greet := 'Hello, ' + who + Punctuation
end;

end.
```

The first `end;` closes the heading; what follows is the block. Notice that
`function Greet;` in the block repeats the name **alone** — the parameters and
the result type were written in the heading and are still in scope. That is
`forward` under another name, and it is why the interface is not a second copy
of anything.

Using it is one word:

```pascal
program sayhello(output);

import Greeting;

begin
  writeln(Greet('world'))
end.
```

**A module-heading *is* the interface** (§6.11.1). There is no `.tpu`, no
`.ppu`, no generated header, no second artefact to keep in step — the thing a
client reads and the thing the implementation must satisfy are the same text.
That is also why the installed library ships as `.pas` sources: there is
nothing else to ship.

**Names arrive by the interface name, not the module name.** `export Greeting
= (…)` introduces an *interface* called `Greeting`, and `import Greeting`
brings in exactly the constituents listed. Two spellings shape that:

- `import Greeting only (Greet);` — the list is exhaustive, so `Punctuation`
  does not arrive at all.
- `import Greeting qualified;` — the names arrive only as `Greeting.Greet`,
  never bare, which is how you keep a local `Greet` of your own.

You can always write the long form whether or not you asked for `qualified`,
and you can rename on import with `=>`. §6.11.3 is the clause.

### There is no manifest, and no build order to maintain

This is the part worth knowing before you plan a project layout. Put the
program and its modules in one directory and compile the program:

```sh
pascalcc ./sayhello.pas -o sayhello
```

That is the whole build. The compiler resolves `import Greeting` by looking
for `greeting.pas` — the interface name, case-folded, with `.pas` after it —
in the source's own directory, then in each `--import-path` you gave, then in
each `:`-separated entry of `AFTERSCHOOL_PASCAL_PATH`. The search is
**transitive**: a module that imports another gets that one found too, and the
components come out in the order their activations must run, so nothing has to
be listed anywhere. `pascalcc` asks the compiler what it found and translates
and links exactly those.

An installed compiler puts the standard library where the third rule finds it,
so `import PasJson` works from any directory with no flag at all. If you keep
your own modules elsewhere, name the directory once:

```sh
pascalcc --import-path ~/pascal/lib app.pas -o app
```

> **One wart, as of this writing.** The first rule — *the source's own
> directory* — is computed from the path you typed, and a bare `prog.pas` has
> no directory in it, so a sibling module is not found. Write `./prog.pas`, or
> pass `--import-path .`, until that is fixed; `doc/roadmap.md` carries the
> row.

`examples/` shows the receiving end: seven of the twelve programs import
library modules and carry nothing but a `.importpath` sidecar naming the two
library directories.

## 4. Strings and text

There are two string types and the difference is the difference between
*bytes* and *characters*.

**`string(n)` is Extended Pascal's**, and it is what Turbo Pascal's `string`
was: a value with a declared capacity, a length, and `s[i]` being the i-th
**byte**. It concatenates with `+`, compares with `=` and `<`, and takes a
substring with `s[i..j]`:

```pascal
program strings(output);

type Line = string(80);

var s: Line;

{ `string` as a parameter type accepts a value of any capacity. }
function Shout(w: string): Line;
begin
  Shout := w + '!'
end;

begin
  s := 'hello';
  writeln(Shout(s), ' ', Shout('and again'));
  writeln(s[2..4], ' ', length(s):1)
end.
```

The `string` in `function Shout(w: string)` is the one thing here Turbo Pascal
has no equivalent of and every program wants: a **schematic** value parameter,
which accepts a `string(n)` of *any* capacity, a literal, or another
function's result. Write your parameters that way and callers never have to
match a number.

Capacity is a decision and not a formality. `readln` into a `string(80)` fills
80 bytes and **silently skips the rest of the line** (§6.9.1) — no error, no
truncation report. `examples/word_count.pas` declares 4096 and says why.

**`utf8(n)` is the text type**, and it holds up to n bytes of UTF-8 kept in
Unicode normal form C. Its element is not a byte and not a code point but an
extended grapheme cluster — what a reader would call a character — so
`length(t)` answers the number a person would count, and `for g in t` walks
them one at a time. An integer index is *refused*: reaching element k means
walking, and the language makes you write the walk rather than hiding it.

```pascal
program text(output);

var t, g: utf8(64);

begin
  t := 'héllo, 世界';
  writeln(length(t):1, ' characters');
  for g in t do
    write(g, '.');
  writeln
end.
```

Because normalisation happens on assignment, two spellings of `é` — one code
point, or `e` and a combining acute — become the same value, and comparing two
texts is a byte comparison that answers what a reader would.
`examples/graphemes.pas` is the whole story in a page, including
`PasUnicode`'s scalar view for when you do want code points, and `Fold` for a
caseless comparison that gets `Straße` and `STRASSE` right.

## 5. Errors: a result you cannot forget to check

Pascal has no exceptions and this language adds none. What it adds is a type.

**`T ! E` is a fallible type** (AP 6.4.13): a value of `T`, or a cause of `E`,
and which one it holds is a tag the language enforces. Reading the arm that
was not written **stops the program** — so forgetting the check is a halt with
a source position, never a stale value silently used.

```pascal
type Width = integer ! ErrorCode;
```

`r.ok` says which arm was written, `r.val` is the value and `r.cause` is the
reason. `ErrorCode` comes from `PasError` and is deliberately tiny — six
categories, `errNone`, `errSyntax`, `errRange`, `errAbsent`, `errFull`,
`errIO` — because a code is a thing you branch on and a sentence is a thing
you print. `ErrorText(e)` gives the sentence.

There are three shapes for reading one, and choosing between them is the whole
of the skill.

**`try(x)`** (AP 6.8.9) is x's value where x succeeded; where it failed, the
cause becomes *this function's* result and the function returns at once. It is
`if not r.ok then exit(r.cause)` written by the language, once, at the point
of use — so it composes: a routine that calls three fallible routines is three
`try`s and no branching.

```pascal
function Doubled(text: string): Width;
begin
  Doubled := 2 * try(ParseInt(text))
end;
```

**`ValueOr(r, whenBad)`** is the accessor: the value, or a default. One
routine covers every fallible type in the library, because `Fallible(T)` is
one schema and the type argument is inferred at the call.

```pascal
writeln('width = ', ValueOr(ParseInt('80'), 72):1);      { 80 }
writeln('width = ', ValueOr(ParseInt('wide'), 72):1);    { 72 }
```

**And the plain `if r.ok`**, which is what you write when the two arms do
different things.

**Which to reach for.** `try` propagates by *leaving the routine*, so it is
right in the middle of a chain and wrong at the edge — a program that must
still answer, print something, or carry on to the next line cannot leave, and
`try` in `main` is `halt` with extra steps. The accessor is the default shape
for a caller that has a sensible default and does not care why. `if r.ok` is
for when it does care. `examples/parse_errors.pas` is these three side by
side; a whole program's worth of them is `examples/json_pretty.pas`, where
every reader answers something sensible for a node that is not there.

## 6. Memory: what an owned pointer is for

In Turbo Pascal a linked list is `^Node` and every node you forget to
`Dispose` is leaked. Nothing in the language knows which pointer is
responsible for which block, so being right is a convention you maintain by
hand across every early return.

**`owned ^T` says which one is responsible** (AP 6.4.14). The variable holding
an owned pointer *owns* the node: when the variable dies — at the end of its
block, or on `dispose` — the node is disposed, and so is everything the node
owns, recursively. That is what an owned pointer is for: it moves the question
"who frees this?" out of your head and into the declaration.

The price is that an owned pointer has **no copy**. Two variables cannot both
own one node, so assignment from one to another is refused. What you get
instead is a move: **`take(p)`** yields what `p` holds and leaves `p` empty,
and it is the only value an owned pointer may be assigned.

```pascal
program memory(output);

type
  List = owned ^Node;
  Node = record key: integer; next: List end;

procedure Push(var l: List; key: integer);
var fresh: List;
begin
  new(fresh);
  fresh^.key := key;
  fresh^.next := take(l);   { the old list hangs off the new node }
  l := take(fresh)          { and the new node becomes the front }
end;

procedure Show(var l: List);
begin
  if l <> nil then begin
    write(' ', l^.key:1);
    Show(l^.next)
  end
end;

procedure Run;
var head: List;
begin
  Push(head, 1);
  Push(head, 2);
  write('list:'); Show(head); writeln
end;                        { head dies here, and the chain with it }

begin
  Run
end.
```

`Show` takes `var l` and not a copy — a `var` parameter bound to an owned
value is a **borrow** for the duration of the call, and it is the one second
name an owned value has. It cannot escape: Pascal has no address-of operator
and `new` is the only thing that produces a pointer, so there is nowhere for a
borrow to be stored. Note also that the list is walked by recursion; a loop
would want a second pointer to the current node, and there isn't one to be had.

`examples/owned_list.pas` is a sorted insert and a pop-front over exactly this
shape.

**Two other things are owned in the same sense.** A **file** variable, which
Pascal has closed at the end of its block since 1982. And a **handle**, which
is how this language holds something a C library owns — an open `FILE *`, a
directory, a socket, a TLS session. You never declare one; the library does,
and you get a variable that closes itself when its block ends. Assigning `nil`
to a handle is the early release.

**`defer S`** arms a statement to run when the enclosing statement-sequence
completes — a normal end, an `exit`, or a `try` that failed — in the reverse of
the order the defers were written. It is where cleanup goes when there is no
owner to attach it to:

```pascal
e := MakeDirectory(dir);
defer e := RemoveDirectory(dir);
```

`examples/defer_cleanup.pas` is a block that makes a directory, writes a file
into it, and removes both on every way out.

## 7. Generics: schemata, and a type as a parameter

Extended Pascal has **schemata**: a type parameterised by a *value*, which is
how `string(n)` works. This dialect lets a discriminant name a **type**
instead, which is what makes a generic container possible.

`PasContainer` is the example, and it is what four hand-copied modules used to
be. A program names its element type in one line and uses the container:

```pascal
program generic(output);

import PasContainer;

type IntVec = ^Vec(integer);

var v: IntVec; k: integer;

begin
  VecInit(v, 8);
  for k := 1 to 5 do
    VecPush(v, k * k);
  for k := 1 to VecLen(v) do
    write(' ', VecGet(IntVec, integer, v, k):1);
  writeln;
  VecFree(v)
end.
```

A routine can take a type parameter too — `function ValueOr(T: type; res:
Fallible(T); whenBad: T): T` is the library's — and **an activation need not
write its type arguments** when the other actuals determine them
(AP 6.7.3.10.4). That is why `VecInit(v, 8)` and `VecPush(v, k * k)` are
written with no types at all: the container variable says what they are.

`VecGet` above is the exception, and it shows you the rule. Its element type
appears **only in the result**, and nothing in the call determines it — so it
must be written, and inference is all-or-nothing, so the pointer type has to
be written beside it. When a generic call looks unreasonably wordy, that is
almost always what has happened. `examples/word_freq.pas` counts words with a
generic map and reads, deliberately, as a program about that signature.

The map's key is a fixed `MapKey` of 63 characters rather than a type
parameter, because a key must be hashed and compared and the language has no
way yet to say that of a type. You pass the pair of routines instead:
`MapPut(m, w, n, StrHash, StrEq)`.

## 8. Concurrency: tasks and channels

There are two threads of control and the model is share-nothing.

A **`task`** is a procedure that only `spawn` may start. A **`channel [n] of
T`** is a bounded queue and a handle. A task is given copies of its value
arguments and references to its channels and **can reach nothing else** —
there is no shared variable to race on — and every task a block spawned is
joined before that block ends.

```pascal
program tasks(output);

type Ints = channel [4] of integer;

task Squares(out: Ints; n: integer);
var i: integer;
begin
  for i := 1 to n do send(out, i * i);
  send(out, 0)                      { the sentinel }
end;

var c: Ints; v: integer;

begin
  spawn Squares(c, 5);
  v := -1;
  while v <> 0 do
    if receive(c, v) then
      if v <> 0 then writeln(v:1)
end.
```

**Read the sentinel, because it is the trap.** A stage cannot close the
channel downstream of it: `release(c)` on a channel a task was *handed* drops
only that task's reference, since a worker must not close a channel its
colleagues are still reading. So a pipeline where each stage closes the next
does not work — it deadlocks, in silence, with no diagnostic. End a stream on
a value the data can never take, as above.

`examples/pipeline_tasks.pas` is a producer, a filter and a consumer built
that way. What is not there yet: you cannot hand a task a socket or a stream
(only transferable values and channels cross), you cannot wait on one task, and
there is no select over several channels and no timeout. A program needing
anything finer writes a second channel.

## 9. Talking to C

An `external` directive after a heading binds a C symbol. There is no wrapper,
no header, and no build step:

```pascal
program cfun(output);

function strlen(s: string): int64; external 'strlen';
function cbrt(x: real): real; external 'cbrt';

begin
  writeln(strlen('hello'):1, ' ', cbrt(27.0):0:3)
end.
```

libc and libm are already linked. The types that cross are exact: `integer` is
C's `int`, `int64` is a 64-bit integer or a `size_t`, `real` is a `double`, a
`string` value parameter arrives as a NUL-terminated `const char *`, and a
`var` parameter of a scalar arrives as the pointer C wants. A **record** may
be the type of a `var` parameter at an `external` heading, so a struct can
cross by address — but a struct whose layout differs between systems (`struct
stat` is the standing example) is one a portable module may not declare, and
the runtime answers instead.

Nothing checks your declaration against the real header. It is a claim you are
making, and getting it wrong is undefined behaviour in the ordinary C sense.

A program that binds a library beyond libc passes the flag itself:

```sh
AFTERSCHOOL_PASCAL_LDFLAGS='-lssl -lcrypto' pascalcc client.pas -o client
```

`examples/c_function.pas` binds five libc functions, including one with a
`var real` out-parameter.

## 10. In an editor

`lsp/` holds a Language Server Protocol server written in this language. Build
it once and point your editor at the binary for Pascal files; it needs no
arguments and talks over standard input and output.

```sh
lsp/build.sh tools/pascalcc ~/bin/pasls
```

It publishes diagnostics as you type — you do not have to save — and answers
nine requests:

| Request | What you get |
| --- | --- |
| `documentSymbol` | the outline of a document |
| `definition` | where a name was declared, across program-components |
| `hover` | what a name is, and its type |
| `foldingRange` | folding for every `begin`, `if` and loop |
| `selectionRange` | expand-selection, outward through nested statements |
| `formatting` | the document laid out by the compiler's own formatter |
| `rangeFormatting` | the same, for the lines you selected |
| `references` | every occurrence of a name, into the components the compilation read |
| `rename` | those occurrences edited, or a refusal that says why |

The outline, folding and selection work on a document that does **not compile
yet**, which is when they are most wanted: they stop after the parse.
Formatting will not — a document the lexer cannot read is answered with no
edits, and your buffer is left alone.

The same binary speaks the Model Context Protocol when given `--mcp`, with two
tools — `outline` and `diagnostics` — for an agent working on Pascal. The
`.mcp.json` at the root of this repository wires it up for Claude Code, and
`lsp/README.md` has the rest.

## 11. Where to go next

- **`examples/`** — twelve programs of a page each, each one a test case:
  `hello_args`, `word_count`, `word_freq`, `dir_sizes`, `json_pretty`,
  `parse_errors`, `owned_list`, `graphemes`, `pipeline_tasks`, `fetch_http`,
  `c_function`, `defer_cleanup`. Read them all; between them they use most of
  the library.
- **`README.md`'s module table** — thirty-one modules with a paragraph each on
  what is in them and what was deliberately left out. Start there when you
  want to know whether the thing you need already exists.
- **[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md)** — the
  language, clause by clause. It is where a requirement is written precisely
  enough to argue with.
- **[`doc/design-digest.md`](design-digest.md)** — a paragraph per mechanism,
  for when you want to know why something is the way it is and do not want to
  read a decision record to find out.
- **[`doc/roadmap.md`](roadmap.md)** — what is missing, measured, with the
  command beside each number.

The language carries **no stability promise**: it is what the compiler in your
hand defines, and a program that needs fixed behaviour should pin a version.
