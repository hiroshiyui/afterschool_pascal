{ pasls -- a Language Server Protocol server for Afterschool Pascal, written
  in Afterschool Pascal.

  `doc/roadmap.md` proposes this program as **the caller**: the thing large
  enough to say whether the dialect is pleasant to write in, which no gate
  here can measure. It is not part of the compiler and it is not a feature --
  it invokes `pascalc` as a separate process and reads what it wrote, exactly
  as an editor would.

  It answers four questions about a document: the diagnostics it publishes on
  every open and change, the outline `textDocument/documentSymbol` asks for
  (ADR-0239), and `textDocument/definition` and `textDocument/hover`, which
  are one question asked twice -- what the name under this position denotes,
  and where it was written (ADR-0246). The roadmap's sentence for the first of
  them is *"a server that does nothing whatever but publishDiagnostics is
  producing findings on the first day"*, and it has produced more since.

  **The three answers do not all cost the same, and that is deliberate.** The
  diagnostics and the definitions run the compiler through Sema and need the
  document's imports; the outline stops after the *parse* and needs none,
  because an outline is what an editor draws while the file is wrong. So a
  file whose components cannot be found still outlines exactly right, and a
  file Sema rejects still says where its names were declared -- which is the
  state a file being edited is in most of the time.

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
  size -- this component's own is
  `file:///home/someone/projects/afterschool_pascal/lsp/pasls.pas` under any
  checkout deeper than a couple of directories, and 63 runs out inside the
  project name. A handful of open documents is what an editor has, so the
  search costs nothing; the finding is recorded in the roadmap rather than
  worked around silently.

  **The compiler reads a file, so the document has to become one.** An editor
  holds a buffer that has never been saved, which is the whole reason a server
  exists, so the text is written to a scratch file and the scratch file is
  what `pascalc` is pointed at. The name carries this program's process
  identifier -- `PasProcess.ProcessId`, which the language did not have until
  this server needed it (ADR-0242) -- so two servers sharing a `TMPDIR` do not
  share the file. `PASLS_SCRATCH` still overrides it whole, which is how a
  harness points every session at a path of its own, and two servers told the
  same path share it again by the instruction of whoever told them.

  The file is left behind when the server ends, and deliberately: it is the
  exact source `pascalc` was handed, which is the one artefact worth having
  when the server and the editor disagree about a document. One file per
  process under `TMPDIR` is what `TMPDIR` is for.

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
  InvalidParams = -32602;

  { MCP's stdio transport, which is the same JSON-RPC 2.0 envelope over a
    different framing (ADR-0241). The version is the one this server was
    written against; §Lifecycle's version negotiation says a server that does
    not support what the client asked for answers with one it does, which is
    what this is. }
  McpVersion = '2025-06-18';

  { §Lifecycle requires an `Implementation` to carry a name and a version, and
    this is *this program's* and not the compiler's -- they are different
    things and only one of them is what a client is talking to. The compiler's
    is a question the `diagnostics` tool can be asked. }
  PaslsVersion = '1.0.0';

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
  { Which protocol this run speaks. The *work* is the same either way -- one
    document store, one import resolver, one scratch path -- and what differs
    is the framing, the method names and who is asking (ADR-0241). }
  TransportKind = (tpLsp, tpMcp);

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
    text: JsonChars;
    { The last `--dump-uses` taken of this document, or nil (ADR-0252).
      Go-to-definition and hover are answered from it, and a reader asks them
      far more often than they edit: an editor sends a hover on every pause
      of the pointer, and each one used to be a whole compilation. Five hovers
      on `selfhost/apfront.pas` cost 795 ms and now cost 159, because four of
      the five compilations were of text that had not changed.

      It is emptied wherever the text is replaced, which is `Store` and
      `Forget` and nowhere else — a cache invalidated in two places is a cache
      whose validity is a property of the record rather than of a caller. }
    uses_: StrVecPtr
  end;

  DocVec = ^Vec(Document);

  CaptureText = string(CaptureMax);

var
  reader: LspReader;
  transport: TransportKind;
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
  { The one place the two transports differ on the way out. MCP's stdio
    transport is one message to a line and forbids an embedded newline;
    `JsonlWrite` refuses a body holding one rather than writing a frame that
    would be read back as two. }
  if transport = tpMcp then e := JsonlWrite(StdOut, out)
  else e := LspWrite(StdOut, out);
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
    d.uses_ := nil;
    CharsOf(text, d.text);
    VecPush(DocVec, docs, d)
  end else begin
    d := VecGet(DocVec, Document, docs, at);
    JsonCharsFree(d.text);
    { The text is being replaced, so what the compiler last said about it is
      about a document that no longer exists (ADR-0252). }
    if d.uses_ <> nil then SVecFree(d.uses_);
    d.uses_ := nil;
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
  if d.uses_ <> nil then SVecFree(d.uses_);
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

{ The other direction of HexValue, for PathToUri. Upper case because RFC 3986
  says a percent-escape "should" use it. }
function HexDigit(n: integer): char;
begin
  if n < 10 then HexDigit := chr(ord('0') + n)
  else HexDigit := chr(ord('A') + n - 10)
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

{ A path as a `file://` URI, which is the direction `UriToPath` does not go.
  It is needed because a defining-point may be in a file the client never
  opened -- that is most of what go-to-definition is for -- and the protocol
  names a location by URI and nothing else.

  Everything outside RFC 3986's unreserved set is percent-escaped, `/` apart.
  Escaping more than is required is always legal and never ambiguous, which
  is the safe direction for a rule this program has one reader of. }
function PathToUri(path: PathName): DocUri;
var out: DocUri;
    i, b: integer;
    c: char;
    plain: boolean;
begin
  out := 'file://';
  for i := 1 to length(path) do begin
    c := path[i];
    plain := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'))
             or ((c >= '0') and (c <= '9'))
             or (c = '-') or (c = '.') or (c = '_') or (c = '~') or (c = '/');
    if plain then begin
      if length(out) < LineMax then out := out + c
    end
    else begin
      b := ord(c);
      if length(out) + 3 <= LineMax then
        out := out + '%' + HexDigit(b div 16) + HexDigit(b mod 16)
    end
  end;
  PathToUri := out
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
{ The command that asks the compiler about `source`.

  The source is a parameter and the *output* is not: the IR goes beside the
  scratch file whatever is being compiled, because under MCP the source is a
  file on disk that somebody owns and writing a `.ll` next to it would be this
  program leaving something behind (ADR-0241). Under LSP the two are the same
  path and the parameter costs nothing. }
function CompilerCommand(flags: CommandLine; imports: CommandLine;
                        source: PathName; var cmd: CommandLine): boolean;
begin
  cmd := '';
  { Checked rather than concatenated: a variable-string assignment past its
    capacity is a run-time error, and the pieces here are all a caller's. }
  if length(compilerCmd) + length(flags) + length(imports) + length(source)
     + length(scratchPath) + 32 > CommandMax then begin
    Note('the compiler command line would be longer than this program holds');
    exit(false)
  end;
  cmd := compilerCmd + flags + imports + ' ''' + source + ''' -o '''
         + scratchPath + '.ll'' 2>&1';
  CompilerCommand := true
end;

function Compile(imports: CommandLine; var out: CaptureText): boolean;
var cmd: CommandLine;
    r: RunResult;
begin
  out := '';
  if not CompilerCommand('', imports, scratchPath, cmd) then exit(false);
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
  { Both are answered from one compilation and one dump (ADR-0246): what a
    name denotes and where it was declared are the same question. }
  JsonPut(caps, 'definitionProvider', JsonNewBoolean(true));
  JsonPut(caps, 'hoverProvider', JsonNewBoolean(true));
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

  **The range is the declaration and `selectionRange` is the name inside
  it**, which is what LSP asks for and what "expand selection to the enclosing
  declaration" needs. It was not always: until the parse tree learned where a
  block ends (ADR-0253) both were the name, because inventing an end would
  have been inventing a claim about the source. A constant and a type still
  answer with the end of their own name, having no block to end. }

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

{ One `symbol` line, taken apart once. Two readers here want it -- the outline
  this server answers over LSP, and the one it renders as text for MCP -- and
  until this record they each wrote the field numbers out for themselves.
  ADR-0253 then put the declaration's extent in at 7 and 8, so the name moved
  from 7 to 9, and only one of the two moved with it. Nothing failed: both
  readers overwrite the folded name with a slice of the source, and every
  session here reads a file it can open, so what broke was exactly the
  fallback -- the outline of a source the server could not read would have
  been a column of end-line numbers. A wire format is a place two readers have
  to agree, and the way to make them agree is to have one of them. }
type
  SymRow = record
    depth, line, col, len, endLine, endCol: integer;
    kind, name: ParseLine
  end;

function SymParse(text: StrItem; var s: SymRow): boolean;
begin
  if SymField(text, 1) <> 'symbol' then
    SymParse := false
  else begin
    s.depth := IntOr(ParseInt(SymField(text, 2)), 0);
    s.kind := SymField(text, 3);
    s.line := IntOr(ParseInt(SymField(text, 4)), 0);
    s.col := IntOr(ParseInt(SymField(text, 5)), 0);
    s.len := IntOr(ParseInt(SymField(text, 6)), 0);
    { The extent, which a block gives and a constant answers with the end of
      its own name (ADR-0253). }
    s.endLine := IntOr(ParseInt(SymField(text, 7)), 0);
    s.endCol := IntOr(ParseInt(SymField(text, 8)), 0);
    { Folded, the lexer having case-folded it: a fallback for a source neither
      reader can slice the real spelling out of. }
    s.name := SymField(text, 9);
    SymParse := true
  end
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

{ A range with two ends that are not the same name -- a declaration's whole
  extent (ADR-0253). Each end converts against the line it is on, which is
  what makes it right under `utf-16` for a block spanning many lines. }
function SpanRange(fromLine: DiagLine; line, col: integer;
                   toLine: DiagLine; endLine, endCol: integer): JsonPtr;
var r, a, b: JsonPtr;
begin
  a := JsonNewObject;
  JsonPut(a, 'line', JsonNewInteger(line - 1));
  JsonPut(a, 'character', JsonNewInteger(CharacterAt(fromLine, col)));
  b := JsonNewObject;
  JsonPut(b, 'line', JsonNewInteger(endLine - 1));
  JsonPut(b, 'character', JsonNewInteger(CharacterAt(toLine, endCol)));
  r := JsonNewObject;
  JsonPut(r, 'start', a);
  JsonPut(r, 'end', b);
  SpanRange := r
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
    endSource: DiagLine;
    name: DiagLine;
    kind: ParseLine;
    endLine, endCol: integer;
    sym: SymRow;
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
       and CompilerCommand(' --dump-symbols', '', scratchPath, cmd) then begin
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
          if SymParse(text, sym) then begin
            depth := sym.depth;
            kind := sym.kind;
            symLine := sym.line;
            symCol := sym.col;
            symLen := sym.len;
            endLine := sym.endLine;
            endCol := sym.endCol;
            name := sym.name;
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
            { 3.17: `range` is the whole symbol and `selectionRange` is the
              name inside it. They were the same until the parse tree learned
              where a block ends (ADR-0253); now a procedure's range reaches
              its `end`, which is what "expand selection to the enclosing
              declaration" needs. The end is converted against *its own* line,
              which is why it is looked up separately. }
            LineOf(d.text, endLine, endSource);
            JsonPut(obj, 'range',
                    SpanRange(source, symLine, symCol,
                              endSource, endLine, endCol));
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

{ --- where a name was declared, and what it is ----------------------------- }

{ `textDocument/definition` and `textDocument/hover`, which are one question
  asked twice: what does the name under this position denote, and where was it
  written (ADR-0246)?

  **It is the first method here that needs Sema.** An outline is the parser's
  answer and stops before the checker on purpose, so that a file being edited
  into shape still has one; a defining-point is not knowable that way -- which
  identifier a name denotes is 6.2.2's scope rules and nothing less. So this
  runs the compiler further, and passes the imports: a name from another
  program-component resolves to nothing without them, and a name from another
  component is exactly the one a reader does not already know.

  **What it does about a file that does not check** is the decision the
  compiler makes rather than this program: `--dump-uses` reports what Sema
  resolved whether or not Sema was happy, because Sema accumulates its
  diagnostics rather than stopping at the first. A file with a mistake in it
  answers about every name but the ones the mistake is about, and that is the
  state an editor is in most of the time.

  **The narrowest span wins.** 6.11.3's `M.x` is two applied occurrences and
  the compiler reports two overlapping spans for it -- the interface's own
  name, and the whole of `M.x` -- so a position inside `M` is contained by
  both and must resolve to the inner one. Nothing else in the dump overlaps,
  so the rule costs one comparison and buys the qualified case exactly. }

type
  { What one line of the dump said, once a position picked it out. }
  UseHit = record
    found: boolean;
    { The occurrence, in the document's own coordinates. }
    line, col, len: integer;
    { Its defining-point. `declLine = 0` means there is nowhere to go: a
      required identifier is declared in a region enclosing the program
      (6.2.2.10) and an interface is registered by name and not by position. }
    declFile, declLine, declCol, declLen: integer;
    kind: ParseLine;
    denotes: DiagLine
  end;

{ Everything from the n'th space-separated field to the end of the line, which
  is how the type is read: it is the last field because it is the only one
  that may contain a space -- `array [1..3] of integer` is one answer. }
function SymRest(line: StrItem; n: integer): DiagLine;
var i, k: integer;
    out: DiagLine;
begin
  out := '';
  k := 0;
  i := 1;
  while (i <= length(line)) and (k < n) do begin
    while (i <= length(line)) and (line[i] = ' ') do i := i + 1;
    if i <= length(line) then begin
      k := k + 1;
      if k < n then
        while (i <= length(line)) and (line[i] <> ' ') do i := i + 1
    end
  end;
  while i <= length(line) do begin
    if length(out) < DiagLineMax then out := out + line[i];
    i := i + 1
  end;
  SymRest := out
end;

{ A Position.character as a byte column of a source line -- `CharacterAt`
  backwards, and the only place this program converts in that direction.
  Under `utf-8` the two units are the same and the arithmetic is the
  0-based/1-based step alone; under `utf-16` it is a walk, because the
  conversion has no inverse that is not one (ADR-0237). }
function ByteColumn(line: DiagLine; ch: integer): integer;
var col: integer;
begin
  if encoding = peUtf8 then ByteColumn := ch + 1
  else begin
    col := 1;
    while (col <= length(line)) and (Utf16Column(line, col) - 1 < ch) do
      col := col + 1;
    ByteColumn := col
  end
end;

{ True where the span this `use` line describes contains (line, col). }
function Covers(useLine, useCol, useLen, line, col: integer): boolean;
begin
  Covers := (useLine = line) and (col >= useCol) and (col < useCol + useLen)
end;

{ Ask the compiler what the name at this position denotes.

  `path` receives the file the defining-point is in, empty where it is this
  document's own -- the dump names file 0 by the path it was handed, which is
  the *scratch* copy and not a file the client has ever heard of. The caller
  answers with the document's own URI for that case, which is the common one. }
function FindUse(uri: DocUri; line, col: integer;
                 var hit: UseHit; var path: PathName): boolean;
var at, i, ul, uc, un, want: integer;
    d: Document;
    lines: StrVecPtr;
    cmd, words: CommandLine;
    r: RunResult;
    text: StrItem;
    source: DiagLine;
    found: boolean;
begin
  hit.found := false;
  path := '';
  at := IndexOf(uri);
  if at = 0 then exit(false);
  d := VecGet(DocVec, Document, docs, at);
  if not WriteScratch(d.text) then exit(false);
  { The document's real path, as Analyse uses it: the sidecar names the file
    the client is editing and the scratch file is a copy of its bytes. }
  found := ImportsFor(UriToPath(uri), words);
  if not CompilerCommand(' --dump-uses', words, scratchPath, cmd) then
    exit(false);
  { A list of lines and not one buffer, for ADR-0239's reason met a second
    time: this answer is one line per name in the file and `CaptureMax` was
    sized for diagnostics. }
  { ...and kept, because the next question is about the same text (ADR-0252).
    The document owns the list from here: it is freed where the text is
    replaced and not at the end of this routine. }
  if d.uses_ <> nil then lines := d.uses_
  else begin
    SVecNew(lines, 64);
    r := CaptureLines(cmd, lines);
    if not r.ok then begin
      Note('could not run the compiler: ' + ErrorText(r.cause));
      SVecFree(lines);
      exit(false)
    end;
    d.uses_ := lines;
    VecSet(DocVec, docs, at, d)
  end;
  for i := 1 to SVecLen(lines) do begin
    text := SVecGet(lines, i);
    if SymField(text, 1) = 'use' then begin
      ul := IntOr(ParseInt(SymField(text, 2)), 0);
      uc := IntOr(ParseInt(SymField(text, 3)), 0);
      un := IntOr(ParseInt(SymField(text, 4)), 0);
      if Covers(ul, uc, un, line, col) then
        { Narrowest wins, so the interface inside a qualified name is
          reachable at all. }
        if (not hit.found) or (un < hit.len) then begin
          hit.found := true;
          hit.line := ul;
          hit.col := uc;
          hit.len := un;
          hit.declFile := IntOr(ParseInt(SymField(text, 5)), 0);
          hit.declLine := IntOr(ParseInt(SymField(text, 6)), 0);
          hit.declCol := IntOr(ParseInt(SymField(text, 7)), 0);
          hit.declLen := IntOr(ParseInt(SymField(text, 8)), 0);
          hit.kind := SymField(text, 9);
          hit.denotes := SymRest(text, 10)
        end
    end
  end;
  { A second pass, and only when there is something to look up: the file table
    is at the head of the dump and the index that selects from it is not known
    until the answer is. Nothing is held between the two but an integer. }
  if hit.found and (hit.declFile > 0) then
    for i := 1 to SVecLen(lines) do begin
      text := SVecGet(lines, i);
      if SymField(text, 1) = 'file' then
        if IntOr(ParseInt(SymField(text, 2)), -1) = hit.declFile then
          path := SymRest(text, 3)
    end;
  { Not freed here: the document owns it now (ADR-0252). }
  FindUse := hit.found
end;

{ The position a request asks about, as a line and a byte column of the
  document this server is holding. }
procedure AskedAt(params: JsonPtr; uri: DocUri; var line, col: integer);
var p: JsonPtr;
    at: integer;
    d: Document;
    source: DiagLine;
begin
  p := JsonMember(params, 'position');
  line := JsonIntegerOr(JsonMember(p, 'line'), -1) + 1;
  col := 0;
  at := IndexOf(uri);
  if (at <> 0) and (line >= 1) then begin
    d := VecGet(DocVec, Document, docs, at);
    LineOf(d.text, line, source);
    col := ByteColumn(source, JsonIntegerOr(JsonMember(p, 'character'), 0))
  end
end;

{ `textDocument/definition`, as a single `Location` or `null`.

  `null` is the protocol's own answer for "there is nowhere to go", and there
  are three ways to reach it here: the position is on no name at all, the name
  did not resolve, or it resolved to something with no defining-point in any
  source -- `integer`, `abs`, an interface. The last is not a failure and is
  reported the same way, there being nothing else the protocol can be told. }
procedure Definition(id: JsonPtr; params: JsonPtr);
var uri: DocUri;
    line, col, at: integer;
    hit: UseHit;
    path: PathName;
    d: Document;
    source: DiagLine;
    reply, result: JsonPtr;
begin
  reply := NewResponse(id);
  { nil until there is an answer, and `null` made at the end where there is
    none. Starting with a `null` and replacing it would abandon that value on
    every request that succeeds, which is a leak of one JSON node per answer
    -- and the one oracle here that would see it reads no output at all
    (ADR-0183). }
  result := nil;
  uri := UriOf(params);
  AskedAt(params, uri, line, col);
  if (line >= 1) and (col >= 1) then
    if FindUse(uri, line, col, hit, path) then
      if hit.declLine > 0 then begin
        { The range is in the *target* file, whose text this server does not
          hold when that file is not the document. So the column is converted
          against the line it is on where that is knowable and taken as bytes
          where it is not -- which is exact under `utf-8` and right under
          `utf-16` for every line that is ASCII, and those are the two cases a
          declaration is almost always in. It degrades to a column a little
          left of the name and never to a wrong line. }
        source := '';
        if hit.declFile = 0 then begin
          at := IndexOf(uri);
          if at <> 0 then begin
            d := VecGet(DocVec, Document, docs, at);
            LineOf(d.text, hit.declLine, source)
          end
        end;
        result := JsonNewObject;
        if hit.declFile = 0 then JsonPut(result, 'uri', JsonNewText(uri))
        else JsonPut(result, 'uri', JsonNewText(PathToUri(path)));
        JsonPut(result, 'range',
                NameRange(source, hit.declLine, hit.declCol, hit.declLen))
      end;
  if result = nil then result := JsonNewNull;
  JsonPut(reply, 'result', result);
  Send(reply);
  JsonFree(reply)
end;

{ `textDocument/hover`, as `MarkupContent` of kind `plaintext` with the range
  the answer is about.

  What it shows is the compiler's own two words -- 6.7.3.1's
  `variable-parameter`, 6.4.7's `discriminant`, the type as `WriteTypeName`
  spells it -- with the name sliced out of the document, because the pool
  holds the folded spelling and `CaseTest` would otherwise be shown back as
  `casetest`. A procedure has no type and the compiler writes `?` for one, so
  the kind stands alone there rather than a question mark being shown to a
  reader as if it meant something. }
procedure Hover(id: JsonPtr; params: JsonPtr);
var uri: DocUri;
    line, col, at: integer;
    hit: UseHit;
    path: PathName;
    d: Document;
    source: DiagLine;
    name, body: DiagLine;
    reply, result, content: JsonPtr;
begin
  reply := NewResponse(id);
  result := nil;
  uri := UriOf(params);
  AskedAt(params, uri, line, col);
  if (line >= 1) and (col >= 1) then
    if FindUse(uri, line, col, hit, path) then begin
      at := IndexOf(uri);
      source := '';
      if at <> 0 then begin
        d := VecGet(DocVec, Document, docs, at);
        LineOf(d.text, hit.line, source)
      end;
      name := '';
      if (hit.col >= 1) and (hit.len > 0)
         and (hit.col + hit.len - 1 <= length(source)) then
        name := source[hit.col..hit.col + hit.len - 1];
      body := hit.kind;
      if name <> '' then body := body + ' ' + name;
      if (hit.denotes <> '') and (hit.denotes <> '?') then
        body := body + ': ' + hit.denotes;
      content := JsonNewObject;
      JsonPut(content, 'kind', JsonNewText('plaintext'));
      JsonPut(content, 'value', JsonNewText(body));
      result := JsonNewObject;
      JsonPut(result, 'contents', content);
      JsonPut(result, 'range', NameRange(source, hit.line, hit.col, hit.len))
    end;
  if result = nil then result := JsonNewNull;
  JsonPut(reply, 'result', result);
  Send(reply);
  JsonFree(reply)
end;

{ --- MCP ------------------------------------------------------------------ }

{ The same program answering a different protocol (ADR-0241), and the reason
  it is the same program is that almost nothing here is about a protocol:
  `ImportsFor` reads a build description, `Compile` starts a compiler,
  `DiagnosticsIn` reads what it said. Only the framing, the method names and
  the shape of an answer differ, and this section is all three.

  **Who is asking is what differs.** LSP serves a person in an editor and its
  unit is a *document the client is holding*; MCP serves an agent working on a
  checkout and its unit is a **file on disk**. So there is no document store on
  this side and no scratch copy: the path is compiled where it lies. That is
  not an economy, it is the honest reading of the two protocols -- an editor's
  buffer may never have been saved, and an agent's file always has been. }

{ One content item of type `text`, which is the whole of what these tools
  return. MCP admits structured content beside it and these do not use it:
  what `--dump-symbols` and the diagnostics carry is already a line format, a
  reader of this is a language model, and a second encoding of the same answer
  would be a second thing to keep true. }
function TextContent(body: JsonPtr; failed: boolean): JsonPtr;
var res, arr, item: JsonPtr;
begin
  item := JsonNewObject;
  JsonPut(item, 'type', JsonNewText('text'));
  JsonPut(item, 'text', body);
  arr := JsonNewArray;
  JsonAppend(arr, item);
  res := JsonNewObject;
  JsonPut(res, 'content', arr);
  { "Tool Execution Errors: reported in tool results with isError: true" --
    a tool that ran and could not do the job, as against a protocol error,
    which is a request that should not have been made. }
  JsonPut(res, 'isError', JsonNewBoolean(failed));
  TextContent := res
end;

{ A tool's descriptor. Every tool here takes one required `path` and nothing
  else, so the schema is built rather than written out per tool -- a second
  shape would be a second function and this is not one yet. }
function PathTool(name: JsonName; title: JsonLine; what: JsonLine;
                  arg: JsonLine): JsonPtr;
var t, schema, props, path, req: JsonPtr;
begin
  path := JsonNewObject;
  JsonPut(path, 'type', JsonNewText('string'));
  JsonPut(path, 'description', JsonNewText(arg));
  props := JsonNewObject;
  JsonPut(props, 'path', path);
  req := JsonNewArray;
  JsonAppend(req, JsonNewText('path'));
  schema := JsonNewObject;
  JsonPut(schema, 'type', JsonNewText('object'));
  JsonPut(schema, 'properties', props);
  JsonPut(schema, 'required', req);
  t := JsonNewObject;
  JsonPut(t, 'name', JsonNewText(name));
  JsonPut(t, 'title', JsonNewText(title));
  JsonPut(t, 'description', JsonNewText(what));
  JsonPut(t, 'inputSchema', schema);
  PathTool := t
end;

{ What this server offers, and it is exactly what the compiler can answer
  about a program. Compiling, running the suite and reading a file are all
  things a shell already does better; what a shell cannot do is tell an agent
  where a name is declared without a regular expression guessing at Pascal --
  which is the mistake ADR-0229 and ADR-0230 moved a whole gate away from. }
function ToolList: JsonPtr;
var arr: JsonPtr;
begin
  arr := JsonNewArray;
  JsonAppend(arr, PathTool('outline', 'Outline a Pascal source',
    'Every name a source file declares -- constants, types, fields, '
    + 'variables, procedures and functions -- with the line and column it '
    + 'was written at and how deeply it nests. Answers for a file that does '
    + 'not compile, because it stops after the parse.',
    'Path to a .pas file'));
  JsonAppend(arr, PathTool('diagnostics', 'Compile a Pascal source',
    'What the compiler says about a source file, one diagnostic to a line as '
    + 'file:line:col: error: message. Imports are resolved from the '
    + '.components sidecar beside the file or under the workspace, so a '
    + 'module is not reported as undeclared names.',
    'Path to a .pas file'));
  ToolList := arr
end;

{ The `path` argument, made absolute, or the empty string where there is none
  this program can hold.

  **Absolute, and that is not tidiness.** `ImportsFor` compares the file it is
  asked about against the entries of a `.components`, which it resolves
  against the sidecar's own directory -- so two spellings of one file are two
  strings and a relative path matches nothing. It was `lib/dialect/pasjson.pas`
  reporting 48 diagnostics again, which is exactly the defect ADR-0238
  answered, arriving a second time by a different road. `Resolve` returns
  `rel` unchanged when it is already absolute, so a caller that gave a full
  path is not touched. }
function PathArg(params: JsonPtr): PathName;
var args: JsonPtr; p: PathName;
begin
  args := JsonMember(params, 'arguments');
  if JsonTextInto(JsonMember(args, 'path'), p) <> errNone then p := ''
  else if p <> '' then p := Resolve(rootPath, p);
  PathArg := p
end;

{ A compilation's output as one text value, line by line, so that nothing
  passes through a 255-character bottleneck on the way. }
function LinesAsText(lines: StrVecPtr; skip: boolean): JsonPtr;
var v: JsonPtr; i: integer; text: StrItem;
begin
  v := JsonNewText('');
  for i := 1 to SVecLen(lines) do begin
    text := SVecGet(lines, i);
    { `skip` drops what is not a diagnostic, which is most of what a
      compilation writes and none of what a caller asked for. }
    if (not skip) or DiagParse(text).ok then begin
      JsonTextAdd(v, text);
      JsonTextAdd(v, chr(10))
    end
  end;
  LinesAsText := v
end;

{ A whole file, so that a line of it can be found without reopening it.

  `PasFile.ReadLine` is the routine for one line and is the wrong shape here:
  it reopens and rescans, which over the 1 624 symbols of
  `selfhost/apfront.pas` is 1 624 passes over 22 102 lines. The document is
  read once into a `JsonChars`, which grows on the heap and so needs no
  capacity guessed at, and `LineOf` -- written for the LSP side, where the
  document is already in hand -- answers from it unchanged. }
function ReadWhole(path: PathName; var b: JsonChars): boolean;
var f: bindable text; bt: BindingType; c: char;
begin
  JsonCharsNew(b);
  bt := binding(f);
  bt.name := path;
  bind(f, bt);
  if not binding(f).bound then begin
    unbind(f);
    exit(false)
  end;
  reset(f);
  while not eof(f) do
    if eoln(f) then begin
      JsonCharsAdd(b, chr(10));
      readln(f)
    end
    else begin
      read(f, c);
      JsonCharsAdd(b, c)
    end;
  unbind(f);
  ReadWhole := true
end;

{ The outline of a file on disk, rendered for a reader rather than for a
  parser: two spaces a level, the kind, the name as the *programmer* wrote it
  and the position. The compiler's own line is eight numbers and the folded
  spelling (ADR-0239, widened by ADR-0253); the source is read here to recover
  the case, as the LSP side reads the document it is holding.

  **Both readers count the fields, and this one was left behind once.**
  ADR-0253 put the declaration's extent in at positions 7 and 8, so the name
  moved from 7 to 9; the LSP side was moved with it and this was not. Nothing
  failed, because the next lines overwrite `name` with a slice of the source
  and every session here reads a file it can open -- so what broke was
  precisely the fallback, and the outline of an unreadable source would have
  been a column of end-line numbers. A field index is a place two readers
  agree, and there is no gate that compares them. }
function OutlineText(lines: StrVecPtr; var doc: JsonChars): JsonPtr;
var v: JsonPtr; i, depth, symLine, symCol, symLen: integer;
    text: StrItem; kind: ParseLine; name, srcLine: DiagLine;
    sym: SymRow;
    pad: StrItem;
begin
  v := JsonNewText('');
  for i := 1 to SVecLen(lines) do begin
    text := SVecGet(lines, i);
    if SymParse(text, sym) then begin
      depth := sym.depth;
      kind := sym.kind;
      symLine := sym.line;
      symCol := sym.col;
      symLen := sym.len;
      { The extent is read and not shown: this outline says where a
        declaration begins, not how far it runs. }
      name := sym.name;
      LineOf(doc, symLine, srcLine);
      if (symCol >= 1) and (symLen > 0)
         and (symCol + symLen - 1 <= length(srcLine)) then
        name := srcLine[symCol..symCol + symLen - 1];
      pad := '';
      while (length(pad) < 2 * depth) and (length(pad) < ItemMax - 40) do
        pad := pad + ' ';
      writestr(text, pad, kind, ' ', name, '  ', symLine:1, ':', symCol:1);
      JsonTextAdd(v, text);
      JsonTextAdd(v, chr(10))
    end
  end;
  OutlineText := v
end;

{ One tool call. }
procedure CallTool(id: JsonPtr; params: JsonPtr);
var reply, err, result: JsonPtr;
    name: JsonLine;
    path: PathName;
    cmd: CommandLine;
    words: CommandLine;
    lines: StrVecPtr;
    doc: JsonChars;
    r: RunResult;
    found: boolean;
begin
  reply := NewResponse(id);
  if JsonTextInto(JsonMember(params, 'name'), name) <> errNone then name := '';
  path := PathArg(params);
  { A request that should not have been made is a *protocol* error, which the
    specification separates from a tool that ran and could not do the job. }
  if (name <> 'outline') and (name <> 'diagnostics') then begin
    err := JsonNewObject;
    JsonPut(err, 'code', JsonNewInteger(MethodNotFound));
    JsonPut(err, 'message', JsonNewText('Unknown tool: ' + name));
    JsonPut(reply, 'error', err)
  end
  else if path = '' then begin
    err := JsonNewObject;
    JsonPut(err, 'code', JsonNewInteger(InvalidParams));
    JsonPut(err, 'message',
            JsonNewText('the tool ' + name + ' needs a string argument '
                        + '`path`, and a path this program can hold'));
    JsonPut(reply, 'error', err)
  end
  { And a file that is not there is the other kind: the request was
    well-formed and the job could not be done. }
  else if not Exists(path) then
    JsonPut(reply, 'result',
            TextContent(JsonNewText('no such file: ' + path), true))
  else begin
    words := '';
    if name = 'diagnostics' then found := ImportsFor(path, words);
    if name = 'outline' then
      found := CompilerCommand(' --dump-symbols', '', path, cmd)
    else
      found := CompilerCommand('', words, path, cmd);
    if not found then
      JsonPut(reply, 'result',
              TextContent(JsonNewText('the compiler command line would be '
                                      + 'longer than this program holds'),
                          true))
    else begin
      SVecNew(lines, 64);
      r := CaptureLines(cmd, lines);
      if not r.ok then
        JsonPut(reply, 'result',
                TextContent(JsonNewText('could not run the compiler: '
                                        + ErrorText(r.cause)), true))
      else begin
        if name = 'outline' then begin
          found := ReadWhole(path, doc);
          { A source the compiler read and this could not is possible and not
            worth refusing over: the outline is then the folded spellings,
            which is what the compiler knows. }
          result := OutlineText(lines, doc);
          JsonCharsFree(doc)
        end
        else
          result := LinesAsText(lines, true);
        JsonPut(reply, 'result', TextContent(result, false))
      end;
      SVecFree(lines)
    end
  end;
  Send(reply);
  JsonFree(reply)
end;

{ MCP's initialize. §Lifecycle: "If the server supports the requested protocol
  version, it MUST respond with the same version. Otherwise, the server MUST
  respond with another protocol version it supports." There is one here, so
  the answer is that one whatever was asked -- which is the second half of that
  sentence and not a refusal. }
procedure McpInitialize(id: JsonPtr; params: JsonPtr);
var reply, result, caps, tools, info: JsonPtr;
    asked: JsonLine;
begin
  if JsonTextInto(JsonMember(params, 'protocolVersion'), asked) <> errNone then
    asked := '';
  if (asked <> '') and (asked <> McpVersion) then
    Note('the client asked for MCP ' + asked + ' and this server speaks '
         + McpVersion);
  tools := JsonNewObject;
  caps := JsonNewObject;
  JsonPut(caps, 'tools', tools);
  info := JsonNewObject;
  JsonPut(info, 'name', JsonNewText('pasls'));
  JsonPut(info, 'version', JsonNewText(PaslsVersion));
  result := JsonNewObject;
  JsonPut(result, 'protocolVersion', JsonNewText(McpVersion));
  JsonPut(result, 'capabilities', caps);
  JsonPut(result, 'serverInfo', info);
  JsonPut(result, 'instructions',
          JsonNewText('Ask `outline` where something is declared in a Pascal '
                      + 'source and `diagnostics` what the compiler makes of '
                      + 'one. Both take a path to a .pas file. `outline` '
                      + 'answers for a file that does not compile.'));
  reply := NewResponse(id);
  JsonPut(reply, 'result', result);
  Send(reply);
  JsonFree(reply)
end;

{ One MCP message. Notifications carry no id and are answered with nothing,
  which is what `notifications/initialized` wants; a request this server does
  not implement is answered, because a client waiting on an id it never gets
  back is a client that hangs. }
procedure McpDispatch(msg: JsonPtr);
var method: JsonLine;
    id, params, reply: JsonPtr;
begin
  if JsonTextInto(JsonMember(msg, 'method'), method) <> errNone then begin
    Note('a message with no method was ignored');
    exit
  end;
  id := JsonMember(msg, 'id');
  params := JsonMember(msg, 'params');
  if method = 'initialize' then McpInitialize(id, params)
  else if method = 'notifications/initialized' then { nothing to do }
  else if method = 'ping' then begin
    { §Utilities/Ping: an empty result. Answered because a client may send one
      before anything else and a server that ignored it would look dead. }
    reply := NewResponse(id);
    JsonPut(reply, 'result', JsonNewObject);
    Send(reply);
    JsonFree(reply)
  end
  else if method = 'tools/list' then begin
    reply := NewResponse(id);
    params := JsonNewObject;
    JsonPut(params, 'tools', ToolList);
    JsonPut(reply, 'result', params);
    Send(reply);
    JsonFree(reply)
  end
  else if method = 'tools/call' then CallTool(id, params)
  else if id <> nil then Unsupported(id, method)
end;

{ --- the loop ------------------------------------------------------------- }

{ One message. The chain below dispatches on a string and so is nobody's
  enumeration: a method this server does not implement is answered when it is
  a request and ignored when it is a notification, which is what the
  specification asks for in each case. }
{ Which document a `textDocument/didChange` is about, or the empty string for
  any other message. Used to decide whether one change makes an earlier one
  stale (ADR-0257). }
function ChangedUri(msg: JsonPtr): DocUri;
var method: JsonLine;
begin
  ChangedUri := '';
  if JsonTextInto(JsonMember(msg, 'method'), method) = errNone then
    if method = 'textDocument/didChange' then
      ChangedUri := UriOf(JsonMember(msg, 'params'))
end;

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
  else if method = 'textDocument/definition' then Definition(id, params)
  else if method = 'textDocument/hover' then Hover(id, params)
  else if id <> nil then Unsupported(id, method)
end;

{ Where the compiler and the scratch file are. Both are overridable because a
  harness has to point them somewhere of its own, and both have a default
  because a user starting this from an editor sets no environment at all. }
{ Which protocol to speak, from the command line. AP 6.7.6.10's `argcount`
  and `argument` (ADR-0173) are required identifiers, so a program reads its
  arguments without declaring the program-parameters §6.5.1 would otherwise
  make it declare -- which matters here more than usual, because this program
  declares *none* on purpose: §6.9.1 makes the default file of `write` a
  program-parameter, so a stray `writeln` is a compile-time error rather than
  a corrupted frame. MCP asks for exactly that discipline in as many words:
  "The server MUST NOT write anything to its stdout that is not a valid MCP
  message." }
procedure ReadTransport;
var i: integer; arg: EnvText;
begin
  transport := tpLsp;
  for i := 1 to argcount do begin
    arg := argument(i);
    if arg = '--mcp' then transport := tpMcp
    else Note('ignoring an argument this program does not know: ' + arg)
  end
end;

procedure ReadEnvironment;
var mine: EnvText;
begin
  compilerCmd := LookupOr('PASLS_COMPILER', 'pascalc');
  { The process identifier is in the default name, and that is the whole of
    what keeps two servers on one machine out of each other's way
    (ADR-0242). It is not `mkstemp`'s guarantee and could not be: §6.7.5.6
    binds by *name*, so a file created exclusively would have to be opened a
    second time to be written, and the exclusivity is given up at that
    moment. What a name can carry is a number no other *live* process has,
    which is exactly the case this had to answer. }
  writestr(mine, ProcessId:1);
  scratchPath := LookupOr('PASLS_SCRATCH',
                          LookupOr('TMPDIR', '/tmp') + '/pasls-' + mine
                          + '.pas')
end;

var body: JsonChars;
    e: ErrorCode;
    parsed: JsonResult;
    at: integer;
    i: integer;
    d: Document;
    complaint: IOLine;
    { ADR-0257's queue of one. `nextBody` and `nextMsg` are the frame the
      drain read; `held` is one it read and did not want, dispatched after
      this turn's message so that ordering is exactly what the client sent. }
    nextBody: JsonChars;
    nextMsg: JsonResult;
    held: JsonPtr;

begin
  held := nil;
  ReadTransport;
  ReadEnvironment;
  encoding := peUtf16;
  { LSP is told its workspace at `initialize` and MCP is not: the protocol has
    a `roots` capability and it belongs to the *client*, reached by a request
    the server issues, which this server does not do. What it has instead is
    where it was started -- a client launches an MCP server as a subprocess,
    and an agent's subprocess is started in the checkout it is working on. So
    the walk that finds a `.components` has a root under both transports, from
    the place each protocol actually puts one (ADR-0241). }
  if transport = tpMcp then rootPath := PathOr(WorkingDirectory, '')
  else rootPath := '';
  LspOpen(reader, StdIn);
  VecInit(DocVec, docs, 4);
  running := true;
  while running do begin
    JsonCharsNew(body);
    { The one place the two transports differ on the way in. }
    if transport = tpMcp then e := JsonlRead(reader, body)
    else e := LspRead(reader, body);
    if e <> errNone then begin
      { The end of the input is how a client that was killed reaches us, and
        it is not a failure: an editor that goes away without saying `exit` is
        the ordinary way an editing session ends. }
      if e <> errAbsent then Note('unreadable frame: ' + ErrorText(e));
      running := false
    end else begin
      parsed := JsonParseChars(body, at);
      if parsed.ok then begin
        { ADR-0257: a change nobody will ever see the answer to is not
          compiled.

          A keystroke is a `didChange` carrying the whole document, so when
          two of them for one file are already waiting, compiling the first is
          work whose answer is stale before it is published. This drains what
          has *arrived* -- never waiting for more -- and keeps only the last
          change per file, which is what a reader pays for and the whole of
          the 933 ms a `didChange` behind work in flight was measured at.

          It is not a construct and does not need one, which is this row's
          third cheaper answer in a row: `select` for the sockets, a cache for
          the hovers, and a queue of one for this. What a thread would still
          buy is a *cancellable* compile, and that is a different sentence.

          The drain stops at the first message that is not a change of the
          same file, and that one is held rather than read again -- so
          ordering is preserved exactly, which is what the golden of two
          changes to two files checks. }
        if transport <> tpMcp then
          while (ChangedUri(parsed.val) <> '') and (held = nil) and
                LspPending(reader) do begin
            JsonCharsNew(nextBody);
            if LspRead(reader, nextBody) <> errNone then
              { The input ended or was refused mid-drain. Nothing is lost:
                this message is still dispatched below and the next turn of
                the loop reports it. }
            else begin
              nextMsg := JsonParseChars(nextBody, at);
              if not nextMsg.ok then begin
                writestr(complaint, 'a message that is not JSON was ignored',
                         ', at byte ', at:1, ': ',
                         ErrorText(nextMsg.cause));
                Note(complaint)
              end
              else if ChangedUri(nextMsg.val) = ChangedUri(parsed.val) then
              begin
                { The earlier change is superseded outright: a didChange
                  carries the whole document, so there is nothing in it the
                  later one does not also say. }
                JsonFree(parsed.val);
                parsed.val := nextMsg.val
              end
              else
                held := nextMsg.val
            end;
            JsonCharsFree(nextBody)
          end;
        if transport = tpMcp then McpDispatch(parsed.val)
        else Dispatch(parsed.val);
        JsonFree(parsed.val);
        if held <> nil then begin
          Dispatch(held);
          JsonFree(held);
          held := nil
        end
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
    JsonCharsFree(d.text);
    { And what the compiler last said about it (ADR-0252). A document the
      client never closed still holds one, and `heap-balance` is what said so:
      the sessions open documents and end without a didClose, which is what an
      editor does when it is killed. }
    if d.uses_ <> nil then SVecFree(d.uses_)
  end;
  VecFree(DocVec, docs)
end.
