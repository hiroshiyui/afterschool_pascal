{ pasls -- a Language Server Protocol server for Afterschool Pascal, written
  in Afterschool Pascal.

  `doc/roadmap.md` proposes this program as **the caller**: the thing large
  enough to say whether the dialect is pleasant to write in, which no gate
  here can measure. It is not part of the compiler and it is not a feature --
  it invokes `pascalc` as a separate process and reads what it wrote, exactly
  as an editor would.

  This is the first increment and it does one thing: it answers
  `textDocument/publishDiagnostics` for every document a client opens or
  changes. The roadmap's sentence for it is *"a server that does nothing
  whatever but publishDiagnostics is producing findings on the first day"*.

  **Four decisions, and each of them is a thing a reader will otherwise
  wonder about.**

  **It declares no program-parameters, and that is a guard rather than an
  omission.** Everything this program writes on standard output is a protocol
  message framed by `PasLsp`, and `output` is a buffered Pascal text file
  whose flushes interleave unpredictably with a descriptor write -- one of
  this chapter's own findings. A program that does not name `output` cannot
  call `writeln` at all: 6.9.1 makes the default file a program-parameter, so
  a stray one is a compile-time error instead of a corrupted frame. What this
  program has to say to a person goes to `StdErr` through `Note`.

  **The document store is a vector searched linearly, and not `PasContainer`'s
  map.** `MapKey` is 63 characters and a document URI is not a key of that
  size -- `file:///home/someone/a/project/src/thing.pas` is past it before the
  file name starts. A handful of open documents is what an editor has, so the
  search costs nothing; the finding is recorded in the roadmap rather than
  worked around silently.

  **The compiler reads a file, so the document has to become one.** An editor
  holds a buffer that has never been saved, which is the whole reason a server
  exists, so the text is written to a scratch file and the scratch file is
  what `pascalc` is pointed at. The path is one fixed name, overridable with
  `PASLS_SCRATCH`, and that is a limitation with a cause: there is no `getpid`
  anywhere in this tree, no `mkstemp`, and nothing in `PasFS` that answers a
  temporary name -- so a program wanting a name no other process will choose
  cannot make one. Two servers sharing a `TMPDIR` would share the file.

  **The positions are the compiler's, converted once.** `ErrorAt` counts lines
  and columns from one; LSP counts both from zero, and `PasLspDiag.DiagJson`
  is the only place that subtracts. The protocol's character unit is a UTF-16
  code unit by default and the compiler's column counts **bytes**, so the same
  routine converts that too -- which is why this server has to hand it the
  source *line* along with the diagnostic, the compiler having reported a
  position and not a source. Finding the line means walking the stored
  document for every diagnostic, which is the price of holding the text as
  bytes and is paid in a place where there are never many.

  **It negotiates the encoding, and negotiating is what makes the conversion
  honest.** 3.17 lets a client offer `positionEncodings` and a server pick
  one; this one takes `utf-8` when it is offered, because the compiler's
  column is then already right and converting would be the defect. A client
  that says nothing gets `utf-16`, which is the protocol's default and the
  case the conversion exists for. Either way the answer is echoed in
  `positionEncoding` so the client is never guessing. }
program pasls;

import PasError;
       PasFS;
       PasIO;
       PasEnv;
       PasStrVec;
       { 6.11.3's import-clause, and the reason for it is a collision rather
         than a preference: PasDir exports `Close` and `NameMax`, which PasIO
         and PasJson also export. `List` is the whole of what this program
         wants from it, and naming that is cheaper than qualifying every use
         of the other two. }
       PasDir only (List);
       { ADR-0120's ParseInt, for the four numbers on a --dump-symbols line.
         A second reader of decimal digits written here would be a second
         reader free to disagree with the one this tree already has -- and
         the one it has is the one AP 6.5.6's empty substring was found
         through (ADR-0219).

         `only` for the same reason PasDir has one, which is now a pattern
         and not an incident: PasParse exports `ResultText` and so does
         PasError. Four names are the whole of what this program wants. }
       PasParse only (ParseMax, ParseLine, ParseInt, IntOr);
       PasProcess;
       PasContainer;
       PasJson;
       PasLsp;
       PasLspDiag;

const
  { What one compilation may say. Whatever does not fit is read and dropped by
    `Capture`, so the compiler still runs to its end and the exit code is
    still its own; a program with more diagnostics than this loses the tail. }
  CaptureMax = 16384;

  { Full synchronisation: the client sends the whole document on every change.
    Incremental sync would need the client's own position arithmetic, which is
    in UTF-16 code units, and this server has no view in those. }
  SyncFull = 1;

  { LSP's DiagnosticSeverity. This compiler emits errors and nothing else. }
  SeverityError = 1;

  { JSON-RPC's own codes, from the specification's table. }
  MethodNotFound = -32601;

  { LSP's SymbolKind, from the specification's table, for the ten words
    --dump-symbols answers in (ADR-0239). The compiler answers about *Pascal*
    and this is where the protocol's numbering lives, which is the whole
    reason it does not answer in numbers: a table owned by a third party
    changing under a Pascal compiler would be a version of this protocol
    baked into it. }
  SkModule = 2;
  SkClass = 5;
  SkField = 8;
  SkEnum = 10;
  SkFunction = 12;
  SkVariable = 13;
  SkConstant = 14;
  SkEnumMember = 22;
  SkStruct = 23;

  { How deeply an outline is followed. Declarations nest through nested
    procedures and this is far past anything a person writes -- the compiler's
    own deepest is three -- but it is a bound and so it is *reported* when it
    is met rather than applied in silence (ADR-0110). Everything past it is
    attached at this depth, which keeps the answer well-formed. }
  SymDepthMax = 64;

  { How far below the workspace root a `.components` file is looked for. This
    tree is three deep at its deepest (`tests/dialect/components/`); eight is
    room without a checkout of somebody's whole home directory being walked
    because they opened one file in it. }
  WalkDepthMax = 8;

type
  { A URI as far as this program can hold one. It is `JsonLine` deliberately
    and not a wider string of its own: `DiagPublish` takes one, so a URI this
    program could hold and that module could not would be a truncation at the
    boundary rather than a refusal at the door. 255 is short for a URI and
    that is a finding, not a design. }
  DocUri = JsonLine;

  { What the client last told us a document contains. The text is a `JsonChars`
    because a source file is not a line and has no bound worth naming. }
  Document = record
    uri: DocUri;
    text: JsonChars
  end;

  DocVec = ^Vec(Document);

  CaptureText = string(CaptureMax);

var
  reader: LspReader;
  docs: DocVec;
  running: boolean;
  { What a Position.character counts in this session. The protocol's default
    until `initialize` says otherwise, which is also what a client that offers
    nothing means. }
  encoding: PosEncoding;
  { The workspace, from `initialize`, or empty where the client named none.
    Only `.components` files are looked for under it. }
  rootPath: PathName;
  { The scratch file, bound to a computed name. 6.7.5.6's bind is the only way
    a program names a file while it is running. }
  scratchFile: bindable text;
  scratchPath: EnvText;
  compilerCmd: EnvText;

{ --- talking to a person -------------------------------------------------- }

{ Standard error, which is the only stream a person reads here. Nothing on
  standard output is for one. }
procedure Note(what: IOLine);
var junk: ErrorCode;
begin
  junk := WriteText(StdErr, 'pasls: ' + what + chr(10))
end;

{ --- talking to the client ------------------------------------------------ }

{ Render one message and frame it. The document is the caller's and is not
  freed here -- a caller that built a reply out of borrowed parts frees the
  whole of it once, afterwards. }
procedure Send(msg: JsonPtr);
var out: JsonChars;
    e: ErrorCode;
begin
  JsonCharsNew(out);
  JsonRender(msg, out);
  e := LspWrite(StdOut, out);
  if e <> errNone then Note('could not write a message: ' + ErrorText(e));
  JsonCharsFree(out)
end;

{ A copy of a request's id, which a response must echo *unchanged in kind*:
  an integer id comes back an integer and a string id a string. The copy is
  needed because the request is freed as soon as it is dispatched. }
function CopyId(id: JsonPtr): JsonPtr;
var s: JsonLine;
begin
  case JsonKindOf(id) of
    jsNumber:
      CopyId := JsonNewInteger(JsonIntegerOr(id, 0));
    jsString:
      begin
        if JsonTextInto(id, s) <> errNone then s := '';
        CopyId := JsonNewText(s)
      end;
    { A request with no id is a notification and gets no response at all, so
      this arm is reached only for a malformed one. Null is what the
      specification says to answer when the id cannot be determined. }
    otherwise
      CopyId := JsonNewNull
  end
end;

{ The envelope every response shares. }
function NewResponse(id: JsonPtr): JsonPtr;
var r: JsonPtr;
begin
  r := JsonNewObject;
  JsonPut(r, 'jsonrpc', JsonNewText('2.0'));
  JsonPut(r, 'id', CopyId(id));
  NewResponse := r
end;

{ --- the document store --------------------------------------------------- }

{ Where this URI is held, or 0. Linear, for the reason in the header. }
function IndexOf(uri: DocUri): integer;
var i: integer;
    d: Document;
begin
  IndexOf := 0;
  for i := 1 to VecLen(DocVec, docs) do begin
    d := VecGet(DocVec, Document, docs, i);
    if d.uri = uri then exit(i)
  end
end;

{ A JSON string value copied out into a buffer of its own, which is how a
  document's text arrives: `JsonTextInto` wants a capacity and a source file
  has none worth naming. }
procedure CharsOf(v: JsonPtr; var b: JsonChars);
var i, n: integer;
begin
  JsonCharsNew(b);
  n := JsonTextLen(v);
  for i := 1 to n do JsonCharsAdd(b, JsonTextAt(v, i))
end;

{ The n'th line of a document, 1-based and without its terminator, as far as
  `DiagLine` holds it. The empty string where the document has no such line,
  which is what a caller passes when it has nothing to convert with.

  Carriage returns are dropped, because `WriteScratch` drops them too: the
  compiler's columns are counted over the file this server wrote, not over the
  bytes the client sent, and the two must be walked the same way. }
procedure LineOf(var b: JsonChars; n: integer; var line: DiagLine);
var i, at, len: integer;
    c: char;
begin
  line := '';
  if n < 1 then exit;
  len := JsonCharsLen(b);
  at := 1;
  i := 1;
  while (i <= len) and (at < n) do begin
    if JsonCharsAt(b, i) = chr(10) then at := at + 1;
    i := i + 1
  end;
  { The document ended before that line began. }
  if at <> n then exit;
  while i <= len do begin
    c := JsonCharsAt(b, i);
    if c = chr(10) then exit;
    if (c <> chr(13)) and (length(line) < DiagLineMax) then line := line + c;
    i := i + 1
  end
end;

{ Remember what the client says this document now contains, replacing what it
  said before. The old text is released here and nowhere else. }
procedure Store(uri: DocUri; text: JsonPtr);
var at: integer;
    d: Document;
begin
  at := IndexOf(uri);
  if at = 0 then begin
    d.uri := uri;
    CharsOf(text, d.text);
    VecPush(DocVec, docs, d)
  end else begin
    d := VecGet(DocVec, Document, docs, at);
    JsonCharsFree(d.text);
    CharsOf(text, d.text);
    VecSet(DocVec, docs, at, d)
  end
end;

{ Forget it, releasing its text. }
procedure Forget(uri: DocUri);
var at, i: integer;
    d, last: Document;
begin
  at := IndexOf(uri);
  if at = 0 then exit;
  d := VecGet(DocVec, Document, docs, at);
  JsonCharsFree(d.text);
  { Close the gap by moving the tail down. Order does not matter to a lookup
    that is linear anyway, but a vector with a hole in it would. }
  for i := at to VecLen(DocVec, docs) - 1 do
    VecSet(DocVec, docs, i, VecGet(DocVec, Document, docs, i + 1));
  if not VecPop(DocVec, docs, last) then
    Note('a document vanished from the store while it was being removed')
end;

{ --- where a file's imports come from ------------------------------------- }

{ The compiler is handed one file and a program is several (6.13), so a module
  compiled alone fails on every name it imports -- 48 diagnostics for
  `lib/dialect/pasjson.pas`, two of them real and 46 cascade. A server that
  did nothing about it would be usable on a single-file program and on nothing
  in the repository it was written in.

  **What it reads is `.components`, and that file is this tree's build
  description.** `tests/run_test.sh`, `selfhost/irtest.sh`, CMake,
  `lsp/build.sh` and four gates already read one: a path per line, relative to
  the sidecar's own directory, in dependency order. It is what
  `compile_commands.json` is to clangd and `go.mod` is to gopls, and a server
  reading the project's build description is what every language server does.
  The alternative -- resolving `import PasError;` to a file by name -- is the
  gap `README.md` names, and it wants the *compiler* to answer rather than a
  second reader of Pascal living here.

  **One rule, and the file already means it: take the entries before this
  one.** A sidecar that names the file gives its prefix, which is exactly the
  set of components translated before it; a sidecar named after the file and
  sitting beside it, which is the ordinary case, does not name it and gives
  all of them. `selfhost/compiler.components` is the shape that needs the
  first half — it sits beside `compiler.pas` *and* names it, and handing a
  component its own interface is what `run_test.sh` is careful not to do. }

function EndsWith(s: PathName; tail: PathName): boolean;
begin
  if length(tail) > length(s) then EndsWith := false
  else EndsWith := s[length(s) - length(tail) + 1..length(s)] = tail
end;

{ The directory a path is in, without the separator; the empty string for a
  path with none, which then resolves against the working directory. }
function DirOf(p: PathName): PathName;
var i: integer;
begin
  i := length(p);
  while (i > 0) and (p[i] <> '/') do i := i - 1;
  if i > 1 then DirOf := p[1..i - 1]
  else if i = 1 then DirOf := '/'
  else DirOf := ''
end;

{ `rel` resolved against `base`, with `.` and `..` taken out. The components
  sidecars are written `../../lib/dialect/paserror.pas`, so nothing can be
  compared until the dots are gone: two spellings of one file are two strings.
  A leading `/` in `rel` makes it its own answer, as it does everywhere. }
function Resolve(base: PathName; rel: PathName): PathName;
var whole, out: PathName;
    i, n, segAt: integer;
    absolute: boolean;

  { Drop the last segment, which is what `..` does. }
  procedure PopSegment;
  var k: integer;
  begin
    k := length(out);
    while (k > 0) and (out[k] <> '/') do k := k - 1;
    if k > 0 then out := out[1..k - 1] else out := ''
  end;

begin
  if (length(rel) > 0) and (rel[1] = '/') then whole := rel
  else if base = '' then whole := rel
  else whole := base + '/' + rel;
  absolute := (length(whole) > 0) and (whole[1] = '/');
  out := '';
  i := 1;
  n := length(whole);
  while i <= n do begin
    while (i <= n) and (whole[i] = '/') do i := i + 1;
    segAt := i;
    while (i <= n) and (whole[i] <> '/') do i := i + 1;
    if i > segAt then begin
      if whole[segAt..i - 1] = '.' then { the current directory: nothing }
      else if whole[segAt..i - 1] = '..' then PopSegment
      else out := out + '/' + whole[segAt..i - 1]
    end
  end;
  if out = '' then begin
    if absolute then out := '/' else out := '.'
  end
  else if not absolute then out := out[2..length(out)];
  Resolve := out
end;

function HexValue(c: char): integer;
begin
  if (c >= '0') and (c <= '9') then HexValue := ord(c) - ord('0')
  else if (c >= 'a') and (c <= 'f') then HexValue := ord(c) - ord('a') + 10
  else if (c >= 'A') and (c <= 'F') then HexValue := ord(c) - ord('A') + 10
  else HexValue := -1
end;

{ A `file:///...` URI as a path, percent-escapes undone -- a project under a
  directory with a space in its name arrives as `%20` and is otherwise a path
  that is not there. The empty string for anything else: a URI with a host
  part, or a scheme this server cannot open, is a document it cannot find on
  disk, and the caller reads the empty answer as "no imports". }
function UriToPath(uri: JsonLine): PathName;
var out: PathName;
    i, n, hi, lo: integer;
    taken: boolean;
begin
  out := '';
  if length(uri) < 8 then exit('');
  if uri[1..8] <> 'file:///' then exit('');
  { From the last slash of the prefix, so the path keeps its own root. }
  i := 8;
  n := length(uri);
  while i <= n do begin
    taken := false;
    if (uri[i] = '%') and (i + 2 <= n) then begin
      hi := HexValue(uri[i + 1]);
      lo := HexValue(uri[i + 2]);
      if (hi >= 0) and (lo >= 0) and (hi * 16 + lo > 0) then begin
        if length(out) < MaxPath then out := out + chr(hi * 16 + lo);
        i := i + 3;
        taken := true
      end
    end;
    if not taken then begin
      if length(out) < MaxPath then out := out + uri[i];
      i := i + 1
    end
  end;
  UriToPath := out
end;

{ Read one sidecar. Where it names `target`, `words` receives `--import` for
  each entry *before* it and the answer is true. Where it does not, the answer
  is `whenAbsent` and `words` receives every entry.

  A line is one path and anything after it is ignored, which is how
  `run_test.sh` reads the same file: a second field used to name a standard
  and ADR-0232 removed the modes. }
function ReadSidecar(sidecar: PathName; target: PathName;
                     whenAbsent: boolean; var words: CommandLine): boolean;
var f: bindable text;
    b: BindingType;
    line, full: PathName;
    acc: CommandLine;
    i: integer;
begin
  ReadSidecar := false;
  words := '';
  acc := '';
  b := binding(f);
  b.name := sidecar;
  bind(f, b);
  { E.16 binds a variable when the external name *exists*, which is the wrong
    question before a `rewrite` and exactly the right one before a `reset`. }
  b := binding(f);
  if not b.bound then exit(false);
  reset(f);
  while not eof(f) do begin
    readln(f, line);
    i := 1;
    while (i <= length(line)) and (line[i] <> ' ') and (line[i] <> chr(9)) do
      i := i + 1;
    line := line[1..i - 1];
    if line <> '' then begin
      full := Resolve(DirOf(sidecar), line);
      if full = target then begin
        words := acc;
        unbind(f);
        exit(true)
      end;
      { A command line that would not fit is one the compiler would refuse
        anyway (ADR-0235). Dropping the tail leaves the earlier components,
        which is the half a reader is more likely to want. }
      if length(acc) + length(full) + 13 <= CommandMax then
        acc := acc + ' --import ''' + full + ''''
    end
  end;
  unbind(f);
  if whenAbsent then begin
    words := acc;
    ReadSidecar := true
  end
end;

{ Look for a sidecar naming `target`, below `dir`. Files before directories,
  so a sidecar in this directory answers before one further down, and both
  lists sorted so that a workspace with two candidates answers the same way
  twice. }
function WalkFor(dir: PathName; depth: integer; target: PathName;
                 var words: CommandLine): boolean;
var names: StrVecPtr;
    i: integer;
    nm, full: PathName;
    r: InfoResult;
    found: boolean;
begin
  found := false;
  if depth > WalkDepthMax then exit(false);
  SVecNew(names, 32);
  if List(dir, names) = errNone then begin
    SVecSort(names);
    for i := 1 to SVecLen(names) do begin
      nm := SVecGet(names, i);
      if EndsWith(nm, '.components') then
        if ReadSidecar(Resolve(dir, nm), target, false, words) then begin
          found := true;
          break
        end
    end;
    if not found then
      for i := 1 to SVecLen(names) do begin
        nm := SVecGet(names, i);
        { A hidden directory holds no source anyone is editing, and a build
          tree holds a second copy of everything -- including sidecars, which
          would then answer with paths into it. }
        if length(nm) = 0 then continue;
        if nm[1] = '.' then continue;
        if (length(nm) >= 5) and (nm[1..5] = 'build') then continue;
        full := Resolve(dir, nm);
        r := Info(full);
        if r.ok then
          if r.val.kind = fkDirectory then
            if WalkFor(full, depth + 1, target, words) then begin
              found := true;
              break
            end
      end
  end;
  SVecFree(names);
  WalkFor := found
end;

{ The `--import` words for a document, or none. }
function ImportsFor(target: PathName; var words: CommandLine): boolean;
var own: PathName;
    i: integer;
begin
  words := '';
  if target = '' then exit(false);
  { A sidecar beside the file and named after it answers first: it is the one
    whose author meant *this* file, and it is what run_test.sh would read. }
  i := length(target);
  while (i > 0) and (target[i] <> '.') and (target[i] <> '/') do i := i - 1;
  if (i > 0) and (target[i] = '.') then own := target[1..i - 1] + '.components'
  else own := target + '.components';
  if Exists(own) then exit(ReadSidecar(own, target, true, words));
  if rootPath = '' then exit(false);
  ImportsFor := WalkFor(rootPath, 0, target, words)
end;

{ --- compiling ------------------------------------------------------------ }

{ The document, as a file the compiler can open.

  A newline in the text becomes a line of the Pascal file; a carriage return
  is dropped, so a client that sends CRLF is read the same as one that does
  not. 6.6.5.2 appends the line terminator that a last line without one is
  missing, so a buffer the user has not finished typing still reaches the
  compiler as a whole file. }
function WriteScratch(var b: JsonChars): boolean;
var bt: BindingType;
    i, n: integer;
    c: char;
begin
  { `bound` is not asked, and asking it would be the bug rather than the check.
    `doc/implementation-defined.md` E.16 makes a variable bound when the name
    *exists*, so a file about to be created reports false and a file already
    written reports true -- the opposite of a readiness test in both
    directions. Unbinding first is what keeps the second bind legal, 6.7.5.6
    making a bind over an existing entity a dynamic-violation.

    `writable` is the field that *is* asked, and it is the one this program
    demanded: AP 6.4.3.4 (ADR-0240). Until it existed there was nothing to ask
    with -- `rewrite` on a name that cannot be created is a run-time error and
    stops the program, and neither standard offers a program a question about
    the write side of an open the way `bound` answers one about the read side.
    A server cannot be killed by a bad `PASLS_SCRATCH` now; it says so and
    keeps the session. It is a probe and not a guarantee, exactly as `bound`
    is, so a disc that fills between these two statements still stops the
    program -- what it covers is every failure the *path* can be blamed for. }
  bt := binding(scratchFile);
  if bt.bound then unbind(scratchFile);
  bt.name := scratchPath;
  bind(scratchFile, bt);
  if not binding(scratchFile).writable then begin
    Note('nothing can be written at ' + scratchPath
         + ' -- set PASLS_SCRATCH to a path this program may create');
    exit(false)
  end;
  rewrite(scratchFile);
  n := JsonCharsLen(b);
  for i := 1 to n do begin
    c := JsonCharsAt(b, i);
    if c = chr(10) then writeln(scratchFile)
    else if c <> chr(13) then write(scratchFile, c)
  end;
  { Unbinding closes it, which is what makes the bytes readable by the process
    started on the next line. }
  unbind(scratchFile);
  WriteScratch := true
end;

{ Compile the scratch file and answer everything the compiler said.

  The redirection is deliberate. This compiler writes its diagnostics to
  `output` -- there being no second stream a standard Pascal program can
  name -- but `tools/pascalcc`, which a user may just as well name in
  `PASLS_COMPILER`, moves them to standard error. Folding the two together is
  what makes either work. }
function CompilerCommand(flags: CommandLine; imports: CommandLine;
                        var cmd: CommandLine): boolean;
begin
  cmd := '';
  { Checked rather than concatenated: a variable-string assignment past its
    capacity is a run-time error, and the pieces here are all a caller's. }
  if length(compilerCmd) + length(flags) + length(imports)
     + 2 * length(scratchPath) + 32 > CommandMax then begin
    Note('the compiler command line would be longer than this program holds');
    exit(false)
  end;
  cmd := compilerCmd + flags + imports + ' ''' + scratchPath + ''' -o '''
         + scratchPath + '.ll'' 2>&1';
  CompilerCommand := true
end;

function Compile(imports: CommandLine; var out: CaptureText): boolean;
var cmd: CommandLine;
    r: RunResult;
begin
  out := '';
  if not CompilerCommand('', imports, cmd) then exit(false);
  r := Capture(cmd, out);
  if not r.ok then begin
    Note('could not run the compiler: ' + ErrorText(r.cause));
    Compile := false
  end else
    { A non-zero exit is the ordinary case here: it is what a file with an
      error in it produces, and the diagnostics are the product. }
    Compile := true
end;

{ Every diagnostic in a compilation's output, as the protocol's array.

  A line that is not a diagnostic is skipped and is not an error -- most of
  what a compilation writes is not one, which is the first thing
  `tests/dialect/lsp_diag.pas` pins. }
function DiagnosticsIn(var out: CaptureText; var doc: JsonChars): JsonPtr;
var arr: JsonPtr;
    line: DiagText;
    source: DiagLine;
    i: integer;
    c: char;
    d: DiagResult;
begin
  arr := JsonNewArray;
  line := '';
  { One past the end, so a final line with no terminator is still a line. }
  for i := 1 to length(out) + 1 do begin
    if i <= length(out) then c := out[i] else c := chr(10);
    if c = chr(10) then begin
      d := DiagParse(line);
      if d.ok then begin
        LineOf(doc, d.val.line, source);
        JsonAppend(arr, DiagJson(d.val, source, encoding))
      end;
      line := ''
    end else if (c <> chr(13)) and (length(line) < DiagMax) then
      line := line + c
  end;
  DiagnosticsIn := arr
end;

{ Compile what we hold for this document and tell the client what came back.

  **A notification is published even when there is nothing to say**, and that
  is the protocol's rule rather than a choice: an empty array is how a client
  is told the problems it was shown are gone, and a server that stays quiet
  leaves the previous set on the screen for ever. }
procedure Analyse(uri: DocUri);
var at: integer;
    d: Document;
    out: CaptureText;
    note: JsonPtr;
    words: CommandLine;
    found: boolean;
begin
  at := IndexOf(uri);
  if at = 0 then exit;
  d := VecGet(DocVec, Document, docs, at);
  if not WriteScratch(d.text) then exit;
  { The document's *real* path, not the scratch one: the sidecars name the
    file the client is editing, and the scratch file is a copy of its bytes
    somewhere else entirely. }
  found := ImportsFor(UriToPath(uri), words);
  if not Compile(words, out) then exit;
  note := DiagPublish(uri, DiagnosticsIn(out, d.text));
  Send(note);
  JsonFree(note)
end;

{ --- the methods ---------------------------------------------------------- }

{ 3.17's `general.positionEncodings`: the client offers a list and the server
  picks one, or falls back to `utf-16` when it supports none of them. `utf-8`
  is preferred here for a reason that is about this compiler and not about
  taste -- its column already counts bytes, so under `utf-8` there is nothing
  to convert and nothing to get wrong. }
procedure Negotiate(params: JsonPtr);
var offered, one: JsonPtr;
    i: integer;
    name: JsonLine;
begin
  encoding := peUtf16;
  offered := JsonMember(JsonMember(JsonMember(params, 'capabilities'),
                                   'general'), 'positionEncodings');
  for i := 1 to JsonCount(offered) do begin
    one := JsonAt(offered, i);
    if JsonTextInto(one, name) <> errNone then name := '';
    if name = 'utf-8' then encoding := peUtf8
  end
end;

{ 3.6's `workspaceFolders` where the client sends them, and `rootUri` where it
  sends the older field instead; neither where it opened a single file, and the
  server then reads only a sidecar sitting beside the document. }
procedure FindRoot(params: JsonPtr);
var folders, one: JsonPtr;
    uri: JsonLine;
begin
  rootPath := '';
  uri := '';
  folders := JsonMember(params, 'workspaceFolders');
  if JsonCount(folders) > 0 then begin
    one := JsonAt(folders, 1);
    if JsonTextInto(JsonMember(one, 'uri'), uri) = errNone then
      rootPath := UriToPath(uri)
  end;
  if rootPath = '' then begin
    uri := '';
    if JsonTextInto(JsonMember(params, 'rootUri'), uri) = errNone then
      rootPath := UriToPath(uri)
  end
end;

function EncodingName: JsonLine;
begin
  if encoding = peUtf8 then EncodingName := 'utf-8'
  else EncodingName := 'utf-16'
end;

procedure Initialize(id: JsonPtr; params: JsonPtr);
var reply, result, caps, info: JsonPtr;
begin
  Negotiate(params);
  FindRoot(params);
  reply := NewResponse(id);
  result := JsonNewObject;
  caps := JsonNewObject;
  JsonPut(caps, 'textDocumentSync', JsonNewInteger(SyncFull));
  { ADR-0239. Answered from --dump-symbols, which is the compiler's own
    account of what a source declares. }
  JsonPut(caps, 'documentSymbolProvider', JsonNewBoolean(true));
  { Echoed whichever way it went, so the client is never guessing. }
  JsonPut(caps, 'positionEncoding', JsonNewText(EncodingName));
  JsonPut(result, 'capabilities', caps);
  info := JsonNewObject;
  JsonPut(info, 'name', JsonNewText('pasls'));
  JsonPut(result, 'serverInfo', info);
  JsonPut(reply, 'result', result);
  Send(reply);
  JsonFree(reply)
end;

{ 3.17's shutdown: answer null, and keep running until `exit` arrives. }
procedure Shutdown(id: JsonPtr);
var reply: JsonPtr;
begin
  reply := NewResponse(id);
  JsonPut(reply, 'result', JsonNewNull);
  Send(reply);
  JsonFree(reply)
end;

procedure Unsupported(id: JsonPtr; method: JsonLine);
var reply, err: JsonPtr;
begin
  reply := NewResponse(id);
  err := JsonNewObject;
  JsonPut(err, 'code', JsonNewInteger(MethodNotFound));
  JsonPut(err, 'message', JsonNewText('pasls does not implement ' + method));
  JsonPut(reply, 'error', err);
  Send(reply);
  JsonFree(reply)
end;

{ The URI of a `textDocument` member, or the empty string where there is none
  or it is longer than this program can hold. }
function UriOf(params: JsonPtr): DocUri;
var doc: JsonPtr;
    s: DocUri;
begin
  doc := JsonMember(params, 'textDocument');
  if JsonTextInto(JsonMember(doc, 'uri'), s) <> errNone then begin
    Note('a document URI this server cannot hold was ignored');
    s := ''
  end;
  UriOf := s
end;

procedure DidOpen(params: JsonPtr);
var uri: DocUri;
    doc: JsonPtr;
begin
  uri := UriOf(params);
  if uri = '' then exit;
  doc := JsonMember(params, 'textDocument');
  Store(uri, JsonMember(doc, 'text'));
  Analyse(uri)
end;

{ Full synchronisation, which is what `Initialize` asked for: the last change
  in the list carries the whole document, and `range` is absent.

  A change to a document that was never opened is stored rather than refused.
  The protocol says a change follows an open and this server does not insist --
  `PasLsp`'s own leniency, applied one level up: what is accepted may be
  generous while what is produced is not. }
procedure DidChange(params: JsonPtr);
var uri: DocUri;
    changes, last: JsonPtr;
begin
  uri := UriOf(params);
  if uri = '' then exit;
  changes := JsonMember(params, 'contentChanges');
  last := JsonAt(changes, JsonCount(changes));
  if last = nil then begin
    Note('a didChange with no content was ignored');
    exit
  end;
  Store(uri, JsonMember(last, 'text'));
  Analyse(uri)
end;

{ A closed document's problems are the editor's to forget, and the way to say
  so is an empty set for it. }
procedure DidClose(params: JsonPtr);
var uri: DocUri;
    note: JsonPtr;
begin
  uri := UriOf(params);
  if uri = '' then exit;
  Forget(uri);
  note := DiagPublish(uri, JsonNewArray);
  Send(note);
  JsonFree(note)
end;

{ --- the outline ---------------------------------------------------------- }

{ LSP's `textDocument/documentSymbol`, and the decision behind it is not in
  this file: it is that the compiler answers a *tool's* question about a
  program in a form of its own (ADR-0239). The only structured thing this
  compiler wrote about a source was `--dump-sema`, which ADR-0085 demoted from
  a specification to a debugging aid on the day there was no second front end
  to diff it against -- so a server reading that would be a second reader of
  Pascal-shaped output, living outside the compiler and free to drift from it.
  This reads `--dump-symbols` instead, which is a line and six fields.

  Three consequences worth knowing here.

  **No `--import`, and that is deliberate.** The flag stops after the parse,
  so an outline never depends on another file being found -- which matters
  most for the file `ImportsFor` cannot place, where the diagnostics are
  useless and the outline is still exactly right.

  **The name is read out of the document and not out of the dump.** The
  compiler's string pool holds the *folded* spelling, the lexer having
  case-folded it, so `CaseTest` reaches this program as `casetest`. What the
  dump reports beside it is a position and a length, which is enough: this
  server holds the document the compiler was handed and slices the spelling
  the programmer wrote out of it. The folded name is the fallback for a line
  the store no longer has.

  **The range is the name and not the declaration.** LSP wants `range` to
  span the whole symbol and `selectionRange` to be the name inside it; the
  parse tree records where a declaration *starts* and never where it ends, so
  the honest answer is the extent this compiler can actually name, given
  twice. An editor's outline, go-to-symbol and breadcrumbs are all right; what
  degrades is "expand selection to the enclosing declaration", and inventing
  an end for it would be inventing a claim about the source. }

{ The n'th space-separated field of a line, or the empty string. }
function SymField(line: StrItem; n: integer): ParseLine;
var i, k: integer;
    out: ParseLine;
begin
  out := '';
  k := 0;
  i := 1;
  while i <= length(line) do
    if line[i] = ' ' then i := i + 1
    else begin
      k := k + 1;
      while (i <= length(line)) and (line[i] <> ' ') do begin
        if (k = n) and (length(out) < ParseMax) then out := out + line[i];
        i := i + 1
      end
    end;
  SymField := out
end;

{ Pascal's word for a declaration, as the protocol's number. A kind this
  program has not heard of is a version skew between it and the compiler it
  started, so it is reported rather than dropped: an outline missing a name
  looks like a compiler that lost it. }
function SymbolKindOf(word: ParseLine): integer;
begin
  if (word = 'program') or (word = 'module') then SymbolKindOf := SkModule
  else if word = 'const' then SymbolKindOf := SkConstant
  else if word = 'type' then SymbolKindOf := SkClass
  else if (word = 'record') or (word = 'schema') then SymbolKindOf := SkStruct
  else if word = 'enum' then SymbolKindOf := SkEnum
  else if word = 'field' then SymbolKindOf := SkField
  else if word = 'value' then SymbolKindOf := SkEnumMember
  else if word = 'var' then SymbolKindOf := SkVariable
  else if (word = 'procedure') or (word = 'function') then
    SymbolKindOf := SkFunction
  else begin
    Note('a symbol kind this server does not know was reported as a '
         + 'variable: ' + word);
    SymbolKindOf := SkVariable
  end
end;

{ A byte column of a source line, as a Position.character in the unit this
  session negotiated -- 0-based, where the compiler counts from one. Under
  `utf-8` the compiler's column already is the protocol's and converting it
  would be the defect rather than the fix (ADR-0237). }
function CharacterAt(line: DiagLine; col: integer): integer;
begin
  if encoding = peUtf16 then CharacterAt := Utf16Column(line, col) - 1
  else CharacterAt := col - 1
end;

{ The extent of a name, as the protocol's Range. }
function NameRange(source: DiagLine; line, col, len: integer): JsonPtr;
var r, a, b: JsonPtr;
begin
  a := JsonNewObject;
  JsonPut(a, 'line', JsonNewInteger(line - 1));
  JsonPut(a, 'character', JsonNewInteger(CharacterAt(source, col)));
  b := JsonNewObject;
  JsonPut(b, 'line', JsonNewInteger(line - 1));
  JsonPut(b, 'character', JsonNewInteger(CharacterAt(source, col + len)));
  r := JsonNewObject;
  JsonPut(r, 'start', a);
  JsonPut(r, 'end', b);
  NameRange := r
end;

{ The document's outline, as the protocol's `DocumentSymbol[]`.

  It is collected a *line* at a time rather than into one buffer, and that is
  a bound this program then does not have: `CaptureMax` is 16384 and the
  outline of `selfhost/apfront.pas` is 51 192 bytes, so the answer would have
  stopped a third of the way through with nothing said. An outline is a list
  of lines and `CaptureLines` collects one on the heap; the per-line bound
  that replaces it is `ItemMax`, and a symbol line is six short fields.
  Four of the twelve findings this program has produced are bounds chosen by
  counting what the largest thing in the tree needed at the time, and the
  largest thing in the tree was a test case. }
procedure Outline(id: JsonPtr; params: JsonPtr);
var uri: DocUri;
    at, i, depth, lastDepth, symLine, symCol, symLen: integer;
    d: Document;
    lines: StrVecPtr;
    cmd: CommandLine;
    r: RunResult;
    reply, result, obj: JsonPtr;
    kids, owner: array [0..SymDepthMax] of JsonPtr;
    text: StrItem;
    source: DiagLine;
    name: DiagLine;
    kind: ParseLine;
    tooDeep: boolean;
begin
  reply := NewResponse(id);
  { An array, and an empty one where there is nothing to say. `null` is legal
    and says the same thing less clearly to a client that then has to test
    for it. }
  result := JsonNewArray;
  uri := UriOf(params);
  at := IndexOf(uri);
  if at <> 0 then begin
    d := VecGet(DocVec, Document, docs, at);
    { A scratch path that cannot be written leaves the outline empty rather
      than stopping the server, which is what the answer below already is for
      a document nobody opened. }
    if WriteScratch(d.text)
       { No imports: the flag stops after the parse and a name is a name
         whether or not the module it came from was found. }
       and CompilerCommand(' --dump-symbols', '', cmd) then begin
      SVecNew(lines, 64);
      r := CaptureLines(cmd, lines);
      if not r.ok then
        Note('could not run the compiler: ' + ErrorText(r.cause))
      else begin
        for i := 0 to SymDepthMax do begin
          kids[i] := nil;
          owner[i] := nil
        end;
        kids[0] := result;
        lastDepth := -1;
        tooDeep := false;
        for i := 1 to SVecLen(lines) do begin
          text := SVecGet(lines, i);
          { A line that is not a symbol is skipped and is not an error: a
            source with a syntax error in it says so on this same stream, and
            an outline of what parsed is still the best answer available. }
          if SymField(text, 1) = 'symbol' then begin
            depth := IntOr(ParseInt(SymField(text, 2)), 0);
            kind := SymField(text, 3);
            symLine := IntOr(ParseInt(SymField(text, 4)), 0);
            symCol := IntOr(ParseInt(SymField(text, 5)), 0);
            symLen := IntOr(ParseInt(SymField(text, 6)), 0);
            name := SymField(text, 7);
            if depth > SymDepthMax then begin
              tooDeep := true;
              depth := SymDepthMax
            end;
            { A depth that skips a level has no parent to hang from, which
              cannot happen from this compiler and would be a nil dereference
              if it did. Clamped to one below the last, so a malformed stream
              produces a flatter outline and never a stopped server. }
            if depth > lastDepth + 1 then depth := lastDepth + 1;
            LineOf(d.text, symLine, source);
            { The spelling the programmer wrote, which the compiler cannot
              report: its string pool holds the folded one. }
            if (symCol >= 1) and (symLen > 0)
               and (symCol + symLen - 1 <= length(source)) then
              name := source[symCol..symCol + symLen - 1];
            obj := JsonNewObject;
            JsonPut(obj, 'name', JsonNewText(name));
            JsonPut(obj, 'kind', JsonNewInteger(SymbolKindOf(kind)));
            JsonPut(obj, 'range',
                    NameRange(source, symLine, symCol, symLen));
            JsonPut(obj, 'selectionRange',
                    NameRange(source, symLine, symCol, symLen));
            { The array this depth's symbols go in, made when the first of
              them arrives so that a childless symbol carries no `children`
              member at all. }
            if kids[depth] = nil then begin
              kids[depth] := JsonNewArray;
              JsonPut(owner[depth - 1], 'children', kids[depth])
            end;
            JsonAppend(kids[depth], obj);
            owner[depth] := obj;
            { A later sibling starts a children array of its own. Depth grows
              one level at a time, so clearing the next one is enough. }
            if depth < SymDepthMax then kids[depth + 1] := nil;
            lastDepth := depth
          end
        end;
        if tooDeep then
          Note('declarations nested deeper than this server follows were '
               + 'reported at its limit')
      end;
      SVecFree(lines)
    end
  end;
  JsonPut(reply, 'result', result);
  Send(reply);
  JsonFree(reply)
end;

{ --- the loop ------------------------------------------------------------- }

{ One message. The chain below dispatches on a string and so is nobody's
  enumeration: a method this server does not implement is answered when it is
  a request and ignored when it is a notification, which is what the
  specification asks for in each case. }
procedure Dispatch(msg: JsonPtr);
var method: JsonLine;
    id, params: JsonPtr;
begin
  if JsonTextInto(JsonMember(msg, 'method'), method) <> errNone then begin
    Note('a message with no method was ignored');
    exit
  end;
  id := JsonMember(msg, 'id');
  params := JsonMember(msg, 'params');
  if method = 'initialize' then Initialize(id, params)
  else if method = 'initialized' then { nothing to do }
  else if method = 'shutdown' then Shutdown(id)
  else if method = 'exit' then running := false
  else if method = 'textDocument/didOpen' then DidOpen(params)
  else if method = 'textDocument/didChange' then DidChange(params)
  else if method = 'textDocument/didClose' then DidClose(params)
  else if method = 'textDocument/documentSymbol' then Outline(id, params)
  else if id <> nil then Unsupported(id, method)
end;

{ Where the compiler and the scratch file are. Both are overridable because a
  harness has to point them somewhere of its own, and both have a default
  because a user starting this from an editor sets no environment at all. }
procedure ReadEnvironment;
begin
  compilerCmd := LookupOr('PASLS_COMPILER', 'pascalc');
  scratchPath := LookupOr('PASLS_SCRATCH',
                          LookupOr('TMPDIR', '/tmp') + '/pasls-scratch.pas')
end;

var body: JsonChars;
    e: ErrorCode;
    parsed: JsonResult;
    at: integer;
    i: integer;
    d: Document;
    complaint: IOLine;

begin
  ReadEnvironment;
  encoding := peUtf16;
  rootPath := '';
  LspOpen(reader, StdIn);
  VecInit(DocVec, docs, 4);
  running := true;
  while running do begin
    JsonCharsNew(body);
    e := LspRead(reader, body);
    if e <> errNone then begin
      { The end of the input is how a client that was killed reaches us, and
        it is not a failure: an editor that goes away without saying `exit` is
        the ordinary way an editing session ends. }
      if e <> errAbsent then Note('unreadable frame: ' + ErrorText(e));
      running := false
    end else begin
      parsed := JsonParseChars(body, at);
      if parsed.ok then begin
        Dispatch(parsed.val);
        JsonFree(parsed.val)
      end else begin
        writestr(complaint, 'a message that is not JSON was ignored, at byte ',
                 at:1, ': ', ErrorText(parsed.cause));
        Note(complaint)
      end
    end;
    JsonCharsFree(body)
  end;
  { Everything this program allocated, given back -- so a run of it balances
    under PASHEAP_BALANCE the way a corpus case does (ADR-0183). }
  for i := 1 to VecLen(DocVec, docs) do begin
    d := VecGet(DocVec, Document, docs, i);
    JsonCharsFree(d.text)
  end;
  VecFree(DocVec, docs)
end.
