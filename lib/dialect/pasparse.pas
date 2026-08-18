{ PasParse -- parsing that reports, and the first module written to ADR-0120's
  result shape.

  PasText.TryParseInt is the same parse and answers `boolean` with the value
  written through a `var`. That shape works and has two costs a caller pays
  every time: the value exists whether or not it was parsed, so nothing stops a
  caller reading it after a false; and `false` says only that something went
  wrong, never what. This module answers one record that carries the value or
  the reason and never both.

  **The tag is not assigned here, and that is the point.** Under
  --std=afterschool a write to a variant's field activates that variant
  (ADR-0118), so `r.num := acc` *is* the statement that makes the result
  successful, and `r.code := errSyntax` is what makes it a failure. There is no
  line to forget, because the line that sets the tag is the line that sets the
  payload. A caller who reads `num` on a failed result does not get a stale
  integer; the read traps.

  That is also why this module is dialect-only. Compiled under --std=extended
  the same source parses and runs, and the tag would then be whatever the
  record's storage happened to hold -- a result that lies. ADR-0119 stops that
  from being possible: the mode is part of a module's linkage name, so this
  cannot be linked into a conformance-mode program at all. }

module PasParse;

export PasParse = (ParseMax, ParseLine, IntResult,
                   ParseInt, IntOr, ResultText);

{ 6.11.1 puts the import-part inside the module-block, after the export-part:
  what a module exports is part of its heading and what it imports is not. }
import PasError;

const
  ParseMax = 255;

type
  ParseLine = string(ParseMax);

  { ADR-0120's shape. The tag is spelled `ok` in every result record; the
    payload's name is the module's to choose, because with no generics the
    payload type is part of the layout and no shared type could carry it.

    `boolean` as the tag-type is not laziness: 6.4.3.3 with ADR-0096 requires
    a variant part's labels to be exactly its tag-type's values, and `boolean`
    has precisely the two a result needs. A three-state code as the tag would
    have to name every one of its values as an arm. }
  IntResult = record
    case ok: boolean of
      true:  (num: integer);
      false: (code: ErrorCode)
    end;

{ `s` as an integer, or the reason it is not one.

  Accepts optional surrounding spaces and an optional leading sign, then one or
  more decimal digits and nothing else. `errSyntax` for anything else, including
  the empty string and a lone sign; `errRange` for a value outside
  -maxint..maxint, detected *before* it is formed, because forming it would
  trap (ADR-0014). }
function ParseInt(s: ParseLine) = r: IntResult;

{ The value of a successful result, or `whenBad` for a failed one -- the
  ParseIntOr shape, kept because a caller with a sensible default should not
  have to write the case. Reading `num` here is safe for the reason the dialect
  makes it safe: the read is inside the arm the tag selects. }
function IntOr(r: IntResult; whenBad: integer): integer;

{ A result as a sentence, for a caller assembling a message rather than
  branching. }
function ResultText(r: IntResult) = t: ErrText;

end;

function ParseInt;
var i, acc, digit: integer; bad: boolean; any: boolean; b: ParseLine;
    code: ErrorCode;
begin
  b := s;
  { TrimAll's job, done here rather than imported: PasText is an Extended
    Pascal module and ADR-0119 will not link one into a dialect program. The
    duplication is the price of the two layers and is named in ADR-0120. }
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
    r.code := code
  else if b[1] = '-' then
    r.num := -acc
  else
    r.num := acc
end;

function IntOr;
begin
  if r.ok then IntOr := r.num else IntOr := whenBad
end;

function ResultText;
begin
  if r.ok then t := 'parsed' else t := ErrorText(r.code)
end;

end.
