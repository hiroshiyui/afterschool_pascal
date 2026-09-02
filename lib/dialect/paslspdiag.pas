{ PasLspDiag -- what `pascalc` said, as the Language Server Protocol says it.

  `doc/roadmap.md` proposes a language server as **the caller**: the program
  large enough to say whether this dialect is pleasant to write in, which no
  gate here can measure. `PasLsp` frames the messages and `PasJson` reads and
  writes them; between those two and a server there is exactly one thing
  missing, and this is it -- the compiler's diagnostics, in the protocol's
  shape.

  **That chapter said `PasParse` reads them.** It does not: `PasParse` parses
  an integer and nothing else, which is the third thing that chapter guessed
  wrong about its own prerequisites, after the JSON row and after `PasStream`
  framing a message it cannot frame. The pattern is worth naming rather than
  fixing three times: a paragraph naming a module by what its *name* suggests
  is a guess, and this project's own register calls that shape out for gates.

  **The compiler's line is one shape and this module knows only that shape.**

      file.pas:12:7: error: 'x' is not declared

  A path, a line, a column, the word `error`, and the message -- and the path
  is taken up to the **first** colon, so a path containing one is not read
  correctly. That is a real limitation and not a hypothetical: a directory
  named `a:b` is legal on this system. It is left because the alternative is
  guessing which colon is the separator, and because the server hands the
  compiler a path it chose itself.

  **The protocol counts from zero and the compiler counts from one.** LSP
  positions are 0-based in both line and character; `ErrorAt` writes 1-based
  in both. The conversion is here, in one place, and `DiagJson` is the only
  routine that performs it -- a `Diagnostic` holds what the compiler said, so
  a caller printing one sees the numbers the compiler printed.

  **The character is a byte offset and the protocol counts something else.**
  LSP positions are UTF-16 code units by default; UTF-8 is negotiable since
  3.17 and is not guaranteed. `ErrorAt` counts bytes -- measured rather than
  assumed: an `e` with an acute before an error on the same line moves the
  compiler's column by two and the protocol's by one. So a line holding
  nothing above U+007F is right under every encoding and a line holding one is
  wrong under the default.

  `doc/roadmap.md` named this as the sharpest edge in the language-server idea
  before any of it was written, and said the conversion was one nothing in the
  tree could do. **That was half wrong, which is the useful half.** The text
  model offers no integer index and never will, and `PasUnicode` answers in
  *scalar values*, which is a third unit again -- but the count the protocol
  wants is derivable from the scalars without an index existing at all: a
  scalar below U+10000 is one UTF-16 code unit and one at or above it is two.
  `Utf16Column` is that walk, and it is the whole of what was missing.

  Two consequences a reader should not have to rediscover. The conversion
  needs the **line**, which a `Diagnostic` does not carry and cannot -- the
  compiler reports a position and not a source -- so `DiagJson` takes it, and
  a caller with nothing to give passes the empty string and gets the byte
  column back unchanged. And it takes the **encoding**, because a server that
  negotiated `utf-8` must not convert: the compiler's own column is then
  exactly right, and converting it would be the defect. }

module PasLspDiag;

export PasLspDiag = (DiagMax, DiagText, DiagLineMax, DiagLine,
                     { 6.11.2: an enumerated type's values are constants of
                       their own and are exported one by one. }
                     PosEncoding, peUtf8, peUtf16,
                     DiagSeverity, dsError, dsWarning,
                     Diagnostic, DiagResult,
                     DiagParse, Utf16Column, DiagJson, DiagPublish);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError; PasJson; PasUnicode;

const
  { A diagnostic that does not fit is truncated rather than refused: a message
    is for a human to read and half of one is worth more than an error code. }
  DiagMax = 255;

  { A source line, for the column conversion. Longer than DiagMax because a
    line of a real program is not a message: the compiler itself has lines
    past 255 characters, and a column past the end of what was handed over is
    counted as bytes rather than refused. }
  DiagLineMax = 4096;

type
  DiagText = string(DiagMax);
  DiagLine = string(DiagLineMax);

  { What a Position.character counts. 3.17's `positionEncoding`, and the two
    values this server can produce: `utf-16` is the protocol's default and the
    one a client that says nothing means, `utf-8` is what a client may offer
    and what makes the compiler's own column exactly right. There is no
    `utf-32` here because nothing in the tree counts in it either. }
  PosEncoding = (peUtf8, peUtf16);

  { 3.17's DiagnosticSeverity, as far as this compiler can go: it writes an
    error and, since ADR-0272, a warning. There is no note and no hint,
    because nothing produces one -- a constant for a value no input can
    reach is the branch doc/sop.md refuses.

    The compiler's own word is what selects it, so this enumeration is the
    protocol's numbers arriving at exactly one place (`DiagJson`) rather than
    being carried around as 1 and 2. }
  DiagSeverity = (dsError, dsWarning);

  { What the compiler said, in the compiler's own numbering. }
  Diagnostic = record
    line: integer;
    col: integer;
    severity: DiagSeverity;
    message: DiagText
  end;

  { AP 6.4.13's fallible type. `errSyntax` for a line that is not a
    diagnostic, which is the ordinary case -- most of what a compilation
    writes is not one. }
  DiagResult = Diagnostic ! ErrorCode;

{ Read one line of `pascalc` output. A line that is neither
  `file:line:col: error:` nor `file:line:col: warning:` answers `errSyntax`,
  and a caller sweeping a compilation's output is expected to meet many of
  those and skip them. The severity word is the only difference between the
  two and it reaches `Diagnostic.severity`. }
function DiagParse(s: DiagText) = r: DiagResult;

{ The compiler's 1-based **byte** column on `line`, as a 1-based **UTF-16 code
  unit** column. Both are 1-based: this converts the unit and nothing else, and
  `DiagJson` is still the only place the 0-based subtraction happens.

  A scalar below U+10000 is one code unit and one at or above it is two, which
  is the whole rule. Three things are counted as one unit per byte instead,
  and all three are the same decision -- when the answer is not knowable, give
  back what the compiler said:

  * a column past the end of `line`, which is what a caller with no line to
    give produces by passing the empty string;
  * a column that falls *inside* a scalar, since the compiler pointed at a
    byte and there is no code unit at that position to name;
  * bytes that are not well-formed UTF-8, which a source file may hold and
    which the compiler read as bytes.

  A line with nothing above U+007F converts to itself, so a caller that never
  meets one cannot tell whether this is called. }
function Utf16Column(line: DiagLine; col: integer): integer;

{ One `Diagnostic` as the protocol's own object: a zero-width range at the
  position, the severity the compiler's own word gave, and `pascalc` as the
  source. The caller owns
  what comes back and frees it with `JsonFree`, or appends it to something it
  frees.

  `line` is the source line the diagnostic is on, needed only for the column
  conversion; the empty string is always safe and means "count bytes". `enc`
  is the position encoding the client and the server agreed on at
  `initialize`, and under `peUtf8` the line is not read at all. }
function DiagJson(d: Diagnostic; line: DiagLine; enc: PosEncoding): JsonPtr;

{ A `textDocument/publishDiagnostics` notification for `uri`, over an array
  `diags` the caller built with `JsonNewArray` and `JsonAppend`. The array
  becomes part of the result and must not be freed separately.

  The URI is schematic because it is a path and not a line: a client that can
  hold a longer one must not meet a shorter bound here (ADR-0291). }
function DiagPublish(uri: string; diags: JsonPtr): JsonPtr;

end;

function DiagParse;
var i, start: integer;
    d: Diagnostic;
    bad: boolean;

  { A run of digits ending at `i`, or -1. Written here rather than imported:
    `PasParse.ParseInt` takes a whole string and what this has is a slice of
    one, and cutting the slice out to hand it over would be two copies to
    avoid ten lines. }
  function Number: integer;
  var acc: integer;
  begin
    acc := -1;
    if (i <= length(s)) and (s[i] >= '0') and (s[i] <= '9') then begin
      acc := 0;
      while (i <= length(s)) and (s[i] >= '0') and (s[i] <= '9') do begin
        { A position above maxint div 10 is a file nobody wrote; refuse it
          rather than trap (ADR-0014). }
        if acc > (maxint - 9) div 10 then
          acc := -1
        else
          acc := acc * 10 + (ord(s[i]) - ord('0'));
        i := i + 1
      end
    end;
    Number := acc
  end;

begin
  bad := false;

  { the path, up to the first colon }
  i := 1;
  while (i <= length(s)) and (s[i] <> ':') do
    i := i + 1;
  if (i > length(s)) or (i = 1) then
    bad := true;

  if not bad then begin
    i := i + 1;
    d.line := Number;
    if (d.line < 1) or (i > length(s)) or (s[i] <> ':') then
      bad := true
  end;

  if not bad then begin
    i := i + 1;
    d.col := Number;
    if (d.col < 1) or (i > length(s)) or (s[i] <> ':') then
      bad := true
  end;

  { The severity word, which is the whole of what separates the two shapes
    the compiler writes. It emitted only errors until ADR-0272, and this said
    so -- *a second severity would be a branch no input reaches* -- which was
    true when it was written and is the comment a new severity has to come
    back and delete. There is still no note and no hint, for that same
    reason. }
  if not bad then begin
    start := i + 1;
    if (start + 7 <= length(s)) and (s[start .. start + 7] = ' error: ') then
      begin
        d.severity := dsError;
        i := start + 8
      end
    else if (start + 9 <= length(s)) and
            (s[start .. start + 9] = ' warning: ') then
      begin
        d.severity := dsWarning;
        i := start + 10
      end
    else
      bad := true
  end;

  if bad then
    r := errSyntax
  else begin
    if length(s) - i + 1 > DiagMax then
      d.message := s[i .. i + DiagMax - 1]
    else
      d.message := s[i .. length(s)];
    { One assignment decides both halves: the write to the field is what sets
      the tag (ADR-0118), so there is no `r.ok :=` here and must not be. }
    r := d
  end
end;

function Utf16Column;
var at, next, units: integer;
    cp: Scalar;
begin
  { Column 1 is column 1 under every encoding, and the loop below never runs
    for it -- which is also the answer for a diagnostic at the start of a
    line, where there is nothing before it to count. }
  units := 1;
  at := 1;
  while at < col do begin
    next := 0;
    if at <= length(line) then next := NextScalar(line, at, cp);
    if (next = 0) or (next > col) then begin
      { Past the end, ill-formed, or a column inside a scalar: one unit per
        remaining byte, which hands the compiler's own column back. }
      units := units + (col - at);
      at := col
    end else begin
      { 65536 is U+10000: at and above it a scalar is a surrogate pair. }
      if cp >= 65536 then units := units + 2 else units := units + 1;
      at := next
    end
  end;
  Utf16Column := units
end;

function DiagJson;
var pos, range, obj: JsonPtr;
    character, sev: integer;

  { The protocol's Position, 0-based where the compiler is 1-based. }
  function At: JsonPtr;
  var p: JsonPtr;
  begin
    p := JsonNewObject;
    JsonPut(p, 'line', JsonNewInteger(d.line - 1));
    JsonPut(p, 'character', JsonNewInteger(character - 1));
    At := p
  end;

begin
  { Under utf-8 the compiler's column is already the protocol's, and
    converting it would be the defect rather than the fix. }
  if enc = peUtf16 then character := Utf16Column(line, d.col)
  else character := d.col;
  range := JsonNewObject;
  JsonPut(range, 'start', At);
  { A zero-width range: the compiler reports a point and inventing an end for
    it would be inventing a claim about the source. An editor shows a caret. }
  JsonPut(range, 'end', At);

  { 3.17's DiagnosticSeverity: 1 is Error and 2 is Warning. A case and not an
    `if`, so that a severity added to the enumeration is a translation error
    here rather than an arm quietly taking the other's number. }
  case d.severity of
    dsError:   sev := 1;
    dsWarning: sev := 2
  end;

  obj := JsonNewObject;
  JsonPut(obj, 'range', range);
  JsonPut(obj, 'severity', JsonNewInteger(sev));
  JsonPut(obj, 'source', JsonNewText('pascalc'));
  JsonPut(obj, 'message', JsonNewText(d.message));
  pos := obj;
  DiagJson := pos
end;

function DiagPublish;
var msg, params: JsonPtr;
begin
  params := JsonNewObject;
  JsonPut(params, 'uri', JsonNewText(uri));
  JsonPut(params, 'diagnostics', diags);

  msg := JsonNewObject;
  JsonPut(msg, 'jsonrpc', JsonNewText('2.0'));
  { A notification and not a request: no `id`, and the client sends no reply. }
  JsonPut(msg, 'method', JsonNewText('textDocument/publishDiagnostics'));
  JsonPut(msg, 'params', params);
  DiagPublish := msg
end;

end.
