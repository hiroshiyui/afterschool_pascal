{ Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
  Copyright (C) 2026 Hui-Hong You
  
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 3 of the License, or (at your option)
  any later version.
  
  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.
  
  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <https://www.gnu.org/licenses/>. }

program Compile(output,
                arg1, arg2, arg3, arg4, arg5, arg6,
                arg7, arg8, arg9, arg10, arg11, arg12,
                arg13, arg14, arg15, arg16, arg17, arg18,
                arg19, arg20, arg21, arg22, arg23, arg24,
                arg25, arg26, arg27, arg28, arg29, arg30,
                arg31, arg32, arg33, arg34, arg35, arg36,
                arg37, arg38, arg39, arg40, arg41, arg42,
                arg43, arg44, arg45, arg46, arg47, arg48,
                arg49, arg50, arg51, arg52, arg53, arg54,
                arg55, arg56, arg57, arg58, arg59, arg60,
                arg61, arg62, arg63, arg64, arg65, arg66,
                arg67, arg68, arg69, arg70, arg71, arg72,
                argOver);

{ The compiler's third program-component: the code generator, and the driver
  that runs the pipeline over a command line. It holds the main-program-block,
  so it is the one that can be linked; ApTypes and ApFront are translated
  before it and imported by it (ADR-0233).

  ADR-0024 made the compiler one source file because neither standard had an
  include mechanism. ADR-0053 gave the language modules and ADR-0079 gave it
  6.13's separately translated program-components, so that reason expired; what
  the split buys is that the compiler's own build now translates a module
  alone, translates a module that imports another, and links the result. That
  was a row in doc/sop.md 7 -- nothing here linked a component and checked the
  result -- and it had already cost a defect.

  The driver cannot be anywhere else. 6.5.1 makes every program-parameter
  possess "the bindability that is bindable" and 6.7.6.8's NOTE 2 makes
  binding(f) report the binding made before activation, so `binding(argk).name`
  is argument k (ADR-0081) -- and a *module*-parameter is bound to nothing,
  which 6.11.1's NOTE 6 permits. Probed rather than assumed: with one argument
  passed, the program sees it and a module sees an unbound parameter.

  The code generator writes textual LLVM IR and links nothing (ADR-0085), which
  is what makes seed/*.ll possible. Three things follow from writing text
  instead of building a module, and each shapes the emitter below.

  * The emitter is *sequential*. It never returns to a basic block it has left,
    so the order it emits in is the order text can be printed in, and no
    instruction list is needed.

  * A global cannot be written in the middle of a function, so the string
    constants a program needs -- every runtime-error message, every file name,
    every string literal -- are given a number where they are used and their
    text is written after the last function. LLVM resolves the forward
    reference.

  * Types print structurally and inline: a Pascal type can only contain itself
    through a pointer, and opaque pointers make every pointer `ptr`. Activation
    records are the exception -- one would be spelled at every variable access
    -- so those get a name apiece, emitted before any function that uses one. }

import ApTypes; ApFront;

const
  { How many directories an import name may be looked for in (ADR-0244). The
    source's own directory is the first and is always there, so this is that
    one plus the --import-path flags plus the AFTERSCHOOL_PASCAL_PATH entries.

    It is *not* derived from argMax the way maxImports is, and the reason is
    worth writing down: a --import-path costs two words of the command line
    and shares the budget ADR-0235 sized for imports, but the environment
    variable costs none at all -- so the flag is the fallback and the variable
    is the route that scales. Going over is reported here rather than
    silently dropping a directory (ADR-0110). }
  maxPaths = 32;
  { The capacity AFTERSCHOOL_PASCAL_PATH is read into. Not pathStr, which is
    the bound on one *path*: a list of them is longer by however many there
    are, and ADR-0123 makes a value that does not fit the capacity an error --
    so reading a list into a one-path string would turn a long variable into a
    trap rather than a diagnostic.

    This comment named the hazard, named the number, and stopped one step
    short of asking whether the number was right for one path either. It was
    not: ADR-0291. }
  envMax = 8192;

type
  { What getenv answers, or nothing. A C pointer that may be null is an
    optional (ADR-0123), and the characters are copied at the call site. }
  envText = string(envMax);
  optEnvText = ?envText;
  { ADR-0293: a source position a trap may name -- see posHead. }
  posConstPtr = ^posConstRec;
  posConstRec = record
    id, line, col: integer;
    next: posConstPtr
  end;

{ The one foreign name this compiler binds (ADR-0244). It is ISO C, it is
  where every operating system keeps what a user configured, and there is no
  other way for a program to be told where it was installed: a
  program-parameter is a *file* (6.5.1), and a compiler that must be told its
  library path on every command line has not been installed anywhere. }
function ExtGetenv(name: string): optEnvText; external 'getenv';

var
  { The command line. ISO 7185 gives a program no access to it beyond its
    program-parameters, and those are files -- which is what made this compiler
    take four positional files and no flags for as long as it was an ISO 7185
    source (ADR-0033).

    ISO/IEC 10206:1991 gives a way. 6.5.1 makes every program-parameter possess
    "the bindability that is bindable" whatever its type-denoter says, and
    6.7.6.8's NOTE 2 makes binding(f) report "the result of any binding of
    program-parameters prior to activation of the main program" -- so the
    *name* each of these was bound to is the corresponding argument, and none of
    them is ever opened. An unbound one is how the list ends, there being no
    other way to count them (ADR-0081, ADR-0082).

    `argMax` is the limit on how many arguments this compiler can be given, and
    it is a real limit rather than a notional one: a program-parameter list is
    written out, so the count is fixed when the compiler is compiled.

    It was twelve, and twelve was not headroom: `tests/dialect/lib_os.pas` has
    four program-components, so `--std=afterschool`, eight `--import` words, a
    source, `-o` and a file name are exactly twelve. One more flag -- and
    ADR-0156's `--target=` is one -- pushed a *correct* command line past the
    end, where it was silently truncated and then reported as "-o needs a file
    name", an accusation against the last argument that arrived rather than the
    first that did not.

    It was raised a second time, from twenty-four, and by a caller rather than
    by an accident: `lsp/pasls.pas` imports ten modules, which is twenty-three
    words before a flag is written, and `maxImports` was eight. The two bounds
    move together and the comment on `argMax` in ApTypes says why.

    `argOver` is how that stops being silent. Nothing can count the arguments
    -- an unbound parameter is the only end-of-list there is -- so a compiler
    with argMax parameters cannot tell argMax from argMax + 9. One *extra*
    program-parameter can: it is bound exactly when there was an argument with
    nowhere to go, and ParseArgs reports rather than truncating. It is never
    read for its name. }
  arg1, arg2, arg3, arg4, arg5, arg6: text;
  arg7, arg8, arg9, arg10, arg11, arg12: text;
  arg13, arg14, arg15, arg16, arg17, arg18: text;
  arg19, arg20, arg21, arg22, arg23, arg24: text;
  arg25, arg26, arg27, arg28, arg29, arg30: text;
  arg31, arg32, arg33, arg34, arg35, arg36: text;
  arg37, arg38, arg39, arg40, arg41, arg42: text;
  arg43, arg44, arg45, arg46, arg47, arg48: text;
  arg49, arg50, arg51, arg52, arg53, arg54: text;
  arg55, arg56, arg57, arg58, arg59, arg60: text;
  arg61, arg62, arg63, arg64, arg65, arg66: text;
  arg67, arg68, arg69, arg70, arg71, arg72: text;
  argOver: text;
  { The tuple `new` is building, for as long as it has nowhere to live: the
    block it will sit in front of is what the tuple is being used to size.
    Nil everywhere else, and that is what makes it safe for BoundValue to
    consult -- outside `new` a heap variable's bounds are only ever in its
    header. }
  newTuple: discValPtr;
  { The command line, once read. }
  srcName, outName: pathStr;
  importCount: integer;
  { Where an `import` name is looked for when no --import supplied it
    (ADR-0244). Three sources, in this order: the directory the source being
    compiled is in, each --import-path in the order written, and each entry of
    AFTERSCHOOL_PASCAL_PATH. The first is what makes a checkout work with no
    configuration at all; the third is Turbo Pascal's unit directories by
    another name, and is why this compiler reads an environment variable at
    all -- a compiler that can be put anywhere has to be *told* where its
    library went, and a flag alone would mean telling it on every line.

    Directories only. A name resolves to `<dir>/<folded name>.pas` and to
    nothing else, which is the convention every module in this tree already
    follows and the only thing a search can be built on without opening every
    file in the directory to see what it declares. }
  pathCount: integer;
  pathDir: array [1..maxPaths] of pathStr;
  { Which entries of importName have been read, so a cycle in the import graph
    is a diagnostic from Sema rather than a compiler that does not return, and
    so a component named twice is read once. It is indexed the same way
    importName is, and resolution *appends* to that array -- a name resolved
    to a file becomes an import like any other, which is what keeps one path
    through the reader instead of two. }
  wasRead: array [1..maxImports] of boolean;
  { Whether there is anything to translate, and whether the command line was
    *wrong* -- which are different questions, because -h answers the first with
    no and the second with no as well. }
  argsOk, argsBad: boolean;
  { Which stages to dump, if any. Dumping is *off* by default: a compiler is
    quiet when it succeeds. It was on unconditionally for as long as there
    were two compilers to compare, because the dumps were what
    selfhost/difftest.sh diffed and there was no second binary to select a mode
    on (ADR-0025) -- and that reason expired with stage 0, twice over now that
    ADR-0232 has retired difftest itself.

    `dumping` decides the diagnostic format as well as the sections. Inside a
    dump a diagnostic is `line col error message`, which is the format the two
    compilers agreed on while there were two; outside one it is
    `file:line:col: error: message`, which is what a person reads and what
    tests/*.err holds. }
  dumpTokensOpt, dumpAstOpt, dumpSemaOpt, dumpAllOpt: boolean;
  { --dump-symbols: every name this source declares, for a tool rather
    than for a person (ADR-0239). It stops after the parse, as --dump-ast
    does, and it is deliberately not a section of --dump-all: an outline
    is wanted for a source Sema would reject, and --dump-all runs the
    whole pipeline. }
  dumpSymbolsOpt: boolean;
  { --dump-words: the vocabulary, which is a property of *this compiler* and
    not of the source it was handed (ADR-0301). It goes through ApFront's
    `WantWords` rather than being read where the other dumps are read, because
    the answer is written where the required identifiers are installed -- and
    it is asked of a source only because a compiler is asked of a source. }
  dumpWordsOpt: boolean;
  dumpStmtsOpt: boolean;
  { --dump-imports: the program-components this translation read, in
    activation order, for the build tool that has to translate and link them
    (ADR-0244). It stops after the parse, as --dump-symbols does, and for the
    same kind of reason: what a caller wants is the *list*, and a source Sema
    would reject still has one. }
  dumpImportsOpt: boolean;
  { --dump-uses: every applied occurrence in this source and the defining-point
    it resolved to (ADR-0246). It is the first dump that needs *Sema* -- an
    outline is the parser's and a definition is not -- and so the first that
    had to say what it does about a file that does not check. It dumps
    anyway: Sema accumulates diagnostics rather than stopping at the first,
    so a source with three mistakes has resolved everything else correctly,
    and an editor asks where a name is declared exactly while the file is
    being edited into shape. }
  dumpUsesOpt: boolean;
  { --dump-limits: how full the two arrays sized for this compiler's own source
    are (ADR-0148). Not a fifth member of the set above and deliberately not a
    section of --dump-all -- those three sections were what
    selfhost/difftest.sh diffed against the reference front end, which had no
    such arrays, so a fourth would have been a disagreement on every file in
    the corpus. The harness is gone (ADR-0232) and the separation is kept: the
    reason below stands on its own.

    It is also the one dump that is not of a stage. The pool is filled by Sema
    and by CodeGen as well as by the lexer, so the question it answers has an
    answer only after the whole pipeline has run: it stops nothing, and it runs
    everything. `dumping` therefore excludes it, a diagnostic during a limits
    run being for a person to read and keeping the file:line:col form. }
  dumpLimitsOpt: boolean;
  { --dump-predicates: what each type-classifying predicate answers about a
    type of each kind (ADR-0194). Needs nothing of the source but is a dump
    like the others, so it runs the whole pipeline and reports after it. }
  dumpPredsOpt: boolean;
  { --dump-trivia: 6.1.8's comments, which the lexer discarded until ADR-0279.
    It stops after the **lexer**, which is one stage earlier than any other
    dump that stops: a comment is lexical and nothing after the scanner has
    ever seen one, so neither the parse nor Sema could change the answer. It
    exists on its own because the trivia is a fact about the source worth
    being able to ask for, and because a formatter that got a comment wrong
    would otherwise be debuggable only by reading its output. }
  dumpTriviaOpt: boolean;
  { --format: the source written back out with a layout of this compiler's own
    (ADR-0279). Not a dump -- what it writes is a *program* and not a report
    about one -- but it stops where a dump does and for the same reason: it
    needs the tokens and the comments and nothing a later stage knows.

    It is deliberately not `-o`: a formatter that could overwrite its input
    is one bad exit away from an empty source file, and a shell redirection
    says what is being replaced where a reader can see it. }
  formatOpt: boolean;
  rangeLo, rangeHi: integer;
  { Which target the emitted module states, 1..tgtCount. Default x86-64: it is
    what the seed was generated for and what this repository is built and
    tested on. }
  targetIx: integer;
  { --coverage: emit a call to pas_cov_hit before every statement, carrying the
    line it begins on (ADR-0104), and a call to pas_cov_branch on each edge of
    every decision the source writes (ADR-0274). What is *executable* is
    decided here and nowhere else -- the runtime counts what it is told and
    the denominator is read back out of the emitted IR, so the two halves of a
    coverage figure come from one artefact and cannot disagree about what was
    instrumented. }
  covOpt: boolean;
  nextReg, nextBlock: integer;   { SSA values and basic blocks, per function }
  { Which way the designator being addressed is used (ADR-0118). vgWrite only
    while EmitAssign is taking its target's address; EmitExpr saves and clears
    it, so a subscript or a call argument *inside* a target is read like any
    other expression while the spine that reaches the field stays a write. }
  designatorGuard: integer;
  curBlock: integer;             { the block being filled, for a phi's label }
  { The string arena's level at this function's entry (ADR-0111). A string
    value's life is one statement, and the runtime cannot see when one ends, so
    the release is emitted here: this value is read once in the prologue --
    where it dominates every block, an SSA value and not an alloca (ADR-0102)
    -- and stored back wherever a statement has finished with what it took. }
  strBase: str;
  { How many arena allocations EmitString has written, ever. Only differences
    are read: a statement took storage exactly when this moved while it was
    being emitted. Counting is what keeps the question off a predicate over the
    tree -- the emitter already knows what it emitted, and a predicate would be
    a second opinion free to drift from it. }
  strTemps: integer;
  nextProcId, nextStr: integer;
  irProc: symPtr;                { the procedure being emitted }
  irLevel: integer;
  { The level-0 block the function being emitted belongs to: the program, or
    the module a procedure was declared in. It is what FrameAt(0) names, since
    a level-0 record is a global rather than something to walk to. }
  irRoot: symPtr;
  strHead, strTail: strConstPtr;
  { ADR-0293: the positions a running program may be asked to name. One
    record per bracketed runtime call, written after the last function as
    `@at.N`, holding the address of `@at.file`, the line and the column;
    translation's source path, written once. One record per call and no
    cache: a statement's calls mostly name *different* positions -- each
    write-parameter its own, the writeln the statement's -- and remembering
    the last one hit once in the 2747 brackets of apfront.pas. }
  posHead, posTail: posConstPtr;
  nextPos: integer;
  { 6.13: the storage, procedures and modules this component names and another
    one defines, each declared once at the end of the module. }
  externVars, externVarTail: symListPtr;
  externProcs, externProcTail: symListPtr;
  externMods, externModTail: symListPtr;
  { The storage of the 6.8.7 constants, in the order they were first named.
    Deferred to the end of the module exactly as the string constants are. }
  constHead, constTail: constGlobalPtr;
  nextConst: integer;
  { AP 6.4.14's release routines, in the order their first call was written. }
  ownRels, ownRelTail: ownRelPtr;
  nextOwnRel: integer;
  labelBlocks: labelBlockPtr;

{ Argument k of the command line, or false when there is no such argument.

  6.7.6.8's binding(f) answers for a program-parameter the same question it
  answers for a file the program bound itself: whether it is bound, and to what.
  6.12 binds the program-parameters before the program is activated, so `bound`
  is false exactly for the positions no argument reached -- which is what makes
  a *variable* number of arguments readable from a *fixed* parameter list.

  The case statement is the whole cost of the approach: a program-parameter is a
  name, not a subscript, so there is no way to say "the k'th". One arm each, and
  argMax + 1 of them: the last is the sentinel that makes an over-long command
  line detectable rather than silently short. }
function Arg(k: integer; var s: pathStr): boolean;
var b: BindingType;
begin
  b.bound := false;
  case k of
    1:  b := binding(arg1);
    2:  b := binding(arg2);
    3:  b := binding(arg3);
    4:  b := binding(arg4);
    5:  b := binding(arg5);
    6:  b := binding(arg6);
    7:  b := binding(arg7);
    8:  b := binding(arg8);
    9:  b := binding(arg9);
    10: b := binding(arg10);
    11: b := binding(arg11);
    12: b := binding(arg12);
    13: b := binding(arg13);
    14: b := binding(arg14);
    15: b := binding(arg15);
    16: b := binding(arg16);
    17: b := binding(arg17);
    18: b := binding(arg18);
    19: b := binding(arg19);
    20: b := binding(arg20);
    21: b := binding(arg21);
    22: b := binding(arg22);
    23: b := binding(arg23);
    24: b := binding(arg24);
    25: b := binding(arg25);
    26: b := binding(arg26);
    27: b := binding(arg27);
    28: b := binding(arg28);
    29: b := binding(arg29);
    30: b := binding(arg30);
    31: b := binding(arg31);
    32: b := binding(arg32);
    33: b := binding(arg33);
    34: b := binding(arg34);
    35: b := binding(arg35);
    36: b := binding(arg36);
    37: b := binding(arg37);
    38: b := binding(arg38);
    39: b := binding(arg39);
    40: b := binding(arg40);
    41: b := binding(arg41);
    42: b := binding(arg42);
    43: b := binding(arg43);
    44: b := binding(arg44);
    45: b := binding(arg45);
    46: b := binding(arg46);
    47: b := binding(arg47);
    48: b := binding(arg48);
    49: b := binding(arg49);
    50: b := binding(arg50);
    51: b := binding(arg51);
    52: b := binding(arg52);
    53: b := binding(arg53);
    54: b := binding(arg54);
    55: b := binding(arg55);
    56: b := binding(arg56);
    57: b := binding(arg57);
    58: b := binding(arg58);
    59: b := binding(arg59);
    60: b := binding(arg60);
    61: b := binding(arg61);
    62: b := binding(arg62);
    63: b := binding(arg63);
    64: b := binding(arg64);
    65: b := binding(arg65);
    66: b := binding(arg66);
    67: b := binding(arg67);
    68: b := binding(arg68);
    69: b := binding(arg69);
    70: b := binding(arg70);
    71: b := binding(arg71);
    72: b := binding(arg72);
    { argMax + 1: bound only when an argument had nowhere to go. }
    73: b := binding(argOver);
    otherwise
  end;
  if b.bound then s := b.name else s := '';
  Arg := b.bound
end;

{ ADR-0156's table of targets, read one way and written the other. Zero for a
  spelling that is not one of them -- `--target=` then reports and names what is
  admitted, because a target whose layout has not been compared against LlSize
  and LlAlign would be answered wrongly rather than refused. }
{ `L:H`, two decimal line numbers, and a bad one is *reported* rather than
  quietly taken for the whole file. Silently widening would be the friendlier
  guess and the wrong one: a caller asking for lines 5 to 2 has a bug, and a
  whole document arriving where a fragment was asked for is the kind of answer
  that gets diagnosed as an editor fault.

  One test decides it, so one message covers every way of getting it wrong --
  a letter in it, no colon, a zero, or the ends the wrong way round. }
procedure ParseRange(protected var spec: pathStr);
var i, v, lo: integer; ok: boolean;
begin
  lo := 0; v := 0; ok := length(spec) > 0;
  for i := 1 to length(spec) do
    if spec[i] = ':' then
      if lo = 0 then begin lo := v; v := 0 end else ok := false
    else if (spec[i] >= '0') and (spec[i] <= '9') then
      v := v * 10 + (ord(spec[i]) - ord('0'))
    else ok := false;
  if ok and (lo > 0) and (v >= lo) then begin
    rangeLo := lo;
    rangeHi := v
  end
  else begin
    writeln('pascalc: --range wants L:H, two line numbers with H at least L');
    { Both, and they are not the same thing: `argsOk` stops the parse, which
      is what `-h` and `--version` want, and `argsBad` is what makes the exit
      status say the command line was wrong. }
    argsOk := false;
    argsBad := true
  end
end;

function TargetIndex(protected var name: pathStr): integer;
begin
  if EQ(name, 'x86_64-pc-linux-gnu') then TargetIndex := tgtX86
  { Both spellings, because they name one machine and a reader will type
    whichever the toolchain does: `aarch64-linux-gnu` is the Debian package and
    the cross compiler's prefix, and `aarch64-unknown-linux-gnu` is what clang
    normalises it to. The *emitted* one is clang's, so that assembling the
    module raises no -Woverride-module; x86_64-pc-linux-gnu needs no such pair,
    being canonical already. }
  else if EQ(name, 'aarch64-linux-gnu') or
          EQ(name, 'aarch64-unknown-linux-gnu') then TargetIndex := tgtAarch64
  else TargetIndex := 0
end;

procedure TargetName(ix: integer; var name: pathStr);
begin
  case ix of
    tgtX86: name := 'x86_64-pc-linux-gnu';
    tgtAarch64: name := 'aarch64-linux-gnu'
  end
end;

procedure Version;
begin
  writeln('pascalc (Afterschool Pascal) ', apVersion)
end;

procedure Usage;
begin
  writeln('Afterschool Pascal -- the compiler, written in Afterschool Pascal');
  writeln('usage: pascalc [options] file.pas');
  writeln('  -o <file>       where to write the LLVM IR');
  writeln('                  (the source name with .ll, by default)');
  writeln('                  (the dialect: Extended Pascal and what is');
  writeln('                  added to it)');
  writeln('  --import <f>    a program-component already translated; its');
  writeln('                  module-headings supply this one''s interfaces');
  writeln('  --import-path <d>  where to look for an interface no --import');
  writeln('                  gave: <d>/<name>.pas, folded. The source''s own');
  writeln('                  directory is searched first and always, and');
  writeln('                  AFTERSCHOOL_PASCAL_PATH is searched after these');
  writeln('  --dump-tokens   write the token stream and stop');
  writeln('  --dump-ast      write the parse tree and stop');
  writeln('  --dump-sema     write the tree Sema annotated and stop');
  writeln('  --target=<t>    which machine the emitted module states it is');
  writeln('                  for: x86_64-pc-linux-gnu (default) or');
  writeln('                  aarch64-linux-gnu');
  writeln('  --dump-all      write all three, with section headers');
  writeln('  --dump-dispatch compile as usual, then write every');
  writeln('                  case-statement that dispatches on an');
  writeln('                  enumeration, and how many of its constants');
  writeln('                  the labels name');
  writeln('  --dump-layout   compile as usual, then write the size,');
  writeln('                  alignment and field offsets of every');
  writeln('                  record type the source defines');
  writeln('  --dump-limits   compile as usual, then write how full the');
  writeln('                  compiler''s own fixed arrays were left');
  writeln('  --dump-predicates  what each type predicate answers about');
  writeln('                  a type of each kind');
  writeln('  --dump-imports  write the program-components this source needs,');
  writeln('                  in the order they must be activated, and stop');
  writeln('  --format        write this source back out with the');
  writeln('                  compiler''s own layout, and stop');
  writeln('  --range=L:H     with --format, write only lines L to H,');
  writeln('                  indented as they stand in the whole file');
  writeln('  --dump-trivia   write every comment this source holds, with');
  writeln('                  its position and the token it precedes, and stop');
  writeln('  --dump-symbols  write every name this source declares, with');
  writeln('                  its kind, position and nesting, and stop');
  writeln('  --dump-words    write every word-symbol and required identifier');
  writeln('                  this compiler knows, and stop');
  writeln('  --dump-stmts    write where every statement of this source');
  writeln('                  begins and ends, and stop');
  writeln('  --dump-uses     check as usual, then write every name this');
  writeln('                  source uses and where it was declared');
  writeln('  --coverage      emit statement and branch counters; the');
  writeln('                  program then writes the lines it ran to');
  writeln('                  PASCOV_LINES and the branch directions it');
  writeln('                  took to PASCOV_BRANCHES');
  writeln('  --version       write the version and stop');
  writeln('  -h, --help      write this list and stop');
  writeln;
  writeln('It writes LLVM IR to the file -o names, diagnostics to standard');
  writeln('output, and nothing else unless a --dump flag asks for it. It does');
  writeln('not link: no standard Pascal program can start another, so');
  writeln('assembling what it wrote is a separate step --');
  writeln;
  writeln('  clang out.ll libpasrt.a -lm -o prog');
  writeln;
  writeln('tools/pascalcc does both, and takes the same flags.')
end;

{ The command line, read once at the start.

  Every flag is an exact word and every value is the argument after it, which
  is `pascalc-s0`'s shape and is what lets the whole of this be equality on
  strings. EQ rather than `=` because 6.8.3.5's operators pad the shorter
  operand with spaces and 6.7.6.7's EQ compares the lengths too: `-o` and
  `-o ` are not the same flag. }
procedure ParseArgs;
var k: integer; a: pathStr; dot: integer; k2: integer; tname: pathStr;
begin
  srcName := '';
  outName := '';
  importCount := 0;
  pathCount := 0;
  for k := 1 to maxImports do
    wasRead[k] := false;
  argsOk := true;
  argsBad := false;
  dumpTokensOpt := false;
  dumpAstOpt := false;
  dumpSemaOpt := false;
  dumpAllOpt := false;
  dumpLimitsOpt := false;
  dumpTriviaOpt := false;
  formatOpt := false;
  rangeLo := 0;
  rangeHi := 0;
  dumpPredsOpt := false;
  dumpLayoutOpt := false;
  dumpSymbolsOpt := false;
  dumpWordsOpt := false;
  dumpStmtsOpt := false;
  dumpImportsOpt := false;
  dumpUsesOpt := false;
  dumpDispatchOpt := false;
  dispatchHead := nil;
  dispatchTail := nil;
  enumHead := nil;
  enumTail := nil;
  chainHead := nil;
  chainTail := nil;
  tagHead := nil;
  tagTail := nil;
  targetIx := tgtX86;
  covOpt := false;
  { Before anything is parsed: an argument past the last program-parameter is
    invisible to the loop below, which ends at the first unbound one. Reporting
    it here is the difference between "this command line is too long" and a
    complaint about whichever flag happened to land in the last slot. }
  if Arg(argMax + 1, a) then begin
    writeln('pascalc: more than ', argMax:1, ' arguments');
    argsOk := false;
    argsBad := true
  end;
  k := 1;
  while Arg(k, a) and argsOk do begin
    if EQ(a, '--dump-tokens') then dumpTokensOpt := true
    else if EQ(a, '--dump-ast') then dumpAstOpt := true
    else if EQ(a, '--dump-sema') then dumpSemaOpt := true
    else if EQ(a, '--dump-all') then begin
      dumpAllOpt := true;
      dumpTokensOpt := true;
      dumpAstOpt := true;
      dumpSemaOpt := true
    end
    else if EQ(a, '--dump-limits') then dumpLimitsOpt := true
    else if EQ(a, '--dump-trivia') then dumpTriviaOpt := true
    else if EQ(a, '--format') then formatOpt := true
    { AP: `--range L:H`, the inclusive line span --format is to print. The
      formatter accumulates its own indentation as it walks the token stream,
      so what a range needs is not a parse but the state the walk already has
      when it arrives -- the lines before the range are walked with the sink
      turned off. }
    else if (length(a) > 8) and EQ(substr(a, 1, 8), '--range=') then begin
      tname := substr(a, 9, length(a) - 8);
      ParseRange(tname)
    end
    else if EQ(a, '--dump-predicates') then dumpPredsOpt := true
    else if EQ(a, '--dump-layout') then dumpLayoutOpt := true
    else if EQ(a, '--dump-symbols') then dumpSymbolsOpt := true
    else if EQ(a, '--dump-words') then dumpWordsOpt := true
    else if EQ(a, '--dump-stmts') then dumpStmtsOpt := true
    else if EQ(a, '--dump-imports') then dumpImportsOpt := true
    else if EQ(a, '--dump-uses') then dumpUsesOpt := true
    else if EQ(a, '--dump-dispatch') then dumpDispatchOpt := true
    else if EQ(a, '--coverage') then covOpt := true
    { ADR-0156. Joined to its flag, unlike -o and --import, which take file
      names a shell completes. }
    else if (length(a) > 9) and EQ(substr(a, 1, 9), '--target=') then begin
      tname := substr(a, 10, length(a) - 9);
      k2 := TargetIndex(tname);
      if k2 = 0 then begin
        writeln('pascalc: unknown target ', tname);
        write('pascalc: this compiler emits for ');
        for k2 := 1 to tgtCount do begin
          if k2 > 1 then write(' and ');
          TargetName(k2, tname);
          write(tname)
        end;
        writeln;
        writeln('pascalc: another target needs its layout compared against ',
                'LlSize and LlAlign first -- see doc/roadmap.md');
        argsOk := false;
        argsBad := true
      end
      else targetIx := k2
    end
    else if EQ(a, '-h') or EQ(a, '--help') then begin
      Usage;
      argsOk := false;
      srcName := ''
    end
    else if EQ(a, '--version') then begin
      Version;
      argsOk := false;
      srcName := ''
    end
    else if EQ(a, '-o') then begin
      k := k + 1;
      if not Arg(k, outName) then begin
        writeln('pascalc: -o needs a file name');
        argsOk := false;
        argsBad := true
      end
    end
    else if EQ(a, '--import-path') then begin
      k := k + 1;
      if pathCount >= maxPaths then begin
        writeln('pascalc: more than ', maxPaths:1, ' import directories');
        argsOk := false;
        argsBad := true
      end
      else if not Arg(k, a) then begin
        writeln('pascalc: --import-path needs a directory name');
        argsOk := false;
        argsBad := true
      end
      else begin
        pathCount := pathCount + 1;
        pathDir[pathCount] := a
      end
    end
    else if EQ(a, '--import') then begin
      k := k + 1;
      if importCount >= maxImports then begin
        writeln('pascalc: more than ', maxImports:1, ' --import arguments');
        argsOk := false;
        argsBad := true
      end
      else if not Arg(k, a) then begin
        writeln('pascalc: --import needs a file name');
        argsOk := false;
        argsBad := true
      end
      else begin
        importCount := importCount + 1;
        importName[importCount] := a
      end
    end
    else if length(a) > 0 then
      if a[1] = '-' then begin
        writeln('pascalc: unknown option ', a);
        argsOk := false;
        argsBad := true
      end
      else if length(srcName) > 0 then begin
        writeln('pascalc: more than one input file given');
        argsOk := false;
        argsBad := true
      end
      else srcName := a;
    k := k + 1
  end;

  if argsOk and (length(srcName) = 0) then begin
    Usage;
    argsOk := false;
    argsBad := true
  end;

  dumping := dumpTokensOpt or dumpAstOpt or dumpSemaOpt or dumpAllOpt;

  { A warning is written on an ordinary compile and never into a dump
    (ADR-0272). Every --dump flag is named, and not `dumping` alone: that one
    answers *which format a diagnostic takes* and covers four of the twelve,
    where the question here is whether anything at all may be added to what a
    reader is parsing. `kind-exhaustive` reads --dump-dispatch and stopped on
    the first warning ever written. }
  warnOn := not (dumpTokensOpt or dumpAstOpt or dumpSemaOpt or dumpAllOpt
                 or dumpSymbolsOpt or dumpWordsOpt or dumpStmtsOpt
                 or dumpUsesOpt
                 or dumpImportsOpt or dumpDispatchOpt or dumpPredsOpt
                 or dumpLayoutOpt or dumpLimitsOpt or dumpTriviaOpt
                 or formatOpt);

  { The lexer keeps 6.1.8's comments only where something asked (ADR-0279).
    --dump-limits is in this list and not merely in the one above, because
    measuring how full the two trivia bounds were left is the whole of what
    that flag is for and it can measure nothing that was never filled. }
  keepTrivia := dumpTriviaOpt or dumpLimitsOpt or formatOpt;

  { The default output is the source with its extension replaced, which is the
    one piece of name arithmetic here. A source with no dot gets .ll appended
    rather than being refused. }
  if argsOk and (length(outName) = 0) then begin
    dot := length(srcName);
    while (dot > 0) and (srcName[dot] <> '.') do dot := dot - 1;
    if dot > 0 then outName := substr(srcName, 1, dot) + 'll'
    else outName := srcName + '.ll'
  end
end;

{ Bind a file variable to a name the command line gave. 6.7.5.6's bind is the
  only way a program names a file while it is running, and this compiler could
  not have been written without it: every name below was computed. }
procedure BindTo(var f: bindText; protected var n: pathStr);
var b: BindingType;
begin
  b := binding(f);
  if b.bound then unbind(f);
  b.name := n;
  bind(f, b)
end;

{ ========================================================================== }
{ CodeGen -- the annotated tree, written out as textual LLVM IR.

  ADR-0006 kept the textual backend a first-class output precisely so that this
  component could exist: a compiler written in Pascal cannot call LLVM's C++
  API, so what survives the rewrite is the assembler text.

  Three things follow from writing text instead of building a module.

  * The emitter is *sequential*. It works because the C++ builder never returns
    to a basic block it has left: every SetInsertPoint moves to a block that is
    then filled to its terminator. So the order the C++ emits instructions in
    is exactly the order they can be printed in, and no instruction list is
    needed here at all.

  * A global cannot be written in the middle of a function, so the string
    constants a program needs -- every runtime-error message, every file name,
    every string literal -- are given a number when they are used and their
    text is written after the last function. LLVM resolves the forward
    reference.

  * Types are printed structurally, inline. A Pascal type can only contain
    itself through a pointer, and opaque pointers make every pointer `ptr`, so
    nothing here is recursive and no named type is needed. The activation
    records are the exception -- one is printed at every variable access, and a
    frame with forty slots would be forty slots of text each time -- so those
    get a name apiece, emitted before any function that uses one. }
{ ========================================================================== }

{ ------------------------------------------------------------- LLVM types }

procedure PutLlType(t: typePtr); forward;
procedure PutStructAt(rec: typePtr; path: numPtr); forward;

{ LLVM has no union, so the variant part is one block of storage. The element
  type is what carries the alignment: [k x i64] is 8-aligned where [n x i8]
  would be 1-aligned and would misalign a real inside a variant. }
procedure PutStorageTypeAt(rec: typePtr; path: numPtr);
var size: int64; align: integer;
begin
  VariantStorageAt(rec, path, size, align);
  if size = 0 then
    write(ircode, '[0 x i8]')
  else
    write(ircode, '[', size div align:1, ' x i', align * 8:1, ']')
end;

{ One arm's own block, for AP 6.4.13.5's side-by-side form. No empty case
  where PutStorageTypeAt has one: that covers a program-written variant part
  whose arm holds no field, and the only arms ever laid apart are a
  fallible-type's, each of which holds exactly one. }
procedure PutArmTypeAt(rec: typePtr; path: numPtr; arm: integer);
var size: int64; align: integer;
begin
  ArmSlotAt(rec, path, arm, size, align);
  write(ircode, '[', size div align:1, ' x i', align * 8:1, ']')
end;

procedure PutStructAt;
var f: fieldPtr; first: boolean; v: variantPtr; i: integer;
begin
  write(ircode, '{ ');
  first := true;
  f := FieldsAt(rec, path);
  while f <> nil do begin
    if not first then write(ircode, ', ');
    PutLlType(f^.ftype);
    first := false;
    f := f^.next
  end;
  if ArmsAt(rec, path) <> nil then
    { AP 6.4.13.5 (ADR-0256): one block per arm where they are laid apart, and
      one shared block where they are laid over -- which is every variant part
      a program can write. }
    if rec^.armsApart then begin
      v := ArmsAt(rec, path);
      i := 0;
      while v <> nil do begin
        if not first then write(ircode, ', ');
        PutArmTypeAt(rec, path, i);
        first := false;
        i := i + 1;
        v := v^.next
      end
    end
    else begin
      if not first then write(ircode, ', ');
      PutStorageTypeAt(rec, path)
    end;
  write(ircode, ' }')
end;

procedure PutLlType;
var b: typePtr;
begin
  b := Base(t);
  if b = nil then
    write(ircode, 'void')
  else
    case b^.kind of
      tyVoid, tySubrange: write(ircode, 'void');
      { An enumeration is its ordinal number; a subrange is represented exactly
        as its host, which is what Base already looked through to. }
      tyInteger, tyEnum: write(ircode, 'i32');
      { ADR-0128, and the whole of what CodeGen knows about the type: it is
        twice an integer and nothing else about it is new. }
      tyInt64: write(ircode, 'i64');
      tyReal: write(ircode, 'double');
      tyBoolean: write(ircode, 'i1');
      tyChar: write(ircode, 'i8');
      tyPointer: write(ircode, 'ptr');
      { A file variable is an opaque block of storage the runtime owns; all the
        compiler needs is its size, and i64 elements give it the alignment a
        struct full of pointers needs. }
      tyFile: write(ircode, '[', fileSize div 8:1, ' x i64]');
      tyHandle: write(ircode, '[', handleSize div 8:1, ' x i64]');
      { Every set is the same 256-bit integer whatever its base type: one bit
        per possible member, which is what makes the operators single
        instructions and keeps a set a *value* (ADR-0028). }
      tySet: write(ircode, 'i', setBits:1);
      { A procedural parameter is a pair: the code to call, and the static link
        to call it with. Both halves are needed because a procedure passed as
        an argument carries the scope it was *declared* in, not the one it is
        called from -- which is the whole difficulty of the feature. }
      tyProc: write(ircode, '{ ptr, ptr }');
      { ADR-0125: the address of the first component, and how many there are. }
      tySlice: write(ircode, '{ ptr, i32 }');
      { ISO/IEC 10206:1991 6.4.2.2 e) makes `complex` a *simple* type, so it
        must be a value and not a thing reached through its address. A
        two-element vector is the one shape that is both: LLVM lowers it in
        registers, and neither backend has to hold an opinion about how a
        struct is passed -- which is the constraint ADR-0030 named and settled
        the same way. }
      tyComplex: write(ircode, '<2 x double>');
      tyRestricted: PutLlType(b^.elem);
      { 6.4.3.3.3: a variable-string-type's value is a length and that many
        characters. The layout is ADR-0045's -- a length beside a buffer whose
        capacity is the discriminant -- so a string whose capacity arrives with
        the actual is that record's flexible array member and DynSize needs no
        new case. }
      tyString, tyText: begin
        write(ircode, '{ i32, [');
        if b^.hi > 0 then write(ircode, b^.hi:1) else write(ircode, '0');
        write(ircode, ' x i8] }')
      end;
      { ADR-0123: a flag and the value it answers for. Printed structurally
        like everything else here, so an optional inside a record or an array
        needs no name of its own. }
      tyOptional: begin
        write(ircode, '{ i32, ');
        PutLlType(b^.elem);
        write(ircode, ' }')
      end;
      tyArray: begin
        { The bounds are folded away: an index is lowered to an offset from the
          lower bound, so the type only needs the extent. }
        write(ircode, '[', TypeLength(b):1, ' x ');
        PutLlType(b^.elem);
        write(ircode, ']')
      end;
      tyRecord: PutStructAt(b, nil)
    end
end;

{ ---------------------------------------------------------------- operands }

{ An operand is its text: `%v7`, `42`, `3.5`, `null`, `@s3`. Keeping it as text
  is what lets a constant be an operand without an instruction to materialise
  it, and ISO 7185 6.6.2 forbids a function returning a record, so these are
  filled through a var parameter rather than returned. }

procedure AppendInt(var s: str; v: int64);
var digits: array [1..24] of char; n, k: integer; negative: boolean;
begin
  negative := v < 0;
  n := 0;
  if negative then v := -v;
  if v = 0 then begin
    n := 1;
    digits[1] := '0'
  end;
  while v > 0 do begin
    n := n + 1;
    { AP 6.4.2.6.4's one narrowing, as PutHex8 does it: the remainder is
      0..9, so the error condition trunc carries cannot arise. }
    digits[n] := chr(ord('0') + trunc(v mod 10));
    v := v div 10
  end;
  if negative then StrAppend(s, '-');
  for k := n downto 1 do
    StrAppend(s, digits[k])
end;

procedure AppendLit(var s: str; w: msgLit);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    StrAppend(s, w[k])
end;

{ A pooled spelling into an IR name. The pool holds identifiers case-folded
  (the lexer folds as it accumulates), so a name built this way is the same
  however the two components spelled it -- which is what 6.13 needs of it. }
procedure AppendPool(var s: str; at, len: integer);
var k: integer;
begin
  for k := at to at + len - 1 do
    StrAppend(s, pool[k])
end;

{ 6.13's linkage name, the only kind of name two translations can agree on.
  Built from the module-heading alone: see NameForLinkage. }
procedure AppendLinkName(var s: str; sym: symPtr);
begin
  if sym^.linkKind = lnkStdIn then AppendLit(s, 'pas.input       ')
  else if sym^.linkKind = lnkStdOut then AppendLit(s, 'pas.output      ')
  { ADR-0121's foreign name is the one thing here this compiler did not
    compose: it names something translated by another language's processor,
    so there is no interface part and no prefix letter to add. }
  else if sym^.linkKind = lnkForeign then
    AppendPool(s, sym^.linkItemAt, sym^.linkItemLen)
  else begin
    if sym^.linkKind = lnkVar then StrAppend(s, 'v') else StrAppend(s, 'p');
    StrAppend(s, '.');
    AppendPool(s, sym^.linkIfaceAt, sym^.linkIfaceLen);
    StrAppend(s, '.');
    AppendPool(s, sym^.linkItemAt, sym^.linkItemLen)
  end
end;

{ The name of a procedure's LLVM function. Nesting allows two procedures of
  the same name in different parents, so ordinarily the name is a counter --
  but an *exported* one takes the linkage name instead, a counter being a fact
  about the order this translation walked the tree in and so unreproducible by
  the translation on the other side of a component boundary (6.13). }
procedure AppendProcName(var s: str; sym: symPtr);
begin
  StrAppend(s, '@');
  if (sym^.linkKind = lnkProc) or (sym^.linkKind = lnkForeign) then
    AppendLinkName(s, sym)
  else begin
    StrAppend(s, 'p');
    AppendInt(s, sym^.irId)
  end
end;

procedure OpInt(n: int64; var v: str);
begin
  StrClear(v);
  AppendInt(v, n)
end;

procedure OpWord(w: msgLit; var v: str);
begin
  StrClear(v);
  AppendLit(v, w)
end;

procedure OpReg(r: integer; var v: str);
begin
  StrClear(v);
  StrAppend(v, '%');
  StrAppend(v, 'v');
  AppendInt(v, r)
end;

procedure OpGlobal(id: integer; var v: str);
begin
  StrClear(v);
  StrAppend(v, '@');
  StrAppend(v, 's');
  AppendInt(v, id)
end;

procedure PutOp(protected var v: str);
var k: integer;
begin
  for k := 1 to v.len do
    write(ircode, v.ch[k])
end;

{ A pooled spelling straight into the IR. WritePool goes to the diagnostic
  sink; this is its counterpart for the compiler's product. }
procedure WritePoolIr(at, len: integer);
var k: integer;
begin
  for k := at to at + len - 1 do
    write(ircode, pool[k])
end;

{ 6.13: a module's two activation functions are named from the module, because
  the component that calls them holds the main-program-declaration and may be
  another translation.

  The **mode is part of that name**, and it is a check rather than decoration
  (ADR-0119). ADR-0118's two rules are a pair -- a write to a field activates
  its variant, a read of an inactive one traps -- and the pair holds only
  within one compilation, because each half is emitted at the access. Split
  them across components and the surviving half is worse than neither: a
  dialect component reading a variant maintained by a conformance-mode one runs
  its guard against a tag nothing ever stored, and *passes* the access. A check
  that answers `safe` for an unsafe read is the one outcome a safety feature
  may not have.

  So the components of one program must agree on the mode. Spelling it into the
  symbol they already have to agree on is what makes that refusal free: the
  program calls this name for every module it activates, so a mixture cannot
  reach an executable. It cannot be misdeclared either -- the name is written
  from the translation that is happening, not from anything a caller says. }
{ Eight hexadecimal digits of a number, low digit last. Written here rather
  than through `write(x:1)` because a digest is compared and never read, and
  hexadecimal keeps a 30-bit one to eight characters instead of ten. }
procedure PutHex8(v: int64);
const digits = '0123456789abcdef';
var i, j, d: integer; sh: int64;
begin
  for i := 7 downto 0 do begin
    sh := 1;
    for j := 1 to i do
      sh := sh * 16;
    { AP 6.4.2.6.4's one narrowing, and the digest is well inside integer --
      each half is below its modulus and each modulus below maxint -- so the
      error condition trunc carries cannot arise here. }
    d := trunc((v div sh) mod 16);
    write(ircode, digits[d + 1])
  end
end;

{ The digest of the heading that declares the module `p` names, from whichever
  component's node holds one (ADR-0245).

  By **name** and not by symbol, which is what makes 6.11.1's split form work:
  a component written as `module M implementation;` holds no heading of its
  own and reads one through --import, so the node with the digest is the
  imported one and the node being emitted is not. Both name the same module. }
procedure ModuleDigest(p: symPtr; var d1, d2: int64);
var m: nodePtr;
begin
  d1 := 0;
  d2 := 0;
  m := progModules;
  while m <> nil do begin
    if PoolSame(m^.mdAt, m^.mdLen, p^.at, p^.len) then
      { `mdHasHeading` and not a test on the digest itself: a hash may
        legitimately land on zero, and a node that holds no heading is the
        question being asked. }
      if m^.mdHasHeading then begin
        d1 := m^.mdDigest1;
        d2 := m^.mdDigest2
      end;
    m := m^.next
  end
end;

procedure PutModulePart(p: symPtr; init: boolean);
var d1, d2: int64;
begin
  write(ircode, '@m.');
  WritePoolIr(p^.at, p^.len);
  write(ircode, '.');
  { A fixed tag where ADR-0119 spelled the mode. There is one language since
    ADR-0232, so nothing here varies -- what the tag still buys is that an
    object left over from a release that *had* the modes fails to link with a
    name a reader can be told about (tools/pascalcc translates it), rather
    than linking and disagreeing about ADR-0118's pair of rules. }
  write(ircode, 'afterschool');
  { ...and the interface's own digest after it (ADR-0245). ADR-0119 put a fact
    the components of one program must agree on into the symbol they already
    have to agree on, and this is the same move for a second such fact: the
    program calls this name once per module it activates, so a component built
    from a *different heading* than the one the program was compiled against
    cannot reach an executable. It is the linker that checks, and it costs
    nothing to ask.

    Nothing to say is written as zeros, which happens only where the heading
    failed to parse -- and a translation that did not parse emits nothing to
    link. }
  write(ircode, '.');
  ModuleDigest(p, d1, d2);
  PutHex8(d1);
  PutHex8(d2);
  if init then write(ircode, '.init') else write(ircode, '.fini')
end;

{ Open an instruction line that defines a fresh value: `  %vN = `. }
procedure Def(var v: str);
begin
  nextReg := nextReg + 1;
  OpReg(nextReg, v);
  write(ircode, '  ');
  PutOp(v);
  write(ircode, ' = ')
end;

function NewBlock: integer;
begin
  nextBlock := nextBlock + 1;
  NewBlock := nextBlock
end;

procedure StartBlock(b: integer);
begin
  writeln(ircode, 'L', b:1, ':');
  curBlock := b
end;

{ Give back everything the string arena lent since this function was entered
  (ADR-0111). Correct at the end of any statement, because nothing a statement
  allocated outlives it: a string-valued function result is a variable-string
  and is copied into the caller's storage, never returned as a pointer into the
  arena. A callee's own statements restore the *callee's* level, which is above
  anything live in the caller, so the discipline nests without a stack of marks
  having to be kept anywhere. }
procedure ReleaseStrTemps;
begin
  write(ircode, '  store i32 ');
  PutOp(strBase);
  writeln(ircode, ', ptr @pas_str_at')
end;

{ The block a label denotes. Created on first mention, which may be either the
  labelled statement or a goto to it -- a forward jump reaches here before the
  statement it targets exists. }
function LabelBlock(id: integer): integer;
var p: labelBlockPtr;
begin
  p := labelBlocks;
  while (p <> nil) and (p^.lid <> id) do
    p := p^.next;
  if p = nil then begin
    new(p);
    p^.lid := id;
    p^.blk := NewBlock;
    p^.next := labelBlocks;
    labelBlocks := p
  end;
  LabelBlock := p^.blk
end;

{ ------------------------------------------------------- string constants }

{ A global cannot be written inside a function, so it is numbered here and its
  text written after the last one. }
function AddGlobal(at, len: integer): integer;
var g: strConstPtr;
begin
  new(g);
  nextStr := nextStr + 1;
  g^.id := nextStr;
  g^.at := at;
  g^.len := len;
  g^.next := nil;
  if strHead = nil then strHead := g else strTail^.next := g;
  strTail := g;
  AddGlobal := nextStr
end;

{ A runtime-error message is built before it is emitted, so the sink is turned
  round for the length of the building. }
procedure MsgStart;
begin
  msgOut := true;
  StrClear(msgBuf)
end;

procedure MsgText(w: textLit);
var n, k: integer;
begin
  n := textWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    StrAppend(msgBuf, w[k])
end;

function MsgEnd: integer;
var at: integer;
begin
  msgOut := false;
  at := PoolAdd(msgBuf);
  MsgEnd := AddGlobal(at, msgBuf.len)
end;

{ ADR-0293: a trap names the source position of the construct that trapped.
  These three are the whole of how a position reaches the running program.

  PutPos writes the position as three trailing arguments -- the file constant,
  the line and the column -- for a trap the emitter writes inline: the block
  is cold, the emitter holds the node, and the runtime formats the message
  with what it is handed. Nothing about it depends on state.

  EmitAt and EmitAtDone bracket a call into a runtime routine that may trap
  on its own -- a read, a file operation, a string store, `**`. The runtime
  knows nothing about the source, so a pointer to a position record is stored
  into its thread-local `pas_at` before the call and cleared after it. The
  clear is not tidiness: it is what makes a call this emitter forgot to
  bracket report *no* position rather than the previous call's, a wrong
  position being worse than none. A runtime routine that never returns
  (`pas_jump_go`) clears the word itself, for the same reason.

  The position is a record and not three stores because a bracket is paid on
  every call of a routine that can trap, which is most of them, and a store
  of one address is the least that can be paid. The record is a constant in
  the module, so it costs the program sixteen bytes of rodata and no code. }
procedure PutPos(line, col: integer);
begin
  write(ircode, ', ptr @at.file, i32 ', line:1, ', i32 ', col:1)
end;

function PosConst(line, col: integer): integer;
var g: posConstPtr;
begin
  new(g);
  nextPos := nextPos + 1;
  g^.id := nextPos;
  g^.line := line;
  g^.col := col;
  g^.next := nil;
  if posHead = nil then posHead := g else posTail^.next := g;
  posTail := g;
  PosConst := nextPos
end;

procedure EmitAt(line, col: integer);
begin
  writeln(ircode, '  store ptr @at.', PosConst(line, col):1, ', ptr @pas_at')
end;

procedure EmitAtDone;
begin
  writeln(ircode, '  store ptr null, ptr @pas_at')
end;

{ AP 6.4.16.4 (ADR-0302): a release the *program* wrote closes the channel.

  Two closers decide what happens when a channel-variable ceases to exist --
  the owner's marks it closed and drops its reference, a task's parameter's
  drops the reference and does not close, because a worker that has finished
  must not close the channel its colleagues are still draining. That answers
  the question whose variable is going away, and it is the wrong answer to the
  other one: a stage of a pipeline writing `release(out)` means *close it*,
  and before this it meant nothing at all -- the reference went down, the
  channel stayed open, and every reader downstream waited for ever with no
  diagnostic from anywhere (ADR-0295 finding 1).

  So the close is emitted where the program's release is, ahead of the release
  itself, and the closer that follows goes on doing exactly what it did. The
  slot's value is read with `pas_handle_peek` rather than `pas_handle_lend`
  because an empty handle-variable may be released and is not an error, which
  is the release's own rule; `pas_chan_shut` is null-safe for that reason. }
procedure EmitChanShut(protected var slot: str);
var v: str;
begin
  Def(v);
  write(ircode, 'call ptr @pas_handle_peek(ptr ');
  PutOp(slot);
  writeln(ircode, ')');
  write(ircode, '  call void @pas_chan_shut(ptr ');
  PutOp(v);
  writeln(ircode, ')')
end;

procedure PutHex(v: integer);
var d: integer;
begin
  d := v div 16;
  if d < 10 then write(ircode, chr(ord('0') + d))
  else write(ircode, chr(ord('A') + d - 10));
  d := v mod 16;
  if d < 10 then write(ircode, chr(ord('0') + d))
  else write(ircode, chr(ord('A') + d - 10))
end;

{ 6.13: what this translation names but another one defines. Each is recorded
  the first time it is reached and declared once at the end of the module,
  which is where this backend puts every global it deferred. The comparison is
  on the *linkage name's parts* rather than on the symbol, because an
  interface imported twice brings two symbols naming one variable. }
function SameLink(a, b: symPtr): boolean;
begin
  SameLink := (a^.linkKind = b^.linkKind) and
              (a^.linkIfaceAt = b^.linkIfaceAt) and
              (a^.linkIfaceLen = b^.linkIfaceLen) and
              (a^.linkItemAt = b^.linkItemAt) and
              (a^.linkItemLen = b^.linkItemLen)
end;

procedure NeedOne(var head, tail: symListPtr; s: symPtr);
var e: symListPtr; known: boolean;
begin
  known := false;
  e := head;
  while e <> nil do begin
    if SameLink(e^.sym, s) then known := true;
    e := e^.next
  end;
  if not known then AppendSym(head, tail, s)
end;

procedure NeedExternal(s: symPtr);
begin
  NeedOne(externVars, externVarTail, s)
end;

procedure NeedExternalProc(s: symPtr);
begin
  NeedOne(externProcs, externProcTail, s)
end;

{ Whether a foreign name is declared by an `external` heading this module
  calls -- asked by the closer declarations, which must not repeat one. }
{ Has an earlier entry already been declared under this linker name?

  AP 6.7.7.11 confines its one-declaration rule to a single program-component,
  so two components may each bind `strlen` -- and one of them may arrive here
  anyway: AP 6.7.3.10.2 translates an instantiation in the component that
  named the types (ADR-0212), so a generic whose body calls a foreign routine
  brings the *other* component's declaration into this module beside the one
  this component wrote. Two `declare`s of one global is what LLVM refuses,
  with an error naming a file nobody wrote -- ADR-0147's own words for it.

  The second is dropped here rather than the program being refused, which is
  where ADR-0263 moved the problem: Sema asks the clause's question about one
  component, and this asks the emitter's question about one module. Where two
  declarations disagree about the signature the first one written wins, which
  costs nothing that is not already true -- the `declare` a foreign heading
  emits is documentary and the call site is the whole of the ABI
  (`doc/sop.md` §7). }
function ForeignDeclaredBefore(upTo: symListPtr): boolean;
var e: symListPtr; found: boolean;
begin
  found := false;
  if upTo^.sym^.linkKind = lnkForeign then begin
    e := externProcs;
    while (e <> nil) and (e <> upTo) do begin
      if (e^.sym^.linkKind = lnkForeign) and
         PoolSame(e^.sym^.linkItemAt, e^.sym^.linkItemLen,
                  upTo^.sym^.linkItemAt, upTo^.sym^.linkItemLen) then
        found := true;
      e := e^.next
    end
  end;
  ForeignDeclaredBefore := found
end;

function ForeignDeclared(at, len: integer): boolean;
var e: symListPtr; found: boolean;
begin
  found := false;
  e := externProcs;
  while e <> nil do begin
    if (e^.sym^.linkKind = lnkForeign) and
       PoolSame(e^.sym^.linkItemAt, e^.sym^.linkItemLen, at, len) then
      found := true;
    e := e^.next
  end;
  ForeignDeclared := found
end;

procedure NeedExternalModule(m: symPtr);
var e: symListPtr; known: boolean;
begin
  known := false;
  e := externMods;
  while e <> nil do begin
    if e^.sym = m then known := true;
    e := e^.next
  end;
  if not known then AppendSym(externMods, externModTail, m)
end;

{ One character of a `c"..."` constant, escaped where LLVM's syntax needs it.
  Shared by the string constants and ADR-0293's file constant, so there is one
  spelling of the rule. }
procedure PutCChar(c: char);
begin
  if (c = '"') or (c = '\') or (ord(c) < 32) or (ord(c) >= 127) then begin
    write(ircode, '\');
    PutHex(ord(c))
  end
  else
    write(ircode, c)
end;

procedure EmitGlobals;
var g: strConstPtr; k: integer;
begin
  g := strHead;
  while g <> nil do begin
    write(ircode, '@s', g^.id:1, ' = private unnamed_addr constant [',
          g^.len + 1:1, ' x i8] c"');
    for k := g^.at to g^.at + g^.len - 1 do
      PutCChar(pool[k]);
    writeln(ircode, '\00"');
    g := g^.next
  end
end;

{ ADR-0293: the source path once, and one record per position a bracketed
  runtime call may name. The path is written straight from mainFile rather
  than through the pool, because a path may be pathMax characters (ADR-0291)
  and msgBuf holds strMax. }
procedure EmitPosGlobals;
var p: posConstPtr; k: integer;
begin
  write(ircode, '@at.file = private unnamed_addr constant [',
        length(mainFile) + 1:1, ' x i8] c"');
  for k := 1 to length(mainFile) do
    PutCChar(mainFile[k]);
  writeln(ircode, '\00"');
  p := posHead;
  while p <> nil do begin
    writeln(ircode, '@at.', p^.id:1,
            ' = private unnamed_addr constant { ptr, i32, i32 } ',
            '{ ptr @at.file, i32 ', p^.line:1, ', i32 ', p^.col:1, ' }');
    p := p^.next
  end
end;

{ The storage of the 6.8.7 constants. It is zeroed here and filled by the
  prologue of the block that defined each one -- a constructor's components are
  expressions, and this backend has no way to spell one as an LLVM initialiser
  (ADR-0069). }
procedure EmitConstGlobals;
var g: constGlobalPtr; k: integer;
begin
  g := constHead;
  while g <> nil do begin
    write(ircode, '@const.');
    for k := g^.at to g^.at + g^.len - 1 do
      write(ircode, pool[k]);
    write(ircode, '.', g^.id:1, ' = internal global ');
    PutLlType(g^.ctype);
    writeln(ircode, ' zeroinitializer');
    g := g^.next
  end
end;

{ -------------------------------------------------------- traps and checks }

{ ADR-0123: the address of an optional's flag (0) or of the value it answers
  for (1). One routine for both, because the only difference is the index and
  a second copy would be free to disagree about the layout. }
procedure OptionalPart(protected var base: str; t: typePtr; index: integer; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(base);
  writeln(ircode, ', i32 0, i32 ', index:1)
end;

procedure EmitTrapIf(protected var cond: str; msg, line, col: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_runtime_error_at(ptr @s', msg:1);
  PutPos(line, col);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ The same shape, for a trap whose message cannot be written here: the runtime
  formats it out of values only the running program has. }
procedure EmitTrapIndex(protected var cond, lo, hi: str; line, col: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_index_error_at(i32 ');
  PutOp(lo);
  write(ircode, ', i32 ');
  PutOp(hi);
  PutPos(line, col);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ And again for a store into a subrange whose bounds are discriminants
  (ADR-0133). Where they are constants the message names the *type*, which is
  what a program wrote and the more useful of the two; a bound evaluated at the
  block's commencement has no spelling to name, so this names its value -- the
  same trade EmitTrapIndex makes, and made here for the same reason. }
procedure EmitTrapRange(protected var cond, lo, hi: str; line, col: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_range_error_at(i32 ');
  PutOp(lo);
  write(ircode, ', i32 ');
  PutOp(hi);
  PutPos(line, col);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ And again for 6.7.2.5's equal-length requirement, where one of the lengths is
  a discriminant and neither is known until the program runs. }
{ No program reaches this, and tests/checks/uncovered_procedures.txt carries
  the argument: the guard that selects EmitStringCompare requires both operands
  to have static bounds, which is DynamicExtent being false, and the one other
  arm that calls it cannot be reached at all. Kept because relaxing that guard
  -- so two schematic char arrays may be compared -- is a feature, and this is
  the check it would need. }
procedure EmitTrapLength(protected var cond, left, right: str;
                         line, col: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_length_error_at(i32 ');
  PutOp(left);
  write(ircode, ', i32 ');
  PutOp(right);
  PutPos(line, col);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ The same shape again, for 6.4.6 d): the schema and the discriminant are named
  where the program is compiled and their values are known only where it runs,
  so the message is assembled out of two string constants and two integers. }
procedure EmitTrapDisc(protected var cond: str; schemaMsg, discMsg: integer;
                       protected var l, r: str; line, col: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_disc_error_at(ptr @s', schemaMsg:1,
        ', ptr @s', discMsg:1, ', i32 ');
  PutOp(l);
  write(ircode, ', i32 ');
  PutOp(r);
  PutPos(line, col);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ ------------------------------------------------------- the static chain }

{ The activation record `levels` deep in the static chain from here. The link
  is field 0 of every frame, so it sits at offset zero and can be loaded from
  the frame pointer without knowing which procedure's struct this level has. }
{ The one activation record of a level-0 block. The program and every module
  have exactly one activation each (6.2.3.6), and a module's has to outlive the
  function that fills it in -- so both are globals rather than allocas, and
  reaching one costs no walk at all (ADR-0053). }
procedure FrameGlobal(b: symPtr; var v: str);
begin
  StrClear(v);
  StrAppend(v, '@');
  AppendLit(v, 'frame           ');
  { 6.13: a module's record is named from the module rather than from a
    counter, because a call into the module takes its address as the static
    link and the counter is a fact about this translation's walk. The
    program's keeps the counter: nothing outside a program can name it. }
  if b^.isModuleSym then begin
    StrAppend(v, '.');
    AppendPool(v, b^.at, b^.len);
    if b^.compiledElsewhere then NeedExternalModule(b)
  end
  else
    AppendInt(v, b^.irId)
end;

procedure FrameAt(lev: integer; var v: str);
var l: integer; cur, nxt: str;
begin
  { A level-0 frame is a global, so there is nothing to walk to: the block
    this function belongs to is the one whose record it names. }
  if lev = 0 then begin
    FrameGlobal(irRoot, v)
  end
  else begin
  StrClear(cur);
  StrAppend(cur, '%');
  AppendLit(cur, 'frame           ');
  for l := irLevel downto lev + 1 do begin
    Def(nxt);
    write(ircode, 'load ptr, ptr ');
    PutOp(cur);
    writeln(ircode);
    cur := nxt
  end;
  v := cur
  end
end;

{ The activation record of a *block*: the program, a module, or a procedure.
  Asking the owner rather than the level is what lets a name imported from
  another module resolve -- its owner is that module, which is not on this
  block's static chain and does not need to be. }
procedure FrameOf(b: symPtr; var v: str);
begin
  if b^.level = 0 then FrameGlobal(b, v)
  else FrameAt(b^.level, v)
end;

{ AP 6.9.3.11: where this block's defer record sits. After the variables and
  after the jump record, for the jump record's own reason -- so that no frame
  index a name resolves to can move. The flags are the field after it, one i8
  per defer-statement, and they are the whole of what says which statements
  are armed. }
function DeferBase(p: symPtr): integer;
var k: integer;
begin
  k := 1 + p^.frameCount;
  if p^.nlLabels <> nil then k := k + 1;
  DeferBase := k
end;

procedure DeferRecord(p: symPtr; protected var frame: str; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', DeferBase(p):1)
end;

{ AP 6.9.3.12: where this block's task set sits -- after the defer record and
  its flags, which is after the jump record, which is after the variables. The
  rule is one rule said three times: a slot nothing in the source can name
  goes at the end, so no frame index a *name* resolves to can move. }
function TaskSetBase(p: symPtr): integer;
var k: integer;
begin
  k := 1 + p^.frameCount;
  if p^.nlLabels <> nil then k := k + 1;
  if p^.deferCount > 0 then k := k + 2;
  TaskSetBase := k
end;

procedure TaskSetSlot(p: symPtr; protected var frame: str; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', TaskSetBase(p):1)
end;

{ AP 6.9.3.15's descriptor array, which follows the task set for the reason
  the task set follows the defer record: a slot nothing in the source can name
  goes at the end. }
procedure SelectSlot(p: symPtr; protected var frame: str; var v: str);
var k: integer;
begin
  k := TaskSetBase(p);
  if p^.spawns then k := k + 1;
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', k:1)
end;

{ The wrapper emitted for a task, and the reason there is one. `pthread_create`
  takes a pointer to a C function of one argument, and a Pascal routine is a
  code-and-link pair (ADR-0030), so no procedure of the program can be handed
  to C -- ADR-0201's finding 4. What crosses instead is *this*, which the compiler emits: it
  unpacks an argument block the spawn filled and calls the task's body with the
  static link and the actuals. The Pascal side never names it.

  A dot keeps the name out of a program's reach, as the defer runner's does:
  ReservedForeignName refuses any foreign name containing one (ADR-0144). }
procedure PutTaskName(p: symPtr);
begin
  write(ircode, '@p', p^.irId:1, '.task')
end;

procedure DeferFlag(p: symPtr; protected var frame: str; k: integer; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', DeferBase(p) + 1:1, ', i32 ', k:1)
end;

{ The runner emitted for a block that defers. A dot is what keeps the name out
  of a program's reach: ReservedForeignName refuses any foreign name
  containing one, so no `external` declaration can collide with it (ADR-0144). }
procedure PutDeferName(p: symPtr);
begin
  write(ircode, '@p', p^.irId:1, '.defer')
end;

{ The jump record is the field after the last variable. Only called for a
  procedure whose nlLabels is non-empty. }
procedure JumpRecord(p: symPtr; protected var frame: str; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', 1 + p^.frameCount:1)
end;

procedure FrameSlot(s: symPtr; var v: str);
var f: str;
begin
  { 6.13: a frame index is a private fact of the translation that decided the
    layout, so a variable another component defines is reached by the name
    both ends computed from the module-heading, and nothing here is known
    about the storage except where it begins. }
  if s^.storageElsewhere then begin
    StrClear(v);
    StrAppend(v, '@');
    AppendLinkName(v, s);
    NeedExternal(s)
  end
  else begin
  FrameOf(s^.owner, f);
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', s^.owner^.irId:1, ', ptr ');
  PutOp(f);
  writeln(ircode, ', i32 0, i32 ', 1 + s^.frameIndex:1)
  end
end;

{ The descriptor a schematic formal parameter travels as: the address of the
  actual, and then its tuple, one discriminant per field in the schema's own
  order. Like the procedural pair it never exists as a value -- the parts are
  stored and loaded through their own getelementptrs and travel as separate
  arguments -- so a caller and a callee agree by both coming through here
  (ADR-0030's shape, and for the same reason). }
procedure PutDescType(param: symPtr);
var p: symListPtr;
begin
  write(ircode, '{ ptr');
  p := param^.descSchema^.discs;
  while p <> nil do begin
    write(ircode, ', ');
    PutLlType(p^.sym^.stype);
    p := p^.next
  end;
  write(ircode, ' }')
end;

{ The arguments one schematic formal parameter contributes: the address, and
  then the tuple, so the descriptor is assembled by the callee and never passed
  as a struct. }
procedure PutDescParamTypes(s: symPtr; named: boolean; var k: integer);
var p: symListPtr;
begin
  write(ircode, 'ptr');
  if named then write(ircode, ' %a', k:1);
  k := k + 1;
  p := s^.descSchema^.discs;
  while p <> nil do begin
    write(ircode, ', ');
    PutLlType(p^.sym^.stype);
    if named then write(ircode, ' %a', k:1);
    k := k + 1;
    p := p^.next
  end
end;

{ The frame variable at this index, which is what a discriminant's frameIndex
  names: the parameter whose slot holds the descriptor it is a field of. }
function FrameVarAt(p: symPtr; idx: integer): symPtr;
var l: symListPtr; k: integer;
begin
  l := p^.frameVars;
  k := 0;
  while (l <> nil) and (k < idx) do begin
    l := l^.next;
    k := k + 1
  end;
  if l = nil then FrameVarAt := nil else FrameVarAt := l^.sym
end;

procedure AddressOfSym(s: symPtr; var v: str);
var slot: str; param: symPtr;
begin
  { A discriminant lives inside the descriptor of the parameter it belongs to,
    so it is reached through that parameter's slot -- which means the walk up
    the static chain is the one every enclosing variable makes, and a recursive
    procedure sees the tuple of the invocation it is running in. }
  if s^.kind = skDisc then begin
    param := FrameVarAt(s^.owner, s^.frameIndex);
    FrameSlot(s, slot);
    Def(v);
    write(ircode, 'getelementptr inbounds ');
    PutDescType(param);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 ', 1 + s^.discIndex:1)
  end
  else begin
    FrameSlot(s, slot);
    { A schematic formal parameter's slot is its descriptor, and the variable is
      at the address its first field holds -- for a `var` parameter the actual,
      and for a value parameter the prologue's copy of it. A `var` parameter --
      and the binding of a `with` -- likewise holds an address, so the variable
      it stands for is one load further on. }
    if s^.descSchema <> nil then begin
      Def(v);
      write(ircode, 'getelementptr inbounds ');
      PutDescType(s);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode, ', i32 0, i32 0');
      slot := v;
      Def(v);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode)
    end
    else if s^.kind = skVarParam then begin
      Def(v);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode)
    end
    else
      v := slot
  end
end;

{ A bound of an array: a constant where the source wrote one, and otherwise the
  discriminant it names, read out of the descriptor. }
{ How many bytes the tuple of a heap variable occupies in front of it. Every
  discriminant is stored as an i32 whatever its own type, so the header is one
  number wide per discriminant -- and it is rounded up to 16 so that the
  variable itself keeps the alignment the allocator gave the block. 16 rather
  than 8 because a set is 256 bits and the target aligns one to 16 (ADR-0028). }
function HeaderSize(t: typePtr): integer;
var bytes, n: integer; d: symListPtr;
begin
  if (t = nil) or not t^.heapTuple or (t^.schema = nil) then
    HeaderSize := 0
  else begin
    n := 0;
    d := t^.schema^.discs;
    while d <> nil do begin
      n := n + 1;
      d := d^.next
    end;
    bytes := 4 * n;
    HeaderSize := ((bytes + 15) div 16) * 16
  end
end;

{ The address of a heap variable's tuple, given the variable's own address.
  Empty for every type whose tuple is somewhere a symbol can name. }
procedure HeaderOf(t: typePtr; protected var base: str; var v: str);
begin
  if (t = nil) or not t^.heapTuple then
    StrClear(v)
  else begin
    Def(v);
    write(ircode, 'getelementptr i8, ptr ');
    PutOp(base);
    writeln(ircode, ', i32 ', -HeaderSize(t):1)
  end
end;

{ `header` is the tuple of the heap variable this type belongs to, and is
  empty for every other type -- a schematic formal and a variable with
  non-constant discriminants both keep theirs where a symbol can name it, and
  AddressOfSym reaches those by the walk every enclosing variable makes. }
procedure BoundValue(t: typePtr; high: boolean; protected var header: str; var v: str);
var disc: symPtr; addr, raw: str; d: discValPtr; done: boolean;
begin
  if high then disc := t^.hiDisc else disc := t^.loDisc;
  if disc = nil then
    if high then OpInt(t^.hi, v) else OpInt(t^.lo, v)
  else begin
    done := false;
    { Inside `new` the tuple has no home yet -- the block it will live in
      front of is the thing being sized -- so the values are answered from the
      arguments themselves. That is what keeps the size, the domain check and
      every later read of the same bounds one piece of code. }
    if disc^.heapDisc then begin
      d := newTuple;
      while d <> nil do begin
        if d^.idx = disc^.discIndex then begin
          v := d^.value_;
          done := true
        end;
        d := d^.next
      end
    end;
    if not done then begin
    if disc^.heapDisc then begin
      Def(addr);
      write(ircode, 'getelementptr i32, ptr ');
      PutOp(header);
      writeln(ircode, ', i32 ', disc^.discIndex:1)
    end
    else
      AddressOfSym(disc, addr);
    Def(raw);
    write(ircode, 'load ');
    if disc^.heapDisc then write(ircode, 'i32')
    else PutLlType(disc^.stype);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode);
    { A discriminant may be of any ordinal type, and the index arithmetic is
      done in the integer type as it always is. }
    if IsChar(disc^.stype) or IsBoolean(disc^.stype) then
      if disc^.heapDisc then
        v := raw   { a heap tuple is stored one i32 per discriminant }
      else begin
        Def(v);
        write(ircode, 'zext ');
        PutLlType(disc^.stype);
        write(ircode, ' ');
        PutOp(raw);
        writeln(ircode, ' to i32')
      end
    else
      v := raw
    end
  end
end;

{ How many components an array has, as a *value*. TypeLength is `hi - lo + 1`
  and answers only for an array whose bounds are numbers; where they are
  discriminants it returns arithmetic on the placeholders, which is a number
  and therefore not obviously wrong. Everything needing a length rather than a
  size comes through here instead. }
{ The capacity of a string type, as a value. 6.4.3.3.3 makes it the schema's
  one discriminant, so it is a number where the type was written with one and
  the descriptor's when an actual brought it -- the same two answers every
  dynamic bound has (ADR-0040). }
procedure StringCapacity(t: typePtr; protected var hdr: str; var v: str);
begin
  if t^.hiDisc = nil then begin
    if t^.hi < 0 then OpInt(0, v) else OpInt(t^.hi, v)
  end
  else
    BoundValue(t, true, hdr, v)
end;

procedure DynLength(t: typePtr; protected var header: str; var v: str);
var lo, hi, extent: str;
begin
  if (t^.loDisc = nil) and (t^.hiDisc = nil) then
    OpInt(TypeLength(t), v)
  else begin
    BoundValue(t, false, header, lo);
    BoundValue(t, true, header, hi);
    Def(extent);
    write(ircode, 'sub i32 ');
    PutOp(hi);
    write(ircode, ', ');
    PutOp(lo);
    writeln(ircode);
    Def(v);
    write(ircode, 'add i32 ');
    PutOp(extent);
    writeln(ircode, ', 1')
  end
end;

{ The bytes a value of this type occupies, as a *value* rather than a constant:
  an array whose bounds arrive with the actual has a size only the descriptor
  can answer. }
procedure DynSize(t: typePtr; var header: str; var v: str);
var lo, hi, extent, count, inner, sum: str;
    f, last: fieldPtr; align: integer; off: int64;
begin
  if not DynamicExtent(t) then
    OpInt(LlSize(t), v)
  { A variable-string is a length beside a buffer, so its size is four bytes
    and the capacity -- the shape ADR-0045 already described, laid out by hand
    because a string is not the record a program could have written. }
  else if IsStringRep(t) then begin
    StringCapacity(t, header, count);
    Def(v);
    write(ircode, 'add i32 4, ');
    PutOp(count);
    writeln(ircode)
  end
  { A record's dynamic part is its last field and nothing else (ADR-0045), so
    every offset in it is a constant and the size is the last field's offset
    plus whatever the tail costs. The offset is accumulated here rather than
    asked of LlSize, because LlSize of the last field is the one number that
    is not known. }
  else if t^.kind = tyRecord then begin
    last := LastField(t^.fields);
    off := 0;
    align := 1;
    f := t^.fields;
    while f <> last do begin
      off := RoundUp(off, LlAlign(f^.ftype)) + LlSize(f^.ftype);
      if LlAlign(f^.ftype) > align then align := LlAlign(f^.ftype);
      f := f^.next
    end;
    off := RoundUp(off, LlAlign(last^.ftype));
    if LlAlign(last^.ftype) > align then align := LlAlign(last^.ftype);
    DynSize(last^.ftype, header, inner);
    { An array of these strides by the size, so it is rounded up to the
      record's alignment exactly as a static record's allocation size is. }
    Def(sum);
    write(ircode, 'add i32 ');
    PutOp(inner);
    writeln(ircode, ', ', off + align - 1:1);
    Def(v);
    write(ircode, 'and i32 ');
    PutOp(sum);
    writeln(ircode, ', ', -align:1)
  end
  else begin
    { (hi - lo + 1) components, each of whatever one component costs. The count
      cannot be negative: the tuple that produced the actual's type was checked
      when it was produced, so an empty range never reaches here. }
    BoundValue(t, false, header, lo);
    BoundValue(t, true, header, hi);
    Def(extent);
    write(ircode, 'sub i32 ');
    PutOp(hi);
    write(ircode, ', ');
    PutOp(lo);
    writeln(ircode);
    Def(count);
    write(ircode, 'add i32 ');
    PutOp(extent);
    writeln(ircode, ', 1');
    { One header serves every level: an array of dynamically-bounded arrays
      has one tuple, and the inner bounds are other discriminants of it. }
    DynSize(t^.elem, header, inner);
    Def(v);
    write(ircode, 'mul i32 ');
    PutOp(count);
    write(ircode, ', ');
    PutOp(inner);
    writeln(ircode)
  end
end;


{ A field of the fixed part is one index into the record. A field of a variant
  is two: to the shared storage, then into the arm laid over it. }
{ Walk down the field's path. At each step the shared storage is the last
  member of the struct we are in, and the arm laid over it starts at the same
  address -- so stepping in is one getelementptr, not two. }
{ ADR-0118: in the dialect, a variant's tag may not lie about which arm holds
  the payload. 6.5.3.3 makes reading or writing a field of an inactive variant
  an *error* -- Annex D.2, which doc/implementation-defined.md lists among the
  ones deliberately left unreported -- and 3.1 lets a processor leave an error
  undetected. So detecting it changes the meaning of no conforming program,
  which is what lets it be the language's rule without weakening ADR-0117's
  containment.

  Called once per variant part crossed on the way to a field, because activity
  is a *chain*: an inner tag stays readable when the arm containing it is not
  active, so `v.p` needs the outer tag to select its arm and the inner tag to
  select its own.

  `guard` is vgNone for the machinery that writes whole records -- the initial
  state, a whole-variable copy, the file walk -- which reaches every arm on
  purpose and must not be checked. vgWrite is a designator being assigned to;
  vgRead is every other use.

  A write *activates* the arm, but only when the arm has exactly one label to
  activate it to: `a, b: (i: integer)` cannot decide between a and b, and the
  variant-part-completer has no label at all. Those are checked like a read
  instead, which is sound and is the same rule 6.5.3.3 states.

  A tagless variant part and a discriminant-selected one are both skipped:
  TagFieldAt answers -1 for each, there being no field to compare against.
  That is a hole in the safety claim rather than an oversight, and it is
  written down in doc/sop.md 7. }
procedure EmitVariantGuard(protected var rec: str; t: typePtr; prefix: numPtr;
                           armIndex, guard, line, col: integer);
var tagIdx, msg: integer;
    arms, arm, other: variantPtr; tt: typePtr; r: rangePtr;
    tagAddr, tagVal, acc, c1, c2, c3, cond: str;
    haveAcc, single: boolean;

  { `acc := acc or (tag in lo..hi)`, with the first term starting it. }
  procedure Accumulate(lo, hi: integer);
  begin
    if lo = hi then begin
      Def(c1);
      write(ircode, 'icmp eq ');
      PutLlType(tt);
      write(ircode, ' ');
      PutOp(tagVal);
      writeln(ircode, ', ', lo:1)
    end
    else begin
      Def(c2);
      write(ircode, 'icmp sge ');
      PutLlType(tt);
      write(ircode, ' ');
      PutOp(tagVal);
      writeln(ircode, ', ', lo:1);
      Def(c3);
      write(ircode, 'icmp sle ');
      PutLlType(tt);
      write(ircode, ' ');
      PutOp(tagVal);
      writeln(ircode, ', ', hi:1);
      Def(c1);
      write(ircode, 'and i1 ');
      PutOp(c2);
      write(ircode, ', ');
      PutOp(c3);
      writeln(ircode)
    end;
    if haveAcc then begin
      Def(cond);
      write(ircode, 'or i1 ');
      PutOp(acc);
      write(ircode, ', ');
      PutOp(c1);
      writeln(ircode);
      acc := cond
    end
    else begin
      acc := c1;
      haveAcc := true
    end
  end;

begin
  tagIdx := TagFieldAt(t, prefix);
  if (guard <> vgNone) and (tagIdx >= 0) then
  begin
    arms := ArmsAt(t, prefix);
    arm := ArmAtIn(arms, armIndex);
    tt := TagTypeAt(t, prefix);
    Def(tagAddr);
    write(ircode, 'getelementptr inbounds ');
    PutStructAt(t, prefix);
    write(ircode, ', ptr ');
    PutOp(rec);
    writeln(ircode, ', i32 0, i32 ', tagIdx:1);

    single := (not arm^.isOtherwise) and (arm^.labels <> nil) and
              (arm^.labels^.next = nil) and
              (arm^.labels^.lo = arm^.labels^.hi);

    if (guard = vgWrite) and single then begin
      { the write says which arm is live, so the tag cannot disagree with the
        payload: the only way to write a payload is through this store }
      write(ircode, '  store ');
      PutLlType(tt);
      write(ircode, ' ', arm^.labels^.lo:1, ', ptr ');
      PutOp(tagAddr);
      writeln(ircode)
    end
    else begin
      Def(tagVal);
      write(ircode, 'load ');
      PutLlType(tt);
      write(ircode, ', ptr ');
      PutOp(tagAddr);
      writeln(ircode);
      haveAcc := false;
      if arm^.isOtherwise then begin
        { 6.4.3.3's completer is selected by whatever the other arms leave, so
          what it accepts is the complement of their labels and `acc` is
          already the trap condition (ADR-0034). }
        other := arms;
        while other <> nil do begin
          if other <> arm then begin
            r := other^.labels;
            while r <> nil do begin
              Accumulate(r^.lo, r^.hi);
              r := r^.next
            end
          end;
          other := other^.next
        end
      end
      else begin
        r := arm^.labels;
        while r <> nil do begin
          Accumulate(r^.lo, r^.hi);
          r := r^.next
        end
      end;
      if haveAcc then begin
        if not arm^.isOtherwise then begin
          { trap when the tag selects some *other* arm }
          Def(cond);
          write(ircode, 'xor i1 ');
          PutOp(acc);
          writeln(ircode, ', true');
          acc := cond
        end;
        MsgStart;
        { one segment: MsgText trims each one's trailing blanks, so a message
          split across two loses the space between them }
        MsgText('variant: the tag selects another arm    ');
        msg := MsgEnd;
        EmitTrapIf(acc, msg, line, col)
      end
    end
  end
end;

procedure FieldAddress(protected var rec: str; t: typePtr; f: fieldPtr; var v: str;
                       guard, line, col: integer);
var cur, p: str; prefix, step: numPtr;
begin
  cur := rec;
  prefix := nil;
  step := f^.variant;
  while step <> nil do begin
    { ADR-0118, before descending: `cur` is the struct holding this variant
      part, and `step^.value_` is the arm being entered. The guard is emitted
      per step because activity is a chain -- see EmitVariantGuard. }
    EmitVariantGuard(cur, t, prefix, step^.value_, guard, line, col);
    Def(p);
    write(ircode, 'getelementptr inbounds ');
    PutStructAt(t, prefix);
    write(ircode, ', ptr ');
    PutOp(cur);
    { AP 6.4.13.5: an arm laid apart is its own member, so the index is the
      fixed fields plus which arm; an overlaid one is the single block that
      follows them. }
    if t^.armsApart then
      writeln(ircode, ', i32 0, i32 ',
              FieldCount(FieldsAt(t, prefix)) + step^.value_:1)
    else
      writeln(ircode, ', i32 0, i32 ', FieldCount(FieldsAt(t, prefix)):1);
    cur := p;
    prefix := PathAppend(prefix, step^.value_);
    step := step^.next
  end;
  Def(v);
  write(ircode, 'getelementptr inbounds ');
  PutStructAt(t, prefix);
  write(ircode, ', ptr ');
  PutOp(cur);
  writeln(ircode, ', i32 0, i32 ', f^.index:1)
end;

{ ---------------------------------------------------------- file variables }

{ Whether a value of this type holds a file anywhere inside it.

  A variant part whose arms are laid **over** one another cannot -- Sema
  refuses a file in one, because the arms share storage and a file's storage
  is its own -- so for those this walks the fixed part alone, which is what
  makes the walk below reach every file exactly once.

  AP 6.4.13.5's side-by-side arms (ADR-0256) are the exception and the reason
  the flag exists: their arms do not share storage, so each is walked, and
  each affine slot is still reached exactly once because each has bytes of its
  own. A fallible-type has one affine arm at most -- 6.4.13.5 admits an affine
  value-type and refuses an affine cause-type -- so in practice one slot is
  registered and the other arm contributes nothing. }
function HoldsFile(t: typePtr): boolean; forward;

{ The arms of a side-by-side variant part (AP 6.4.13.5), asked the same
  question. Mutually recursive with HoldsFile, which is what the forward
  above is for. }
function ArmsHoldFile(v: variantPtr): boolean;
var found: boolean; f: fieldPtr;
begin
  found := false;
  while (v <> nil) and not found do begin
    f := v^.fields;
    while (f <> nil) and not found do begin
      if HoldsFile(f^.ftype) then found := true;
      f := f^.next
    end;
    v := v^.next
  end;
  ArmsHoldFile := found
end;

function HoldsFile;
var found: boolean; f: fieldPtr;
begin
  found := false;
  if t <> nil then
    if IsAffine(t) then found := true
    else if IsArray(t) then found := HoldsFile(t^.elem)
    else if IsRecord(t) then begin
      f := t^.fields;
      while (f <> nil) and not found do begin
        if HoldsFile(f^.ftype) then found := true;
        f := f^.next
      end;
      if t^.armsApart and not found then found := ArmsHoldFile(t^.variants)
    end;
  HoldsFile := found
end;

{ The release routine for this domain, made if this is the first call to it.
  The body is not emitted here: EmitOwnRels drains the worklist after the last
  user function, which is what lets a routine's body contain a call to itself
  (ADR-0181). }
function OwnRelId(dom: typePtr): integer;
var r, fresh: ownRelPtr;
begin
  r := ownRels;
  while (r <> nil) and (r^.dom <> dom) do r := r^.next;
  if r = nil then begin
    new(fresh);
    nextOwnRel := nextOwnRel + 1;
    fresh^.dom := dom;
    fresh^.id := nextOwnRel;
    fresh^.emitted := false;
    fresh^.next := nil;
    if ownRelTail = nil then ownRels := fresh else ownRelTail^.next := fresh;
    ownRelTail := fresh;
    r := fresh
  end;
  OwnRelId := r^.id
end;

{ Every file inside `addr`, set up or torn down. ISO 7185 6.5.1's own example
  is `pooltape : array [1..4] of FileOfInteger` and 6.5.5's is `pooltape[2]^`,
  so a file need not be an entire variable -- and each one needs its
  `struct pas_file` prepared before the program can name it, and closed when
  the storage goes away.

  `binding` and `arg` describe the *whole* variable and so apply only when it
  is itself a file: a program parameter is an entire variable (6.10), so a file
  reached through a subscript or a field is always an internal one. }
procedure WalkFiles(addr: str; t: typePtr; init: boolean;
                    binding, arg, name, line, col: integer);
var istext, direct, cap, ixLo, ixHi, headB, bodyB, doneB: integer;
    comp: int64;
    f: fieldPtr;
    v: variantPtr;
    nohdr, count, iv, i, more, elem, next, zero, one, held, chan: str;
begin
  { AP 6.4.12 (ADR-0174): a handle is set up empty with its closer and torn
    down by the runtime, which releases what it holds -- the file's own two
    calls, for the file's reason: the storage is going away. }
  if IsHandle(t) then begin
    if init then begin
      { AP 6.4.16: a channel-type's closer is the runtime's and there is no
        foreign name to write; and unlike every other handle, the variable
        does not start empty. A channel exists for as long as the variable
        that declares it -- its capacity is part of its type, so there is
        nothing left for an assignment to decide and no birth for a program to
        write. That is why `channel [8] of integer` is a declaration and not a
        constructor. }
      if IsChannel(t) then begin
        write(ircode, '  call void @pas_handle_init(ptr ');
        PutOp(addr);
        writeln(ircode, ', ptr @pas_chan_close)');
        EmitAt(line, col);
        Def(chan);
        write(ircode, 'call ptr @pas_chan_new(i64 ', LlSize(t^.elem):1,
              ', i64 ', t^.hi:1, ')');
        writeln(ircode);
        EmitAtDone;
        write(ircode, '  call void @pas_handle_set(ptr ');
        PutOp(addr);
        write(ircode, ', ptr ');
        PutOp(chan);
        writeln(ircode, ')')
      end
      else begin
        StrClear(nohdr);
        AppendPool(nohdr, t^.handleAt, t^.handleLen);
        write(ircode, '  call void @pas_handle_init(ptr ');
        PutOp(addr);
        write(ircode, ', ptr @');
        PutOp(nohdr);
        writeln(ircode, ')')
      end
    end
    else begin
      write(ircode, '  call void @pas_handle_done(ptr ');
      PutOp(addr);
      writeln(ircode, ')')
    end
  end
  else if IsFile(t) then begin
    if not init then begin
      write(ircode, '  call void @pas_file_done(ptr ');
      PutOp(addr);
      writeln(ircode, ')')
    end
    else begin
      { The component type is the whole of what the runtime needs to know
        about a `file of T`: how many bytes one component is, and whether the
        file has the line structure only a `text` has. }
      comp := 1;
      if t^.elem <> nil then comp := LlSize(t^.elem);
      istext := 0;
      if t^.isText then istext := 1;
      { 6.4.3.6: an index-type makes the file direct-access, and the runtime
        does two things differently. It opens the stream for reading *and*
        writing -- SeekUpdate must be able to turn one into the other without
        reopening, since it has to preserve the contents -- and it holds the
        clause's own bound on the length.

        The capacity is `ord(b) - ord(a) + 1`, and zero says there is none
        worth carrying: an index-type spanning maxint values or more has a
        capacity this compiler has no integer for, and a program has no way to
        reach it. The guard is the one ResolveArray uses on an array's index
        for the same arithmetic, written the same way round so neither
        subtraction can leave the type (ADR-0134). }
      direct := 0;
      cap := 0;
      if t^.indexType <> nil then begin
        direct := 1;
        ixLo := OrdinalLo(t^.indexType);
        ixHi := OrdinalHi(t^.indexType);
        if (ixLo <= 0) and (ixHi >= maxint + ixLo) then cap := 0
        else cap := ixHi - ixLo + 1
      end;
      EmitAt(line, col);
      write(ircode, '  call void @pas_file_init(ptr ');
      PutOp(addr);
      writeln(ircode, ', i32 ', binding:1, ', i32 ', arg:1,
              ', ptr @s', name:1, ', i32 ', comp:1, ', i32 ', istext:1,
              ', i32 ', direct:1, ', i32 ', cap:1, ')');
      EmitAtDone
    end
  end
  { AP 6.4.14 (ADR-0181). Setting up is storing `nil`, and it is not a
    nicety: the release below reads the slot, and a frame slot is not zeroed,
    so without this the epilogue of a block whose `new` never ran would
    dispose whatever the stack happened to hold. Tearing down is the generated
    routine, which tests for empty, walks the variable and disposes it -- all
    three in the callee, because the third of them is the recursive case. }
  else if IsOwnedPointer(t) then begin
    if init then begin
      write(ircode, '  store ptr null, ptr ');
      PutOp(addr);
      writeln(ircode)
    end
    else begin
      Def(held);
      write(ircode, 'load ptr, ptr ');
      PutOp(addr);
      writeln(ircode);
      write(ircode, '  call void @ownrel', OwnRelId(t^.elem):1, '(ptr ');
      PutOp(held);
      writeln(ircode, ')')
    end
  end
  else if IsRecord(t) then begin
    f := t^.fields;
    while f <> nil do begin
      if HoldsFile(f^.ftype) then begin
        FieldAddress(addr, t, f, elem, vgNone, 0, 0);
        WalkFiles(elem, f^.ftype, init, 0, 0, name, line, col)
      end;
      f := f^.next
    end;
    { AP 6.4.13.5 (ADR-0256): an arm laid beside the others has bytes of its
      own, so the affine slot in it is set up and torn down like any field --
      once, at an address nothing else uses. `vgNone` is right and is not an
      omission: the walk reaches every arm on purpose, where a *program*
      reading the inactive one is what EmitVariantGuard traps.

      An overlaid variant part is not walked and cannot be: Sema refuses an
      affine field in one, which is the invariant HoldsFile states. }
    if t^.armsApart then begin
      v := t^.variants;
      while v <> nil do begin
        f := v^.fields;
        while f <> nil do begin
          if HoldsFile(f^.ftype) then begin
            FieldAddress(addr, t, f, elem, vgNone, 0, 0);
            WalkFiles(elem, f^.ftype, init, 0, 0, name, line, col)
          end;
          f := f^.next
        end;
        v := v^.next
      end
    end
  end
  else if IsArray(t) then begin
    if HoldsFile(t^.elem) then begin
      { A loop rather than an unrolled run: the length may be a discriminant's
        (ADR-0040), and an array of files is otherwise as long as the program
        says. It is emitted in the prologue, where an alloca belongs anyway. }
      StrClear(nohdr);
      DynLength(t, nohdr, count);
      Def(iv);
      writeln(ircode, 'alloca i32');
      OpInt(0, zero);
      write(ircode, '  store i32 ');
      PutOp(zero);
      write(ircode, ', ptr ');
      PutOp(iv);
      writeln(ircode);
      headB := NewBlock;
      bodyB := NewBlock;
      doneB := NewBlock;
      writeln(ircode, '  br label %L', headB:1);

      StartBlock(headB);
      Def(i);
      write(ircode, 'load i32, ptr ');
      PutOp(iv);
      writeln(ircode);
      Def(more);
      write(ircode, 'icmp slt i32 ');
      PutOp(i);
      write(ircode, ', ');
      PutOp(count);
      writeln(ircode);
      write(ircode, '  br i1 ');
      PutOp(more);
      writeln(ircode, ', label %L', bodyB:1, ', label %L', doneB:1);

      StartBlock(bodyB);
      Def(elem);
      write(ircode, 'getelementptr ');
      PutLlType(t);
      write(ircode, ', ptr ');
      PutOp(addr);
      write(ircode, ', i32 0, i32 ');
      PutOp(i);
      writeln(ircode);
      WalkFiles(elem, t^.elem, init, 0, 0, name, line, col);
      OpInt(1, one);
      Def(next);
      write(ircode, 'add i32 ');
      PutOp(i);
      write(ircode, ', ');
      PutOp(one);
      writeln(ircode);
      write(ircode, '  store i32 ');
      PutOp(next);
      write(ircode, ', ptr ');
      PutOp(iv);
      writeln(ircode);
      writeln(ircode, '  br label %L', headB:1);

      StartBlock(doneB)
    end
  end
end;

{ AP 6.4.14.3's release, as a function of the domain type (ADR-0181). Emitted
  after the last user function, so nothing here interleaves with a body being
  written -- the emitter is sequential and cannot return to a block it has
  left (ADR-0025), and a function definition cannot be nested inside another.
  Draining a worklist rather than recursing: a routine whose domain owns
  something of its own type calls itself, and OwnRelId hands out that number
  before this body exists.

  The three things it does are the three the *callee* has to do. Testing for
  empty is here rather than at the call, because a call site that tested would
  be straight-line code for a list of unknown length. Walking the variable is
  WalkFiles, which is the same walk the block epilogue uses -- so a file or a
  handle inside a heap variable is closed by the routine that disposes the
  variable, and neither of them needed a second implementation. Disposing is
  last, for the obvious reason.

  The parameter is named rather than numbered so it cannot collide with the
  `%vN` Def hands out. }
procedure EmitOwnRels;
var r: ownRelPtr; more: boolean; own, empty, raw: str; doneB, workB: integer;
    head: integer;
begin
  repeat
    more := false;
    r := ownRels;
    while r <> nil do begin
      if not r^.emitted then begin
        r^.emitted := true;
        more := true;
        writeln(ircode);
        { The Pascal name of the domain, for a reader of -S output. Not
          WriteTypeName: that goes through the Put sink, which is aimed at the
          diagnostic stream or at msgBuf and never at the IR file. No arm for
          a domain without a name: 6.4.14.1 makes it a type-identifier, so it
          always has one, and a branch nothing can reach is a liability
          line-coverage is right to name. }
        write(ircode, '; release the variable ', r^.id:1, ' owns: ');
        if r^.dom^.aliasLen > 0 then
          WritePoolIr(r^.dom^.aliasAt, r^.dom^.aliasLen);
        writeln(ircode);
        writeln(ircode, 'define internal void @ownrel', r^.id:1,
                '(ptr %own) {');
        nextReg := 0;
        nextBlock := 0;
        StrClear(own);
        AppendLit(own, '%own            ');
        StartBlock(NewBlock);
        workB := NewBlock;
        doneB := NewBlock;
        Def(empty);
        write(ircode, 'icmp eq ptr ');
        PutOp(own);
        writeln(ircode, ', null');
        write(ircode, '  br i1 ');
        PutOp(empty);
        writeln(ircode, ', label %L', doneB:1, ', label %L', workB:1);

        StartBlock(workB);
        if HoldsFile(r^.dom) then
          WalkFiles(own, r^.dom, false, 0, 0, 0, 0, 0);
        { Stepping back over a tuple header, as dispose's own arm does, and
          for the reason written there: what was allocated is the header and
          the variable together, so what is given back has to be the block.
          The comment here used to say the arm was unreachable because
          6.4.14.2 refused a schema domain outright, and named itself as the
          second place to change if that were ever lifted (ADR-0320). It was,
          and this is it -- the release and dispose must give back the same
          address, and until this line existed a block-scoped release of a
          schema-domain owned pointer reached free() with the variable's
          address and aborted with `free(): invalid size`. }
        head := HeaderSize(r^.dom);
        if head <> 0 then begin
          raw := own;
          Def(own);
          write(ircode, 'getelementptr i8, ptr ');
          PutOp(raw);
          writeln(ircode, ', i32 ', -head:1)
        end;
        write(ircode, '  call void @pas_dispose(ptr ');
        PutOp(own);
        writeln(ircode, ')');
        writeln(ircode, '  br label %L', doneB:1);

        StartBlock(doneB);
        writeln(ircode, '  ret void');
        writeln(ircode, '}')
      end;
      r := r^.next
    end
  until not more
end;

{ ------------------------------------------------------------- conversions }

{ Widen an integer to double where Pascal's implicit conversion applies. }
procedure ToReal(var v: str; from: typePtr);
var r: str;
begin
  { ADR-0128's int64 widens to real by the same instruction one width up. It
    is the one widening here that is not exact -- above 2^53 the nearest double
    is not the value -- and it is the widening 6.4.6 c) already permits for
    integer, whose exactness is an accident of this processor's 32 bits rather
    than something the standard promises. }
  if IsInteger(from) or IsInt64(from) then begin
    Def(r);
    write(ircode, 'sitofp ');
    if IsInt64(from) then write(ircode, 'i64 ') else write(ircode, 'i32 ');
    PutOp(v);
    writeln(ircode, ' to double');
    v := r
  end
end;

{ The real part of a complex value; 6.7.6.2's `re`. }
procedure ReOf(a: str; var v: str);
begin
  Def(v);
  write(ircode, 'extractelement <2 x double> ');
  PutOp(a);
  writeln(ircode, ', i32 0')
end;

{ ...and the imaginary one, 6.7.6.2's `im`. }
procedure ImOf(a: str; var v: str);
begin
  Def(v);
  write(ircode, 'extractelement <2 x double> ');
  PutOp(a);
  writeln(ircode, ', i32 1')
end;

{ A complex value from its two parts. This and the two above are the whole
  interface to the representation, which is why 6.4.2.2's NOTE that the
  representation "could be rectangular, polar, or something quite different"
  costs nothing to honour: only these three know it is rectangular. }
procedure MakeComplex(re, im: str; var v: str);
var half: str;
begin
  Def(half);
  write(ircode, 'insertelement <2 x double> undef, double ');
  PutOp(re);
  writeln(ircode, ', i32 0');
  Def(v);
  write(ircode, 'insertelement <2 x double> ');
  PutOp(half);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ', i32 1')
end;

{ 6.4.6 c)'s widening: a real or an integer is the complex with that real part
  and a zero imaginary one. }
procedure ToComplex(var v: str; from: typePtr);
var zero, w: str;
begin
  if not IsComplex(from) then begin
    ToReal(v, from);
    OpWord('0.0             ', zero);
    MakeComplex(v, zero, w);
    v := w
  end
end;

{ ADR-0128's widening, and it is one instruction: the integer type is
  -maxint..maxint, so every value of it is a value of int64 and the sign
  extension cannot lose one. Nothing widens *to* an integer -- that is `trunc`,
  and it is checked. }
procedure ToInt64(var v: str; from: typePtr);
var w: str;
begin
  if not IsInt64(from) then begin
    Def(w);
    write(ircode, 'sext ');
    PutLlType(from);
    write(ircode, ' ');
    PutOp(v);
    writeln(ircode, ' to i64');
    v := w
  end
end;

procedure ConvertFor(var v: str; from, toT: typePtr);
begin
  if IsReal(toT) then ToReal(v, from)
  else if IsInt64(toT) then ToInt64(v, from)
  { 6.4.6 c): "an implicit integer-to-complex conversion or real-to-complex
    conversion, respectively, shall be performed". }
  else if IsComplex(toT) then ToComplex(v, from)
end;

{ A real literal reaches the IR as the text it was written with -- which is
  what a textual backend wanted all along, and why the conversion three records
  deferred never had to be written. LLVM's assembler is the strtod, and it is
  the same correctly-rounded conversion the C++ compiler gets from its own.
  The only adjustment is that LLVM's float syntax needs a decimal point, and
  Pascal's `1e6` has none. }
{ The digits of an int64 constant, and no adjustment at all: LLVM writes an
  integer the way Pascal does, where a real needed a decimal point Pascal's
  `1e6` has none of. The text is carried for the same reason a real's is --
  this compiler's own integers are 32 bits, so it has no value of the type to
  convert to and back from (ADR-0025, ADR-0128). }
procedure EmitInt64Text(at, len: integer; negative: boolean; var v: str);
var k: integer;
begin
  StrClear(v);
  if negative then StrAppend(v, '-');
  for k := 1 to len do
    StrAppend(v, pool[at + k - 1])
end;

procedure EmitRealText(at, len: integer; negative: boolean; var v: str);
var k, ePos: integer; hasDot: boolean;
begin
  ePos := len + 1;
  hasDot := false;
  for k := 1 to len do
    if (pool[at + k - 1] = 'e') or (pool[at + k - 1] = 'E') then begin
      if ePos > len then ePos := k
    end
    else if pool[at + k - 1] = '.' then
      hasDot := true;

  StrClear(v);
  if negative then StrAppend(v, '-');
  for k := 1 to ePos - 1 do
    StrAppend(v, pool[at + k - 1]);
  if not hasDot then begin
    StrAppend(v, '.');
    StrAppend(v, '0')
  end;
  for k := ePos to len do
    StrAppend(v, pool[at + k - 1])
end;

{ Whether a store into this type emits anything. A subrange covering its whole
  host needs no check, which is what keeps `1..maxint` from paying for one.
  It is a function of its own because EmitFor has to ask the question *before*
  emitting the check -- 6.8.3.9 puts the check under the loop's entry test --
  and a second copy of the condition there could drift from this one. }
function NeedsSubrangeCheck(target: typePtr): boolean;
var host: typePtr;
begin
  NeedsSubrangeCheck := false;
  if target <> nil then
    if target^.kind = tySubrange then
      { A bound that is a discriminant is not a number here, and the two on the
        type are placeholders -- so the question cannot be asked and the check
        is always emitted. Reading them anyway would answer about the subrange
        0..0, which is a subrange nobody wrote. }
      if (target^.loDisc <> nil) or (target^.hiDisc <> nil) then
        NeedsSubrangeCheck := true
      else begin
        host := Base(target);
        NeedsSubrangeCheck :=
          (target^.lo > OrdinalLo(host)) or (target^.hi < OrdinalHi(host))
      end
end;

{ ISO 7185 6.4.6 makes it an error to store a value outside a subrange's
  bounds, so every place a value enters a subrange variable comes through here. }
{ Where a bound is a discriminant the two numbers on the type say nothing and
  BoundValue reads the descriptor instead -- the same call the subscript check
  makes, which is the whole of what ADR-0127 left for ADR-0133 to do. The
  comparison moves to i32 with it, because that is the width a discriminant is
  loaded and widened to; a char or boolean value widens to meet it, and zext is
  exact there because their ordinals are non-negative. The header is empty, and
  for a reason rather than by omission: a header is where a *heap* variable
  keeps its tuple, and `new` builds one only for a type with a dynamic extent,
  which a subrange never has. So `type t = 1..m; q = ^t` allocates four bytes
  with no tuple in front of them and `ptr^ := k` is checked against the block's
  own descriptor, which is where its bounds have been all along. }
procedure CheckedForSubrange(protected var v: str; target: typePtr;
                             line, col: integer);
var below, above, bad, lo, hi, hdr, val: str; sign, dynamic: boolean;
    msg: integer;
begin
  if target <> nil then
    if target^.kind = tySubrange then begin
      if NeedsSubrangeCheck(target) then
      begin
        dynamic := (target^.loDisc <> nil) or (target^.hiDisc <> nil);
        sign := IsInteger(target);
        val := v;
        if dynamic then begin
          StrClear(hdr);
          BoundValue(target, false, hdr, lo);
          BoundValue(target, true, hdr, hi);
          if IsChar(target) or IsBoolean(target) then begin
            Def(val);
            write(ircode, 'zext ');
            PutLlType(target);
            write(ircode, ' ');
            PutOp(v);
            writeln(ircode, ' to i32')
          end;
          sign := true
        end
        else begin
          OpInt(target^.lo, lo);
          OpInt(target^.hi, hi)
        end;
        Def(below);
        if sign then write(ircode, 'icmp slt ')
        else write(ircode, 'icmp ult ');
        if dynamic then write(ircode, 'i32') else PutLlType(target);
        write(ircode, ' ');
        PutOp(val);
        write(ircode, ', ');
        PutOp(lo);
        writeln(ircode);
        Def(above);
        if sign then write(ircode, 'icmp sgt ')
        else write(ircode, 'icmp ugt ');
        if dynamic then write(ircode, 'i32') else PutLlType(target);
        write(ircode, ' ');
        PutOp(val);
        write(ircode, ', ');
        PutOp(hi);
        writeln(ircode);
        Def(bad);
        write(ircode, 'or i1 ');
        PutOp(below);
        write(ircode, ', ');
        PutOp(above);
        writeln(ircode);

        if dynamic then
          EmitTrapRange(bad, lo, hi, line, col)
        else begin
          MsgStart;
          MsgText('value out of range (                    ');
          WriteTypeName(target);
          Put(')');
          msg := MsgEnd;
          EmitTrapIf(bad, msg, line, col)
        end
      end
    end
end;

{ ============================== expressions ============================== }

procedure EmitExpr(e: nodePtr; var v: str); forward;
{ AP 6.9.3.12: written below with the task wrapper it pairs with, because the
  two are one construct read from its two ends -- the statement that fills an
  argument block and the function that unpacks it. }
procedure EmitSpawn(s: nodePtr); forward;
procedure EmitAddress(e: nodePtr; var v: str); forward;
{ 6.8.7's structured-value-constructor, built into `into` -- the hidden frame
  slot Sema gave it when `into` is empty, and otherwise the component or the
  variable the value is for. }
procedure EmitStructValue(e: nodePtr; var into: str); forward;
{ A string value as ADR-0051 defines one: a pointer and a length, produced for
  any string expression at all -- a literal, a variable, a substring or a
  concatenation. Forward because EmitUserCall needs it and is written first: a
  variable-string *value* parameter travels as exactly this pair (ADR-0115). }
procedure EmitString(e: nodePtr; var data, len: str); forward;

{ The tuple governing a designator, found by walking to the whole variable it
  selects from. One header serves every dimension -- `g^[i][j]` reads `rows`
  and `cols` out of the same one -- and only the outermost designator has the
  address it sits in front of, so an inner subscript cannot compute it from
  its own base. Walking down is what stands in for threading it through. }
procedure HeapHeader(e: nodePtr; var v: str);
var base: str; walking, done: boolean;
begin
  walking := true;
  while walking do
    if e^.kind = nkIndex then e := e^.ixBase
    else if e^.kind = nkField then e := e^.fdBase
    else walking := false;
  done := false;
  { A name that was a field of an enclosing `with` has no node standing for the
    record it came from, so the walk stops one step short of the whole
    variable: the binding is what holds that address, and its type is what says
    whether a header is in front of it. }
  if (e^.kind = nkVar) and (e^.vrField <> nil) and (e^.vrSym <> nil) then
    if (e^.vrSym^.stype <> nil) and e^.vrSym^.stype^.heapTuple then begin
      AddressOfSym(e^.vrSym, base);
      HeaderOf(e^.vrSym^.stype, base, v);
      done := true
    end;
  { `ntype` is read without a nil test, and that is the contract rather than an
    omission: Sema leaves every node's type non-null, assigning a placeholder
    on an error path rather than nil, so that CodeGen cannot crash on a
    half-checked tree (ADR-0008). This routine carried `(e^.ntype = nil) or`
    in front of the test for a long time, unreached by 807 cases and 323
    scenarios -- and had it ever been reached it would have answered with an
    empty header, which is a contract violation propagating quietly instead of
    stopping where it happened. The check above it tests a *symbol's* type,
    which is a different contract and stays. }
  if not done then
    if not e^.ntype^.heapTuple then
      StrClear(v)
    else begin
      EmitAddress(e, base);
      HeaderOf(e^.ntype, base, v)
    end
end;
{ Where AP 6.7.5.10's break and 6.7.5.11's continue branch to: the block
  after the innermost repetitive-statement being emitted, and the block that
  decides whether it iterates again. Saved and restored around each loop's
  body, so the lexical nesting *is* the stack and there is none to keep.

  Zero means "no loop", which cannot be reached: Sema refuses both statements
  outside one, and a block boundary resets its own copy of loopDepth. Kept as
  a distinguishable value rather than left arbitrary so that a defect shows up
  as a branch to %L0 -- an undefined label LLVM rejects -- and not as a branch
  into some earlier loop's blocks.

  The continue target is not always the condition. A for-statement tests
  whether the control-variable has reached the limit *after* the body and
  steps only if it has not, so what continue enters is that test and not the
  loop's head; a for-in over a set enters the step, its element test having
  already been passed. }
var
  breakBlock, contBlock: integer;

  { AP 6.4.12.6 (ADR-0255): where the next call is to build its handle
    result, or nil.

    Deliberately the shape Sema's `handleBirth` has, and about the same
    statement seen from the other end of the pipeline: a handle-valued call
    may stand in exactly one position, so the *statement* knows the
    destination and the call does not. Set by EmitAssign immediately before
    the value is emitted, read and cleared by EmitUserCall, and cleared again
    by EmitAssign afterwards so a foreign call -- which never reads it, its
    answer arriving in a register -- leaves nothing armed. Threading it as a
    parameter instead would mean a second reader of "which node kind holds a
    call", which EmitExpr already dispatches three ways, and that is the
    drift ADR-0230 is about. }
  factoryInto: nodePtr;

procedure EmitStmt(s: nodePtr); forward;
{ AP 6.8.9's try assigns a result the way exit(e) does, and through the same
  routine -- which is defined among the statements, because until this
  construct no *expression* could contain an assignment. }
procedure EmitAssign(s: nodePtr); forward;
{ AP 6.9.3.11: forward because a statement-sequence is completed in three
  places and the earliest of them, a repeat-statement's body, is emitted
  before this is defined. }
procedure EndSequence(list: nodePtr); forward;

{ The value a designator holds. An array or a record has no register form, so
  what it yields is its address; everything else is loaded from it. }
procedure EmitLoad(e: nodePtr; var v: str);
var addr: str;
begin
  EmitAddress(e, addr);
  if IsMemory(e^.ntype) then
    v := addr
  else begin
    Def(v);
    write(ircode, 'load ');
    PutLlType(e^.ntype);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode)
  end
end;

{ The storage of a constant whose value does not fit in a register.

  A string constant is its literal, named (ADR-0068), so what it needs is what
  the literal already had: a private constant global holding the characters. A
  6.8.7 constructor gets a global of its own instead, filled once by the
  prologue of the block that defined it (ADR-0069) -- memoised on the node, so
  two names for one value share one global. }
procedure ConstAddress(s: symPtr; var v: str);
var g, found: constGlobalPtr; k: integer;
begin
  if s^.constValue^.kind <> nkStructValue then
    EmitAddress(s^.constValue, v)
  else begin
    found := nil;
    g := constHead;
    while g <> nil do begin
      if g^.cvalue = s^.constValue then found := g;
      g := g^.next
    end;
    if found = nil then begin
      new(found);
      nextConst := nextConst + 1;
      found^.id := nextConst;
      found^.at := s^.at;
      found^.len := s^.len;
      found^.cvalue := s^.constValue;
      found^.ctype := s^.stype;
      found^.next := nil;
      if constHead = nil then constHead := found else constTail^.next := found;
      constTail := found
    end;
    StrClear(v);
    AppendLit(v, '@const.         ');
    for k := found^.at to found^.at + found^.len - 1 do
      StrAppend(v, pool[k]);
    StrAppend(v, '.');
    AppendInt(v, found^.id)
  end
end;

procedure EmitConst(s: symPtr; var v: str);
var b: typePtr;
begin
  b := Base(s^.stype);
  if s^.constValue <> nil then
    { A value that travels by address answers with its storage, which is what
      every designator of a structured type answers with (ADR-0017). }
    if IsMemory(s^.stype) then
      ConstAddress(s, v)
    { A set is a *value* and has nowhere to be (ADR-0028), so the constructor is
      emitted where the constant is named. It reads nothing, so there is no
      order to get wrong and nothing to initialise ahead of time. }
    else
      EmitExpr(s^.constValue, v)
  else if b = nil then
    OpInt(0, v)
  else
    case b^.kind of
      tyInteger, tyEnum: OpInt(s^.intVal, v);
      { The text that was written, exactly as a real's is and for exactly the
        same reason: this compiler has no value of either type to hold, so
        LLVM's assembler is what reads the digits (ADR-0025, ADR-0128). }
      tyInt64: EmitInt64Text(s^.realAt, s^.realLen, s^.realNeg, v);
      tyReal: EmitRealText(s^.realAt, s^.realLen, s^.realNeg, v);
      tyBoolean:
        if s^.boolVal then OpWord('true            ', v)
        else OpWord('false           ', v);
      tyChar: OpInt(ord(s^.charVal), v);
      { No constant of the remaining kinds has a scalar operand, and an
        optional is among them: 6.3 gives no way to write one, there being no
        constructor syntax for it. The label is here anyway -- a kind left off
        is a crash rather than a wrong answer (ADR-0018), and "no program can
        reach it" is the argument that was wrong the last two times. It costs
        no coverage: a label is not a statement and the arm was already run. }
      tyVoid, tySubrange, tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc,
      tyComplex, tyRestricted, tyString, tyText, tyOptional, tySlice, tyHandle:
        OpInt(0, v)
    end
end;

{ ------------------------------------------------------------------- sets }

{ The 256-bit constant whose set bits are exactly the values of `baseType`:
  the bits from its first ordinal to its last. Built by shifting rather than
  written as a literal, because a 256-bit literal is a number this compiler's
  own source language cannot spell -- and LLVM folds the shifts before they
  ever reach the target. }
procedure SetUniverse(baseType: typePtr; var v: str);
var ones, sh, below, above: str;
begin
  OpInt(-1, ones);
  { Clear the bits above hi, then the bits below lo. Sema has already refused
    a base type outside 0..setLimit, so neither shift can reach setBits. }
  OpInt(setLimit - OrdinalHi(baseType), sh);
  Def(below);
  write(ircode, 'lshr i', setBits:1, ' ');
  PutOp(ones);
  write(ircode, ', ');
  PutOp(sh);
  writeln(ircode);
  OpInt(OrdinalLo(baseType), sh);
  Def(above);
  write(ircode, 'shl i', setBits:1, ' ');
  PutOp(ones);
  write(ircode, ', ');
  PutOp(sh);
  writeln(ircode);
  Def(v);
  write(ircode, 'and i', setBits:1, ' ');
  PutOp(below);
  write(ircode, ', ');
  PutOp(above);
  writeln(ircode)
end;

{ ISO 7185 6.4.6 makes it an error to store a value that is not of the
  variable's type, and a set carrying a member outside its base type is exactly
  that. It is one `and` against the base type's universe: the check a set
  constructor cannot make for itself, because a constructor does not know what
  it is being assigned to. }
procedure CheckedForSetBase(protected var v: str; target: typePtr;
                            line, col: integer);
var universe, notU, stray, bad, zero: str; msg: integer;
begin
  if IsSet(target) and (target^.elem <> nil) then
    { A base type covering the whole universe can hold anything a set value
      can carry, so `set of char` pays nothing. }
    if (OrdinalLo(target^.elem) <> 0) or
       (OrdinalHi(target^.elem) <> setLimit) then begin
      SetUniverse(target^.elem, universe);
      OpInt(-1, notU);
      Def(stray);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(universe);
      write(ircode, ', ');
      PutOp(notU);
      writeln(ircode);
      Def(bad);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(v);
      write(ircode, ', ');
      PutOp(stray);
      writeln(ircode);
      OpInt(0, zero);
      Def(notU);
      write(ircode, 'icmp ne i', setBits:1, ' ');
      PutOp(bad);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode);

      MsgStart;
      MsgText('set member out of range (               ');
      WriteTypeName(target);
      Put(')');
      msg := MsgEnd;
      EmitTrapIf(notU, msg, line, col)
    end
end;

{ A value entering a variable of `target`: the subrange check and the set check
  are the same idea for two kinds of type, so call sites ask once. }
procedure CheckedForStore(protected var v: str; target: typePtr;
                          line, col: integer);
begin
  CheckedForSubrange(v, target, line, col);
  CheckedForSetBase(v, target, line, col)
end;

{ A member's position in the bit vector, checked and widened. Every set shares
  one 256-bit representation, so the position must lie in 0..setLimit whatever
  the base type is -- a shift by more than that is poison in LLVM, and would be
  a silently wrong answer here. }
procedure SetIndex(e: nodePtr; var v: str);
var raw, lo, hi, below, above, bad: str; msg: integer; sign: boolean;
begin
  EmitExpr(e, raw);
  sign := IsInteger(e^.ntype);
  if sign or (LlSize(e^.ntype) > 1) then begin
    OpInt(0, lo);
    OpInt(setLimit, hi);
    MsgStart;
    MsgText('set member out of range                 ');
    msg := MsgEnd;
    if sign then begin
      Def(below);
      write(ircode, 'icmp slt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(above);
      write(ircode, 'icmp sgt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bad);
      write(ircode, 'or i1 ');
      PutOp(below);
      write(ircode, ', ');
      PutOp(above);
      writeln(ircode)
    end
    else begin
      Def(bad);
      write(ircode, 'icmp ugt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode)
    end;
    EmitTrapIf(bad, msg, e^.line, e^.col)
  end;
  Def(v);
  write(ircode, 'zext ');
  PutLlType(e^.ntype);
  write(ircode, ' ');
  PutOp(raw);
  write(ircode, ' to i', setBits:1);
  writeln(ircode)
end;

{ A set constructor, built by or-ing one member at a time into an empty set. A
  single value contributes 1 shifted left by it; a range lo..hi contributes the
  bits from lo to hi, which is the same pair of shifts SetUniverse uses -- with
  the difference that the bounds are expressions, so hi < lo is a run-time
  possibility and must yield the empty set rather than a mask of everything
  (ISO 7185 6.7.1). }
procedure EmitSet(e: nodePtr; var v: str);
var m: nodePtr; lo, hi, one, ones, bits, tmp, sh, empty, cmp, acc: str;
begin
  OpInt(0, acc);
  OpInt(1, one);
  OpInt(-1, ones);
  OpInt(0, empty);
  m := e^.seMembers;
  while m <> nil do begin
    SetIndex(m^.smLo, lo);
    if m^.smHi = nil then begin
      Def(bits);
      write(ircode, 'shl i', setBits:1, ' ');
      PutOp(one);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode)
    end
    else begin
      SetIndex(m^.smHi, hi);
      OpInt(setLimit, sh);
      Def(tmp);
      write(ircode, 'sub i', setBits:1, ' ');
      PutOp(sh);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bits);
      write(ircode, 'lshr i', setBits:1, ' ');
      PutOp(ones);
      write(ircode, ', ');
      PutOp(tmp);
      writeln(ircode);
      Def(tmp);
      write(ircode, 'shl i', setBits:1, ' ');
      PutOp(ones);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(sh);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(bits);
      write(ircode, ', ');
      PutOp(tmp);
      writeln(ircode);
      { An empty range selects nothing. Without this the two masks would still
        intersect in the bits between hi and lo. }
      Def(cmp);
      write(ircode, 'icmp ugt i', setBits:1, ' ');
      PutOp(lo);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bits);
      write(ircode, 'select i1 ');
      PutOp(cmp);
      write(ircode, ', i', setBits:1, ' ');
      PutOp(empty);
      write(ircode, ', i', setBits:1, ' ');
      PutOp(sh);
      writeln(ircode)
    end;
    Def(tmp);
    write(ircode, 'or i', setBits:1, ' ');
    PutOp(acc);
    write(ircode, ', ');
    PutOp(bits);
    writeln(ircode);
    acc := tmp;
    m := m^.next
  end;
  v := acc
end;

{ `x in s`. A member position outside 0..setLimit cannot be in any set, and
  answers false rather than trapping: the value is not of the base type, which
  is what `in` is there to report. }
procedure EmitIn(e: nodePtr; var v: str);
var raw, idx, limit, ok, safe, zero, one, set_, shifted, got, hit: str;
begin
  EmitExpr(e^.bnLhs, raw);
  { Widened with its own signedness, a value outside 0..setLimit lands outside
    that range in the 256-bit word too -- so one unsigned compare catches a
    negative value and an oversized one alike. }
  Def(idx);
  if IsInteger(e^.bnLhs^.ntype) then write(ircode, 'sext ')
  else write(ircode, 'zext ');
  PutLlType(e^.bnLhs^.ntype);
  write(ircode, ' ');
  PutOp(raw);
  write(ircode, ' to i', setBits:1);
  writeln(ircode);
  OpInt(setLimit + 1, limit);
  Def(ok);
  write(ircode, 'icmp ult i', setBits:1, ' ');
  PutOp(idx);
  write(ircode, ', ');
  PutOp(limit);
  writeln(ircode);
  { The shift is by a value LLVM has to see is under setBits, or it is
    poison. }
  OpInt(0, zero);
  Def(safe);
  write(ircode, 'select i1 ');
  PutOp(ok);
  write(ircode, ', i', setBits:1, ' ');
  PutOp(idx);
  write(ircode, ', i', setBits:1, ' ');
  PutOp(zero);
  writeln(ircode);
  EmitExpr(e^.bnRhs, set_);
  Def(shifted);
  write(ircode, 'lshr i', setBits:1, ' ');
  PutOp(set_);
  write(ircode, ', ');
  PutOp(safe);
  writeln(ircode);
  OpInt(1, one);
  Def(got);
  write(ircode, 'and i', setBits:1, ' ');
  PutOp(shifted);
  write(ircode, ', ');
  PutOp(one);
  writeln(ircode);
  Def(hit);
  write(ircode, 'icmp ne i', setBits:1, ' ');
  PutOp(got);
  write(ircode, ', ');
  PutOp(zero);
  writeln(ircode);
  Def(v);
  write(ircode, 'and i1 ');
  PutOp(ok);
  write(ircode, ', ');
  PutOp(hit);
  writeln(ircode)
end;

{ The set operators, all of them one instruction on the bit vector: union is
  `or`, intersection is `and`, difference is `and not`, and inclusion is
  "nothing left over" (ISO 7185 6.7.2.3, 6.7.2.5). }
procedure EmitSetBinary(e: nodePtr; protected var l, r: str; var v: str);
var notR, left, zero, ones: str;
begin
  case e^.bnOp of
    opAdd: begin
      Def(v);
      write(ircode, 'or i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opMul: begin
      Def(v);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    { 6.8.3.4's symmetric difference: the members of exactly one operand, which
      is xor and needs no more saying than the other three. }
    opSymDiff: begin
      Def(v);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opSub: begin
      OpInt(-1, ones);
      Def(notR);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(r);
      write(ircode, ', ');
      PutOp(ones);
      writeln(ircode);
      Def(v);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(notR);
      writeln(ircode)
    end;
    opEq, opNe: begin
      Def(v);
      if e^.bnOp = opEq then write(ircode, 'icmp eq i', setBits:1, ' ')
      else write(ircode, 'icmp ne i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    { `l <= r` is "l has nothing r lacks", and `l >= r` is the same question
      with the operands the other way round. }
    opLe, opGe, opLt, opGt, opRealDiv, opIntDiv, opMod, opAnd, opOr, opIn,
    opExp, opPow, opAndThen, opOrElse:
    begin
      OpInt(-1, ones);
      if e^.bnOp = opGe then begin notR := l; left := r end
      else begin notR := r; left := l end;
      Def(zero);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(notR);
      write(ircode, ', ');
      PutOp(ones);
      writeln(ircode);
      Def(notR);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(left);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode);
      OpInt(0, zero);
      Def(v);
      write(ircode, 'icmp eq i', setBits:1, ' ');
      PutOp(notR);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode)
    end
  end
end;

{ An argument list has to be complete before the call line can be written, so
  the operands are collected as they are emitted. }
procedure AppendOpnd(var head, tail: opndPtr; protected var v: str; asPtr: boolean;
                     t: typePtr);
var o: opndPtr;
begin
  new(o);
  o^.text := v;
  o^.asPtr := asPtr;
  o^.otype := t;
  o^.next := nil;
  if head = nil then head := o else tail^.next := o;
  tail := o
end;

{ The pair a procedural argument travels as. Naming a procedure with a body
  takes its address and the frame it was *declared* under; naming a procedural
  parameter forwards the pair that parameter already holds, so a procedure
  handed on through three levels still runs in its own scope. }
procedure EmitProcArgument(actual: symPtr; var head, tail: opndPtr);
var slot, half, code, link: str;
begin
  if actual^.kind = skProcParam then begin
    FrameSlot(actual, slot);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    Def(code);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    AppendOpnd(head, tail, code, true, nil);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 1');
    Def(link);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    AppendOpnd(head, tail, link, true, nil)
  end
  else begin
    StrClear(code);
    AppendProcName(code, actual);
    if (actual^.owner <> nil) and actual^.owner^.compiledElsewhere then
      NeedExternalProc(actual);
    AppendOpnd(head, tail, code, true, nil);
    FrameOf(actual^.owner, link);
    AppendOpnd(head, tail, link, true, nil)
  end
end;

{ The parameter types the defining side writes, and the one writer of them:
  declared here so that PutProcSignature can use it, defined beside
  EmitProcBody where it is read. }
procedure PutParamTypes(p: symListPtr; named: boolean); forward;

{ The signature an indirect call through a procedural parameter uses: the
  static link, then the parameters, exactly as EmitProcBody builds it for a
  procedure with a body -- and written by the same procedure, because this
  was a copy of it and a copy is free to drift. It drifted twice: ADR-0115's
  variable-string value parameter and ADR-0125's slice each became two
  arguments on the defining side, and this went on declaring one, so a call
  through a procedural parameter with such a formal passed three arguments
  to a type naming two and clang refused the module
  (tests/extended/procparam_string.pas). }
procedure PutProcSignature(callee: symPtr);
var result: typePtr;
begin
  result := ResultTypeOf(callee);
  { A result that lives in memory (ADR-0017) has no register form, and the
    callee's activation record dies at the return, so the storage cannot be
    there. The caller supplies it and its address travels as a hidden argument
    after the static link; the function then returns void. That is ADR-0030's
    choice again -- a procedural parameter's pair and a schematic parameter's
    tuple both travel as extra scalar arguments, so nothing here depends on how
    a struct is passed, because none ever is. }
  if result = nil then write(ircode, 'void')
  else if IsMemory(result) then write(ircode, 'void')
  else PutLlType(result);
  write(ircode, ' (ptr');
  if result <> nil then
    if IsMemory(result) then write(ircode, ', ptr');
  PutParamTypes(callee^.params, false);
  write(ircode, ')')
end;

{ The k'th discriminant of the tuple this expression's type was produced with.
  A generic type belongs to one variable -- nothing else can be given it, and a
  subscript of one would already have yielded the component -- so an expression
  possessing one *is* that variable, and its tuple is in the descriptor. A heap
  variable carries its tuple in front of it, so any designator of one answers,
  not only a name: `p^` is not a name and `q^[1]^` is not even a pointer
  variable. Every other type produced from a schema was produced from
  constants, and they are on the type. }
procedure DiscValue(e: nodePtr; k: integer; want: typePtr; var v: str);
var d: symListPtr; tv: numPtr; i: integer; hdr, half, raw: str;
begin
  if e^.ntype^.heapTuple then begin
    HeapHeader(e, hdr);
    Def(half);
    write(ircode, 'getelementptr i32, ptr ');
    PutOp(hdr);
    writeln(ircode, ', i32 ', k:1);
    Def(raw);
    write(ircode, 'load i32, ptr ');
    PutOp(half);
    writeln(ircode);
    { The header holds one i32 per discriminant whatever its own type. }
    if IsChar(want) or IsBoolean(want) then begin
      Def(v);
      write(ircode, 'trunc i32 ');
      PutOp(raw);
      write(ircode, ' to ');
      PutLlType(want);
      writeln(ircode)
    end
    else
      v := raw
  end
  else if IsGeneric(e^.ntype) and (e^.kind = nkVar) then begin
    d := e^.vrSym^.discSyms;
    for i := 1 to k do
      if d <> nil then d := d^.next;
    if d = nil then OpInt(0, v)
    else begin
      AddressOfSym(d^.sym, half);
      Def(v);
      write(ircode, 'load ');
      PutLlType(want);
      write(ircode, ', ptr ');
      PutOp(half);
      writeln(ircode)
    end
  end
  else begin
    tv := e^.ntype^.tuple;
    for i := 1 to k do
      if tv <> nil then tv := tv^.next;
    if tv = nil then OpInt(0, v) else OpInt(tv^.value_, v)
  end
end;

{ ISO 7185 6.6.3.7's descriptor, filled from the actual: one pair of bounds per
  index-type-specification, in the order ConfBound numbered them, flattened
  across the whole nest.

  Two shapes of actual, and the second is what makes a conformant array
  parameter passable on. Where the actual is an ordinary array its bounds are
  constants and OpInt writes them; where it is itself a conformant array
  parameter its bounds are its own caller's descriptor, and DiscValue reads
  them the way it reads a schematic formal's -- which it can, because
  BoundSchemaFor made the formal's type generic and a generic nkVar is the case
  DiscValue already had. So `q(a)` inside `q` hands the same bounds down
  without the compiler needing a case for it. }
{ A descriptor field has the discriminant's own type, and BoundValue works in
  i32 -- so a bound of a type narrower than that is truncated on the way in,
  which is what DiscValue does for a schema's discriminants and for the same
  reason. char and boolean are the two: an enumeration is already i32.
  `array [l..u: boolean] of real` is BSI's LEV1F28, and without this the module
  it emitted was refused by LLVM rather than by the compiler. }
procedure NarrowBound(var v: str; want: typePtr);
var narrow: str;
begin
  if IsChar(want) or IsBoolean(want) then begin
    Def(narrow);
    write(ircode, 'trunc i32 ');
    PutOp(v);
    write(ircode, ' to ');
    PutLlType(want);
    writeln(ircode);
    v := narrow
  end
end;

procedure EmitConfBounds(arg: nodePtr; t1, f: typePtr;
                         var head, tail: opndPtr);
var a, hdr: str; want: typePtr;
begin
  want := f^.indexType^.host;
  { **BoundValue, and nothing else.** It answers a constant where the actual's
    bound is one and reads the descriptor where it is not, so all three shapes
    of actual go through one call: an ordinary array, a schematic formal's
    `array [1..n]`, and a conformant array parameter being handed on.

    The first draft asked DiscValue instead, which reads the k-th discriminant
    of a *bare name* -- and so answered 0 for `y[i]`, a row of a
    two-dimensional conformant array passed to a one-dimensional one. The
    bounds of that row are fields of y's descriptor, and loDisc and hiDisc on
    the row's own type name them; walking the designator was never necessary.
    BSI's LEV1F45 is the program that sorts the rows of a matrix. }
  HeapHeader(arg, hdr);
  BoundValue(t1, false, hdr, a);
  NarrowBound(a, want);
  AppendOpnd(head, tail, a, false, want);
  BoundValue(t1, true, hdr, a);
  NarrowBound(a, want);
  AppendOpnd(head, tail, a, false, want);
  if f^.elem^.isConfSchema then
    EmitConfBounds(arg, t1^.elem, f^.elem, head, tail)
end;

{ ADR-0125: the pair a slice is, from whatever designator produced it. The
  single path to one, the way EmitString is the single path to a string's
  pointer-and-length -- and the same three shapes: a slice formal, which holds
  its pair in a slot; a whole array, whose address is its first component's and
  whose count is its extent; and `a[i..j]`, which is the first two with
  arithmetic on top.

  The range is checked here and not by the callee, because this is where the
  base's own extent is still known. }
procedure EmitSliceValue(e: nodePtr; var base, len: str);
var t, bt: typePtr; slot, half, hdr, lo, hi, off, adj, stride, bytes: str;
begin
  t := e^.ntype;
  if (e^.kind = nkVar) and (e^.vrField = nil) and IsSlice(e^.vrSym^.stype) then
  begin
    { A slice formal, handed on. Both halves come out of the slot; nothing is
      re-checked, the pair having been checked where it was made. }
    FrameSlot(e^.vrSym, slot);
    Def(half);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(t);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    Def(base);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    Def(half);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(t);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 1');
    Def(len);
    write(ircode, 'load i32, ptr ');
    PutOp(half);
    writeln(ircode)
  end
  else if e^.kind = nkSubstr then begin
    EmitSliceValue(e^.ssBase, base, len);
    bt := e^.ssBase^.ntype;
    EmitExpr(e^.ssLo, lo);
    EmitExpr(e^.ssHi, hi);
    { An array carries its own lower bound and a slice is always 1-based, so
      the indices are normalised before anything is checked -- which is what
      lets one runtime routine answer for both. }
    if IsArray(bt) and not IsSlice(bt) then begin
      StrClear(hdr);
      if DynamicExtent(bt) then HeapHeader(e^.ssBase, hdr);
      BoundValue(bt, false, hdr, off);
      Def(adj);
      write(ircode, 'sub i32 ');
      PutOp(lo);
      write(ircode, ', ');
      PutOp(off);
      writeln(ircode);
      Def(lo);
      write(ircode, 'add i32 ');
      PutOp(adj);
      writeln(ircode, ', 1');
      Def(adj);
      write(ircode, 'sub i32 ');
      PutOp(hi);
      write(ircode, ', ');
      PutOp(off);
      writeln(ircode);
      Def(hi);
      write(ircode, 'add i32 ');
      PutOp(adj);
      writeln(ircode, ', 1')
    end;
    EmitAt(e^.line, e^.col);
    write(ircode, '  call void @pas_slice_check(i32 ');
    PutOp(lo);
    write(ircode, ', i32 ');
    PutOp(hi);
    write(ircode, ', i32 ');
    PutOp(len);
    writeln(ircode, ')');
    EmitAtDone;
    { The new count, and then the new base: (hi - lo) + 1 components, starting
      (lo - 1) of them along. }
    Def(adj);
    write(ircode, 'sub i32 ');
    PutOp(hi);
    write(ircode, ', ');
    PutOp(lo);
    writeln(ircode);
    Def(len);
    write(ircode, 'add i32 ');
    PutOp(adj);
    writeln(ircode, ', 1');
    Def(off);
    write(ircode, 'sub i32 ');
    PutOp(lo);
    writeln(ircode, ', 1');
    Def(bytes);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(t^.elem);
    write(ircode, ', ptr ');
    PutOp(base);
    write(ircode, ', i32 ');
    PutOp(off);
    writeln(ircode);
    base := bytes
  end
  else begin
    { A whole array. Its address is its first component's -- ADR-0017 lays an
      array out as its components and nothing else -- and its extent is what
      DynLength answers, which is a constant unless a discriminant decided it. }
    EmitAddress(e, base);
    StrClear(hdr);
    if DynamicExtent(e^.ntype) then HeapHeader(e, hdr);
    DynLength(e^.ntype, hdr, len)
  end;
  StrClear(stride)
end;

{ ADR-0121 said the call site is the whole of the ABI -- LLVM does not check a
  direct call against the declaration under opaque pointers -- and ADR-0122
  makes that literal: a foreign call's arguments are their own rule, because
  none of the four shapes above describes one. There is no descriptor, no
  pointer-and-length pair and no callee prologue to convert anything. }
procedure EmitForeignArgument(arg: nodePtr; f: symPtr;
                              var head, tail: opndPtr);
var a, alen, cs: str;
begin
  { ADR-0129: the address and the count, in that order and as two arguments
    from one formal. The count is widened because every length this target's
    data path takes is a `size_t`; the range it names was checked where the
    designator was written, which is where the base's own extent was still
    known, so what C receives is a bound this compiler proved. }
  if IsSlice(f^.stype) then begin
    EmitSliceValue(arg, a, alen);
    ToInt64(alen, intType);
    AppendOpnd(head, tail, a, true, nil);
    AppendOpnd(head, tail, alen, false, int64Type)
  end
  else if f^.kind = skVarParam then begin
    { The actual's own storage. Sema has already required a variable, so this
      is the same address any other var parameter would bind to -- what is
      missing is only the callee's willingness to give it back. }
    EmitAddress(arg, a);
    AppendOpnd(head, tail, a, true, nil)
  end
  { AP 6.4.12.4: a handle is lent. The word inside the slot crosses and the
    variable keeps ownership; the runtime is what says an empty one may not
    be lent (Annex A.7), because a C routine given NULL for a stream does not
    report. }
  else if IsHandle(f^.stype) then begin
    EmitAddress(arg, a);
    EmitAt(arg^.line, arg^.col);
    Def(cs);
    write(ircode, 'call ptr @pas_handle_lend(ptr ');
    PutOp(a);
    writeln(ircode, ')');
    EmitAtDone;
    AppendOpnd(head, tail, cs, true, nil)
  end
  else if ForeignStringFormal(f) then begin
    { The pair becomes one pointer: a C string carries its length in-band, so
      the NUL is what the length turns into. The copy is arena storage, which
      is exactly the lifetime wanted -- longer than the argument list, no
      longer than the statement -- and being arena storage it has to bump
      ADR-0111's counter, this being a third producer. }
    EmitString(arg, a, alen);
    strTemps := strTemps + 1;   { ADR-0111: this statement must release }
    EmitAt(arg^.line, arg^.col);
    Def(cs);
    write(ircode, 'call ptr @pas_str_cstr(ptr ');
    PutOp(a);
    write(ircode, ', i32 ');
    PutOp(alen);
    writeln(ircode, ')');
    EmitAtDone;
    AppendOpnd(head, tail, cs, true, nil)
  end
  else begin
    EmitExpr(arg, a);
    ConvertFor(a, arg^.ntype, f^.stype);
    CheckedForStore(a, f^.stype, arg^.line, arg^.col);
    AppendOpnd(head, tail, a, false, f^.stype)
  end
end;

{ slotSym is the call site's own storage for a result that lives in memory
  (6.7.2); nil for every other call, and unread for them. }
procedure EmitUserCall(callee: symPtr; args: nodePtr; slotSym: symPtr;
                       var v: str; line, col: integer);
var link, a, alen, slot, half, target, resAddr, padded: str;
    head, tail, o: opndPtr;
    p, dp: symListPtr; arg: nodePtr; result: typePtr; k: integer;
    byAddr, comma, foreignPtr: boolean;
begin
  StrClear(target);
  if callee^.kind = skProcParam then begin
    { The link to run under comes out of the pair, not from the static chain:
      the caller's chain says nothing about where the passed procedure was
      declared, which is the reason the link had to be carried at all. }
    FrameSlot(callee, slot);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    Def(target);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 1');
    Def(link);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode)
  end
  else if callee^.linkKind = lnkForeign then begin
    { ADR-0121: a foreign function has no enclosing activation, so the static
      link that leads every other call here is simply not written. Nothing
      else about the call changes -- every argument already travels as a
      separate scalar, because nothing here may depend on how a struct is
      passed (ADR-0030), which is exactly what a C ABI wants. }
    StrClear(link);
    AppendProcName(target, callee);
    NeedExternalProc(callee)
  end
  else begin
    { A callee declared at level L runs with the frame at level L-1 as its
      enclosing scope -- which for a recursive call is the caller's own
      parent, not the caller. }
    FrameOf(callee^.owner, link);
    AppendProcName(target, callee);
    { An instantiation is the exception, and has to be: AP 6.7.3.10 produces it
      *here*, in the translation that named the types, however far away the
      generic was declared. Its owner may well be a module compiled elsewhere
      -- that is the whole point of a generic in a library -- but the routine
      itself is in this module's own output, so declaring it external would
      make it defined and declared at once. }
    if callee^.owner^.compiledElsewhere and (callee^.genOf = nil) then
      NeedExternalProc(callee)
  end;

  head := nil;
  tail := nil;
  arg := args;
  p := callee^.params;
  while (arg <> nil) and (p <> nil) do begin
    if callee^.linkKind = lnkForeign then
      EmitForeignArgument(arg, p^.sym, head, tail)
    else if p^.sym^.kind = skProcParam then
      EmitProcArgument(ProcActualSym(arg), head, tail)
    { The address, then the tuple the actual was produced with -- constants
      where the actual is an ordinary variable, and the caller's own descriptor
      where it is itself a schematic formal, which is how a schematic array is
      handed on through any number of blocks. }
    { 6.6.3.7's conformant array parameter: the address, then the actual's own
      bounds. Same slot and same shape as the schematic formal below it; what
      differs is where the numbers come from, the actual not having been
      produced from a schema. }
    else if p^.sym^.isConformant then begin
      EmitAddress(arg, a);
      AppendOpnd(head, tail, a, true, nil);
      EmitConfBounds(arg, arg^.ntype, p^.sym^.stype, head, tail)
    end
    { 6.7.3.2's `string` value parameter travels as the pair EmitString
      already builds -- the value's address and the value's *length* -- which
      is the same two arguments a one-discriminant descriptor is, so the
      callee's prologue is unchanged and copies the length it was handed. That
      the shapes coincide is what makes the clause's rule free: the capacity
      the formal possesses is the length of the value, which is exactly what
      arrives. }
    else if StringValueFormal(p^.sym) then begin
      EmitString(arg, a, alen);
      AppendOpnd(head, tail, a, true, nil);
      AppendOpnd(head, tail, alen, false, intType)
    end
    else if p^.sym^.descSchema <> nil then begin
      EmitAddress(arg, a);
      AppendOpnd(head, tail, a, true, nil);
      k := 0;
      dp := p^.sym^.descSchema^.discs;
      while dp <> nil do begin
        DiscValue(arg, k, dp^.sym^.stype, a);
        AppendOpnd(head, tail, a, false, dp^.sym^.stype);
        k := k + 1;
        dp := dp^.next
      end
    end
    else if (p^.sym^.kind <> skVarParam) and IsStringRep(p^.sym^.stype) then
    begin
      { The pair, not an address: the actual need not be a variable and need
        not have the formal's capacity, so what travels is the value 6.4.6
        will store (ADR-0115). The conversion is the callee's, because only
        its slot has the capacity to pad to. }
      EmitString(arg, a, alen);
      AppendOpnd(head, tail, a, true, nil);
      AppendOpnd(head, tail, alen, false, intType)
    end
    { 6.4.6's padding, built where the actual's length is known. A structured
      value parameter travels as an address (ADR-0017) and a shorter actual has
      none of the formal's shape, so the conversion happens at the call and
      what travels is the address of the converted value -- the mirror of
      ADR-0115's variable-string parameter, where the capacity is the callee's
      and the conversion is therefore its own. The storage is the string arena,
      which is exactly the lifetime wanted: longer than the argument list, no
      longer than the statement (ADR-0111). An alloca could not have served --
      a call inside a loop would claim one on every iteration (ADR-0102) -- and
      being an arena producer this bumps that counter, which nothing checks. }
    else if (p^.sym^.kind <> skVarParam) and
            PadsToFixedString(p^.sym^.stype, arg^.ntype) then begin
      EmitString(arg, a, alen);
      strTemps := strTemps + 1;   { ADR-0111: this statement must release }
      EmitAt(arg^.line, arg^.col);
      Def(padded);
      write(ircode, 'call ptr @pas_str_pad(i32 ',
            TypeLength(p^.sym^.stype):1, ', ptr ');
      PutOp(a);
      write(ircode, ', i32 ');
      PutOp(alen);
      writeln(ircode, ')');
      EmitAtDone;
      AppendOpnd(head, tail, padded, true, nil)
    end
    { ADR-0125: the address of the first component and how many there are.
      The range was checked where the designator was written, which is the
      only place the base's own extent is still known. }
    else if IsSlice(p^.sym^.stype) then begin
      EmitSliceValue(arg, a, alen);
      AppendOpnd(head, tail, a, true, nil);
      AppendOpnd(head, tail, alen, false, intType)
    end
    else begin
      if (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype) then
        { A `var` parameter binds to the variable itself; a structured value
          parameter is copied from it by the callee. Either way an address
          travels, and Sema has already required something that has one. }
        EmitAddress(arg, a)
      else begin
        EmitExpr(arg, a);
        ConvertFor(a, arg^.ntype, p^.sym^.stype);
        CheckedForStore(a, p^.sym^.stype, arg^.line, arg^.col)
      end;
      AppendOpnd(head, tail, a,
                 (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype),
                 p^.sym^.stype)
    end;
    arg := arg^.next;
    p := p^.next
  end;

  result := ResultTypeOf(callee);
  { Where to build a result that lives in memory. Sema gave this call site a
    frame slot of its own; the callee writes through the address and hands
    nothing back, so the call *is* the storage and this address is what the
    expression evaluates to. The address is taken before the call line is
    started, because the emitter is sequential. }
  byAddr := false;
  if result <> nil then byAddr := IsMemory(result);
  { ADR-0123: a foreign function answers a `ptr` in a register, so the result
    slot is not an argument to it -- it is where the answer is *put*, after
    the call, by the four lines at the end of this procedure. }
  foreignPtr := byAddr and (callee^.linkKind = lnkForeign);
  if foreignPtr then byAddr := false;
  if byAddr then
    { AP 6.4.12.6 (ADR-0255): a factory writes into the variable that will own
      the handle, and there is no slot to write into instead -- NewResultSlot
      makes none for a handle, a slot here being a second handle the prologue
      would register and the epilogue release. `factoryInto` is where the
      assignment said to build it, read and cleared here. }
    if factoryInto <> nil then begin
      EmitAddress(factoryInto, resAddr);
      factoryInto := nil
    end
    else AddressOfSym(slotSym, resAddr);
  if (result <> nil) and not byAddr then begin
    Def(v);
    write(ircode, 'call ')
  end
  else begin
    StrClear(v);
    write(ircode, '  call ')
  end;
  { An indirect call states the whole signature; a direct one names a function
    whose signature the module already carries. }
  if callee^.kind = skProcParam then
    PutProcSignature(callee)
  else if foreignPtr then write(ircode, 'ptr')
  else if (result = nil) or byAddr then write(ircode, 'void')
  else PutLlType(result);
  write(ircode, ' ');
  PutOp(target);
  write(ircode, '(');
  { With no static link there is nothing before the first argument, so the
    separator has to be counted rather than assumed. }
  comma := true;
  if callee^.linkKind = lnkForeign then comma := false
  else begin
    write(ircode, 'ptr ');
    PutOp(link)
  end;
  if byAddr then begin
    if comma then write(ircode, ', ');
    write(ircode, 'ptr ');
    PutOp(resAddr);
    comma := true
  end;
  o := head;
  while o <> nil do begin
    if comma then write(ircode, ', ');
    comma := true;
    if o^.asPtr then write(ircode, 'ptr') else PutLlType(o^.otype);
    write(ircode, ' ');
    PutOp(o^.text);
    o := o^.next
  end;
  writeln(ircode, ')');
  if byAddr then v := resAddr;
  { The pointer C answered, made into an optional. `pas_cstr_take` copies the
    characters and reports whether there were any; the flag is stored here,
    because the layout of an optional is CodeGen's and no runtime routine may
    hold a second opinion about it. NULL is absence and is not an error --
    which is the whole of what ADR-0122 was missing. }
  if foreignPtr and IsHandle(result) then
    { AP 6.4.12.2: the word is the value, and the assignment this call is
      the right side of stores it into the variable that owns it }
  else if foreignPtr then begin
    AddressOfSym(slotSym, resAddr);
    OptionalPart(resAddr, result, 1, slot);
    EmitAt(line, col);
    Def(half);
    { AP 6.7.7.8 (ADR-0187): a record's copy is a guarded memcpy where a
      string's is a guarded strlen-and-store, and the two are one shape --
      each routine reports whether there was a value, and the four lines after
      this `if` store the flag, because the layout of an optional is CodeGen's.
      The length is the *record's* size and not the struct's: that a C compiler
      laid the same thing out is a claim the program makes (6.7.7.6.2), and
      this reads exactly the fields the program declared. }
    if IsRecord(result^.elem) then begin
      write(ircode, 'call i32 @pas_rec_take(ptr ');
      PutOp(slot);
      write(ircode, ', i64 ', LlSize(result^.elem):1, ', ptr ');
      PutOp(v);
      writeln(ircode, ')')
    end
    else begin
      write(ircode, 'call i32 @pas_cstr_take(ptr ');
      PutOp(slot);
      write(ircode, ', i32 ', result^.elem^.hi:1, ', ptr ');
      PutOp(v);
      writeln(ircode, ')')
    end;
    EmitAtDone;
    OptionalPart(resAddr, result, 0, alen);
    write(ircode, '  store i32 ');
    PutOp(half);
    write(ircode, ', ptr ');
    PutOp(alen);
    writeln(ircode);
    v := resAddr
  end
end;

{ ISO 7185 6.7.2.5 orders equal-length strings by their first differing
  character, which is what the runtime helper reports; the operator then only
  has to say what it wants of the sign. }
procedure EmitStringCompare(e: nodePtr; var v: str);
var lhs, rhs, cmp, len, other, bad, lhdr, rhdr: str;
begin
  EmitAddress(e^.bnLhs, lhs);
  EmitAddress(e^.bnRhs, rhs);
  HeapHeader(e^.bnLhs, lhdr);
  DynLength(e^.bnLhs^.ntype, lhdr, len);
  { Sema requires equal lengths, and can say so wherever both are numbers.
    Where one is a discriminant the requirement is the same one, made here --
    and it has to be made, because a comparison over the wrong number of
    characters answers rather than failing. }
  if DynamicExtent(e^.bnLhs^.ntype) or DynamicExtent(e^.bnRhs^.ntype) then begin
    HeapHeader(e^.bnRhs, rhdr);
    DynLength(e^.bnRhs^.ntype, rhdr, other);
    Def(bad);
    write(ircode, 'icmp ne i32 ');
    PutOp(len);
    write(ircode, ', ');
    PutOp(other);
    writeln(ircode);
    EmitTrapLength(bad, len, other, e^.line, e^.col)
  end;
  Def(cmp);
  write(ircode, 'call i32 @pas_str_compare(ptr ');
  PutOp(lhs);
  write(ircode, ', ptr ');
  PutOp(rhs);
  write(ircode, ', i32 ');
  PutOp(len);
  writeln(ircode, ')');
  Def(v);
  case e^.bnOp of
    opEq: write(ircode, 'icmp eq i32 ');
    opNe: write(ircode, 'icmp ne i32 ');
    opLt: write(ircode, 'icmp slt i32 ');
    opLe: write(ircode, 'icmp sle i32 ');
    opGt: write(ircode, 'icmp sgt i32 ');
    opGe: write(ircode, 'icmp sge i32 ');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse, opSymDiff:
      write(ircode, 'icmp eq i32 ')
  end;
  PutOp(cmp);
  writeln(ircode, ', 0')
end;

{ The overflow-reporting form of +, - and *. }
{ `i32` or `i64`, and the least value of the machine word behind each. ADR-0128
  makes int64 the same arithmetic one width wider, so every emitter below takes
  the width rather than being written twice -- two copies of a checked multiply
  is two places for the check to go missing from. }
procedure PutIntWidth(wide: boolean);
begin
  if wide then write(ircode, 'i64') else write(ircode, 'i32')
end;

procedure PutIntMin(wide: boolean);
begin
  if wide then write(ircode, '-9223372036854775808')
  else write(ircode, '-2147483648')
end;

procedure EmitCheckedArith(which: char; protected var l, r: str; var v: str;
                           msg: integer;
                           wide: boolean; line, col: integer);
var pair, ovf, isMin, bad: str;
begin
  Def(pair);
  write(ircode, 'call { ');
  PutIntWidth(wide);
  write(ircode, ', i1 } @llvm.');
  if which = '+' then write(ircode, 'sadd')
  else if which = '-' then write(ircode, 'ssub')
  else write(ircode, 'smul');
  write(ircode, '.with.overflow.');
  PutIntWidth(wide);
  write(ircode, '(');
  PutIntWidth(wide);
  write(ircode, ' ');
  PutOp(l);
  write(ircode, ', ');
  PutIntWidth(wide);
  write(ircode, ' ');
  PutOp(r);
  writeln(ircode, ')');
  Def(v);
  write(ircode, 'extractvalue { ');
  PutIntWidth(wide);
  write(ircode, ', i1 } ');
  PutOp(pair);
  writeln(ircode, ', 0');
  Def(ovf);
  write(ircode, 'extractvalue { ');
  PutIntWidth(wide);
  write(ircode, ', i1 } ');
  PutOp(pair);
  writeln(ircode, ', 1');
  { -maxint..maxint is the integer type (6.4.2.2), so a result of INT_MIN is
    out of range even though it fits the machine word. ADR-0128 gives int64 the
    same shape -- -maxint64..maxint64 -- so the same test answers for both. }
  Def(isMin);
  write(ircode, 'icmp eq ');
  PutIntWidth(wide);
  write(ircode, ' ');
  PutOp(v);
  write(ircode, ', ');
  PutIntMin(wide);
  writeln(ircode);
  Def(bad);
  write(ircode, 'or i1 ');
  PutOp(ovf);
  write(ircode, ', ');
  PutOp(isMin);
  writeln(ircode);
  EmitTrapIf(bad, msg, line, col)
end;

procedure GuardNonZero(protected var r: str; msg: integer; wide: boolean;
                       line, col: integer);
var zero: str;
begin
  Def(zero);
  write(ircode, 'icmp eq ');
  PutIntWidth(wide);
  write(ircode, ' ');
  PutOp(r);
  writeln(ircode, ', 0');
  EmitTrapIf(zero, msg, line, col)
end;

{ 6.7.2.2 (D.46): "a term of the form i mod j shall be an error if j is zero
  or negative". Both halves, in the words Sema's folder already uses for a
  constant divisor -- which is what makes the two answers the same answer.
  Before this, `const c = 5 mod -3` was a diagnostic and the same expression
  over a variable quietly computed 1. }
procedure GuardPositive(protected var r: str; msg: integer; wide: boolean;
                        line, col: integer);
var nonpos: str;
begin
  Def(nonpos);
  write(ircode, 'icmp sle ');
  PutIntWidth(wide);
  write(ircode, ' ');
  PutOp(r);
  writeln(ircode, ', 0');
  EmitTrapIf(nonpos, msg, line, col)
end;

{ 6.7.2.2 (D.44): "a term of the form x/y shall be an error if y is zero".
  IEEE would answer with an infinity, which is not a value of the real-type.
  The complex division uses this too, on c*c + d*d -- that number is zero
  exactly when the divisor is, so one comparison serves rather than two. }
procedure GuardRealNonZero(protected var r: str; msg, line, col: integer);
var zero: str;
begin
  Def(zero);
  write(ircode, 'fcmp oeq double ');
  PutOp(r);
  writeln(ircode, ', 0.0');
  EmitTrapIf(zero, msg, line, col)
end;

{ 6.6.6.2 (D.34): "for sqrt(x), it is an error if x is negative". Without the
  check the answer is a NaN, which is not a value of the real-type either. }
procedure GuardSqrtArg(protected var x: str; msg, line, col: integer);
var bad: str;
begin
  Def(bad);
  write(ircode, 'fcmp olt double ');
  PutOp(x);
  writeln(ircode, ', 0.0');
  EmitTrapIf(bad, msg, line, col)
end;

{ 6.6.6.2 (D.33): "for ln(x), it is an error if x is not greater than zero" --
  so zero as well as negative, where sqrt admits zero. That one value is the
  whole difference between this procedure and the one above it. }
procedure GuardLnArg(protected var x: str; msg, line, col: integer);
var bad: str;
begin
  Def(bad);
  write(ircode, 'fcmp ole double ');
  PutOp(x);
  writeln(ircode, ', 0.0');
  EmitTrapIf(bad, msg, line, col)
end;

{ ISO 7185 6.6.6.2: trunc and round are errors unless the result is a value of
  the integer type. The bounds are the exactly-representable powers of two just
  outside the range, and the comparisons are *ordered*, so a NaN fails both and
  traps rather than converting to something unspecified. }
procedure CheckedFpToInt(protected var x: str; var v: str;
                         msg, line, col: integer);
var gt, lt, ok, bad: str;
begin
  Def(gt);
  write(ircode, 'fcmp ogt double ');
  PutOp(x);
  writeln(ircode, ', -2147483648.0');
  Def(lt);
  write(ircode, 'fcmp olt double ');
  PutOp(x);
  writeln(ircode, ', 2147483648.0');
  Def(ok);
  write(ircode, 'and i1 ');
  PutOp(gt);
  write(ircode, ', ');
  PutOp(lt);
  writeln(ircode);
  Def(bad);
  write(ircode, 'xor i1 ');
  PutOp(ok);
  writeln(ircode, ', true');
  EmitTrapIf(bad, msg, line, col);
  Def(v);
  write(ircode, 'fptosi double ');
  PutOp(x);
  writeln(ircode, ' to i32')
end;

{ --coverage's second dimension (ADR-0274). One call on each edge of every
  decision the *source* writes, carrying where the decision stands and which
  way it went -- 1 for the condition true, 0 for false, and for a repeat that
  is the iteration that ends rather than the one that runs.

  A statement counter cannot answer this. EmitStmt writes one call per
  statement keyed on its *line*, so `if c then a else b` on one line is
  covered when either arm runs, and `if c then a` with no else has no
  statement at all on its false side. The column is what separates two
  decisions written on one line, which is why the identity is a pair.

  The four callers each have to give the untaken direction a block of its
  own, and none of them may share one that anything else can reach: a while's
  exit block is where AP 6.7.5.10's break lands, and a repeat's body block is
  entered once before the first test. A counter placed in either would report
  a direction that was never taken. }
procedure CovBranch(n: nodePtr; dir: integer);
begin
  if covOpt and (n <> nil) then
    if n^.line > 0 then
      writeln(ircode, '  call void @pas_cov_branch(i32 ', n^.line:1,
              ', i32 ', n^.col:1, ', i32 ', dir:1, ')')
end;

{ `and` and `or` short-circuit, which is what makes a guarded test such as
  `while (i <= n) and (a[i] <> x)` safe to write (ADR-0010). Extended Pascal's
  `and then` and `or else` (6.8.3.3) *require* that, so the one lowering serves
  all four -- the difference between them is a promise to the programmer, not
  a difference in the code. }
procedure EmitShortCircuit(e: nodePtr; var v: str);
var lhs, rhs: str; isAnd: boolean;
    rhsB, endB, skipB, lhsEnd, rhsEnd: integer;
begin
  isAnd := (e^.bnOp = opAnd) or (e^.bnOp = opAndThen);
  EmitExpr(e^.bnLhs, lhs);
  lhsEnd := curBlock;
  rhsB := NewBlock;
  endB := NewBlock;
  { The skipped direction reaches the join directly, so under --coverage it
    needs a block to be counted in -- and the phi's incoming label moves with
    it, that edge now arriving from the counter rather than from wherever the
    left operand finished (ADR-0274). }
  if covOpt then skipB := NewBlock else skipB := endB;
  write(ircode, '  br i1 ');
  PutOp(lhs);
  if isAnd then
    writeln(ircode, ', label %L', rhsB:1, ', label %L', skipB:1)
  else
    writeln(ircode, ', label %L', skipB:1, ', label %L', rhsB:1);

  StartBlock(rhsB);
  CovBranch(e, 1);
  EmitExpr(e^.bnRhs, rhs);
  rhsEnd := curBlock;
  writeln(ircode, '  br label %L', endB:1);

  if covOpt then begin
    StartBlock(skipB);
    CovBranch(e, 0);
    writeln(ircode, '  br label %L', endB:1);
    lhsEnd := skipB
  end;

  StartBlock(endB);
  Def(v);
  write(ircode, 'phi i1 [ ');
  if isAnd then write(ircode, 'false') else write(ircode, 'true');
  write(ircode, ', %L', lhsEnd:1, ' ], [ ');
  PutOp(rhs);
  writeln(ircode, ', %L', rhsEnd:1, ' ]')
end;

{ The four arithmetic operators and the two relational ones ISO/IEC 10206:1991
  gives the complex type. All six are emitted inline: nothing here needs a
  library, and keeping them out of the runtime keeps the *only* complex-shaped
  value crossing a C boundary out of existence -- which is what lets the
  representation stay a vector without either backend acquiring an opinion
  about how a struct is passed (ADR-0030's constraint). }
{ One `<op> double x, y`. The complex arithmetic is a dozen of these, and
  spelling each out would bury the formula in the emission. }
procedure EmitFBin(op: msgLit; x, y: str; var v: str);
begin
  Def(v);
  PutIrLit(op);
  write(ircode, ' double ');
  PutOp(x);
  write(ircode, ', ');
  PutOp(y);
  writeln(ircode)
end;

{ 6.8.3.2 table 3 gives `**` and `pow` a complex *left* operand, and the right
  one is never complex -- a real for `**`, an integer for `pow`. Both go to the
  runtime, which carries the standard's two special cases with them. }
procedure EmitComplexPow(e: nodePtr; l, r: str; lt, rt: typePtr;
                         realExp: boolean; var v: str);
var re, im, pr, pi_: str;
begin
  ToComplex(l, lt);
  ReOf(l, re);
  ImOf(l, im);
  if realExp then ToReal(r, rt);
  Def(pr);
  if realExp then write(ircode, 'call double @pas_cpow_re(double ')
  else write(ircode, 'call double @pas_cpowi_re(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  if realExp then write(ircode, ', double ') else write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  Def(pi_);
  if realExp then write(ircode, 'call double @pas_cpow_im(double ')
  else write(ircode, 'call double @pas_cpowi_im(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  if realExp then write(ircode, ', double ') else write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  MakeComplex(pr, pi_, v)
end;

procedure EmitComplexBinary(e: nodePtr; l, r: str; var v: str);
var a, b_, c_, d_, ac, bd, ad, bc, re, im, den, cc, dd, er, ei: str;
    cmsg: integer;
begin
  case e^.bnOp of
    opAdd: begin
      Def(v);
      write(ircode, 'fadd <2 x double> ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opSub: begin
      Def(v);
      write(ircode, 'fsub <2 x double> ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    { (a + bi)(c + di) = (ac - bd) + (ad + bc)i }
    opMul: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      EmitFBin('fmul            ', a, c_, ac);
      EmitFBin('fmul            ', b_, d_, bd);
      EmitFBin('fsub            ', ac, bd, re);
      EmitFBin('fmul            ', a, d_, ad);
      EmitFBin('fmul            ', b_, c_, bc);
      EmitFBin('fadd            ', ad, bc, im);
      MakeComplex(re, im, v)
    end;
    { (a + bi)/(c + di) = ((ac + bd) + (bc - ad)i) / (c*c + d*d). Division by a
      zero divisor is left to IEEE, exactly as real `/` is: this compiler does
      not trap that one either, so trapping here would be the odd one out. }
    opRealDiv: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      EmitFBin('fmul            ', c_, c_, cc);
      EmitFBin('fmul            ', d_, d_, dd);
      EmitFBin('fadd            ', cc, dd, den);
      MsgStart;
      MsgText('division by zero                        ');
      cmsg := MsgEnd;
      GuardRealNonZero(den, cmsg, e^.line, e^.col);
      EmitFBin('fmul            ', a, c_, ac);
      EmitFBin('fmul            ', b_, d_, bd);
      EmitFBin('fadd            ', ac, bd, er);
      EmitFBin('fdiv            ', er, den, re);
      EmitFBin('fmul            ', b_, c_, bc);
      EmitFBin('fmul            ', a, d_, ad);
      EmitFBin('fsub            ', bc, ad, ei);
      EmitFBin('fdiv            ', ei, den, im);
      MakeComplex(re, im, v)
    end;
    { Only = and <> reach here; Sema refused the four ordering operators,
      because 6.8.3.5 gives them "any simple-type except complex-type" and
      there is no order on the complex numbers to give them. }
    opEq, opNe, opLt, opLe, opGt, opGe, opIntDiv, opMod, opAnd, opOr,
    opAndThen, opOrElse, opSymDiff, opIn, opExp, opPow: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      Def(ac);
      write(ircode, 'fcmp oeq double ');
      PutOp(a);
      write(ircode, ', ');
      PutOp(c_);
      writeln(ircode);
      Def(bd);
      write(ircode, 'fcmp oeq double ');
      PutOp(b_);
      write(ircode, ', ');
      PutOp(d_);
      writeln(ircode);
      Def(re);
      write(ircode, 'and i1 ');
      PutOp(ac);
      write(ircode, ', ');
      PutOp(bd);
      writeln(ircode);
      if e^.bnOp = opEq then
        v := re
      else begin
        Def(v);
        write(ircode, 'xor i1 ');
        PutOp(re);
        writeln(ircode, ', true')
      end
    end
  end
end;

{ ISO/IEC 10206:1991 6.4.3.3: every string *value*, as the pointer and length
  pair 6.4.3.3.1 describes it -- "a one-to-one mapping from an index-domain to
  a set of components possessing the char-type", with the index-domain's size
  as the length.

  The pair is what makes `substr` and `trim` free: they are a pointer and a
  shorter length into the string they came from, and copy nothing. Only `+`
  makes characters that did not exist. }
{ The literal a name is bound to, or nil where the node is not a name bound to
  one.

  ADR-0220: the arm inside EmitString that answers for a literal is keyed on
  the node's *kind*, and a constant reaches CodeGen as a designator -- so `''`
  and `const e = ''` were two answers to one clause, the second reading a
  length out of characters that are not there. Both spellings of a
  constant-access are asked, a bare name and 6.11.3's qualified one, an
  imported null-string being the same value arriving by another route. }
function StringConstOf(e: nodePtr): nodePtr;
var s: symPtr;
begin
  s := nil;
  if e^.kind = nkVar then begin
    if (e^.vrField = nil) and (e^.vrCall = nil) then s := e^.vrSym
  end
  else if e^.kind = nkField then
    s := e^.fdQualified;
  StringConstOf := nil;
  if s <> nil then
    if s^.kind = skConst then
      if s^.constValue <> nil then
        if s^.constValue^.kind = nkStr then
          StringConstOf := s^.constValue
end;

procedure EmitString;
var ad, al, bd, bl, at_, count, hdr, addr, c, one: str; st: typePtr;
    part: array [0..2] of str; k, first: integer; lit: nodePtr;
begin
  { 6.4.2.5's states are one-to-one, so a restricted string *is* the string it
    restricts as far as its representation goes. Asked here rather than by
    changing the node's type, and asked at all only because IsStringType
    deliberately does not see through. }
  st := Underlying(e^.ntype);
  { A concatenation, and the one operation that needs storage. }
  { AP 6.4.15.7. Unlike 6.8.3.6's concatenation the length is not the sum of
    the two -- normal form can shorten a join, `e` and a combining acute
    becoming one composed character -- so the runtime returns a text *value*
    in the arena, a length word and the bytes, and this reads it with the same
    two getelementptrs a text variable is read with. }
  if (e^.kind = nkBinary) and (e^.bnOp = opAdd) and IsText(st) then begin
    EmitString(e^.bnLhs, ad, al);
    EmitString(e^.bnRhs, bd, bl);
    strTemps := strTemps + 1;   { ADR-0111: this statement must release }
    EmitAt(e^.line, e^.col);
    Def(addr);
    write(ircode, 'call ptr @pas_text_concat(ptr ');
    PutOp(ad);
    write(ircode, ', i32 ');
    PutOp(al);
    write(ircode, ', ptr ');
    PutOp(bd);
    write(ircode, ', i32 ');
    PutOp(bl);
    writeln(ircode, ')');
    EmitAtDone;
    Def(at_);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(canonTextType);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 0');
    Def(len);
    write(ircode, 'load i32, ptr ');
    PutOp(at_);
    writeln(ircode);
    Def(data);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(canonTextType);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 1')
  end
  else if (e^.kind = nkBinary) and (e^.bnOp = opAdd) and IsStringType(st) then
  begin
    EmitString(e^.bnLhs, ad, al);
    EmitString(e^.bnRhs, bd, bl);
    strTemps := strTemps + 1;   { ADR-0111: this statement must release }
    EmitAt(e^.line, e^.col);
    Def(data);
    write(ircode, 'call ptr @pas_str_concat(ptr ');
    PutOp(ad);
    write(ircode, ', i32 ');
    PutOp(al);
    write(ircode, ', ptr ');
    PutOp(bd);
    write(ircode, ', i32 ');
    PutOp(bl);
    writeln(ircode, ')');
    EmitAtDone;
    { 6.8.3.6: "whose length shall be equal to the sum of the length of a and
      the length of b" -- so the length is arithmetic here and the runtime
      never returns one. }
    Def(len);
    write(ircode, 'add i32 ');
    PutOp(al);
    write(ircode, ', ');
    PutOp(bl);
    writeln(ircode)
  end
  { 6.7.6.9's date(t) and time(t). Both are a value of the
    canonical-string-type, so both are a pointer and a length like every other
    string value -- and because the representation is fixed-width, the length
    is a *constant* and only the characters cost a call. That is the same
    division pas_str_concat makes, where 6.8.3.6 fixes the length and the
    runtime returns only the bytes.

    Three fields are loaded and passed as numbers, for the reason GetTimeStamp
    samples rather than being handed the record: nothing about how a TimeStamp
    is laid out crosses to the runtime, in either direction. All six of the
    fields either function reads are integers, so no conversion arises. }
  else if (e^.kind = nkCall) and IsTimeBuiltin(e^.clBuiltin) then begin
    strTemps := strTemps + 1;   { ADR-0111: pas_date and pas_time take arena }
    EmitAddress(e^.clArgs, hdr);
    if e^.clBuiltin = biDate then first := 2 else first := 5;
    for k := 0 to 2 do begin
      Def(addr);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clArgs^.ntype);
      write(ircode, ', ptr ');
      PutOp(hdr);
      writeln(ircode, ', i32 0, i32 ', first + k:1);
      Def(part[k]);
      write(ircode, 'load i32, ptr ');
      PutOp(addr);
      writeln(ircode)
    end;
    EmitAt(e^.line, e^.col);
    Def(data);
    if e^.clBuiltin = biDate then write(ircode, 'call ptr @pas_date(i32 ')
    else write(ircode, 'call ptr @pas_time(i32 ');
    PutOp(part[0]);
    write(ircode, ', i32 ');
    PutOp(part[1]);
    write(ircode, ', i32 ');
    PutOp(part[2]);
    writeln(ircode, ')');
    EmitAtDone;
    if e^.clBuiltin = biDate then OpInt(dateLen, len)
    else OpInt(timeLen, len)
  end
  { AP 6.7.6.10's argument(k): the characters are argv's own, which outlive
    every statement, so unlike date and trim nothing is taken from the arena.
    The runtime checks k against the count and reports the error; the length
    is a second call on a position the first has already admitted. }
  else if (e^.kind = nkCall) and (e^.clBuiltin = biArgument) then begin
    EmitExpr(e^.clArgs, hdr);
    EmitAt(e^.line, e^.col);
    Def(data);
    write(ircode, 'call ptr @pas_argument(i32 ');
    PutOp(hdr);
    writeln(ircode, ')');
    EmitAtDone;
    Def(len);
    write(ircode, 'call i32 @pas_argument_len(i32 ');
    PutOp(hdr);
    writeln(ircode, ')')
  end
  else if (e^.kind = nkCall) and
          ((e^.clBuiltin = biSubstr) or (e^.clBuiltin = biTrim)) then begin
    EmitString(e^.clArgs, ad, al);
    if e^.clBuiltin = biTrim then begin
      data := ad;
      Def(len);
      write(ircode, 'call i32 @pas_str_trimlen(ptr ');
      PutOp(ad);
      write(ircode, ', i32 ');
      PutOp(al);
      writeln(ircode, ')')
    end
    else begin
      { 6.7.6.7: substr(s, i, j) is j characters from position i, and the
        two-argument form is "substr(sv, iv, length(sv)-(iv)+1)" -- the tail. }
      EmitExpr(e^.clArgs^.next, at_);
      if e^.clArgs^.next^.next <> nil then
        EmitExpr(e^.clArgs^.next^.next, count)
      else begin
        Def(bd);
        write(ircode, 'sub i32 ');
        PutOp(al);
        write(ircode, ', ');
        PutOp(at_);
        writeln(ircode);
        Def(count);
        write(ircode, 'add i32 ');
        PutOp(bd);
        writeln(ircode, ', 1')
      end;
      EmitAt(e^.line, e^.col);
      write(ircode, '  call void @pas_str_slice_check(i32 ');
      PutOp(at_);
      write(ircode, ', i32 ');
      PutOp(count);
      write(ircode, ', i32 ');
      PutOp(al);
      writeln(ircode, ')');
      EmitAtDone;
      Def(bl);
      write(ircode, 'sub i32 ');
      PutOp(at_);
      writeln(ircode, ', 1');
      Def(data);
      write(ircode, 'getelementptr inbounds i8, ptr ');
      PutOp(ad);
      write(ircode, ', i32 ');
      PutOp(bl);
      writeln(ircode);
      len := count
    end
  end
  { 6.5.6 and 6.8.6.5: `s[i..j]` is j - i + 1 characters from position i. Under
    ADR-0051's representation that is a pointer and a length and nothing is
    copied, which is why a substring-*variable* and a substring of a value are
    the same three instructions -- the difference is only whether anything may
    be stored through the pointer, and that was decided in Sema. }
  else if e^.kind = nkSubstr then begin
    EmitString(e^.ssBase, ad, al);
    EmitExpr(e^.ssLo, bd);
    EmitExpr(e^.ssHi, bl);
    Def(count);
    write(ircode, 'sub i32 ');
    PutOp(bl);
    write(ircode, ', ');
    PutOp(bd);
    writeln(ircode);
    Def(at_);
    write(ircode, 'add i32 ');
    PutOp(count);
    writeln(ircode, ', 1');
    { Not pas_str_slice_check, whose message calls its subject a sequence of
      components. The fourth argument is AP 6.5.6 (ADR-0219): the empty
      substring `s[i..i-1]` is admissible, where both standards make it an
      error, and that is the one disjunct the two rules differ over -- so the
      check is one function and the disjunct is an argument to it. It was the
      *mode* that chose the argument until ADR-0232; there is one language now
      and the argument is the constant below, kept as an argument because the
      runtime routine is shared with the slice check, which does not admit it.

      6.7.6.7's `substr(s, i, 0)` already yields the null-string in Extended
      Pascal and ADR-0125's `a[i..i-1]` is already the empty slice, so this
      leaves `s[i..i-1]` as the only bracketed range in the dialect that could
      not be empty. lib/dialect/pasparse.pas is where that cost a defect. }
    EmitAt(e^.line, e^.col);
    write(ircode, '  call void @pas_str_substr_check(i32 ');
    PutOp(bd);
    write(ircode, ', i32 ');
    PutOp(bl);
    write(ircode, ', i32 ');
    PutOp(al);
    write(ircode, ', i32 1');
    writeln(ircode, ')');
    EmitAtDone;
    Def(one);
    write(ircode, 'sub i32 ');
    PutOp(bd);
    writeln(ircode, ', 1');
    Def(data);
    write(ircode, 'getelementptr inbounds i8, ptr ');
    PutOp(ad);
    write(ircode, ', i32 ');
    PutOp(one);
    writeln(ircode);
    len := at_
  end
  { A literal is its own characters and its own length, whatever type it was
    given -- and the null-string is *why* this comes first: `''` has the
    canonical type, which would otherwise be read as a length in front of
    characters that are not there. }
  else if e^.kind = nkStr then begin
    EmitAddress(e, data);
    OpInt(e^.stLen, len)
  end
  { 6.4.3.3.1 gives the char-type length 1, and a char in a register has no
    address -- this is where it gets one. }
  else if IsChar(st) then begin
    EmitExpr(e, c);
    strTemps := strTemps + 1;   { ADR-0111: a char given an address is arena }
    EmitAt(e^.line, e^.col);
    Def(data);
    write(ircode, 'call ptr @pas_str_char(i8 ');
    PutOp(c);
    writeln(ircode, ')');
    EmitAtDone;
    OpInt(1, len)
  end
  { ...and a *name* bound to a literal is that same value, which is where the
    guard above was one node kind too narrow (ADR-0220). It stands here rather
    than beside the literal so that its reach is exactly the arm it corrects:
    a constant of a nonzero literal possesses a fixed-string-type and falls to
    the last arm as it always has, so the only value this catches is the
    null-string -- the one string constant whose type is the canonical one,
    because 6.4.3.3.2 gives no fixed-string-type a capacity of zero. }
  else if StringConstOf(e) <> nil then begin
    lit := StringConstOf(e);
    EmitAddress(e, data);
    OpInt(lit^.stLen, len)
  end
  { A variable-string variable: the length is stored in front of the
    characters, which is the whole of 6.4.3.3.3's representation. }
  else if IsStringRep(st) then begin
    EmitAddress(e, addr);
    Def(at_);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(st);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 0');
    Def(len);
    write(ircode, 'load i32, ptr ');
    PutOp(at_);
    writeln(ircode);
    Def(data);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(st);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 1')
  end
  { ...and a fixed-string-type, whose length 6.4.3.3.2 makes equal to its
    capacity: "the length of all values of a particular fixed-string-type is
    equal to the capacity". }
  else begin
    EmitAddress(e, data);
    HeapHeader(e, hdr);
    DynLength(st, hdr, len)
  end
end;

{ 6.4.6's assignment rules for a string destination, which are three different
  things depending on what the destination is -- padded to the capacity for a
  fixed string, exact for a variable one, one character for a char -- and one
  thing they share: it is an *error* if the value is longer than the
  capacity. }
{ The same three rules, given the value as a pointer and a length rather than
  as an expression -- which is what 6.7.5.5's writestr has, since its value was
  produced by the runtime and no expression in the tree denotes it. }
procedure EmitStringStoreValue(protected var dst: str; t: typePtr; protected var sd, sl: str;
                               protected var hdr: str; line, col: integer);
var cap: str;
begin
  { AP 6.4.15.5: a text is the one target whose store is not a copy. The bytes
    are validated and normalised on the way in, which is where 6.4.15.2's
    invariant is established -- and it is established here and nowhere else,
    so everything downstream may assume it. The runtime normalises through the
    string arena, so this is an arena producer and the statement must release
    (ADR-0111); the caller bumps the counter. }
  if IsText(t) then begin
    StringCapacity(t, hdr, cap);
    strTemps := strTemps + 1;
    EmitAt(line, col);
    write(ircode, '  call void @pas_text_store(ptr ');
    PutOp(dst);
    write(ircode, ', i32 ');
    PutOp(cap);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')');
    EmitAtDone
  end
  else if IsStringRep(t) then begin
    StringCapacity(t, hdr, cap);
    EmitAt(line, col);
    write(ircode, '  call void @pas_str_store_var(ptr ');
    PutOp(dst);
    write(ircode, ', i32 ');
    PutOp(cap);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')');
    EmitAtDone
  end
  else if IsChar(t) then begin
    EmitAt(line, col);
    write(ircode, '  call void @pas_str_store_char(ptr ');
    PutOp(dst);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')');
    EmitAtDone
  end
  else begin
    DynLength(t, hdr, cap);
    EmitAt(line, col);
    write(ircode, '  call void @pas_str_store_fixed(ptr ');
    PutOp(dst);
    write(ircode, ', i32 ');
    PutOp(cap);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')');
    EmitAtDone
  end
end;

procedure EmitStringStore(protected var dst: str; t: typePtr; src: nodePtr;
                          protected var hdr: str);
var sd, sl: str;
begin
  EmitString(src, sd, sl);
  EmitStringStoreValue(dst, t, sd, sl, hdr, src^.line, src^.col)
end;

{ 6.8.3.5: the relational operators over string types, where the shorter value
  is "effectively extended with trailing spaces to the length of the longer".
  That is the ISO 7185 divergence that matters -- there the lengths had to be
  equal, and this compiler said so. }
{ A concatenation appearing where a *value* is wanted rather than where a
  string is: only a string context can consume one, so the pair is built and
  the pointer stands for it. Sema has already refused every other use.

  Which is why no program enters this, and why the entry in
  tests/checks/uncovered_procedures.txt says its argument is empirical: every
  context that admits a string-valued expression routes it through EmitString
  before EmitExpr, and eighteen were compiled to check. A nineteenth would
  retire the entry -- and want a case, not an edit. }
procedure EmitStringValue(e: nodePtr; var v: str);
var d, l: str;
begin
  EmitString(e, d, l);
  v := d
end;

{ AP 6.4.15.6's comparison: the byte sequences, lexicographically. Both
  operands being in Normalization Form C, that *is* canonical equivalence --
  which is the whole benefit of normalising where a value is constructed rather
  than where two are compared (ADR-0189).

  An operand that is not a text has not been through that door, so the runtime
  normalises it first and this becomes an arena producer. Sema has already
  refused the one case where that would be wrong rather than slow: a *string*
  against a text, where normalising silently would answer a question the
  program did not ask. }
procedure EmitTextCompare(e: nodePtr; var v: str);
var ad, al, bd, bl, cmp: str;
begin
  EmitString(e^.bnLhs, ad, al);
  EmitString(e^.bnRhs, bd, bl);
  if not IsText(e^.bnLhs^.ntype) or not IsText(e^.bnRhs^.ntype) then
    strTemps := strTemps + 1;   { ADR-0111: the normalised copy is arena }
  EmitAt(e^.line, e^.col);
  Def(cmp);
  write(ircode, 'call i32 @pas_text_cmp(ptr ');
  PutOp(ad);
  write(ircode, ', i32 ');
  PutOp(al);
  write(ircode, ', ptr ');
  PutOp(bd);
  write(ircode, ', i32 ');
  PutOp(bl);
  { The left operand is always the text -- Sema admits no pair without one --
    so only the right may need normalising, and this flag is which. }
  if IsText(e^.bnRhs^.ntype) then writeln(ircode, ', i32 0)')
  else writeln(ircode, ', i32 1)');
  EmitAtDone;
  Def(v);
  write(ircode, 'icmp ');
  case e^.bnOp of
    opEq: write(ircode, 'eq');
    opNe: write(ircode, 'ne');
    opLt: write(ircode, 'slt');
    opLe: write(ircode, 'sle');
    opGt: write(ircode, 'sgt');
    opGe: write(ircode, 'sge');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr, opAndThen,
    opOrElse, opSymDiff, opIn, opExp, opPow: write(ircode, 'eq')
  end;
  write(ircode, ' i32 ');
  PutOp(cmp);
  writeln(ircode, ', 0')
end;

procedure EmitStringCompare2(e: nodePtr; var v: str);
var ad, al, bd, bl, cmp: str;
begin
  EmitString(e^.bnLhs, ad, al);
  EmitString(e^.bnRhs, bd, bl);
  Def(cmp);
  write(ircode, 'call i32 @pas_str_cmp_pad(ptr ');
  PutOp(ad);
  write(ircode, ', i32 ');
  PutOp(al);
  write(ircode, ', ptr ');
  PutOp(bd);
  write(ircode, ', i32 ');
  PutOp(bl);
  writeln(ircode, ')');
  Def(v);
  write(ircode, 'icmp ');
  case e^.bnOp of
    opEq: write(ircode, 'eq');
    opNe: write(ircode, 'ne');
    opLt: write(ircode, 'slt');
    opLe: write(ircode, 'sle');
    opGt: write(ircode, 'sgt');
    opGe: write(ircode, 'sge');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr, opAndThen,
    opOrElse, opSymDiff, opIn, opExp, opPow: write(ircode, 'eq')
  end;
  write(ircode, ' i32 ');
  PutOp(cmp);
  writeln(ircode, ', 0')
end;

{ ADR-0123: `o = nil` and `o <> nil`, the presence test. Sema has required
  that one side be nil and the other an optional, so the only question left is
  which side is which -- and nothing is loaded but the flag, which is what
  makes this the one thing a program may ask without unwrapping. }
procedure EmitOptionalTest(e: nodePtr; var v: str);
var opnd: nodePtr; base, flag, has: str; t: typePtr;
begin
  if IsOptional(e^.bnLhs^.ntype) then opnd := e^.bnLhs else opnd := e^.bnRhs;
  t := Underlying(opnd^.ntype);
  EmitAddress(opnd, base);
  OptionalPart(base, t, 0, flag);
  Def(has);
  write(ircode, 'load i32, ptr ');
  PutOp(flag);
  writeln(ircode);
  Def(v);
  { `= nil` is *absent*, so the sense is inverted against the flag. }
  if e^.bnOp = opEq then write(ircode, 'icmp eq i32 ')
  else write(ircode, 'icmp ne i32 ');
  PutOp(has);
  writeln(ircode, ', 0')
end;

{ AP 6.4.12.2's `h = nil`: the slot's first word is the value and NULL is
  empty. Taken before the operands are evaluated, a handle having no register
  form. }
procedure EmitHandleTest(e: nodePtr; var v: str);
var opnd: nodePtr; base, word: str;
begin
  if IsHandle(e^.bnLhs^.ntype) then opnd := e^.bnLhs else opnd := e^.bnRhs;
  EmitAddress(opnd, base);
  Def(word);
  write(ircode, 'load ptr, ptr ');
  PutOp(base);
  writeln(ircode);
  Def(v);
  if e^.bnOp = opEq then write(ircode, 'icmp eq ptr ')
  else write(ircode, 'icmp ne ptr ');
  PutOp(word);
  writeln(ircode, ', null')
end;

procedure EmitBinary(e: nodePtr; var v: str);
var l, r, rem, neg, adj, bad, m1, m2: str;
    lt, rt: typePtr; msg: integer; sign, useFloat, wide: boolean;
begin
  if (e^.bnOp = opAnd) or (e^.bnOp = opOr) or (e^.bnOp = opAndThen)
     or (e^.bnOp = opOrElse) then
    EmitShortCircuit(e, v)
  { `x in s` is the one operator whose operands are of different kinds, so it
    is taken before the two are evaluated alike. }
  else if e^.bnOp = opIn then
    EmitIn(e, v)
  { ADR-0123's presence test, taken before the operands are evaluated: an
    optional has no register form, so EmitExpr below would have nothing to
    hand back. }
  else if IsHandle(e^.bnLhs^.ntype) or IsHandle(e^.bnRhs^.ntype) then
    EmitHandleTest(e, v)
  else if IsOptional(Underlying(e^.bnLhs^.ntype)) or
          IsOptional(Underlying(e^.bnRhs^.ntype)) then
    EmitOptionalTest(e, v)
  { 6.8.3.6's concatenation, which is a value and not a comparison. }
  else if (e^.bnOp = opAdd) and (IsStringType(e^.ntype) or IsText(e^.ntype)) then
    EmitStringValue(e, v)
  { 6.8.3.5's padded comparison, whenever either side is a string and the
    lengths are not both statically equal char arrays -- the ISO 7185 path is
    kept for the case it already handled, so nothing about that language's
    emitted code moved. }
  { AP 6.4.15.6, before the string arm for the same reason Sema's is: 6.8.3.5's
    padded comparison extends the shorter operand with spaces, and a text has
    no character for that to be about. }
  else if IsText(e^.bnLhs^.ntype) or IsText(e^.bnRhs^.ntype) then
    EmitTextCompare(e, v)
  else if IsStringOrChar(e^.bnLhs^.ntype) and IsStringOrChar(e^.bnRhs^.ntype)
          and not (IsChar(e^.bnLhs^.ntype) and IsChar(e^.bnRhs^.ntype)) then
    if IsCharArray(e^.bnLhs^.ntype) and IsCharArray(e^.bnRhs^.ntype) and
       (e^.bnLhs^.ntype^.loDisc = nil) and (e^.bnLhs^.ntype^.hiDisc = nil) and
       (e^.bnRhs^.ntype^.loDisc = nil) and (e^.bnRhs^.ntype^.hiDisc = nil) and
       (TypeLength(e^.bnLhs^.ntype) = TypeLength(e^.bnRhs^.ntype)) then
      EmitStringCompare(e, v)
    else
      EmitStringCompare2(e, v)
  { Strings compare through the runtime rather than in registers, and must be
    caught before the operands are evaluated: an array has no register form. }
  else if IsCharArray(e^.bnLhs^.ntype) and IsCharArray(e^.bnRhs^.ntype) then
    EmitStringCompare(e, v)
  else begin
    EmitExpr(e^.bnLhs, l);
    EmitExpr(e^.bnRhs, r);
    lt := e^.bnLhs^.ntype;
    rt := e^.bnRhs^.ntype;

    { Both operands are the same 256-bit word whatever their base types, so the
      set operators need nothing from the types beyond knowing they are sets. }
    if IsSet(lt) or IsSet(rt) then
      EmitSetBinary(e, l, r, v)
    { 6.8.3.2 table 3 and 6.8.3.5 table 6. A complex operand decides the whole
      operation, so this is taken before the real/integer split rather than
      inside it: `1 + z` is complex addition with the 1 widened, not integer
      addition with something odd afterwards. The two exponentiating operators
      are excluded because their *right* operand is never complex. }
    else if IsComplex(e^.ntype) and (e^.bnOp = opExp) then
      EmitComplexPow(e, l, r, lt, rt, true, v)
    else if IsComplex(e^.ntype) and (e^.bnOp = opPow) then
      EmitComplexPow(e, l, r, lt, rt, false, v)
    else if IsComplex(lt) or IsComplex(rt) then begin
      ToComplex(l, lt);
      ToComplex(r, rt);
      EmitComplexBinary(e, l, r, v)
    end
    else begin
    { ADR-0128: an int64 anywhere makes the whole operation one width wider,
      and the narrower operand is sign-extended before anything else looks at
      it -- the same shape ToReal has always had, and it has to be done for a
      *comparison* too, where the result type is boolean and says nothing about
      the operands. }
    wide := IsInt64(lt) or IsInt64(rt);
    if wide and not IsReal(e^.ntype) and not IsComplex(e^.ntype) then begin
      ToInt64(l, lt);
      ToInt64(r, rt)
    end;

    case e^.bnOp of
      opAdd, opSub, opMul:
        if IsReal(e^.ntype) then begin
          ToReal(l, lt);
          ToReal(r, rt);
          Def(v);
          if e^.bnOp = opAdd then write(ircode, 'fadd double ')
          else if e^.bnOp = opSub then write(ircode, 'fsub double ')
          else write(ircode, 'fmul double ');
          PutOp(l);
          write(ircode, ', ');
          PutOp(r);
          writeln(ircode)
        end
        else begin
          MsgStart;
          MsgText('integer overflow in                     ');
          Put(' ');
          if e^.bnOp = opAdd then Put('+')
          else if e^.bnOp = opSub then Put('-')
          else Put('*');
          msg := MsgEnd;
          if e^.bnOp = opAdd then
            EmitCheckedArith('+', l, r, v, msg, wide, e^.line, e^.col)
          else if e^.bnOp = opSub then
            EmitCheckedArith('-', l, r, v, msg, wide, e^.line, e^.col)
          else EmitCheckedArith('*', l, r, v, msg, wide, e^.line, e^.col)
        end;

      opRealDiv: begin
        ToReal(l, lt);
        ToReal(r, rt);
        MsgStart;
        MsgText('division by zero                        ');
        msg := MsgEnd;
        GuardRealNonZero(r, msg, e^.line, e^.col);
        Def(v);
        write(ircode, 'fdiv double ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end;

      { Exponentiation is the one arithmetic operator with no instruction
        behind it, so all three forms are runtime calls -- and the error
        conditions of 6.8.3.2 go with them rather than being emitted as tests
        around the call. Integer `pow` is where the trap matters most: it is
        repeated multiplication, and each step is checked exactly as `*` is. }
      opExp: begin
        ToReal(l, lt);
        ToReal(r, rt);
        EmitAt(e^.line, e^.col);
        Def(v);
        write(ircode, 'call double @pas_pow_real(double ');
        PutOp(l);
        write(ircode, ', double ');
        PutOp(r);
        writeln(ircode, ')');
        EmitAtDone
      end;

      opPow:
        if IsReal(e^.ntype) then begin
          ToReal(l, lt);
          EmitAt(e^.line, e^.col);
          Def(v);
          write(ircode, 'call double @pas_pow_realint(double ');
          PutOp(l);
          write(ircode, ', i32 ');
          PutOp(r);
          writeln(ircode, ')');
          EmitAtDone
        end
        else begin
          EmitAt(e^.line, e^.col);
          Def(v);
          write(ircode, 'call i32 @pas_pow_int(i32 ');
          PutOp(l);
          write(ircode, ', i32 ');
          PutOp(r);
          writeln(ircode, ')');
          EmitAtDone
        end;

      opIntDiv: begin
        MsgStart;
        MsgText('division by zero                        ');
        msg := MsgEnd;
        GuardNonZero(r, msg, wide, e^.line, e^.col);
        { maxint div -1 is representable, but INT_MIN div -1 is not; LLVM calls
          it undefined rather than wrapping, so it is excluded explicitly. The
          same sentence one width up for ADR-0128's int64. }
        Def(m1);
        write(ircode, 'icmp eq ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(l);
        write(ircode, ', ');
        PutIntMin(wide);
        writeln(ircode);
        Def(m2);
        write(ircode, 'icmp eq ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(r);
        writeln(ircode, ', -1');
        Def(bad);
        write(ircode, 'and i1 ');
        PutOp(m1);
        write(ircode, ', ');
        PutOp(m2);
        writeln(ircode);
        MsgStart;
        MsgText('integer overflow in div                 ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg, e^.line, e^.col);
        Def(v);
        write(ircode, 'sdiv ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end;

      opMod: begin
        MsgStart;
        MsgText('the right operand of mod must be        ');
        Put(' ');
        MsgText('positive                                ');
        msg := MsgEnd;
        GuardPositive(r, msg, wide, e^.line, e^.col);
        { ISO 7185 defines i mod j (for j > 0) as a non-negative result, unlike
          the truncating remainder LLVM gives. }
        Def(rem);
        write(ircode, 'srem ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode);
        Def(neg);
        write(ircode, 'icmp slt ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(rem);
        writeln(ircode, ', 0');
        Def(adj);
        write(ircode, 'add ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(rem);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode);
        Def(v);
        write(ircode, 'select i1 ');
        PutOp(neg);
        write(ircode, ', ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(adj);
        write(ircode, ', ');
        PutIntWidth(wide);
        write(ircode, ' ');
        PutOp(rem);
        writeln(ircode)
      end;

      opEq, opNe, opLt, opLe, opGt, opGe: begin
        useFloat := IsReal(lt) or IsReal(rt);
        if useFloat then begin
          ToReal(l, lt);
          ToReal(r, rt);
          Def(v);
          case e^.bnOp of
            opEq: write(ircode, 'fcmp oeq double ');
            opNe: write(ircode, 'fcmp one double ');
            opLt: write(ircode, 'fcmp olt double ');
            opLe: write(ircode, 'fcmp ole double ');
            opGt: write(ircode, 'fcmp ogt double ');
            opGe: write(ircode, 'fcmp oge double ');
            opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse, opSymDiff:
              write(ircode, 'fcmp oeq double ')
          end
        end
        else begin
          { char, boolean and enumerations compare as unsigned ordinals;
            integer, the only one with negative values, as signed. Pointers
            compare only for equality, which needs no predicate choice. }
          sign := IsInteger(lt) or IsInt64(lt) or IsInt64(rt);
          Def(v);
          case e^.bnOp of
            opEq: write(ircode, 'icmp eq ');
            opNe: write(ircode, 'icmp ne ');
            opLt: if sign then write(ircode, 'icmp slt ')
                  else write(ircode, 'icmp ult ');
            opLe: if sign then write(ircode, 'icmp sle ')
                  else write(ircode, 'icmp ule ');
            opGt: if sign then write(ircode, 'icmp sgt ')
                  else write(ircode, 'icmp ugt ');
            opGe: if sign then write(ircode, 'icmp sge ')
                  else write(ircode, 'icmp uge ');
            opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse, opSymDiff:
              write(ircode, 'icmp eq ')
          end;
          if IsPointer(lt) and IsPointer(rt) then write(ircode, 'ptr')
          { Both operands were widened above, so the wider type is what they
            are now -- asking the right one would answer i32 for `n < 1`
            (ADR-0128). }
          else if wide then write(ircode, 'i64')
          else if IsPointer(lt) then PutLlType(lt)
          else PutLlType(rt);
          write(ircode, ' ')
        end;
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end
    end
    end
  end
end;

procedure EmitUnary(e: nodePtr; var v: str);
var a: str;
begin
  EmitExpr(e^.unArg, a);
  case e^.unOp of
    opPos: begin
      ConvertFor(a, e^.unArg^.ntype, e^.ntype);
      v := a
    end;
    { Negation is unchecked, and verify/ carries the theorem saying it cannot
      overflow: -maxint..maxint is symmetric. }
    opNeg:
      if IsReal(e^.ntype) then begin
        ToReal(a, e^.unArg^.ntype);
        Def(v);
        write(ircode, 'fneg double ');
        PutOp(a);
        writeln(ircode)
      end
      else begin
        ConvertFor(a, e^.unArg^.ntype, e^.ntype);
        Def(v);
        write(ircode, 'sub nsw ');
        PutIntWidth(IsInt64(e^.ntype));
        write(ircode, ' 0, ');
        PutOp(a);
        writeln(ircode)
      end;
    opNot: begin
      Def(v);
      write(ircode, 'xor i1 ');
      PutOp(a);
      writeln(ircode, ', true')
    end
  end
end;

{ 6.7.6.2's transcendentals over a complex operand. Each is two calls, one per
  part, because a `double complex` crossing the C boundary would put an ABI
  question into an interface whose whole point is not to have one -- the same
  reason ADR-0030's procedural pair travels as two arguments. The runtime
  computes both parts from the same C99 call, so the pair cannot disagree about
  anything but rounding, which is exact for both halves. }
procedure ComplexCall(stem: msgLit; a: str; var v: str);
var re, im, pr, pi_: str;
begin
  ReOf(a, re);
  ImOf(a, im);
  Def(pr);
  write(ircode, 'call double @');
  PutIrLit(stem);
  write(ircode, '_re(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ')');
  Def(pi_);
  write(ircode, 'call double @');
  PutIrLit(stem);
  write(ircode, '_im(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ')');
  MakeComplex(pr, pi_, v)
end;

{ The branch that leaves this activation, which two constructs write and
  neither of them terminates a block with anything else: AP 6.7.5.9's exit and
  AP 6.8.9's try. The label is the block the epilogue starts with, claimed on
  first use and written by EmitExitTarget after the body -- a forward
  reference, which is what textual IR admits and an instruction list would not
  (ADR-0025). The caller opens whatever block comes next, because the two want
  different ones: an exit-statement wants a fresh unreachable one for the
  statements after it, and a try wants the block its value is read in. }
procedure EmitLeaveBlock;
begin
  if irProc^.exitBlock = 0 then irProc^.exitBlock := NewBlock;
  writeln(ircode, '  br label %L', irProc^.exitBlock:1)
end;

{ AP 6.8.9's try (ADR-0178), which is the husk CheckTry left, emitted in the
  order the clause states it: bind the operand, test its tag, leave with the
  cause where it is false, and yield the value where it is true.

  The binding is EmitWith's, line for line and for the same reason -- the
  operand is read three times and evaluating a function-designator three times
  would be three calls. Everything after it is an ordinary designator over an
  ordinary record, so a value-type that is a string, an array or a record
  needs nothing here: EmitAddress answers for this node, and the field read it
  ends in is the address such a value already travels as.

  The two field reads carry ADR-0118's tag check, and in correct code neither
  can fire -- each is emitted on the branch its own arm is active on. Left in
  rather than suppressed, for a reason a mutation then confirmed: making the
  cause fall through to the continuation instead of leaving stops the program
  at that check, where the golden would otherwise have had to notice a wrong
  answer. A redundant check costs an -O2 build nothing, and suppressing it
  would have put a second opinion about the tag beside the branch itself. }
procedure EmitTry(e: nodePtr; var v: str);
var a, slot, tag: str; failB, contB: integer;
begin
  EmitAddress(e^.clArgs, a);
  FrameSlot(e^.clSlot, slot);
  write(ircode, '  store ptr ');
  PutOp(a);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  EmitExpr(e^.clOk, tag);
  failB := NewBlock;
  contB := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(tag);
  writeln(ircode, ', label %L', contB:1, ', label %L', failB:1);
  StartBlock(failB);
  EmitAssign(e^.clFail);
  EmitLeaveBlock;
  StartBlock(contB);
  EmitExpr(e^.clVal, v)
end;

procedure EmitCall(e: nodePtr; var v: str);
var a, w, lim, tmp, b_, re, im, x, y, c_, d_, k_, sum: str;
    sqinf, mag, sqfin, sqbad, narrow: str;
    at, idx: typePtr; msg, up: integer; isSucc: boolean;
begin
  if e^.clSym <> nil then
    EmitUserCall(e^.clSym, e^.clArgs, e^.clSlot, v, e^.line, e^.col)
  { AP 6.8.9's try, taken here so that none of the instruction-shaped arms
    below can see it -- which is also why biTry is left out of their
    exhaustive lists (tests/checks/partial_cases.txt). }
  else if e^.clBuiltin = biTry then
    EmitTry(e, v)
  { 6.7.6.8's binding(f): the result is a record, so it is built in the hidden
    frame slot Sema gave this call site and the call becomes that slot's
    address. Everything after -- a field selection, a whole-record assignment,
    a value parameter -- is then the ordinary designator it looks like. }
  else if e^.clBuiltin = biBinding then begin
    if e^.clSlot = nil then
      OpInt(0, v)
    else begin
      EmitAddress(e^.clArgs, a);
      AddressOfSym(e^.clSlot, v);
      Def(x);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clSlot^.stype);
      write(ircode, ', ptr ');
      PutOp(v);
      writeln(ircode, ', i32 0, i32 0');
      Def(y);
      write(ircode, 'call ptr @pas_binding_name(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(c_);
      write(ircode, 'call i32 @pas_binding_namelen(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      EmitAt(e^.line, e^.col);
      write(ircode, '  call void @pas_str_store_var(ptr ');
      PutOp(x);
      write(ircode, ', i32 ', bindNameCap:1, ', ptr ');
      PutOp(y);
      write(ircode, ', i32 ');
      PutOp(c_);
      writeln(ircode, ')');
      EmitAtDone;
      Def(d_);
      write(ircode, 'call i32 @pas_binding_bound(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(w);
      write(ircode, 'trunc i32 ');
      PutOp(d_);
      writeln(ircode, ' to i1');
      Def(x);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clSlot^.stype);
      write(ircode, ', ptr ');
      PutOp(v);
      writeln(ircode, ', i32 0, i32 1');
      write(ircode, '  store i1 ');
      PutOp(w);
      write(ircode, ', ptr ');
      PutOp(x);
      writeln(ircode);
      { AP 6.4.3.4's `writable` (ADR-0240), field 2. Asked on every `binding`
        rather than on demand, because 6.7.6.8 makes the call yield a whole
        record and there is no half of one to yield -- which is the same
        reason `name` is copied for a caller that only wants `bound`. }
      Def(d_);
      write(ircode, 'call i32 @pas_binding_writable(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(w);
      write(ircode, 'trunc i32 ');
      PutOp(d_);
      writeln(ircode, ' to i1');
      Def(x);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clSlot^.stype);
      write(ircode, ', ptr ');
      PutOp(v);
      writeln(ircode, ', i32 0, i32 2');
      write(ircode, '  store i1 ');
      PutOp(w);
      write(ircode, ', ptr ');
      PutOp(x);
      writeln(ircode)
    end
  end
  { 6.7.6.7's string functions. `substr` and `trim` are string *values* and are
    emitted by EmitString; the rest answer about one, so they take the pair
    apart here. }
  else if e^.clBuiltin = biLength then begin
    { ADR-0125: a slice answers the same question through the same pair. }
    if IsSlice(e^.clArgs^.ntype) then EmitSliceValue(e^.clArgs, x, v)
    { AP 6.4.15.8: over a text the answer is the number of *elements*, which
      the pair does not carry -- the length beside the bytes is a count of
      bytes, and this is the one place the two units part company. So it is a
      call, and by that clause's NOTE it is not a constant-time one. }
    else if IsText(e^.clArgs^.ntype) then begin
      EmitString(e^.clArgs, x, y);
      Def(v);
      write(ircode, 'call i32 @pas_text_length(ptr ');
      PutOp(x);
      write(ircode, ', i32 ');
      PutOp(y);
      writeln(ircode, ')')
    end
    else EmitString(e^.clArgs, x, v)
  end
  else if e^.clBuiltin = biIndex then begin
    EmitString(e^.clArgs, x, y);
    EmitString(e^.clArgs^.next, c_, d_);
    Def(v);
    write(ircode, 'call i32 @pas_str_index(ptr ');
    PutOp(x);
    write(ircode, ', i32 ');
    PutOp(y);
    write(ircode, ', ptr ');
    PutOp(c_);
    write(ircode, ', i32 ');
    PutOp(d_);
    writeln(ircode, ')')
  end
  { AP 6.7.6.10 (ADR-0173). argcount is one call; argument's value is a
    string and comes through EmitString like trim's. }
  else if e^.clBuiltin = biArgCount then begin
    Def(v);
    writeln(ircode, 'call i32 @pas_argcount()')
  end
  { AP 6.4.12.5 (ADR-0206): the release with an answer. The slot's address,
    exactly as `pas_handle_set` takes it -- the runtime owns the emptying,
    because it is the same three lines every other release already runs and a
    second copy of them here would be a copy free to drift. }
  else if e^.clBuiltin = biRelease then begin
    EmitAddress(e^.clArgs, x);
    { AP 6.4.16.4: a channel is closed by the release the program wrote,
      whichever variable holds it (ADR-0302). }
    if IsChannel(e^.clArgs^.ntype) then EmitChanShut(x);
    Def(v);
    write(ircode, 'call i32 @pas_handle_release_result(ptr ');
    PutOp(x);
    writeln(ircode, ')')
  end
  { AP 6.9.3.13's receive. The channel's own word out of the slot, and the
    address of the variable the value is written into -- the runtime copies
    `esize` bytes into it, which is what makes the reader's value share
    nothing with the sender's. Answers 1 with a value and 0 when the channel
    is closed and drained, which is the loop condition and the whole reason
    this is a function where `send` is a procedure. }
  else if e^.clBuiltin = biReceive then begin
    EmitAddress(e^.clArgs, x);
    EmitAt(e^.line, e^.col);
    Def(y);
    write(ircode, 'call ptr @pas_handle_lend(ptr ');
    PutOp(x);
    writeln(ircode, ')');
    EmitAtDone;
    EmitAddress(e^.clArgs^.next, c_);
    EmitAt(e^.line, e^.col);
    Def(w);
    write(ircode, 'call i32 @pas_chan_receive(ptr ');
    PutOp(y);
    write(ircode, ', ptr ');
    PutOp(c_);
    writeln(ircode, ')');
    EmitAtDone;
    Def(v);
    write(ircode, 'icmp ne i32 ');
    PutOp(w);
    writeln(ircode, ', 0')
  end
  else if (e^.clBuiltin = biSubstr) or (e^.clBuiltin = biTrim) or
          (e^.clBuiltin = biArgument) then
    EmitStringValue(e, v)
  else if (e^.clBuiltin = biStrEq) or (e^.clBuiltin = biStrNe) or
          (e^.clBuiltin = biStrLt) or (e^.clBuiltin = biStrGt) or
          (e^.clBuiltin = biStrLe) or (e^.clBuiltin = biStrGe) then begin
    EmitString(e^.clArgs, x, y);
    EmitString(e^.clArgs^.next, c_, d_);
    { 6.7.6.7's NOTE 3: these are *not* the operators -- they compare lengths
      as well as characters, so a proper prefix is strictly less than its
      extension where `<` would pad and call them equal. }
    Def(w);
    write(ircode, 'call i32 @pas_str_cmp_exact(ptr ');
    PutOp(x);
    write(ircode, ', i32 ');
    PutOp(y);
    write(ircode, ', ptr ');
    PutOp(c_);
    write(ircode, ', i32 ');
    PutOp(d_);
    writeln(ircode, ')');
    Def(v);
    write(ircode, 'icmp ');
    case e^.clBuiltin of
      biStrEq: write(ircode, 'eq');
      biStrNe: write(ircode, 'ne');
      biStrLt: write(ircode, 'slt');
      biStrGt: write(ircode, 'sgt');
      biStrLe: write(ircode, 'sle');
      biStrGe: write(ircode, 'sge');
      biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred, biSqrt,
      biSin, biCos, biLn, biExp, biArcTan, biTrunc, biRound, biEof, biEoln,
      biCmplx, biPolar, biRe, biIm, biArg, biPosition, biLastPosition,
      biEmpty, biCard, biLength, biIndex, biSubstr, biTrim, biArgCount,
      biArgument:
        write(ircode, 'eq')
    end;
    write(ircode, ' i32 ');
    PutOp(w);
    writeln(ircode, ', 0')
  end
  { 6.7.6.5's `empty` and 6.7.6.6's two positions. The runtime counts from
    zero, so a position comes back relative to the index-type's smallest value
    and the lower bound is added here -- the same fold an array subscript makes
    in the other direction. }
  else if (e^.clBuiltin = biEmpty) or (e^.clBuiltin = biPosition) or
          (e^.clBuiltin = biLastPosition) then begin
    if e^.clArgs = nil then
      OpInt(0, v)
    else begin
      EmitAddress(e^.clArgs, a);
      EmitAt(e^.line, e^.col);
      Def(w);
      if e^.clBuiltin = biEmpty then write(ircode, 'call i32 @pas_empty(ptr ')
      else if e^.clBuiltin = biPosition then
        write(ircode, 'call i32 @pas_position(ptr ')
      else write(ircode, 'call i32 @pas_lastposition(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      EmitAtDone;
      if e^.clBuiltin = biEmpty then begin
        Def(v);
        write(ircode, 'trunc i32 ');
        PutOp(w);
        writeln(ircode, ' to i1')
      end
      else begin
        idx := e^.clArgs^.ntype^.indexType;
        if OrdinalLo(idx) <> 0 then begin
          Def(lim);
          write(ircode, 'add i32 ');
          PutOp(w);
          writeln(ircode, ', ', OrdinalLo(idx):1);
          w := lim
        end;
        { the result possesses the index type, which may be narrower than i32 }
        if IsChar(idx) or IsBoolean(idx) then begin
          Def(v);
          write(ircode, 'trunc i32 ');
          PutOp(w);
          write(ircode, ' to ');
          PutLlType(idx);
          writeln(ircode)
        end
        else
          v := w
      end
    end
  end
  { The file enquiries take the file's address, not its value, and Sema has
    already supplied `input` where the program left the argument out. }
  else if (e^.clBuiltin = biEof) or (e^.clBuiltin = biEoln) then begin
    if e^.clArgs = nil then
      OpWord('false           ', v)   { the parameter was missing: reported }
    else begin
      EmitAddress(e^.clArgs, a);
      EmitAt(e^.line, e^.col);
      Def(w);
      if e^.clBuiltin = biEof then write(ircode, 'call i32 @pas_eof(ptr ')
      else write(ircode, 'call i32 @pas_eoln(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      EmitAtDone;
      Def(v);
      write(ircode, 'trunc i32 ');
      PutOp(w);
      writeln(ircode, ' to i1')
    end
  end
  { 6.7.6.3: the two-argument constructors, and the only way to write a complex
    value -- the standard gives the type no literal. `polar` is
    `r*cos t + r*sin t * i`, computed here rather than in the runtime for the
    same reason the operators are. }
  else if (e^.clBuiltin = biCmplx) or (e^.clBuiltin = biPolar) then begin
    EmitExpr(e^.clArgs, x);
    ToReal(x, e^.clArgs^.ntype);
    EmitExpr(e^.clArgs^.next, y);
    ToReal(y, e^.clArgs^.next^.ntype);
    if e^.clBuiltin = biCmplx then
      MakeComplex(x, y, v)
    else begin
      Def(c_);
      write(ircode, 'call double @llvm.cos.f64(double ');
      PutOp(y);
      writeln(ircode, ')');
      Def(d_);
      write(ircode, 'call double @llvm.sin.f64(double ');
      PutOp(y);
      writeln(ircode, ')');
      Def(re);
      write(ircode, 'fmul double ');
      PutOp(x);
      write(ircode, ', ');
      PutOp(c_);
      writeln(ircode);
      Def(im);
      write(ircode, 'fmul double ');
      PutOp(x);
      write(ircode, ', ');
      PutOp(d_);
      writeln(ircode);
      MakeComplex(re, im, v)
    end
  end
  else begin
    EmitExpr(e^.clArgs, a);
    at := e^.clArgs^.ntype;
    { The three accessors are the representation itself, so they are not
      calls. }
    if IsComplex(at) then
      case e^.clBuiltin of
        biRe: ReOf(a, v);
        biIm: ImOf(a, v);
        { 6.7.6.2's `abs` of a complex is its magnitude and `arg` its argument,
          and both yield a *real* -- the two places the table's result kind
          does not follow its operand. }
        biAbs: begin
          ReOf(a, re);
          ImOf(a, im);
          Def(v);
          write(ircode, 'call double @pas_hypot(double ');
          PutOp(re);
          write(ircode, ', double ');
          PutOp(im);
          writeln(ircode, ')')
        end;
        biArg: begin
          ReOf(a, re);
          ImOf(a, im);
          Def(v);
          write(ircode, 'call double @pas_atan2(double ');
          PutOp(im);
          write(ircode, ', double ');
          PutOp(re);
          writeln(ircode, ')')
        end;
        { sqr keeps its operand's type, so this is the multiplication with
          both operands the same value. }
        biSqr: begin
          ReOf(a, x);
          ImOf(a, y);
          Def(c_);
          write(ircode, 'fmul double ');
          PutOp(x);
          write(ircode, ', ');
          PutOp(x);
          writeln(ircode);
          Def(d_);
          write(ircode, 'fmul double ');
          PutOp(y);
          write(ircode, ', ');
          PutOp(y);
          writeln(ircode);
          Def(re);
          write(ircode, 'fsub double ');
          PutOp(c_);
          write(ircode, ', ');
          PutOp(d_);
          writeln(ircode);
          Def(b_);
          write(ircode, 'fmul double ');
          PutOp(x);
          write(ircode, ', ');
          PutOp(y);
          writeln(ircode);
          Def(im);
          write(ircode, 'fmul double 2.0, ');
          PutOp(b_);
          writeln(ircode);
          MakeComplex(re, im, v)
        end;
        biSqrt:   ComplexCall('pas_csqrt       ', a, v);
        biSin:    ComplexCall('pas_csin        ', a, v);
        biCos:    ComplexCall('pas_ccos        ', a, v);
        biLn:     ComplexCall('pas_cln         ', a, v);
        biExp:    ComplexCall('pas_cexp        ', a, v);
        biArcTan: ComplexCall('pas_carctan     ', a, v);
        biNone, biOdd, biOrd, biChr, biSucc, biPred, biTrunc, biRound,
        biEof, biEoln, biCmplx, biPolar, biPosition, biLastPosition, biEmpty,
        biLength, biIndex, biSubstr, biTrim, biCard, biStrEq, biStrNe,
        biStrLt, biStrGt, biStrLe, biStrGe, biArgCount, biArgument:
          OpWord('undef           ', v)
      end
    else
    case e^.clBuiltin of
      biAbs:
        if IsReal(at) then begin
          Def(v);
          write(ircode, 'call double @llvm.fabs.f64(double ');
          PutOp(a);
          writeln(ircode, ')')
        end
        else begin
          { -maxint..maxint is symmetric, so `poison` for the least value can
            never be reached -- and the same holds of -maxint64..maxint64
            (ADR-0014, ADR-0128). }
          Def(v);
          write(ircode, 'call ');
          PutIntWidth(IsInt64(e^.ntype));
          write(ircode, ' @llvm.abs.');
          PutIntWidth(IsInt64(e^.ntype));
          write(ircode, '(');
          PutIntWidth(IsInt64(e^.ntype));
          write(ircode, ' ');
          PutOp(a);
          writeln(ircode, ', i1 false)')
        end;
      { 6.6.6.2 (D.32, and ISO/IEC 10206:1991's D.57 for both types): "sqr(x)
        computes the square of x. It is an error if such a value does not
        exist." For an integer that is the overflow CheckedArith already
        reports; for a real it is an infinity where the operand was finite,
        which is the only real operation the standard names this way --
        6.7.2.2 makes the accuracy of the others implementation-defined rather
        than their overflow an error. The magnitude is what is tested, not the
        value: sqr of minus infinity is plus infinity too, and an operand that
        was already infinite is D.74's error rather than this one. }
      biSqr:
        if IsReal(at) then begin
          Def(v);
          write(ircode, 'fmul double ');
          PutOp(a);
          write(ircode, ', ');
          PutOp(a);
          writeln(ircode);
          Def(sqinf);
          write(ircode, 'fcmp oeq double ');
          PutOp(v);
          writeln(ircode, ', 0x7FF0000000000000');
          Def(mag);
          write(ircode, 'call double @llvm.fabs.f64(double ');
          PutOp(a);
          writeln(ircode, ')');
          Def(sqfin);
          write(ircode, 'fcmp one double ');
          PutOp(mag);
          writeln(ircode, ', 0x7FF0000000000000');
          Def(sqbad);
          write(ircode, 'and i1 ');
          PutOp(sqinf);
          write(ircode, ', ');
          PutOp(sqfin);
          writeln(ircode);
          MsgStart;
          MsgText('real overflow in sqr                    ');
          msg := MsgEnd;
          EmitTrapIf(sqbad, msg, e^.line, e^.col)
        end
        else begin
          MsgStart;
          MsgText('integer overflow in sqr                 ');
          msg := MsgEnd;
          EmitCheckedArith('*', a, a, v, msg, IsInt64(e^.ntype),
                           e^.line, e^.col)
        end;
      biOdd: begin
        Def(w);
        write(ircode, 'and i32 ');
        PutOp(a);
        writeln(ircode, ', 1');
        Def(v);
        write(ircode, 'icmp ne i32 ');
        PutOp(w);
        writeln(ircode, ', 0')
      end;
      biOrd:
        if IsInteger(at) or IsEnum(at) then
          v := a
        else begin
          Def(v);
          write(ircode, 'zext ');
          PutLlType(at);
          write(ircode, ' ');
          PutOp(a);
          writeln(ircode, ' to i32')
        end;
      biChr: begin
        { ISO 7185 6.6.6.4: chr(i) is an error unless i is the ordinal of some
          char, so the truncation is guarded rather than allowed to alias. }
        Def(w);
        write(ircode, 'icmp slt i32 ');
        PutOp(a);
        writeln(ircode, ', 0');
        Def(lim);
        write(ircode, 'icmp sgt i32 ');
        PutOp(a);
        writeln(ircode, ', 255');
        Def(tmp);
        write(ircode, 'or i1 ');
        PutOp(w);
        write(ircode, ', ');
        PutOp(lim);
        writeln(ircode);
        MsgStart;
        MsgText('chr: argument is not a character        ');
        Put(' ');
        MsgText('ordinal                                 ');
        msg := MsgEnd;
        EmitTrapIf(tmp, msg, e^.line, e^.col);
        Def(v);
        write(ircode, 'trunc i32 ');
        PutOp(a);
        writeln(ircode, ' to i8')
      end;
      { 6.7.6.3's card: a population count over the 256-bit word every set is
        (ADR-0028), so the standard's "error if no such value of integer-type
        exists" cannot arise -- the answer is at most 256. }
      biCard: begin
        Def(w);
        write(ircode, 'call i', setBits:1, ' @llvm.ctpop.i', setBits:1,
              '(i', setBits:1, ' ');
        PutOp(a);
        writeln(ircode, ')');
        Def(v);
        write(ircode, 'trunc i', setBits:1, ' ');
        PutOp(w);
        writeln(ircode, ' to i32')
      end;
      biSucc, biPred: begin
        { succ and pred are errors at the ends of the ordinal type (6.6.6.4),
          and which type that is decides where the ends are: `blue` for an
          enumeration, maxint for an integer -- and for a subrange 1..9 it is
          the *host's* ends and not 1 and 9, because 6.7.1 treats a factor of a
          subrange type as being of the type it is a subrange of. Base is what
          says so; the representation is unaffected, LlSize and PutLlType
          having looked through it already. }
        at := Base(at);
        isSucc := e^.clBuiltin = biSucc;
        { 6.7.6.4's succ(x, k), and pred(x, k) which the clause defines as
          succ(x, -(k)). The step is computed in i32 whatever the ordinal's
          width, because ord(x) + k may leave the type in either direction and
          the check is a *range* rather than the one-ended comparison a step of
          1 needs -- so the arithmetic must not wrap before it is looked at. }
        if e^.clArgs^.next <> nil then begin
          EmitExpr(e^.clArgs^.next, k_);
          if IsChar(at) or IsBoolean(at) then begin
            Def(w);
            write(ircode, 'zext ');
            PutLlType(at);
            write(ircode, ' ');
            PutOp(a);
            writeln(ircode, ' to i32')
          end
          else
            w := a;
          { In i64, and that is the whole of D.65. The paragraph above says the
            arithmetic must not wrap before it is looked at, and an i32 add
            wraps: for the integer type OrdinalHi is maxint, so succ(maxint, 2)
            wrapped to -maxint and the range check then found it comfortably
            inside the type. succ(maxint) reported, because a step of 1 takes
            the one-ended path below and compares *before* stepping -- so the
            two spellings of one clause disagreed, and the k form silently
            answered with a value of the wrong sign.

            i64 is enough by construction and not by luck: both operands are
            i32, so their sum needs at most 33 bits and the comparison sees the
            mathematical value. The truncation afterwards is unconditional now
            -- the sum is i64 whatever the ordinal's width -- which is also how
            the two size arms below became one. }
          Def(tmp);
          write(ircode, 'sext i32 ');
          PutOp(w);
          writeln(ircode, ' to i64');
          Def(lim);
          write(ircode, 'sext i32 ');
          PutOp(k_);
          writeln(ircode, ' to i64');
          Def(sum);
          if isSucc then write(ircode, 'add i64 ') else write(ircode, 'sub i64 ');
          PutOp(tmp);
          write(ircode, ', ');
          PutOp(lim);
          writeln(ircode);
          OpInt(OrdinalLo(at), lim);
          Def(w);
          write(ircode, 'icmp slt i64 ');
          PutOp(sum);
          write(ircode, ', ');
          PutOp(lim);
          writeln(ircode);
          OpInt(OrdinalHi(at), lim);
          Def(tmp);
          write(ircode, 'icmp sgt i64 ');
          PutOp(sum);
          write(ircode, ', ');
          PutOp(lim);
          writeln(ircode);
          Def(lim);
          write(ircode, 'or i1 ');
          PutOp(w);
          write(ircode, ', ');
          PutOp(tmp);
          writeln(ircode);
          MsgStart;
          if isSucc then MsgText('succ                                    ')
          else MsgText('pred                                    ');
          MsgText(':                                       ');
          Put(' ');
          MsgText('the result is not a value of            ');
          Put(' ');
          WriteTypeName(at);
          msg := MsgEnd;
          EmitTrapIf(lim, msg, e^.line, e^.col);
          Def(v);
          write(ircode, 'trunc i64 ');
          PutOp(sum);
          write(ircode, ' to ');
          PutLlType(at);
          writeln(ircode)
        end
        else begin
        if isSucc then up := OrdinalHi(at) else up := OrdinalLo(at);
        OpInt(up, lim);
        Def(w);
        write(ircode, 'icmp eq ');
        PutLlType(at);
        write(ircode, ' ');
        PutOp(a);
        write(ircode, ', ');
        PutOp(lim);
        writeln(ircode);
        MsgStart;
        if isSucc then MsgText('succ                                    ')
        else MsgText('pred                                    ');
        MsgText(':                                       ');
        Put(' ');
        WriteOrdinalName(at, up);
        MsgText(' has no                                 ');
        Put(' ');
        if isSucc then MsgText('successor                               ')
        else MsgText('predecessor                             ');
        Put(' ');
        MsgText('in                                      ');
        Put(' ');
        WriteTypeName(at);
        msg := MsgEnd;
        EmitTrapIf(w, msg, e^.line, e^.col);
        Def(v);
        if isSucc then write(ircode, 'add ') else write(ircode, 'sub ');
        PutLlType(at);
        write(ircode, ' ');
        PutOp(a);
        writeln(ircode, ', 1')
        end
      end;
      biSqrt, biSin, biCos, biLn, biExp, biArcTan: begin
        ToReal(a, at);
        if e^.clBuiltin = biSqrt then begin
          MsgStart;
          MsgText('sqrt of a negative number               ');
          msg := MsgEnd;
          GuardSqrtArg(a, msg, e^.line, e^.col)
        end
        else if e^.clBuiltin = biLn then begin
          MsgStart;
          MsgText('ln of a number that is not positive     ');
          msg := MsgEnd;
          GuardLnArg(a, msg, e^.line, e^.col)
        end;
        Def(v);
        case e^.clBuiltin of
          biSqrt: write(ircode, 'call double @llvm.sqrt.f64(double ');
          biSin:  write(ircode, 'call double @llvm.sin.f64(double ');
          biCos:  write(ircode, 'call double @llvm.cos.f64(double ');
          biLn:   write(ircode, 'call double @llvm.log.f64(double ');
          biExp:  write(ircode, 'call double @llvm.exp.f64(double ');
          biArcTan: write(ircode, 'call double @pas_atan(double ');
          biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred, biTrunc,
          biRound, biEof, biEoln: write(ircode, 'call double @pas_atan(double ')
        end;
        PutOp(a);
        writeln(ircode, ')')
      end;
      biTrunc:
        { ADR-0128's narrowing, and the only one: an int64 outside
          -maxint..maxint has no integer to be truncated to, which is
          6.6.6.3's own error condition. The comparison is made in the wider
          type and the truncation follows it, so nothing is tested after the
          bits it would have tested are gone. }
        if IsInt64(at) then begin
          Def(w);
          write(ircode, 'icmp sgt i64 ');
          PutOp(a);
          writeln(ircode, ', 2147483647');
          Def(lim);
          write(ircode, 'icmp slt i64 ');
          PutOp(a);
          writeln(ircode, ', -2147483647');
          Def(narrow);
          write(ircode, 'or i1 ');
          PutOp(w);
          write(ircode, ', ');
          PutOp(lim);
          writeln(ircode);
          MsgStart;
          MsgText('trunc: value out of integer range       ');
          msg := MsgEnd;
          EmitTrapIf(narrow, msg, e^.line, e^.col);
          Def(v);
          write(ircode, 'trunc i64 ');
          PutOp(a);
          writeln(ircode, ' to i32')
        end
        else begin
          ToReal(a, at);
          MsgStart;
          MsgText('trunc: value out of integer range       ');
          msg := MsgEnd;
          CheckedFpToInt(a, v, msg, e^.line, e^.col)
        end;
      biRound: begin
        { 6.6.6.3 and 6.7.6.3 define round by *equivalence* and not by a
          rounding mode: round(x) shall be equivalent to trunc(x+0.5) where x
          is positive or zero, and to trunc(x-0.5) otherwise. `llvm.round` was
          emitted here for a long time on the strength of the two agreeing at
          every halfway point, which they do -- and they part company wherever
          x +- 0.5 is inexact, because the addition rounds. For
          x = 0.49999999999999994 the sum is exactly 1.0, so the clause
          requires 1 where llvm.round yields 0.

          So the *addend* is selected and the result is left to the truncation
          CheckedFpToInt already performs. Three details are load-bearing:
          `oge` puts a NaN on the -0.5 arm, where it stays a NaN and the range
          check traps it; -0.0 lands on the +0.5 arm, which is where "positive
          or zero" wants it, though both arms truncate to 0 there anyway; and
          the range check now applies to the shifted value rather than to the
          rounded one, which is what the clause's own trunc(x+0.5) asks. }
        ToReal(a, at);
        Def(w);
        write(ircode, 'fcmp oge double ');
        PutOp(a);
        writeln(ircode, ', 0.0');
        Def(tmp);
        write(ircode, 'select i1 ');
        PutOp(w);
        writeln(ircode, ', double 5.000000e-01, double -5.000000e-01');
        Def(sum);
        write(ircode, 'fadd double ');
        PutOp(a);
        write(ircode, ', ');
        PutOp(tmp);
        writeln(ircode);
        MsgStart;
        MsgText('round: value out of integer range       ');
        msg := MsgEnd;
        CheckedFpToInt(sum, v, msg, e^.line, e^.col)
      end;
      biNone, biEof, biEoln, biCmplx, biPolar, biRe, biIm, biArg,
      biPosition, biLastPosition, biEmpty, biLength, biIndex, biSubstr,
      biTrim, biStrEq, biStrNe, biStrLt, biStrGt, biStrLe, biStrGe,
      biArgCount, biArgument: OpInt(0, v)
    end
  end
end;

procedure EmitAddress;
var base, idx, lo, hi, below, above, bad, off, target, stride, byte: str;
    hdr, half: str; arr: typePtr; msg: integer;
begin
  case e^.kind of
    nkVar: begin
      { The husk first: a bare argcount is a call and has no address, and
        Sema refused every position that wanted one (IsDesignator answers
        false for a vrSym of nil), so this is reached for a value only. }
      if e^.vrCall <> nil then
        EmitExpr(e^.vrCall, v)
      { A parameterless function written as a bare name is a call (6.8.2.2),
        and a result living in memory *is* the storage the call filled in -- so
        the address of this expression is the address the call returns, not the
        address of anything named vrSym, which is a function and has none. }
      else if (e^.vrField = nil) and IsInvocable(e^.vrSym) then
        EmitExpr(e, v)
      { A constant whose value lives in memory has storage of its own and no
        frame slot, so it must be answered before AddressOfSym -- which would
        otherwise index the frame at frameIndex = -1, i.e. the static link. }
      else if (e^.vrField = nil) and (e^.vrSym^.kind = skConst) then
        ConstAddress(e^.vrSym, v)
      else begin
      AddressOfSym(e^.vrSym, base);
      if e^.vrField = nil then
        v := base
      else
        { The name was a field of an enclosing `with`, and vrSym is that
          statement's binding -- the record's address, taken once on entry. }
        FieldAddress(base, e^.vrSym^.stype, e^.vrField, v, designatorGuard,
                     e^.line, e^.col)
      end
    end;

    nkField:
      { 6.11.3's qualified name denotes one symbol, so it is addressed as a
        bare name is -- the base is an interface-identifier and has no address
        of its own. }
      if e^.fdQualified <> nil then begin
        if e^.fdQualified^.kind = skConst then
          ConstAddress(e^.fdQualified, v)
        else if IsInvocable(e^.fdQualified) then
          EmitExpr(e, v)
        else
          AddressOfSym(e^.fdQualified, v)
      end
      else begin
        EmitAddress(e^.fdBase, base);
        FieldAddress(base, e^.fdBase^.ntype, e^.fdResolved, v, designatorGuard,
                     e^.line, e^.col)
      end;

    nkIndex: begin
      arr := e^.ixBase^.ntype;
      { 6.4.3.3.3 NOTE 1: "The individual components of a variable-string-type
        can be obtained by indexing it as an array." The bound is the *length*,
        not the capacity (6.5.3.2), because the index-domain is the value's and
        the capacity is the type's -- so this cannot go through the array path,
        whose bounds come from the type. }
      { ADR-0125: a slice is indexed against the length it carries, which is
        the only bound in scope -- the callee cannot see where its slice came
        from, and that is exactly the property the pair exists for. }
      if IsSlice(arr) then begin
        EmitSliceValue(e^.ixBase, base, hi);
        EmitExpr(e^.ixIndex, idx);
        Def(below);
        write(ircode, 'icmp slt i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(above);
        write(ircode, 'icmp sgt i32 ');
        PutOp(idx);
        write(ircode, ', ');
        PutOp(hi);
        writeln(ircode);
        Def(bad);
        write(ircode, 'or i1 ');
        PutOp(below);
        write(ircode, ', ');
        PutOp(above);
        writeln(ircode);
        OpInt(1, lo);
        EmitTrapIndex(bad, lo, hi, e^.ixIndex^.line, e^.ixIndex^.col);
        Def(off);
        write(ircode, 'sub i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(v);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(arr^.elem);
        write(ircode, ', ptr ');
        PutOp(base);
        write(ircode, ', i32 ');
        PutOp(off);
        writeln(ircode)
      end
      else if IsVarString(arr) then begin
        EmitString(e^.ixBase, base, hi);
        EmitExpr(e^.ixIndex, idx);
        Def(below);
        write(ircode, 'icmp slt i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(above);
        write(ircode, 'icmp sgt i32 ');
        PutOp(idx);
        write(ircode, ', ');
        PutOp(hi);
        writeln(ircode);
        Def(bad);
        write(ircode, 'or i1 ');
        PutOp(below);
        write(ircode, ', ');
        PutOp(above);
        writeln(ircode);
        OpInt(1, lo);
        EmitTrapIndex(bad, lo, hi, e^.ixIndex^.line, e^.ixIndex^.col);
        Def(off);
        write(ircode, 'sub i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(v);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(base);
        write(ircode, ', i32 ');
        PutOp(off);
        writeln(ircode)
      end
      else begin
      arr := e^.ixBase^.ntype;
      EmitAddress(e^.ixBase, base);
      EmitExpr(e^.ixIndex, idx);
      { char and boolean subscripts are narrower than i32; widening is exact
        because their ordinals are non-negative. }
      if IsChar(e^.ixIndex^.ntype) or IsBoolean(e^.ixIndex^.ntype) then begin
        Def(off);
        write(ircode, 'zext ');
        PutLlType(e^.ixIndex^.ntype);
        write(ircode, ' ');
        PutOp(idx);
        writeln(ircode, ' to i32');
        idx := off
      end;
      { ISO 7185 6.5.3.2 makes an index outside the bounds an error. The check
        comes first, so the subtraction below cannot overflow: afterwards
        lo <= i <= hi, and both bounds are values of the index type. }
      { A heap variable's tuple sits in front of the *variable*, so the
        bounds come from there rather than from any activation record -- and
        for an inner dimension that is not the address just computed. }
      HeapHeader(e^.ixBase, hdr);
      BoundValue(arr, false, hdr, lo);
      BoundValue(arr, true, hdr, hi);
      Def(below);
      write(ircode, 'icmp slt i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(above);
      write(ircode, 'icmp sgt i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bad);
      write(ircode, 'or i1 ');
      PutOp(below);
      write(ircode, ', ');
      PutOp(above);
      writeln(ircode);
      { The message names the bounds, so a schematic array's has to be built
        where the bounds are known -- which is at run time, in the runtime. }
      if (arr^.loDisc <> nil) or (arr^.hiDisc <> nil) then
        EmitTrapIndex(bad, lo, hi, e^.ixIndex^.line, e^.ixIndex^.col)
      else begin
        MsgStart;
        MsgText('array index out of bounds (             ');
        AppendInt(msgBuf, arr^.lo);
        MsgText('..                                      ');
        AppendInt(msgBuf, arr^.hi);
        Put(')');
        msg := MsgEnd;
        EmitTrapIf(bad, msg, e^.ixIndex^.line, e^.ixIndex^.col)
      end;

      Def(off);
      write(ircode, 'sub i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      { An array whose extent is not known until the block is entered has no
        LLVM array type to index: the component's size is what the descriptor
        answers, so the address is computed in bytes. The arithmetic is the
        same `(i - lo) * stride` the two-index getelementptr stands for. }
      if DynamicExtent(arr) then begin
        DynSize(arr^.elem, hdr, stride);
        Def(byte);
        write(ircode, 'mul i32 ');
        PutOp(off);
        write(ircode, ', ');
        PutOp(stride);
        writeln(ircode);
        Def(v);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(base);
        write(ircode, ', i32 ');
        PutOp(byte);
        writeln(ircode)
      end
      else begin
        Def(v);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(arr);
        write(ircode, ', ptr ');
        PutOp(base);
        write(ircode, ', i32 0, i32 ');
        PutOp(off);
        writeln(ircode)
      end
      end
    end;

    nkDeref:
      { `f^` on a file is the buffer variable, not a dereference: the runtime
        owns it, so it hands back its address -- and fetches the character it
        holds first, which is where the lookahead actually happens. }
      if IsFile(e^.drBase^.ntype) then begin
        EmitAddress(e^.drBase, base);
        EmitAt(e^.line, e^.col);
        Def(v);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(base);
        writeln(ircode, ')');
        EmitAtDone
      end
      { ADR-0123: `o^` is the value an optional holds, and the flag is read
        first. It is the only way to that value, so this is the one check
        the type exists to make -- a T that is not optional never reaches it. }
      else if IsOptional(Underlying(e^.drBase^.ntype)) then begin
        EmitAddress(e^.drBase, base);
        OptionalPart(base, Underlying(e^.drBase^.ntype), 0, half);
        Def(off);
        write(ircode, 'load i32, ptr ');
        PutOp(half);
        writeln(ircode);
        Def(bad);
        write(ircode, 'icmp eq i32 ');
        PutOp(off);
        writeln(ircode, ', 0');
        MsgStart;
        MsgText('this optional has no value              ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg, e^.line, e^.col);
        OptionalPart(base, Underlying(e^.drBase^.ntype), 1, v)
      end
      else begin
        { The pointer's *value* is the address of the variable it denotes. }
        EmitExpr(e^.drBase, target);
        Def(bad);
        write(ircode, 'icmp eq ptr ');
        PutOp(target);
        writeln(ircode, ', null');
        MsgStart;
        MsgText('dereference of nil                      ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg, e^.line, e^.col);
        v := target
      end;

    { A literal is a packed array of char, so it needs an address like any
      other value of that type. }
    nkStr: OpGlobal(AddGlobal(e^.stAt, e^.stLen), v);

    { 6.7.6.8's binding(f) denotes the hidden frame slot its result was built
      in, so it is an address like any designator's. }
    nkCall: EmitCall(e, v);

    { 6.8.7's structured-value-constructor. It is not a variable-access -- it
      has an address only because an array and a record have no register form
      (ADR-0017), which is the same reason a memory-living function result has
      one. IsDesignator still answers false for it, so nothing may assign to
      one or pass one as a var parameter. }
    nkStructValue: begin
      StrClear(v);
      EmitStructValue(e, v)
    end;

    nkValueElem,
    nkInt, nkReal, nkInt64, nkChar, nkNil, nkSet, nkSetMember, nkBinary, nkUnary,
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
    nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
    nkPointer, nkOptional, nkHandle, nkFallible, nkFile, nkSetOf, nkSchema, nkInquiry, nkRestricted, nkConstDecl, nkTypeDecl,
    nkProcDecl, nkBlock, nkModule, nkExportPart, nkExportItem,
    nkImportSpec, nkImportItem:
      OpWord('null            ', v)   { Sema has already required a designator }
  end
end;

procedure EmitExpr;
var addr: str; savedGuard: integer;
begin
  { ADR-0118: an expression is a *read*, whatever encloses it. This is what
    keeps `r.a[i].b := 5` honest -- the spine reaching `b` stays a write and
    activates the arms it passes through, while `i` is evaluated here and is
    checked like any other read. Saved and restored rather than simply set,
    because EmitExpr is reached from inside a target's own address. }
  savedGuard := designatorGuard;
  designatorGuard := vgRead;
  case e^.kind of
    nkInt: OpInt(e^.intVal, v);
    nkReal: EmitRealText(e^.rlAt, e^.rlLen, false, v);
    nkInt64: EmitInt64Text(e^.i64At, e^.i64Len, false, v);
    nkChar: OpInt(ord(e^.chVal), v);
    nkStr: EmitAddress(e, v);
    nkNil: OpWord('null            ', v);
    nkDeref: EmitLoad(e, v);
    { 6.8.7.4's set-value wears a subscript's syntax, and Sema hung the
      constructor it really is on the spine (ADR-0066). A set is a value
      (ADR-0028), so it is emitted here and never through EmitAddress. }
    nkIndex:
      if e^.ixSetValue <> nil then begin
        EmitSet(e^.ixSetValue, v);
        CheckedForSetBase(v, e^.ntype, e^.line, e^.col)
      end
      else EmitLoad(e, v);
    { The same, for a spine whose outermost selector was a range. A substring
      proper is a string and leaves through EmitString, so this arm exists for
      the set-value reading alone. }
    nkSubstr:
      if e^.ssSetValue <> nil then begin
        EmitSet(e^.ssSetValue, v);
        CheckedForSetBase(v, e^.ntype, e^.line, e^.col)
      end
      else OpInt(0, v);
    { A schema-discriminant is the value the type was produced with, so it is
      a constant here and there is nothing to load (6.8.4). }
    nkField:
      { A qualified name reaches whatever the interface holds, and the three
        things it can hold each behave as the bare form does. }
      if e^.fdQualified <> nil then
        if e^.fdQualified^.kind = skConst then EmitConst(e^.fdQualified, v)
        else if IsInvocable(e^.fdQualified) then
          EmitUserCall(e^.fdQualified, nil, e^.fdSlot, v, e^.line, e^.col)
        else EmitLoad(e, v)
      { ...unless the base is a schematic formal parameter, whose type was
        produced with no tuple: then it is one field of the descriptor the
        actual brought, and reading it is a load like any other. }
      else if e^.fdDiscSym <> nil then
        { A heap variable's tuple is in front of the variable, so `p^.n` is
          read from where `p^` is; every other descriptor is reached by the
          walk any enclosing variable takes. }
        if e^.fdDiscSym^.heapDisc then
          DiscValue(e^.fdBase, e^.fdDiscSym^.discIndex, e^.ntype, v)
        else begin
          AddressOfSym(e^.fdDiscSym, addr);
          Def(v);
          write(ircode, 'load ');
          PutLlType(e^.ntype);
          write(ircode, ', ptr ');
          PutOp(addr);
          writeln(ircode)
        end
      else if e^.fdIsDisc then OpInt(e^.fdDiscValue, v)
      else EmitLoad(e, v);
    nkVar:
      { the husk first: AP 6.7.6.10's bare argcount (ADR-0173) }
      if e^.vrCall <> nil then
        EmitExpr(e^.vrCall, v)
      else if (e^.vrField = nil) and (e^.vrSym^.kind = skConst) then
        EmitConst(e^.vrSym, v)
      { A parameterless call written as a bare name -- of a function, or of a
        functional parameter, which is the same call through a loaded
        address. }
      else if (e^.vrField = nil) and IsInvocable(e^.vrSym) then
        EmitUserCall(e^.vrSym, nil, e^.vrSlot, v, e^.line, e^.col)
      else
        EmitLoad(e, v);
    nkSet: EmitSet(e, v);
    nkBinary: EmitBinary(e, v);
    nkUnary: EmitUnary(e, v);
    nkCall: EmitCall(e, v);
    { The value of a structured value is the address of the storage it was
      built in -- ADR-0017's rule that an array or a record has no register
      form, which is why this is the same answer EmitAddress gives. }
    nkStructValue:
      { `digits[]`, the null-set-value. A set has no storage to build into, so
        this is the one structured value that is a constant rather than an
        address (ADR-0066). }
      if IsSet(e^.ntype) then OpInt(0, v)
      else begin
        StrClear(v);
        EmitStructValue(e, v)
      end;
    nkValueElem,
    nkSetMember,
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
    nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
    nkPointer, nkOptional, nkHandle, nkFallible, nkFile, nkSetOf, nkSchema, nkInquiry, nkRestricted, nkConstDecl, nkTypeDecl,
    nkProcDecl, nkBlock, nkModule, nkExportPart, nkExportItem,
    nkImportSpec, nkImportItem:
      OpInt(0, v)
  end;
  designatorGuard := savedGuard
end;

{ ============================== statements =============================== }

{ Copy one whole array or record from an address already in hand. `read` from
  a file whose component is structured needs this form: what it copies from is
  the buffer variable, which is a runtime call rather than a designator. }
procedure EmitCopyAt(protected var dst: str; t: typePtr; protected var src: str);
var align: integer;
begin
  align := LlAlign(t);
  write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ', align:1, ' ');
  PutOp(dst);
  write(ircode, ', ptr align ', align:1, ' ');
  PutOp(src);
  writeln(ircode, ', i64 ', LlSize(t):1, ', i1 false)')
end;

procedure EmitCopy(protected var dst: str; t: typePtr; src: nodePtr);
var s: str;
begin
  EmitAddress(src, s);
  EmitCopyAt(dst, t, s)
end;

{ Give the variable at `dst`, of type `t`, the value of `src`. This is the
  whole of what assignment does -- the conversion, the range check, and the
  whole-variable copy -- and `write` to a file that is not a text needs exactly
  it, because 6.6.5.2 defines that write as `f^ := e`. }
procedure EmitStore(var dst: str; t: typePtr; src: nodePtr);
var v, hdr, slot, flag: str; from: typePtr;
begin
  { 6.4.2.5: "Attribution of a value of a type to a variable possessing the
    underlying-type of the type shall constitute the attribution of the
    associated value of the underlying-type." So storing a restricted value *is*
    storing the underlying one -- two lines, and they cover a restricted record,
    array, string and scalar alike. Without them a restricted variable-string
    missed the string path below and stored a scalar over the length word,
    because IsStringType deliberately does not see through: that predicate
    grants the string *operators*, which 6.4.2.5's NOTE forbids. }
  t := Underlying(t);
  from := Underlying(src^.ntype);
  { ISO/IEC 10206:1991 6.4.6: a string destination is not a memcpy. A short
    value is padded with spaces into a fixed string, kept at its own length in
    a variable one, and a value longer than the capacity is an *error* -- so
    this is a runtime operation and is taken before the copy below.

    The destination is asked with IsStringOrChar and not IsStringType, because
    6.4.6 f) names both: "T1 and T2 are compatible, T1 is a string-type *or the
    char-type*, and the length of the value of T2 is less than or equal to the
    capacity of T1", and 6.4.5 d) makes a string-type and the char-type
    compatible in either order. Asking IsStringType let `c := s` fall past this
    arm into the scalar store below, which stored the string's *pointer* into
    an i8 -- IR that clang refuses, naming a file the program's author never
    wrote. EmitStringStoreValue has had the char arm all along; nothing but
    this predicate kept an assignment from reaching it.

    Two chars are excluded because they are an ordinary scalar store, and
    IsChar(t) joins the disjunction because a char has no TypeLength to compare
    -- `or` short-circuits, so that comparison is never reached for one. }
  { AP 6.4.15.5's store joins this arm rather than getting one of its own, and
    for the reason the comment above gives about `c := s`: what decides is the
    *destination*, and every source a text admits is already something
    EmitString can hand over as a pointer and a length. The direction out --
    a variable-string from a text -- is the same arm read the other way.

    A text against a text is here too and is not a copy: 6.4.15.2's invariant
    has to be established at the store even when the source already satisfies
    it, because the two capacities may differ and only the store checks that. }
  if IsText(t) or IsText(from) then begin
    StrClear(hdr);
    EmitStringStore(dst, t, src, hdr)
  end
  else if IsStringOrChar(t) and IsStringOrChar(from) and
     not (IsChar(t) and IsChar(from)) and
     (IsVarString(t) or IsVarString(from) or IsChar(from) or IsChar(t) or
      (TypeLength(t) <> TypeLength(from))) then begin
    StrClear(hdr);
    EmitStringStore(dst, t, src, hdr)
  end
  { 6.8.7's structured-value-constructor is *built*, so it is built here rather
    than built elsewhere and copied -- which is not only cheaper: a
    component-value of an initial-state-specifier has no slot of its own to be
    built in (ADR-0061), because the variable being initialised is the storage
    it was always going to occupy. }
  else if src^.kind = nkStructValue then
    EmitStructValue(src, dst)
  { ADR-0123. Three sources and three shapes: another optional of this type is
    a whole-value copy, flag and all; `nil` writes the flag alone; anything
    else is a value of T, which goes in through this same routine so a string,
    a record and a scalar each keep their own rule.

    The value is stored *before* the flag, which matters: storing a string
    longer than its capacity is an error that stops the program (6.4.6), and
    doing it in this order means no optional is ever marked present over
    storage the store did not finish writing. }
  else if IsOptional(t) then
    if IsOptional(from) then
      EmitCopy(dst, t, src)
    else begin
      if not IsNil(from) then begin
        OptionalPart(dst, t, 1, slot);
        EmitStore(slot, t^.elem, src)
      end;
      OptionalPart(dst, t, 0, flag);
      write(ircode, '  store i32 ');
      if IsNil(from) then write(ircode, '0') else write(ircode, '1');
      write(ircode, ', ptr ');
      PutOp(flag);
      writeln(ircode)
    end
  { A whole array or record is copied; ISO 7185 6.8.2.2 makes assignment of a
    structured value a copy of every component, not a sharing of storage. }
  else if IsStructured(t) then
    EmitCopy(dst, t, src)
  else begin
    EmitExpr(src, v);
    ConvertFor(v, from, t);
    CheckedForStore(v, t, src^.line, src^.col);
    write(ircode, '  store ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(v);
    write(ircode, ', ptr ');
    PutOp(dst);
    writeln(ircode)
  end
end;

{ ------------------------------------------- structured-value-constructors }

{ One component of a structured value: a nested array- or record-value builds
  itself into the address, and anything else is the ordinary store -- so a
  subrange component is range-checked and a string component padded by the code
  that already does both. }
procedure EmitComponentValue(var addr: str; t: typePtr; v: nodePtr);
begin
  if v^.kind = nkStructValue then EmitStructValue(v, addr)
  else EmitStore(addr, t, v)
end;

{ Copy one already-built component onto another. A component-value is one
  expression however many components it is *for*, so it is emitted once and
  then copied -- evaluating it once per component would call a function in it
  once per component. }
procedure CopyComponent(protected var dst, src: str; t: typePtr);
var v: str;
begin
  if IsMemory(t) then
    EmitCopyAt(dst, t, src)
  else begin
    Def(v);
    write(ircode, 'load ');
    PutLlType(t);
    write(ircode, ', ptr ');
    PutOp(src);
    writeln(ircode);
    write(ircode, '  store ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(v);
    write(ircode, ', ptr ');
    PutOp(dst);
    writeln(ircode)
  end
end;

procedure ArrayElement(protected var base: str; arr: typePtr; index: integer;
                       var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds ');
  PutLlType(arr);
  write(ircode, ', ptr ');
  PutOp(base);
  writeln(ircode, ', i32 0, i32 ', index - arr^.lo:1)
end;

{ 6.8.7.2's array-value. The completer is filled in *first* and the elements
  written over it, which is what makes "any component not mapped to by an
  element" need no complement to be computed -- the ranges are disjoint, so
  every component ends up holding the value the standard says it holds. }
procedure EmitArrayValue(e: nodePtr; protected var into: str);
var arr, comp: typePtr; el: nodePtr; r: rangePtr; src, dst: str;
    pass, first, i: integer; wanted: boolean;
begin
  arr := e^.ntype;
  comp := arr^.elem;
  for pass := 0 to 1 do begin
    el := e^.svElems;
    while el <> nil do begin
      wanted := el^.veCompleter = (pass = 0);
      if wanted then begin
        { Where the one evaluation lands: the first component this element is
          for, and then a copy to each of the rest. }
        if el^.veCompleter or (el^.veValues = nil) then first := arr^.lo
        else first := el^.veValues^.lo;
        ArrayElement(into, arr, first, src);
        EmitComponentValue(src, comp, el^.veValue);
        if el^.veCompleter then
          for i := arr^.lo to arr^.hi do begin
            if i <> first then begin
              ArrayElement(into, arr, i, dst);
              CopyComponent(dst, src, comp)
            end
          end
        else begin
          r := el^.veValues;
          while r <> nil do begin
            for i := r^.lo to r^.hi do
              if i <> first then begin
                ArrayElement(into, arr, i, dst);
                CopyComponent(dst, src, comp)
              end;
            r := r^.next
          end
        end
      end;
      el := el^.next
    end
  end
end;

{ 6.8.7.3's record-value over the field-list at `path`. A variant-part-value
  stores the selector -- when the variant part has a tag field to store it in --
  and then this same procedure builds the arm's field-list-value, because an
  arm's field-list is a field-list like any other (ADR-0026). }
procedure EmitRecordValue(e: nodePtr; rec: typePtr; path: numPtr;
                          var into: str);
var fields, f, first: fieldPtr; el: nodePtr; num: numPtr;
    src, dst, ord_: str; tag, i: integer;
begin
  fields := FieldsAt(rec, path);
  el := e^.svElems;
  while el <> nil do begin
    { An element every name of which was refused contributes nothing; Sema has
      already said why. }
    if el^.veFields <> nil then begin
      first := nil;
      f := fields;
      while f <> nil do begin
        if f^.index = el^.veFields^.value_ then first := f;
        f := f^.next
      end;
      FieldAddress(into, rec, first, src, vgNone, 0, 0);
      EmitComponentValue(src, first^.ftype, el^.veValue);
      num := el^.veFields^.next;
      while num <> nil do begin
        f := fields;
        while f <> nil do begin
          if f^.index = num^.value_ then begin
            FieldAddress(into, rec, f, dst, vgNone, 0, 0);
            CopyComponent(dst, src, f^.ftype)
          end;
          f := f^.next
        end;
        num := num^.next
      end
    end;
    el := el^.next
  end;

  if e^.svArm >= 0 then begin
    tag := TagFieldAt(rec, path);
    if tag >= 0 then begin
      f := fields;
      i := 0;
      first := nil;
      while f <> nil do begin
        if i = tag then first := f;
        i := i + 1;
        f := f^.next
      end;
      FieldAddress(into, rec, first, dst, vgNone, 0, 0);
      OpInt(e^.svTagOrd, ord_);
      write(ircode, '  store ');
      PutLlType(first^.ftype);
      write(ircode, ' ');
      PutOp(ord_);
      write(ircode, ', ptr ');
      PutOp(dst);
      writeln(ircode)
    end;
    EmitRecordValue(e^.svVariant, rec, PathAppend(path, e^.svArm), into)
  end
end;

{ 6.8.7. A structured-value-constructor has no register form (ADR-0017), so it
  is *built* rather than computed: the components are stored into the storage
  the value will occupy, and the expression's value is that storage's address.
  At the top that storage is the hidden frame slot Sema gave the node; a nested
  component-value is built directly into the component it is for, which is why
  nothing here allocates anything. }
procedure EmitStructValue;
begin
  if into.len = 0 then AddressOfSym(e^.svSlot, into);
  if IsArray(e^.ntype) then EmitArrayValue(e, into)
  else if IsRecord(e^.ntype) then EmitRecordValue(e, e^.ntype, nil, into)
end;

{ A discriminant may be of any ordinal type, and a message reports it as a
  number -- which is what its ordinal is. }
procedure WidenOrdinal(var v: str; t: typePtr);
var raw: str;
begin
  if IsChar(t) or IsBoolean(t) then begin
    raw := v;
    Def(v);
    write(ircode, 'zext ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(raw);
    writeln(ircode, ' to i32')
  end
end;

{ Two types produced from one schema are the same type exactly when they were
  produced with the same tuple (6.4.8), so that is the comparison -- one per
  discriminant, whatever the body did with them. A discriminant may be of any
  ordinal type; the message reports it as a number, which is what its ordinal
  is. }
procedure EmitTupleCheck(dst, src: nodePtr);
var dp: symListPtr; l, r, bad: str;
    schema: symPtr; schemaMsg, discMsg, k: integer;
begin
  schema := dst^.ntype^.schema;
  MsgStart;
  WritePool(schema^.at, schema^.len);
  schemaMsg := MsgEnd;
  dp := schema^.discs;
  k := 0;
  while dp <> nil do begin
    DiscValue(dst, k, dp^.sym^.stype, l);
    DiscValue(src, k, dp^.sym^.stype, r);
    MsgStart;
    WritePool(dp^.sym^.at, dp^.sym^.len);
    discMsg := MsgEnd;
    Def(bad);
    write(ircode, 'icmp ne ');
    PutLlType(dp^.sym^.stype);
    write(ircode, ' ');
    PutOp(l);
    write(ircode, ', ');
    PutOp(r);
    writeln(ircode);
    WidenOrdinal(l, dp^.sym^.stype);
    WidenOrdinal(r, dp^.sym^.stype);
    EmitTrapDisc(bad, schemaMsg, discMsg, l, r, dst^.line, dst^.col);
    k := k + 1;
    dp := dp^.next
  end
end;

{ 6.4.6 d): where both types were produced from one schema but the tuples are
  not both known, whether they are the same type is a question only the running
  program can answer. Sema let the assignment through on the schema alone, so
  this is where the tuples meet -- and once they agree the copy is the ordinary
  whole-variable one with a length that is computed rather than written. }
procedure EmitAssign;
var dst, src, size, hdr, td, tl, sd, sl: str; t, comp: typePtr;
    align: integer;
begin
  { 6.5.6's substring-variable. Its type is "a new fixed-string-type" of
    capacity hi - lo + 1, and the *fixed*-string store is already exactly that
    rule -- pad a shorter value with spaces, refuse a longer one -- so the only
    thing this case supplies is a capacity that is computed rather than
    written. EmitString has done the bounds check and the arithmetic. }
  if s^.asTarget^.kind = nkSubstr then begin
    EmitString(s^.asTarget, td, tl);
    EmitString(s^.asValue, sd, sl);
    EmitAt(s^.line, s^.col);
    write(ircode, '  call void @pas_str_store_fixed(ptr ');
    PutOp(td);
    write(ircode, ', i32 ');
    PutOp(tl);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')');
    EmitAtDone
  end
  { AP 6.4.12.2 (ADR-0174): the variable takes ownership of what the external
    call answered, and the runtime releases what it held first. The call is
    evaluated before the address is taken, as any right side is.

    AP 6.4.12.6 (ADR-0255) is the other half and is not a second lowering of
    the same thing. A factory -- a function of this program -- answers a type
    that IsMemory, so it was already taking the address of the variable its
    result is to live in; what it is given here is the address of *this*
    target, and its own `Open := ExtFopen(...)` is this same assignment one
    frame in, storing through it. So the handle is born in the variable that
    will own it and is never held anywhere else, and a factory over a factory
    passes the address on with no intermediate handle at all.

    Nothing is stored here in that case, and that is the correctness crux
    rather than an optimisation: a `pas_handle_set` after the call would
    release what the callee had just written into this very slot. }
  { AP 6.4.12.7 (ADR-0267): the move, for a handle. Two calls and the order
    is the whole of it -- `pas_handle_take` empties the source *without*
    calling the closer, which is what makes it a move, and `pas_handle_set`
    then releases what the target held and stores.

    Emptying first is ADR-0182's decision read one type over, and it is what
    makes a self-move work: `h := take(h)` empties the slot, so the release
    inside `pas_handle_set` finds nothing and the value goes back where it
    was. Doing it the other way round would close the very handle being
    moved.

    This arm stands *before* the birth arm below because a `take` is an
    nkCall and EmitCall has no arm for biTake -- reaching it would stop the
    compiler, which is the property AP 6.4.14.6 relies on to make every other
    position unreachable. }
  else if IsHandle(s^.asTarget^.ntype) and
          (s^.asValue^.kind = nkCall) and
          (s^.asValue^.clBuiltin = biTake) then begin
    EmitAddress(s^.asValue^.clArgs, src);
    Def(hdr);
    write(ircode, 'call ptr @pas_handle_take(ptr ');
    PutOp(src);
    writeln(ircode, ')');
    { ADR-0118, as every other arm here does it: this is the one designator
      whose variant a write activates. }
    designatorGuard := vgWrite;
    EmitAddress(s^.asTarget, dst);
    designatorGuard := vgRead;
    { AP 6.4.16.4, as the release below: what the target held is released
      here, and a channel released by the program is closed (ADR-0302). }
    if IsChannel(s^.asTarget^.ntype) then EmitChanShut(dst);
    write(ircode, '  call void @pas_handle_set(ptr ');
    PutOp(dst);
    write(ircode, ', ptr ');
    PutOp(hdr);
    writeln(ircode, ')')
  end
  else if IsHandle(s^.asTarget^.ntype) then begin
    if s^.asFactory then factoryInto := s^.asTarget;
    EmitExpr(s^.asValue, src);
    factoryInto := nil;
    if not s^.asFactory then begin
      { ADR-0118, as the ordinary assignment path does it: this is the one
        designator whose variant a write *activates*. It did not matter until
        AP 6.4.13.5 (ADR-0256) put a handle inside a variant part -- until
        then no handle could be one, so this arm never addressed an arm and
        the omission was invisible. Without it `res.val := ExtFopen(...)` is
        guarded as a read and traps against whichever arm was last active. }
      designatorGuard := vgWrite;
      EmitAddress(s^.asTarget, dst);
      designatorGuard := vgRead;
      { AP 6.4.16.4 (ADR-0302): `c := nil` is AP 6.4.12.2's early release
        written as an assignment, so it closes the channel exactly as
        `release(c)` does -- one meaning for the two spellings. }
      if IsChannel(s^.asTarget^.ntype) then EmitChanShut(dst);
      write(ircode, '  call void @pas_handle_set(ptr ');
      PutOp(dst);
      write(ircode, ', ptr ');
      PutOp(src);
      writeln(ircode, ')')
    end
  end
  { AP 6.4.13.5 (ADR-0256): the fallible form of the arm above, and the same
    lowering read one level out. The record contains something affine, so it
    has no copy and there is nothing to memcpy: the callee is handed this
    target's address and builds its answer there -- the tag and whichever arm
    it activated. A memcpy would be ADR-0150's double free with a handle in
    place of a file, two records each holding a slot the runtime is tracking.

    Nothing else in EmitAssign reaches this: Sema admits exactly one value
    here, a call of a function of this very type, and `asFactory` is what says
    the callee is one of this program's. }
  else if s^.asFactory and IsFallible(s^.asTarget^.ntype) then begin
    factoryInto := s^.asTarget;
    EmitExpr(s^.asValue, src);
    factoryInto := nil
  end
  { AP 6.4.14.6 (ADR-0182): the move. Four instructions and no runtime call --
    read what the source holds, empty it, release what the target held, store.

    **The source is read and emptied first, and that order is the decision.**
    A target designator reached *through* the source -- `p^.next := take(p)`
    -- would otherwise compute an address inside the very node it is about to
    orphan, and the store would make the node its own successor: a cycle that
    nothing owns and no release can reach. Emptying first makes that program
    dereference `nil` and stop, which is a defect reported instead of a leak.
    The order costs nothing where the two are unrelated, which is every other
    program.

    It also makes `n := take(n^.next)` the whole of pop-front: the source is
    the head's own field, so releasing what the target held disposes the head
    alone -- its successor having just been emptied out of it -- and the tail
    lands in `n`.

    This is where a `take` is lowered and the only place: EmitCall has no arm
    for biTake, so a call anywhere else stops the compiler rather than
    emitting a move nobody could see. AP 6.4.14.6 admits no other position,
    which is what makes that unreachable rather than unfinished. }
  else if IsOwnedPointer(s^.asTarget^.ntype) then begin
    EmitAddress(s^.asValue^.clArgs, src);
    Def(hdr);
    write(ircode, 'load ptr, ptr ');
    PutOp(src);
    writeln(ircode);
    write(ircode, '  store ptr null, ptr ');
    PutOp(src);
    writeln(ircode);
    EmitAddress(s^.asTarget, dst);
    Def(td);
    write(ircode, 'load ptr, ptr ');
    PutOp(dst);
    writeln(ircode);
    write(ircode, '  call void @ownrel',
          OwnRelId(s^.asTarget^.ntype^.elem):1, '(ptr ');
    PutOp(td);
    writeln(ircode, ')');
    write(ircode, '  store ptr ');
    PutOp(hdr);
    write(ircode, ', ptr ');
    PutOp(dst);
    writeln(ircode)
  end
  else begin
  { ADR-0118: the target of an assignment is the one designator whose variant
    a write *activates*. Cleared immediately, so the value on the right and
    everything after it is read like any other expression. }
  designatorGuard := vgWrite;
  EmitAddress(s^.asTarget, dst);
  designatorGuard := vgRead;
  t := s^.asTarget^.ntype;
  { A string is produced from the required schema, so it would otherwise take
    the tuple-comparison path below -- and must not: 6.4.6 f) makes two
    capacities *compatible*, and the check that matters is the value's length
    against the destination's capacity, which the store makes.

    A text is produced from a required schema too (AP 6.4.15.1) and 6.4.15.5
    makes its capacities compatible the same way, so it joins this arm. Left
    out, `t := s` between a schematic `var t: utf8` and a `string` compared
    the *string's* capacity against the text's and trapped -- the tuple check
    reads the destination's schema and does not ask whether the source was
    produced from the same one. }
  if IsStringType(t) or IsText(t) then begin
    HeapHeader(s^.asTarget, hdr);
    EmitStringStore(dst, t, s^.asValue, hdr)
  end
  { And a subrange, for the reason Assignable exempts one: the anonymous
    schema on it describes where its *bounds* are and not an extent, so there
    is no tuple to compare and nothing to copy by size. Its store is the
    ordinary one, with the range check reading the descriptor (ADR-0133). }
  { ...or the extent is not a constant for any other reason. Since ISO 7185
    6.6.3.7 there is one: a *row* of a two-dimensional conformant array
    parameter has bounds in the descriptor and no schema of its own, because
    BoundSchemaFor gives one to the parameter and not to each level of its
    nest. Without this disjunct `a[p] := a[q]` between two rows took the static
    path and LlSize answered for the placeholder bounds -- one component copied
    of however many there are. BSI's LEV1F45 is the program that assigns a row.

    There is no tuple to check on that path: 6.6.3.7 makes every actual of one
    conformant-array-parameter-specification possess the same type, so two rows
    of one parameter have the same extent by construction and an assignment
    between rows of *different* parameters is refused by name equivalence. }
  else if ((t^.schema <> nil) and (t^.kind <> tySubrange) and
           (IsGeneric(t) or IsGeneric(s^.asValue^.ntype)))
          or DynamicExtent(t) then begin
    if t^.schema <> nil then EmitTupleCheck(s^.asTarget, s^.asValue);
    EmitAddress(s^.asValue, src);
    { The alignment is the component's, for the same reason a schematic value
      parameter's copy takes it from there: the array type has no extent to
      give. }
    comp := t;
    while comp^.kind = tyArray do comp := comp^.elem;
    align := LlAlign(comp);
    { The length is the *destination's*, which the tuple check has just shown
      to be the source's too -- and for a variable created by `new` it is read
      from the header in front of it rather than from a descriptor. }
    HeaderOf(t, dst, hdr);
    DynSize(t, hdr, size);
    write(ircode, '  call void @llvm.memcpy.p0.p0.i32(ptr align ', align:1,
          ' ');
    PutOp(dst);
    write(ircode, ', ptr align ', align:1, ' ');
    PutOp(src);
    write(ircode, ', i32 ');
    PutOp(size);
    writeln(ircode, ', i1 false)')
  end
  else
    EmitStore(dst, t, s^.asValue)
  end
end;

{ The write-parameters of the text form (6.10.3), emitted into whichever file
  is given -- the one the statement named, or 6.7.5.5's auxiliary variable when
  this is a writestr. Nothing here knows which. }
{ ISO 7185 6.9.3.1 requires TotalWidth and FracDigits to be at least one;
  ISO/IEC 10206:1991 6.10.3.1 moves the bound to zero -- "it shall be an error
  if the value is less than zero" -- which is what makes write(e:0) legal and
  D.102/D.103 what makes a negative one an error either way.

  The check is emitted here rather than made in the runtime, because the bound
  is the one thing about it the standard decides and the runtime is never told
  which standard it was compiled for. It also keeps -1 usable as the "no width
  given" sentinel: no width that reaches the runtime is ever negative. }
procedure CheckedWidth(protected var v: str; isPrec: boolean;
                       line, col: integer);
var least, msg: integer; leastOp, bad: str;
begin
  least := 0;
  OpInt(least, leastOp);
  Def(bad);
  write(ircode, 'icmp slt i32 ');
  PutOp(v);
  write(ircode, ', ');
  PutOp(leastOp);
  writeln(ircode);
  MsgStart;
  if isPrec then MsgText('a fraction length                       ')
  else MsgText('a field width                           ');
  MsgText(' must not be negative                   ');
  msg := MsgEnd;
  EmitTrapIf(bad, msg, line, col)
end;

{ The write-parameters of the text form (6.10.3), emitted into whichever file
  is given -- the one the statement named, or 6.7.5.5's auxiliary variable when
  this is a writestr. Nothing here knows which. }
procedure EmitWriteArgs(s: nodePtr; protected var fh: str);
var v, width, prec, addr, slen, shdr, sdata: str;
    a: nodePtr; b: typePtr;
begin
    a := s^.wrArgs;
    while a <> nil do begin
      if a^.waWidth <> nil then begin
        EmitExpr(a^.waWidth, width);
        CheckedWidth(width, false, a^.waWidth^.line, a^.waWidth^.col)
      end
      else OpInt(-1, width);
      if a^.waPrec <> nil then begin
        EmitExpr(a^.waPrec, prec);
        CheckedWidth(prec, true, a^.waPrec^.line, a^.waPrec^.col)
      end
      else OpInt(-1, prec);

      { A packed array of char is written as its address plus its length --
        which covers a string literal, since that is what a literal's type is. }
      { A string is written as its address plus its length -- which covers a
      literal, since that is what a literal's type is, and a variable-string
      and a canonical value alike, since EmitString is what a string value
      *is*. 6.10.3.6 asks for exactly those two numbers. }
    { AP 6.4.15.10: the same two numbers, and a different writer -- because the
      field-width is in **elements** and the pair carries bytes, so the padding
      cannot be computed from the length the way it can for every other type
      written here. That clause's NOTE admits the width is still not what a
      terminal does: a wide character occupies two columns and a combining mark
      none, and East Asian Width is a table this language does not carry. }
    if IsText(a^.waValue^.ntype) then begin
      EmitString(a^.waValue, sdata, slen);
      EmitAt(a^.waValue^.line, a^.waValue^.col);
      write(ircode, '  call void @pas_write_text(ptr ');
      PutOp(fh);
      write(ircode, ', ptr ');
      PutOp(sdata);
      write(ircode, ', i32 ');
      PutOp(slen);
      write(ircode, ', i32 ');
      PutOp(width);
      writeln(ircode, ')');
      EmitAtDone
    end
    else if IsStringType(a^.waValue^.ntype) then begin
      EmitString(a^.waValue, sdata, slen);
      EmitAt(a^.waValue^.line, a^.waValue^.col);
      write(ircode, '  call void @pas_write_str(ptr ');
      PutOp(fh);
      write(ircode, ', ptr ');
      PutOp(sdata);
      write(ircode, ', i32 ');
      PutOp(slen);
      write(ircode, ', i32 ');
      PutOp(width);
      writeln(ircode, ')');
      EmitAtDone
    end
    else if IsCharArray(a^.waValue^.ntype) then begin
        EmitAddress(a^.waValue, addr);
        HeapHeader(a^.waValue, shdr);
        DynLength(a^.waValue^.ntype, shdr, slen);
        EmitAt(a^.waValue^.line, a^.waValue^.col);
        write(ircode, '  call void @pas_write_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(addr);
        write(ircode, ', i32 ');
        PutOp(slen);
        write(ircode, ', i32 ');
        PutOp(width);
        writeln(ircode, ')');
        EmitAtDone
      end
      else begin
        EmitExpr(a^.waValue, v);
        b := Base(a^.waValue^.ntype);
        if (b^.kind = tyInteger) or (b^.kind = tyInt64) then begin
          { The runtime has taken an i64 since it was written -- an integer is
            widened into it, and 6.10.3.1's decimal representation is the same
            one whatever the width, so ADR-0128's type needs nothing of the
            runtime but the sext left out. }
          if b^.kind = tyInteger then begin
            Def(addr);
            write(ircode, 'sext i32 ');
            PutOp(v);
            writeln(ircode, ' to i64')
          end
          else
            addr := v;
          EmitAt(a^.waValue^.line, a^.waValue^.col);
          write(ircode, '  call void @pas_write_int(ptr ');
          PutOp(fh);
          write(ircode, ', i64 ');
          PutOp(addr);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')');
          EmitAtDone
        end
        else if b^.kind = tyReal then begin
          EmitAt(a^.waValue^.line, a^.waValue^.col);
          write(ircode, '  call void @pas_write_real(ptr ');
          PutOp(fh);
          write(ircode, ', double ');
          PutOp(v);
          write(ircode, ', i32 ');
          PutOp(width);
          write(ircode, ', i32 ');
          PutOp(prec);
          writeln(ircode, ')');
          EmitAtDone
        end
        else if b^.kind = tyBoolean then begin
          Def(addr);
          write(ircode, 'zext i1 ');
          PutOp(v);
          writeln(ircode, ' to i32');
          EmitAt(a^.waValue^.line, a^.waValue^.col);
          write(ircode, '  call void @pas_write_bool(ptr ');
          PutOp(fh);
          write(ircode, ', i32 ');
          PutOp(addr);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')');
          EmitAtDone
        end
        else if b^.kind = tyChar then begin
          EmitAt(a^.waValue^.line, a^.waValue^.col);
          write(ircode, '  call void @pas_write_char(ptr ');
          PutOp(fh);
          write(ircode, ', i8 ');
          PutOp(v);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')');
          EmitAtDone
        end
      end;
      a := a^.next
    end;
end;

procedure EmitWrite(s: nodePtr);
var fh, aux, sdata, slen, tdata, tlen, hdr: str;
    a: nodePtr;
begin
  { ISO/IEC 10206:1991 6.7.5.5: writestr is rewrite(f); writeln(f, p...);
    reset(f); read(f, ss) over an auxiliary text variable. The runtime is that
    variable, so everything between here and the store below is the ordinary
    text `write` -- emitted by the very same procedure. }
  if s^.wrStr <> nil then begin
    EmitAt(s^.line, s^.col);
    Def(aux);
    writeln(ircode, 'call ptr @pas_str_write_begin()');
    EmitWriteArgs(s, aux);
    EmitAt(s^.line, s^.col);
    Def(slen);
    write(ircode, 'call i32 @pas_str_write_len(ptr ');
    PutOp(aux);
    writeln(ircode, ')');
    EmitAtDone;
    EmitAtDone;
    Def(sdata);
    write(ircode, 'call ptr @pas_str_write_ptr(ptr ');
    PutOp(aux);
    writeln(ircode, ')');
    { The read(f, ss) half. 6.4.6's capacity check inside the store is
      6.7.5.5's "error if the equivalent of eoln(f) is false upon completion":
      more was written than the destination can hold. }
    if s^.wrStr^.kind = nkSubstr then begin
      EmitString(s^.wrStr, tdata, tlen);
      EmitAt(s^.wrStr^.line, s^.wrStr^.col);
      write(ircode, '  call void @pas_str_store_fixed(ptr ');
      PutOp(tdata);
      write(ircode, ', i32 ');
      PutOp(tlen);
      write(ircode, ', ptr ');
      PutOp(sdata);
      write(ircode, ', i32 ');
      PutOp(slen);
      writeln(ircode, ')');
      EmitAtDone
    end
    else begin
      EmitAddress(s^.wrStr, tdata);
      HeapHeader(s^.wrStr, hdr);
      EmitStringStoreValue(tdata, s^.wrStr^.ntype, sdata, slen, hdr,
                           s^.wrStr^.line, s^.wrStr^.col)
    end;
    write(ircode, '  call void @pas_str_write_end(ptr ');
    PutOp(aux);
    writeln(ircode, ')')
  end
  else if s^.wrFile <> nil then begin
    EmitAddress(s^.wrFile, fh);
    { On a file that is not a text, ISO 7185 6.6.5.2 defines write(f, e) as
      f^ := e; put(f) -- so it is emitted as exactly that, an assignment to
      the buffer variable and the primitive. No formatting applies. }
    if not IsTextFile(s^.wrFile^.ntype) then begin
      a := s^.wrArgs;
      while a <> nil do begin
        EmitAt(a^.waValue^.line, a^.waValue^.col);
        Def(sdata);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        EmitStore(sdata, s^.wrFile^.ntype^.elem, a^.waValue);
        EmitAt(a^.waValue^.line, a^.waValue^.col);
        write(ircode, '  call void @pas_put(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        a := a^.next
      end
    end
    else begin
      EmitWriteArgs(s, fh);
      if s^.wrNewline then begin
        EmitAt(s^.line, s^.col);
        write(ircode, '  call void @pas_writeln(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone
      end
    end
  end
end;

{ The variables of the text form (6.10.1), filled from whichever file is given
  -- the one the statement named, or 6.7.5.5's auxiliary variable. }
procedure EmitReadArgs(s: nodePtr; protected var fh: str);
var slot, v, wide, rhdr, rcap: str; a: nodePtr; t: typePtr;
    needStore: boolean;
begin
    a := s^.rdArgs;
    while a <> nil do begin
      { 6.5.1 lists a substring-variable among the variable-accesses, so 6.10
        admits one here. Its capacity is hi - lo + 1 rather than its type's,
        which is exactly what EmitString computes -- and a substring is a
        *fixed*-string-type (6.5.6), so the flag is the fixed one and the tail
        is padded with spaces. }
      { Pascal has no `continue`, so what the C++ says with one is said here
        by a flag: the three scalar branches below produce a value to store and
        the two string branches do not. Without it a `read` of a string stored
        whatever register the *previous* argument left behind. }
      needStore := false;
      { ADR-0144: ISO/IEC 10206:1991 6.10.2 writes `read(f, v)` out as
        `begin v := f^; get(f) end`, so the target of a read is *assigned to*
        and ADR-0118's activation applies to it exactly as it does to the left
        side of an assignment-statement. Its own NOTE 2 says so in as many
        words -- "the variable-access is not a variable parameter.
        Consequently, it may be a variant-selector or a component of a packed
        structure".

        Without this the dialect trapped on `read(r.gr)` where the tag named
        another arm, which is a valid ISO/IEC 10206:1991 program refused --
        a containment break, and one no corpus program could reach because no
        corpus program reads into a variant. Cleared per argument rather than
        per statement: `read(a, b)` assigns to both, and each is its own
        designator. }
      designatorGuard := vgWrite;
      if a^.kind = nkSubstr then begin
        EmitString(a, slot, rcap);
        EmitAt(a^.line, a^.col);
        write(ircode, '  call void @pas_read_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(slot);
        write(ircode, ', i32 ');
        PutOp(rcap);
        writeln(ircode, ', i32 0)')
      end
      else begin
      EmitAddress(a, slot);
      t := a^.ntype;
      { ISO/IEC 10206:1991 6.10.1 e) and f): reading a string does not skip
        leading blanks, never crosses an end-of-line, and takes at most the
        capacity -- a fixed target is then padded with spaces and a variable
        one gets exactly what was read. That is one runtime call for both, told
        apart by the capacity and one flag. }
      if IsStringType(t) then begin
        HeapHeader(a, rhdr);
        if IsVarString(t) then StringCapacity(t, rhdr, rcap)
        else DynLength(t, rhdr, rcap);
        EmitAt(a^.line, a^.col);
        write(ircode, '  call void @pas_read_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(slot);
        write(ircode, ', i32 ');
        PutOp(rcap);
        if IsVarString(t) then writeln(ircode, ', i32 1)')
        else writeln(ircode, ', i32 0)')
      end
      else if IsChar(t) then begin
        needStore := true;
        EmitAt(a^.line, a^.col);
        Def(v);
        write(ircode, 'call i8 @pas_read_char(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        EmitAtDone;
        EmitAtDone
      end
      else if IsReal(t) then begin
        needStore := true;
        EmitAt(a^.line, a^.col);
        Def(v);
        write(ircode, 'call double @pas_read_real(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone
      end
      { An int64 is what the runtime already accumulates in, so this is the
        one arm with nothing to narrow -- and no subrange to check, ADR-0128
        making int64 numeric rather than ordinal. }
      else if IsInt64(t) then begin
        needStore := true;
        EmitAt(a^.line, a^.col);
        Def(v);
        write(ircode, 'call i64 @pas_read_int64(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone
      end
      else begin
        needStore := true;
        { The runtime returns i64 and has already rejected anything outside
          -maxint..maxint, so this truncation cannot lose a valid value. }
        EmitAt(a^.line, a^.col);
        Def(wide);
        write(ircode, 'call i64 @pas_read_int(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        Def(v);
        write(ircode, 'trunc i64 ');
        PutOp(wide);
        writeln(ircode, ' to i32');
        CheckedForSubrange(v, t, a^.line, a^.col)
      end
      end;
      if needStore then begin
        write(ircode, '  store ');
        PutLlType(t);
        write(ircode, ' ');
        PutOp(v);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode)
      end;
      designatorGuard := vgRead;
      a := a^.next
    end;
end;

{ Each variable is filled by the runtime call its type selects, and `readln`
  then finishes the line -- which is what makes readln(x) one statement. }
procedure EmitRead(s: nodePtr);
var fh, slot, v, buf, aux, sdata, slen: str; a: nodePtr; comp: typePtr;
begin
  { 6.7.5.5's readstr: rewrite(f); writeln(f, e); reset(f); read(f, v...).
    The string's characters are what the auxiliary text variable holds, so the
    variables are read by the very procedure below. }
  if s^.rdStr <> nil then begin
    EmitString(s^.rdStr, sdata, slen);
    EmitAt(s^.line, s^.col);
    Def(aux);
    write(ircode, 'call ptr @pas_str_read_begin(ptr ');
    PutOp(sdata);
    write(ircode, ', i32 ');
    PutOp(slen);
    writeln(ircode, ')');
    EmitAtDone;
    EmitReadArgs(s, aux);
    { "It shall be an error if the equivalent of eof(f) is true upon
      completion" -- the runtime asks, because eof is its question and the
      auxiliary variable is not a file the program can name. }
    EmitAt(s^.line, s^.col);
    write(ircode, '  call void @pas_str_read_end(ptr ');
    PutOp(aux);
    writeln(ircode, ')');
    EmitAtDone
  end
  else if s^.rdFile <> nil then begin
    EmitAddress(s^.rdFile, fh);
    { The mirror of EmitWrite: on a file that is not a text, 6.6.5.2 makes
      read(f, v) mean v := f^; get(f). The buffer variable is fetched again
      for each variable because `get` invalidates the previous one. }
    if not IsTextFile(s^.rdFile^.ntype) then begin
      comp := s^.rdFile^.ntype^.elem;
      a := s^.rdArgs;
      while a <> nil do begin
        EmitAddress(a, slot);
        EmitAt(a^.line, a^.col);
        Def(buf);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        if IsStructured(a^.ntype) then
          EmitCopyAt(slot, a^.ntype, buf)
        else begin
          Def(v);
          write(ircode, 'load ');
          PutLlType(comp);
          write(ircode, ', ptr ');
          PutOp(buf);
          writeln(ircode);
          ConvertFor(v, comp, a^.ntype);
          CheckedForStore(v, a^.ntype, a^.line, a^.col);
          write(ircode, '  store ');
          PutLlType(a^.ntype);
          write(ircode, ' ');
          PutOp(v);
          write(ircode, ', ptr ');
          PutOp(slot);
          writeln(ircode)
        end;
        EmitAt(a^.line, a^.col);
        write(ircode, '  call void @pas_get(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone;
        a := a^.next
      end
    end
    else begin
      EmitReadArgs(s, fh);
      if s^.rdNewline then begin
        EmitAt(s^.line, s^.col);
        write(ircode, '  call void @pas_readln(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitAtDone
      end
    end
  end
end;

{ `new(p)` gives p the address of fresh storage for one variable of its domain;
  `dispose(p)` gives it back. The size is a compile-time constant because the
  domain type is. }
{ 10206 6.7.5.3's other form of `new`: the arguments are the tuple the created
  variable's type is produced with. The size is asked of the tuple before there
  is anywhere to put the tuple, so for the length of those two calls the bounds
  are answered from the values rather than from a header -- no scratch storage
  exists, which is what lets a sequential emitter do this at all. }
procedure CheckSchemaDomain(t: typePtr; schema: symPtr;
                            var header: str; line, col: integer);
  forward;

{ ISO/IEC 10206:1991 6.7.5.3, for `new(p, c1, ..., cn)`: "the initial state of
  the selector of the variant corresponding with the case-constant ci shall be
  the state bearing the value associated with the variant corresponding to the
  value denoted by ci", and its NOTE 1 spells out the consequence -- "any
  corresponding tag-field is also attributed the value of the case-constant".

  ISO 7185 did not require it -- its 6.6.5.3 said the created variable "shall
  be totally-undefined", a statement about which variants exist and not about
  the tag -- so this used to be behind a mode test.

  It was not implemented at all: pcSelect was read for SelectedSize and for
  nothing else, so `new(p, green)` allocated the right amount of storage and
  left the tag reading `red`. That is a program given a wrong answer -- `case
  p^.k of` took the wrong arm -- and ADR-0118's guard then trapped on a read of
  the variant the program had just asked for.

  The walk is FieldAddress's, without the guard: descend one variant part per
  selector, storing the tag at each level that has one. A variant part with no
  tag-field answers -1 and is skipped, there being nothing to attribute the
  value to (6.4.3.4 requires a tag-type here, but a *tagless* part can sit
  above one in the same record). }
procedure EmitNewSelectors(rec: typePtr; block: str; sel, vals: numPtr);
var path: numPtr; tagIdx: integer; tt: typePtr; cur, p, tagAddr: str;
begin
  cur := block;
  path := nil;
  while (sel <> nil) and (vals <> nil) do begin
    tagIdx := TagFieldAt(rec, path);
    if tagIdx >= 0 then begin
      tt := TagTypeAt(rec, path);
      Def(tagAddr);
      write(ircode, 'getelementptr inbounds ');
      PutStructAt(rec, path);
      write(ircode, ', ptr ');
      PutOp(cur);
      writeln(ircode, ', i32 0, i32 ', tagIdx:1);
      write(ircode, '  store ');
      PutLlType(tt);
      write(ircode, ' ', vals^.value_:1, ', ptr ');
      PutOp(tagAddr);
      writeln(ircode)
    end;
    Def(p);
    write(ircode, 'getelementptr inbounds ');
    PutStructAt(rec, path);
    write(ircode, ', ptr ');
    PutOp(cur);
    writeln(ircode, ', i32 0, i32 ', FieldCount(FieldsAt(rec, path)):1);
    cur := p;
    path := PathAppend(path, sel^.value_);
    sel := sel^.next;
    vals := vals^.next
  end
end;

procedure EmitNewTuple(s: nodePtr; domain: typePtr; protected var slot: str);
var d: symListPtr; value_: nodePtr; v, size, raw, block, vr, nohdr: str;
    k, head: integer; cell, next: discValPtr;
begin
  newTuple := nil;
  k := 0;
  d := domain^.schema^.discs;
  value_ := s^.pcArgs^.next;
  while (d <> nil) and (value_ <> nil) do begin
    EmitExpr(value_, v);
    ConvertFor(v, value_^.ntype, d^.sym^.stype);
    { A discriminant outside its own type is outside 6.4.7's domain, and this
      is where the value enters the variable that holds it -- so the check
      that guards every other such store makes this one too. }
    CheckedForStore(v, d^.sym^.stype, s^.line, s^.col);
    if IsChar(d^.sym^.stype) or IsBoolean(d^.sym^.stype) then begin
      raw := v;
      Def(v);
      write(ircode, 'zext ');
      PutLlType(d^.sym^.stype);
      write(ircode, ' ');
      PutOp(raw);
      writeln(ircode, ' to i32')
    end;
    new(cell);
    cell^.idx := k;
    cell^.value_ := v;
    cell^.next := newTuple;
    newTuple := cell;
    k := k + 1;
    d := d^.next;
    value_ := value_^.next
  end;

  StrClear(nohdr);
  { 6.7.5.3: it shall be a dynamic-violation if the tuple is not in the domain
    of the schema -- the same check a variable's tuple gets on entry. }
  CheckSchemaDomain(domain, domain^.schema, nohdr, s^.line, s^.col);
  DynSize(domain, nohdr, size);
  head := HeaderSize(domain);
  Def(raw);
  write(ircode, 'add i32 ');
  PutOp(size);
  writeln(ircode, ', ', head:1);
  Def(v);
  write(ircode, 'zext i32 ');
  PutOp(raw);
  writeln(ircode, ' to i64');
  EmitAt(s^.line, s^.col);
  Def(block);
  write(ircode, 'call ptr @pas_new(i64 ');
  PutOp(v);
  writeln(ircode, ')');
  EmitAtDone;

  cell := newTuple;
  while cell <> nil do begin
    Def(vr);
    write(ircode, 'getelementptr i32, ptr ');
    PutOp(block);
    writeln(ircode, ', i32 ', cell^.idx:1);
    write(ircode, '  store i32 ');
    PutOp(cell^.value_);
    write(ircode, ', ptr ');
    PutOp(vr);
    writeln(ircode);
    next := cell^.next;
    cell := next
  end;
  newTuple := nil;

  { The pointer denotes the *variable*, not the block, so everything else
    about a pointer -- assignment, comparison with nil, dereference -- is
    unchanged, and only `new` and `dispose` know the header is there. }
  Def(vr);
  write(ircode, 'getelementptr i8, ptr ');
  PutOp(block);
  writeln(ircode, ', i32 ', head:1);
  write(ircode, '  store ptr ');
  PutOp(vr);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode)
end;

{ ISO 7185 6.6.5.4's pack(a, i, z) and unpack(z, a, i). The clause does not
  describe an operation -- it gives a *statement sequence* each is equivalent
  to:

      k := i; for j := u to v do begin zz[j] := aa[k];
                                       if j <> v then k := succ(k) end

  The bounds are checked once, before anything is copied, rather than at each
  aa[k]: k runs monotonically from i, so the two ends are the only values that
  can leave the array, and a partial copy before the trap would be worse than
  none.

  The copy itself is a memcpy, and that is a fact about *this* compiler rather
  than a shortcut. 6.4.3.1 leaves `packed` entirely to the implementation and
  this one packs nothing, so a packed array and an unpacked array of the same
  component type have the same layout and the representation change these
  procedures exist to make is vacuous here. What is left of 6.6.5.4 is the
  index arithmetic and the range check (ADR-0067). }
procedure EmitTransfer(s: nodePtr);
var unpackedArg, packedArg, indexArg: nodePtr;
    ua, pa, idx, wide, lo, hi, last, off, from, below, above, bad: str;
    uhdr, phdr, plo, phi, spn, stride, byte, plen, wlen: str;
    ut, pt: typePtr;
    span, align, msg: integer;
begin
  TransferArgs(s, unpackedArg, packedArg, indexArg);
  ut := unpackedArg^.ntype;
  pt := packedArg^.ntype;
  EmitAddress(unpackedArg, ua);
  EmitAddress(packedArg, pa);
  EmitExpr(indexArg, idx);
  { char and boolean subscripts are narrower than i32; widening is exact
    because their ordinals are non-negative. }
  if IsChar(indexArg^.ntype) or IsBoolean(indexArg^.ntype) then begin
    Def(wide);
    write(ircode, 'zext ');
    PutLlType(indexArg^.ntype);
    write(ircode, ' ');
    PutOp(idx);
    writeln(ircode, ' to i32');
    idx := wide
  end;

  { Both arrays' bounds may arrive with an actual: a schematic formal's
    `array [1..n]`, and since ISO 7185 6.6.3.7 a conformant array parameter's.
    BoundValue answers a constant where there is one and reads the descriptor
    where there is not, so asking it unconditionally is the whole difference --
    and until BSI's LEV1F06, LEV1F07 and LEV1F51 said otherwise this read
    ut^.lo and ut^.hi, which for either shape are the placeholders 0 and 0.
    That was ADR-0040's gap and not this feature's: `pack` of a schematic
    formal was already wrong, and no program in the corpus packed one. }
  HeapHeader(unpackedArg, uhdr);
  HeapHeader(packedArg, phdr);
  BoundValue(ut, false, uhdr, lo);
  BoundValue(ut, true, uhdr, hi);
  if DynamicExtent(pt) then begin
    { j - i, the packed array's span, when it is not a constant either. }
    BoundValue(pt, false, phdr, plo);
    BoundValue(pt, true, phdr, phi);
    Def(spn);
    write(ircode, 'sub i32 ');
    PutOp(phi);
    write(ircode, ', ');
    PutOp(plo);
    writeln(ircode);
    Def(last);
    write(ircode, 'add i32 ');
    PutOp(idx);
    write(ircode, ', ');
    PutOp(spn);
    writeln(ircode)
  end
  else begin
    span := pt^.hi - pt^.lo;
    Def(last);
    write(ircode, 'add i32 ');
    PutOp(idx);
    writeln(ircode, ', ', span:1)
  end;
  Def(below);
  write(ircode, 'icmp slt i32 ');
  PutOp(idx);
  write(ircode, ', ');
  PutOp(lo);
  writeln(ircode);
  Def(above);
  write(ircode, 'icmp sgt i32 ');
  PutOp(last);
  write(ircode, ', ');
  PutOp(hi);
  writeln(ircode);
  Def(bad);
  write(ircode, 'or i1 ');
  PutOp(below);
  write(ircode, ', ');
  PutOp(above);
  writeln(ircode);
  { The message names the bounds, so where they are not constants it has to be
    built where they are known -- which is the subscript check's own answer,
    and the same helper. }
  if DynamicExtent(ut) then
    EmitTrapIndex(bad, lo, hi, indexArg^.line, indexArg^.col)
  else begin
    MsgStart;
    MsgText('array index out of bounds (             ');
    AppendInt(msgBuf, ut^.lo);
    MsgText('..                                      ');
    AppendInt(msgBuf, ut^.hi);
    Put(')');
    msg := MsgEnd;
    EmitTrapIf(bad, msg, indexArg^.line, indexArg^.col)
  end;

  { k - m, the offset of the first unpacked component. The check above has
    already made the subtraction sound. }
  Def(off);
  write(ircode, 'sub i32 ');
  PutOp(idx);
  write(ircode, ', ');
  PutOp(lo);
  writeln(ircode);
  { An array whose extent is not known until the block is entered has no LLVM
    array type to index, so the address is computed in bytes -- the same
    `(i - lo) * stride` the two-index getelementptr stands for, and the same
    two helpers the subscript path uses. }
  if DynamicExtent(ut) then begin
    DynSize(ut^.elem, uhdr, stride);
    Def(byte);
    write(ircode, 'mul i32 ');
    PutOp(off);
    write(ircode, ', ');
    PutOp(stride);
    writeln(ircode);
    Def(from);
    write(ircode, 'getelementptr inbounds i8, ptr ');
    PutOp(ua);
    write(ircode, ', i32 ');
    PutOp(byte);
    writeln(ircode)
  end
  else begin
    Def(from);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(ut);
    write(ircode, ', ptr ');
    PutOp(ua);
    write(ircode, ', i32 0, i32 ');
    PutOp(off);
    writeln(ircode)
  end;

  { How much moves is the packed array's size, which is itself a run-time
    question when its bounds arrived with an actual. Computed *before* the call
    is written: the emitter is sequential and has no instruction list, so an
    instruction cannot be produced half way through another one's line. }
  if DynamicExtent(pt) then begin
    DynSize(pt, phdr, plen);
    Def(wlen);
    write(ircode, 'zext i32 ');
    PutOp(plen);
    writeln(ircode, ' to i64')
  end;

  align := LlAlign(ut^.elem);
  write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ', align:1, ' ');
  if s^.pcStd = spPack then PutOp(pa) else PutOp(from);
  write(ircode, ', ptr align ', align:1, ' ');
  if s^.pcStd = spPack then PutOp(from) else PutOp(pa);
  if DynamicExtent(pt) then begin
    write(ircode, ', i64 ');
    PutOp(wlen);
    writeln(ircode, ', i1 false)')
  end
  else
    writeln(ircode, ', i64 ', LlSize(pt):1, ', i1 false)')
end;

procedure EmitStdProc(s: nodePtr);
var slot, block, raw, rec, nameRec, nlen, ndata, part, narrow, at_: str;
    chSlot, chan, chVal, chTmp, chMark, chHdr: str;
    disposeValue: boolean;
    status: str;
    domain, idx: typePtr; head, msg, k: integer;
begin
  { 6.7.5.7's halt takes no *variable*, so it is answered before the address of
    a first argument is taken. The runtime closes what is open and stops;
    nothing here knows which blocks were abandoned, and it does not need to --
    the open-file list is the same one ADR-0032's non-local goto walks, for the
    same reason. The optional exit status is the extension ADR-0084 documents;
    omitted, it is the 0 a conforming program always gets. }
  { AP 6.7.5.9's exit, answered before any address is taken because there is
    no argument left by the time CodeGen runs: Sema moved it into the
    assignment hanging off the node, which is emitted here by the code that
    already knows how to store a result of any type.

    The branch names a label the emitter has not written yet. That is what
    textual IR buys and an instruction list would not have: the target is the
    block the epilogue starts with, claimed here on first use and closed by
    EmitExitTarget after the body. Whatever follows in the source is emitted
    into a fresh block, unreachable and valid, exactly as a goto's is. }
  if s^.pcStd = spExit then begin
    if s^.pcExit <> nil then EmitAssign(s^.pcExit);
    EmitLeaveBlock;
    StartBlock(NewBlock)
  end
  { AP 6.7.5.10 and 6.7.5.11. Both are one branch and neither runs anything on
    the way out: leaving a statement-sequence this way does not *complete* it,
    so what it armed waits for the activation to terminate, which is 6.9.3.11's
    NOTE 2 for a goto-statement and the same sentence here (6.7.5.10 NOTE 2).
    The armed statement is executed late rather than not at all, because the
    flag it is armed by is read again in the block's runner.

    Whatever follows in the source is emitted into a fresh block, unreachable
    and valid, exactly as an exit's is. }
  else if (s^.pcStd = spBreak) or (s^.pcStd = spContinue) then begin
    if s^.pcStd = spBreak then
      writeln(ircode, '  br label %L', breakBlock:1)
    else
      writeln(ircode, '  br label %L', contBlock:1);
    StartBlock(NewBlock)
  end
  { AP 6.9.3.13's send. The value is evaluated into storage of this
    activation and the runtime copies it into the channel, so what the reader
    gets is a copy and not a name -- share-nothing, at the one place a value
    crosses between two activations.

    The temporary is an `alloca`, and here that is safe for the reason
    ADR-0102 gives: it is claimed once per *statement* and the statement is
    not a loop. A send inside a loop would claim one per iteration, so the
    storage is a frame slot Sema gave the statement... which it is not, and
    this is the one place the emitter is knowingly at ADR-0102's boundary --
    see the send arm's note in doc/sop.md §7. }
  else if s^.pcStd = spSend then begin
    EmitAddress(s^.pcArgs, chSlot);
    EmitAt(s^.line, s^.col);
    Def(chan);
    write(ircode, 'call ptr @pas_handle_lend(ptr ');
    PutOp(chSlot);
    writeln(ircode, ')');
    EmitAtDone;
    { A value that has no register form yields an *address* (ADR-0017), so the
      runtime copies from it and there is no temporary at all.

      The question is `IsMemory` and not `IsStructured`, which is ADR-0191's
      split met a second time: a `string(n)` is a length beside a buffer and
      travels by address, and it is not structured -- so the arm below tried
      to `store` an aggregate through a pointer EmitExpr had answered with,
      and the module did not assemble. A channel of `string(16)` was
      `Transferable`, admitted by every check in the front end, and unwritable
      (ADR-0302). }
    { ...but a string is not one of those, and that is the second half of what
      ADR-0302 found. A `string(n)` is a length beside a buffer, so what the
      channel holds is `LlSize` bytes and what a *value* of one occupies is
      only as many as it has -- `'ab' + s` lives in the arena and is four
      bytes and two. Copying the element's size out of it reads past what the
      expression produced. And 6.4.6 c)'s padding has to happen somewhere:
      what crosses is the element type's value and not the expression's. So
      the store is an ordinary assignment into a temporary of the element
      type, which is where padding, the capacity check and -- for a text --
      AP 6.4.15.5's normalisation all already live. }
    if IsStringType(s^.pcArgs^.ntype^.elem) or
       IsText(s^.pcArgs^.ntype^.elem) then begin
      Def(chMark);
      writeln(ircode, 'call ptr @llvm.stacksave.p0()');
      Def(chTmp);
      write(ircode, 'alloca ');
      PutLlType(s^.pcArgs^.ntype^.elem);
      writeln(ircode);
      StrClear(chHdr);
      EmitStringStore(chTmp, s^.pcArgs^.ntype^.elem, s^.pcArgs^.next, chHdr);
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_chan_send(ptr ');
      PutOp(chan);
      write(ircode, ', ptr ');
      PutOp(chTmp);
      writeln(ircode, ')');
      EmitAtDone;
      write(ircode, '  call void @llvm.stackrestore.p0(ptr ');
      PutOp(chMark);
      writeln(ircode, ')')
    end
    else if IsMemory(s^.pcArgs^.ntype^.elem) then begin
      EmitAddress(s^.pcArgs^.next, chTmp);
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_chan_send(ptr ');
      PutOp(chan);
      write(ircode, ', ptr ');
      PutOp(chTmp);
      writeln(ircode, ')');
      EmitAtDone
    end
    { A scalar needs somewhere for the runtime to copy from, and the storage
      is claimed and given back around this one statement.

      ADR-0102's rule is that an `alloca` is only safe where the emitter
      reaches it once per activation, and a send inside a loop is exactly
      where it is not -- so the stack pointer is saved and restored, which
      bounds the claim to the statement rather than to the iteration. A frame
      slot would have been the other answer and needs one per send-statement
      *type*, which the frame layout is emitted too early to know; passing the
      value in a register would need the runtime to know its width, and
      taking the low bytes of a word is an assumption about byte order this
      compiler does not make. }
    else begin
      Def(chMark);
      writeln(ircode, 'call ptr @llvm.stacksave.p0()');
      EmitExpr(s^.pcArgs^.next, chVal);
      Def(chTmp);
      write(ircode, 'alloca ');
      PutLlType(s^.pcArgs^.ntype^.elem);
      writeln(ircode);
      write(ircode, '  store ');
      PutLlType(s^.pcArgs^.ntype^.elem);
      write(ircode, ' ');
      PutOp(chVal);
      write(ircode, ', ptr ');
      PutOp(chTmp);
      writeln(ircode);
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_chan_send(ptr ');
      PutOp(chan);
      write(ircode, ', ptr ');
      PutOp(chTmp);
      writeln(ircode, ')');
      EmitAtDone;
      write(ircode, '  call void @llvm.stackrestore.p0(ptr ');
      PutOp(chMark);
      writeln(ircode, ')')
    end
  end
  { AP 6.9.3.14's wait (ADR-0312). `pas_handle_lend` is what makes an empty
    task-variable an error, and it is the same call `send` makes on a channel
    for the same reason: there is no activation to wait for, and answering
    quietly would make `wait` on a variable a program forgot to spawn into
    read as a task that finished. }
  else if s^.pcStd = spWait then begin
    EmitAddress(s^.pcArgs, chSlot);
    EmitAt(s^.line, s^.col);
    Def(chan);
    write(ircode, 'call ptr @pas_handle_lend(ptr ');
    PutOp(chSlot);
    writeln(ircode, ')');
    write(ircode, '  call void @pas_task_wait(ptr ');
    PutOp(chan);
    writeln(ircode, ')');
    EmitAtDone
  end
  else if s^.pcStd = spHalt then begin
    { The operand is computed first: the emitter is sequential, so anything
      EmitExpr writes has to come out before the call line is begun. }
    if s^.pcArgs = nil then begin
      StrClear(status);
      StrAppend(status, '0')
    end
    else EmitExpr(s^.pcArgs, status);
    write(ircode, '  call void @pas_halt(i32 ');
    PutOp(status);
    writeln(ircode, ')')
  end
  { 6.6.5.4's transfer procedures, answered before the first argument's
    address is taken because *which* argument is the array differs between the
    two and neither is simply "the file" (ADR-0067). }
  else if (s^.pcStd = spPack) or (s^.pcStd = spUnpack) then
    EmitTransfer(s)
  else begin
  { 6.6.5.3's `dispose(q)` removes "the identifying-value denoted by the
    expression q", so there need be no address to take -- `dispose(f(p))` is a
    conforming statement (the suite's CONF129). Sema decided this: the question
    asked here is the structural one it already asked, and the answer decides
    only whether there is a slot, not what anything means. }
  disposeValue := (s^.pcStd = spDispose) and not IsDesignator(s^.pcArgs);
  if disposeValue then
    EmitExpr(s^.pcArgs, block)
  else
    EmitAddress(s^.pcArgs, slot);
  case s^.pcStd of
    { 6.7.5.6's bind(f, b). The binding is implementation-defined and here it
      is a file name, so what crosses to the runtime is b.name as the pointer
      and length every string value is -- b.bound is ignored, which NOTE 3 says
      outright. }
    spBind: begin
      EmitAddress(s^.pcArgs^.next, rec);
      Def(nameRec);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype);
      write(ircode, ', ptr ');
      PutOp(rec);
      writeln(ircode, ', i32 0, i32 0');
      Def(nlen);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype^.fields^.ftype);
      write(ircode, ', ptr ');
      PutOp(nameRec);
      writeln(ircode, ', i32 0, i32 0');
      Def(raw);
      write(ircode, 'load i32, ptr ');
      PutOp(nlen);
      writeln(ircode);
      Def(ndata);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype^.fields^.ftype);
      write(ircode, ', ptr ');
      PutOp(nameRec);
      writeln(ircode, ', i32 0, i32 1');
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_bind(ptr ');
      PutOp(slot);
      write(ircode, ', ptr ');
      PutOp(ndata);
      write(ircode, ', i32 ');
      PutOp(raw);
      writeln(ircode, ')');
      EmitAtDone
    end;
    spUnbind: begin
      write(ircode, '  call void @pas_unbind(ptr ');
      PutOp(slot);
      writeln(ircode, ')')
    end;
    spReset, spRewrite, spGet, spPut, spUpdate, spExtend: begin
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_');
      case s^.pcStd of
        spReset:   write(ircode, 'reset');
        spRewrite: write(ircode, 'rewrite');
        spGet:     write(ircode, 'get');
        spPut:     write(ircode, 'put');
        spUpdate:  write(ircode, 'update');
        spExtend:  write(ircode, 'extend');
        spNone, spNew, spDispose, spSeekRead, spSeekWrite, spSeekUpdate,
        spBind, spUnbind, spGetTimeStamp:
          write(ircode, 'get')
      end;
      write(ircode, '(ptr ');
      PutOp(slot);
      writeln(ircode, ')');
      EmitAtDone
    end;
    { 6.7.5.2's three seeks. The position reaches the runtime already relative
      to the index-type's smallest value, so `SeekRead(f, 'c')` on a
      `file ['a'..'z'] of T` arrives as 2 -- the same division of labour an
      array subscript has, where the lower bound is folded into the offset and
      the runtime never sees an ordinal. }
    spSeekRead, spSeekWrite, spSeekUpdate: begin
      EmitExpr(s^.pcArgs^.next, raw);
      WidenOrdinal(raw, s^.pcArgs^.next^.ntype);
      idx := s^.pcArgs^.ntype^.indexType;
      if OrdinalLo(idx) <> 0 then begin
        Def(block);
        write(ircode, 'sub i32 ');
        PutOp(raw);
        writeln(ircode, ', ', OrdinalLo(idx):1);
        raw := block
      end;
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_');
      case s^.pcStd of
        spSeekRead:   write(ircode, 'seekread');
        spSeekWrite:  write(ircode, 'seekwrite');
        spSeekUpdate: write(ircode, 'seekupdate');
        spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut, spUpdate,
        spExtend, spBind, spUnbind, spGetTimeStamp:
          write(ircode, 'seekread')
      end;
      write(ircode, '(ptr ');
      PutOp(slot);
      write(ircode, ', i32 ');
      PutOp(raw);
      writeln(ircode, ')');
      EmitAtDone
    end;
    spNew: begin
      domain := s^.pcArgs^.ntype^.elem;
      { AP 6.4.14.3: `new` is a release point for an owned pointer, the way
        6.4.12.2's assignment is one for a handle. Without this a second `new`
        over the same variable abandons the first, which is the very leak the
        type exists to close -- and it was one: 3000 iterations of `new(b)`
        with a stream in the domain reported "fopen answered empty at
        iteration 62" under a 64-descriptor limit. The slot holds `nil` before
        the first `new`, because WalkFiles set it up that way, so this is safe
        on the first pass through as well. }
      if IsOwnedPointer(s^.pcArgs^.ntype) then begin
        Def(block);
        write(ircode, 'load ptr, ptr ');
        PutOp(slot);
        writeln(ircode);
        write(ircode, '  call void @ownrel', OwnRelId(domain):1, '(ptr ');
        PutOp(block);
        writeln(ircode, ')')
      end;
      if domain^.heapTuple then EmitNewTuple(s, domain, slot)
      else begin
      { ISO 7185 6.6.5.3: with tag values, only the selected variants have to
        fit. Without them the whole record does. }
      EmitAt(s^.line, s^.col);
      Def(block);
      if s^.pcSelect = nil then
        writeln(ircode, 'call ptr @pas_new(i64 ',
                LlSize(s^.pcArgs^.ntype^.elem):1, ')')
      else
        writeln(ircode, 'call ptr @pas_new(i64 ',
                SelectedSize(s^.pcArgs^.ntype^.elem, nil, s^.pcSelect):1, ')');
      EmitAtDone;
      write(ircode, '  store ptr ');
      PutOp(block);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode);
      { 6.7.5.3's selectors, which ISO 7185 does not have. }
      if s^.pcSelect <> nil then
        EmitNewSelectors(domain, block, s^.pcSelect, s^.pcTagVals);
      { A created variable holding a file needs the same preparation a declared
        one gets: pas_file_init per file, because 6.4.4 does not stop a
        domain-type from containing one. dispose closes them below, which is
        where the storage stops existing. }
      if HoldsFile(domain) then begin
        MsgStart;
        MsgText('heap                                    ');
        msg := MsgEnd;
        WalkFiles(block, domain, true, 0, 0, msg, s^.line, s^.col)
      end
      end
    end;
    spDispose: begin
      domain := nil;
      if s^.pcArgs^.ntype <> nil then domain := s^.pcArgs^.ntype^.elem;
      { The value is already in `block` when there was no slot to load it
        from. }
      if not disposeValue then begin
        Def(block);
        write(ircode, 'load ptr, ptr ');
        PutOp(slot);
        writeln(ircode)
      end;
      { ISO 7185 6.6.5.3 (D.23): "for dispose, it is an error if the parameter
        of a pointer-type has a nil-value". The check used to be made only for
        a schema domain, where stepping back over a header turns it into a free
        of an address that was never allocated; for every other domain it was a
        harmless error, freeing nil doing nothing. Harmless is not the test the
        standard sets, and it is the same comparison either way -- the *reason*
        to report differed, never the rule. }
      Def(raw);
      write(ircode, 'icmp eq ptr ');
      PutOp(block);
      writeln(ircode, ', null');
      MsgStart;
      MsgText('dispose of nil                          ');
      msg := MsgEnd;
      EmitTrapIf(raw, msg, s^.pcArgs^.line, s^.pcArgs^.col);
      if HoldsFile(domain) then
        WalkFiles(block, domain, false, 0, 0, 0, 0, 0);
      { What was allocated is the header and the variable together, so what is
        given back has to be the block rather than the variable. }
      head := HeaderSize(s^.pcArgs^.ntype^.elem);
      if head <> 0 then begin
        raw := block;
        Def(block);
        write(ircode, 'getelementptr i8, ptr ');
        PutOp(raw);
        writeln(ircode, ', i32 ', -head:1)
      end;
      write(ircode, '  call void @pas_dispose(ptr ');
      PutOp(block);
      writeln(ircode, ')');
      { ISO 7185 6.6.5.3 leaves the pointer undefined afterwards. Setting it to
        nil makes the next dereference trap instead of reading freed storage --
        stricter than the standard requires, and cheap. An expression that is
        not a variable has nowhere to put it, and nothing that could read it
        back, so there is nothing to leave undefined. }
      if not disposeValue then begin
        write(ircode, '  store ptr null, ptr ');
        PutOp(slot);
        writeln(ircode)
      end
    end;
    { 6.7.5.8's GetTimeStamp(t). The clock is sampled once and then read field
      by field, which is the shape that keeps the record's *layout* out of the
      runtime entirely: what crosses the boundary is eight numbers, and the
      stores are made here.

      The alternative -- handing the runtime eight field addresses, or a
      pointer to the whole record -- was rejected for ADR-0030's reason. A
      Boolean field is an i1, and how an i1 sits in memory is precisely the
      sort of fact neither backend may depend on.

      The first two fields are the Booleans and the other six are integers, so
      the only conversion is the trunc those two need. }
    { 6.9.5's page. The effect on the file is implementation-defined, so it is
      the runtime's to choose; what the standard fixes is the implicit writeln
      when the current line is not empty, and that needs the file's own state
      -- which is the runtime's too. Sema has already supplied output when none
      was written. }
    spPage: begin
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_page(ptr ');
      PutOp(slot);
      writeln(ircode, ')');
      EmitAtDone
    end;
    spGetTimeStamp: begin
      writeln(ircode, '  call void @pas_gettimestamp()');
      for k := 0 to 7 do begin
        EmitAt(s^.line, s^.col);
        Def(part);
        writeln(ircode, 'call i32 @pas_timestamp_field(i32 ', k:1, ')');
        EmitAtDone;
        Def(at_);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(s^.pcArgs^.ntype);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 ', k:1);
        if k < 2 then begin
          Def(narrow);
          write(ircode, 'trunc i32 ');
          PutOp(part);
          writeln(ircode, ' to i1');
          write(ircode, '  store i1 ');
          PutOp(narrow)
        end
        else begin
          write(ircode, '  store i32 ');
          PutOp(part)
        end;
        write(ircode, ', ptr ');
        PutOp(at_);
        writeln(ircode)
      end
    end;
    spNone, spHalt, spExit, spBreak, spContinue:
      { spHalt, spExit, spBreak and spContinue were all answered above; spNone
        is not a standard one }
  end
  end
end;

procedure EmitIf(s: nodePtr);
var cond: str; thenB, elseB, endB: integer;
begin
  EmitExpr(s^.ifCond, cond);
  thenB := NewBlock;
  { An if with no else-part has nothing on its false side to count, which is
    half of what a statement counter cannot see -- so --coverage gives that
    direction a block whether the program wrote one or not (ADR-0274).
    EmitStmt answers nil with nothing, so the block holds only the counter. }
  if (s^.ifElse <> nil) or covOpt then elseB := NewBlock else elseB := 0;
  endB := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  write(ircode, ', label %L', thenB:1, ', label %L');
  if elseB <> 0 then writeln(ircode, elseB:1) else writeln(ircode, endB:1);

  StartBlock(thenB);
  CovBranch(s, 1);
  EmitStmt(s^.ifThen);
  writeln(ircode, '  br label %L', endB:1);

  if elseB <> 0 then begin
    StartBlock(elseB);
    CovBranch(s, 0);
    EmitStmt(s^.ifElse);
    writeln(ircode, '  br label %L', endB:1)
  end;

  StartBlock(endB)
end;

procedure EmitWhile(s: nodePtr);
var cond: str;
    condB, bodyB, endB, exitB, mark, savedBrk, savedCnt: integer;
begin
  condB := NewBlock;
  bodyB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);
  StartBlock(condB);
  { A loop's condition is the one expression a statement evaluates more than
    once, so the release EmitStmt writes after the whole while-statement comes
    too late for it -- an iteration's worth of arena would be kept for every
    iteration (ADR-0111). It goes here instead, after the condition has been
    reduced to an i1 and therefore needs nothing the arena holds. }
  mark := strTemps;
  EmitExpr(s^.whCond, cond);
  if strTemps > mark then ReleaseStrTemps;
  { The exit block is where AP 6.7.5.10's break lands as well, so the false
    direction cannot be counted there: a loop only ever left by a break would
    report a condition that never became false (ADR-0274). }
  if covOpt then exitB := NewBlock else exitB := endB;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', exitB:1);

  StartBlock(bodyB);
  CovBranch(s, 1);
  savedBrk := breakBlock;
  savedCnt := contBlock;
  breakBlock := endB;
  contBlock := condB;
  EmitStmt(s^.whBody);
  breakBlock := savedBrk;
  contBlock := savedCnt;
  writeln(ircode, '  br label %L', condB:1);

  if covOpt then begin
    StartBlock(exitB);
    CovBranch(s, 0);
    writeln(ircode, '  br label %L', endB:1)
  end;

  StartBlock(endB)
end;

procedure EmitRepeat(s: nodePtr);
var cond: str;
    bodyB, contB, endB, doneB, againB, mark, savedBrk, savedCnt: integer;
    sub: nodePtr;
begin
  bodyB := NewBlock;
  { The condition is a block of its own rather than the tail of the body's,
    because AP 6.7.5.11's continue enters it: 6.9.3.7 tests after the body, so
    completing an iteration early means reaching the test and not the head. }
  contB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', bodyB:1);
  StartBlock(bodyB);
  savedBrk := breakBlock;
  savedCnt := contBlock;
  breakBlock := endB;
  contBlock := contB;
  sub := s^.rpBody;
  while sub <> nil do begin
    EmitStmt(sub);
    sub := sub^.next
  end;
  { 6.9.3.7's body is a statement-sequence, so it is completed once per
    iteration and what it armed runs there (AP 6.9.3.11). }
  EndSequence(s^.rpBody);
  breakBlock := savedBrk;
  contBlock := savedCnt;
  writeln(ircode, '  br label %L', contB:1);
  StartBlock(contB);
  { repeat runs until the condition becomes true }
  mark := strTemps;
  EmitExpr(s^.rpCond, cond);
  { Re-evaluated per iteration, exactly as a while's condition is, and released
    for the same reason (ADR-0111). The body's own statements do not cover it:
    a body that concatenates nothing writes no release at all. }
  if strTemps > mark then ReleaseStrTemps;
  { Neither destination may carry the counter as it stands: the exit block is
    also where a break lands, and the body block is entered once before the
    first test, so a repeat that runs a single iteration would report both
    directions taken (ADR-0274). }
  if covOpt then begin doneB := NewBlock; againB := NewBlock end
  else begin doneB := endB; againB := bodyB end;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', doneB:1, ', label %L', againB:1);
  if covOpt then begin
    StartBlock(doneB);
    CovBranch(s, 1);
    writeln(ircode, '  br label %L', endB:1);
    StartBlock(againB);
    CovBranch(s, 0);
    writeln(ircode, '  br label %L', bodyB:1)
  end;
  StartBlock(endB)
end;

{ A labelled statement is its own basic block, entered by falling into it as
  well as by jumping to it -- so the preceding code branches there rather than
  running on, which is what makes the label a join point rather than a second
  entry to the same block. }
procedure EmitLabeled(s: nodePtr);
var b: integer;
begin
  if s^.lbId < 0 then
    EmitStmt(s^.lbStmt)   { Sema reported it; emit the body anyway }
  else begin
    b := LabelBlock(s^.lbId);
    writeln(ircode, '  br label %L', b:1);
    StartBlock(b);
    EmitStmt(s^.lbStmt)
  end
end;

{ Anything written after a goto is unreachable, but it is still *code*: a
  statement may follow it in the same sequence, and LLVM requires it to live in
  a block of its own rather than after a terminator. }
procedure EmitGoto(s: nodePtr);
var frame, rec: str;
begin
  if s^.gtId >= 0 then begin
    if s^.gtNonLocal then begin
      { Out of this block altogether. The target's activation is the one on
        this procedure's static chain, which for a recursive enclosing
        procedure is the invocation this one was called from -- the same rule
        every other access to an enclosing frame follows (ADR-0016). The
        runtime closes the abandoned blocks' files before cutting the stack
        back. The label arrives as its id plus one, because a longjmp with
        zero would come back looking like the ordinary entry. }
      FrameOf(s^.gtOwner, frame);
      JumpRecord(s^.gtOwner, frame, rec);
      EmitAt(s^.line, s^.col);
      write(ircode, '  call void @pas_jump_go(ptr ');
      PutOp(rec);
      writeln(ircode, ', i32 ', s^.gtId + 1:1, ')');
      EmitAtDone;
      writeln(ircode, '  unreachable')
    end
    else
      writeln(ircode, '  br label %L', LabelBlock(s^.gtId):1);
    StartBlock(NewBlock)
  end
end;

{ 6.9.3.9.3's set-member-iteration. A set is one 256-bit word with a bit per
  possible member (ADR-0028), so "for each member" is a walk over the base
  type's ordinals testing one bit -- the same lshr/and the `in` operator emits,
  with the member as the loop's own counter rather than as an expression.

  The order is ascending, and the standard leaves it open: 6.9.3.9.3 makes it
  "implementation-dependent", so this is a documented choice rather than a
  requirement. Ascending is what a walk over the bits gives. }
{ AP 6.4.15.9's iteration. A loop of its own rather than an arm inside
  EmitForIn, because nothing is shared: a set walks its base type's ordinals
  and tests a bit, and this walks byte offsets and asks the runtime where the
  next element ends.

  What *is* shared is the frame slot Sema gave the statement. It holds a byte
  offset here rather than an ordinal, and it is a frame slot for the same
  reason: an alloca is emitted wherever the sequential emitter has reached, so
  a nested one would be claimed per iteration of the outer loop and exhaust
  the stack at -O0 (ADR-0102). }
procedure EmitForInText(s: nodePtr);
var slot, data, len, counter, at_, nextOp, elem, test, cap, hdr: str;
    t: typePtr; condB, bodyB, endB, savedBrk, savedCnt: integer;
begin
  EmitAddress(s^.frVar, slot);
  t := s^.frVar^.ntype;
  { "shall be evaluated prior to the first execution" -- once, before the
    loop, and the pair is a pair of SSA values defined here, so it dominates
    every block below. Where the operand took arena storage (a concatenation)
    that storage is this statement's and outlives the loop, which is why the
    body may not release the arena. }
  EmitString(s^.frSet, data, len);
  StrClear(hdr);
  StringCapacity(t, hdr, cap);

  FrameSlot(s^.frCounter, counter);
  write(ircode, '  store i32 0, ptr ');
  PutOp(counter);
  writeln(ircode);

  condB := NewBlock;
  bodyB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(condB);
  Def(at_);
  write(ircode, 'load i32, ptr ');
  PutOp(counter);
  writeln(ircode);
  Def(test);
  write(ircode, 'icmp slt i32 ');
  PutOp(at_);
  write(ircode, ', ');
  PutOp(len);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(test);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', endB:1);

  StartBlock(bodyB);
  { Where this element ends. The runtime answers with a byte offset, which is
    the only unit a boundary has -- an element has no ordinal to count in. }
  Def(nextOp);
  write(ircode, 'call i32 @pas_text_boundary(ptr ');
  PutOp(data);
  write(ircode, ', i32 ');
  PutOp(len);
  write(ircode, ', i32 ');
  PutOp(at_);
  writeln(ircode, ')');
  Def(elem);
  write(ircode, 'getelementptr inbounds i8, ptr ');
  PutOp(data);
  write(ircode, ', i32 ');
  PutOp(at_);
  writeln(ircode);
  Def(test);
  write(ircode, 'sub i32 ');
  PutOp(nextOp);
  write(ircode, ', ');
  PutOp(at_);
  writeln(ircode);
  { pas_text_take and not pas_text_store: the element is already in normal
    form and this is inside a loop, so it must take nothing from the arena. }
  EmitAt(s^.line, s^.col);
  write(ircode, '  call void @pas_text_take(ptr ');
  PutOp(slot);
  write(ircode, ', i32 ');
  PutOp(cap);
  write(ircode, ', ptr ');
  PutOp(elem);
  write(ircode, ', i32 ');
  PutOp(test);
  writeln(ircode, ')');
  EmitAtDone;
  write(ircode, '  store i32 ');
  PutOp(nextOp);
  write(ircode, ', ptr ');
  PutOp(counter);
  writeln(ircode);
  savedBrk := breakBlock;
  savedCnt := contBlock;
  breakBlock := endB;
  { The counter is advanced *before* the body, so the head is what completes
    an iteration here and there is no step block to enter. }
  contBlock := condB;
  EmitStmt(s^.frBody);
  breakBlock := savedBrk;
  contBlock := savedCnt;
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(endB)
end;

procedure EmitForIn(s: nodePtr);
var slot, set_, counter, i, hiOp, oneOp, zeroOp, test, widened: str;
    shifted, bit, hit, now, next: str;
    t, base: typePtr; condB, testB, bodyB, stepB, endB, lo, hi: integer;
    savedBrk, savedCnt: integer;
begin
  EmitAddress(s^.frVar, slot);
  t := s^.frVar^.ntype;
  { "The set-expression shall be evaluated prior to the first execution, if
    any, of the statement" -- and a set is a value (ADR-0028), so evaluating it
    here *is* evaluating it once. Nothing in the body can reach the storage it
    came from. }
  EmitExpr(s^.frSet, set_);

  { The bits worth testing are the base type's own. An empty-set constructor
    has no base type to ask, and no members either, so the control variable's
    range serves and the loop finds nothing. }
  if (s^.frSet^.ntype <> nil) and (s^.frSet^.ntype^.elem <> nil) then
    base := s^.frSet^.ntype^.elem
  else
    base := t;
  { ...and clamped to the bits a set actually has. A *constructor* takes its
    base type from its members, so `[1, 2]` is a set of integer -- a type
    ADR-0028 refuses to declare but infers here -- and its ordinal range is the
    whole of `integer`. There is no bit outside 0..setLimit to find a member
    in. }
  lo := OrdinalLo(base);
  if lo < 0 then lo := 0;
  hi := OrdinalHi(base);
  if hi > setLimit then hi := setLimit;

  { The counter lives in a frame slot Sema gave this statement, not in an
    alloca. It has to survive from one iteration to the next, so it needs
    storage -- but an alloca is emitted wherever the sequential emitter has
    reached (ADR-0025), so a `for ... in` inside another loop would claim a
    fresh one on every iteration of the outer loop and, at -O0 where nothing
    promotes it away, exhaust the stack. A frame slot is claimed once per
    activation, which is the same reason ADR-0043 gives for not putting `new`'s
    scratch storage on the stack. }
  FrameSlot(s^.frCounter, counter);
  OpInt(lo, i);
  write(ircode, '  store i32 ');
  PutOp(i);
  write(ircode, ', ptr ');
  PutOp(counter);
  writeln(ircode);

  condB := NewBlock;
  testB := NewBlock;
  bodyB := NewBlock;
  stepB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);

  { `hi` is at most setLimit (ADR-0028), so the counter is an i32 that cannot
    overflow before the test fails -- which is why this needs none of the
    sequence form's stop-before-stepping care. }
  StartBlock(condB);
  Def(i);
  write(ircode, 'load i32, ptr ');
  PutOp(counter);
  writeln(ircode);
  OpInt(hi, hiOp);
  Def(test);
  write(ircode, 'icmp sle i32 ');
  PutOp(i);
  write(ircode, ', ');
  PutOp(hiOp);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(test);
  writeln(ircode, ', label %L', testB:1, ', label %L', endB:1);

  StartBlock(testB);
  Def(widened);
  write(ircode, 'zext i32 ');
  PutOp(i);
  writeln(ircode, ' to i', setBits:1);
  Def(shifted);
  write(ircode, 'lshr i', setBits:1, ' ');
  PutOp(set_);
  write(ircode, ', ');
  PutOp(widened);
  writeln(ircode);
  OpInt(1, oneOp);
  Def(bit);
  write(ircode, 'and i', setBits:1, ' ');
  PutOp(shifted);
  write(ircode, ', ');
  PutOp(oneOp);
  writeln(ircode);
  OpInt(0, zeroOp);
  Def(hit);
  write(ircode, 'icmp ne i', setBits:1, ' ');
  PutOp(bit);
  write(ircode, ', ');
  PutOp(zeroOp);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(hit);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', stepB:1);

  { D.96: "it is an error if any value that is a member of the value of the
    set-expression ... is assignment-compatibility-erroneous with respect to
    the type possessed by the control-variable". 6.9.3.9.3 makes the members
    assignment-compatible rather than the set, so a control variable narrower
    than the base type is legal and this is where the rule bites -- through the
    check every other store makes. }
  StartBlock(bodyB);
  { The counter is an i32 and the control variable is its own width -- i8 for a
    char, i1 for a boolean, i32 for an integer or an enumeration. LLVM has no
    same-width cast, so the equal case emits nothing at all. }
  if LlSize(t) >= 4 then
    now := i
  else begin
    Def(now);
    write(ircode, 'trunc i32 ');
    PutOp(i);
    write(ircode, ' to ');
    PutLlType(t);
    writeln(ircode)
  end;
  CheckedForSubrange(now, t, s^.line, s^.col);
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(now);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  savedBrk := breakBlock;
  savedCnt := contBlock;
  breakBlock := endB;
  { The element test has already been passed for this iteration, so completing
    it early means stepping the counter and not re-entering the head. }
  contBlock := stepB;
  EmitStmt(s^.frBody);
  breakBlock := savedBrk;
  contBlock := savedCnt;
  writeln(ircode, '  br label %L', stepB:1);

  StartBlock(stepB);
  Def(now);
  write(ircode, 'load i32, ptr ');
  PutOp(counter);
  writeln(ircode);
  OpInt(1, oneOp);
  Def(next);
  write(ircode, 'add i32 ');
  PutOp(now);
  write(ircode, ', ');
  PutOp(oneOp);
  writeln(ircode);
  write(ircode, '  store i32 ');
  PutOp(next);
  write(ircode, ', ptr ');
  PutOp(counter);
  writeln(ircode);
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(endB)
end;

procedure EmitFor(s: nodePtr);
var slot, from, toV, cur, test, now, same, next: str;
    willRun: str;
    t: typePtr; condB, bodyB, stepB, endB, checkB, skipB: integer;
    contB, savedBrk, savedCnt: integer;
    unsignedOrdinal: boolean;
begin
  if s^.frSet <> nil then
    if IsText(s^.frSet^.ntype) then EmitForInText(s) else EmitForIn(s)
  else begin
  EmitAddress(s^.frVar, slot);
  t := s^.frVar^.ntype;

  { Both bounds are checked against the control variable's type, and nothing
    between them needs checking: the loop never leaves [from, to].

    But 6.8.3.9 checks them *conditionally*: the bounds "shall be
    assignment-compatible with the type possessed by the control-variable if
    the statement of the for-statement is executed". So the check belongs after
    the entry test and not before it -- `for i := maxint to maxint - 1 do` over
    an `i : 0..10` is a legal program with an empty loop, and checking eagerly
    stops it. The suite's CONF181 is that program. }
  EmitExpr(s^.frFrom, from);
  ConvertFor(from, s^.frFrom^.ntype, t);
  EmitExpr(s^.frTo, toV);
  ConvertFor(toV, s^.frTo^.ntype, t);

  if NeedsSubrangeCheck(t) then begin
    { The entry test, written once here and again in condB below. It cannot be
      shared: this one compares two registers before the loop exists, and that
      one compares what the slot holds against the stored limit. }
    unsignedOrdinal := not IsInteger(t);
    Def(willRun);
    if s^.frDownto then
      if unsignedOrdinal then write(ircode, 'icmp uge ')
      else write(ircode, 'icmp sge ')
    else
      if unsignedOrdinal then write(ircode, 'icmp ule ')
      else write(ircode, 'icmp sle ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(from);
    write(ircode, ', ');
    PutOp(toV);
    writeln(ircode);

    checkB := NewBlock;
    skipB := NewBlock;
    write(ircode, '  br i1 ');
    PutOp(willRun);
    writeln(ircode, ', label %L', checkB:1, ', label %L', skipB:1);

    StartBlock(checkB);
    CheckedForSubrange(from, t, s^.frFrom^.line, s^.frFrom^.col);
    CheckedForSubrange(toV, t, s^.frTo^.line, s^.frTo^.col);
    writeln(ircode, '  br label %L', skipB:1);

    StartBlock(skipB)
  end;

  { The limit is evaluated exactly once, as ISO 7185 6.8.3.9 requires, and
    `toV` *is* that evaluation -- so it needs no storage of its own. It is
    defined before any of the loop's blocks exist, which is what makes it
    dominate every use inside them however the to-expression was emitted.

    It used to be stored into an alloca and loaded back twice per iteration.
    That alloca is written where the emitter has reached rather than in the
    entry block -- the emitter is sequential and cannot go back (ADR-0025) --
    so a `for` inside any loop claimed a fresh one on every iteration of the
    outer one, and at -O0, where nothing promotes it away, a long-running
    nested loop exhausted the stack. ADR-0043 names that hazard for `new` and
    avoids it there; this is the same hazard, and the answer here is that there
    was never anything to store. }
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(from);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);

  condB := NewBlock;
  bodyB := NewBlock;
  stepB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(condB);
  Def(cur);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  { Integer is the only ordinal with negative values; char, boolean and
    enumerations all order as unsigned. }
  unsignedOrdinal := not IsInteger(t);
  Def(test);
  if s^.frDownto then
    if unsignedOrdinal then write(ircode, 'icmp uge ')
    else write(ircode, 'icmp sge ')
  else
    if unsignedOrdinal then write(ircode, 'icmp ule ')
    else write(ircode, 'icmp sle ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(cur);
  write(ircode, ', ');
  PutOp(toV);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(test);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', endB:1);

  StartBlock(bodyB);
  savedBrk := breakBlock;
  savedCnt := contBlock;
  breakBlock := endB;
  { Not condB. 6.9.3.9 tests the control-variable against the limit *after* the
    body and steps only if it has not been reached, so what AP 6.7.5.11's
    continue enters is that test -- entering the head instead would run the
    body again with the same value, forever. }
  contB := NewBlock;
  contBlock := contB;
  EmitStmt(s^.frBody);
  breakBlock := savedBrk;
  contBlock := savedCnt;
  writeln(ircode, '  br label %L', contB:1);
  StartBlock(contB);
  { Stop before stepping past the limit so the last iteration cannot overflow.
    verify/ carries the theorem that says the step is therefore unchecked. }
  Def(now);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  Def(same);
  write(ircode, 'icmp eq ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(now);
  write(ircode, ', ');
  PutOp(toV);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(same);
  writeln(ircode, ', label %L', endB:1, ', label %L', stepB:1);

  StartBlock(stepB);
  Def(next);
  if s^.frDownto then write(ircode, 'sub ') else write(ircode, 'add ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(now);
  writeln(ircode, ', 1');
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(next);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(endB)
  end
end;

{ The record is designated once and its address kept for the body, so a
  subscript in the designator is evaluated a single time (6.8.3.10) and cannot
  see a change the body makes to the subscript's variable. }
procedure EmitWith(s: nodePtr);
var addr, slot, field, hdr, half, raw, val: str; d: symListPtr; k: integer;
begin
  EmitAddress(s^.wtRecord, addr);
  FrameSlot(s^.wtBinding, slot);
  { The binding of a `with` over a heap variable produced from a schema is a
    descriptor rather than a bare pointer (ADR-0071): its discriminants have no
    other home, since the header they live in front of is reached from the
    variable's address and a bare discriminant name has no designator to walk
    down. The element is evaluated once -- this reads the tuple out of the
    address just computed, never out of a second evaluation. }
  if s^.wtBinding^.descSchema = nil then begin
    write(ircode, '  store ptr ');
    PutOp(addr);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode)
  end
  else begin
    Def(field);
    write(ircode, 'getelementptr inbounds ');
    PutDescType(s^.wtBinding);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    write(ircode, '  store ptr ');
    PutOp(addr);
    write(ircode, ', ptr ');
    PutOp(field);
    writeln(ircode);
    HeaderOf(s^.wtRecord^.ntype, addr, hdr);
    d := s^.wtBinding^.discSyms;
    k := 0;
    while d <> nil do begin
      Def(half);
      write(ircode, 'getelementptr i32, ptr ');
      PutOp(hdr);
      writeln(ircode, ', i32 ', k:1);
      Def(raw);
      write(ircode, 'load i32, ptr ');
      PutOp(half);
      writeln(ircode);
      { The header holds one i32 per discriminant whatever its own type. }
      if IsChar(d^.sym^.stype) or IsBoolean(d^.sym^.stype) then begin
        Def(val);
        write(ircode, 'trunc i32 ');
        PutOp(raw);
        write(ircode, ' to ');
        PutLlType(d^.sym^.stype);
        writeln(ircode)
      end
      else
        val := raw;
      Def(field);
      write(ircode, 'getelementptr inbounds ');
      PutDescType(s^.wtBinding);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode, ', i32 0, i32 ', 1 + k:1);
      write(ircode, '  store ');
      PutLlType(d^.sym^.stype);
      write(ircode, ' ');
      PutOp(val);
      write(ircode, ', ptr ');
      PutOp(field);
      writeln(ircode);
      k := k + 1;
      d := d^.next
    end
  end;
  EmitStmt(s^.wtBody)
end;

{ ISO 7185 6.8.3.5 has no `else` arm, so the default is an error rather than a
  way out: a selector matching no label stops the program. That maps onto a
  switch exactly, and the jump table survives optimisation. }
{ AP 6.9.3.11. The three routines below are the whole of the lowering, and
  the shape they share is that a defer-statement's *statement* is emitted in
  two places: where the sequence it stands in is completed, and inside the
  block's runner. Nothing else in this emitter emits one statement twice,
  which is why Sema refuses a label and a goto inside a deferred statement --
  a label would be two labels with one number.

  A `defer` is armed by storing 1 in its flag, and an armed statement clears
  its own flag before it runs. So the two emissions cannot both fire, the
  runner cannot run a statement a sequence already ran, and a defer-statement
  reached twice without its sequence completing -- a backward `goto` over one
  -- arms what is already armed and runs it once. }

{ The defer-statement a statement *is*, looking through the labels a program
  may have put in front of it. }
function DeferStmtOf(s: nodePtr): nodePtr;
begin
  while (s <> nil) and (s^.kind = nkLabeled) do s := s^.lbStmt;
  if s = nil then DeferStmtOf := nil
  else if s^.kind = nkDefer then DeferStmtOf := s
  else DeferStmtOf := nil
end;

{ `if armed then begin disarm; statement end`. }
procedure EmitDeferRun(d: nodePtr);
var frame, flag, val, cond: str; runB, contB: integer;
begin
  FrameAt(irProc^.level, frame);
  DeferFlag(irProc, frame, d^.dfIndex, flag);
  Def(val);
  write(ircode, 'load i8, ptr ');
  PutOp(flag);
  writeln(ircode);
  Def(cond);
  write(ircode, 'icmp ne i8 ');
  PutOp(val);
  writeln(ircode, ', 0');
  runB := NewBlock;
  contB := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', runB:1, ', label %L', contB:1);
  StartBlock(runB);
  { Disarmed before it runs, not after: the statement may itself leave the
    block -- by halting -- and what must not happen is running it twice. }
  FrameAt(irProc^.level, frame);
  DeferFlag(irProc, frame, d^.dfIndex, flag);
  write(ircode, '  store i8 0, ptr ');
  PutOp(flag);
  writeln(ircode);
  EmitStmt(d^.dfStmt);
  writeln(ircode, '  br label %L', contB:1);
  StartBlock(contB)
end;

{ Reverse source order, from a list that is linked forwards: recursion is
  what reverses it, and the caller has already established that there is at
  least one defer-statement here -- so no sequence pays for this walk, and
  the depth is the length of a sequence that defers rather than of any
  sequence at all. }
procedure RunDefersReversed(sub: nodePtr);
var d: nodePtr;
begin
  if sub <> nil then begin
    RunDefersReversed(sub^.next);
    d := DeferStmtOf(sub);
    if d <> nil then EmitDeferRun(d)
  end
end;

{ AP 6.9.3.11: a statement-sequence has been completed, so what it armed runs.
  Called for each of the three constructs that hold one -- a compound
  statement, a repeat-statement's body, and 6.9.3.5's case-statement-completer
  -- and for nothing else, a branch of an `if` and the body of a `while` being
  single statements. }
procedure EndSequence;
var sub: nodePtr; any: boolean;
begin
  any := false;
  sub := list;
  while sub <> nil do begin
    if DeferStmtOf(sub) <> nil then any := true;
    sub := sub^.next
  end;
  if any then RunDefersReversed(list)
end;

procedure EmitCase(s: nodePtr);
var sel, wide, ge, le, both: str; arm: nodePtr; n: rangePtr;
    first, k, count, armB, defaultB, endB, nextB, msg: integer;
begin
  EmitExpr(s^.csSelector, sel);
  { The switch wants a single integer type; a char or boolean selector is
    widened, and its labels with it. }
  if IsChar(s^.csSelector^.ntype) or IsBoolean(s^.csSelector^.ntype) then begin
    Def(wide);
    write(ircode, 'zext ');
    PutLlType(s^.csSelector^.ntype);
    write(ircode, ' ');
    PutOp(sel);
    writeln(ircode, ' to i32');
    sel := wide
  end;

  count := 0;
  arm := s^.csArms;
  while arm <> nil do begin
    count := count + 1;
    arm := arm^.next
  end;
  { The arms' blocks are numbered before the switch is written, because the
    switch names them all and they are filled afterwards. They are consecutive,
    so one number is enough to find them again. }
  first := nextBlock + 1;
  for k := 1 to count do
    armB := NewBlock;
  defaultB := NewBlock;
  endB := NewBlock;

  { A range is *tested*, not enumerated: `1..maxint` is a legal label list
    (ISO/IEC 10206:1991 6.8.3.5) and two billion switch cases. So the ranges are
    a chain of comparisons ahead of the switch, and only single constants reach
    the switch itself. Sema has already proved the arms disjoint, so which of
    the two answers first cannot matter. }
  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    n := arm^.caValues;
    while n <> nil do begin
      if n^.lo <> n^.hi then begin
        nextB := NewBlock;
        Def(ge);
        write(ircode, 'icmp sge i32 ');
        PutOp(sel);
        writeln(ircode, ', ', n^.lo:1);
        Def(le);
        write(ircode, 'icmp sle i32 ');
        PutOp(sel);
        writeln(ircode, ', ', n^.hi:1);
        Def(both);
        write(ircode, 'and i1 ');
        PutOp(ge);
        write(ircode, ', ');
        PutOp(le);
        writeln(ircode);
        write(ircode, '  br i1 ');
        PutOp(both);
        writeln(ircode, ', label %L', k:1, ', label %L', nextB:1);
        StartBlock(nextB)
      end;
      n := n^.next
    end;
    k := k + 1;
    arm := arm^.next
  end;

  write(ircode, '  switch i32 ');
  PutOp(sel);
  write(ircode, ', label %L', defaultB:1, ' [');
  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    n := arm^.caValues;
    while n <> nil do begin
      if n^.lo = n^.hi then
        write(ircode, ' i32 ', n^.lo:1, ', label %L', k:1);
      n := n^.next
    end;
    k := k + 1;
    arm := arm^.next
  end;
  writeln(ircode, ' ]');

  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    StartBlock(k);
    EmitStmt(arm^.caBody);
    writeln(ircode, '  br label %L', endB:1);
    k := k + 1;
    arm := arm^.next
  end;

  StartBlock(defaultB);
  if s^.csHasOtherwise then begin
    { ISO/IEC 10206:1991: the default arm is a statement-sequence rather than
      the trap. Everything else about the lowering is unchanged, which is the
      point -- an `otherwise` is what the default block holds, not a different
      shape of switch. }
    arm := s^.csOtherwise;
    while arm <> nil do begin
      EmitStmt(arm);
      arm := arm^.next
    end;
    EndSequence(s^.csOtherwise);
    writeln(ircode, '  br label %L', endB:1)
  end
  else begin
    MsgStart;
    MsgText('case: no label matches the selector     ');
    msg := MsgEnd;
    write(ircode, '  call void @pas_runtime_error_at(ptr @s', msg:1);
    PutPos(s^.csSelector^.line, s^.csSelector^.col);
    writeln(ircode, ')');
    writeln(ircode, '  unreachable')
  end;

  StartBlock(endB)
end;

{ AP 6.9.3.15's select-statement (ADR-0313).

  The whole of the waiting is the runtime's, and what the emitter writes is a
  descriptor array and a switch. That split is deliberate: which arm goes
  first rotates, so that a channel always ready cannot starve the arm below
  it, and a rotation is a fact about the *execution* rather than about the
  program -- putting it here would have made the emitted code carry a counter
  and the arms be tried in emitted order, which is the thing being avoided.

  Everything is evaluated before the call and nothing after it. A channel is
  lent once, a receive's destination has its address taken once, and a send's
  value is stored once into the frame slot Sema gave that arm -- so a select
  that goes round its arms a hundred times evaluates each actual exactly one
  time, and how many times it went round is unobservable. }
procedure EmitSelectArmSetup(a: nodePtr; protected var base: str);
var armp, fld, chan, val, addr: str;
begin
  Def(armp);
  write(ircode, 'getelementptr inbounds i8, ptr ');
  PutOp(base);
  writeln(ircode, ', i64 ', a^.saIndex * selectArmSize:1);

  write(ircode, '  store i32 ', a^.saKind:1, ', ptr ');
  PutOp(armp);
  writeln(ircode);

  { `got` -- what a receive that fired answers. Cleared here rather than
    trusted, because the frame slot is the block's and holds whatever the
    previous select in this block left in it. }
  Def(fld);
  write(ircode, 'getelementptr inbounds i8, ptr ');
  PutOp(armp);
  writeln(ircode, ', i64 4');
  write(ircode, '  store i32 0, ptr ');
  PutOp(fld);
  writeln(ircode);

  EmitAddress(a^.saArgs, addr);
  EmitAt(a^.saArgs^.line, a^.saArgs^.col);
  Def(chan);
  write(ircode, 'call ptr @pas_handle_lend(ptr ');
  PutOp(addr);
  writeln(ircode, ')');
  EmitAtDone;
  Def(fld);
  write(ircode, 'getelementptr inbounds i8, ptr ');
  PutOp(armp);
  writeln(ircode, ', i64 8');
  write(ircode, '  store ptr ');
  PutOp(chan);
  write(ircode, ', ptr ');
  PutOp(fld);
  writeln(ircode);

  { Where the value comes from or goes to. A receive writes into the program's
    own variable, so the runtime is given its address; a send reads out of the
    hidden variable this arm's value was just stored into. }
  if a^.saKind = 0 then EmitAddress(a^.saArgs^.next, val)
  else begin
    AddressOfSym(a^.saSlot, val);
    EmitStore(val, a^.saSlot^.stype, a^.saArgs^.next)
  end;
  Def(fld);
  write(ircode, 'getelementptr inbounds i8, ptr ');
  PutOp(armp);
  writeln(ircode, ', i64 16');
  write(ircode, '  store ptr ');
  PutOp(val);
  write(ircode, ', ptr ');
  PutOp(fld);
  writeln(ircode)
end;

procedure EmitSelect(s: nodePtr);
var a, sub: nodePtr;
    frame, base, ms, chosen, armp, fld, raw, bit, tgt: str;
    first, k, armB, timeoutB, endB, bounded: integer;
begin
  FrameAt(irProc^.level, frame);
  SelectSlot(irProc, frame, base);

  a := s^.slArms;
  while a <> nil do begin
    if a^.saKind <> 2 then EmitSelectArmSetup(a, base);
    a := a^.next
  end;

  { The deadline. An `after` arm gives one, an `otherwise` is a deadline of
    zero -- the runtime polls once and answers that nothing was ready -- and a
    select with neither waits for as long as it takes. Sema has refused both
    at once, so the two cannot disagree here. }
  bounded := 0;
  StrClear(ms);
  StrAppend(ms, '0');
  a := s^.slArms;
  while a <> nil do begin
    if a^.saKind = 2 then begin
      EmitExpr(a^.saDelay, raw);
      Def(ms);
      write(ircode, 'sext i32 ');
      PutOp(raw);
      writeln(ircode, ' to i64');
      bounded := 1
    end;
    a := a^.next
  end;
  if s^.slHasOtherwise then bounded := 1;

  EmitAt(s^.line, s^.col);
  Def(chosen);
  write(ircode, 'call i32 @pas_select(ptr ');
  PutOp(base);
  write(ircode, ', i32 ', s^.slCount:1, ', i32 ', bounded:1, ', i64 ');
  PutOp(ms);
  writeln(ircode, ')');
  EmitAtDone;

  first := nextBlock + 1;
  for k := 1 to s^.slCount do
    armB := NewBlock;
  timeoutB := NewBlock;
  endB := NewBlock;

  { The runtime answers the index of the arm that proceeded, or the arm count
    where it gave up. The count is the default label as well, so a value the
    runtime cannot produce lands somewhere with a statement rather than in
    `unreachable`. }
  write(ircode, '  switch i32 ');
  PutOp(chosen);
  write(ircode, ', label %L', timeoutB:1, ' [');
  for k := 0 to s^.slCount - 1 do
    write(ircode, ' i32 ', k:1, ', label %L', first + k:1);
  writeln(ircode, ' ]');

  a := s^.slArms;
  while a <> nil do begin
    if a^.saKind <> 2 then begin
      StartBlock(first + a^.saIndex);
      { `ok := receive(c, v)`: what the runtime wrote into the descriptor,
        which is 1 for a value and 0 for the close of a drained channel. }
      if a^.saTarget <> nil then begin
        Def(armp);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(base);
        writeln(ircode, ', i64 ', a^.saIndex * selectArmSize:1);
        Def(fld);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(armp);
        writeln(ircode, ', i64 4');
        Def(raw);
        write(ircode, 'load i32, ptr ');
        PutOp(fld);
        writeln(ircode);
        Def(bit);
        write(ircode, 'trunc i32 ');
        PutOp(raw);
        writeln(ircode, ' to i1');
        EmitAddress(a^.saTarget, tgt);
        write(ircode, '  store i1 ');
        PutOp(bit);
        write(ircode, ', ptr ');
        PutOp(tgt);
        writeln(ircode)
      end;
      EmitStmt(a^.saBody);
      writeln(ircode, '  br label %L', endB:1)
    end;
    a := a^.next
  end;

  StartBlock(timeoutB);
  a := s^.slArms;
  while a <> nil do begin
    if a^.saKind = 2 then EmitStmt(a^.saBody);
    a := a^.next
  end;
  sub := s^.slOtherwise;
  while sub <> nil do begin
    EmitStmt(sub);
    sub := sub^.next
  end;
  EndSequence(s^.slOtherwise);
  writeln(ircode, '  br label %L', endB:1);

  StartBlock(endB)
end;

procedure EmitStmt;
var sub: nodePtr; v, flag: str; mark: integer;
begin
  if s <> nil then begin
    { What the string arena stood at before this statement was emitted
      (ADR-0111). Compared against the same counter afterwards, it says whether
      anything below took storage -- from this statement or from any expression
      inside it -- and so whether a release has to be written. }
    mark := strTemps;
    { --coverage (ADR-0104). One counter per statement, before the statement's
      own code, so a statement that traps still counts as reached -- which is
      what makes a coverage report usable on a program that stops.

      Two kinds are skipped and both would be noise rather than information: an
      empty statement (6.8.2.1 makes one legal wherever a statement may stand, and
      it emits nothing) and a compound, whose line is the `begin` and whose
      constituents are each counted already. A node with no recorded position is
      skipped too, since a line of 0 names nothing in the source. }
    if covOpt and (s^.line > 0)
       and (s^.kind <> nkEmpty) and (s^.kind <> nkCompound) then
      writeln(ircode, '  call void @pas_cov_hit(i32 ', s^.line:1, ')');
    case s^.kind of
      nkEmpty: ;
      nkCompound: begin
        sub := s^.cpBody;
        while sub <> nil do begin
          EmitStmt(sub);
          sub := sub^.next
        end;
        EndSequence(s^.cpBody)
      end;
      { AP 6.9.3.11: arming is the whole of what a defer-statement emits. The
        statement itself was emitted where the sequence ends and in the
        runner, both of which read this flag. }
      nkDefer: begin
        FrameAt(irProc^.level, v);
        DeferFlag(irProc, v, s^.dfIndex, flag);
        write(ircode, '  store i8 1, ptr ');
        PutOp(flag);
        writeln(ircode)
      end;
      nkAssign: EmitAssign(s);
      { The husk first: 6.6.4.1 lets the program declare its own `write`, and
        Sema puts the call it really is here (ADR-0087). Nothing below this
        line knows the name was ever one of the six. }
      nkWrite:
        if s^.wrCall <> nil then begin
          if s^.wrCall^.pcSym <> nil then
            EmitUserCall(s^.wrCall^.pcSym, s^.wrCall^.pcArgs, nil, v,
                         s^.wrCall^.line, s^.wrCall^.col)
        end
        else EmitWrite(s);
      nkRead:
        if s^.rdCall <> nil then begin
          if s^.rdCall^.pcSym <> nil then
            EmitUserCall(s^.rdCall^.pcSym, s^.rdCall^.pcArgs, nil, v,
                         s^.rdCall^.line, s^.rdCall^.col)
        end
        else EmitRead(s);
      nkIf: EmitIf(s);
      nkWhile: EmitWhile(s);
      nkRepeat: EmitRepeat(s);
      nkFor: EmitFor(s);
      nkWith: EmitWith(s);
      nkCase: EmitCase(s);
      nkGoto: EmitGoto(s);
      nkSpawn: EmitSpawn(s);
      nkSelect: EmitSelect(s);
      nkLabeled: EmitLabeled(s);
      nkProcCall:
        if s^.pcStd <> spNone then EmitStdProc(s)
        else if s^.pcSym <> nil then
          EmitUserCall(s^.pcSym, s^.pcArgs, nil, v, s^.line, s^.col);
      nkInt, nkReal, nkInt64, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar, nkIndex,
      nkStructValue, nkValueElem,
      nkSubstr, nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkWriteArg, nkCaseArm, nkSelectArm, nkVariantArm, nkGroup,
      nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer, nkOptional, nkHandle,
      nkFallible,
      nkConfArray,
      nkFile, nkSetOf, nkSchema, nkInquiry, nkRestricted, nkConstDecl, nkTypeDecl, nkProcDecl,
      nkLabelDecl, nkBlock, nkModule, nkExportPart, nkExportItem,
      nkImportSpec, nkImportItem: ;
    end;
    { The release goes *after* the statement, which is where the emitter can
      still write: it cannot go back to put a mark in front of one, and every
      statement leaves a block open behind it -- EmitGoto starts a fresh one
      precisely so that what follows a goto has somewhere to live.

      A compound is skipped because its constituents each release already; a
      structured statement is not, since only that release reclaims what its
      *own* controlling expression took. A goto out of a statement skips the
      release it was inside, and nothing is lost by it: the next statement that
      allocates restores this level before going on. }
    if (strTemps > mark) and (s^.kind <> nkCompound) then
      ReleaseStrTemps
  end
end;

{ ============================== procedures =============================== }

procedure PutSlotType(s: symPtr);
begin
  { A schematic formal parameter's slot holds the whole descriptor: the
    address, and the tuple that says how far the thing at it reaches. A `var`
    parameter's slot holds the address of the caller's variable, not a copy of
    its value. Everything else -- including a structured value parameter, which
    the prologue copies in -- holds the value itself. }
  if s^.descSchema <> nil then PutDescType(s)
  { ADR-0125: a slice's slot holds the pair even though it is a var parameter,
    because the *length* is not in the caller's variable -- it is what the
    designator computed, and there is nowhere else for it to live. }
  else if IsSlice(s^.stype) then PutLlType(s^.stype)
  else if s^.kind = skVarParam then write(ircode, 'ptr')
  else PutLlType(s^.stype)
end;

{ The LLVM parameters one Pascal parameter list contributes, after the static
  link. Every parameter is one argument except a procedural one, which is two
  -- the code and the link it needs -- so a caller and a callee agree on the
  shape only by both coming through here. }
procedure PutParamTypes;
var k: integer;
begin
  k := 0;
  while p <> nil do begin
    write(ircode, ', ');
    if p^.sym^.descSchema <> nil then
      PutDescParamTypes(p^.sym, named, k)
    else begin
      if p^.sym^.kind = skProcParam then begin
        write(ircode, 'ptr');
        if named then write(ircode, ' %a', k:1);
        k := k + 1;
        write(ircode, ', ptr')
      end
      { A variable-string value parameter is the second thing here that is two
        arguments, and for ADR-0030's reason rather than by analogy: a string
        *value* is a pointer and a length (ADR-0051), and the actual may be a
        literal, a fixed string or a string of another capacity -- so there is
        no single object whose address could be passed instead. The callee's
        prologue converts the pair into its own slot, which is where 6.4.6's
        padding has somewhere to happen (ADR-0115). }
      else if (p^.sym^.kind <> skVarParam) and IsStringRep(p^.sym^.stype) then
      begin
        write(ircode, 'ptr');
        if named then write(ircode, ' %a', k:1);
        k := k + 1;
        write(ircode, ', i32')
      end
      { ADR-0125's slice is the third, and for ADR-0030's reason a third time:
        an address and a count, and no single object whose address would carry
        both. }
      else if IsSlice(p^.sym^.stype) then begin
        write(ircode, 'ptr');
        if named then write(ircode, ' %a', k:1);
        k := k + 1;
        write(ircode, ', i32')
      end
      else if (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype) then
        write(ircode, 'ptr')
      else
        PutLlType(p^.sym^.stype);
      if named then write(ircode, ' %a', k:1);
      k := k + 1
    end;
    p := p^.next
  end
end;

{ AP 6.9.3.12: the type of one field of a task's argument block.

  It is the formal's *slot* type, but for a handle -- where the slot is a
  handle record and what crosses is the one word the handle is. The block is
  what the two activations have instead of a shared stack, so every field is
  a value copied into it, the address of an object with a lock, or a handle
  the spawning variable has stopped holding (ADR-0302). }
procedure PutTaskArgType(f: symPtr);
begin
  if IsHandle(f^.stype) then write(ircode, 'ptr')
  else PutSlotType(f)
end;

{ The argument-block type of a task: the static link, then one field per
  formal, in order. Named after the task and emitted beside its frame type. }
procedure EmitTaskArgType(p: symPtr);
var l: symListPtr;
begin
  write(ircode, '%targ', p^.irId:1, ' = type { ptr');
  l := p^.params;
  while l <> nil do begin
    write(ircode, ', ');
    PutTaskArgType(l^.sym);
    l := l^.next
  end;
  writeln(ircode, ' }')
end;

procedure EmitFrameType(p: symPtr);
var l: symListPtr;
begin
  p^.irId := nextProcId;
  nextProcId := nextProcId + 1;
  write(ircode, '%frame', p^.irId:1, ' = type { ptr');
  l := p^.frameVars;
  while l <> nil do begin
    write(ircode, ', ');
    PutSlotType(l^.sym);
    l := l^.next
  end;
  { A block reachable by a non-local goto carries the jump record after its
    variables. It is last so that no frame index moves, and it is not a frame
    variable because nothing in the source can name it: the prologue arms it,
    the epilogue disarms it, and a goto in a nested block reaches it by
    walking the static chain (ADR-0032). }
  if p^.nlLabels <> nil then
    write(ircode, ', [', jumpSize div 8:1, ' x i64]');
  { AP 6.9.3.11: the defer record, and one flag per defer-statement of the
    block. Last for the jump record's reason, and absent altogether from a
    block that defers nothing -- which is what makes this feature cost every
    program that does not use it exactly nothing (ADR-0175). }
  if p^.deferCount > 0 then begin
    write(ircode, ', [', deferSize div 8:1, ' x i64]');
    write(ircode, ', [', p^.deferCount:1, ' x i8]')
  end;
  { AP 6.9.3.12: the set of tasks this block has spawned, so it can join every
    one before its activation ends. Last, for the two records above's reason,
    and absent from a block that spawns nothing -- so the construct costs a
    program that does not use it exactly nothing, which is ADR-0175's rule
    applied a third time. }
  if p^.spawns then
    write(ircode, ', [', taskSetSize div 8:1, ' x i64]');
  { AP 6.9.3.15: the descriptor array a select-statement hands the runtime,
    one entry per channel arm and sized to the widest select in this block --
    one slot per *block* and not one per statement, for the reason the two
    records above are one apiece. It is last, so no frame index a name
    resolves to moves, and it is absent from a block that selects nothing. }
  if p^.selectArms > 0 then
    write(ircode, ', [', (p^.selectArms * selectArmSize) div 8:1, ' x i64]');
  writeln(ircode, ' }');
  if p^.isTask then EmitTaskArgType(p)
end;

procedure DeclareProcs(b: nodePtr);
var d: nodePtr;
begin
  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdSym <> nil then
      { A foreign routine has no activation record here -- its body is on the
        other side of the link and was laid out by another processor -- so
        there is no frame type to name (ADR-0121). }
      { AP 6.7.3.10: a generic routine has no activation record either, and
        for a nearer reason than a foreign one's -- it has no formals and no
        result type, because those are what a call decides. Asking for a frame
        type here laid out a slot for a result of no type, which LLVM refuses
        as `void` in a struct. Its instantiations are separate declarations in
        this same list and each gets its own. }
      if (d^.pdSym^.irId = 0) and    { a forward declaration already made one }
         (d^.pdSym^.linkKind <> lnkForeign) and
         (not d^.pdSym^.isGeneric) then
        EmitFrameType(d^.pdSym);
    d := d^.next
  end;
  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdBody <> nil then
      if d^.pdSym = nil then DeclareProcs(d^.pdBody)
      else if not d^.pdSym^.isGeneric then DeclareProcs(d^.pdBody);
    d := d^.next
  end
end;

{ Every file variable the frame holds starts closed, and knows how reset and
  rewrite will find the external file it stands for. The standard files are
  opened here -- ISO 7185 6.10 has `input` reset and `output` rewritten before
  the program body runs -- but no character is read until the program asks, or
  a program that never reads would hang waiting for a terminal. }
procedure InitFiles(p: symPtr);
var l: symListPtr; addr: str;
    binding, name: integer;
begin
  l := p^.frameVars;
  while l <> nil do begin
    { AP 6.7.8.1: a task's handle parameter is installed by the prologue --
      a channel's slot takes a reference to the value that crossed and a
      moved handle's takes the value itself (ADR-0302) -- so this walk must
      not set one up over it. Every other handle parameter is a var parameter
      and was already excluded; these are the only value parameters of a
      handle-type a routine of this program can have. }
    if HoldsFile(l^.sym^.stype) and (l^.sym^.kind <> skVarParam) and
       not (IsHandle(l^.sym^.stype) and (l^.sym^.kind = skParam)) then begin
      case l^.sym^.binding of
        fbInternal:  binding := 0;
        fbStdInput:  binding := 1;
        fbStdOutput: binding := 2;
        fbArgument:  binding := 3
      end;
      name := AddGlobal(l^.sym^.at, l^.sym^.len);
      AddressOfSym(l^.sym, addr);
      WalkFiles(addr, l^.sym^.stype, true, binding, l^.sym^.fileArg, name,
                l^.sym^.declLine, l^.sym^.declCol)
    end;
    l := l^.next
  end
end;

{ AP 6.9.3.11: the flags start clear -- an `alloca` does not -- and the
  record goes on the runtime's list, so that a `goto` past this block and a
  `halt` can run what this block armed. A block that defers nothing emits none
  of it. }
{ AP 6.9.3.12: the task set starts empty. An `alloca` does not, and the
  runtime reads the count before it reads the array. }
procedure InitTasks(p: symPtr);
var frame, slot: str;
begin
  if p^.spawns then begin
    FrameAt(p^.level, frame);
    TaskSetSlot(p, frame, slot);
    write(ircode, '  call void @pas_tasks_init(ptr ');
    PutOp(slot);
    writeln(ircode, ')')
  end
end;

procedure InitDefers(p: symPtr);
var frame, rec, flag: str; k: integer;
begin
  if p^.deferCount > 0 then begin
    FrameAt(p^.level, frame);
    for k := 0 to p^.deferCount - 1 do begin
      DeferFlag(p, frame, k, flag);
      write(ircode, '  store i8 0, ptr ');
      PutOp(flag);
      writeln(ircode)
    end;
    DeferRecord(p, frame, rec);
    write(ircode, '  call void @pas_defer_init(ptr ');
    PutOp(rec);
    write(ircode, ', ptr ');
    PutDeferName(p);
    write(ircode, ', ptr ');
    PutOp(frame);
    writeln(ircode, ')')
  end
end;

{ AP 6.7.5.9: where an `exit` branched to, written between the body and the
  epilogue so that both paths reach the epilogue and there is one of it. The
  fall-through needs the branch as much as the exits do -- the block before it
  is whatever the body ended in, and a basic block ends in a terminator.

  Nothing is emitted for a block no `exit` claimed, which is every block of
  every program written before this clause and of every conforming one. }
procedure EmitExitTarget(p: symPtr);
begin
  if p^.exitBlock <> 0 then begin
    writeln(ircode, '  br label %L', p^.exitBlock:1);
    StartBlock(p^.exitBlock)
  end
end;

{ A block exit closes the files the block declared, which is ISO 7185's rule
  and also the only thing that flushes a file written to inside a procedure.
  Since AP 6.7.5.9 a block may be left before its last statement, so this is
  reached from the one place EmitExitTarget leaves control at rather than from
  the end of the body -- and it is still emitted exactly once per block. }
procedure CloseFiles(p: symPtr);
var l: symListPtr; addr, frame, rec: str;
begin
  { AP 6.9.3.11 before anything is closed: a statement armed in this block may
    still write to a file the block owns, and this is the last moment it can.
    Whatever the sequences already ran is disarmed, so what this reaches is
    what a `goto` inside the block left pending. Calling it twice is a no-op
    -- pas_defer_done clears the runner as it unlinks -- which is what lets a
    module's finalization share this epilogue with its initialization. }
  { AP 6.9.3.12: **join before releasing anything**, and this is the whole
    safety argument of the construct rather than a tidiness.

    A task's body is a nested routine reached through a static link into this
    frame, and it was lent whatever channels it was given. So it must not
    outlive either -- and everything below this releases something: the defer
    runner runs statements of this block, the file walk closes this block's
    files and handles, and the frame itself goes away when the activation
    ends. Joining first is what makes ADR-0201's sentence -- *a borrow cannot
    outlive the call because the caller is not running during it* -- true
    again in the presence of two threads of control, which is the one sentence
    that record said two threads break.

    It is emitted first for the same reason it is placed last in the frame:
    the ordering is the rule, and the rule is stated in one place. }
  if p^.spawns then begin
    FrameAt(p^.level, frame);
    TaskSetSlot(p, frame, rec);
    write(ircode, '  call void @pas_tasks_join(ptr ');
    PutOp(rec);
    writeln(ircode, ')')
  end;
  if p^.deferCount > 0 then begin
    FrameAt(p^.level, frame);
    DeferRecord(p, frame, rec);
    write(ircode, '  call void @pas_defer_done(ptr ');
    PutOp(rec);
    writeln(ircode, ')')
  end;
  l := p^.frameVars;
  while l <> nil do begin
    if HoldsFile(l^.sym^.stype) and (l^.sym^.kind <> skVarParam) then begin
      AddressOfSym(l^.sym, addr);
      WalkFiles(addr, l^.sym^.stype, false, 0, 0, 0, 0, 0)
    end;
    l := l^.next
  end;
  { Disarming the jump record is part of the same exit. Nothing the compiler
    accepts can reach a dead frame -- the static chain only names live ones --
    so it buys a diagnosable error rather than a jump into reclaimed stack. }
  if p^.nlLabels <> nil then begin
    FrameAt(p^.level, frame);
    JumpRecord(p, frame, rec);
    write(ircode, '  call void @pas_jump_done(ptr ');
    PutOp(rec);
    writeln(ircode, ')')
  end
end;

{ The target's half of a non-local goto. The record is armed first -- which
  notes the files the block already has open, so a later jump knows which ones
  it abandons -- and then `_setjmp` is called *here*, in the function that owns
  the frame. It cannot be called through a runtime wrapper: the wrapper would
  have returned by the time the jump arrived, and its frame is what `_setjmp`
  recorded. #0 is `returns_twice`, without which LLVM may keep a value in a
  register across the call that the jump will not restore. }
procedure JumpDispatch(p: symPtr);
var frame, rec, env, arrived: str; num: numPtr; bodyB: integer;
begin
  if p^.nlLabels <> nil then begin
    FrameAt(p^.level, frame);
    JumpRecord(p, frame, rec);
    Def(env);
    write(ircode, 'call ptr @pas_jump_env(ptr ');
    PutOp(rec);
    writeln(ircode, ')');
    Def(arrived);
    write(ircode, 'call i32 @_setjmp(ptr ');
    PutOp(env);
    writeln(ircode, ') #0');
    bodyB := NewBlock;
    write(ircode, '  switch i32 ');
    PutOp(arrived);
    writeln(ircode, ', label %L', bodyB:1, ' [');
    num := p^.nlLabels;
    while num <> nil do begin
      writeln(ircode, '    i32 ', num^.value_ + 1:1, ', label %L',
              LabelBlock(num^.value_):1);
      num := num^.next
    end;
    writeln(ircode, '  ]');
    StartBlock(bodyB)
  end
end;

{ 6.4.7 NOTE 2: a tuple that leaves an index range empty selects no type from
  the schema at all. Where the tuple is a constant Sema says so; where it is
  not, this does. }
procedure CheckSchemaDomain;
var lo, hi, bad: str; msg: integer; last: fieldPtr;
begin
  if t <> nil then
    { A record reaches here only with its dynamic part last (ADR-0045), so the
      walk into it is the same walk: one dimension per level, wherever the
      level came from. }
    if (t^.kind = tyRecord) and DynamicExtent(t) then begin
      last := LastField(t^.fields);
      CheckSchemaDomain(last^.ftype, schema, header, line, col)
    end
    { A subrange whose bounds are discriminants, which ADR-0133 made reachable
      here. 6.4.2.4 requires the first bound not to exceed the second, and
      where both are constants Sema says so before the program runs; where one
      is not, nothing else would. An empty one has no values, so every store
      into it traps -- but a block that declares such a variable and never
      stores into it would run with a type that is not a type, which is the
      case this catches. It is not guarded by DynamicExtent, a subrange having
      none: its size is its host's whatever its bounds are. }
    else if (t^.kind = tySubrange) and
            ((t^.loDisc <> nil) or (t^.hiDisc <> nil)) then begin
      BoundValue(t, false, header, lo);
      BoundValue(t, true, header, hi);
      Def(bad);
      write(ircode, 'icmp slt i32 ');
      PutOp(hi);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      MsgStart;
      { A constant, where the array's message above has to choose between the
        schema's name and a description: an empty subrange has nothing to name
        but itself. }
      MsgText('this subrange has no values: its upper  ');
      MsgText(' bound is below its lower bound         ');
      msg := MsgEnd;
      EmitTrapIf(bad, msg, line, col)
    end
    { 6.4.3.3.3: "Each tuple in the domain of the schema shall have one
      component that is a value of integer-type greater than zero", and
      AP 6.4.15.1 says the same of `utf8`. So a capacity of zero or less is
      outside the *domain*, which 6.4.8 makes a dynamic-violation -- and 3.1
      permits one to be left undetected only "up to, but not beyond, execution
      of the declaration", with 5.1 f)'s NOTE 1 stating that dynamic-violations
      "must be detected".

      Sema catches it where the tuple is a constant. Where a discriminant
      brought it, nothing did: `procedure g(n: integer); var x: string(n)`
      called with 0 produced a string of capacity 0 in silence, and `utf8(-1)`
      ran to completion. Found by ADR-0224's audit (ADR-0225).

      The two kinds share the arm because they share the shape -- `hi` is the
      capacity and `hiDisc` the discriminant it came from -- and differ only in
      the noun, which is the same pair of words Sema uses on the static path.
      A canonical-string-type is excluded by the `hiDisc` test: it has no
      capacity and no discriminant. }
    else if IsStringRep(t) and (t^.hiDisc <> nil) then begin
      BoundValue(t, true, header, hi);
      Def(bad);
      write(ircode, 'icmp slt i32 ');
      PutOp(hi);
      writeln(ircode, ', 1');
      MsgStart;
      if IsText(t) then
        MsgText('the capacity of a text must be greater  ')
      else
        MsgText('the capacity of a string must be greater');
      MsgText(' than zero                              ');
      msg := MsgEnd;
      EmitTrapIf(bad, msg, line, col)
    end
    else if (t^.kind = tyArray) and DynamicExtent(t) then begin
      if (t^.loDisc <> nil) or (t^.hiDisc <> nil) then begin
        BoundValue(t, false, header, lo);
        BoundValue(t, true, header, hi);
        Def(bad);
        write(ircode, 'icmp slt i32 ');
        PutOp(hi);
        write(ircode, ', ');
        PutOp(lo);
        writeln(ircode);
        MsgStart;
        { An anonymous schema has no spelling, because the program wrote no
          schema (ADR-0113). Naming one would be naming something the source
          does not contain, so the message describes the array instead -- the
          same condition, said in the words of what was written. }
        if schema^.len = 0 then begin
          { MsgText drops a piece's trailing blanks, so a space that has to
            survive a join goes at the *start* of the next piece. }
          MsgText('this array has no components: its upper ');
          MsgText(' bound is below its lower bound         ')
        end
        else begin
          MsgText('no type is produced from schema ''       ');
          WritePool(schema^.at, schema^.len);
          MsgText(''' with these discriminants              ')
        end;
        msg := MsgEnd;
        EmitTrapIf(bad, msg, line, col)
      end;
      CheckSchemaDomain(t^.elem, schema, header, line, col)
    end
end;

{ 6.2.3.2: the actual-discriminant-part of a variable is evaluated when the
  block is entered. The tuple goes into the descriptor first, because
  everything after it -- the domain check, the size, the storage -- is asked of
  the descriptor and not of the expressions that filled it. }
{ ISO/IEC 10206:1991 6.2.3.5: "Each variable contained by an activation of a
  block ... shall be created in its initial state within the commencement of
  the activation." 6.6 makes every expression in one nonvarying, so nothing
  here can depend on the order -- which is why the whole feature is a walk of
  the frame rather than a place in the declaration sequence.

  A record's fields may each carry one, so a record with no initial state of
  its own may still have parts of it initialised. That is the recursion; it
  does not go into an array, because 6.4.3.2 forbids a component-type from
  carrying a specifier at all. }
procedure InitialStateInto(var addr: str; t: typePtr; init: nodePtr);
var f: fieldPtr; sub: str;
begin
  if init <> nil then
    EmitStore(addr, t, init)
  else if IsRecord(t) then begin
    f := t^.fields;
    while f <> nil do begin
      if (f^.initValue <> nil) or IsRecord(f^.ftype) then begin
        FieldAddress(addr, t, f, sub, vgNone, 0, 0);
        InitialStateInto(sub, f^.ftype, f^.initValue)
      end;
      f := f^.next
    end
  end
end;

procedure InitInitialStates(p: symPtr);
var l: symListPtr; addr: str;
begin
  l := p^.frameVars;
  while l <> nil do begin
    { 6.2.3.5 excludes formal parameters, and a hidden slot has no declaration
      to have carried a specifier. }
    if l^.sym^.kind = skVar then
      if (l^.sym^.initValue <> nil) or IsRecord(l^.sym^.stype) then begin
        AddressOfSym(l^.sym, addr);
        InitialStateInto(addr, l^.sym^.stype, l^.sym^.initValue)
      end;
    l := l^.next
  end
end;

{ ISO/IEC 10206:1991 6.8.7's value built into the storage its constant was
  given. It runs *before* the initial states, because 6.6's specifier may name a
  constant, and before anything else because a constant-expression is nonvarying
  (6.8.2) and so cannot read what the rest of the prologue writes. The order
  within the list is the order the constants were defined, which is a legal
  order for the same reason ADR-0053's written order of modules is: a
  component-value naming another constant names an earlier one (ADR-0069). }
procedure InitConstants(p: symPtr);
var l: symListPtr; addr: str;
begin
  l := p^.memConsts;
  while l <> nil do begin
    ConstAddress(l^.sym, addr);
    EmitStructValue(l^.sym^.constValue, addr);
    l := l^.next
  end
end;

{ Whether this frame variable fills its own descriptor when the block is
  entered, as against a schematic formal parameter's, which the caller brings
  already filled. Two shapes say yes: a variable written with a schema whose
  actual-discriminant-part was not constant (discExprs), and one whose *bounds*
  were not constants, which has no actual-discriminant-part anywhere and whose
  discriminants each carry the bound they were made from (ADR-0113). }
function FillsOwnDescriptor(s: symPtr): boolean;
begin
  if s^.descSchema = nil then FillsOwnDescriptor := false
  else if s^.discExprs <> nil then FillsOwnDescriptor := true
  else if s^.discSyms = nil then FillsOwnDescriptor := false
  else FillsOwnDescriptor := s^.discSyms^.sym^.discExpr <> nil
end;

procedure InitDynamicVars(p: symPtr);
var l, d: symListPtr; a, e: nodePtr; slot, half, value_, size, storage: str;
    nohdr: str; comp: typePtr; align: integer;
begin
  l := p^.frameVars;
  while l <> nil do begin
    if FillsOwnDescriptor(l^.sym) or l^.sym^.boundsFromType then begin
      { Through FrameSlot rather than a written %frame: a level-0 owner -- the
        program -- keeps its variables in a global and has no frame register,
        so spelling one here emitted IR naming a value that does not exist.
        Every other reach for a slot outside this procedure already goes
        through it (ADR-0016). }
      FrameSlot(l^.sym, slot);
      { A variable whose bounds are its *type's* fills nothing: 6.2.3.8 b)
        evaluated them once at the type-definition, and this slot holds only
        the address (ADR-0127). Re-evaluating them here would be a second
        evaluation of one bound and could answer differently -- a bound may
        call a function -- which is exactly what makes two variables of one
        type two extents. }
      if not l^.sym^.boundsFromType then begin
      a := l^.sym^.discExprs;
      d := l^.sym^.discSyms;
      while d <> nil do begin
        { The written actual-discriminant-part, walked in step -- or, where
          there was no schema to write one, the bound this discriminant was
          made from (ADR-0113). }
        if a <> nil then e := a else e := d^.sym^.discExpr;
        EmitExpr(e, value_);
        ConvertFor(value_, e^.ntype, d^.sym^.stype);
        { A discriminant outside its own type is outside 6.4.7's domain. The
          store is where a value enters a variable, so the check that guards
          every other such store is the one that says so here too. }
        CheckedForStore(value_, d^.sym^.stype, l^.sym^.declLine, l^.sym^.declCol);
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutDescType(l^.sym);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 ', 1 + d^.sym^.discIndex:1);
        write(ircode, '  store ');
        PutLlType(d^.sym^.stype);
        write(ircode, ' ');
        PutOp(value_);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        if a <> nil then a := a^.next;
        d := d^.next
      end;
      StrClear(nohdr);
      CheckSchemaDomain(l^.sym^.stype, l^.sym^.descSchema, nohdr,
                        l^.sym^.declLine, l^.sym^.declCol)
      end;
      { A type-definition's own descriptor allocates nothing: a type has no
        storage, and the variables of it each get their own below. Its slot is
        a descriptor all the same, so the discriminants sit where every reader
        of them already looks; the address field is the one word it does not
        use (ADR-0127). }
      if not l^.sym^.boundsOwner then begin
      StrClear(nohdr);
      comp := l^.sym^.stype;
      while comp^.kind = tyArray do comp := comp^.elem;
      align := LlAlign(comp);
      DynSize(l^.sym^.stype, nohdr, size);
      Def(storage);
      write(ircode, 'alloca i8, i32 ');
      PutOp(size);
      writeln(ircode, ', align ', align:1);
      Def(half);
      write(ircode, 'getelementptr inbounds ');
      PutDescType(l^.sym);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode, ', i32 0, i32 0');
      write(ircode, '  store ptr ');
      PutOp(storage);
      write(ircode, ', ptr ');
      PutOp(half);
      writeln(ircode)
      end
    end;
    l := l^.next
  end
end;

{ The prologue shared by main and every procedure: alloca the frame, store the
  static link, copy the incoming arguments into their slots. }
{ The facts every emitted function starts from, and the frame it works
  through. Split out of EnterFrame because a module's finalization needs
  exactly this and none of the prologue that follows it -- no parameters to
  copy in, no files to open, no jump record to arm, since 6.11.1 gives a
  module-block no label-declaration-part. }
procedure BeginFunction(p: symPtr);
begin
  { A label belongs to exactly one block, so the map is emptied per function.
    Sema numbers labels across the whole program, so a stale entry would never
    be *matched* -- this bounds what is kept, and is not what makes the block
    numbers right. }
  labelBlocks := nil;
  irProc := p;
  irLevel := p^.level;
  { The level-0 block this function belongs to, which is what FrameAt(0)
    names. For a procedure it is whatever module or program it is declared in,
    reached by walking the owners. }
  irRoot := p;
  while irRoot^.owner <> nil do irRoot := irRoot^.owner;
  nextReg := 0;
  designatorGuard := vgRead;
  nextBlock := 0;
  { AP 6.7.5.9: block numbers restart with the function, so the target an
    `exit` branches to has to as well. A module's block is emitted twice --
    an initialization and a finalization -- and each numbers its own. }
  p^.exitBlock := 0;
  StartBlock(NewBlock);
  { The arena level this activation inherits, read before anything can add to
    it (ADR-0111). Emitted in every function and not only in the ones that
    concatenate, because the emitter is sequential and the prologue is written
    before the body that would answer the question. It costs nothing where it
    is unused: a load from a global with no reader is deleted, which a call
    would not have been -- and that, rather than tidiness, is why the runtime
    shares this one datum as a global instead of a mark/release pair. }
  Def(strBase);
  writeln(ircode, 'load i32, ptr @pas_str_at')
end;

procedure EnterFrame(p: symPtr);
var l, d, e: symListPtr; link, slot, arg, half, actual, size, copy: str;
    actual2, chars: str;
    nohdr, arglen, shdr, closer: str; k, align: integer; comp: typePtr;
begin
  BeginFunction(p);
  { A level-0 block's record is a global: it has one activation, and a
    module's must outlive the function that initialises it (ADR-0053). A
    global is already zeroed, so its static link needs no store either. }
  if p^.level > 0 then begin
    writeln(ircode, '  %frame = alloca %frame', p^.irId:1);
    Def(link);
    writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
            ', ptr %frame, i32 0, i32 0')
  end;

  if p^.level = 0 then begin
    { The program and a module have no enclosing block, so the static link is
      never followed and there is nothing to store. }
    if not p^.isModuleSym then
      { The command line goes to the runtime before any file is opened: it is
        where `reset` looks for the name of an external file. }
      writeln(ircode, '  call void @pas_args(i32 %argc, ptr %argv)')
  end
  else begin
    write(ircode, '  store ptr %link, ptr ');
    PutOp(link);
    writeln(ircode);
    { A result that lives in memory was built by the caller, and its address
      arrives here. Sema made resultVar an skVarParam for exactly this, so
      storing the pointer in its slot is the whole of the binding -- every
      later `f := ...` and every read of the result variable goes through
      AddressOf, which dereferences an skVarParam without being told why. }
    if p^.kind = skFunc then
      if IsMemory(p^.stype) then begin
        Def(slot);
        writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
                ', ptr %frame, i32 0, i32 ',
                1 + p^.resultVar^.frameIndex:1);
        write(ircode, '  store ptr %res, ptr ');
        PutOp(slot);
        writeln(ircode)
      end;
    l := p^.params;
    k := 0;
    while l <> nil do begin
      StrClear(arg);
      StrAppend(arg, '%');
      StrAppend(arg, 'a');
      AppendInt(arg, k);
      Def(slot);
      writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
              ', ptr %frame, i32 0, i32 ', 1 + l^.sym^.frameIndex:1);
      if l^.sym^.descSchema <> nil then begin
        { The tuple is stored first, because everything about the size of what
          the address points at is asked of it -- including, for a value
          parameter, how much to copy. }
        actual := arg;
        d := l^.sym^.discSyms;
        while d <> nil do begin
          k := k + 1;
          StrClear(arg);
          StrAppend(arg, '%');
          StrAppend(arg, 'a');
          AppendInt(arg, k);
          { The last discriminant stored, kept for 6.7.3.2's string arm below:
            for that schema there is exactly one and it is the length. }
          actual2 := arg;
          Def(half);
          write(ircode, 'getelementptr inbounds ');
          PutDescType(l^.sym);
          write(ircode, ', ptr ');
          PutOp(slot);
          writeln(ircode, ', i32 0, i32 ', 1 + d^.sym^.discIndex:1);
          write(ircode, '  store ');
          PutLlType(d^.sym^.stype);
          write(ircode, ' ');
          PutOp(arg);
          write(ircode, ', ptr ');
          PutOp(half);
          writeln(ircode);
          d := d^.next
        end;
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutDescType(l^.sym);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 0');
        write(ircode, '  store ptr ');
        PutOp(actual);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        if StringValueFormal(l^.sym) then begin
          { 6.7.3.2's `string` value parameter. What arrived is not a string
            object but the pair EmitString builds -- the value's characters and
            the value's length -- because the actual is an *expression* here
            and a literal, a concatenation or a char has no object whose
            address could travel. So the object is built rather than copied:
            the length is already stored as the discriminant by the loop above,
            which is what makes the formal possess "the type produced from the
            schema string with the tuple having that length as its component",
            and the storage is 4 + that many bytes.

            No padding and no 6.4.6 refusal, unlike the fixed-capacity arm
            (ADR-0115): the capacity *is* the length, so the value fits exactly
            by construction and there is nothing to pad to.

            The alloca is in the prologue, which is the one place ADR-0102
            allows one: it is reached once per activation, and the storage dies
            with the frame. }
          Def(size);
          write(ircode, 'add i32 ');
          PutOp(actual2);
          writeln(ircode, ', 4');
          Def(copy);
          write(ircode, 'alloca i8, i32 ');
          PutOp(size);
          writeln(ircode, ', align 4');
          write(ircode, '  store i32 ');
          PutOp(actual2);
          write(ircode, ', ptr ');
          PutOp(copy);
          writeln(ircode);
          Def(chars);
          write(ircode, 'getelementptr inbounds i8, ptr ');
          PutOp(copy);
          writeln(ircode, ', i32 4');
          write(ircode, '  call void @llvm.memcpy.p0.p0.i32(ptr align 1 ');
          PutOp(chars);
          write(ircode, ', ptr align 1 ');
          PutOp(actual);
          write(ircode, ', i32 ');
          PutOp(actual2);
          writeln(ircode, ', i1 false)');
          write(ircode, '  store ptr ');
          PutOp(copy);
          write(ircode, ', ptr ');
          PutOp(half);
          writeln(ircode)
        end
        else if l^.sym^.kind <> skVarParam then begin
          { A value parameter is a copy, and this one's size is not known until
            the tuple is in place -- so the storage is claimed here rather than
            in the frame, and dies with the activation as the frame does. }
          comp := l^.sym^.stype;
          while comp^.kind = tyArray do comp := comp^.elem;
          align := LlAlign(comp);
          StrClear(nohdr);
          DynSize(l^.sym^.stype, nohdr, size);
          Def(copy);
          write(ircode, 'alloca i8, i32 ');
          PutOp(size);
          writeln(ircode, ', align ', align:1);
          write(ircode, '  call void @llvm.memcpy.p0.p0.i32(ptr align ',
                align:1, ' ');
          PutOp(copy);
          write(ircode, ', ptr align ', align:1, ' ');
          PutOp(actual);
          write(ircode, ', i32 ');
          PutOp(size);
          writeln(ircode, ', i1 false)');
          write(ircode, '  store ptr ');
          PutOp(copy);
          write(ircode, ', ptr ');
          PutOp(half);
          writeln(ircode)
        end
      end
      { ADR-0125: two arguments into one slot, exactly as a procedural
        parameter's pair is assembled -- the address first, then the count. }
      else if IsSlice(l^.sym^.stype) then begin
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(l^.sym^.stype);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 0');
        write(ircode, '  store ptr ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        k := k + 1;
        StrClear(arg);
        StrAppend(arg, '%');
        StrAppend(arg, 'a');
        AppendInt(arg, k);
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(l^.sym^.stype);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 1');
        write(ircode, '  store i32 ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode)
      end
      else if l^.sym^.kind = skProcParam then begin
        { Two arguments, one slot: the pair is assembled here and never exists
          as a value. }
        Def(half);
        write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 0');
        write(ircode, '  store ptr ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        k := k + 1;
        StrClear(arg);
        StrAppend(arg, '%');
        StrAppend(arg, 'a');
        AppendInt(arg, k);
        Def(half);
        write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 1');
        write(ircode, '  store ptr ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode)
      end
      else if (l^.sym^.kind <> skVarParam) and IsStringRep(l^.sym^.stype) then
      begin
        { 6.4.6's store, from the pair the caller passed into the slot this
          activation owns: shorter is padded with spaces, longer is refused,
          and the capacity is the *formal's* -- which is the whole reason the
          conversion happens here and not at the call (ADR-0115). It is the
          same call `s := expr` compiles to, so a value parameter and an
          assignment cannot disagree about 6.4.6. }
        k := k + 1;
        StrClear(arglen);
        StrAppend(arglen, '%');
        StrAppend(arglen, 'a');
        AppendInt(arglen, k);
        StrClear(shdr);
        EmitStringStoreValue(slot, l^.sym^.stype, arg, arglen, shdr,
                             l^.sym^.declLine, l^.sym^.declCol)
      end
      { AP 6.7.8.1: a task's channel parameter. The value crosses and the
        formal takes a *reference* to the channel -- which is the one thing
        this language lets two activations name, and the reason it may is
        that the object is the only one here with a mutex in it.

        The slot is an ordinary handle slot, so `send`, `receive` and every
        other reader of it need nothing added; what differs is the closer.
        An owned channel variable is released by `pas_chan_close`, which
        marks it closed and drops a reference; this one is released by
        `pas_chan_unref`, which drops the reference and does **not** close --
        because a worker that has finished must not close the channel its
        colleagues are still draining. Two closers for one type, and which
        one a variable gets says whether it owns the channel or shares it. }
      else if (l^.sym^.kind <> skVarParam) and IsHandle(l^.sym^.stype) then
      begin
        write(ircode, '  call void @pas_handle_init(ptr ');
        PutOp(slot);
        if IsChannel(l^.sym^.stype) then
          writeln(ircode, ', ptr @pas_chan_unref)')
        else begin
          { AP 6.7.8.1 (ADR-0302): a handle **moved** into a task, so the slot
            gets the type's own closer -- the task owns what it was given, and
            its block releases it exactly as the block that used to hold it
            would have. The spawning variable was emptied by `take` before the
            thread existed, so no closer runs twice. }
          StrClear(closer);
          AppendPool(closer, l^.sym^.stype^.handleAt,
                     l^.sym^.stype^.handleLen);
          write(ircode, ', ptr @');
          PutOp(closer);
          writeln(ircode, ')')
        end;
        write(ircode, '  call void @pas_handle_set(ptr ');
        PutOp(slot);
        write(ircode, ', ptr ');
        PutOp(arg);
        writeln(ircode, ')')
      end
      else if (l^.sym^.kind <> skVarParam) and IsStructured(l^.sym^.stype) then
      begin
        { A structured value parameter arrives as the caller's address; the
          copy that makes it a *value* parameter is made here, once, so the
          callee can write to it without the caller seeing the change. }
        align := LlAlign(l^.sym^.stype);
        write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ',
              align:1, ' ');
        PutOp(slot);
        write(ircode, ', ptr align ', align:1, ' ');
        PutOp(arg);
        writeln(ircode, ', i64 ', LlSize(l^.sym^.stype):1, ', i1 false)')
      end
      else begin
        write(ircode, '  store ');
        PutSlotType(l^.sym);
        write(ircode, ' ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode)
      end;
      k := k + 1;
      l := l^.next
    end
  end;

  { After the parameters, because a discriminant may be one of them, and
    before anything that could jump: the storage a dynamically sized variable
    stands for has to exist for the whole activation. }
  InitConstants(p);
  InitDynamicVars(p);
  InitInitialStates(p);
  InitFiles(p);
  InitDefers(p);
  InitTasks(p);
  { 6.2.3.6 orders the *commencements* of the modules that supply the
    main-program-block before the program's own, and written order is such an
    order -- 6.2.2.9 already puts a module-heading before everything that
    imports its interface, so a supplier is textually first.

    What comes before them here is only the program's own file and
    initial-state prologue, and no module can observe that: the program
    exports nothing, so nothing of its is nameable from a module. What a
    module *can* observe is `output`, which 6.11.4.2 requires to be open
    before the first access to it -- and opening it is what this prologue has
    just done. }
  if p = programSym then begin
    e := activeModules;
    while e <> nil do begin
      { Declared here and not only where its storage is reached. A module
        supplies the main-program-block whether or not this component names
        anything of it, so 6.2.3.6's commencement calls its activation either
        way -- and until this line the *only* thing registering an imported
        module was FrameGlobal, which runs when something of the module's is
        accessed. A module imported and not used was therefore called and never
        declared, and the emitted IR named a symbol it had not mentioned. }
      if e^.sym^.compiledElsewhere then NeedExternalModule(e^.sym);
      write(ircode, '  call void ');
      PutModulePart(e^.sym, true);
      writeln(ircode, '()');
      e := e^.next
    end
  end;
  JumpDispatch(p)
end;

{ AP 6.9.3.11's runner: the function `pas_defer_done` calls, and so the one a
  `goto` past this block and a `halt` reach its armed statements through.

  It takes the block's own frame rather than allocating one, which is what
  makes every name inside a deferred statement mean there what it meant where
  it was written: `irLevel` is the block's level, so FrameAt of that level is
  this parameter and FrameAt of any enclosing level walks the static chain
  from it exactly as the block's own code does. A level-0 block's frame is a
  global and the parameter goes unread, which costs a word and needs no second
  shape.

  The list is already in reverse source order (Sema pushes onto it), so
  walking it forwards is the order 6.9.3.11 requires. }
{ AP 6.9.3.12's wrapper: what `pthread_create` is actually given.

  A Pascal routine is a code address *and* the activation it runs under
  (ADR-0030) and C takes one word, so no procedure of this program can be
  handed to a thread library -- ADR-0201's finding 4, and the reason
  concurrency here had to be a language construct. This is the shape that
  answers it: the compiler emits one C-callable function per task, taking the
  argument block the spawn filled, and it unpacks the static link and the
  actuals and makes an ordinary call. Nothing the program wrote becomes a
  function pointer.

  A structured value parameter is passed by address, as it is at every other
  call site here -- and the address is the field *inside the block*, which the
  thread owns and frees, so the callee's prologue copies from storage that
  outlives the activation that spawned it. }
procedure EmitTaskWrapper(p: symPtr);
var l: symListPtr; a, fld, val, chars, slen, target: str; k: integer;
    ops, opTail, o: opndPtr;
begin
  if not p^.isTask then exit;
  writeln(ircode);
  write(ircode, '; the thread entry of ');
  WritePoolIr(p^.at, p^.len);
  writeln(ircode);
  write(ircode, 'define internal void ');
  PutTaskName(p);
  writeln(ircode, '(ptr %a) {');
  BeginFunction(p);
  StrClear(a);
  StrAppend(a, '%');
  StrAppend(a, 'a');
  { Every operand is computed first and the call is written afterwards, which
    the sequential emitter requires: `Def` begins an instruction, so a
    getelementptr written between two arguments would land inside the
    argument list. It is the shape EmitUserCall has, for the same reason. }
  ops := nil;
  opTail := nil;
  Def(val);
  write(ircode, 'load ptr, ptr ');
  PutOp(a);
  writeln(ircode);
  AppendOpnd(ops, opTail, val, true, nil);
  l := p^.params;
  k := 1;
  while l <> nil do begin
    Def(fld);
    write(ircode, 'getelementptr inbounds %targ', p^.irId:1, ', ptr ');
    PutOp(a);
    writeln(ircode, ', i32 0, i32 ', k:1);
    { A structured value parameter travels as an address everywhere in this
      emitter, so the field itself is what crosses -- and the block outlives
      this activation, which a frame slot of the spawning one would not. }
    { A variable-string or a text travels as a pointer and a length, which is
      the fourth of the things that are two words and may not depend on how a
      struct is passed (ADR-0051, ADR-0115). Loading the whole record and
      handing it over as one operand produced a call whose arguments did not
      match the callee's, and the block field is addressable, so the two
      operands come straight out of it -- the characters and the count that
      says how many of them the value has. }
    if IsStringType(l^.sym^.stype) or IsText(l^.sym^.stype) then begin
      Def(val);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(l^.sym^.stype);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode, ', i32 0, i32 0');
      Def(slen);
      write(ircode, 'load i32, ptr ');
      PutOp(val);
      writeln(ircode);
      Def(chars);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(l^.sym^.stype);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode, ', i32 0, i32 1');
      AppendOpnd(ops, opTail, chars, true, nil);
      AppendOpnd(ops, opTail, slen, false, intType)
    end
    else if IsStructured(l^.sym^.stype) and not IsHandle(l^.sym^.stype) then
      AppendOpnd(ops, opTail, fld, true, nil)
    { A channel's word, or a handle's -- the field holds one pointer either
      way and the prologue decides what the slot does with it (ADR-0302). }
    else if IsHandle(l^.sym^.stype) then begin
      Def(val);
      write(ircode, 'load ptr, ptr ');
      PutOp(fld);
      writeln(ircode);
      AppendOpnd(ops, opTail, val, true, nil)
    end
    else begin
      Def(val);
      write(ircode, 'load ');
      PutSlotType(l^.sym);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode);
      AppendOpnd(ops, opTail, val, false, l^.sym^.stype)
    end;
    k := k + 1;
    l := l^.next
  end;
  StrClear(target);
  AppendProcName(target, p);
  write(ircode, '  call void ');
  PutOp(target);
  write(ircode, '(');
  o := ops;
  while o <> nil do begin
    if o <> ops then write(ircode, ', ');
    if o^.asPtr then write(ircode, 'ptr') else PutLlType(o^.otype);
    write(ircode, ' ');
    PutOp(o^.text);
    o := o^.next
  end;
  writeln(ircode, ')');
  writeln(ircode, '  ret void');
  writeln(ircode, '}')
end;

{ AP 6.9.3.12's spawn-statement.

  Three things happen. The argument block is allocated by the runtime -- not
  by an `alloca`, which a spawn inside a loop would claim once per iteration
  (ADR-0102), and not by a frame slot, which would have to be sized to the
  largest block in the block before the frame type knows any of them. Its size
  comes from LLVM rather than from this compiler: a null-based getelementptr
  of one element is the type's size, so nothing here has an opinion about the
  layout it just asked for.

  Then it is filled: the static link the callee will run under, then each
  actual. A structured value is copied *into* the block, because the callee
  takes its address and the block outlives the activation that spawned it. A
  channel crosses as the one word it is, with a reference taken for the formal
  that is about to hold it -- taken here, before the thread exists, so it
  cannot race with the owner releasing the channel.

  Then the thread. `pas_tasks_spawn` takes ownership of the block and the
  thread frees it. }
procedure EmitSpawn;
var task: symPtr; l: symListPtr; arg: nodePtr;
    frame, set_, size, one, blk, fld, val, link, hdr: str;
    k: integer;
begin
  task := s^.spSym;
  if task = nil then exit;
  Def(one);
  write(ircode, 'getelementptr %targ', task^.irId:1, ', ptr null, i32 1');
  writeln(ircode);
  Def(size);
  write(ircode, 'ptrtoint ptr ');
  PutOp(one);
  writeln(ircode, ' to i64');
  EmitAt(s^.line, s^.col);
  Def(blk);
  write(ircode, 'call ptr @pas_tasks_alloc(i64 ');
  PutOp(size);
  writeln(ircode, ')');
  EmitAtDone;

  { The static link: a task declared at level L runs with the frame at level
    L-1 as its enclosing scope, which is the rule every other call here
    follows (ADR-0016). }
  FrameOf(task^.owner, link);
  write(ircode, '  store ptr ');
  PutOp(link);
  write(ircode, ', ptr ');
  PutOp(blk);
  writeln(ircode);

  arg := s^.spArgs;
  l := task^.params;
  k := 1;
  while (arg <> nil) and (l <> nil) do begin
    { AP 6.7.8.1 (ADR-0302): a handle that is not a channel is **moved** in.
      The actual is `take(v)` -- Sema admits nothing else here -- so the two
      calls of AP 6.4.12.7 become one: `pas_handle_take` empties the spawning
      variable *without* calling the closer, and the value goes into the
      argument block instead of into another slot. The prologue of the task
      is where `pas_handle_set` then happens, one thread later, which is why
      the order that matters for a move is not at risk here: nothing holds the
      value between the two but the block, and the block belongs to the
      thread about to be started. }
    if IsHandle(l^.sym^.stype) and not IsChannel(l^.sym^.stype) then begin
      EmitAddress(arg^.clArgs, val);
      Def(link);
      write(ircode, 'call ptr @pas_handle_take(ptr ');
      PutOp(val);
      writeln(ircode, ')');
      Def(fld);
      write(ircode, 'getelementptr inbounds %targ', task^.irId:1, ', ptr ');
      PutOp(blk);
      writeln(ircode, ', i32 0, i32 ', k:1);
      write(ircode, '  store ptr ');
      PutOp(link);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode)
    end
    else if IsChannel(l^.sym^.stype) then begin
      EmitAddress(arg, val);
      EmitAt(arg^.line, arg^.col);
      Def(link);
      write(ircode, 'call ptr @pas_handle_lend(ptr ');
      PutOp(val);
      writeln(ircode, ')');
      EmitAtDone;
      write(ircode, '  call void @pas_chan_ref(ptr ');
      PutOp(link);
      writeln(ircode, ')');
      Def(fld);
      write(ircode, 'getelementptr inbounds %targ', task^.irId:1, ', ptr ');
      PutOp(blk);
      writeln(ircode, ', i32 0, i32 ', k:1);
      write(ircode, '  store ptr ');
      PutOp(link);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode)
    end
    { A variable-string or a text, which is ADR-0302's finding met one
      construct over: it is `IsMemory` and not `IsStructured`, so it used to
      fall to the branch below that stores a *register* value and produced IR
      naming a global where a pointer belongs. And a copy of the element's
      size would be wrong even once the branch was right, a string value being
      as long as it is rather than as long as the formal -- so what happens
      here is an ordinary assignment into the block's field, which is where
      6.4.6 c)'s padding, the capacity check and AP 6.4.15.5's normalisation
      already live. `send` reaches the same answer through a temporary because
      the channel's element is not addressable until the runtime copies it;
      here the destination *is* the field. }
    else if IsStringType(l^.sym^.stype) or IsText(l^.sym^.stype) then begin
      Def(fld);
      write(ircode, 'getelementptr inbounds %targ', task^.irId:1, ', ptr ');
      PutOp(blk);
      writeln(ircode, ', i32 0, i32 ', k:1);
      StrClear(hdr);
      EmitStringStore(fld, l^.sym^.stype, arg, hdr)
    end
    else if IsStructured(l^.sym^.stype) then begin
      EmitAddress(arg, val);
      Def(fld);
      write(ircode, 'getelementptr inbounds %targ', task^.irId:1, ', ptr ');
      PutOp(blk);
      writeln(ircode, ', i32 0, i32 ', k:1);
      write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ',
            LlAlign(l^.sym^.stype):1, ' ');
      PutOp(fld);
      write(ircode, ', ptr align ', LlAlign(l^.sym^.stype):1, ' ');
      PutOp(val);
      writeln(ircode, ', i64 ', LlSize(l^.sym^.stype):1, ', i1 false)')
    end
    else begin
      EmitExpr(arg, val);
      Def(fld);
      write(ircode, 'getelementptr inbounds %targ', task^.irId:1, ', ptr ');
      PutOp(blk);
      writeln(ircode, ', i32 0, i32 ', k:1);
      write(ircode, '  store ');
      PutSlotType(l^.sym);
      write(ircode, ' ');
      PutOp(val);
      write(ircode, ', ptr ');
      PutOp(fld);
      writeln(ircode)
    end;
    k := k + 1;
    arg := arg^.next;
    l := l^.next
  end;

  FrameAt(irProc^.level, frame);
  TaskSetSlot(irProc, frame, set_);
  EmitAt(s^.line, s^.col);
  { AP 6.9.3.12 (ADR-0312): the two forms differ in one call. The named one
    answers the task record with a reference for the variable, and the
    unnamed one leaves the set holding the only one -- so a task that is not
    named costs exactly what it cost before, and neither form changes when
    the block is joined.

    The address of the target is taken **after** the thread is started, and
    that is deliberate: `pas_handle_set` releases what the variable held, and
    what it held is a reference and never a join, so nothing here can block
    while the argument block is half built. A spawn in a loop therefore drops
    the previous iteration's reference at the point the new activation
    replaces it, and the block's set goes on naming both. }
  if s^.spTarget = nil then begin
    write(ircode, '  call void @pas_tasks_spawn(ptr ');
    PutOp(set_);
    write(ircode, ', ptr ');
    PutTaskName(task);
    write(ircode, ', ptr ');
    PutOp(blk);
    writeln(ircode, ')');
    EmitAtDone
  end
  else begin
    Def(val);
    write(ircode, 'call ptr @pas_tasks_spawn_named(ptr ');
    PutOp(set_);
    write(ircode, ', ptr ');
    PutTaskName(task);
    write(ircode, ', ptr ');
    PutOp(blk);
    writeln(ircode, ')');
    EmitAtDone;
    EmitAddress(s^.spTarget, fld);
    write(ircode, '  call void @pas_handle_set(ptr ');
    PutOp(fld);
    write(ircode, ', ptr ');
    PutOp(val);
    writeln(ircode, ')')
  end
end;

procedure EmitDeferRunner(p: symPtr);
var e: nodeListPtr;
begin
  if p^.deferCount > 0 then begin
    writeln(ircode);
    write(ircode, '; deferred statements of ');
    WritePoolIr(p^.at, p^.len);
    writeln(ircode);
    write(ircode, 'define internal void ');
    PutDeferName(p);
    writeln(ircode, '(ptr %frame) {');
    BeginFunction(p);
    e := p^.defers;
    while e <> nil do begin
      EmitDeferRun(e^.dn);
      e := e^.next
    end;
    writeln(ircode, '  ret void');
    writeln(ircode, '}')
  end
end;

procedure EmitProcBody(d: nodePtr);
var p: symPtr; slot, res, nm: str;
begin
  p := d^.pdSym;
  writeln(ircode);
  { The Pascal name this function was written under, and the line it starts
    on. The *name* is a counter (AppendProcName says why it has to be), which
    makes -S output unreadable and leaves anything mapping a symbol back to
    the source with nothing to map through -- so the spelling is carried in a
    comment, where it costs no linkage and no assembler can act on it.

    tests/checks/coverage.py is what reads it: it maps the procedures a corpus
    run entered back to the ones this file declares, which cannot be inferred
    from the counter, since irId follows the order CodeGen walked the tree and
    not the order the source declares. }
  write(ircode, '; ');
  WritePoolIr(p^.at, p^.len);
  writeln(ircode, ' ', d^.line:1);
  { An exported procedure is externally visible, because 6.13 lets the
    component that calls it be another translation. }
  if p^.linkKind = lnkProc then write(ircode, 'define ')
  else write(ircode, 'define internal ');
  { A result that lives in memory is written into storage the caller supplied,
    so the function returns void and takes its address after the static link.
    It is named rather than numbered so the parameters keep the %a0.. they
    always had -- the two backends' assembler text is not compared (ADR-0025),
    only what it does. }
  if (p^.kind = skFunc) and not IsMemory(p^.stype) then PutLlType(p^.stype)
  else write(ircode, 'void');
  StrClear(nm);
  AppendProcName(nm, p);
  write(ircode, ' ');
  PutOp(nm);
  write(ircode, '(ptr %link');
  if p^.kind = skFunc then
    if IsMemory(p^.stype) then write(ircode, ', ptr %res');
  PutParamTypes(p^.params, true);
  writeln(ircode, ') {');

  EnterFrame(p);
  EmitStmt(d^.pdBody^.blBody);
  EmitExitTarget(p);
  CloseFiles(p);

  if (p^.kind = skFunc) and not IsMemory(p^.stype) then begin
    Def(slot);
    writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
            ', ptr %frame, i32 0, i32 ', 1 + p^.resultVar^.frameIndex:1);
    Def(res);
    write(ircode, 'load ');
    PutLlType(p^.stype);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode);
    write(ircode, '  ret ');
    PutLlType(p^.stype);
    write(ircode, ' ');
    PutOp(res);
    writeln(ircode)
  end
  else
    { A result that lives in memory went straight into the caller's storage,
      so there is nothing left to hand back. }
    writeln(ircode, '  ret void');
  writeln(ircode, '}');
  EmitDeferRunner(p);
  EmitTaskWrapper(p)
end;

procedure EmitProcs(b: nodePtr);
var d: nodePtr; gen: boolean;
begin
  d := b^.blProcs;
  while d <> nil do begin
    { AP 6.7.3.5: a generic routine has a block in the source and no
      translation of its own -- one compiled body cannot serve every T, which
      is the whole reason it is generic. What is emitted instead is its
      instantiations, and each of those is an ordinary procedure-declaration
      appended to this same list, so the walk below reaches them without being
      told they are special. }
    gen := false;
    if d^.pdSym <> nil then gen := d^.pdSym^.isGeneric;
    if (d^.pdBody <> nil) and not gen then begin
      EmitProcBody(d);
      EmitProcs(d^.pdBody)
    end;
    d := d^.next
  end
end;

procedure EmitDeclares;
begin
  writeln(ircode);
  { Only under --coverage, so an ordinary module names nothing it does not use
    and every program's IR is exactly what it was before the flag existed. }
  if covOpt then writeln(ircode, 'declare void @pas_cov_hit(i32)');
  if covOpt then
    writeln(ircode, 'declare void @pas_cov_branch(i32, i32, i32)');
  writeln(ircode, 'declare void @pas_runtime_error(ptr)');
  { ADR-0293: a trap's position. The inline checks pass theirs as arguments;
    a call into a runtime routine that may trap stores a record's address
    into the runtime's thread-local word first -- see EmitAt. Thread-local
    here as well as in the runtime, for pas_str_at's reason. }
  writeln(ircode, 'declare void @pas_runtime_error_at(ptr, ptr, i32, i32)');
  writeln(ircode, '@pas_at = external thread_local(initialexec) global ptr');
  writeln(ircode, 'declare void @pas_args(i32, ptr)');
  writeln(ircode,
          'declare void @pas_file_init(ptr, i32, i32, ptr, i32, i32, ',
          'i32, i32)');
  writeln(ircode, 'declare void @pas_file_done(ptr)');
  { AP 6.9.3.11 (ADR-0175) }
  writeln(ircode, 'declare void @pas_defer_init(ptr, ptr, ptr)');
  writeln(ircode, 'declare void @pas_defer_done(ptr)');
  { AP 6.4.12 (ADR-0174) }
  writeln(ircode, 'declare void @pas_handle_init(ptr, ptr)');
  writeln(ircode, 'declare i32 @pas_chan_close(ptr)');
  writeln(ircode, 'declare ptr @pas_chan_new(i64, i64)');
  writeln(ircode, 'declare void @pas_chan_ref(ptr)');
  writeln(ircode, 'declare i32 @pas_chan_unref(ptr)');
  writeln(ircode, 'declare void @pas_chan_send(ptr, ptr)');
  { AP 6.4.16.4 (ADR-0302) }
  writeln(ircode, 'declare void @pas_chan_shut(ptr)');
  writeln(ircode, 'declare ptr @pas_handle_peek(ptr)');
  writeln(ircode, 'declare ptr @llvm.stacksave.p0()');
  writeln(ircode, 'declare void @llvm.stackrestore.p0(ptr)');
  writeln(ircode, 'declare i32 @pas_chan_receive(ptr, ptr)');
  writeln(ircode, 'declare void @pas_tasks_init(ptr)');
  writeln(ircode, 'declare ptr @pas_tasks_alloc(i64)');
  writeln(ircode, 'declare void @pas_tasks_spawn(ptr, ptr, ptr)');
  writeln(ircode, 'declare ptr @pas_tasks_spawn_named(ptr, ptr, ptr)');
  writeln(ircode, 'declare void @pas_task_wait(ptr)');
  writeln(ircode, 'declare i32 @pas_select(ptr, i32, i32, i64)');
  writeln(ircode, 'declare i32 @pas_task_drop(ptr)');
  writeln(ircode, 'declare void @pas_tasks_join(ptr)');
  writeln(ircode, 'declare void @pas_handle_done(ptr)');
  writeln(ircode, 'declare void @pas_handle_set(ptr, ptr)');
  writeln(ircode, 'declare ptr @pas_handle_lend(ptr)');
  writeln(ircode, 'declare i32 @pas_handle_release_result(ptr)');
  writeln(ircode, 'declare ptr @pas_handle_take(ptr)');
  writeln(ircode, 'declare ptr @pas_jump_env(ptr)');
  writeln(ircode, 'declare void @pas_jump_done(ptr)');
  writeln(ircode, 'declare void @pas_jump_go(ptr, i32)');
  writeln(ircode, 'declare i32 @_setjmp(ptr) #0');
  writeln(ircode, 'attributes #0 = { returns_twice }');
  writeln(ircode, 'declare void @pas_reset(ptr)');
  writeln(ircode, 'declare void @pas_rewrite(ptr)');
  writeln(ircode, 'declare void @pas_get(ptr)');
  writeln(ircode, 'declare void @pas_put(ptr)');
  writeln(ircode, 'declare ptr @pas_buffer(ptr)');
  writeln(ircode, 'declare ptr @pas_new(i64)');
  writeln(ircode, 'declare void @pas_dispose(ptr)');
  writeln(ircode, 'declare void @pas_write_int(ptr, i64, i32)');
  writeln(ircode, 'declare void @pas_write_real(ptr, double, i32, i32)');
  writeln(ircode, 'declare void @pas_write_bool(ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_write_char(ptr, i8, i32)');
  writeln(ircode, 'declare void @pas_write_str(ptr, ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_writeln(ptr)');
  writeln(ircode, 'declare void @pas_page(ptr)');
  writeln(ircode, 'declare i8 @pas_read_char(ptr)');
  writeln(ircode, 'declare double @pas_read_real(ptr)');
  writeln(ircode, 'declare i64 @pas_read_int(ptr)');
  writeln(ircode, 'declare i64 @pas_read_int64(ptr)');
  writeln(ircode, 'declare void @pas_readln(ptr)');
  writeln(ircode, 'declare i32 @pas_eof(ptr)');
  writeln(ircode, 'declare i32 @pas_eoln(ptr)');
  writeln(ircode, 'declare i32 @pas_str_compare(ptr, ptr, i32)');
  writeln(ircode, 'declare double @pas_pow_real(double, double)');
  writeln(ircode, 'declare double @pas_pow_realint(double, i32)');
  writeln(ircode, 'declare i32 @pas_pow_int(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare i32 @llvm.abs.i32(i32, i1)');
  writeln(ircode, 'declare double @llvm.fabs.f64(double)');
  writeln(ircode, 'declare double @llvm.sqrt.f64(double)');
  writeln(ircode, 'declare double @llvm.sin.f64(double)');
  writeln(ircode, 'declare double @llvm.cos.f64(double)');
  writeln(ircode, 'declare double @llvm.log.f64(double)');
  writeln(ircode, 'declare double @llvm.exp.f64(double)');
  writeln(ircode, 'declare double @pas_atan(double)');
  { ISO/IEC 10206:1991 6.4.3.3's string operations. A string value is a pointer
    and a length, so every one of these takes the pair rather than an
    aggregate. }
  writeln(ircode, 'declare ptr @pas_str_char(i8)');
  writeln(ircode, 'declare ptr @pas_str_concat(ptr, i32, ptr, i32)');
  { ADR-0122: a string on its way to a foreign routine, NUL-terminated into
    the same arena. ADR-0123 is the other direction, and answers the flag
    rather than writing it -- the layout of an optional stays here. }
  writeln(ircode, 'declare ptr @pas_str_cstr(ptr, i32)');
  writeln(ircode, 'declare i32 @pas_cstr_take(ptr, i32, ptr)');
  { ADR-0187: the same shape for a record, the length being the size
    the record has here rather than anything the far side reports. }
  writeln(ircode, 'declare i32 @pas_rec_take(ptr, i64, ptr)');
  { ADR-0125's slice range, normalised to the base's own 1..n. }
  writeln(ircode, 'declare void @pas_slice_check(i32, i32, i32)');
  { How much of the runtime's string arena is in use -- the one thing this
    module names in the runtime that is not a function (ADR-0111). It is data
    rather than a mark/release pair so that the read every prologue makes is a
    load with no reader in a program that never concatenates, and is deleted;
    the calls it replaces would have been emitted and kept in every function of
    every program. `int` on that side, i32 here, asserted there. }
  { AP 6.9.3.12 (ADR-0268): the arena cursor is thread-local, because the
    arena is a stack of what the current chain of activations is using and a
    task is a second chain. The keyword has to be here as well as in the
    runtime -- a module that declared it as an ordinary global would read the
    wrong storage, and LLVM would not object. }
  { AP 6.9.3.12 (ADR-0268): the arena cursor is thread-local, because the
    arena is a stack of what the current chain of activations is using and a
    task is a second chain. The keyword has to be here as well as in the
    runtime -- a module declaring it as an ordinary global would read the
    wrong storage, and the linker says so rather than letting it pass. }
  writeln(ircode, '@pas_str_at = external thread_local global i32');
  writeln(ircode, 'declare i32 @pas_str_cmp_pad(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_cmp_exact(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_trimlen(ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_index(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare void @pas_str_slice_check(i32, i32, i32)');
  writeln(ircode, 'declare void @pas_str_substr_check(i32, i32, i32, i32)');
  writeln(ircode, 'declare void @pas_str_store_fixed(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare ptr @pas_str_pad(i32, ptr, i32)');
  { 6.7.5.5's auxiliary text variable, which the runtime owns }
  writeln(ircode, 'declare ptr @pas_str_read_begin(ptr, i32)');
  writeln(ircode, 'declare void @pas_str_read_end(ptr)');
  writeln(ircode, 'declare ptr @pas_str_write_begin()');
  writeln(ircode, 'declare i32 @pas_str_write_len(ptr)');
  writeln(ircode, 'declare ptr @pas_str_write_ptr(ptr)');
  writeln(ircode, 'declare void @pas_str_write_end(ptr)');
  writeln(ircode, 'declare void @pas_str_store_var(ptr, i32, ptr, i32)');
  { AP 6.4.15's four (ADR-0191). Declared unconditionally with the rest: the
    emitter writes one declaration list for every module, and a declaration
    nothing calls costs a line of IR and no code. }
  writeln(ircode, 'declare void @pas_text_store(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_text_length(ptr, i32)');
  writeln(ircode, 'declare ptr @pas_text_concat(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare void @pas_text_take(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_text_boundary(ptr, i32, i32)');
  writeln(ircode, 'declare i32 @pas_text_cmp(ptr, i32, ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_write_text(ptr, ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_str_store_char(ptr, ptr, i32)');
  writeln(ircode, 'declare void @pas_read_str(ptr, ptr, i32, i32)');
  { ISO/IEC 10206:1991 6.7.5.6 and 6.7.6.8's binding operations. }
  writeln(ircode, 'declare void @pas_bind(ptr, ptr, i32)');
  writeln(ircode, 'declare void @pas_unbind(ptr)');
  writeln(ircode, 'declare void @pas_halt(i32)');
  writeln(ircode, 'declare i32 @pas_binding_bound(ptr)');
  writeln(ircode, 'declare i32 @pas_binding_writable(ptr)');
  writeln(ircode, 'declare ptr @pas_binding_name(ptr)');
  writeln(ircode, 'declare i32 @pas_argcount()');
  writeln(ircode, 'declare ptr @pas_argument(i32)');
  writeln(ircode, 'declare i32 @pas_argument_len(i32)');
  writeln(ircode, 'declare i32 @pas_binding_namelen(ptr)');
  { ISO/IEC 10206:1991 6.7.5.8 and 6.7.6.9's time operations. }
  writeln(ircode, 'declare void @pas_gettimestamp()');
  writeln(ircode, 'declare i32 @pas_timestamp_field(i32)');
  writeln(ircode, 'declare ptr @pas_date(i32, i32, i32)');
  writeln(ircode, 'declare ptr @pas_time(i32, i32, i32)');
  { ISO/IEC 10206:1991 6.7.5.2 and 6.7.6.6's direct-access operations. }
  writeln(ircode, 'declare void @pas_seekread(ptr, i32)');
  writeln(ircode, 'declare void @pas_seekwrite(ptr, i32)');
  writeln(ircode, 'declare void @pas_seekupdate(ptr, i32)');
  writeln(ircode, 'declare void @pas_update(ptr)');
  writeln(ircode, 'declare void @pas_extend(ptr)');
  writeln(ircode, 'declare i32 @pas_position(ptr)');
  writeln(ircode, 'declare i32 @pas_lastposition(ptr)');
  writeln(ircode, 'declare i32 @pas_empty(ptr)');
  { ISO/IEC 10206:1991's complex functions. `abs` and `arg` are one libm call
    each; the six transcendentals are two runtime calls each, one per part,
    because a `double complex` returned across this boundary would put the C
    ABI's opinion about a two-double aggregate into an interface whose whole
    point is not to have one. }
  writeln(ircode, 'declare double @pas_hypot(double, double)');
  writeln(ircode, 'declare double @pas_atan2(double, double)');
  writeln(ircode, 'declare double @pas_csqrt_re(double, double)');
  writeln(ircode, 'declare double @pas_csqrt_im(double, double)');
  writeln(ircode, 'declare double @pas_cexp_re(double, double)');
  writeln(ircode, 'declare double @pas_cexp_im(double, double)');
  writeln(ircode, 'declare double @pas_cln_re(double, double)');
  writeln(ircode, 'declare double @pas_cln_im(double, double)');
  writeln(ircode, 'declare double @pas_csin_re(double, double)');
  writeln(ircode, 'declare double @pas_csin_im(double, double)');
  writeln(ircode, 'declare double @pas_ccos_re(double, double)');
  writeln(ircode, 'declare double @pas_ccos_im(double, double)');
  writeln(ircode, 'declare double @pas_carctan_re(double, double)');
  writeln(ircode, 'declare double @pas_carctan_im(double, double)');
  writeln(ircode, 'declare double @pas_cpow_re(double, double, double)');
  writeln(ircode, 'declare double @pas_cpow_im(double, double, double)');
  writeln(ircode, 'declare double @pas_cpowi_re(double, double, i32)');
  writeln(ircode, 'declare double @pas_cpowi_im(double, double, i32)');
  writeln(ircode, 'declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)');
  { A schematic formal parameter's copy has a length only the descriptor knows,
    and the message for a subscript outside its bounds names bounds the
    compiler never had. }
  writeln(ircode, 'declare void @llvm.memcpy.p0.p0.i32(ptr, ptr, i32, i1)');
  writeln(ircode, 'declare i', setBits:1, ' @llvm.ctpop.i', setBits:1,
          '(i', setBits:1, ')');
  writeln(ircode, 'declare void @pas_index_error_at(i32, i32, ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_range_error_at(i32, i32, ptr, i32, i32)');
  { 6.4.6 d): an assignment between two types produced from one schema with
    different tuples. The schema and the discriminant are named here; only the
    values come from the running program. }
  writeln(ircode, 'declare void @pas_disc_error_at(ptr, ptr, i32, i32, ptr, i32, i32)');
  { 6.7.2.5 compares strings of one length, and a schema's is a discriminant. }
  writeln(ircode, 'declare void @pas_length_error_at(i32, i32, ptr, i32, i32)')
end;

{ One global activation record. }
{ 6.13: the slots of this record another component may reach, each given a
  name of its own beside it. The record itself stays where it is and keeps its
  layout private -- an alias is the same address under a second, external
  symbol, so the importing translation needs to know neither the layout nor
  even that there is a frame. }
procedure EmitFrameAliases(p: symPtr);
var e: symListPtr; v, g: str;
begin
  FrameGlobal(p, g);
  e := p^.frameVars;
  while e <> nil do begin
    if (e^.sym^.linkKind <> lnkNone) and not e^.sym^.storageElsewhere then begin
      StrClear(v);
      StrAppend(v, '@');
      AppendLinkName(v, e^.sym);
      PutOp(v);
      write(ircode, ' = alias ');
      PutSlotType(e^.sym);
      write(ircode, ', ptr getelementptr inbounds (%frame', p^.irId:1,
            ', ptr ');
      PutOp(g);
      writeln(ircode, ', i32 0, i32 ', 1 + e^.sym^.frameIndex:1, ')')
    end;
    e := e^.next
  end
end;

{ 6.13's other side: everything this component names and another one defines.
  A variable is declared as i8 because nothing here knows its layout and only
  its address is ever taken; a module's record likewise, it being only a static
  link to pass. }
procedure EmitExterns;
var e, q: symListPtr; nm: str; first: boolean; cl: namePtr;
begin
  e := externVars;
  while e <> nil do begin
    StrClear(nm);
    StrAppend(nm, '@');
    AppendLinkName(nm, e^.sym);
    PutOp(nm);
    writeln(ircode, ' = external global i8');
    e := e^.next
  end;
  e := externMods;
  while e <> nil do begin
    write(ircode, '@frame.');
    WritePoolIr(e^.sym^.at, e^.sym^.len);
    writeln(ircode, ' = external global i8');
    write(ircode, 'declare void ');
    PutModulePart(e^.sym, true);
    writeln(ircode, '()');
    write(ircode, 'declare void ');
    PutModulePart(e^.sym, false);
    writeln(ircode, '()');
    e := e^.next
  end;
  { AP 6.4.12 (ADR-0174): the routine each handle-type names as its closer,
    declared with the shape fclose, closedir and pclose have -- unless an
    `external` heading of the program already declared the name, in which
    case that declaration stands and this one would be a second definition of
    one global, which LLVM refuses. The runtime calls it through the pointer
    either way, and the two shapes agree on every admitted target. }
  cl := handleClosers;
  while cl <> nil do begin
    if not ForeignDeclared(cl^.at, cl^.len) then begin
      StrClear(nm);
      AppendPool(nm, cl^.at, cl^.len);
      write(ircode, 'declare i32 @');
      PutOp(nm);
      writeln(ircode, '(ptr)')
    end;
    cl := cl^.next
  end;
  e := externProcs;
  while e <> nil do begin
    if ForeignDeclaredBefore(e) then
      { one linker symbol, one `declare` in this module (ADR-0263) }
    else begin
    write(ircode, 'declare ');
    { ADR-0123: a foreign function whose result is an optional answers a
      pointer, which the call site unpacks -- so the declaration says what C
      says and not what the Pascal type is. }
    if (e^.sym^.linkKind = lnkForeign) and (e^.sym^.kind = skFunc) and
       (IsOptional(e^.sym^.stype) or IsHandle(e^.sym^.stype)) then
      write(ircode, 'ptr')
    else if (e^.sym^.kind = skFunc) and not IsMemory(e^.sym^.stype) then
      PutLlType(e^.sym^.stype)
    else
      write(ircode, 'void');
    StrClear(nm);
    AppendProcName(nm, e^.sym);
    write(ircode, ' ');
    PutOp(nm);
    write(ircode, '(');
    { ADR-0121: no static link, and the parameter list is written here rather
      than by PutParamTypes -- that one always leads with a comma because
      every other declaration has the link in front of it, and the two types
      that cross this boundary need none of the shapes it knows about. }
    if e^.sym^.linkKind = lnkForeign then begin
      q := e^.sym^.params;
      first := true;
      while q <> nil do begin
        if first then first := false else write(ircode, ', ');
        { ADR-0129: one formal, two arguments -- the only place in this
          declaration list where the counts differ. }
        if IsSlice(q^.sym^.stype) then
          write(ircode, 'ptr, i64')
        { ADR-0122's two address rows print the same way, an opaque pointer
          being the whole of what either is on this side. }
        else if (q^.sym^.kind = skVarParam) or ForeignStringFormal(q^.sym) or
                IsHandle(q^.sym^.stype) then
          write(ircode, 'ptr')
        else
          PutLlType(q^.sym^.stype);
        q := q^.next
      end
    end
    else begin
      write(ircode, 'ptr');
      if e^.sym^.kind = skFunc then
        if IsMemory(e^.sym^.stype) then write(ircode, ', ptr');
      PutParamTypes(e^.sym^.params, false)
    end;
    writeln(ircode, ')')
    end;
    e := e^.next
  end
end;

procedure EmitFrameGlobal(p: symPtr);
var g: str;
begin
  FrameGlobal(p, g);
  PutOp(g);
  { A module's record is externally visible because a call into it takes its
    address as the static link; the program's is not. }
  if p^.isModuleSym then write(ircode, ' = global %frame', p^.irId:1)
  else write(ircode, ' = internal global %frame', p^.irId:1);
  writeln(ircode, ' zeroinitializer');
  EmitFrameAliases(p)
end;

{ The finalization calls, in the reverse of the list's order. The list is
  singly linked, so the recursion is what reverses it. }
procedure EmitFinis(e: symListPtr);
begin
  if e <> nil then begin
    EmitFinis(e^.next);
    write(ircode, '  call void ');
    PutModulePart(e^.sym, false);
    writeln(ircode, '()')
  end
end;

{ 6.11.1's module. Its heading and its block share one activation record, and
  the two `to` parts are its commencement and its finalization -- so it comes
  out as a pair of functions over one global frame, called by main around the
  program's own body. }
procedure EmitModule(m: nodePtr);
var p: symPtr;
begin
  p := m^.mdSym;
  writeln(ircode);
  write(ircode, 'define void ');
  PutModulePart(p, true);
  writeln(ircode, '() {');
  EnterFrame(p);
  if m^.mdInit <> nil then EmitStmt(m^.mdInit);
  EmitExitTarget(p);
  writeln(ircode, '  ret void');
  writeln(ircode, '}');
  { A module's block defers into its *initialization*: 6.11.4's
    module-initialization is the statement-part of the module-block, and the
    finalization shares the frame and the same epilogue. }
  EmitDeferRunner(p);

  { The finalization has its own function because 6.2.3.6 runs it after the
    main-program-block has terminated, not after the initialization. }
  writeln(ircode);
  write(ircode, 'define void ');
  PutModulePart(p, false);
  writeln(ircode, '() {');
  BeginFunction(p);
  if m^.mdFini <> nil then EmitStmt(m^.mdFini);
  EmitExitTarget(p);
  { A module's files are closed when its activation terminates, which is the
    same obligation a block's exit has and the same call that discharges it. }
  CloseFiles(p);
  writeln(ircode, '  ret void');
  writeln(ircode, '}');

  { After both definitions, because an alias names a global that must already
    have been written. }

  if m^.mdBlock <> nil then EmitProcs(m^.mdBlock)
end;

procedure RunCodeGen;
var m, d: nodePtr;
begin
  { No loop is being emitted yet. Sema refuses AP 6.7.5.10's break and
    6.7.5.11's continue outside one, so nothing reads these before a loop sets
    them; zero is what makes a defect in that reasoning an invalid module
    rather than a branch into another loop's blocks. }
  breakBlock := 0;
  contBlock := 0;
  factoryInto := nil;
  BindTo(ircode, outName);
  rewrite(ircode);
  { The layout LlSize and LlAlign model, stated so the assembler uses the same
    one. Without it LLVM falls back to its own defaults, and the two disagree
    the moment a type is wider than a machine word: an i256 is 16-aligned here
    and 8-aligned there, so a set in a record got 16-byte moves against an
    8-aligned frame. The hand-written rules were never wrong -- they were
    unstated, which is the same thing once someone else is doing the layout.

    Which target's, since ADR-0156. `clang` overrides both lines with its own
    target's and warns about the triple only -- so on the ordinary path these
    are advisory, and what they are for is every consumer that trusts the
    module instead: `llc` with no -mtriple, `opt`, and a reader. Being *absent*
    is what was a segfault; being another machine's is what --target= is for. }
  case targetIx of
    tgtX86: begin
      writeln(ircode, 'target datalayout = "e-m:e-p270:32:32-p271:32:32-',
                      'p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"');
      writeln(ircode, 'target triple = "x86_64-pc-linux-gnu"')
    end;
    tgtAarch64: begin
      writeln(ircode, 'target datalayout = "e-m:e-p270:32:32-p271:32:32-',
                      'p272:64:64-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-',
                      'S128-Fn32"');
      writeln(ircode, 'target triple = "aarch64-unknown-linux-gnu"')
    end
  end;
  writeln(ircode);
  nextProcId := 1;
  nextStr := 0;
  strTemps := 0;
  strHead := nil;
  posHead := nil;
  nextPos := 0;
  strTail := nil;
  nextConst := 0;
  constHead := nil;
  constTail := nil;
  nextOwnRel := 0;
  ownRels := nil;
  ownRelTail := nil;
  externVars := nil;
  externVarTail := nil;
  externProcs := nil;
  externProcTail := nil;
  externMods := nil;
  externModTail := nil;

  { The frame types come before any function that indexes one. Every module's
    comes too, and every procedure of every module is declared before any body
    is emitted: the main program may call an imported procedure, and a module
    written earlier may have been given its body later. }
  if progBlock <> nil then EmitFrameType(programSym);
  { Every module node carries its symbol by the time Sema is done, and codegen
    does not run when Sema found anything -- so there is nothing to guard
    against. A split module is two nodes sharing one symbol, which is what the
    irId test asks about. }
  m := progModules;
  while m <> nil do begin
    { 6.13: a module translated elsewhere gets no frame type here -- this
      translation has its heading, and a heading does not say what the block
      declares, so any layout built from it would be a different one. }
    if (m^.mdSym^.irId = 0) and not m^.mdSym^.compiledElsewhere then
      EmitFrameType(m^.mdSym);
    m := m^.next
  end;
  m := progModules;
  while m <> nil do begin
    if m^.mdHeading <> nil then DeclareProcs(m^.mdHeading);
    if m^.mdBlock <> nil then DeclareProcs(m^.mdBlock);
    m := m^.next
  end;
  if progBlock <> nil then DeclareProcs(progBlock);
  { AP 6.7.3.10's instantiations are in no block's procedure-part, so their
    frame types are named here -- before any function that indexes one, which
    is the rule every other frame type follows. }
  d := instDeclHead;
  while d <> nil do begin
    if d^.pdSym^.irId = 0 then EmitFrameType(d^.pdSym);
    DeclareProcs(d^.pdBody);
    d := d^.next
  end;

  { A level-0 activation record is a global (ADR-0053): the program has one
    activation and so has every module, and a module's must outlive the
    function that initialises it. }
  writeln(ircode);
  if progBlock <> nil then EmitFrameGlobal(programSym);
  m := progModules;
  while m <> nil do begin
    if (m^.mdBlock <> nil) and not m^.mdSym^.compiledElsewhere then
      EmitFrameGlobal(m^.mdSym);
    m := m^.next
  end;

  { Once per *module*, not once per component: a module written as a separate
    interface and implementation is two nodes sharing one symbol, and it has
    one activation record and one pair of functions. The block is the half
    that carries them. }
  m := progModules;
  while m <> nil do begin
    if (m^.mdBlock <> nil) and not m^.mdSym^.compiledElsewhere then
      EmitModule(m);
    m := m^.next
  end;

  { 6.13: a component with no main-program-declaration is every module it
    carries and nothing else -- no main, and so no activation of anything.
    The component holding the main-program-declaration is what commences
    these, and it may be another translation. }
  if progBlock = nil then begin
    { AP 6.7.3.10's instantiations, for the reason the program arm emits them:
      a generic imported from a module is instantiated by the translation that
      *named the types*, and a module is such a translation as much as a
      program is (ADR-0216). Without this the frame type is emitted -- the loop
      above it is shared -- the call is emitted, and the body is not, so the
      component assembles to a module referring to a function nobody defined.
      Nothing in this compiler could see that: the translation succeeds, and
      what fails is the *link*, one component later. }
    d := instDeclHead;
    while d <> nil do begin
      EmitProcBody(d);
      EmitProcs(d^.pdBody);
      d := d^.next
    end;
    { AP 6.4.14's release routines, before the globals for the globals'
      reason: they are what the module has left to emit, and a function
      definition cannot be nested inside the one that calls it. A module-only
      translation reaches this arm, so it needs the drain as much as a program
      does -- a module's own variables are released by its finalization. }
    EmitOwnRels;
    writeln(ircode);
    EmitGlobals;
    EmitPosGlobals;
    EmitConstGlobals;
    EmitExterns;
    EmitDeclares
  end
  else begin

  { main takes the command line, because ISO 7185 6.10 leaves it to the
    implementation to say how a program parameter names an external file and
    this one binds them to the arguments, in the order they are written. }
  writeln(ircode);
  writeln(ircode, 'define i32 @main(i32 %argc, ptr %argv) {');
  EnterFrame(programSym);
  EmitStmt(progBlock^.blBody);
  { AP 6.7.5.9 in the main-program-block terminates the *program*, and does it
    by the ordinary end: 6.2.3.6's finalizations below run, which is what
    distinguishes it from 6.7.5.7's halt. }
  EmitExitTarget(programSym);
  CloseFiles(programSym);
  { 6.2.3.6 read the other way round for termination: the activation of A
    terminates before the finalization of B, so the finalizations run in the
    reverse of the order the commencements did. }
  EmitFinis(activeModules);
  writeln(ircode, '  ret i32 0');
  writeln(ircode, '}');
  EmitDeferRunner(programSym);

  EmitProcs(progBlock);

  { AP 6.7.3.10's instantiations. A generic imported from a module is
    instantiated *here*, by the translation that named the types, and so is
    emitted here -- which is what lets 6.7.3.10 reach across 6.13 at all. }
  d := instDeclHead;
  while d <> nil do begin
    EmitProcBody(d);
    EmitProcs(d^.pdBody);
    d := d^.next
  end;

  EmitOwnRels;

  writeln(ircode);
  EmitGlobals;
  EmitPosGlobals;
  EmitConstGlobals;
  EmitExterns;
  EmitDeclares
  end
end;

{ --- resolving an interface name to a file -------------------------------- }

{ The directory `srcName` is in, with its separator, or nothing where the name
  has no separator in it at all -- which means the working directory, and an
  empty prefix is exactly that. Written out rather than taken from a library:
  this component imports ApTypes and ApFront and nothing else, and PasFS is
  not available to a compiler that has to build from the seed. }
{ The directory the source was named in, which is './' when it was named
  without one (ADR-0308). Answering the empty string there looked right and
  was not: AddPath drops an empty directory on purpose, so `pascalc prog.pas`
  searched nowhere for a sibling module while `pascalc ./prog.pas` found it,
  and ADR-0244's first search rule -- a program and its components written in
  one directory find each other -- was true of every spelling but the one a
  person types. }
function SourceDir: pathStr;
var k: integer;
begin
  k := length(srcName);
  while (k > 0) and (srcName[k] <> '/') do
    k := k - 1;
  if k = 0 then SourceDir := './'
  else SourceDir := substr(srcName, 1, k)
end;

{ One directory onto the search path, reported rather than dropped when the
  path is full (ADR-0110) and skipped when it is empty -- an empty entry in
  AFTERSCHOOL_PASCAL_PATH would name the working directory, which POSIX says
  of PATH and which is a surprise nobody wants from a compiler. }
procedure AddPath(d: pathStr);
begin
  if length(d) > 0 then
    if pathCount >= maxPaths then begin
      writeln('pascalc: more than ', maxPaths:1,
              ' import directories; ignoring ', d);
      errorSeen := true
    end
    else begin
      pathCount := pathCount + 1;
      { With the separator, always. SourceDir keeps the one it found and a
        directory written by a person has none, so the one place that can put
        it right is the one place both arrive at. }
      if d[length(d)] = '/' then pathDir[pathCount] := d
      else pathDir[pathCount] := d + '/'
    end
end;

{ The search path, once, after the command line has been read.

  The order is the decision (ADR-0244): the source's own directory, then the
  --import-path flags in the order written, then AFTERSCHOOL_PASCAL_PATH. The
  first is what makes a checkout compile with no configuration -- every
  component of a program written in one directory finds its neighbours -- and
  the last is what makes an installed library reachable from anywhere without
  a flag. A flag between them is how a caller overrides an installed module
  with one of its own, which is the only reason the middle exists. }
procedure BuildSearchPath;
var flags: array [1..maxPaths] of pathStr;
    n, i, at: integer; got: optEnvText; list: envText; piece: pathStr;
begin
  { The flags were pushed onto pathDir as they were read, because the source
    name may come after them on the command line and the source's directory
    has to be first. So they are taken off and put back behind it. }
  n := pathCount;
  for i := 1 to n do
    flags[i] := pathDir[i];
  pathCount := 0;
  AddPath(SourceDir);
  for i := 1 to n do
    AddPath(flags[i]);

  got := ExtGetenv('AFTERSCHOOL_PASCAL_PATH');
  if got <> nil then begin
    list := got^;
    at := 1;
    piece := '';
    while at <= length(list) do begin
      if list[at] = ':' then begin
        AddPath(piece);
        piece := ''
      end
      else if length(piece) >= strMax then begin
        { A single directory longer than a name is refused rather than
          truncated: a truncated path would name a directory that exists often
          enough to be worse than an error. }
        writeln('pascalc: a directory in AFTERSCHOOL_PASCAL_PATH is longer ',
                'than ', strMax:1, ' characters');
        errorSeen := true;
        piece := '';
        while (at <= length(list)) and (list[at] <> ':') do
          at := at + 1;
        at := at - 1
      end
      else
        piece := piece + list[at];
      at := at + 1
    end;
    AddPath(piece)
  end
end;

{ Is there a file at `path`? 6.7.5.6's bind is the only way a program can ask,
  and E.16 makes `bound` mean the name designates something that exists
  (ADR-0172). Nothing is opened: the file variable is bound, asked and left,
  and the reader binds it again when it has decided to read.

  `imports` is the variable, which is also what ReadOne reads through --
  binding is not opening, so asking about a dozen candidates costs nothing and
  disturbs nothing. }
function FileThere(path: pathStr): boolean;
var b: BindingType;
begin
  b := binding(imports);
  if b.bound then unbind(imports);
  b.name := path;
  bind(imports, b);
  FileThere := binding(imports).bound;
  unbind(imports)
end;

{ The file that supplies the interface spelled at `at`, `len` in the pool, or
  false where the search path has none.

  **The name is the file name**, folded, with `.pas` after it. That is a
  convention and it is stated as one: nothing here opens a directory and reads
  headings to find out what a file declares, because the compiler would then
  be parsing every Pascal source in every directory on the path to answer one
  question. Every module in `lib/` is already spelled this way, and Turbo
  Pascal's unit search was the same rule with a different extension.

  It is the **interface's** name that is looked for, because that is what an
  import writes. A module may export an interface under another name -- 6.11.1
  admits it and `tests/extended/components/counter.pas` does it -- and such a
  component is reachable by `--import` and not by the search path, which is
  the price of not opening every file to ask. `--import` is what it is for.

  The pooled spelling is the *folded* one, which is what makes this work at
  all: a program writing `import PasError` and one writing `import paserror`
  are the same program (6.1.2), and they must find the same file. }
function ResolveName(at, len: integer; var path: pathStr): boolean;
var i, k: integer; base, cand: pathStr; found: boolean;
begin
  base := '';
  for k := at to at + len - 1 do
    base := base + pool[k];
  found := false;
  i := 1;
  while (i <= pathCount) and not found do begin
    cand := pathDir[i] + base + '.pas';
    if FileThere(cand) then begin
      path := cand;
      found := true
    end;
    i := i + 1
  end;
  ResolveName := found
end;

{ 6.13: the already-translated components, taken in before the source, and
  whatever the search path had to add to them.

  Their module-headings become this translation's interfaces; nothing else of
  theirs is kept, and nothing of theirs is dumped -- the dumps are what this
  driver writes for the file it was given, and it was given the other one.

  **A component is read after everything it imports** (ADR-0244), which is
  what makes the list an activation order: 6.2.3.6 commences a supplying
  module before the one that imports it, and Sema hands CodeGen this list in
  the order the activations must happen. So ReadOne parses its file, resolves
  what that file imports, reads those *first*, and appends its own modules
  after them. Post-order, and the recursion is the whole of the ordering. }

{ Is the interface spelled at (at, len) exported by a module in `list`?

  The **interface** and not the module, and the two are different names:
  6.11.1 lets `module counter` export `counting`, and 6.2.2.2 makes each
  interface a region of its own -- one module may export several. So an import
  names an interface, and asking a module for its own spelling would send the
  search after a file that supplies something already in hand.
  `tests/extended/components/counter.pas` is the case that is not the same
  word. }
function SuppliedBy(list: nodePtr; at, len: integer): boolean;
var m, part: nodePtr; got: boolean;
begin
  got := false;
  m := list;
  while m <> nil do begin
    part := m^.mdExports;
    while part <> nil do begin
      if PoolSame(part^.epAt, part^.epLen, at, len) then got := true;
      part := part^.next
    end;
    m := m^.next
  end;
  SuppliedBy := got
end;

{ Where `path` sits in importName, or 0. A file resolved twice -- two modules
  importing a third -- is read once, and a file the command line already named
  is not read a second time under another name. }
function ImportIndex(path: pathStr): integer;
var i, at: integer;
begin
  at := 0;
  for i := 1 to importCount do
    if EQ(importName[i], path) then at := i;
  ImportIndex := at
end;

procedure ReadOne(idx: integer; var head, tail: nodePtr;
                  var count: integer); forward;

{ Everything `blk` imports that nothing has supplied yet, read before whatever
  is importing it. `own` is the module list of the file `blk` belongs to: a
  file declaring two modules where the second imports the first supplies its
  own name and must not go looking for a file. }
procedure ReadImportsIn(blk, own: nodePtr; var head, tail: nodePtr;
                        var count: integer);
var spec: nodePtr; path: pathStr; at: integer;
begin
  if blk <> nil then begin
    spec := blk^.blImports;
    while spec <> nil do begin
      if not (SuppliedBy(head, spec^.isAt, spec^.isLen)
              or SuppliedBy(own, spec^.isAt, spec^.isLen)) then
        if ResolveName(spec^.isAt, spec^.isLen, path) then begin
          at := ImportIndex(path);
          if at = 0 then
            if importCount >= maxImports then begin
              ErrorAt(spec^.line, spec^.col);
              writeln('more than ', maxImports:1,
                      ' program-components in one translation')
            end
            else begin
              importCount := importCount + 1;
              importName[importCount] := path;
              at := importCount
            end;
          if at > 0 then ReadOne(at, head, tail, count)
        end;
        { A name the search path has no file for is left alone. Sema reports
          it as an interface nothing supplies, which is the diagnostic a
          program that meant to pass --import wants to see, and it names the
          interface rather than a file nobody wrote. }
      spec := spec^.next
    end
  end
end;

procedure ReadOne;
var mine, mineTail, m: nodePtr; sawProgram: boolean;
begin
  if not wasRead[idx] then begin
    wasRead[idx] := true;
    curFile := importName[idx];
    curImportIdx := idx;
    BindTo(imports, importName[idx]);
    reset(imports);
    readingImports := true;
    { Appended after whatever the previous components left. A generic routine
      is re-read from a saved token position when a client instantiates it
      (AP 6.7.3.10), and until this the array was cleared between components,
      so a generic in an imported module had a position pointing at tokens
      that had been overwritten by the next source. }
    pos := tokCount + 1;
    Tokenize;
    mine := nil;
    mineTail := nil;
    sawProgram := false;
    if not errorSeen then begin
      ParseComponent(mine, mineTail, sawProgram);
      if not errorSeen then
        if sawProgram then begin
          ErrorAt(1, 1);
          writeln('an already-translated component may not declare a program');
          mine := nil;
          mineTail := nil
        end
    end;
    readingImports := false;
    curFile := srcName;
    curImportIdx := 0;
    depth := 0;
    aborted := false;

    { What this component imports, before this component. }
    m := mine;
    while m <> nil do begin
      ReadImportsIn(m^.mdHeading, mine, head, tail, count);
      ReadImportsIn(m^.mdBlock, mine, head, tail, count);
      m := m^.next
    end;

    m := mine;
    while m <> nil do begin
      m^.mdElsewhere := true;
      count := count + 1;
      m := m^.next
    end;
    if mine <> nil then
      if head = nil then begin
        head := mine;
        tail := mineTail
      end
      else begin
        tail^.next := mine;
        tail := mineTail
      end
  end
end;

{ Every program-component this translation read, in the order their
  activations must commence -- one to a line, behind the word `component`
  (ADR-0244).

  It is `--dump-imports`, and it exists because **resolving a name gives an
  interface and not an object**. The compiler reads a module's heading to
  check the program; something still has to translate that module and link the
  result, and until this there was no way for a build tool to learn what the
  compiler had found without reading Pascal itself -- which is the mistake
  ADR-0229, ADR-0230 and ADR-0239 each moved something off. `tools/pascalcc`
  is the caller, exactly as `lsp/pasls.pas` is `--dump-symbols`'s.

  The order is the module list's, which is dependency order, and a file
  declaring several modules is written once. The paths are the ones the
  compiler opened, so a relative `--import-path` yields a relative path and a
  caller in another directory gets what it can use. }
procedure DumpComponentList(mods: nodePtr);
var m: nodePtr; i, last: integer; seen: array [1..maxImports] of boolean;
begin
  for i := 1 to maxImports do
    seen[i] := false;
  m := mods;
  while m <> nil do begin
    last := m^.mdFileIdx;
    if (last >= 1) and (last <= importCount) then
      if not seen[last] then begin
        seen[last] := true;
        writeln('component ', importName[last])
      end;
    m := m^.next
  end
end;

{ The components the *command line* named, in the order it named them.
  Nothing to take in is the ordinary case -- every source in the corpus is a
  whole program-block. Each --import names one and is bound in turn, where the
  four-file interface took them concatenated because a program that cannot
  name a file cannot open several (ADR-0079, ADR-0081). }
procedure ReadTranslatedComponents(var head, tail: nodePtr;
                                   var count: integer);
var i, named: integer;
begin
  head := nil;
  tail := nil;
  count := 0;
  named := importCount;
  for i := 1 to named do
    ReadOne(i, head, tail, count)
end;

{ ...and the ones the *source* turned out to need, which cannot be known until
  it has been parsed. Called after ParseProgram and before Sema, with the
  source's own modules as what it already supplies. }
procedure ReadResolvedComponents(var head, tail: nodePtr;
                                 var count: integer);
var m, own: nodePtr;
begin
  own := progModules;
  ReadImportsIn(progBlock, own, head, tail, count);
  m := own;
  while m <> nil do begin
    ReadImportsIn(m^.mdHeading, own, head, tail, count);
    ReadImportsIn(m^.mdBlock, own, head, tail, count);
    m := m^.next
  end
end;

{ How much of each array sized for this compiler's own source is left
  (ADR-0148). Written after the whole pipeline has run, and after a failed one
  too: an exhausted array *is* the error, so the numbers are what a reader
  wants either way, and the gate that reads them has already failed on the
  exit status.

  Bare, with no `=== ` header. A header separates the three sections of
  --dump-all; a flag that writes one report writes it unadorned, which is the
  rule --dump-tokens follows and a test comment once asserted the reverse of.

  Two arrays, and not every fixed one -- an argued list rather than an
  omission. These two grow with the size of the source and creep toward their
  ceiling with nothing announcing it. maxImports is bounded by the command
  line, maxDepth and maxBlockDepth by nesting the parser refuses beyond, and
  strMax by one identifier: each of those reports what happened in the words of
  the thing that happened, at the moment it happens, so a headroom figure for
  them would measure something nobody is approaching unawares. }
{ --dump-predicates (ADR-0194). For every kind of type this compiler has, what
  each of its type-classifying predicates answers about a type of that kind.

  It exists because `kind-exhaustive` covers a `case ... of` over an
  enumeration and nothing else, and three defects in three increments lived in
  a **predicate** instead: `IsMemory` asking `IsVarString`, so that the
  relational operators took a text for a register value and emitted `icmp` on
  an aggregate; the code generator's comparison dispatch; and `EmitAssign`
  choosing the string store with `IsStringType`, so a text target fell through
  to a schema tuple-comparison and stopped the program (ADR-0191, ADR-0193).
  None of the three is a case-statement. All three were found by writing a
  program that used the new type.

  What this reports is the answer for a type of that kind with **nothing else
  set** -- a fresh `NewType(k)`, no element, no flags, no fields. That is the
  answer a predicate gives by default, and it is where all three defects were.
  A predicate that also reads a flag (`IsFallible`, `IsTextFile`,
  `IsOwnedPointer`) therefore reports its flag-clear answer, and one that looks
  through `Base` reports `tySubrange` as false. Both are stated rather than
  hidden: the gate's job is to make somebody look at every cell when a kind is
  added, not to know which answer is right.

  The list of predicates below is written out, so it is a second copy of what
  the source already says -- the shape ADR-0144 found a gate green over. The
  `predicate-kinds` gate reads the source for every
  `function Is...(t: typePtr): boolean` and requires this dump to name exactly
  those, so a predicate added without a row here fails rather than passing
  unseen. }
procedure DumpPredicates;
var kindTotal: integer; k: typeKind;

  { A padded literal without its padding. }
  procedure WriteTrim(w: msgLit);
  var n, i: integer;
  begin
    n := msgWidth;
    while (n > 1) and (w[n] = ' ') do n := n - 1;
    for i := 1 to n do write(w[i])
  end;

  procedure PutKindName(k: typeKind);
  begin
    case k of
      tyVoid: WriteTrim('tyVoid          ');
      tyInteger: WriteTrim('tyInteger       ');
      tyReal: WriteTrim('tyReal          ');
      tyBoolean: WriteTrim('tyBoolean       ');
      tyChar: WriteTrim('tyChar          ');
      tyEnum: WriteTrim('tyEnum          ');
      tySubrange: WriteTrim('tySubrange      ');
      tyArray: WriteTrim('tyArray         ');
      tyRecord: WriteTrim('tyRecord        ');
      tyPointer: WriteTrim('tyPointer       ');
      tyFile: WriteTrim('tyFile          ');
      tySet: WriteTrim('tySet           ');
      tyProc: WriteTrim('tyProc          ');
      tyComplex: WriteTrim('tyComplex       ');
      tyRestricted: WriteTrim('tyRestricted    ');
      tySlice: WriteTrim('tySlice         ');
      tyOptional: WriteTrim('tyOptional      ');
      tyHandle: WriteTrim('tyHandle        ');
      tyString: WriteTrim('tyString        ');
      tyText: WriteTrim('tyText          ');
      tyInt64: WriteTrim('tyInt64         ');
    end
  end;

  { One predicate against every kind. A procedural parameter is what makes
    this one routine rather than thirty-six (ISO 7185 6.6.3.1, ADR-0030). }
  procedure Row(name: msgLit; function P(t: typePtr): boolean);
  var k: typeKind; n: integer;
  begin
    n := 0;
    for k := tyVoid to tyInt64 do
      if P(NewType(k)) then n := n + 1;
    WriteTrim(name);
    write(' ', n:1, ' of ', kindTotal:1, ':');
    for k := tyVoid to tyInt64 do
      if P(NewType(k)) then begin
        write(' ');
        PutKindName(k)
      end;
    writeln
  end;

begin
  kindTotal := 0;
  for k := tyVoid to tyInt64 do kindTotal := kindTotal + 1;
  { The kinds themselves, in order, before the answers. Two things come of
    naming them: the table below is readable without the enumeration beside it,
    and a kind that no predicate is true of is *visible* rather than merely
    absent -- `tyVoid` is one, correctly, and a bare `tySubrange` is the other,
    because every ordinal predicate looks through Base() and a type of that
    kind with no host to look through answers no to all of them. }
  write('kinds ', kindTotal:1, ':');
  for k := tyVoid to tyInt64 do begin
    write(' ');
    PutKindName(k)
  end;
  writeln;
  Row('IsInteger       ', IsInteger);
  Row('IsReal          ', IsReal);
  Row('IsInt64         ', IsInt64);
  Row('IsComplex       ', IsComplex);
  Row('IsVarString     ', IsVarString);
  Row('IsText          ', IsText);
  Row('IsStringRep     ', IsStringRep);
  Row('IsOptional      ', IsOptional);
  Row('IsFallible      ', IsFallible);
  Row('IsHandleBirth   ', IsHandleBirth);
  Row('IsSlice         ', IsSlice);
  Row('IsNumeric       ', IsNumeric);
  Row('IsArith         ', IsArith);
  Row('IsBoolean       ', IsBoolean);
  Row('IsChar          ', IsChar);
  Row('IsEnum          ', IsEnum);
  Row('IsArray         ', IsArray);
  Row('IsRecord        ', IsRecord);
  Row('IsPointer       ', IsPointer);
  Row('IsFile          ', IsFile);
  Row('IsHandle        ', IsHandle);
  Row('IsChannel       ', IsChannel);
  Row('IsTask          ', IsTask);
  Row('IsOwned         ', IsOwned);
  Row('IsOwnedPointer  ', IsOwnedPointer);
  Row('IsAffine        ', IsAffine);
  Row('IsTextFile      ', IsTextFile);
  Row('IsNil           ', IsNil);
  Row('IsSet           ', IsSet);
  Row('IsProcType      ', IsProcType);
  Row('IsEmptySet      ', IsEmptySet);
  Row('IsRestricted    ', IsRestricted);
  Row('IsStructured    ', IsStructured);
  Row('IsMemory        ', IsMemory);
  Row('IsOrdinal       ', IsOrdinal);
  Row('IsCharArray     ', IsCharArray);
  Row('IsStringType    ', IsStringType);
  Row('IsStringOrChar  ', IsStringOrChar);
  Row('IsOrdered       ', IsOrdered);
  Row('IsEquatable     ', IsEquatable);
  Row('IsGeneric       ', IsGeneric);
end;

procedure DumpLimits;
begin
  writeln('pool ', poolLen:1, ' of ', poolMax:1);
  writeln('tokens ', tokCount:1, ' of ', tokMax:1);
  { Filled only because this flag sets `keepTrivia` (ADR-0279): on any other
    run it would be 0 of its bound and the answer would be a fact about the
    flags rather than about the source. }
  writeln('comments ', triviaCount:1, ' of ', triviaMax:1)
end;

{ The four questions the chain half asks of a shape the tree does not hold
  (ADR-0230). Each is a scan and each is a dump's own cost: --dump-dispatch is
  asked once per compilation and never on a path a program pays for. }

function ChainRecOf(n: nodePtr): chainPtr;
var c: chainPtr;
begin
  c := chainHead;
  while (c <> nil) and (c^.node <> n) do c := c^.next;
  ChainRecOf := c
end;

{ an if that is some other if's else-part continues a chain; one that is not
  begins one -- including an if that dispatches on nothing, which is how
  `if a then ... else if e^.kind = nkVar then ...` has its head in the arm
  that tests no tag at all }
function IsContinuation(n: nodePtr): boolean;
var c: chainPtr; found: boolean;
begin
  found := false;
  c := chainHead;
  while c <> nil do begin
    if c^.elsePart = n then found := true;
    c := c^.next
  end;
  IsContinuation := found
end;

function ChainArms(head: chainPtr): integer;
var c: chainPtr; n: integer;
begin
  n := 0;
  c := head;
  while c <> nil do begin
    n := n + 1;
    c := ChainRecOf(c^.elsePart)
  end;
  ChainArms := n
end;

{ does any arm of this chain test this constant of this enumeration? }
function ChainHas(head: chainPtr; t: typePtr; k: integer): boolean;
var c: chainPtr; tg: tagPtr; found: boolean;
begin
  found := false;
  c := head;
  while c <> nil do begin
    tg := tagHead;
    while tg <> nil do begin
      if (tg^.node = c^.node) and (tg^.ty = t) and (tg^.ord_ = k) then
        found := true;
      tg := tg^.next
    end;
    c := ChainRecOf(c^.elsePart)
  end;
  ChainHas := found
end;

{ The field the first test of this enumeration in this chain read, or a zero
  length where the tested side was not a field-designator. Reported so that a
  reader -- and the gate -- can tell a value asked for its own kind from a
  lookahead comparing a token against a few spellings. }
procedure ChainField(head: chainPtr; t: typePtr; var at, len: integer);
var c: chainPtr; tg: tagPtr;
begin
  at := 0;
  len := 0;
  c := head;
  while (c <> nil) and (len = 0) do begin
    tg := tagHead;
    while (tg <> nil) and (len = 0) do begin
      if (tg^.node = c^.node) and (tg^.ty = t) then begin
        at := tg^.fieldAt;
        len := tg^.fieldLen
      end;
      tg := tg^.next
    end;
    c := ChainRecOf(c^.elsePart)
  end
end;

function ChainNames(head: chainPtr; t: typePtr): integer;
var k, n: integer;
begin
  n := 0;
  for k := 0 to EnumCount(t) - 1 do
    if ChainHas(head, t, k) then n := n + 1;
  ChainNames := n
end;

{ --dump-dispatch (ADR-0229). Every case-statement in the compiled program
  whose selector is an enumeration, with the enclosing routine, the
  enumeration, and how many of that enumeration's constants the labels name.

  It exists because a case-statement with no matching label *stops the
  program* (ADR-0018), so a constant left off one is a crash and not a wrong
  answer -- and no other oracle here can see that. A missing arm is not a
  statement, so `line-coverage` cannot; a crash writes nothing, so no golden
  holds it; and while there was a second front end its counterpart was a
  `switch` with a `default`, so difftest had one side falling over rather than
  a disagreement.

  `tests/checks/kind_exhaustive.py` has asked this question since ADR-0145 by
  *parsing Pascal with regular expressions*, and doc/sop.md 7 already calls the
  source-parsing oracle the weaker of the two. What it cannot know is what the
  compiler knows for nothing: which types are enumerations, how many constants
  each has, and what the selector's type actually is. It recognises an
  enumeration constant by a naming convention -- two or three lower-case
  letters then a capital -- and a routine by a header regex.

  The pair `named of total` is the whole mechanism, as it is in the catalogue
  this replaces: a constant added to an enumeration moves every `total` over
  it, so every site naming a subset fails at once. That is exactly the moment
  `tyString` and then `tyOptional` needed a reader and did not get one.

  **What a dump does not do is judge an arm.** `tyOptional: StaticThroughout
  := true` names the constant and is wrong, and this reports it as covered.
  Moving the oracle out of a Python parser and into the compiler makes it
  exact about *which* constants are named; it does not make it a proof that
  naming them was right. ADR-0194 says the same of --dump-predicates. }
procedure DumpDispatch;
var d, q, q3, chainOut: dispatchPtr; r: rangePtr; lay: layoutPtr;
    c: chainPtr; n, k, named, fat, flen: integer; covered: boolean;
begin
  chainOut := nil;
  d := dispatchHead;
  while d <> nil do begin
    { the n-th case over this enumeration in this routine, counted the way the
      catalogue keys its entries -- by order of appearance, which is source
      order because Sema checks a block's statements in the order written }
    n := 1;
    q := dispatchHead;
    while q <> d do begin
      if (q^.ty = d^.ty) and
         PoolSame(q^.procAt, q^.procLen, d^.procAt, d^.procLen) then
        n := n + 1;
      q := q^.next
    end;
    write('case ');
    WritePool(d^.procAt, d^.procLen);
    write(':');
    if d^.ty^.aliasLen > 0 then WritePool(d^.ty^.aliasAt, d^.ty^.aliasLen)
    else write('?');
    write(':', n:1, ' names ', d^.named:1, ' of ', d^.total:1);
    if d^.hasOtherwise then write(' otherwise');
    write(' at ', d^.line:1, ':', d^.col:1);
    if d^.named < d^.total then begin
      write(' missing');
      for k := 0 to d^.total - 1 do begin
        covered := false;
        r := d^.ranges;
        while r <> nil do begin
          if (k >= r^.lo) and (k <= r^.hi) then covered := true;
          r := r^.next
        end;
        if not covered then begin
          write(' ');
          WriteOrdinalName(d^.ty, k)
        end
      end
    end;
    writeln;
    d := d^.next
  end;

  { The declared enumerations, so the dump describes its own denominator. A
    reader of it then needs no other source of truth about what an enumeration
    is or how many constants it has -- which is what lets the gate stop reading
    Pascal altogether (ADR-0230). }
  lay := enumHead;
  while lay <> nil do begin
    write('enum ');
    WritePool(lay^.at, lay^.len);
    writeln(' ', EnumCount(lay^.ty):1);
    lay := lay^.next
  end;

  { ADR-0230's half: the if-chains. A chain is a shape and not a node, so it is
    reconstructed here rather than recorded -- a head is an if that is no other
    if's else-part, and the chain is what the else-parts reach from there.

    A chain answers for each enumeration it tests *separately*, which is the
    ordinary case here and never happens to a case-statement: EmitString tests
    a node's kind and its type in one set of conditions. Two tests of one
    enumeration is the smallest thing a reader could have got wrong by leaving
    a third off, so a chain naming one constant of a type is not reported --
    that is a question, not a dispatch. }
  c := chainHead;
  while c <> nil do begin
    if not IsContinuation(c^.node) then
      if ChainArms(c) >= 2 then begin
        lay := enumHead;
        while lay <> nil do begin
          named := ChainNames(c, lay^.ty);
          if named >= 2 then begin
            n := 1;
            q3 := chainOut;
            while q3 <> nil do begin
              if (q3^.ty = lay^.ty) and
                 PoolSame(q3^.procAt, q3^.procLen, c^.procAt, c^.procLen) then
                n := n + 1;
              q3 := q3^.next
            end;
            new(q3);
            q3^.procAt := c^.procAt;
            q3^.procLen := c^.procLen;
            q3^.ty := lay^.ty;
            q3^.next := chainOut;
            chainOut := q3;
            write('chain ');
            WritePool(c^.procAt, c^.procLen);
            write(':');
            WritePool(lay^.at, lay^.len);
            write(':', n:1, ' on ');
            ChainField(c, lay^.ty, fat, flen);
            if flen > 0 then WritePool(fat, flen) else write('?');
            write(' names ', named:1, ' of ', EnumCount(lay^.ty):1);
            write(' at ', c^.line:1, ':', c^.col:1);
            if named < EnumCount(lay^.ty) then begin
              write(' missing');
              for k := 0 to EnumCount(lay^.ty) - 1 do
                if not ChainHas(c, lay^.ty, k) then begin
                  write(' ');
                  WriteOrdinalName(lay^.ty, k)
                end
            end;
            writeln
          end;
          lay := lay^.next
        end
      end;
    c := c^.next
  end;

  { The other half of the catalogue's question: a constant that *no*
    case-statement anywhere names. That is not a defect -- it is how a
    constant dispatched some other way looks -- but it is a fact worth
    holding, because a constant that stops being named is one something used
    to reach and no longer does.

    Walked over the *declared* enumerations rather than over the sites, and
    that distinction is the whole of why the declarations are collected at
    all: an enumeration no case-statement mentions has every constant unnamed
    and appears at no site to be found at -- `stdKind` was exactly that until
    ADR-0232 removed it, and a pass over the sites reported none of its
    three. }
  lay := enumHead;
  while lay <> nil do begin
    for k := 0 to EnumCount(lay^.ty) - 1 do begin
      covered := false;
      q := dispatchHead;
      while q <> nil do begin
        if q^.ty = lay^.ty then begin
          r := q^.ranges;
          while r <> nil do begin
            if (k >= r^.lo) and (k <= r^.hi) then covered := true;
            r := r^.next
          end
        end;
        q := q^.next
      end;
      if not covered then begin
        write('unused ');
        WritePool(lay^.at, lay^.len);
        write(' ');
        WriteOrdinalName(lay^.ty, k);
        writeln
      end
    end;
    lay := lay^.next
  end
end;

{ --dump-layout (ADR-0185). Every record type-definition the source made, with
  the size and alignment this compiler gives it and the offset of each of its
  fields.

  It exists because AP 6.7.7.6.2 lets a record cross to C, and what makes that
  sound is that RecordLayout *is* C's struct rule -- a claim about two
  compilers agreeing, which neither of them can check alone. This is one half
  of the check: the offsets this compiler computed, in a form a C probe can be
  generated from. `tests/checks/foreign_layout.py` is the other half.

  The arithmetic is ArmLayoutAt's, written a second time rather than shared,
  and that is the one thing to be careful of: ArmLayoutAt accumulates a size
  and never names an offset, so there is no offset in it to return. Moving one
  out would change the routine every whole-record copy's length comes from.
  The loop below is therefore the same three lines, and `foreign_layout.py`
  compares its answers against a C compiler on every run -- so the copy cannot
  drift without the gate saying so, which is what makes a second copy
  acceptable here.

  A variant part is reported as a line and not walked: an arm's storage is
  this compiler's own shape and no C union is laid out from it, which is why
  6.7.7.6.2 refuses such a record at the boundary in the first place. }
procedure DumpLayout;
var lay: layoutPtr; f: fieldPtr; align, a: integer; off, size: int64;
begin
  lay := layoutHead;
  while lay <> nil do begin
    RecordLayout(lay^.ty, size, align);
    write('record ');
    WritePool(lay^.at, lay^.len);
    writeln(' size=', size:1, ' align=', align:1);
    off := 0;
    f := lay^.ty^.fields;
    while f <> nil do begin
      a := LlAlign(f^.ftype);
      off := RoundUp(off, a);
      write('  field ');
      WritePool(f^.at, f^.len);
      writeln(' offset=', off:1, ' size=', LlSize(f^.ftype):1,
              ' align=', a:1);
      off := off + LlSize(f^.ftype);
      f := f^.next
    end;
    if lay^.ty^.variants <> nil then
      writeln('  variants');
    lay := lay^.next
  end
end;

{ The table the `use` lines' `declfile` field indexes into: the source, then
  the components this translation read, in the order --dump-imports gives them
  (ADR-0246). It comes first because a caller reading the stream in order must
  be able to resolve a defining-point as soon as it sees one, and because the
  list is complete by now -- resolution has run and every import is known.

  A defining-point in an --import is reported with the path this compiler
  opened, which is the path a caller can open too. That is what makes
  go-to-definition cross a file at all: the alternative is a server that can
  only answer about the document in front of it, which is the question an
  editor asks least. }
procedure DumpUseFiles;
var i: integer;
begin
  writeln('file 0 ', srcName);
  for i := 1 to importCount do
    writeln('file ', i:1, ' ', importName[i])
end;

{ The pipeline. What it *writes* depends on which dumps were asked for; what
  it *runs* is decided the same way, because a dump flag stops at the stage it
  names -- `--dump-tokens` does not parse, which is how the C++ driver behaves
  and the only way a dump of a stage can be taken of a program the next stage
  would reject.

  `--dump-all` is the exception and runs everything, including the code
  generator: that was the form selfhost/difftest.sh compared, and generating
  the IR on every file in the corpus is free coverage of the backend --
  which is why tests/checks/coverage.py still sweeps it that way now that the
  harness is gone (ADR-0232). }
procedure Compile;
var earlier, earlierTail: nodePtr; earlierCount: integer; go, whole: boolean;
begin
  { --dump-limits asks about a whole run, so it runs the whole pipeline exactly
    as --dump-all does. Without this `--dump-tokens --dump-limits` would report
    the pool as the lexer alone had left it and call that the answer. }
  whole := dumpAllOpt or dumpLimitsOpt or dumpLayoutOpt or dumpPredsOpt or
           dumpDispatchOpt;
  BuildSearchPath;
  ReadTranslatedComponents(earlier, earlierTail, earlierCount);

  { --- lex ---------------------------------------------------------------- }
  if dumpAllOpt then writeln('=== tokens');
  mainTokBase := tokCount + 1;
  pos := mainTokBase;
  Tokenize;
  if dumpTokensOpt then DumpTokens;
  if dumpTriviaOpt then DumpTrivia;
  { After the trivia dump and not before it, so `--format --dump-trivia` reads
    as the report and then the program. Both rewind the source cursor. }
  if formatOpt and not errorSeen then begin
    SetFormatRange(rangeLo, rangeHi);
    FormatSource
  end;
  { A dump flag stops at the stage it names, which is how the C++ driver
    behaves -- and the only way a stage can be dumped for a program the next
    stage would reject. This source is Extended Pascal, which has no early
    return -- AP 6.7.5.9's exit is the dialect's and a conformance mode has
    nothing like it -- so "stop" is a flag every
    later stage is guarded by. `--dump-all` is not a stop: it is the whole
    pipeline with every section shown, and `--dump-limits` is not a stop for
    the same reason by a different route -- it shows no section at all and
    needs every stage to have run before its question has an answer. }
  go := not ((dumpTokensOpt or dumpTriviaOpt or formatOpt) and not whole);

  { --- parse -------------------------------------------------------------- }
  if go then begin
    if dumpAllOpt then writeln('=== ast');
    { Lexing is where this stops when the lexer found anything wrong, so a
      source with a bad token is reported on its diagnostics and not on a tree
      built from tokens that were never valid. }
    if not errorSeen then begin
      ParseProgram;
      { What the source imports is knowable only now, so the search path is
        walked here and whatever it finds joins the components the command
        line named (ADR-0244). After ParseProgram and before the tree is
        touched: reading a component parses one, and ParseComponent is what
        keeps that from overwriting the answer just obtained. }
      if not errorSeen then
        ReadResolvedComponents(earlier, earlierTail, earlierCount);
      { In front of this component's own modules, because 6.2.2.9 puts a
        module-heading before everything that imports its interface and a
        separately translated one is earlier still. }
      if earlier <> nil then begin
        earlierTail^.next := progModules;
        progModules := earlier;
        if progModuleTail = nil then progModuleTail := earlierTail;
        progMainIndex := progMainIndex + earlierCount
      end;
      if (not errorSeen) and (dumpAstOpt or dumpAllOpt) then begin
        annotate := false;
        DumpProgram
      end;
      { --dump-symbols asks the parse stage and stops there, which is not an
        economy: an outline is what an editor draws while the file is *wrong*,
        so every question Sema could answer is one that would take the answer
        away at the moment a reader wants it (ADR-0239). }
      if (not errorSeen) and dumpSymbolsOpt then DumpSymbols;
      { After the resolution above, which is where the list comes from. }
      if (not errorSeen) and dumpImportsOpt then DumpComponentList(earlier)
    end;
    go := not ((dumpAstOpt or dumpSymbolsOpt or dumpStmtsOpt or
                dumpImportsOpt) and not whole)
  end;

  { --- check -------------------------------------------------------------- }
  if go then begin
    if dumpAllOpt then writeln('=== sema');
    if not errorSeen then begin
      if dumpUsesOpt then DumpUseFiles;
      RunSema;
      if (not errorSeen) and (dumpSemaOpt or dumpAllOpt) then begin
        annotate := true;
        DumpProgram
      end
    end;
    { The `use` lines were written by Sema as it resolved each name, so there
      is nothing to do here; what this says is the *ending*. Every other dump
      is guarded by `not errorSeen` because it shows a stage's result and a
      stage that failed has none -- but this dump is not one answer, it is one
      line per name, and a source Sema rejected has resolved every name but
      the ones it complained about. Stopping here rather than emitting IR is
      all that is left, and it is unconditional for the same reason
      --dump-symbols is: whatever a caller asked this question for, it did not
      ask for an object file. }
    go := not ((dumpSemaOpt or dumpUsesOpt or dumpWordsOpt) and not whole)
  end;

  { --- emit --------------------------------------------------------------- }
  { The IR is the compiler's *product*, not a dump, so it goes to a file of its
    own rather than to a fourth section: it has to be assembled and linked, and
    two backends' assembler text cannot be diffed the way three stages of a
    tree can (ADR-0025). }
  if go and not errorSeen then RunCodeGen;

  { --- and how full it left the arrays ------------------------------------ }
  if dumpLimitsOpt then DumpLimits;
  { ...and what its type predicates say about each kind. Reported after a
    whole run for consistency with the two dumps beside it, though it asks
    nothing of the program: the subject is the compiler (ADR-0194). }
  if dumpPredsOpt then DumpPredicates;
  { --- and what it decided a record looks like ---------------------------- }
  if dumpLayoutOpt and not errorSeen then DumpLayout;
  if dumpDispatchOpt and not errorSeen then DumpDispatch
end;
begin
  ParseArgs;
  newTuple := nil;

  { A command line that did not parse has already said why, or has written the
    option list because -h asked for it. Either way there is nothing to
    translate, and this source's standard has no early return (AP 6.7.5.9's
    exit belongs to the dialect) -- so the whole of the work is
    inside the test. }
  if argsOk then begin
    curFile := srcName;
    { The two facts NoteUse asks: whether to write at all, and which file
      `curFile` has to equal for the text to be this document's. Set before
      anything is read, because a defining-point in an --import is declared
      while curFile names that import. }
    notingUses := dumpUsesOpt;
    if dumpWordsOpt then WantWords;
    notingStmts := dumpStmtsOpt;
    mainFile := srcName;
    BindTo(source, srcName);
    Compile
  end;

  { Report the outcome to whatever invoked this. A conforming Pascal program
    cannot -- 6.7.5.7's halt takes no parameters and there is no other control
    procedure -- so the status is the one extension this compiler needs and the
    only one it adds beyond the underscore in an identifier (ADR-0084). Without
    it `pascalc bad.pas && clang ...` runs the linker on a file that was never
    written. }
  if errorSeen or argsBad then halt(1)
end.
