# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/).

The public interface of a compiler is **the accepted language, the diagnostics
and the command line**. That is what these entries describe and what the version
number tracks.

Entries for a released version are left as they were written, so `pascalc-s0`
appears below in the release where it still existed.

## [Unreleased]

### Added

- **A diagnostic can be a warning** (ADR-0272). Every diagnostic this compiler
  wrote was an error; `WarnAt` stands beside `ErrorAt` and the only difference
  is that a warning does not fail the compilation. The format is unchanged --
  `file:line:col: warning: message` on the same stream -- so anything already
  parsing a diagnostic reads one, and the exit status is untouched.

- **A local variable declared and never used is reported.** The first warning.
  It applies to a variable with a frame slot in a procedure's or function's
  activation, in the file being compiled, and deliberately not to a parameter,
  to a variable of the program's or a module's own block, to a `bindable` one,
  or to anything at all once an error has been reported. It found twelve dead
  declarations in the compiler's own source on its first run.

- **`pascalc --format`** (ADR-0279) writes a source back out with a layout of
  the compiler's own: the same tokens in the same order, the same comments in
  the same places, and nothing else the same. It works from the token stream,
  keeps to a 79-column margin where a space already stands, never splits a
  token and never reflows a comment, and refuses rather than printing a file
  with a comment missing from it. Nothing in this repository is formatted by
  it.

- **The language server formats a document** (ADR-0280).
  `textDocument/formatting` runs `pascalc --format` over the buffer and answers
  with one edit over the whole of it. A source the lexer rejects, or one with
  more comments than the formatter can keep in order, is answered with no edits
  and the buffer is left alone. `tools/pascalcc` passes `--format` through to
  the compiler and links nothing, as it already did for the dump flags.

- **`pascalc --dump-trivia`** writes every comment a source holds, with its
  position and the token it precedes. It stops after the lexer, which is one
  stage earlier than any other dump that stops.

- **The lexer records 6.1.8's comments** rather than discarding them -- but
  only when `--format`, `--dump-trivia` or `--dump-limits` asks. An ordinary
  compilation is unchanged in every respect, including what it can fail on. A
  source with more than 20 000 comments still compiles; what is refused is the
  request to format it. `--dump-limits` reports the count as a third array
  beside the pool and the tokens.

- **A statement after one that leaves is reported** (ADR-0277). The second
  warning. Five statements leave -- `goto`, `halt`, `exit`, `break` and
  `continue` -- and a statement written after one of them in the same
  statement-sequence is named `this statement cannot be reached`. A labelled
  statement is looked *through* and is where a run of dead statements ends; a
  run is reported once; and the empty statement a doubled separator leaves
  behind is never named. It is not a flow analysis: an if whose two arms both
  leave is not claimed. Five dead statements exist in the 779 tracked sources
  and all five are deliberate.

- **A function that writes its result on one path and not another is
  reported** (ADR-0278). The third warning. 6.7.2 requires a function-block to
  write its result at least once and a body that never does is an error; this
  is the body where the one assignment stands somewhere not every path reaches
  -- an `if` with no else-part, one arm of two, a `case` arm that writes
  nothing, a loop that may run no times. `halt` and `exit(e)` are understood,
  and so is `repeat ... until false`. A `goto`, an assignment made by a nested
  procedure, and 6.7.2's result-variable-specification each silence it.

- **`name.warn`**, a test sidecar for what a *successful* compilation said --
  neither `name.out` nor `name.err` can hold that. A case without one must
  produce no warning.

- **The language server reports a warning as one.** `PasLspDiag` recognises
  ` warning: ` beside ` error: ` and `Diagnostic` carries a `DiagSeverity`, so
  an editor gets LSP's DiagnosticSeverity 2 where the compiler wrote a warning
  and 1 where it wrote an error. It had recognised only errors, and would have
  silently dropped every warning.

- **`--coverage` measures branches as well as statements** (ADR-0274). Beside
  the existing counter per statement, one counter is now emitted on each edge
  of every decision the source writes -- an if-statement, a while-statement, a
  repeat-statement, and each short-circuit `and`, `or`, `and then` or
  `or else`. A run appends the directions it took to `$PASCOV_BRANCHES` as
  `line col direction`, keyed on line **and column** because two decisions may
  be written on one line. Nothing changes for a program compiled without the
  flag. A `for` statement's test and every runtime check are outside it: the
  first is generated from the bounds rather than written, and the second is
  the compiler's branch rather than the program's.

- **A fuzzing gate** (ADR-0275). `tests/checks/fuzz.py` truncates real sources
  at every byte, generates one input per fixed buffer and per depth limit, and
  mutates the corpus from a fixed seed. It found no crash -- 3128 inputs in
  the suite and 41 628 in a campaign -- which is the result: the claim that
  this compiler survives hostile input was made by nothing before it.

- **`too many tokens` and `out of string space` are counted as diagnostics
  again.** Both were excluded from the coverage gate as "capacity limits, not
  diagnostics about a program being compiled". Both carry a file, a line and a
  column, and neither had a golden because no case had ever reached one.
  Nothing about the compiler changed; what changed is that they are now named.

### Changed

- **`ResolveRestricted` no longer carries a `done` flag.** The two
  if-statements it stood between are now one if and its `else`, which is what
  the flag meant. No behaviour changes; it is the one thing the warning above
  found in 779 sources.

### Fixed

- **The language server no longer stops on a large document** (ADR-0276).
  `PasContainer`'s vector clamped a growth request at `CapMax` and then wrote
  the element anyway, one past its array, so any document of a million bytes
  or more halted the server -- and `selfhost/apfront.pas` is 992 056 bytes,
  1 017 200 as a JSON string. `VecPush` now writes nothing it has no room for,
  `VecReserve` asks whether the vector would actually be bigger (it copied the
  whole vector on every push at the ceiling), and `VecFull` and
  `JsonCharsFull` are how a caller asks. A message that does not fit is
  reported as `errFull` and skipped, with the session intact.

- **`CapMax` is 16 000 000, not 1 000 000.** The old bound was round and had
  never been compared against anything; the new one is 15.7 times the largest
  message this tree can produce, and it is stated in elements with the
  measurement beside it.

### Changed

- **A `--dump` flag now suppresses warnings.** Each dump has a reader parsing
  a fixed grammar and a warning is not part of any of their answers.

## [3.2.0] - 2026-08-30

The release that closed `doc/roadmap.md`'s *What a daily program still cannot
reach for*. Every row of that chapter is struck through — six library gaps and
the two absences in the language itself — and nothing replaced any of it.

Two of the six rows had said *why* they were blocked and both reasons were
wrong, which is the lesson the chapter now records: a row saying a feature is
blocked is a row nobody has tried.

### Added

- **A type parameter may say what it needs** (ADR-0266, AP 6.7.3.10.5).
  `function Sum(Elem: numeric type; a, b: Elem): Elem` -- a type parameter may
  carry one of four categories, `numeric`, `ordinal`, `ordered` or
  `equatable`, and the call that names a type outside it is refused **at the
  call**, saying which requirement it missed. Without one such a program was
  refused inside the generic's own source, by whatever operator its body used.
  The four names are recognised only between a parameter's colon and the word
  `type`: nothing is reserved, and a program may go on declaring a type, a
  variable or a routine of each. A category filters the activation and does
  not check the generic's body abstractly -- a body that misuses a type its
  category admits is still caught where it always was.

- **A generic activation need not write its types** (ADR-0254,
  AP 6.7.3.10.4). `Swap(i, j)` where `Swap(integer, i, j)` was required, and
  `ValueOr(r, 0)` where `r` already says the type. A call writes an argument
  for every parameter, or one for every parameter that is not a type; the two
  counts are never the same, so the shorter form is unambiguous. A type
  parameter is fixed by the first argument that determines it — through a
  type-name, a schema production, or a slice's component — and every later
  argument is an ordinary argument judged as any other. One that no argument
  determines, such as an element type appearing only in the result, must still
  be written, and the compiler says which one.

- **A function may answer a handle** (ADR-0255), so a library can hand back an
  open stream, directory or pipe instead of taking a `var` parameter for it.
  The value is built in the variable it is assigned to, so no second name for
  it exists at any moment, and a factory calling a factory passes the
  destination on. A record containing a handle is still not a valid result.
- **A fallible type's value side may be a handle, a file or an owned pointer**
  (ADR-0256), so `function Open(p: Path): Stream ! ErrorCode` is writable and a
  producer can say *why* it failed. Such a record's two arms are laid beside
  one another rather than over one another; it has no copy, the one assignment
  it takes being a call of a function of its own type; and `try` is refused on
  it, since `try` yields the value and an owned value has none to yield — test
  `.ok`. The cause side may not be owned, for the same reason.

- **The language server folds code and expands a selection** (ADR-0258).
  `textDocument/foldingRange` puts an arrow beside every `begin`, `if` and
  loop; `textDocument/selectionRange` expands outward through nested
  statements instead of jumping to the enclosing declaration. Both come from a
  new `pascalc --dump-stmts`, which stops after the parse — so both work on a
  file that does not compile yet.
- **The language server does not compile a change nobody will see the answer
  to** (ADR-0257). A burst of keystrokes costs one compilation rather than one
  each: four queued edits of a 22 900-line source went from 780 ms to 340, and
  the change being waited for is compiled first rather than last.
- `PasIO.FdReady` and `PasLsp.LspPending` ask whether a read would block.

- **Four library modules**: `PasTime` (arithmetic on a date, an ISO 8601 form
  written and parsed, a UTC offset shift), `PasTerm` (is this a terminal, how
  big is it, raw mode, a key, the cursor sequences), `PasHttp` (an HTTP/1.1
  client over `PasNet`, `Content-Length` and chunked, no TLS) and `PasRegex`
  (regular expressions with a stated worst case, `2 × program × subject`,
  because a backtracking matcher has no bound this language could enforce).
- **A map may be keyed by any type a program names** (ADR-0260). The hash and
  the equality travel with each operation as procedural parameters, which is
  what `PasSort` has always done; no language feature was needed, and the
  roadmap's claim that this waited on generic *constraints* was wrong.
- **A generic's diagnostic says which activation asked for the instantiation**
  (ADR-0259). An error inside a generic's body is reported at the generic, as
  it must be; one more line now names the call that demanded that translation,
  which matters most for a call that writes no type arguments at all.
- `pascalc --dump-stmts`, and the language server's folding and
  selection-expansion built on it.
- The corpus is compiled and run under AddressSanitizer, UndefinedBehaviour-
  Sanitizer and LeakSanitizer as a `ctest` case (ADR-0261).
- **`lib/dialect/pastls.pas`, a verified TLS client** (ADR-0264) — `Connect`,
  `ConnectTrusting`, `WriteText`, `WriteLine`, `ReadLine`, `Close`, over
  OpenSSL. **Verification cannot be turned off**: there is no flag, no mode
  and no second entry point that skips it, and every connection checks the
  chain to a trust anchor, checks it is valid now, and checks the certificate
  is for the host that was asked for, with TLS 1.2 as the floor. What a caller
  chooses is which anchors — the system's, or one PEM file, a self-signed
  certificate being its own anchor. No server side, no client certificate and
  no revocation checking. A program using it links `-lssl -lcrypto`; nothing
  else here links anything, the runtime included. Its exported bounds are
  `Tls`-prefixed (`TlsLineMax` and the rest), as `PasLsp`'s are: `PasHttp` has
  a `ReasonMax` of its own and `PasNet` three more, so an HTTPS client could
  not otherwise import what it needs. This closes the last row of
  `doc/roadmap.md`'s *What a daily program still cannot reach for*, and that
  row had said it was blocked for two reasons neither of which was true.
- **Concurrency: `task`, `spawn`, `channel [n] of T`, `send` and `receive`**
  (ADR-0268), share-nothing and reserving no word-symbol. A task takes a copy
  of every value it is passed and a reference to every channel, and may name
  only its own variables; every task a block spawned is joined before that
  block releases anything. Built to the design ADR-0201 settled four
  increments earlier, on ADR-0267's move.
  Not here: a task cannot be *given* a handle, there is no way to wait for one
  task, no select over several channels, and no timeout on a send or receive.
- **A handle moves** (ADR-0267, AP 6.4.12.7). `take` applies to a variable of
  a handle-type as it applies to one of an owned-pointer-type — the two are
  one word apiece, and the reason neither may be copied is the reason both
  need a move. A **file** is still refused and always will be: there is no
  value in one for a variable to stop holding.
- **`lib/dialect/pashttps.pas`, HTTP/1.1 over TLS** (ADR-0265), and the
  `PasHttp` grammar it is built on: `BeginRequest` and `NextPiece` turn a
  request into the octets to write, and `BeginResponse`, `WantsLine`,
  `FeedLine` and `FeedEnd` turn a sequence of lines into a response, with no
  transport under any of them. `PasHttp.Send` and `PasHttp.Receive` are now
  twelve lines each over that grammar and behave as they did; `PasHttps` is
  the same twelve over a `PasTls.Connection`. A module that chose between
  transports would have had to import `PasTls`, and then every program using
  plain HTTP would link OpenSSL.
- **`AFTERSCHOOL_PASCAL_LDFLAGS`**, which adds flags to `pascalcc`'s final
  link alone, after the runtime. `AFTERSCHOOL_PASCAL_CFLAGS` reaches every
  `clang` and stays that way for the sanitizers; a library a program *binds*
  belongs in one place, and `-lssl` handed to a `clang -c` is an input clang
  complains about once per translation.

### Changed

- **A handle may be assigned three things rather than two**, and `take` empties
  two kinds rather than one, so both diagnostics were reworded (ADR-0267).
- **The runtime's per-activation bookkeeping is thread-local** — the open
  files, the live handles, the armed deferred statements and the string
  arena — because each is a stack of what one chain of activations owns and a
  task is a second chain (ADR-0268). It costs a single-threaded program
  nothing measurable and costs a program with *n* tasks *n* string arenas.

### Fixed

- **A program could not bind a C function that a module it imported had bound
  privately** (ADR-0263). AP 6.7.7.11 scopes "one linker symbol, one
  `external` declaration" to a single program-component; the compiler enforced
  it over the whole compilation, so importing `PasIO` took `read` and `write`
  away from you, and `PasNet` took the socket calls. The diagnostic named the
  module's own routine, which your program cannot see.
- **A file variable bound by `bind` leaked its name.** The name was freed only
  when *replaced*, so a bound file going out of scope lost one — once per
  bind, and the language server binds once per keystroke.
- **A generic taking a procedural parameter could be instantiated wrongly.**
  The second instantiation reused the first's resolved types where the
  procedural parameter's own parameter type depended on the type arguments,
  and the actual was then refused against a type from another activation.
- **A generic call could not put a type parameter after a value parameter.**
  `procedure P(a, b: integer; T: type; x: T)` matched the type parameter
  against the second `integer` and reported that an argument nobody meant as a
  type must name one, so no call to such a routine compiled.
- **Two type parameters in one group took one type between them.**
  `procedure P(T, U: type; …)` gave `U` the type of `T`.
- **The language server's MCP outline reported end-line numbers instead of
  names** for a declaration it could not read out of the source — a
  declaration past the 4 096 characters it holds of a line. The LSP outline
  was unaffected.

### Changed

- **The language server answers a repeated hover without recompiling**
  (ADR-0252). What `--dump-uses` last said about a document is kept against
  that document and dropped when its text changes, so five hovers on an
  unchanged 22 900-line source cost one compilation rather than five — 795 ms
  to 106. Nothing about an answer changes; only how often one is computed.
- **`--dump-symbols` writes a declaration's extent** (ADR-0253), so its line
  is now `symbol <depth> <kind> <line> <col> <len> <endline> <endcol> <name>`.
  A declaration with a block reaches its closing `end`; one without answers
  with the end of its own name. The language server maps the two onto the
  protocol's `range` and `selectionRange`, which were the same value until
  the parser recorded where a block stops.

## [3.1.0] — 2026-08-30

The release the **language server** was written for. `lsp/pasls.pas` is a
Language Server Protocol implementation written in Afterschool Pascal and for
it — the first client here large enough to say whether the dialect is pleasant
to write in, which no gate can measure — and it also answers MCP over the same
binary. Writing it produced twenty-three findings, seventeen acted on, two of
which changed the language.

Beside it, the compiler became something you can **install**: an `import` that
names no file is resolved by search, `cmake --install` lays out a prefix, and
`pascalc` and its runtime are found beside `pascalcc`.

### Changed

- **Objects built by an earlier release will not link with objects built by
  this one.** A digest of a module-heading's tokens is now part of the name of
  that module's activation procedures (ADR-0245), so a mixture the linker
  used to accept is refused. That is the point of it — the mixture produced a
  wrong answer with a zero exit status, and the entry under *Fixed* below has
  the detail — but it means a partial rebuild across this version boundary
  fails at the link step rather than silently working. Rebuild every
  component. A comment, a reflow or a change confined to a module-block still
  forces no relink.
- **An `import` that names no file now searches instead of failing.** Where a
  translation gave no `--import` for an interface, the compiler used to report
  that the interface had not been exported; it now looks for
  `<directory>/<name>.pas` in the source's own directory, then each
  `--import-path`, then each entry of `AFTERSCHOOL_PASCAL_PATH` (ADR-0244).
  A program that relied on the old failure — a stray `counter.pas` beside a
  source that imports `counter` — will now find and translate that file.

- **A translation may be given 32 `--import` arguments and 72 command-line
  arguments**, where the limits were 8 and 24 (ADR-0235). The two are one
  limit: an import costs two words of the command line, so a bound on imports
  is only real as far as the argument list can express it, and `argMax` is now
  derived from `maxImports` rather than counted separately. A command line
  above either is still reported and never truncated. What asked for it was the
  first program in this tree with ten modules — `lsp/pasls.pas`, whose import
  chain could not be written at all.

### Fixed

- **An object built from an older module-heading is refused** (AP 6.13.2,
  ADR-0245). §6.11.1 makes the heading the interface and §6.13 translates the
  components separately, so two translations could read two different headings
  for one module and agree about every name in both: a program compiled
  against `record tag: integer; a, b: integer` and linked against an object
  built from `record a, b: integer` resolved every symbol, ran, and printed
  `a=11 b=0` for what it wrote as `a=11 b=22` — exit 0, no diagnostic
  anywhere. A digest of the heading's **tokens** is now part of the name of
  that module's activation procedures, so the linker refuses the mixture and
  `pascalcc` says which module and why. Tokens rather than text: a comment, a
  separator or a reflow in a heading forces no relink, and a change confined
  to a module-block is not a change to a heading.

### Added

- **`--dump-uses`**, which writes every applied occurrence in a source and the
  defining-point it resolved to — the file, line, column and length the name
  was declared at, with the kind and the type (ADR-0246). It is what a tool
  asks for go-to-definition and for a hover, and it is the first dump that
  runs the compiler through Sema: which declaration a name denotes is
  §6.2.2's scope rules and a parse cannot say. Unlike every other dump it
  reports what Sema resolved **whether or not Sema was happy**, because Sema
  accumulates its diagnostics rather than stopping at the first and a name is
  most worth looking up while the file is still being edited. A `file <index>
  <path>` table comes first, so a defining-point in another program-component
  can be named.
- **The language server answers `textDocument/definition` and
  `textDocument/hover`** out of that flag, with the imports its diagnostics
  path already resolves — so a definition crosses a file, which is what the
  method is worth having for.
- **A record field is answered too** (ADR-0247), and it is the one applied
  occurrence in this language that resolves to no symbol: §6.4.3.3 makes a
  record type a *region* with a defining-point in it for every field, while a
  selection is resolved by asking the record's type rather than a scope. A
  field written bare inside §6.8.3.10's `with` answers the field's own
  declaration as well, not the with-statement.
- **An interface name is answered** (ADR-0248), and the occurrence that
  matters is `import Middle;` — where a module says where it gets things
  from — rather than §6.11.3's rarer `M.x`. It leads to the `export` clause
  §6.11.1 makes the interface's defining-point, in whichever file that is.
- **A name inside a schema's own body is answered** (ADR-0249). §6.4.7
  re-resolves such a body once per distinct tuple, *where the type is
  written*, so the compiler reads one file's text while checking another;
  what says whether to report it is the schema's own file and not the one
  being compiled. A schema declared in another component still answers
  nothing about its body, that text not being in this document.
- **A declaration answers as an occurrence of itself** (ADR-0250), so a hover
  over `var Total: Counter` gives the type where it used to give nothing. The
  one place it is more than a no-op is Pascal's declaration/definition split:
  §6.6.1's `forward` and §6.11.1's module-heading declare a routine whose body
  arrives later, and the name at the implementation now leads back to the
  interface that promised it.
- **A module's own declarations and its `export` clause answer** (ADR-0251).
  §6.11.1 registers an interface beside the scope rather than in it, and puts
  a module's declarations in a heading whose defining-points §6.2.2.12 makes
  the block's as well — so each needed handling of its own, and each name is
  reported once whichever part declared it.
- **An `import` can name no file at all.** An interface no `--import` supplied
  is looked for as `<directory>/<name>.pas` — folded as §6.1.2 folds every
  identifier — in the directory the source is in, then in each
  `--import-path <dir>`, then in each `:`-separated entry of the new
  environment variable **`AFTERSCHOOL_PASCAL_PATH`** (ADR-0244). The search is
  transitive and answers in the order §6.2.3.6 requires activations to
  commence, and `tools/pascalcc` translates and links whatever the compiler
  found. A program in a directory with its own modules now needs no flags at
  all. The file is named after the *interface*: a module exporting one under
  another name is still reached with `--import`.
- **`--dump-imports`**, which writes the program-components a translation read,
  one to a line in activation order. It is how a build tool learns what
  resolution found, resolution giving the compiler an interface and not an
  object.
- **`cmake --install` puts the compiler somewhere.** `pascalc` and `pascalcc`
  in `<prefix>/bin`, `libpasrt.a` in `<prefix>/lib`, the library's sources in
  `<prefix>/lib/afterschool`. `pascalcc` looks for its compiler and its runtime
  beside itself before it looks in a build tree, and adds the installed library
  to the search path when `AFTERSCHOOL_PASCAL_PATH` says nothing — so `PATH` is
  the whole of what an installed copy needs.
- **`PasFS.TemporaryPath(dir, prefix)`** — a path in `dir` that names nothing
  else, with the file created empty so it goes on naming nothing else after
  this process has exited (ADR-0243). Nothing removes it; `Remove` is how it
  goes away. It is **not** `mkstemp`, which takes a `char *` it modifies and
  cannot be reached through this foreign-function interface, and it costs the
  runtime's non-ISO-C catalogue nothing: C11 7.21.5.3's exclusive `fopen` mode
  is the whole mechanism, tried in a loop.
- **`PasProcess.ProcessId`** — the number the operating system knows a program
  by, from `getpid` (ADR-0242). Positive, and held by no other program running
  at the same moment, which is the whole of what it is for: a program that must
  choose a file name no other *live* process will choose had nothing to build
  one from. It is not `mkstemp` and cannot be — §6.7.5.6 binds a file by
  **name**, so an exclusive creation is given up the moment the name is opened
  a second time to be written. The language server's scratch path carries it,
  so two servers sharing a `TMPDIR` no longer share a file.
- **The language server speaks a second protocol.** `pasls --mcp` answers the
  Model Context Protocol over standard input and output — the same binary, the
  same import resolution, the same compiler (ADR-0241). Two tools: `outline`,
  every name a source declares with its position and nesting, which answers for
  a file that does not compile; and `diagnostics`, what the compiler says about
  a source with its imports resolved. It serves an agent working on a checkout
  where the LSP side serves a person in an editor.
- **`PasLsp` gained `JsonlRead` and `JsonlWrite`**, the newline-delimited
  framing that transport uses, over the same reader the `Content-Length` one
  uses. A body holding a newline is refused rather than written, that framing
  having nothing else to say where a message ends.
- **`BindingType` has a third field, `writable`** — true exactly when the file
  a variable is bound to could be opened for writing (AP 6.4.3.4.7, ADR-0240).
  ISO/IEC 10206:1991 §6.4.3.4 NOTE 7 admits additional fields as an extension,
  so this needs no new syntax at all. It answers the question the language had
  only half of: `bound` tells a program about to *read* whether the file is
  there, and a program about to `rewrite` had nothing — a path that cannot be
  created stopped the program with no way to find out first.
- **Every writer in `lib/pasfile.pas` answers whether it wrote.**
  `WriteAllText`, `WriteLine`, `AppendLine` and `AppendText` were procedures
  that could not report failure and could fail; they are functions returning
  `boolean` now, and `CopyFile`'s boolean covers the destination as well as the
  source. **This changes their signatures**: a call that ignored the result no
  longer compiles.
- **`pascalc --dump-symbols`**, which writes every name a source declares —
  its kind, the position of the name, its length and how deeply it nests, one
  to a line (ADR-0239). It stops after the parse rather than after Sema, so it
  answers for a source the checker would reject and needs no `--import`, and it
  answers in Pascal's words rather than any protocol's numbers.
  `tools/pascalcc` passes any `--dump-` flag through and does nothing else with
  it; before this it refused them, on a stream a caller reading the answer was
  not reading.
- **The language server answers `textDocument/documentSymbol`** out of that
  flag (ADR-0239) — an editor's outline, with the declarations nested as they
  were written and the names carrying the case the *programmer* typed, which
  the server recovers from the document since the compiler's string pool holds
  only the folded spelling. The outline of a document that no longer compiles
  is unchanged, which is the point of stopping at the parse.
- **The language server finds a file's imports** by reading `.components`
  (ADR-0238). Before this the compiler was handed a module on its own and
  reported every name it imported as undeclared — 48 diagnostics for one
  library module and 21 171 for the compiler's own front end — so the server
  was useful on a single-file program and on nothing else. The rule is *take
  the entries before this file*: a sidecar beside the file answers first,
  otherwise the workspace named at `initialize` is searched for one naming it.
- **The language server negotiates the position encoding** and converts
  columns when it must (ADR-0237). An LSP `Position.character` counts UTF-16
  code units by default and this compiler counts bytes, so a line holding a
  character above U+007F was reported at the wrong column. The server now takes
  `utf-8` when a client offers it — the compiler's column is then already
  right — and converts to UTF-16 otherwise, echoing which in
  `positionEncoding`.
- **A language server**, `lsp/pasls.pas`, written in Afterschool Pascal and
  built by `lsp/build.sh` (ADR-0236). It speaks the Language Server Protocol
  over standard input and output and publishes `pascalc`'s diagnostics for
  every document a client opens or changes, so an editor shows them without the
  file being saved. `PASLS_COMPILER` and `PASLS_SCRATCH` configure it; both
  have defaults. It is not installed and it is not part of the compiler —
  `lsp/README.md` says what it does and does not do.

## [3.0.1] — 2026-08-28

**Nothing about the accepted language, the diagnostics or the command line
changed in this release, and that is the whole of what this file tracks.** The
same 427 diagnostic messages, character for character; no test case added,
removed or altered; no golden touched; no flag. A program that compiled under
3.0.0 compiles here, to the same IR.

What shipped is the compiler's own structure, and it is recorded because a
reader of `seed/` will notice it immediately.

### Changed

- **The compiler is three ISO/IEC 10206:1991 §6.13 program-components**
  (ADR-0233), where it was one source file: `selfhost/aptypes.pas` imports
  nothing, `selfhost/apfront.pas` imports it, and `selfhost/compiler.pas` holds
  the main-program-block and imports both.
  `selfhost/compiler.components` lists them in order and is what CMake, the
  harnesses and CI read. Building from source is unchanged — `cmake -S . -B
  build && cmake --build build` — and needs nothing it did not need before.
- **The committed seed is one module per component**: `seed/pascalc.ll` is
  replaced by `seed/aptypes.ll`, `seed/apfront.ll` and `seed/compiler.ll`, and
  the build matches `seed/*.ll` with a glob rather than naming a file. Anything
  outside this repository that named `seed/pascalc.ll` has to be updated; the
  documented build never did.

### Fixed

- `tests/checks/coverage.py` and `tests/checks/line_coverage.py` reported a
  **skip** where they meant a failure, so a compiler that could not translate
  its own source read as a missing `clang`. They now tell the two apart. No
  effect on the compiler; it is a gate that was failing in no direction.
- `tests/checks/variant-check` needed `bc`, which is not among the documented
  dependencies (`cmake`, `make`, `clang`, `git`, `python3` and nothing else).
  It now adds in the shell. No effect on the compiler; the build's dependency
  list is the claim it was falsifying.
- The `seed-is-current` CI job was written in bash, and a `run:` block in a
  container is `sh -e {0}` — so the job died on a syntax error at the tag,
  which is the only place it runs. Its check is now
  `tests/checks/seed_current.sh`, which a release runs by hand before tagging.
  No effect on the compiler; the seed it was meant to check is the one this
  source produces, three modules, verified.

## [3.0.0] — 2026-08-28

**Afterschool Pascal is a Pascal dialect, and the conformance modes are gone**
(ADR-0232). This is the breaking change of version 3 and it is larger than any
before it.

- `pascalc --std=<name>` is an **unknown option**. `tools/pascalcc --std=<name>`
  is accepted and ignored, so a build script written for version 2 still runs.
- **One diagnostic loses a sentence.** `succ` and `pred` given the wrong number
  of arguments said *"takes exactly one argument, or two under `--std=extended`"*
  and now say *"takes one or two arguments"*. It was the only message that named
  a flag, and both halves of it had stopped being true: there is no
  `--std=extended` to compile with, and the second argument is no longer
  conditional on anything.
- A `{ @std:iso7185 }` header comment is now an **ordinary comment**
  (ADR-0166 is withdrawn), and the `name.std` sidecar is gone from every
  harness, as is the second field of a `.components` line.
- **All 45 word-symbols are reserved.** ISO/IEC 10206:1991 §6.1.2 adds ten to
  ISO 7185's 35 — `otherwise`, `value`, `only`, `module`, `export`, `import`,
  `qualified`, `protected`, `bindable`, `pow`, and `restricted` besides — and a
  valid ISO 7185 program may use any of them as an ordinary identifier. Such a
  program no longer compiles and cannot be made to: 25 of the 172 ISO 7185
  cases in this repository were rewritten or deleted for it, and BSI's CONF005
  was written in 1982 to check exactly that a processor still accepts them.
- **The clause 5.1 a) compliance statement is withdrawn**, not reworded. A
  processor that cannot compile CONF005 does not comply with ISO 7185 at any
  level. `doc/implementation-defined.md` keeps everything else it said.
- **Five oracles retire with the surface they asked about**: the BSI Pascal
  Validation Suite (the only third-party corpus this project ever had),
  `difftest`, `dialect-containment`, `annex-b` and `reserved-words`. The front
  end is now guarded by goldens and by `tests/spec/` alone; `doc/sop.md` §7
  carries the gap and calls it the largest on the page.
- **A module built by an older release does not link.** The activation names
  carry a language tag (ADR-0119) and it is now fixed at `afterschool`, so an
  object holding `.extended.init` leaves the symbol undefined; `pascalcc`
  translates the linker's message.

Everything the two standards accepted, this language still accepts and still
means the same by — but for the ten word-symbols above. Every clause reading in
this repository is still true of it.

**One program that compiled and ran before now stops at run time**, and it is
what an upgrade can cost you: `read(f, s)` for a string variable at **end of
file** now reports an error and exits 1, where it used to answer with the
null-string and carry on. ISO/IEC 10206:1991's Annex D, D.97, makes reading at
end-of-file an error whatever is being read, and this compiler already reported
it for a char and for the numeric forms — the two string forms of §6.10.1 e)
and f) reached neither check, so one procedure gave two answers to one clause.
End of **line** is unchanged: NOTE 6 and NOTE 7 give it the null-string, and
still do, `readstr` included.

One entry is a **fix to something this release itself introduced**: the two
tree dumps stopped the compiler on any program declaring a fallible-type, for
three days, with every gate green. The rest only accept more.

### Added

- **`utf8(n)`, a text-type** (`--std=afterschool`, AP 6.4.15). What a program
  holds when it means the characters rather than the octets. The capacity is
  in **bytes** and `length` counts **elements**, an element being an extended
  grapheme cluster — so a family emoji joined by zero-width joiners is one
  element of eighteen bytes, and `length(t)` and `t.capacity` are in different
  units.

  A value is put into Unicode normal form C where it is constructed, so **two
  spellings of one character are one value**: `'{composed}'` written with a single
  `é` and `'{decomposed}'` written with `e` and a combining acute compare equal, and
  the comparison is a byte comparison with nothing decoded. Assignment from a
  string or a char, comparison, `length`, `capacity` and `write` (whose field
  width pads to a count of elements) are all there. Ill-formed UTF-8 and a
  value too long for the capacity are errors that stop the program, as a value
  outside a subrange has always been.

  `+` joins two texts and is **not** a byte concatenation: `'he' + '́llo'`
  is six bytes, not seven, because the combining acute composes with the `e`
  across the join, and the result equals `'héllo'`. `for g in t do`
  walks the elements — joining them back together gives the original. Still to
  come: case mapping, case folding and grapheme-indexed slicing.

- **`lib/dialect/pasunicode.pas`**, the two things the text-type leaves to a
  library. `ToText(s, var t)` **reports** where an assignment to a `utf8(n)`
  stops the program — `errSyntax` for bytes that are not UTF-8, `errFull` for a
  value whose normal form will not fit, and nothing assigned unless it
  succeeds. That is what a program reading bytes it did not write needs, where
  the assignment's rule is right for a program's own literals. The rest is a
  **scalar view** — `NextScalar`, `ScalarCount`, `Encode` — because an element
  of a text is a grapheme cluster and a program sometimes wants the code points
  under one: a family emoji is one element and five scalar values.

  `Fold`, `Upper` and `Lower` are full Unicode case operations, and the first
  is the one worth knowing about: **folding is not lowercasing**. `Fold(a) =
  Fold(b)` asks whether two values are the same but for case, and comparing two
  lowercased values answers it wrongly — the German sharp s lowercases to
  itself and folds to `ss`, so `straße` and `STRASSE` are equal under folding
  and unequal under lowering. All three are *full* mappings, so one character
  may become two and the destination's capacity is checked; a mapping that
  depends on a language or a context is declined, so Greek's final sigma is not
  special-cased and there is no Turkish `I`.

  `char` and `string(n)` are unchanged in all three modes, and `utf8` is a
  required identifier a program may shadow. The Unicode version behind it is
  stated in `doc/implementation-defined.md` §2.7.

- **`--dump-predicates`**: what each of the compiler's type-classifying
  predicates answers about a type of each kind. It exists for the
  `predicate-kinds` gate, which is what three defects in three increments
  argued for — a `case … of` with a constant left off has been checked since
  ADR-0124, and all three of those lived in a *predicate* instead, where
  nothing looked.

- **`--dump-layout`**: compile as usual, then write the size, alignment and
  field offsets of every record the source defines. It is the compiler's half
  of a check on a foreign struct declaration — a source states what C struct it
  believes a record to be, in a comment (`@cstruct`, `@cfield`), and a C
  compiler holding the real header judges the two together. A wrong field list
  now fails the build naming the field, where it used to be silent.
- **`PasFS.Info`**: a file's size, modification time and kind, together,
  answering `FileInfo ! ErrorCode` — `errAbsent` when nothing is there, told
  apart from `errIO`. It is the one routine in the library that deliberately
  does *not* cross a struct.
- **A record may be a `var` parameter of an `external` declaration** under
  `--std=afterschool`, which is how a struct the *caller* owns crosses:
  `procedure ExtStat(path: string; var buf: StatBuf); external 'stat'`. There
  is nothing new to spell — that heading was always writable and simply
  refused — and nothing was lowered for it, because this compiler already lays
  a record out the way C lays out a struct. A record qualifies when it has no
  variant part and every field, at any depth, is `char`, `integer`, `int64`,
  `real`, a fixed array of one of those, or a record of them; the diagnostic
  names the offending field rather than the record. `packed` is accepted and
  has no effect, so it is not a way to spell C's `__attribute__((packed))`. By
  value a record is refused in both directions. **You write the field list
  yourself and nothing checks it against the header** — the same unchecked
  claim as every `external` signature.
- **`PasDir`**: reading a directory — `Open`, `Next`, `Close` and `List`, with
  the `DIR *` owned as a handle, so it is closed by leaving the block that
  declared it. `Next` writes into a string of the caller's own capacity and
  answers `errFull` for a name too long for it, the length being checked by the
  side that holds the pointer rather than by the copy. There is deliberately no
  entry *kind*: `d_type` is not POSIX, so a caller composes `PasFS.Info`.
  `List` leaves out `.` and `..`, so an empty vector means an empty directory.
  It supersedes `PasProcess.CaptureLines('ls -1 dir', names)`, which forked a
  shell and could not tell an empty directory from a failed `ls`.
- **An `external` function may answer an optional of a record** under
  `--std=afterschool`, which is how a struct the *callee* owns comes back:
  `function GmTime(var t: int64): OptTm; external 'gmtime'`. A null address is
  the absent value; any other address yields a **copy**, made where the call
  occurs, so no C pointer ever becomes a Pascal value and a later call moves
  the callee's storage without moving what you were given. The record must be
  one that already crosses — the same field rule, for the same reason — and the
  copy is as long as the record you declared, so a record naming a *prefix* of
  the struct's members reads the prefix. `readdir`, `gmtime` and `localtime`
  are declarable. A record result **by value** is still refused and its
  diagnostic now names `?` as the remedy, where it used to say only that
  `integer`, `int64` and `real` cross the boundary.
- **`pasx_record_probe`** in the runtime: a struct carrying one member of every
  kind a foreign record may hold, filled with values no other member could
  hold. A program declaring the matching record and calling it learns whether
  this compiler and its C compiler agree about offsets on *its* target.
  **`pasx_record_answer`** is its counterpart in the other direction: it
  answers the address of one static object that every call overwrites, so a
  program can see for itself that what it received was a copy.
- **`owned ^T`** under `--std=afterschool`: a pointer that owns the variable it
  identifies. The variable is disposed when the pointer's own variable ceases
  to exist, and everything owned inside it — a file, a handle, another owned
  pointer — is released with it, so a list or a tree is freed by leaving the
  block that owns its root. A second `new` over the same variable releases the
  first, and `dispose` remains the early release. It cannot be copied: no
  assignment, no value parameter, no function result, no comparison but with
  `nil`, so what a routine is lent is a `var` parameter and a traversal is
  recursive rather than a loop. **This closes a leak, not a convenience**: a
  variable created by `new` exists in no activation, so nothing released what a
  heap record held unless the program said `dispose` — under a 64-descriptor
  limit, a loop allocating one such record per iteration ran out at the 62nd.
  `owned` is not reserved; a program may still have a type of that name.

- **`take`** under `--std=afterschool`: the move. `take(v)` empties an owned
  pointer variable and yields what it held, and may stand only as the whole
  right side of an assignment to a variable of that type. It is what makes an
  owned chain a usable one — without it `head := fresh` is a copy, so a chain
  could be pushed at its far end and read and nothing else, with no operation
  in constant time at all. `head := take(head^.next)` is a complete removal of
  the first element. Like `int64`, `argcount`, `exit` and `try` it is a
  required identifier, so a program with a `take` of its own keeps it.

- **`PasList`** in `lib/dialect/`: a chain of `string(255)` the declaring block
  owns, and **the only container here with no `Free`** — the head is an
  `owned ^`, so the chain is disposed when the variable holding it ceases to
  exist and there is nothing for a caller to forget. `ListPush`, `ListPop`,
  `ListPeek` and `ListEmpty` are constant time; `ListLen`, `ListAppend`,
  `ListGet`, `ListDrop` and `ListReverse` are O(n) and recursive, because the
  rule that stops a second pointer from dangling also stops one from walking.
  A program wanting an index still wants `PasStrVec`.

- **`try`** under `--std=afterschool`: `try(x)` is the value of a fallible `x`
  where it succeeded, and where it did not it assigns the cause to the
  enclosing function's result and terminates that activation — so error
  handling in this dialect is now three constructs that fit together, `T ! E`,
  `exit` and this. Everything terminating an activation entails happens on the
  way out: the armed statements run and the block's files and handles close.
  The enclosing result need not be a fallible type, only something the cause is
  assignable to; the operand is evaluated once; a `try` may stand only in a
  function, and not in a deferred statement. `try` is a required identifier and
  shadowable, so a program that declares its own keeps it, and under either
  conformance mode the answer is *unknown function 'try'*. AP 6.8.9, ADR-0178.
  `tests/dialect/try.pas`.
- **`exit`** under `--std=afterschool`: `exit` terminates the activation of the
  block it stands in, and `exit(e)` first assigns `e` to that block's function
  result — the guard clause, which neither standard has and every widely used
  Pascal does. It is not `halt`: the armed statements run, the block's files
  and handles close, and in the main program the module finalizations still
  run. `exit` is a required identifier and shadowable, so a program that
  declares its own keeps it; a deferred statement may not contain one. Under
  either conformance mode the name is nobody's and the answer is *unknown
  procedure 'exit'*. AP 6.7.5.9, ADR-0177. `tests/dialect/exit.pas`.

- **Fallible types** under `--std=afterschool`: `T ! E` denotes the result
  record a module used to write per payload type — tag `ok`, value `val`,
  reason `cause` — so a module writes `IntResult = integer ! ErrorCode`
  instead of five lines, and the field names are the same everywhere.
  Assigning a value of either side chooses the outcome; reading the other arm
  stops the program; the tag cannot be assigned, read into, or passed as a
  variable parameter. AP 6.4.13, ADR-0176. `tests/dialect/fallible.pas`.

- **`lib/dialect/`'s six result records are now six one-line types**, and the
  failing side is spelled `cause` in every module. It had three spellings, and
  `PasProcess.RunResult.code` was a *success* payload where `r.code` elsewhere
  was the `ErrorCode`. Callers read `r.val` and `r.cause`.

- **`defer S`** under `--std=afterschool`: a statement armed where it is
  written and executed when the statement-sequence it stands in is completed,
  or when the activation terminates — a `goto` out of the block and `halt`
  included. Several armed in one sequence run in the reverse of the order they
  are written, and before the block's files and handles are closed. A deferred
  statement may not contain a label, a `goto` or another `defer`. `defer`
  reserves nothing: a program that declares one keeps it. AP 6.9.3.11,
  ADR-0175. `tests/dialect/defer.pas`.

- **Handle-types** under `--std=afterschool`: `type Dir = handle external
  'closedir'` is a foreign address this program owns, with a file variable's
  rules — no copy, released when the variable dies, on `goto`, `halt` and
  `dispose` — and three of its own: assignment from an external function of
  its type, comparison with `nil`, and lending to an external as a value
  parameter, where an empty handle is a run-time error. AP 6.4.12, ADR-0174.
  `tests/dialect/handle.pas`.

- **`argcount` and `argument(k)`** under `--std=afterschool`: the program's
  command line as a list, two required identifiers that §6.1.3 makes
  shadowable. `argument(k)` outside `1..argcount` is a run-time error. Under
  the conformance modes the names are nobody's, as `int64` is (Annex B).
  AP 6.7.6.10, ADR-0173. `tests/dialect/arguments.pas`.

- **`lib/passtrvec.pas`**: a growable sequence of strings — `PasVector`'s
  interface under `SVec` names, with `SVecIndexOf`, a stable `SVecSort`,
  `SVecJoin` and `SVecSplit`. `tests/extended/lib_strvec.pas`.

- **`lib/dialect/pasprocess.pas`**: `Run` a command through the shell and get
  its exit code, `ExitCode`, `Sleep`, `Seconds` and `CpuSeconds` — four libc
  names through `external`. `tests/dialect/lib_process.pas`.

- **`lib/dialect/passtream.pas`**: buffered streams over `fopen` as a
  handle-type — `OpenRead`, `OpenWrite`, `OpenAppend`, `Close`, `WriteText`,
  `WriteLine`, `ReadLine`, `Flush`. A dialect program can create a file
  through the library now, which `PasIO` could not. `tests/dialect/lib_stream.pas`.

- **`PasProcess.Capture` and `CaptureLines`**: a command's standard output
  into a string or onto a `StrVec`, with its exit code, through `popen` as a
  handle. A directory listing is `CaptureLines('ls -1 dir', names)`.

- **`lib/pasfile.pas`**, the conforming layer's seventh module: whole files
  by name — `FileExists`, `LineCount`, `ReadLine`, `ForEachLine`,
  `ReadAllText`, `WriteAllText`, `WriteLine`, `AppendLine`, `AppendText`,
  `CopyFile`. Every reader answers false for a file that is not there, which
  `binding(f).bound` now makes possible without leaving the standard.
  `tests/extended/lib_file.pas`.

- A **value parameter of a `packed array [1..n] of char`** takes any string
  expression and pads it, under `--std=extended` and `--std=afterschool`.
  `p('abc')` for a formal of capacity 5 hands over `'abc  '`, which is what
  §6.7.3.2's assignment-compatibility and §6.4.6's padding paragraph require
  and what `f := 'abc'` had always done. An actual longer than the capacity
  stops the program (§6.4.6 c)). ISO 7185 is unaffected — it has neither rule
  — and refuses the call as two incompatible types, which is what its
  diagnostic now says.
- **`index` folds in a constant-expression**, so §6.3.2 — the standard's own
  example of a constant-definition-part — compiles. Its closing line is
  `hex_alpha = hex_string[index(hex_string,'A')..index(hex_string,'F')]`, and
  a constant-expression is what an array bound and a subrange bound are.

- **A string-valued constant-expression folds**, under `--std=extended` and
  `--std=afterschool`. `const k = 'ab' + 'cd'`, `substr('abcd', 2, 2)`,
  `trim('ab  ')` and the six relational operators and functions over strings
  are constant-expressions and were refused as *not a compile-time constant*.
  §6.8.2 restricts one only by requiring it to be nonvarying, and none of
  these varies.

- **A real-valued constant-expression folds**, under the same two standards.
  §6.3.2's own example opens `unity = 1.0; third = unity/3.0`, and that second
  line did not compile; nor did `pi = 4 * arctan(1)`, `trunc`, `round`,
  `sqrt`, `sin`, `cos`, `ln`, `exp` or `arctan` anywhere a constant is wanted.
  All of them do now, and so do the arithmetic and relational operators over
  reals.

  Two consequences a program can see. **The accuracy of a folded expression is
  the accuracy of the same operation at run time**, because the fold calls
  what the emitted code calls — §6.8.2's NOTE 2 requires an implementation to
  say this, and `doc/implementation-defined.md` now does, along with the half
  that cannot be promised across a cross-compile. And an error the clause
  names — a zero divisor, `ln` of a value that is not positive, `sqrt` of a
  negative one, a negative base of `**`, `trunc` or `round` out of integer
  range, overflow — is now a **compile-time diagnostic** where a constant
  commits it, where it used to be a refusal to fold.

  ISO 7185 is unaffected: §6.3 there admits a `constant` and not an
  expression, so no ISO 7185 program has one of these to fold.

### Changed

- **`binding(f).bound` now says whether the file is there.** A variable is
  bound to an external entity when the entity exists, asked whenever `binding`
  is called — false for a name nothing is at, true for the same variable once
  `rewrite` has created the file. ISO/IEC 10206:1991 §6.7.5.6 makes the
  binding implementation-defined and NOTE 2 makes `binding` the test of its
  success, so a conforming program can ask before `reset` stops it. A program
  that does not ask behaves exactly as before: the name is kept and the
  unchecked `reset` stops with *cannot open for reading* (ADR-0172,
  `doc/implementation-defined.md` E.16). The runtime's departure from ISO C is
  five names, `access` being the fifth, and `runtime-isoc` now strips non-ISO
  headers before it looks.

- A **record-value's variant-part-value must name the tag field** its variant
  part declares: `shape[n: 1; case kind: box of [w: 6; h: 7]]` and no longer
  `case box of`. §6.8.7.3 requires it twice over, and the optional
  tag-field-identifier in the grammar is for a variant part whose selector has
  no identifier at all — which is still written without one.

### Fixed

- **A handle-valued `external` function written bare escaped AP 6.4.12.2 in
  both directions**, under `--std=afterschool`. `t := make` for a
  parameterless one was refused where `t := make(0)` is accepted; and the
  clause's other sentence — that such a call may stand nowhere else — was not
  applied to that spelling at all, so `if make = nil then …` compiled, ran,
  exited 0 and **leaked the handle**, which is the one thing the type exists
  to prevent. §6.8.5 makes a function-designator's parameter list optional and
  the processor implemented both sentences from a node kind. ADR-0180.
  `tests/dialect/handle_bare_call.pas`, `tests/dialect/handle_errors.pas`.

- **A parameterless function written bare could not be a value parameter** of
  a structured type. `take(mk)` was refused with *argument 1 of 'take' is
  Point and needs a variable* where `take(mk(0))`, `q := mk` and `mk.x` were
  all accepted — §6.8.5 makes a function-designator's actual-parameter-list
  optional, so the bare name *is* the call, and the check tested the node kind
  instead of the construct. Extended Pascal only: ISO 7185 §6.6.2 gives a
  function no structured result to pass. ADR-0179.
  `tests/extended/value_param_bare_call.pas`.

- **`--dump-ast` and `--dump-sema` stopped the compiler** on any program
  declaring a fallible-type: `DumpTypeExpr` had no arm for the kind, and a
  case-statement whose selector matches no label halts. Present since fallible
  types landed three days earlier, invisible to every oracle — no dump case had
  one, `difftest` skips a dialect source, and the coverage sweep drives
  `--dump-all` over the corpus without reading what it exits with.
  `tests/dumps/fallible.pas`.

- **A procedural parameter whose own formal is a variable-string value
  parameter can be called.** `procedure each(procedure visit(l: string(12)))`
  compiled and then clang refused the module: the indirect call's type was
  written by a copy of the defining side's writer that had not learned
  ADR-0115's pair (nor ADR-0125's slice), so three arguments were passed to a
  type naming two. One writer now serves both sides.
  `tests/extended/procparam_string.pas`.

- `doc/implementation-defined.md`'s E.29 said a Boolean written with an
  explicit width is "truncated from the left", which names the wrong end.
  §6.10.3.6 writes "the first through TotalWidth-th characters", so `true:2`
  is `TR` — which is what the compiler has always written and what
  `tests/extended/fieldwidth.pas` has always checked.

## [2.1.0] — 2026-08-23

**Two programs that compiled in 2.0.0 do not compile in 2.1.0, and one that
compiled prints different characters.** Each was a defect — a program the
standard already forbade, or output the standard already specified otherwise —
so no deprecation is offered and none is available. They come first because
they are what an upgrade can cost you:

  1. a `protected` variable passed to a **variable conformant array** parameter
     is now refused. It was written through, silently, and the program exited
     0;
  2. a `for` statement whose control variable is **bindable** is now refused;
  3. a constant naming a **structured component** of another constant now reads
     that component. It read all-zero, with no diagnostic.

The rest is the same work's other half: reals written at an exact halfway value
now round the way the clause prescribes rather than the way C's `printf` does,
and two functions that could not be written before now can.

Six of the eight entries below come from the fourth
`.claude/skills/langspec-audit/` run (ADR-0168, ADR-0169, ADR-0170); the other
two were found while probing the clauses those raised. Both standards remain
complete and the accepted language is otherwise unchanged — no new syntax, no
new flag, no change to `--std`.

### Changed

- **A program that passed a `protected` variable to a variable conformant array
  parameter no longer compiles.** ISO/IEC 10206:1991 §6.9.4 b) makes an actual
  passed to an unprotected formal variable parameter a threat, and §6.7.3.7.3
  says a variable conformant array's actual is one. That arm never asked, so
  `protected` was defeated silently — the callee wrote the caller's variable
  and the program exited 0. The same held through a record field (§6.9.4 h))
  and when a *protected* conformant array was handed on to an unprotected one.
  The diagnostic is the one an ordinary var parameter already gave.

- **A `for` statement over a `bindable` control variable no longer compiles.**
  §6.9.3.9.1: "The control-variable shall possess an ordinal-type **and shall
  be nonbindable**." Only the first half was asked.

- **A constant naming a structured component of another constant now has that
  component's value.** ISO/IEC 10206:1991 §6.8.8.1 gives a constant-access "the
  value and type … of the indexed-constant, field-designated-constant, or
  substring-constant". A component that was a *scalar* was right; one that was
  an array or a record read as all-zero, with no diagnostic:

  ```pascal
  const grid = outer[1: inner[1:1; 2:2; 3:3]; 2: inner[1:4; 2:5; 3:6]];
        row  = grid[2];
  ```

  `row[i]` printed 0 where `grid[2][i]` printed 4, 5, 6 — in one program.
  **A program that reads such a constant can print different characters than it
  did in 2.0.0**, and there is no spelling under which the old zeros were
  right. A string component, a set component and `const b = a` were all correct
  before and are unchanged.

- **A real written at an exact halfway value rounds away from zero, not to
  even.** ISO 7185 §6.9.3.4.2 and ISO/IEC 10206:1991 §6.10.3.4.2 do not say
  "rounded" and leave the direction open — they prescribe `eWritten := abs(e) +
  0.5 * 10.0 pow(-FracDigits)` and then truncate. This runtime handed the job to
  C's `printf`, which rounds half to even, so every exact halfway value came out
  one unit low half the time and said nothing: `write(0.125:6:2)` wrote `0.12`
  where the clause requires `0.13`, `write(2.5:4:0)` wrote `2.` against `3.`,
  and `write(1.25:8)` wrote ` 1.2E+00` against ` 1.3E+00`. **A program that
  writes reals can print different characters than it did in 2.0.0.** Only at
  exact halfway values — a value that is not one is unaffected, and so is every
  value your program computed rather than wrote as a literal, unless it landed
  on a half exactly.

- **A negative value that rounds away to nothing is written without a minus.**
  The same clause writes the sign "if `(e < 0.0)` and `(eWritten > 0.0)`", and
  `eWritten` is the value *after* rounding — so `write(-0.000001:0:2)` is
  `0.00`, not `-0.00`, and the field is four characters rather than five,
  MinNumChars not counting a sign that is not there. Negative zero is written
  without one for the other half of the same condition, `-0.0 < 0.0` being
  false, where `printf` writes the sign bit.

### Fixed

- **`new(p)` counts as writing to a result variable.** ISO/IEC 10206:1991
  §6.9.4 e) makes `new(p)` a threat to `p` — §6.7.5.3 says the same thing the
  other way, since it "shall attribute to p" the identifying-value — and §6.7.2
  requires a function-block to contain "at least one statement threatening" its
  result variable. That entry was missing from the list, so a constructor was
  refused with *never writes to its result variable*:

  ```pascal
  function cons(v: integer; rest: link) = res: link;
  begin new(res); res^.value := v; res^.next := rest end;
  ```

  There was no workaround — the result is a pointer, so there is nothing to
  assign it but `new`.

- **A function may fill its result variable through a conformant array
  parameter.** The other direction of the same missing rule as `new(p)` above:
  §6.7.2 asks §6.9.4 whether the result was threatened, and with b) unapplied
  to conformant arrays a function whose only writer was `fill(res)` was refused
  with *never writes to its result variable*.

- **A real near the bottom of the range is written accurately.** Not a
  regression from any release; found while fixing the rounding above, and worth
  naming because implementing the clause's scaling step literally reintroduces
  it. `1e-320` is a denormal, and dividing by `10.0 pow (-320)` — which is not a
  number this format holds — writes it as `0.000000000000E+00`. The digits now
  come from the value's exact decimal expansion, so no division happens.

## [2.0.0] — 2026-08-22

**The release where the default standard changes.** A source compiled with no
`--std=` flag is ISO/IEC 10206:1991 rather than ISO 7185. The two languages are
not nested — Extended Pascal reserves thirteen word-symbols that a conforming
ISO 7185 program may use as ordinary identifiers — so this is the change the
major version is for: an ISO 7185 program with a field called `value` now needs
`--std=iso7185`, which is kept, and not deprecated. Almost every affected
program says so loudly, and the whole silent surface is one construct, measured
across all 812 BSI programs and named under **Changed** below.

Four conformance fixes change what an already-valid program *does*, and each is
spelled out with its old and new behaviour. Two more change what compiles at
all: a `char` given a string value emitted IR that `clang` refused, and an
initial-state-specifier written after a discriminated schema was checked and
then discarded, leaving a local variable reading its own stack.

Both standards remain complete. What moved is which of them you get by
default — and, with `@std:`, that a source can now say for itself.

### Changed

- **`--std=extended` is now the default.** A source compiled with no `--std=`
  flag is ISO/IEC 10206:1991 rather than ISO 7185. `--std=iso7185` still
  selects the older standard and is not deprecated — it keeps its corpus, its
  clause 5.1 a) compliance statement and its own oracle.

  **Read this before upgrading.** The two standards are not nested: Extended
  Pascal reserves thirteen word-symbols (`value`, `module`, `otherwise`,
  `restricted`, …) that a conforming ISO 7185 program may use as ordinary
  identifiers. An ISO 7185 program with a field called `value` now needs
  `--std=iso7185`. Almost every affected program says so loudly — a reserved
  word where an identifier belongs is a syntax error — with **one** exception
  measured across the whole corpus: a field width of zero. ISO 7185 §6.9.3.1
  requires a width "greater than or equal to one" and ISO/IEC 10206:1991
  §6.10.3.1 requires "greater than or equal to zero", so `write('y':0)` changes
  from trapping to printing nothing, silently. That is the entire silent
  surface of this change; everything else is a diagnostic.

  All 812 programs of the BSI Validation Suite were compiled both ways to
  measure this: 811 compile identically, and the one that does not is
  `CONF005` — the program BSI wrote in 1982 to check that a conforming
  processor still accepts `module` and `restricted` as identifiers, and the
  reason `--std=iso7185` was kept rather than retired.

- **`round(x)` computes a different value for a few arguments**, under every
  `--std`. ISO 7185 §6.6.6.3 and ISO/IEC 10206:1991 §6.7.6.3 define round by
  *equivalence* — "if x is positive or zero, round(x) shall be equivalent to
  trunc(x+0.5); otherwise, round(x) shall be equivalent to trunc(x-0.5)" — and
  this compiler emitted a round-half-away-from-zero instruction. The two agree
  at every halfway point, including all four of the clause's own examples, and
  disagree wherever x ± 0.5 is inexact, because the addition itself rounds:
  `round(0.49999999999999994)` was 0 and the clause requires 1. If your program
  depended on the old answer it depended on a defect, and `trunc(x + 0.5)`
  spells the old behaviour where you want it back.

- **`succ(x, k)` and `pred(x, k)` now stop the program when the result is not a
  value of the type.** The sum was computed at the width of the ordinal and the
  range check read it afterwards, so `succ(maxint, 2)` wrapped to -2147483647
  and ran on; `succ(maxint)` had always reported. Annex D.65 makes it an error
  either way, so a program relying on the wrap was relying on an unreported one.

- **A result-variable-specification may no longer be spelled like a
  parameter.** `function f(n: integer) = n: integer` has two defining-points of
  `n` for one region, which §6.2.2.7 forbids, and it was accepted and silently
  meant something else — the result variable won inside the block, so the body
  wrote the result and the argument was unreadable. Rename one of the two.

- **A restricted or bindable type is no longer accepted as a field of a variant
  part**, under `--std=extended` and `--std=afterschool`. ISO/IEC 10206:1991
  §6.4.3.4 says "a variant-denoter shall not contain a type-denoter denoting
  either a restricted-type or the bindability that is bindable or denoting a
  structured-type having any component whose type-denoter is not permissible as
  a type-denoter contained by a variant-denoter", and this compiler read none of
  that sentence. It is a violation and not an error — Annex D's D.3 for the
  clause is the discriminant-selector rule — so clause 5.1 e) obliges a
  processor to report it and refuse to run the program. **A program that
  compiled before will now be rejected**, and the fix is to move the field out
  of the variant part: the restriction is on the variant-denoter and on nothing
  else, so the same type in a record's fixed part is as legal as it ever was.
  The two messages are `a restricted type cannot be a field of a variant part`
  and `a bindable type cannot be a field of a variant part`. `--std=iso7185` is
  untouched: neither word-symbol exists there.

- **The message for binding something nonbindable names a different rule.** It
  was `only a variable of a bindable type may be bound`; it is now
  `only a variable whose type-denoter says bindable may be bound`, because
  bindability is not a property of the type — `type bt = bindable text` hands
  it on without making a type distinct from `text`. The four procedures and
  functions of §6.7.5.6 and §6.7.6.8 share the one message.

### Added

- **A bindable *field* or *array component* may now be bound.** `bind(r.log, b)`
  over `record log: bindable text end`, and `bind(pool[i], b)` over
  `array [1..4] of bindable text`, were both refused — with a message naming
  the container rather than the thing asked about, `'r' is not bindable`.
  ISO/IEC 10206:1991 §6.7.5.6 and §6.7.6.8 ask whether "the variable-access f"
  possesses the bindability that is bindable, and §6.4.3.4 and §6.4.3.5 give a
  field and an array's component the bindability of their own type-denoter.
  Under `import i qualified` there had been no workaround.

- **A `string` value parameter now takes any string expression.** `procedure
  p(s: string)` accepted only a variable produced from the schema, so a literal,
  a char, a constant, a concatenation and a function result were all refused —
  including ISO/IEC 10206:1991 §6.11.6's own worked example, `record
  event('event-module initialization')`. The clause is §6.7.3.2, which asks for
  "a type having an underlying-type that is a string-type or the char-type".
  The formal's capacity is now the **length of the value** rather than the
  capacity of the variable it came out of, which is the same clause's next
  sentence; a program that assigned into such a formal beyond the value's length
  was relying on the old reading and will now stop.

- **A qualified name may be an actual procedural or functional parameter.**
  `call(i.p)` was refused with "must be the name of a procedure or function".
  §6.7.3.4 asks for a *procedure-name*, and §6.7.1 spells one as an optional
  interface qualifier and an identifier. Under `import i qualified` there had
  been no workaround at all.

- **`succ(x, k)`, `pred(x, k)` and `length` may appear in a
  constant-expression**, so they may appear in an array bound and a subrange
  bound: `packed array [1..length(greeting)] of char` compiles. §6.8.2 makes
  every required function nonvarying except `eof`, `eoln`, `empty`, `position`
  and `LastPosition`. Eight are still refused — `trunc`, `round`, `sqrt`,
  `sin`, `cos`, `ln`, `exp`, `arctan` — because a real constant is carried here
  as the text that was written and never converted to a number; they now say so
  rather than reporting the expression as not constant, and
  `doc/implementation-defined.md` §6 records it as a restriction.

- **A source can name its own standard.** A comment before the program heading
  containing `@std:iso7185`, `@std:extended` or `@std:afterschool` selects the
  language that source is written in, so a file that needs a particular
  standard no longer depends on every caller passing the right flag:

  ```pascal
  { @std:iso7185 }
  program legacy(output);
  var value: integer;
  begin value := 7; writeln(value:1) end.
  ```

  It is read before the lexer runs, because the standard decides which words
  are reserved. Only the header counts — after the first token of the program
  it is an ordinary comment — and an explicit `--std=` still wins, so a build
  system that names a standard gets what it asked for. A misspelt name is
  reported rather than ignored.

  `pascalcc` no longer has a `--std` default of its own; it passes through what
  it was given, so the compiler's default and the annotation both work through
  it.

### Fixed

- **A string value may be assigned to a `char` variable.** `c := s[2..2]`,
  `c := v` over a one-character `string`, `c := substr(s, 4, 1)`, a
  concatenation, a `trim` and a function result were all accepted by the type
  rules and then miscompiled: ten spellings emitted invalid IR, so the author
  saw an LLVM error naming a temporary file they never wrote, and the substring
  form silently stored `chr(0)`. ISO/IEC 10206:1991 §6.4.5 d) makes a
  string-type and the char-type compatible and §6.4.6 f) names "a string-type
  **or the char-type**" as the destination, so all of them are legal. The
  null-string stores a space, which is §6.4.6's padding rule at a capacity of
  one, and a value longer than one character stops the program. `--std=iso7185`
  is untouched — it has no such rule and refuses the assignment outright.

- **An initial-state-specifier is honoured after a discriminated-schema.**
  `var t: string(4) value 'jk'` parsed, checked its value, and then discarded
  it; only the type-name spelling, `var t: s4 value 'jk'`, worked. §6.4.1 offers
  the specifier after any of the four bases a type-denoter may have, a
  discriminated-schema included. A **global** was left zeroed; a **local** was
  left reading its uninitialised frame slot, so `writeln(t)` printed several
  kilobytes of stack. If you wrote this declaration and worked around it with an
  assignment at the top of the block, that assignment is now redundant rather
  than load-bearing.

- **A clause number that names nothing, in seven places.** `§6.8.3.11` was
  glossed as "the non-local goto" in `CLAUDE.md`, `runtime/pasrt.c`, the
  roadmap, a test and two records — but ISO 7185 numbers the goto-statement
  `§6.8.2.4` and stops its structured statements at `§6.8.3.10`, while Extended
  Pascal uses `§6.8.3.x` for *Operators* and numbers the goto `§6.9.2.4`. Every
  site that can be corrected now names both. A new check,
  `clause-citations`, asks of all 7382 clause citations in the tree whether
  each names a clause at all; it catches a number that names nothing, and
  cannot catch one that names the wrong clause of the right shape.

- **A wrong clause number, in four places.** ISO 7185 numbers Record-types
  §6.4.3.3 and ISO/IEC 10206:1991 numbers it §6.4.3.4, Extended Pascal having
  inserted String-types above it — so the bare "§6.4.3.4" that `README.md`,
  `doc/implementation-defined.md`, `tests/bsi/expected.tsv` and both front ends'
  comments gave as the clause permitting a file in a variant part pointed at
  **Set-types** whenever an ISO 7185 program was the subject. Each now names
  both numbers. Nothing about the compiler's behaviour changes.

## [1.8.0] — 2026-08-22

**The release where the platform lock got a scoped way out.** `pascalc` takes a
`--target=`, and CI builds and runs the whole corpus on aarch64 — so what was an
argument that the port would work is now a machine that ran it. The two things
that made the rest of a port guesswork are measured rather than estimated: the
frame layouts are compared against LLVM's for every admitted target on every
run, and the runtime's distance from ISO C is four named functions with a check
that keeps it four.

**Nothing about compiling for x86-64 changes.** A target belongs on the admitted
list only once the hand-written layout rules have been compared against LLVM's
for it, and that does not yet hold for a 32-bit machine — so the list is two
entries long on purpose.

The rest is oracles. An adversarial reading of both standards by readers who had
not seen the reasoning found no misreading and five defects in the machinery
around the readings; one of them was a diagnostic that had been false since the
last release.

### Added

- **`pascalc --target=` and `pascalcc --target=`.** Which machine the emitted
  module states it is for: `x86_64-pc-linux-gnu` (the default) or
  `aarch64-linux-gnu`. `pascalcc` hands it to both halves, so
  `pascalcc --target=aarch64-linux-gnu -c hello.pas` produces an aarch64 object
  on an x86-64 machine given a cross toolchain. Any other target is **refused**,
  naming what is admitted: a target belongs on that list only once this
  compiler's own layout rules have been compared against LLVM's for it, which
  does not hold for a 32-bit machine.

- **`AFTERSCHOOL_PASCAL_TARGET`.** Points a whole run of `pascalcc` at one
  target, the way `AFTERSCHOOL_PASCAL_OPT` points one at an optimisation level.
  An explicit `--target=` still wins. It is what lets a test harness — or CI —
  compile a corpus for a machine without a flag on every invocation.

- **Ten cases pinning what each conformance mode says about each dialect
  construct**, one per construct per mode, and a check that the dialect
  specification's Annex B states the same messages. Under `--std=iso7185` and
  `--std=extended` a program using `external`, `?`, `array of T`, `a[i..j]` over
  an array, or `int64` is refused, and now with a golden behind each refusal.
  One correction fell out of writing them: the two modes do **not** say the same
  thing about `a[i..j]` over an array — ISO 7185 complains about the `..` token,
  Extended Pascal about the type.

- **A check that the runtime stays close to ISO C.** `runtime/pasrt.c` uses the
  standard library and four names beyond it — `_setjmp` and `_longjmp` for the
  non-local `goto`, `fmemopen` and `open_memstream` for `readstr` and
  `writestr` — and a fifth cannot be added without an entry and an argument.
  Nothing about the compiled program changes; this bounds what a port to
  another C library has to supply.

### Changed

- **The compiler accepts twenty-four command-line arguments, up from twelve,
  and says so when given more.** Twelve was exactly what a program with four
  separately translated components needs, so adding one flag pushed the `-o`
  file name off the end — where it was silently dropped and reported as
  `-o needs a file name`, blaming the wrong argument. Going over the limit now
  produces `pascalc: more than 24 arguments` and a non-zero exit.

### Fixed

- **A parameter whose type is not a type name is no longer told the wrong
  rule.** The diagnostic said `a parameter's type must be a type name`, which
  stopped being true when conformant array parameters landed in 1.7.0 — a
  parameter may equally be written as a schema, and the message denied it. It
  is now `a parameter's type must be a type name or a conformant array schema`.
  Both front ends carry the wording, so `difftest` compares them.

- **`doc/implementation-defined.md` states compliance in the terms clause 5.1
  prescribes.** That clause gives the sentence a processor's accompanying
  documentation shall contain, with a placeholder for the processor's name; the
  document kept the placeholder, so the required statement named nothing. Both
  standards' forms are now written out, and the ISO 7185 one says level 1.

- **`PAS_JUMP_SIZE` is a per-target maximum rather than a measurement of
  x86-64.** The storage a block needs to be the target of a non-local `goto`
  embeds a `jmp_buf`, which is 200 bytes on x86-64, 312 on aarch64 and 392 on
  32-bit arm; the constant was 256, so the runtime's own `_Static_assert`
  stopped a build for any of them. It is 1024 now, and the cost is paid only by
  a block that is a non-local `goto` target. `runtime/pasrt.c` compiles for
  aarch64, both arm ABIs, i686 and x86-64, and a complete aarch64 `pascalc`
  links from a textually retargeted seed. Nothing about the compiler's own
  behaviour on x86-64 changes.

## [1.7.0] — 2026-08-21

### Added

- **Conformant array parameters, and this is now a level 1 processor.**
  ISO 7185 clause 5.1 a) makes §6.6.3.6 e), §6.6.3.7 and §6.6.3.8 the whole of
  the difference between the two levels, and all three are accepted:

  ```pascal
  function total(var a: array [u..v: integer] of integer): integer;
  ```

  One compiled body serves every extent an array-type can have; `u` and `v`
  denote the smallest and largest values of the index-type the *actual*
  possesses; and §6.6.3.8's conformability decides which actuals fit. The
  packed form, the nested form and §6.6.3.7's abbreviated
  `array [u..v: T1; j..k: T2] of T3` are all accepted, as is a conformant array
  parameter passed on to another. `doc/implementation-defined.md` §1 now states
  level 1. All 51 programs of the BSI Validation Suite's LEVEL1 directory
  behave as their class headers require.

- **`pascalc --dump-limits`** compiles as usual and then writes how full it
  left its own fixed arrays — the character pool and the token table — each
  against its capacity, one per line (`pool 491964 of 1000000`). Neither
  standard bounds the size of a program, so both limits are this processor's
  and `doc/implementation-defined.md` now states them; the flag is how a large
  program's headroom is read off a real compilation rather than guessed at.
  Unlike the four `--dump-*` flags it stops no stage: the pool is filled by
  Sema and by CodeGen as well as by the lexer, so it runs everything.

### Fixed

- **`pack` and `unpack` work on an array whose bounds arrive with the actual.**
  Both read the arrays' bounds and the packed one's size from the type's
  compile-time `lo` and `hi`, which for a schematic formal parameter
  (`var s: sch`) are placeholders — so `pack(s, 1, z)` moved the wrong bytes
  and trapped against bounds of `1..0`. It has been wrong since schematic
  formals landed and no program in the corpus packed one; conformant array
  parameters reached it a second way, and BSI's LEV1F06, LEV1F07 and LEV1F51
  are the programs that report it.

- **A structured type containing a file is no longer assignable**, under all
  three `--std` modes. §6.4.6 a) of both standards makes a value
  assignment-compatible only when its type "is permissible as the
  component-type of a file-type" — a file at any depth — and this compiler read
  only the first half of that sentence, so `b := a` between two records holding
  a `text` was accepted. The copy is a memcpy of the file's own storage, so both
  variables then named one open file and the block closed it twice: a double
  free and SIGABRT, from a program a conforming processor must reject at compile
  time. It is now `cannot assign r: it contains a file, and a file has no copy`.
  BSI's DEV102 is this program, and it was the one DEVIANCE test of 266 this
  compiler did not reject.

### Changed

- **`--std=afterschool`: one linker symbol is one `external` declaration.** Two
  headings naming the same foreign symbol in one program-component are now
  refused with a diagnostic. They were accepted and then failed at assembly
  time — `invalid redefinition of function 'abs'`, reported against a temporary
  file the program's author never wrote. The names are compared exactly, so
  `'ABS'` and `'abs'` are different symbols, and two modules of one program may
  each declare the same name. `--std=iso7185` and `--std=extended` are
  untouched: they refuse the `external` directive itself.

## [1.6.0] — 2026-08-20

The first release after an independent audit of `doc/afterschool-pascal-spec.md`
against the standards it amends (ADR-0144). Five readers were given the document
and told to prove it wrong; six compiler defects and nine citation errors came
back, and most of what follows is theirs.

**Read the first entry under `Changed` before upgrading.** It alters what an
already-valid ISO/IEC 10206:1991 program prints.

`--std=iso7185` is untouched by every entry below.

### Changed

- **`new(p, c1, ..., cn)` sets each selector** (ADR-0144, `--std=extended` and
  `--std=afterschool`). ISO/IEC 10206:1991 §6.7.5.3 requires the tag-field of
  each selected variant to be attributed the case-constant's value; the tags
  were read only to size the allocation, so the tag kept whatever the storage
  held.

  ```pascal
  new(p, green);
  case p^.k of red: writeln('red'); green: writeln('green') end
  ```

  printed `red` in 1.5.0 and prints `green` in 1.6.0. Any program using `new`
  with variant selectors may therefore behave differently — correctly, and
  differently. ISO 7185 §6.6.5.3 has no such requirement, saying instead that
  the created variable "shall be totally-undefined", so `--std=iso7185` is
  unchanged.

- **`read` into a field of a variant activates that variant**
  (ADR-0144, `--std=afterschool`). §6.10.2 writes `read(f, v)` out as
  `v := f^; get(f)`, so its target is assigned to; the dialect treated it as a
  read and stopped the program on a valid Extended Pascal program.

- **A constant may not have type `int64`**, and the compiler now says so
  (ADR-0136). This settles a sentence ADR-0128 left open. Five of the six
  positions report the message they always reported for a type that is not
  ordinal; a constant-definition, which requires no ordinal, gets one of its
  own rather than the generic *is not a compile-time constant*, which of a
  literal would not have been true:

  ```
  the value of constant 'c' has type int64, and a constant cannot:
  assign it to a variable of that type instead
  ```

  No program is affected: every program this refuses is one that did not
  compile before. Admitting such a constant later would widen what is accepted
  and break nothing.

### Added

- **An empty case-list-element may abut `otherwise`** (`--std=extended` and
  `--std=afterschool`). `case i of 1: otherwise s end` is legal —
  ISO/IEC 10206:1991 §6.9.3.5 makes the separator before the completer optional
  — and was refused with *expected a statement, found 'otherwise'*.

- **A dialect program can use the conforming library** (ADR-0137). A module
  whose interface exposes no record with a tagged variant-part now emits its
  activation names under `--std=afterschool` as well as its own, so
  `lib/`'s six ISO/IEC 10206:1991 modules — `PasStrings`, `PasSort`,
  `PasMath`, `PasVector`, `PasMap`, `PasText` — link into an Afterschool
  Pascal program. None of them needed a change.

  Before this, Sema accepted such a program completely and it died at the
  link on `m.pasmath.afterschool.init`: ADR-0119 spelled the mode into a
  module's activation names, and the mode is a proxy for the ABI far too
  coarse to be right. The safety rule it protects is unchanged — a module
  exporting a tagged variant is still mode-locked, because that is the one
  construct whose meaning differs between the modes.

  A dialect module still cannot be linked into a conforming program, and that
  asymmetry is deliberate: a dialect module may declare `external` routines
  and is not a conforming program-component.

- **`doc/afterschool-pascal-spec.md`** (ADR-0135) — a specification of the
  dialect, written as an amendment to ISO/IEC 10206:1991 in that standard's own
  clause numbering. It is derived from the decision records and verified by
  probe, never from the compiler's source, and it found five divergences on its
  first pass, one of them the crash above.

- **The dialect reserves no word-symbol, and now says so** (ADR-0140,
  AP §6.1.2). A feature is spelled in a position where a conforming program
  could not have written it — `external` in the directive slot, `array of` in a
  juxtaposition that was a syntax error, `?` in a character no program can
  spell, `int64` in a scope §6.2.2.5 lets any program shadow. Nothing about
  what the compiler accepts changes; what changes is that the rule every future
  spelling is held to is written down and enforced.

### Fixed

- **Assigning a slice is refused instead of writing outside an array**
  (ADR-0143, `--std=afterschool`). `p := r` between two slice formals reached
  `Assignable`'s last resort, which compares type *kinds* and so accepted any
  two slices whatever their component types; CodeGen then copied
  descriptor-sized bytes between the two arrays' **contents**, writing past the
  end of the shorter one and exiting 0, at `-O0` and `-O2` alike.

- **A slice type can no longer escape through `type of`** (ADR-0143,
  `--std=afterschool`). ISO/IEC 10206:1991 §6.4.9's type-inquiry named a slice
  type, so a slice could be made a variable, a type-definition, a record field,
  an array component, a pointer domain or a file component — every position the
  specification forbids — each holding a descriptor nothing had filled in.

- **Comparing two slices is refused instead of emitting invalid IR**
  (ADR-0139, `--std=afterschool`). AP §6.4.5 makes two slices compatible so
  that one `array of T` parameter accepts either, and the relational operators
  ask compatibility — so `a[1..2] = a[3..4]` was accepted by Sema and lowered
  to an `icmp` over a two-word descriptor, which `clang` rejects as invalid IR
  against a file nobody wrote. All six operators and every component type were
  affected; `<` on two slices of `real` emitted an unsigned integer compare.
  The new diagnostic is *a slice cannot be compared*.

- **A module is mode-locked when a tagged variant is reachable through a
  procedural parameter's own parameters** (ADR-0142). Such a module was called
  portable, linked into a dialect program, and the program's variant check then
  passed an unsafe read.

- **A level-0 activation record's name is refused as a foreign name**
  (ADR-0144, `--std=afterschool`). `external 'frame1'` collided with the
  program's own frame global and was reported by LLVM as *redefinition of
  function '@frame1'* — an error naming a file nobody wrote. It is now a
  diagnostic from the compiler.

- **A wide literal where a constant is required no longer stops the compiler**
  (ADR-0136), under `--std=afterschool`. Writing an unsigned-integer greater
  than `maxint` in a constant-definition, a subrange bound, an array's
  index-type, a set's base-type, a case-constant, or an operand of a
  constant-expression terminated `pascalc` with `case: no label matches the
  selector` — a case-statement in its own source with no arm for the wide
  literal. It reported nothing, so no golden could hold it.

  Reachable since 1.5.0 and invisible to every gate: the corpus wrote the type
  name and `maxint64` in all six positions, and both of those fold. Only a
  literal reached the missing arm. Found by probing a requirement while writing
  `doc/afterschool-pascal-spec.md` (ADR-0135).


## [1.5.0] — 2026-08-19

**The release the dialect arrived in.** ADR-0109's practical Pascal had a
goal and no surface; it now has a third `--std`, a foreign-function
interface, a standard library in two layers, and the types those needed.
The two conformance modes are untouched by all of it — that separation is
the whole design, and `tests/dialect/inherits_extended.pas` is what pins it.

**And the last known conformance defect is fixed.** §6.1 of
`doc/implementation-defined.md` — the programs this compiler accepts that
ISO 7185 requires it to reject — is **empty** for the first time, and §3's
unreported-error list is three entries shorter. Read *Changed* before upgrading: five shapes
that used to compile no longer do, and each of them returned or read
something wrong.

### Added

- **`external` — a foreign function, under `--std=afterschool` only**
  (ADR-0121). A program can now call code this compiler did not emit, which
  is what the whole outward-facing half of ADR-0109 was waiting on: sockets,
  clocks, locales and ADR-0116's allocator convention are all behind it.

  ```pascal
  function cbrt(x: real): real; external 'cbrt';
  procedure srandom(seed: integer); external 'srandom';
  ```

  The word sits where `forward` does, so it is an *identifier* in that one
  position (ISO 7185 §6.1.4, ISO/IEC 10206:1991 §6.1.4) and nothing is
  reserved — a program that names a variable `external` is untouched, in every
  mode. The foreign name is a string-literal and there is no default: this
  lexer case-folds identifiers and a linker matches a symbol exactly, so
  deriving one from the other would be a lossy mapping to a name that has to
  be right.

  **Two types cross the boundary: `integer` and `real`.** They are the two the
  C ABI on this target needs no parameter attribute for, which was settled by
  probing `clang` rather than by reading — a `char` is passed `i8 signext` and
  disagrees with §6.4.2.2's 0..255 about the sign bit, and a `bool` is passed
  `i1 zeroext` as a `_Bool` few C interfaces take. Value parameters only, and
  the test is on the **exact** type: `1..9` does not cross, because nothing on
  the other side promises a value is in range.

  `tools/pascalcc` already links libc and libm, so a first foreign call needs
  no build change and there is no `-l` surface yet.

  **Nothing checks the declaration against the function it names.** The linker
  checks the name; nothing checks the signature. The boundary is *visible* —
  one directive, the foreign name written out — and that is the only property
  claimed for it.

  Neither conformance mode accepts it, and ADR-0119 then makes an
  `external`-using module unimportable by a conformance-mode program: so the
  outward-facing library is dialect-only, permanently, and `lib/`'s existing
  modules stay Extended Pascal that any conforming processor can take.

- **`?T` — an optional type, under `--std=afterschool` only** (ADR-0123). A
  value of T, or nothing, and the language's first way of saying "there may be
  nothing here" without inventing a convention per routine.

  ```pascal
  type OptName = ?string(16);
  var n: OptName;
  begin
    n := nil;                       { absent }
    n := 'hello';                   { present, by ordinary assignment }
    if n <> nil then writeln(n^)
  end
  ```

  `nil` is the absent value and `= nil` is the test, so no identifier and no
  operator is added. `?` is a character neither standard admits anywhere, so
  the lexis costs nothing and no program that compiled stops compiling — in
  either conformance mode `?` is still `unexpected character '?'`.

  **`o^` is the only way to the value, and it traps when there is none.** That
  is the guarantee read the other way round: a `T` that is not optional can
  never be absent. Nothing is assignable *from* an optional, which is the whole
  of the type discipline — two lines, and `o + 1`, `writeln(o)` and `o < nil`
  are then refused by rules that were already there.

  An optional may hold any type that is not a file and not itself an optional,
  including a record, an array or a string; it may sit in a record or an array,
  and it may be a parameter or a function result. It is name-equivalent like
  every other structured type (ADR-0017): two separately declared `?integer`
  are two types.

  The check is **not** elided by a guard — `if o <> nil then o^` still emits
  it. What the type localises is *where* the check is, not whether it happens.

- **A foreign function may return an optional string** (ADR-0123), which lifts
  ADR-0122's refusal of the result direction exactly as far as null now has
  somewhere to live.

  ```pascal
  type EnvText = string(4096);
       OptEnvText = ?EnvText;
  function getenv(name: string): OptEnvText; external 'getenv';
  ```

  Null is absence, not a failure and not an empty string. Non-null is copied at
  the call site, so **no C pointer ever becomes a Pascal value** — the program
  holds a string of its own and the pointer is dead by the end of the
  statement. The capacity is required and is checked: a value that does not fit
  is §6.4.6's error, in §6.4.6's words.

  Still refused: a bare string result (now with a message that names the
  remedy), `?integer` — C has no null integer — and every other pointer.

- **`PasEnv` — the process environment** (`lib/dialect/`, ADR-0123): `Lookup`,
  `LookupOr`, `Defined`, `Define` and `Undefine`. `Lookup` of an unset name
  answers `nil`, of a name set to the empty string answers a present value of
  length zero, and a caller can tell the two apart — which no shape in this
  library could do before.

  **`putenv` is deliberately absent**: it keeps the pointer it is handed, and
  this compiler's string arena reclaims that storage at the end of the
  statement. `setenv` copies. It is the first time the FFI's registered blind
  spot has decided an interface rather than being recorded against one.

- **`array of T` — a slice, under `--std=afterschool` only** (ADR-0125). A
  formal parameter's type, and a view of part of an array:

  ```pascal
  function Total(protected var s: array of integer): integer;
  var k, t: integer;
  begin
    t := 0;
    for k := 1 to length(s) do t := t + s[k];
    Total := t
  end;
  ...
  Total(a);          { the whole of it }
  Total(a[3..5]);    { three components }
  ```

  Extended Pascal gives a string a substring (§6.7.6.7) and gives an array
  nothing, so a routine that wanted part of one had to be handed the whole
  thing and two indices — which puts the bounds outside anything that checks
  them. **A slice carries its own length**, so the callee's `s[k]` is checked
  against the part it was given and not against the array it came from.

  §6.4.3.2 requires a bracketed index-type after `array`, so `array of T` is a
  syntax error in both standards and nothing that compiled stops compiling.
  The designator `a[i..j]` is the one §6.5.6 already gives a substring; only
  the base's type tells the two apart, and in a conformance mode it still
  means a substring and still refuses an array.

  A slice is indexed **1..length** however far into the base it starts — the
  rule §6.7.6.7 gives a substring, and a divergence from Delphi's 0-based open
  array that fails at the first access rather than quietly. `length(s)` answers
  the count. An empty slice (`a[4..3]`) is admissible.

  `var` and `protected var` only: a slice is a view of the caller's storage,
  and a value parameter is a copy. It may not be a variable, a field, a result,
  or a named type — the denoter is legal as a formal parameter's own type and
  nowhere else.

- **Fixed: a schema whose body holds an optional crashed the compiler.**
  `?T` was the seventeenth type kind and `StaticThroughout` still enumerated
  sixteen; a Pascal case-statement with no matching label stops the program, so
  a schematic formal parameter over such a schema —

  ```pascal
  type Box(n: integer) = record slot: ?integer; pad: array [1..n] of integer end;
  procedure show(var b: Box);
  ```

  — stopped `pascalc` rather than compiling. Present only in the unreleased
  ADR-0123 work, and never in a released version.

- **Fixed: two `string` parameters in one group of an `external` heading.**
  `function setenv(name, val: string; …)` was refused since ADR-0122, because
  §6.7.3.3's "one formal-parameter-section is one parameter-form, so every
  actual brings the same tuple" was being applied to a foreign heading. A
  foreign `string` formal is not a schematic formal and has no tuple. Nothing
  had asked: the only such declaration in the corpus was `strcmp`, and every
  call passed two actuals of equal length.

- **A string and a `var` parameter cross the foreign boundary** (ADR-0122),
  still under `--std=afterschool` only.

  ```pascal
  function atoi(s: string): integer; external 'atoi';
  function modf(x: real; var ip: real): real; external 'modf';
  ```

  **An address crosses only as an argument.** Nothing comes back as one: a
  returned `char *` is the callee's storage or nobody's, and it may be null —
  `getenv` of a name that is not set answers null in the ordinary course of
  things — which needs an optional type this language does not have yet. An
  *argument* is different: the caller owns the storage and outlives the call,
  so the lifetime question does not arise.

  `string` in an `external` heading means `const char *`, and it is **not** a
  schematic formal: there is no descriptor to bind and no capacity, so the
  actual has only to be a string and may be a literal, a variable, a
  concatenation, a substring or a char. What crosses is a NUL-terminated copy
  in the string arena, alive for the statement. A capacity (`string(20)`) or a
  fixed size (`packed array [1..3] of char`) on the formal is refused: a C
  string carries its length in-band as the NUL, so the size is the actual's.

  **A string containing `chr(0)` traps** rather than being truncated. C cannot
  represent one, and a path silently cut short is the class of thing every
  other check here traps on.

  A `var` parameter of `integer` or `real` crosses as the actual's own address
  — `int *` and `double *`. A **buffer** does not: it is a pointer *and* a
  length, and the length is not in-band the way a C string's is. So `read` and
  `snprintf` still wait, on a language decision about slices rather than on the
  FFI. A procedural parameter is refused outright, the static link being a half
  with no image at all in C.

- **`PasFS` — the file system** (`lib/dialect/`, ADR-0122): `Remove`, `Rename`,
  `MakeDirectory`, `RemoveDirectory` and `Exists`, over `remove`, `rename`,
  `mkdir`, `rmdir` and `access`. A routine with nothing to return answers an
  `ErrorCode` directly, `errNone` being success, because ADR-0120's result
  record draws its safety from the payload setting the tag and an arm with no
  payload has nothing to set it with.

  **Every failure is `errIO` and cannot be finer**, because `errno` is
  `*__errno_location()` on glibc and a pointer *result* is the one thing
  ADR-0122 refuses. `Readable` and `Writable` are absent for a second reason:
  `R_OK` and `W_OK` are numbers a C header supplies and an FFI without a header
  parser cannot see, while `F_OK` is 0 and 0 is 0 everywhere.

- **`hypot`, `atan2` and `atan` are names a program may have.** ADR-0121 could
  not let a program name a linker symbol the emitted module already declares,
  LLVM refusing any redeclared global, and those three were declared because
  `arctan` compiles to the first and `abs` and `arg` of a `complex` to the
  other two. They are now `pas_atan`, `pas_atan2` and `pas_hypot` in the
  runtime, so `external 'hypot'` works — in the same program that uses
  `complex`, which `tests/dialect/foreign_libm.pas` is.

  Two names are still refused and neither can move: `main` is the entry point,
  and `_setjmp` has to be called in the frame `longjmp` returns to, so a
  wrapper would return before §6.8.3.11's non-local goto ever jumped.

- **`PasMathX` — the first binding module** (`lib/dialect/`, ADR-0121):
  `Cbrt`, `Log10`, `Log2`, `FMod` and `RealOr`, over libm functions neither
  standard has. It holds one claim still — a binding module **exports Pascal
  and keeps the directive to itself** — and where a routine can fail it answers
  ADR-0120's result shape rather than a NaN: `Log10(-1.0)` reports `errRange`,
  and reading the payload without asking traps.

- **`lib/` — the beginning of a standard library** (ADR-0114), and it widens
  what the sentence above calls the public interface: until now this project
  shipped a compiler, and it now also ships Pascal that other programs import.
  Three modules, in ordinary Extended Pascal:
  - `PasStrings` — `Upper`, `Lower`, `StartsWith`, `EndsWith`, `IndexOf`,
    `PadLeft`, `PadRight`, `Times`, `Reverse`, `Replace`;
  - `PasSort` — `SortIndexed` and `LowerBound` over positions rather than
    elements, so one body serves any element type; `SortInts` and the
    `IntVector` schema for the common case;
  - `PasMath` — `IMin`, `IMax`, `Gcd`, `Lcm`, `ISqrt` and a seedable Lehmer
    generator, each written so no intermediate leaves `-maxint..maxint`.

  **The compiler is unchanged**: a library module is a §6.11 module translated
  as a §6.13 program-component, both of which were already implemented, so
  neither `--std=iso7185` nor `--std=extended` accepts or refuses anything
  different. There is no install location and no resolution by name —
  `--import` takes a path — so a program outside this repository names paths
  into a checkout.

  One thing a caller should read first, a consequence of existing behaviour
  rather than of this change: an exported function assigns its own identifier
  once at the end, §6.11.1 making its heading a `forward` whose body cannot see
  a result-variable-specification. **Fixed under Fixed, below**, in a later
  change of this same unreleased version; the paragraph is left as written
  because it is what a caller of the library at that point had to know.

- **Three more modules — containers and text** (ADR-0116):
  - `PasVector` — `IntVec`, a growable sequence of integers: `VecNew`,
    `VecPush`, `VecPop`, `VecGet`, `VecSet`, `VecReserve`, `VecFill`, `VecSum`,
    `VecClear`, `VecFree`;
  - `PasMap` — `StrMap`, a `string(32)`-keyed dictionary with open addressing
    and tombstones: `MapPut`, `MapGet`, `MapHas`, `MapDelete`, `MapCount`, and
    `MapSlots`/`MapLiveAt`/`MapKeyAt`/`MapValAt` to walk it;
  - `PasText` — `Split`, `Join`, `TrimStart`, `TrimEnd`, `TrimAll`,
    `CountChar`, `TryParseInt`, `ParseIntOr`, `IntToStr`.

  **A container is a pointer to a schema and growth replaces the variable**, so
  every routine that may grow takes `var v: VecPtr`. A schema is chosen once —
  `var v: IntVec(n)` fixes `n` at the declaration — which makes the heap the
  only mechanism for an extent that changes.

  **The element type is written out.** `PasSort` avoided "no generics" by
  phrasing itself over positions and never seeing an element; a container holds
  the elements, so their type is part of its layout. The documented answer for
  another element type is to copy the file.

  **No container takes an allocator.** An allocator record is not expressible —
  a record field may not have a procedure type — and a per-type allocator
  parameter, which does compile, can only recycle blocks `new` produced and
  serves a capacity nothing checks. `VecReserve` is what survives of the idea:
  control over *when* allocation happens.

  `TryParseInt` inspects characters itself rather than using `readstr`, because
  §6.9.1's read of an integer is an *error* when the text is not a number and
  stops the program — a library cannot offer "parse this if it is a number" on
  top of something that halts when it is not.

- **`--std=afterschool` — a third language mode, the dialect** (ADR-0117). It
  is where the project's stated goal gets built, and unlike the first two it
  **nests**: it contains ISO/IEC 10206:1991, so every Extended Pascal program is
  a valid Afterschool Pascal program meaning the same thing. `--std=iso7185` and
  `--std=extended` are unaffected and stay exactly what they are.

  **It admits no feature yet**, which is the point rather than a caveat: today
  the mode accepts exactly Extended Pascal, and that containment is the property
  every later feature is added to. `tests/dialect/inherits_extended.pas` holds
  it, and the same source under `--std=extended` and `--std=afterschool`
  produces identical output.

  It carries **no stability promise**. The dialect is what the compiler at hand
  defines; a program needing fixed behaviour should pin a compiler version.

  `tests/dialect/` is the third corpus directory and the directory decides the
  flag, as `tests/extended/` does. `selfhost/difftest.sh` **skips** dialect
  sources — the reference front end is frozen at the conformance surface, so
  there is no second implementation, and comparing two rejections would pass
  while proving nothing. Skips are counted and reported, and the corpus check
  now requires compared + skipped to equal the whole.

- **In `--std=afterschool`, a variant record's tag cannot lie** (ADR-0118) —
  the dialect's first feature. Writing a variant's field makes that variant
  active, and reading a field whose variant is not active traps, so a tagged
  union is checked rather than merely conventional. Construction needs no tag
  assignment and cannot get it wrong:

  ```pascal
  r.num := 42;      { activates ok }
  r.msg := 'nope';  { activates bad }
  writeln(r.num)    { traps: the tag selects another arm }
  ```

  §6.5.3.3 makes reading an inactive variant an **error** and §3.1 lets a
  processor leave an error undetected, which both conformance modes do — so a
  correct program never does it and the dialect detecting it changes nothing
  that was already right. Nothing in `--std=iso7185` or `--std=extended`
  behaves differently.

  Two limits: a write activates only when the arm has exactly one label, since
  `aa, bb: (i: integer)` cannot decide between them and is checked against the
  tag instead; and a variant part with **no tag field**, which §6.4.3.3 permits,
  has nothing to check against and stays an unchecked union.

- **`seed/ddc.sh` — diverse double-compiling, and it passed.** The seed is an
  opaque committed artefact whose provenance was this repository's history and
  nothing else. Building a compiler through the `v0.1.0` C++ implementation
  (LLVM's own code generator) and one through the seed, then having each
  translate `selfhost/compiler.pas`, produced identical output — 7,024,210
  bytes, sha256 `399b9cdc…`. `seed/README.md` carries the dated statement and
  the limits: `v0.1.0` is this project's own earlier compiler, so the two are
  diverse in implementation but not independently authored, which rules out a
  seed that drifted from its source rather than a mistake present in both. The
  script skips rather than fails when it cannot run, and says so explicitly on
  the day the `v0.1.0` compiler stops accepting today's source — after which the
  question can no longer be asked.

- **`lib/dialect/` — a second library layer, in `--std=afterschool`**
  (ADR-0120), and the answer to the finding three increments of `lib/` kept
  producing: every routine that can fail invents its own way of saying so.
  A fallible routine now answers one record that carries the value **or** the
  reason:

  ```pascal
  IntResult = record
    case ok: boolean of
      true:  (num: integer);
      false: (code: ErrorCode)
    end;
  ```

  Nothing assigns the tag — the write to the payload is what sets it — so a
  caller who reads `num` on a failed result **traps** rather than receiving an
  integer that was never parsed. `lib/dialect/paserror.pas` holds the shared
  `ErrorCode`; `lib/dialect/pasparse.pas` is the first producer.

  It is a shape and not a type: with no generics a result's payload type is
  part of its layout, so each producing module declares its own record and what
  is shared is the error code and the spelling of the tag.

  **The two layers do not mix.** `lib/` stays Extended Pascal and stays
  importable by any conforming program; `lib/dialect/` is dialect all the way
  down, and the entry below is what makes that enforced rather than promised.
  The cost is duplication — `ParseInt` trims its own input because it cannot
  call `PasText.TrimAll`.

- **`int64` — an integer twice as wide, under `--std=afterschool` only**
  (ADR-0128), and the other half of the data path ADR-0125's closing probe
  named: on this target every length `read`, `write` and `recv` take is a
  `size_t` and every one of them *answers* an `ssize_t`.

  ```pascal
  function llabs(x: int64): int64; external 'llabs';
  var n: int64;
  begin
    n := 5000000000;
    writeln(n * 2, ' ', maxint64)
  end.
  ```

  It is a **numeric** type and not an ordinal one, and the rest follows from
  that. It answers where `real` answers — `+ - * / div mod`, the relational
  operators, `abs`, `sqr`, unary sign, and the widening from `integer` — and it
  is refused wherever an ordinal is wanted: no case label, no array index, no
  subrange bound, no set base, no `for` control variable, no `succ`, `pred`,
  `ord`, `odd`, `chr` or `in`. Overflow traps as `integer`'s does and at both
  ends, `-maxint64..maxint64` being the type. `trunc` is the one way back to
  `integer` and it is checked; there is no implicit narrowing.

  `maxint64` is a required constant beside `maxint`, and the type crosses the
  `external` boundary as a value parameter, a `var` parameter and a function
  result.

  Two things it does not do, and both come from the same place — the compiler is
  written in this language and its own integers are 32 bits, so it has no value
  of the wide type to hold. A literal is carried as the **text** that was
  written, exactly as a real literal always has been, so nothing 64-bit folds:
  `const c = 5000000000` names the digits and `const c = maxint64 - 1` is not a
  constant-expression. And `read` does not take one where `write` does, which is
  in `doc/implementation-defined.md`.

  Nothing about `--std=iso7185` or `--std=extended` moved: `int64` is an
  ordinary identifier there, and a decimal literal above `maxint` is the error
  it always was.

- **A buffer crosses the `external` boundary, as a slice** (ADR-0129), under
  `--std=afterschool` only. The pair travels as `(ptr, i64)` — the address of
  the first component, then how many there are — which is the argument shape
  `read`, `write`, `recv`, `send` and `snprintf` all take, so the POSIX data
  path is bindable for the first time:

  ```pascal
  function PosixRead(fd: integer; var buf: array of char): int64;
    external 'read';
  ...
  n := PosixRead(0, buf[1..5]);      { five bytes, and read is told so }
  ```

  **The program never writes the count.** `PosixRead` has two parameters and
  `read(2)` has three: the length C receives is the one the compiler computed
  from the designator and checked against the array, so a buffer overrun is not
  something a caller can spell. The rejected alternative — an address alone,
  with the program passing the count — would have put that hazard back at the
  one place across this boundary where nothing is checked.

  The component may be `char`, `integer`, `int64` or `real`, and the list is
  deliberately not the one the other rows use. A slice is storage the callee
  **writes**, so a subrange would come back with nothing to check it and
  `boolean` has 254 byte patterns that are not values of it. `char` is admitted
  here and refused as a value because that refusal was about the register
  convention: in memory the type has no bit pattern that is not a value of it.

  Two limits worth knowing before binding anything. A count is **components**
  and C's is bytes, so `read` bound to an `array of integer` asks for a quarter
  of what it looks like. And a C function whose length does not immediately
  follow its pointer — `memcpy`, or anything spelled `(size_t n, void *p)` —
  cannot be bound with a slice, there being no bare-address form.

  `p[2..5]` over a **packed** array of char is still §6.5.6's substring and
  yields a string, so a buffer wants `array [1..n] of char`; passing such an
  array whole works either way.

- **`PasIO` — descriptor input and output** (`lib/dialect/`, ADR-0130), and
  the first user of the buffer above: `OpenRead`, `Close`, `ReadInto`,
  `WriteFrom`, `WriteAll`, `WriteText`, `AtEnd`, `CountOr`, `ResultText`. A
  read or a write answers a `CountResult` carrying the count **or** the reason,
  and a short answer is not a failure — zero from a read is the end of the
  input, which `AtEnd` names.

  **It reads files and writes to descriptors that were already open.** There is
  no `OpenWrite`: creating a file needs `O_WRONLY`, `O_CREAT` and `O_TRUNC`,
  which are header numbers an FFI without a header parser cannot see, and the
  policy `PasFS` set over `access`'s modes is that a number a module cannot
  check does not go in. `O_RDONLY` is 0, the one flag value a header is not
  needed for.

  **It does not share a descriptor with §6.9 and §6.10's own I/O**, which go
  through buffered streams while everything here is unbuffered — writing to
  `StdOut` from both interleaves by whichever flushed last.

  Failures are `errIO` and nothing finer. The *reason* is readable through
  `PasOS` below.

- **`PasOS` — why the last call failed** (`lib/dialect/`, ADR-0131):
  `LastErrorNumber`, `ErrorNumberText`, `LastErrorText`. Two failures that
  answer one `errIO` now say *No such file or directory* and *Not a
  directory*.

  **`errno` is a macro**, so it has no linker symbol and no foreign-function
  interface can bind it — which is why it is `runtime/pasrt.c` and not a
  language decision. Three records had said it was unreachable because glibc
  spells it `*__errno_location()`, a returned pointer; that was true and was
  not the reason.

  The runtime therefore has a **second surface**: `pas_` names are what the
  compiler emits calls to and are refused as foreign names, `pasx_` names are
  what a program may bind, and `pasx_errno` is the only one. `strerror` needed
  nothing new — a `char *` result is what ADR-0123 already receives.

  It gives the sentence and **not** a classification: ENOENT and EACCES are
  numbers in a header this compiler cannot read, so the code a binding module
  answers stays PasError's closed set. And the value is meaningful only in the
  statement after the one that failed, which is C's contract.

- **`PasFS` gains `WorkingDirectory`, `LinkTarget` and `PathOr`**, answering a
  `PathResult` that carries the path **or** the reason (ADR-0132). No compiler
  change and no new mechanism: `getcwd` and `readlink` write into a buffer the
  *caller* owns, so ADR-0129's slice lends the storage, ADR-0123's optional
  receives `getcwd`'s pointer, and ADR-0128's `int64` receives `readlink`'s
  `ssize_t`.

  A returned pointer that is the caller's own storage coming home has no
  ownership question in it, which is what separates these two from `getenv`
  and a `DIR *`. `LinkTarget` answers `errFull` when the target fills the
  buffer exactly — `readlink` writes no terminator, so a possibly-truncated
  path cannot be told from one that just fits, and reporting is the direction
  that does not silently return a short path.

### Changed

#### Programs that used to compile and no longer do

- **A subrange whose bounds are not constants, as a set's base type.** It never
  worked, and it is now refused with *the bounds of a subrange must be ordinal
  constants*. It is legal under §6.2.3.8 b) and the refusal is a deviation,
  recorded in `doc/implementation-defined.md` §6: every set here is one 256-bit
  word whose base type must have its values in 0..255, and a bound the block
  evaluates cannot be checked against that before the program runs. Every other
  position works — see *Fixed* below. (ADR-0127, ADR-0133, ADR-0134)

- **A field or a file component whose *size* a non-constant bound decides**, as
  in `record f: array [1..m] of integer end`. §6.2.3.8 b) reaches the bound and
  a record is no kind of block, so the *bound* is legal; what has no answer is
  where the storage goes, a field after a dynamically sized one sitting at an
  offset nothing can compute (ADR-0045). It compiled, and it was **wrong**:
  `v.a[1]` read 99140726979296144 where 1 had been stored. Refused now, with
  *the bounds of the field 'f' must be constants, because a field's storage is
  sized where the record is*. (ADR-0134)

- **A function with a result-variable-specification that never writes to it.**
  `function f = r: integer; begin end` compiled and returned whatever the slot
  held. §6.7.2 requires the block to contain "at least one statement
  threatening" the result variable — §6.9.4's *threatens*, so a `read` into it
  or passing it to a `var` parameter counts and an assignment is not required.
  *function 'f' never writes to its result variable 'r'*. (ADR-0134)

- **A record whose constant occurrence names one of its own fields.**
  `const fred = 3; type r = record a: array [1..fred] of integer; fred: integer
  end` compiled with the bound reading 3. §6.4.3.3 gives a field-identifier its
  defining-point in the record and §6.2.2.4 makes the scope the whole region, so
  `fred` there is the field and names no constant. This was the last program
  this compiler was known to accept that ISO 7185 requires it to reject, and
  `doc/implementation-defined.md` §6.1 is now empty. (ADR-0134)

- **A type-inquiry naming a parameter of another formal-parameter-list**, as in
  `procedure outer(k: integer; procedure q(x: type of k))`. §6.4.9 requires a
  parameter-identifier object's defining-point to be in the formal-parameter-list
  closest-containing the object. Written in the *block* the same spelling is a
  variable-identifier (§6.7.3.1 gives a parameter both defining-points), so
  `procedure p(var a: v); var b: type of a;` — the clause's own example — is
  unaffected. (ADR-0134)

- **The program-components of one program must agree on `--std`**, and a
  mixture no longer links (ADR-0119). A module's two activation functions carry
  the mode in their names — `@m.counter.extended.init` against
  `@m.counter.afterschool.init` — so a component built under a different
  standard leaves the caller's symbol undefined, and `pascalcc` translates that
  into a sentence naming the module and the mode.

  It is a restriction, and it is there because the alternative was a false
  assurance. `--std=afterschool`'s variant rules are a *pair* — a write to a
  field activates its variant, a read of an inactive one traps — and both are
  emitted at the access, so §6.13's separate translation let them be split. A
  dialect component reading a variant that a conformance-mode component wrote
  ran its guard against a tag nothing had stored and **permitted** the access:
  the check compiled in, switched on, and answering `safe` for an unsafe read.

  Nothing in this repository mixed modes, and an all-`--std=extended` program
  links exactly as before. What changes is that rebuilding half a program after
  changing `--std` now refuses instead of misbehaving.

#### At run time

- **Writing past a direct-access file's index-type is now an error.** §6.4.3.6
  requires `length(f)` never to exceed `ord(b) - ord(a) + 1`, and an eleventh
  component written to a `file [1..10] of T` was accepted — one of the errors
  `doc/implementation-defined.md` §3 listed as unreported. *this file holds at
  most 2 components*. Only a write at the end can grow a file, so `update` is
  unaffected and seeking to the append position of a full file is still legal.
  (ADR-0134)

#### Diagnostics

- **A subrange bound that is not an ordinal is now told so.** With §6.2.3.8 b)'s
  offer live at a subrange denoter, a bound that fails to fold is reported by
  the arm that knows why: `type bad = q..q` with `q = nil` and `sub: 1..maxint64`
  say *the bounds of a subrange must be ordinal* rather than *must be ordinal
  constants*. Neither fault was ever about constancy — `maxint64` is a constant.
  This is the same correction ADR-0127 made to the message for a schema's
  discriminants. (ADR-0133)

### Fixed

- **`read` takes an `int64`**, under `--std=afterschool` (ADR-0128, ADR-0134).
  `write` always did — §6.10.3.1's decimal representation is the same at both
  widths — so this was the one asymmetry the type had, and *a value of type
  int64 cannot be read* is a message no program gets now.

  ```pascal
  var n: int64;
  begin read(n); writeln(n) end.
  ```

  §6.9.1 c) and d)'s longest-prefix rule is the same sentence at both widths, so
  the runtime selects the bound rather than carrying a second copy of the loop.
  A value outside `-maxint64..maxint64` is reported, and the check is made
  *during* the accumulation because `value * 10` would already have wrapped.

- **A subrange may have a bound that is not a constant**, in every position but
  a set's base type. §6.4.2.4 writes `subrange-bound = expression` and
  §6.2.3.8 b) evaluates one "closest-contained by … the block" at that block's
  commencement, so all of these are legal and none of them worked:

  ```pascal
  procedure p(m: integer);
  type t = 1..m;
  var x: t; y: 1..m; a: array [1..m] of 1..m;
      r: record f: 1..m end;
      g: file of 1..m;
  ```

  `var x: 1..m` compiled and could be read but never assigned to, and
  `array [1..m] of 1..m` **trapped on a legal store** — `a[1] := 2` with
  `m = 3` stopped with *value out of range (1..)*, the upper bound reading zero.
  ADR-0127 refused the shape rather than leave it wrong; this is the fix it
  named. The range check at a store now reads the bounds out of the descriptor
  §6.2.3.8 b) filled, which is what the subscript check has always done.

  The trap message names the bounds as **values** — *value out of range
  (1..3)* — because a bound evaluated at the block's commencement has no
  spelling in the source, the program having written an expression and not a
  name. That is what the array-index message already does.

  The last two arrived a record later (ADR-0134): a record is no kind of
  block, so a bound written inside one is still closest-contained by the block
  the declaration is in. What a record and a file refuse is the *consequence*
  rather than the position — a field or component whose size the bound decides,
  listed above.

  An **empty** one is reported at the declaration rather than at the first
  store: *this subrange has no values: its upper bound is below its lower
  bound*, which is §6.4.2.4's other requirement and would otherwise go unsaid
  in a block that never assigns. Extended Pascal and the dialect only;
  ISO 7185 §6.4.2.4 writes `subrange-type = constant '..' constant`.
  (ADR-0133, ADR-0134)

- **A type-definition may have a bound that is not a constant.** §6.2.3.8 b)
  evaluates "each actual-discriminant-part or subrange-bound … closest-contained
  by … the block" at that block's commencement, and a type-definition is
  contained by the block — so `type t = array [1..m] of integer` and
  `type t = vec(m)` inside a procedure are legal, and were refused. The variable
  half landed in the previous release (ADR-0113); this is the rest of the
  clause, and it was the finding of ADR-0107's independent reading most likely
  to break a real program.

  ```pascal
  procedure p(m: integer);
  type t = array [1..m] of integer;
  var a, b: t;
  ```

  The bound is evaluated **once for the type**, however many variables of it the
  block declares — so `a` and `b` are one type with one extent and `a := b` is
  an assignment, which is what §6.4.1 requires of a type-name. Extended Pascal
  and the dialect only; ISO 7185 §6.4.2.4 writes `subrange-type = constant '..'
  constant`. (ADR-0127)

- **The compiler no longer runs out of tokens compiling itself.** The lexer
  reads its input into a fixed array of tokens, which grows with the size of the
  source; the compiler is its own largest input and had reached **107 tokens**
  under the bound — 0.08% free, and the next change to add more than that
  stopped the build with *"too many tokens: this compiler accepts 140000"*.
  Raised from 140,000 to 300,000, `poolMax` from 700,000 to 1,000,000 so the two
  run out at about the same size of source, and the seed refreshed to match —
  the seed carries the old bound, so this is again the one shape of change that
  cannot wait for a release tag. A large program that failed with either message
  now compiles. (ADR-0126, and ADR-0095 four days earlier for the pool)

  The headroom is now **measured**: `buffer-headroom` runs with every `ctest`
  and fails above 80% full, so the third occurrence is a report rather than a
  wall. That measurement is the sentence ADR-0095 closed with and did not act on.

- **A module imported and not used was called and never declared.** §6.2.3.6
  activates every module that supplies the main-program-block, whether or not
  the importing component names anything of it — but the only thing registering
  an imported module for declaration was the path that names its activation
  record, which runs when something of the module's is *accessed*. So a program
  importing a module it never used emitted a call to `@m.<name>.fini` into a
  file that declared no such symbol, and the assembler refused it: the program
  did not build at all. Present since modules landed (ADR-0053), and reached by
  nothing in the corpus, every `--import` in the tree having used what it named.

- **A `forward`-declared function may name its own result.** §6.7.2's
  result-variable-specification — `function f(...): t[r]` — was refused for a
  function whose heading had already been given, so §6.11.1 putting every
  exported function's heading in a module-heading made it unavailable to every
  module in `lib/`. §6.8.2.2 makes a *read* of the function identifier a
  recursive call, so an exported function that accumulates had no name to
  accumulate in and had to use a local.

  The clause gives the result identifier a defining-point in "the block of the
  function-block, **if any**, associated with the identifier of the
  function-heading", and one paragraph later says the identical thing of the
  formal-parameter-list — which has always reached a forward body. The
  asymmetry was literal in the compiler: parameters were bound from the
  *symbol*, the result variable from the *declaration node*, and a forward
  body's node carries no specification. The refusal now reads the symbol too,
  and both halves of the clause behave alike.

  `tests/extended/forward_resultvar.pas` is the case; `doc/sop.md` §7 carried
  this as the first question for the next `langspec-audit`, which it turned out
  not to need.

- **A function's result may be a structured value parameter's actual.**
  §6.6.3.2 makes a value parameter's actual an *expression* and §6.7.1 makes a
  function-designator one, so `SumPoint(MakePoint(3, 4))` is legal wherever
  `SumPoint(q)` is. It was refused whenever the formal was structured —
  *argument 1 of 'sumpoint' is point and needs a variable* — and the refusal was
  undocumented, which is consistent with its being a defect rather than a
  decision.

  The compiler had disagreed with itself: `q := MakePoint(3, 4)` already copied
  a record out of a call's storage, and `MakePoint(9, 1).x` already selected
  from one, so the address a value parameter needs to copy from was there all
  along. What kept a call off the list of things Sema would copy from was
  `isDesignator` answering false for one — the right answer to the question a
  **var** parameter asks, where there is no variable to bind, and the wrong
  question for a value parameter.

  This is the idiom a `Result`-shaped record exists for: handing one function's
  result straight to another. Both front ends changed, since this is the
  conformance surface the reference implementation still follows.

- **A schema type containing a string may now be allocated.** `new(p, d)` where
  the domain is a schema whose component contains a variable-string — the shape
  a keyed container wants, `array [1..cap] of record key: string(k); … end` —
  stopped the *compiler* with `case: no label matches the selector`. Not a
  diagnostic and not a wrong answer: a crash, on a legal program, before
  anything was emitted. Sema's `StaticThroughout` asks whether a bound anywhere
  inside a type depends on a discriminant; its case over the sixteen type kinds
  listed fifteen, and Pascal's case-statement traps on the sixteenth rather than
  falling through. The correct arm is `true`, because a string whose capacity is
  a discriminant is answered *before* the case by the dynamic-bounds test — so
  one that reaches it has a fixed capacity and nothing inside it can vary. The
  reference front end had it right all along, its counterpart ending
  `default: return true`; `difftest` could not report the difference because the
  Pascal crashed rather than printing a different dump.

- **A variable-string may now be a value parameter**, so a string argument may
  be a literal, another function's result, a concatenation, or a string of a
  different capacity — `StartsWith(s, 'Hello')` and `Upper(Reverse(s))` compile,
  and neither did before. ISO/IEC 10206:1991 §6.6.3.2 with §6.4.6 requires it;
  this compiler refused it and said the conversion had "nowhere to build the
  result that the caller can name".

  The premise was wrong in one word. The conversion needs somewhere with the
  **formal's** capacity, which is the callee's own frame slot for the
  parameter — so the caller passes a pointer and a length (the string value
  §6.4.6 will store) and the callee's prologue makes the same store `s := expr`
  makes. A value longer than the formal's capacity is an error at the call, with
  the message an assignment gives, because it is the same check.

  A **restricted** string value parameter is still refused, and now says so in
  its own words: whether a clause forbidding assignment of a restricted value
  permits copying one into a parameter is a reading nobody has taken. A
  **fixed**-string value parameter is unchanged — `packed array [1..8] of char`
  is copied rather than converted, so an actual must still have the same length.
  ADR-0115.

## [1.4.0] — 2026-08-18

**One of the changes below turns a wrong answer into an error, and three
refuse a program that compiled before.** None of them removes language you
could rely on — in each case the program was already being compiled into
something other than what it said — but a compiler that changes its mind about
a source you have is the thing worth reading before upgrading:

- a statement whose live string values exceed the arena **stopped being
  silently wrong**. It used to wrap and write one live value over another, so
  `a + a = b + b` over two 512K strings compared a buffer with itself and
  called two values differing in every character equal, exit status 0. There is
  no repair that keeps an answer, so it is now an error;
- an identifier or a character-string longer than 255 characters is refused
  rather than truncated. Truncation made two names one, and printed 255
  characters of a 300-character literal;
- a type-name written inside a record type-denoter that is also one of that
  record's fields is refused wherever it appears, where only `^fred` was
  refused before;
- a program's own block now costs one nesting level, so 999 remain inside it.

Each is a defect against a clause, and every one of them was found by an
oracle rather than by a user: a security audit drove untrusted input at the
front end, and an independent reading of the standards went looking for the
other two. `doc/implementation-defined.md` §6 now states every limit this
processor imposes, which clause 5.1 c) requires and which it had been missing.

### Added

- **A subrange bound in a variable's own type-denoter may be an expression**,
  under `--std=extended`, so `var a: array [1..m] of real` inside a procedure
  is accepted and the array is sized when the procedure is entered:

  ```pascal
  procedure p(m: integer);
  var a: array [1..m] of real;
  ```

  ISO/IEC 10206:1991 §6.4.2.4 writes `subrange-bound = expression` and
  §6.2.3.8 b) evaluates one at the block's commencement, after the formal value
  parameters are attributed. Either end may be one, both may be, they may
  appear at more than one level (`array [1..m] of array [1..k] of real`), and
  each name of a declaration group is sized for itself. A bound outside the
  domain — `1..0` — stops the program on entry, and every subscript is bounds
  checked against the bounds the descriptor holds. **ISO 7185 is unchanged**:
  §6.4.2.4 there writes `subrange-type = constant '..' constant`, and
  `--std=iso7185` refuses it as before. ADR-0113.

  Still refused, and recorded in `doc/implementation-defined.md` §6: the same
  bound in a *type-definition* (`type t = array [1..m] of integer`) or in a
  record field, and in a module's variables, whose activation lasts as long as
  the program.

### Changed

- **An identifier or a character-string longer than 255 characters is now an
  error** rather than being silently shortened to 255. A program containing one
  compiled before and does not now, and that is the point: the limit was being
  applied by dropping the tail, so two identifiers agreeing in their first 255
  characters were *one name* — a program could assign to one and read the other
  with nothing said — and `writeln` of a 300-character literal printed 255 of
  them, so its output did not match its source. Found by a security audit;
  ADR-0110 records why the limit is reported rather than raised, and
  `doc/implementation-defined.md` §6 now states it as clause 5.1 c) requires.
- **A type-name inside a record type-denoter that is also one of the record's
  fields is now refused**, wherever it is written. §6.4.3.3 puts a field's
  defining-point in the region that is the record-type and §6.2.2.4 makes its
  scope that whole region, so `record a: fred; fred: integer end` names the
  field and not the type — as do `array [fred]`, `set of fred`, `file of fred`
  and `fred(3)`, and a field named `integer` takes that spelling from the
  required identifiers inside its own record. Only a pointer's domain-type
  (`^fred`) was refused before, which is the occurrence BSI's DEV043 pointed
  at; the clause names no production. A program that uses a type-name inside a
  record and also has a field of that spelling compiled before and does not
  now. ADR-0112; `doc/implementation-defined.md` §6.1 records the one occurrence
  still not asked, which is a *constant* one.
- **A statement whose string values need more than 1 048 576 characters at once
  now stops the program** with `more string values are live at once than the
  string arena holds`. The storage was a ring: on exhaustion it wrapped to the
  start and wrote one live value over another, so `a + a = b + b` over two
  512K strings compared one buffer with itself and reported two values
  differing in every character as **equal**, exit status 0. There is no repair
  that keeps an answer — a wrap only happens when the values do not fit — so
  what changes is that a wrong answer becomes an error. Concatenating in a loop
  is unaffected and was the reason the wrap looked harmless: a statement's
  string values are released when the statement finishes, so four megabytes go
  through the one-megabyte arena without trouble. ADR-0111 has the mechanism,
  ADR-0110 the rule it applies, and `doc/implementation-defined.md` §6 states
  the limit.
- **A block counts as one nesting level**, so 999 remain inside a program's own
  block where 1000 did before. Nothing counted a block, so a procedure
  declaration nested a scope without nesting anything the parser measured: 1001
  nested procedures indexed Sema's scope stack off its end and stopped the
  compiler with `array index out of bounds (0..1001)` on **stderr**, where its
  diagnostics go to stdout — a caller redirecting stderr got a non-zero exit
  and no message. It is now the ordinary `nesting is too deep` diagnostic.

## [1.3.1] — 2026-08-17

**Three of the fixes below change what an already-valid program prints or
reads.** A patch release does not normally do that, and this one does: each was
a defect against a clause of the standard, and correcting it necessarily
changes the output of a program that met the defect. The affected programs are

- any that writes a `real` and then calls `page` on the same file,
- any that reads a `real` written with more than 63 characters,
- any that writes a `real` in `[1e-100, 1e-99)` with an explicit field width.

Nothing else changes. If you have goldens recorded against 1.3.0 for programs
of those shapes, they will move, and the new value is the conforming one.

### Added

- **`llc-second-backend`**, a `ctest` case and a CI job, asking the one question
  no oracle here could: **is the compiler binary miscompiled?**
  `selfhost/irtest.sh` compiles the compiler with itself twice and requires
  stage 2 to equal stage 3, but both stages come from one binary — so a `clang`
  that got a corner of `selfhost/compiler.pas` wrong would build a wrong
  compiler that reproduced itself exactly, and every golden would agree, having
  been written by it. The check builds the compiler a second way, through `llc`
  at `-O0` and `-O2`, and requires both to translate `compiler.pas` to
  byte-identical IR.
  - It **skips without `llc`**, as `verify-lowering` does without z3: `llc` is
    LLVM's, and ADR-0085's claim is that the build needs nothing of LLVM's.
    The CI job installs it, in a container of its own for that reason, and
    greps the log to refuse a green bar that skipped.
  - It is **not** a second reader of the IR, and the script says so: `llc` and
    `clang` share LLVM's parser and verifier and reject the same module with
    the same message. What it varies is the backend configuration.

### Fixed

- **`page` after writing a real** wrote no line terminator. ISO 7185 §6.9.5
  performs an implicit `writeln(f)` when the current line is not empty, and
  five of the six write primitives recorded that the line had something on it.
  `write(1.5); page` therefore wrote the form feed straight after the value and
  stranded it on the previous page. Six programs in the corpus call `page` and
  none wrote a real first, so every oracle agreed —
  `doc/implementation-defined.md` E.30 included, which had stated the rule the
  code did not keep. `tests/page_after_real.pas` pins all three forms a real
  can be written in.
- **`read` of a real longer than 63 characters** returned the wrong value *and*
  desynchronised the input. §6.9.1 c) and d) take the longest sequence that
  forms a number; the runtime accumulated into a fixed buffer and stopped the
  loop rather than the read, so the digits past the sixty-third stayed in the
  file and became the next value read. A seventy-digit number came back as its
  first sixty-three digits — wrong by seven orders of magnitude — and every
  subsequent read was one number out of step. `tests/readlongreal.pas`.
- **A real in `[1e-100, 1e-99)` was written one character wider than the
  field**, against §6.10.3.4.1's requirement that the floating-point form
  occupy exactly TotalWidth characters. The exponent's width was taken from the
  magnitude of `log10` rather than from the exponent actually written, and for
  that band the two differ. `doc/implementation-defined.md` E.25 and E.27 had
  always described the intended rule correctly; nothing checked it.
  `tests/extended/writereal_width.pas` now does, by measuring the
  representation rather than pinning digits.
- **`pascalcc --help`** printed the licence header and stopped one line before
  the first option, so every option was invisible — including `-c`, `-O0..-O3`
  and `<file>.o`, which `pascalc -h` does not know about and which are
  documented nowhere else.

### Changed

- **`pascalc-s0` refuses the options it cannot honour** rather than accepting
  and ignoring them. `-o`, `-S`, `-c`, `-O0..-O3`, `--keep-temps` and
  `--import` each set a field nothing read, so `pascalc-s0 -o out.txt -S -c
  hello.pas` exited 0 and wrote no `out.txt`. They are residue from when `src/`
  was the compiler; since ADR-0108 it is a front end and generates no code.
  This binary is not the compiler and nothing shipped depends on it.

## [1.3.0] — 2026-08-16

**The differential oracle is green.** ADR-0108 brought the C++ front end back
one release ago and it arrived red: 89 of 731 files on which it and the compiler
disagreed, the drift of twenty-four Sema commits it never received. All 89 are
closed, one commit per rule, each naming the clause it ports. Two independent
front ends now agree on every Pascal source in the tree — 732 of them, token for
token and node for node.

Almost none of that is visible from a Pascal program: the reference front end
generates no code and nothing it produces ships. What *is* visible is small and
is listed below, and one item can break a build that used to work.

### Changed

- **Two schema definitions that used to compile are now refused**, and a build
  containing either will fail. Both were illegal and neither was detected,
  because a schema's body is resolved lazily at its first production, so nothing
  ever looked at the text of the definition:
  - a schema naming another **defined after it** (§6.2.2.9 requires a
    defining-point to precede every applied occurrence, with only a pointer
    domain and an export-list excepted), and
  - a schema **naming itself** outside a pointer domain, where it was never used
    (§6.4.7 states that as a rule about the definition, so it does not wait for
    a production).

  The fix is to reorder the definitions, or to write the self-reference through
  a pointer domain, which is the form §6.4.7 allows.
- **The build now requires a C++20 compiler**, for `src/`. Nothing it produces
  ships and `build/bin/pascalc` does not depend on it — it builds `pascalc-s0`,
  which is a lexer, parser and Sema with no code generator, and exists so
  `selfhost/difftest.sh` has a second answer to compare. README said "no C++
  compiler" until this release.
- `--dump-sema` prints a **redefined `write` or `read`** at the statement's real
  depth. Sema hangs the resolved call off the write statement as a husk
  (ADR-0087) and the dump padded for both nodes, so a `proccall` printed two
  levels deeper than its own arguments. `--dump-ast` runs before Sema and never
  had the husk, so it is unaffected. The reference front end is what caught it:
  the *product* was the wrong one, and copying its output into `src/` to make
  four files agree would have been ADR-0073's failure exactly.

### Added

- **An enumerated type may appear in a schema body.** §6.4.2.3 puts the
  defining-point of an enumerated type's constants in "the block, module-heading
  or module-block closest-containing the enumerated-type" — the block, not the
  production — so `t(n: one) = record c: (red, green); a: array [1..n] of
  integer end` is a legal program, and it was rejected. The constants are now
  declared once, in the block, and every production shares the one type.

### Fixed

- Every conformance rule the reference front end lacked is ported into it — 25
  commits, each naming the clause it carries — so `difftest` compares them
  again. Among them: §6.6.6.4's `succ`/`pred` host type, §6.7.5.5's
  `readstr`/`writestr`, §6.2.2.10's required identifiers as symbols, §6.6.4.1's
  redefinable read/write family, §6.2.2.9's defining-point order and its pointer
  domain exception, §6.6.5.3's `dispose`, §6.4.5 c)'s set packing, §6.6.3.3's
  var-parameter restrictions, §6.1.8's comment delimiters, §6.8.1's three goto
  conditions, §6.4.3.3's variant labels and record-as-region, §6.8.3.9's
  for-statement threats, §6.2.1's declaration interleaving, §6.6.3.2's value
  parameter containing a file, §6.6.3.6's congruity over parameter *sections*,
  §6.5.4's function result, and §6.4.3.2's four properties of a string-type.
  **None changes what `pascalc` accepts**; each closes a place where the two
  front ends disagreed. Eleven programs of the BSI validation suite came back
  with them, CONF027 and CONF116 among them.

## [1.2.0] — 2026-08-15

**The language is unchanged** — no new syntax, no new diagnostic, and nothing a
working program does differently. What makes this a minor release rather than a
patch is one new flag, `--coverage`, and it is a flag for the same reason
everything else here is: coverage in this repository was an argument, and this
release makes it a number.

Three of them, each gating in both directions: which procedures the corpus
enters, which statements it runs, and which clauses of the two standards a
scenario cites. The first measurement of any of them found four documented
`--dump` flags no test had ever passed and a procedure argued unreachable that
turned out to be exactly that.

### Added

- **`tests/spec/`**, a specification suite: 43 scenarios written against 13
  clauses of the two standards, in a subset of Gherkin, with a runner of its own
  and no new dependency. Every other test here starts from the compiler; a
  scenario starts from a clause and states the requirement in the standard's
  terms (ADR-0105). All 292 clause headings of the two standards are classified
  testable, structural or not-implemented, so coverage is measured against the
  189 that can carry a scenario, and `spec-clause-traceability` gates it in both
  directions (ADR-0106).
- **`--coverage`**, a new flag: the compiled program records which of its own
  statements ran and appends their line numbers to `$PASCOV_LINES`. What was
  instrumented is in the IR the same compilation wrote, so the two halves of a
  coverage figure come from one artefact (ADR-0104). It works on any Pascal
  program; this repository's own use of it is one caller.
- **`line-coverage`**, a `ctest` case built on that flag: 12,708 of 13,358
  statements of the compiler are run by the corpus, and the count may not grow.
  Unlike `procedure-coverage` it is a ratchet rather than an allowlist, which
  `doc/sop.md` §7 records as the weaker instrument.
- `pascalc`'s command-line error paths are tested — an unknown option, a missing
  `-o` or `--import` operand, two input files, none. Nothing had ever run them,
  and the gate that counts diagnostics is blind to them by construction: it
  filters `pascalc: ` messages out as driver output.
- **`procedure-coverage`**, a `ctest` case that measures how much of the
  compiler the corpus enters — 554 of 556 procedures — and fails when a
  procedure stops being entered *or* when one argued unreachable starts being.
  It instruments the emitted IR with clang's SanitizerCoverage, which is
  possible only because the backend is textual (ADR-0103).
- **`tests/dumps/`**, five cases and a harness for `--dump-tokens`,
  `--dump-ast`, `--dump-sema` and `--dump-all`. No case in the corpus had ever
  passed any of them, so nothing checked they did not crash.
- **`tests/extended/schema_simple_body.pas`**, for a schema whose body is a
  simple type (`counter(limit: integer) = integer`). Every schema in the corpus
  produced an array or a record, leaving the one place a type is copied rather
  than interned exercised by nothing.
- `pascalc -h` is now checked to document every flag `ParseArgs` accepts —
  derived from the parser rather than compared against a golden, since the two
  agreeing is the thing worth knowing. It was a manual release-checklist step.
- Each function in the emitted IR carries a comment naming the Pascal procedure
  it came from and the line it starts on, which is what makes `-S` output
  readable and what the coverage mapping reads.

### Removed

- `StrIsLit`, which had no callers.

## [1.1.1] — 2026-08-15

A patch release: one crash fixed, and the rest is what looks for the next one.
The language is unchanged — no new syntax, no new flag, and nothing a working
program does differently.

### Fixed

- **A `for` statement inside another loop no longer exhausts the stack.** Both
  forms of the statement claimed storage on *every iteration of the loop around
  them*, so a long-running nested loop compiled with `-O0` died on a stack
  overflow. Programs built at the default `-O2` were never affected: LLVM
  hoists an alloca whose address does not escape, and the leak disappears with
  it. The answer computed was correct either way — the program simply ran out
  of stack first, which is why 495 tests, the validation suite, the SMT proofs
  and the stage-2/stage-3 fixed point were all green over it. (ADR-0102)
- **`verify/`'s model of `succ` and `pred` described the compiler v1.1.0
  replaced.** It claimed a subrange runs out at its own last value, where
  §6.7.1 makes it the host's — so `succ(9)` of a `1..9` is 10 and not an error.
  No proof failed and none could: those rules prove the *model* against the
  *specification*, and neither touches the compiler. The one check that does
  compare them exercised `succ` on enumerations alone, which is the single
  ordinal type where the wrong reading and the right one agree.

### Added

Nothing a program can use. Everything here exists to make the next defect of
these kinds fail a test instead of shipping.

- **The whole corpus now runs at `-O0` as well as `-O2`**, in CI and on demand
  with `AFTERSCHOOL_PASCAL_OPT=-O0 ctest`. A `name.opt` sidecar pins a single
  case's level where a sweep would hide what it is testing, and the test
  harness bounds the stack so a storage leak can actually fail something.
- **`diagnostic-coverage`**, a test that every message the compiler can write
  is named by some golden. Counting them found 32 unreached at once; 26 cases
  were written, and the remaining four are argued unreachable in
  `tests/checks/unreachable_diagnostics.txt` and commented at their branches.
  It fails in both directions — an entry that later acquires a golden is as
  loud as a message with none.
- **`model-drift`**, a CI check that a change to the code generator either
  changes `verify/` or says in its commit message why it need not.
- **`doc/sop.md`** and the `change-lifecycle` skill: the standard operating
  procedure, organised around what each oracle in this repository *cannot* see,
  with a live register of what is still unchecked.

## [1.1.0] — 2026-08-15

**A conformance release, and the first one that refuses programs 1.0.0
compiled.** The language did not grow: no syntax was added and no flag. What
changed is that thirty conformance defects were found and fixed, and most of
them are rules the compiler was not enforcing — so a program relying on one now
gets a diagnostic where it used to get a binary. **Read "Changed" before
upgrading**; it lists every construct that stops compiling and, for each, what
to write instead.

None of this was found by a test failing. The BSI Pascal Validation Suite was
adopted as a test case (ADR-0086) and disagreed with the compiler on its first
run; ADR-0085 had retired the differential oracle in 1.0.0, and this release is
what filled the hole it left — first with the suite, then with an adversarial
re-reading of the compiler's own interpretations (ADR-0101).

### Added

- **A licence.** GPLv3-or-later, `Copyright (C) 2026 Hui-Hong You`, with a
  linking exception on the runtime: `runtime/pasrt.c` is linked into every
  program this compiler builds, and without the exception compiling an ordinary
  Pascal program would place that program under the GPL. It does not — see
  `COPYING.RUNTIME`. The compiler itself carries no exception. The BSI
  validation suite and the standards under `doc/vendor/` are neither ours nor
  distributed, and `tests/bsi/README.md` states BSI's own three conditions.
- **`tests/bsi`** — the BSI Pascal Validation Suite 5.7 (© 1982 British
  Standards Institution) as a `ctest` case. The suite is **fetched, not
  committed** (`tests/bsi/fetch.sh`), and the case skips when it is absent.
  Running it is **not a validation**; see `tests/bsi/README.md` for BSI's terms.
- **`.github/workflows/ci.yml`** — build and test on every push in two minimal
  containers, which is what checks that the build needs `cmake`, `make` and
  `clang` and nothing of LLVM's. A third job fetches the validation suite and
  runs it, since the case skips wherever nobody has fetched it — which was
  every container, leaving the newest oracle running only on a developer's
  machine.
- **`.claude/skills/langspec-audit`** — the procedure that produced ADR-0101:
  independent readers given the compiler's behaviour and not its reasoning, and
  told to prove it wrong from the standards text. It exists because no oracle in
  this repository can contradict a *misreading* — the goldens agree with
  whoever wrote them, and the validation-suite catalogue records what this
  compiler does.

### Fixed

Every entry changes what an **already-valid program** does, and none was found
by a test failing: the BSI Pascal Validation Suite was adopted as a test case
and disagreed with the compiler on the first run (ADR-0086).

- **A program may declare its own `write`** — or `read`, `readln`, `writeln`,
  and under `--std=extended` `readstr` and `writestr`. ISO 7185 §6.2.2.10 puts
  the required identifiers in a region enclosing the program and §6.6.4.1 is
  the procedures' half of it, so a declaration in the program hides one, as it
  already did for every other required procedure. `write(i)` in a program
  declaring `procedure write(var a: integer)` used to run the required `write`
  and report nothing; it now calls the one the program declared. This also
  makes `write := 5` an assignment where it was a syntax error, and lets a
  declared `write` be passed as a procedural parameter, which §6.6.3.7 refuses
  only for the required one. (ADR-0087)
- **A name used in a block may no longer be declared in it.** ISO 7185
  §6.2.2.9 requires a defining-point to precede every applied occurrence of its
  identifier in the region it belongs to, and this compiler enforced that only
  where the name resolved to nothing. Where it resolved to an enclosing
  declaration the earlier uses kept the outer meaning and the later declaration
  took effect from its own position — one name with two meanings in one block,
  reported by nothing. Ordinary shadowing is unaffected: a block that declares
  a name it had not already used is legal and always was. §6.2.2.9's own
  exception, a pointer domain naming a type defined later in its own
  type-definition-part, is exempt. (ADR-0088)
- **A pointer's domain binds to a type of its own type-definition-part.**
  ISO 7185 §6.2.2.9's one exception says the domain-type may name a type
  defined later in "the type-definition-part containing the defining-point of
  the type-identifier" — so an enclosing type of the same spelling does not
  settle it, the inner one still being possible further down. Such a name was
  resolved where it stood, so a pointer meant the outer type and every use of
  it was a type error. Found by the validation suite's CONF027.
- **`dispose` takes an expression**, where §6.6.5.3 gives `new` a variable and
  `dispose` "the identifying-value denoted by the expression q" — so
  `dispose(f(p))` is a conforming statement and was refused. The nil written
  back into the pointer afterwards still happens wherever there is a variable
  to write it into. Its diagnostic now names what it found and no longer says
  "variable". Found by CONF129.
- **Three programs the standard requires to be rejected now are.** ISO 7185
  §6.6.6.3 gives `trunc` and `round` a parameter of real-type, so an integer is
  no longer accepted and widened; §6.10 requires the program-parameter
  identifiers to be distinct; and §6.4.3.3 puts the `;` before a variant-part
  inside the production rather than the brackets, so a record without it is a
  syntax error. None was written by any program in this corpus, which is why
  all three had gone unnoticed.
- **`reset` appends an end-of-line to a text file that does not end in one.**
  ISO 7185 §6.6.5.2's post-assertion requires it whenever the contents are not
  empty and do not already end in one, and this compiler did not: a program
  reading back a file it wrote without a final `writeln` reached end-of-file
  where a line should have ended, and `eoln` there stopped the program with a
  run-time error instead of answering `true`. An empty file still gains
  nothing, the clause requiring the contents to be non-empty. Found by the
  validation suite's CONF067 and CONF078.
- **`rewrite` of an ordinary file puts it back at the start of a line**, so a
  `page` straight after one no longer writes a blank line before its form feed
  (§6.9.5). `rewrite(output)` is unchanged and must be: it discards nothing.
- **`succ` and `pred` on a subrange run out at the *host's* bounds**, not the
  subrange's. ISO 7185 §6.6.6.4 gives the result "the same type as that of the
  expression (see 6.7.1)", and §6.7.1 says "any factor whose type is S, where S
  is a subrange of T, shall be treated as if it were of type T". So `succ` of a
  `1..9` holding 9 is now `10` where it used to stop the program; storing that
  result back into the subrange is still an error, and is where the check
  always belonged.
- **A `for` statement whose body never executes no longer checks its bounds.**
  §6.8.3.9 requires them to be assignment-compatible with the control
  variable's type *"if the statement of the for-statement is executed"*, so
  `for i := maxint to maxint - 1 do` over an `i : 0..10` is a legal program with
  an empty loop. It used to stop with a range error. A loop that does run checks
  its bounds exactly as before.
- **`writestr(s)` with nothing to write is reported.** ISO/IEC 10206:1991
  §6.7.5.5 requires at least one write-parameter after the string-variable; the
  statement had been impossible to write, so the check for it existed only on
  the ordinary `write` path, and it compiled and wrote nothing.
- **A `readstr` missing its string no longer demands `input`.** It reads from a
  string and from no file, so the diagnostic named a rule the program was not
  breaking.
- **A program-parameter declared after a procedure is now bound.** Under
  `--std=extended` a variable-declaration-part may follow a procedure (§6.2.1),
  and the pass that binds program-parameters ran once, before the first body —
  so anything declared later was never bound and `binding(f)` reported nothing.
  It now binds at each procedure declaration and reports once the declarations
  are complete; every program that does not interleave is unaffected, the two
  passes collapsing into the single one that was there before. (ADR-0100)
- **A procedure body sees only what precedes it** under `--std=extended`
  (§6.2.2.9). Every variable of a block used to exist before any body was
  checked, whatever the source order, so a body could read a variable declared
  after it. `--std=iso7185` was never affected: §6.2.1's fixed order refuses it
  a clause earlier. (ADR-0100)
- **A diagnostic names a required type by its own name.** `integer`, `real`,
  `char`, `boolean` and `text` became symbols in this release (ADR-0097), and
  without an alias the message for a mismatch printed the type's structure
  instead of the word the program wrote.
- **The compiler no longer runs out of string space compiling itself.** The
  lexer interns every *occurrence* of every identifier and literal into one
  fixed array, which grows with the size of the source; the compiler is its own
  largest input and had reached 74 characters under the bound. Raised from
  440,000 to 700,000 and the seed refreshed to match — the seed carries the old
  bound, so this was the one change that could not wait for a release tag.
  A large program that failed with *"out of string space"* now compiles.
  (ADR-0095)

### Changed

#### Programs that used to compile and no longer do

Each of these is a rule the standard states and this compiler was not applying.
The construct compiled and ran; it now produces a diagnostic. They are ordered
by how likely they are to appear in code somebody has already written.

- **A `for` statement's control variable may not be *threatened*** — assigned
  to, passed as an actual `var` parameter, read into, or used as the control
  variable of a nested `for` — anywhere in the block, "including any
  procedure-and-function-declaration-part of the block" (ISO 7185 §6.8.3.9).
  **This is the entry most likely to reject working code**: a block-level
  counter that any procedure in the same block assigns is now refused, even
  when that procedure is never called from the loop and even when it is never
  called at all. Give the loop a variable nothing else writes. (ADR-0089)
- **A variant part's labels must be exactly the values of its tag-type** — no
  value outside the type, and none of the type left unnamed (§6.4.3.3). So
  `case tag: integer of 1: (…); 2: (…)` is now refused, because `integer` has
  other values. Write a tag-type that covers the arms (`type sel = 1..2`), or
  under `--std=extended` add an `otherwise` — which discharges coverage but
  never membership. This one looks over-strict and is not: BSI's DEV073 header
  records that its own test was *"reclassified from CONFORMANCE to DEVIANCE due
  to change in DP7185"*, so the permissive reading is pre-standard. (ADR-0096,
  audited in ADR-0101)
- **A `goto` may not jump into a branch, a loop body, a `with` body or a case
  arm.** §6.8.1 admits a label only where it is a statement of a
  *statement-sequence* containing the goto, and only a compound-statement, a
  repeat-statement and Extended Pascal's `otherwise` completer hold one. Two
  labels at the same depth in different branches of one `if` used to be mutually
  reachable. (ADR-0094, with the completer in ADR-0101)
- **A name used in a block may not then be declared in it** (§6.2.2.9) — see
  "Fixed" below; this was enforced only where the name resolved to nothing, and
  now covers the case where it resolved to an enclosing declaration.
- **A required identifier may be declared away, and then means what the program
  said.** `integer`, `ord`, `text` and the rest are now symbols in a region
  enclosing the program (§6.2.2.10), so `type integer = char` takes effect. The
  reverse also holds: a name that resolves to something *not invocable* no
  longer falls back to the required function of the same spelling, so a program
  declaring `var ord: array [1..3] of integer` can no longer also call
  `ord('a')` — §6.2.2.11 forbids one identifier denoting two things in one
  block. Required *procedures* are still not symbols. (ADR-0097, ADR-0101)
- **Inside a record's declaration a field name denotes the field** (§6.4.3.3
  makes the record-type a region), so a pointer domain spelled like a field of
  that record — or of any record it is written inside — no longer finds the type
  of that name. (ADR-0098)
- **An actual `var` parameter may not denote a component of a packed variable,
  the selector of a variant part, or a component of a string-type** (§6.6.3.3;
  the third sentence is ISO/IEC 10206:1991 §6.7.3.3 and reaches variable-strings).
  Packing does **not** propagate inward: `pa[1].f` over a `packed array of rec`
  is still legal, because `pa[1]` possesses an unpacked record. (ADR-0099,
  ADR-0101)
- **A set-type's packing decides compatibility** (§6.4.5 c). `set of boolean`
  and `packed set of false..true` are no longer compatible. A set-*constructor*
  is exempt and always was — §6.7.1 leaves it uncommitted — so `p := [true]`
  fits either. (ADR-0093)
- **A string-type is four properties at once** (§6.4.3.2): packed, an integer
  subrange index, a smallest index *value* of 1, and a component that is `char`
  and not a subrange of one. ISO 7185 adds a largest value above 1;
  ISO/IEC 10206:1991 §6.4.3.3.2 drops that clause and nothing else. An array
  meeting only some of these is no longer treated as a string. (ADR-0090)
- **A value parameter's type may not contain a file** (§6.6.3.2) — the check
  asked whether the type *was* a file, so a record or array holding one was
  copied. (ADR-0092)
- **An actual `var` parameter may not be written `(x)`** (§6.5.1 lists no
  parenthesised variable-access). The parser had been discarding the brackets,
  so `p((x))` and `p(x)` were the same tree. (ADR-0092)
- **Congruity is over parameter *sections*, not parameters** (§6.6.3.6), so
  `(var a, b: integer)` and `(var a: integer; var b: integer)` are not congruous
  and a procedural parameter may not be passed where the other is expected.
  (ADR-0092)
- **A `forward` directive must follow a heading, not a procedure-identification**
  (§6.6.1); the compiler recognised the resumption and never looked at the
  directive. (ADR-0091)
- **A pointer's domain-type must be declared** even in a block with no type
  part (§6.4.4) — the check ran only when a run of type definitions ended, so
  such a program kept an unknown domain in silence. (ADR-0091)
- **A separator is required between a number and a following identifier,
  word-symbol or number** (§6.1.10), so `1two` is no longer two tokens. Only the
  decimal form: an extended-digit sequence is maximal, a letter being a digit
  there. (ADR-0091)
- **A parameterless function identifier is not a pointer-variable** (§6.5.4), so
  `f^` where `f` is a function is refused. ADR-0056's parser gate cannot see this
  shape — a parameterless call is a bare identifier — so Sema decides it.
  (ADR-0091)
- **An assignment to a function identifier must be inside that function**
  (§6.8.2.2 says *contain*), so a sibling procedure assigning another function's
  result is refused. A procedure *nested* inside the function may still do it,
  and always could. (ADR-0094)

#### Documentation of what is not enforced

- **`doc/implementation-defined.md` §6 lists the programs this compiler accepts
  that the standard requires to be rejected**, grouped by cause, where it had
  named none of them. Clause 5.1 c) requires them to be documented and the
  largest — §6.2.2.9's rule that a defining-point precedes every applied
  occurrence in its region — accounts for nine on its own.
- **`doc/implementation-defined.md` §3 names eight more unreported errors** —
  ISO 7185's D.5, D.6, D.12, D.13, D.19, D.27, D.30 and D.48. Nothing about the
  compiler changed: each had been unenforced since the feature it belongs to
  landed, and the section had been written one feature at a time with nothing
  reading Annex D end to end against it. It is now keyed to Annex D and
  regenerable — every `ERROR` row of `tests/bsi/expected.tsv` carries the
  number it names — and it says which two entries stop the suite's own programs
  without being enforced.

## [1.0.0] — 2026-08-14

**The toolchain stands on its own.** v0.1.0 said the number would reach 1.0.0
"when the toolchain stands on its own, not when the language does" — and this is
that release. `selfhost/compiler.pas` is the only compiler, `seed/pascalc.ll`
builds it, and a clone with no C++ compiler and no LLVM development files
compiles the compiler, passes 435 tests, reaches the stage-2/stage-3 fixed point
and proves 43 SMT rules.

The language is unchanged from 0.1.0 — both standards were already complete. The
major version is about what it takes to build this, and about `pascalc-s0`
disappearing from the command line.

### Removed

- **Stage 0, the C++ compiler.** `src/` and `selfhost/difftest.sh` are deleted;
  `selfhost/compiler.pas` is the only compiler. `seed/pascalc.ll` — a working
  compiler in LLVM IR, committed — is what builds it, so a checkout still builds
  itself. (ADR-0085)
- **LLVM as a build dependency.** Nothing links `libLLVM`; `cmake` needs no
  `LLVM_DIR`, only `clang` on PATH to assemble IR.
- The differential test, which compared two independent implementations over 436
  sources. Nothing replaces it, and ADR-0085 says what that costs.

### Added

- **`tools/pascalcc`** — compile *and* link. `pascalc` writes IR and stops,
  permanently: no standard Pascal program can start an assembler.
- `--dump-tokens`, `--dump-ast`, `--dump-sema`, `--dump-all` on `pascalc`, and
  157 error-path sources adopted as real test cases with `.err` goldens, taking
  the suite from 279 to 435.

### Changed

- **`pascalc` is quiet on success** and writes `file:line:col: error: message`
  on failure, where it used to write three dump sections unconditionally.
- The repository is **x86-64 Linux only**: the seed carries a target triple.
  Tag `v0.1.0` is the last commit where a C++ compiler could reproduce a
  compiler from source alone.

### Fixed

- `cmake --build` left a stale `build/bin/pascalc` when the compiler failed to
  build, so `ctest` passed against a compiler that did not match the source.
- A fresh configure could not create `build/bin` once no C++ executable target
  remained.
- `selfhost/badparse/variant-in-variant.pas` had been accepted by both compilers
  since ADR-0026 and was no longer a negative test; a differential oracle cannot
  see a test that has stopped testing anything. Deleted — the feature is covered
  by `tests/nested_variants.pas`.

## [0.1.0] — 2026-08-14

The first versioned release. It is `0.y.z` rather than `1.0.0` deliberately:
the language is complete and the bootstrap closes, but `pascalc-s0` is still
what builds `pascalc`, no seed is checked in, and `pascalc` cannot link. The
number will reach 1.0.0 when the toolchain stands on its own, not when the
language does.

### Added

- **The whole of ISO 7185 Standard Pascal**, under `--std=iso7185` (the
  default): procedures and functions nested to any depth with `forward`,
  procedural and functional parameters; arrays, records, variant parts, sets,
  pointers and recursive types; enumerations, subranges, `case` and `with`;
  text files with the buffer variable `f^`, and `file of T`; `goto`, including
  the non-local form out of a block into an enclosing one; `pack`, `unpack` and
  `page`; and string constants.
- **The whole of ISO/IEC 10206:1991 Extended Pascal**, under `--std=extended`.
  The two are *not* nested — Extended Pascal reserves word-symbols a valid ISO
  7185 program may use as identifiers — so the standard is a property of the
  source. Among what it adds: `otherwise` in a case statement and in a variant
  part; exponentiation (`**` and `pow`); non-decimal literals; schema types and
  discriminated schemata; schematic and protected parameters; type inquiry;
  initial-state specifiers (`value`); `complex`; direct-access files; the
  `string` schema, substrings, `readstr` and `writestr`; restricted types;
  structured-value and set-value constructors; constant-accesses; binding
  (`bind`, `unbind`, `binding`); time stamps; short-circuit `and then` and
  `or else`; `for … in` over a set; modules with `export`/`import`; and §6.13's
  separately translated program-components.
- **`pascalc`, the compiler written in Afterschool Pascal.** `cmake --build`
  produces it by translating `selfhost/compiler.pas` with `pascalc-s0`. It
  compiles itself: stage 2 equals stage 3, so the source is a fixed point.
- **A command line for `pascalc`** — `-o`, `--std=`, `--import`, `--version`,
  `-h` — read through the binding of its own program-parameters, which is the
  only channel either standard gives a program to its arguments.
- **`--version`** on both compilers.
- **Formal verification** (`verify/`): 43 SMT rules proving the lowering
  against a property-style statement of the standard, 27 of them for every
  32-bit input, with no known gaps.
- **`doc/implementation-defined.md`**, the document clause 5.1 requires: the
  compliance level (**level 0**), every implementation-defined and
  -dependent feature of both standards' annexes, every error not reported, and
  the extensions and restrictions.

### Changed

- **`halt` accepts an optional exit status**, an extension: `halt(1)` was a
  compile-time error before, so no conforming program is affected, and a bare
  `halt` still exits 0. Neither standard models an exit status, and without one
  a compiler written in Pascal cannot report failure. (ADR-0084)
- **`selfhost/compiler.pas` is written in Extended Pascal**, where it was
  ISO 7185. This changes nothing about the language the compiler *accepts*.
  (ADR-0082)

### Fixed

Every entry here changes what an already-valid program does, and each was found
by compiling a probe for a clause rather than by a test failing.

- **A program-parameter is bindable** (§6.5.1) and **`binding(p)` reports the
  argument it was bound to** (§6.7.6.8). Both were unimplemented: `binding` on
  a program-parameter was refused at compile time, and a bound one reported
  `false` with an empty name.
- **`unbind` clears the binding made before the program started.** It left a
  program-parameter reporting `argv[0]` afterwards.
- **`BindingType.name` is the same type as a program's own `string(255)`.** It
  was built outside the schema intern table, so §6.4.8's identity rule failed
  for it and it could not be passed to `procedure p(var s: string)`.
- **`i mod j` with a negative `j` is an error** (§6.7.2.2), as the constant
  folder had always said and the emitted code had not.
- **`ln`, `sqrt`, `x/y` and `dispose(nil)`** report the errors Annex D names,
  where they had returned a value.
- **A `for` statement's control variable must be declared in the block that
  contains the statement** (§6.8.3.9).
- **A comment may be closed by either delimiter** (§6.1.8): `{ … *)` is one
  comment, and was two loops that could not.
- **`reset(input)` no longer discards a character** the stream had consumed.
- **A field width of zero** writes what §6.10.3 says for each type — three
  different answers, not one — and a width below a string's length truncates
  it, in both standards.
- **`char + char`** is a two-character string (§6.8.3.6).
- **Declaration parts have an order under `--std=iso7185`** (§6.2.1) and may
  interleave under `--std=extended` (§6.2.1, §6.2.2.9).
- **A constant may not be selected from under ISO 7185**, §6.8.8 belonging to
  the next standard; and **`f()` is refused in both**, Pascal having no empty
  argument list.
- **`const q = nil`** is accepted under `--std=extended` (§6.7.1).
- Crashes fixed: a designator rooted at a `with` binding over a heap variable,
  and both dumps on a source declaring only modules.

### Known limitations

- `pascalc` writes LLVM IR and **does not link** — neither standard has process
  control, so assembling is a separate `clang` step. `pascalc-s0` links.
- Conformant array parameters (§6.6.3.6 e), §6.6.3.7, §6.6.3.8) are not
  accepted; this is a **level 0** processor.
- Twelve command-line arguments and eight `--import`s are the limits of
  `pascalc`; both report rather than truncate.
- Twelve errors go unreported, each named in `doc/implementation-defined.md`.
- No binary release: `pascalc-s0` links `libLLVM`, needs `clang` on `PATH`, and
  finds `libpasrt.a` through a baked-in path.

[3.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v3.1.0
[3.0.1]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v3.0.1
[3.0.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v3.0.0
[2.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v2.1.0
[2.0.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v2.0.0
[1.8.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.8.0
[1.7.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.7.0
[1.6.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.6.0
[1.5.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.5.0
[1.4.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.4.0
[1.3.1]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.3.1
[1.3.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.3.0
[1.2.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.2.0
[1.1.1]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.1.1
[1.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.1.0
[1.0.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.0.0
[0.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v0.1.0
