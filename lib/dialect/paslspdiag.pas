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

  **The character is a byte offset and the protocol may not want one.** LSP
  positions are UTF-16 code units by default and UTF-8 is negotiable since
  3.17. This module writes the compiler's column, which counts bytes, so a
  line containing no character above U+007F is correct under every encoding
  and a line containing one is wrong under two of the three. AP 6.4.15 offers
  no integer index at all, and `PasUnicode` answers in scalar values, which is
  a third unit again -- so the conversion this needs is one nothing in the
  tree can do today. `doc/roadmap.md` names it as the sharpest edge in the
  language-server idea; this is where it lands. }

module PasLspDiag;

export PasLspDiag = (DiagMax, DiagText, Diagnostic, DiagResult,
                     DiagParse, DiagJson, DiagPublish);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError; PasJson;

const
  { A diagnostic that does not fit is truncated rather than refused: a message
    is for a human to read and half of one is worth more than an error code. }
  DiagMax = 255;

type
  DiagText = string(DiagMax);

  { What the compiler said, in the compiler's own numbering. }
  Diagnostic = record
    line: integer;
    col: integer;
    message: DiagText
  end;

  { AP 6.4.13's fallible type. `errSyntax` for a line that is not a
    diagnostic, which is the ordinary case -- most of what a compilation
    writes is not one. }
  DiagResult = Diagnostic ! ErrorCode;

{ Read one line of `pascalc` output. A line that is not `file:line:col: error:`
  answers `errSyntax`, and a caller sweeping a compilation's output is expected
  to meet many of those and skip them. }
function DiagParse(s: DiagText) = r: DiagResult;

{ One `Diagnostic` as the protocol's own object: a zero-width range at the
  position, severity 1 (Error), and `pascalc` as the source. The caller owns
  what comes back and frees it with `JsonFree`, or appends it to something it
  frees. }
function DiagJson(d: Diagnostic): JsonPtr;

{ A `textDocument/publishDiagnostics` notification for `uri`, over an array
  `diags` the caller built with `JsonNewArray` and `JsonAppend`. The array
  becomes part of the result and must not be freed separately. }
function DiagPublish(uri: JsonLine; diags: JsonPtr): JsonPtr;

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

  { `: error: ` is the whole of what this recognises. The compiler emits no
    warning and no note, so a second severity would be a branch no input
    reaches -- and `doc/sop.md` is clear about what an unreachable branch is
    worth here. }
  if not bad then begin
    start := i + 1;
    if (start + 7 <= length(s)) and (s[start .. start + 7] = ' error: ') then
      i := start + 8
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

function DiagJson;
var pos, range, obj: JsonPtr;

  { The protocol's Position, 0-based where the compiler is 1-based. }
  function At: JsonPtr;
  var p: JsonPtr;
  begin
    p := JsonNewObject;
    JsonPut(p, 'line', JsonNewInteger(d.line - 1));
    JsonPut(p, 'character', JsonNewInteger(d.col - 1));
    At := p
  end;

begin
  range := JsonNewObject;
  JsonPut(range, 'start', At);
  { A zero-width range: the compiler reports a point and inventing an end for
    it would be inventing a claim about the source. An editor shows a caret. }
  JsonPut(range, 'end', At);

  obj := JsonNewObject;
  JsonPut(obj, 'range', range);
  JsonPut(obj, 'severity', JsonNewInteger(1));
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
