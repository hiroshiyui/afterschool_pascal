{ PasParse -- parsing that reports, and the first module written to ADR-0120's
  result shape.

  PasText.TryParseInt is the same parse and answers `boolean` with the value
  written through a `var`. That shape works and has two costs a caller pays
  every time: the value exists whether or not it was parsed, so nothing stops a
  caller reading it after a false; and `false` says only that something went
  wrong, never what. This module answers one record that carries the value or
  the reason and never both.

  **The tag is not assigned here, and that is the point.** In this dialect a
  write to a variant's field activates that variant (ADR-0118), so `r := acc`
  *is* the statement that makes the result
  successful, and `r := errSyntax` is what makes it a failure -- the value's
  type says which outcome it is (AP 6.4.13). There is no line to forget,
  because the line that sets the tag is the line that sets the payload. A
  caller who reads `val` on a failed result does not get a stale integer; the
  read traps.

  That is also why this module is dialect-only. Under a Pascal that does not
  make the tag authoritative the same source parses and runs, and the tag is
  then whatever the record's storage happened to hold -- a result that lies.
  While there were conformance modes ADR-0119 made that unlinkable, the mode
  being part of a module's linkage name; ADR-0232 removed them, so what stops
  it now is that there is no such Pascal here to compile this under. }

module PasParse;

export PasParse = (ParseMax, ParseLine, IntResult,
                   ParseInt, IntResultText);

{ 6.11.1 puts the import-part inside the module-block, after the export-part:
  what a module exports is part of its heading and what it imports is not. }
import PasError;

const
  ParseMax = 255;

type
  ParseLine = string(ParseMax);

  { ADR-0120's shape, written by the language since AP 6.4.13 (ADR-0176):
    `T ! E` denotes the record this module used to declare -- tag `ok`, value
    `val`, reason `cause` -- so the shape is one type rather than a convention
    each module copies, and the field names are the same in every module. }
  IntResult = Fallible(integer);

{ `s` as an integer, or the reason it is not one.

  Accepts optional surrounding spaces and an optional leading sign, then one or
  more decimal digits and nothing else. `errSyntax` for anything else, including
  the empty string and a lone sign; `errRange` for a value outside
  -maxint..maxint, detected *before* it is formed, because forming it would
  trap (ADR-0014). }
function ParseInt(s: ParseLine) = r: IntResult;

{ A result as a sentence, for a caller assembling a message rather than
  branching. }
function IntResultText(r: IntResult) = t: ErrText;

end;

function ParseInt;
var i, acc, digit: integer; bad: boolean; any: boolean; b: ParseLine;
    code: ErrorCode;
begin
  b := s;
  { TrimAll's job, done here rather than imported: PasText is an Extended
    Pascal module and ADR-0119 will not link one into a dialect program. The
    duplication is the price of the two layers and is named in ADR-0120.

    Both loops are written the obvious way, and AP 6.5.6 (ADR-0219) is what
    lets them be: `b[2..length(b)]` on a string of one space is `b[2..1]`, the
    empty substring, and under 6.5.6 as the standard states it that stopped the
    program. The guard this needed instead was two extra lines here, an
    invariant to reconstruct for the second loop, and a defect that shipped. }
  while (length(b) > 0) and (b[1] = ' ') do
    b := b[2..length(b)];
  while (length(b) > 0) and (b[length(b)] = ' ') do
    b := b[1..length(b) - 1];

  i := 1;
  bad := false;
  code := errSyntax;
  if (length(b) >= 1) and ((b[1] = '+') or (b[1] = '-')) then
    i := 2;
  acc := 0;
  any := false;
  while (i <= length(b)) and not bad do begin
    if (b[i] >= '0') and (b[i] <= '9') then begin
      digit := ord(b[i]) - ord('0');
      { before the multiply, not after: a value above maxint traps rather than
        wrapping, so it cannot be formed and then rejected }
      if acc > (maxint - digit) div 10 then begin
        bad := true;
        code := errRange
      end
      else begin
        acc := acc * 10 + digit;
        any := true
      end
    end
    else
      bad := true;
    i := i + 1
  end;

  { One assignment decides both halves. There is no `r.ok := ...` on either
    path and there must not be one: the write to the field is what sets the
    tag, and an explicit tag assignment would be a second opinion able to
    disagree with the payload -- which is the whole thing ADR-0118 removes. }
  if bad or not any then
    r := code
  else if b[1] = '-' then
    r := -acc
  else
    r := acc
end;

function IntResultText;
begin
  if r.ok then t := 'parsed' else t := ErrorText(r.cause)
end;

end.
