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
       PasIO;
       PasEnv;
       PasStrVec;
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

{ --- compiling ------------------------------------------------------------ }

{ The document, as a file the compiler can open.

  A newline in the text becomes a line of the Pascal file; a carriage return
  is dropped, so a client that sends CRLF is read the same as one that does
  not. 6.6.5.2 appends the line terminator that a last line without one is
  missing, so a buffer the user has not finished typing still reaches the
  compiler as a whole file. }
procedure WriteScratch(var b: JsonChars);
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

    There is no check that the path can be written either, because there is
    nothing to check with: `rewrite` on a name that cannot be created is a
    run-time error and stops the program, and neither standard gives a program
    a way to ask beforehand. A server cannot survive a bad `PASLS_SCRATCH`,
    and that is a finding rather than an oversight. }
  bt := binding(scratchFile);
  if bt.bound then unbind(scratchFile);
  bt.name := scratchPath;
  bind(scratchFile, bt);
  rewrite(scratchFile);
  n := JsonCharsLen(b);
  for i := 1 to n do begin
    c := JsonCharsAt(b, i);
    if c = chr(10) then writeln(scratchFile)
    else if c <> chr(13) then write(scratchFile, c)
  end;
  { Unbinding closes it, which is what makes the bytes readable by the process
    started on the next line. }
  unbind(scratchFile)
end;

{ Compile the scratch file and answer everything the compiler said.

  The redirection is deliberate. This compiler writes its diagnostics to
  `output` -- there being no second stream a standard Pascal program can
  name -- but `tools/pascalcc`, which a user may just as well name in
  `PASLS_COMPILER`, moves them to standard error. Folding the two together is
  what makes either work. }
function Compile(var out: CaptureText): boolean;
var cmd: CommandLine;
    r: RunResult;
begin
  out := '';
  cmd := compilerCmd + ' ''' + scratchPath + ''' -o ''' + scratchPath
         + '.ll'' 2>&1';
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
begin
  at := IndexOf(uri);
  if at = 0 then exit;
  d := VecGet(DocVec, Document, docs, at);
  WriteScratch(d.text);
  if not Compile(out) then exit;
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

function EncodingName: JsonLine;
begin
  if encoding = peUtf8 then EncodingName := 'utf-8'
  else EncodingName := 'utf-16'
end;

procedure Initialize(id: JsonPtr; params: JsonPtr);
var reply, result, caps, info: JsonPtr;
begin
  Negotiate(params);
  reply := NewResponse(id);
  result := JsonNewObject;
  caps := JsonNewObject;
  JsonPut(caps, 'textDocumentSync', JsonNewInteger(SyncFull));
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
