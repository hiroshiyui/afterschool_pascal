{ What a case range may not be. Sema accumulates, so one run reports all of
  them; the parse-level refusal under --std=iso7185 is in
  selfhost/badparse/case-range-is-extended.pas instead. }
program CaseRangeErrors(output);
type
  colour = (red, green, blue);
  bad = record
    case tag: integer of
      1..5:  (a: integer);
      { overlapping ranges select two variants for the same tag value }
      4..8:  (b: char)
  end;
var
  i: integer;
  c: colour;
  v: bad;
begin
  case i of
    { a range that runs backwards denotes no values at all, and a label
      selecting nothing can only be a mistake }
    9..1: i := 1;
    { the two ends must be of one type }
    1..'z': i := 2;
    { and the whole range must be of the selector's type }
    red..blue: i := 3;
    { overlap with an earlier range, reported at the lowest shared value }
    20..30: i := 4;
    25..40: i := 5;
    { overlap between a range and a single constant, either way round }
    50: i := 6;
    45..55: i := 7
  end;
  case c of
    red..blue: c := red
  end;
  v.tag := 1;
  writeln(i:1)
end.
