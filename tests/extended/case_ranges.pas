{ ISO/IEC 10206:1991 generalised the case-constant-list to allow ranges:

    case-constant-list = case-range (',' case-range)*
    case-range         = case-constant ('..' case-constant)?

  Both the case statement (§6.8.3.5) and a variant (§6.4.3.3) name that
  production, so a range is legal in either and neither gets a rule of its own.

  A range is *tested*, never expanded into its members -- `1..maxint` is a
  legal label list and two billion switch cases -- so what runs is a chain of
  comparisons ahead of the switch that the single constants still go into.

  Not a valid ISO 7185 program: there, a label list holds constants only. }
program CaseRanges(output);
const
  dozen = 12;
type
  code = 1..100;
  { a variant labelled by ranges, which is the same production }
  band = record
    case level: code of
      1..9:    (small: integer);
      10..99:  (medium: char);
      otherwise (large: boolean)
  end;
  bandptr = ^band;
var
  i, n: integer;
  ch: char;
  b: band;
  bp: bandptr;

procedure Classify(v: integer);
begin
  write(v:4, ': ');
  case v of
    { a range, a list of ranges, and a plain constant side by side }
    0: writeln('zero');
    1..9: writeln('one digit');
    10..99, 1000..9999: writeln('two digits or four');
    100..999: writeln('three digits');
    otherwise writeln('bigger, or negative')
  end
end;

begin
  Classify(0);
  Classify(7);
  Classify(42);
  Classify(500);
  Classify(1234);
  Classify(70000);
  Classify(-1);

  { char ranges, the shape this feature exists for }
  n := 0;
  for ch := 'a' to 'z' do
    case ch of
      'a', 'e', 'i', 'o', 'u': n := n + 1;
      'b'..'d', 'f'..'h': n := n + 10;
      otherwise n := n + 100
    end;
  writeln('letters: ', n:1);

  { a range of one value is a single constant written the long way }
  case 5 of
    5..5: writeln('a range of one');
    otherwise writeln('no')
  end;

  { the ends are case-constants like any other, so a named constant is one }
  case 12 of
    dozen..dozen: writeln('a named bound');
    otherwise writeln('no')
  end;

  { the range nothing may enumerate: every positive integer in one label. A
    compiler that expanded a range into switch cases would not survive this
    line, which is why this one compares instead. }
  case 123456 of
    1..maxint: writeln('the whole positive half');
    otherwise writeln('no')
  end;

  { and without an otherwise, a value in no range still traps -- the ranges
    change what the switch tests, not what its default does }
  for i := 1 to 3 do
    case i of
      1..2: write('low ');
      3: writeln('high')
    end;

  b.level := 5;
  b.small := 11;
  writeln('band small: ', b.small:1);
  b.level := 50;
  b.medium := 'm';
  writeln('band medium: ', b.medium);
  b.level := 100;
  b.large := true;
  writeln('band large: ', b.large);

  { `new(p, c)` selects a variant by tag value, and a range claims every value
    in it -- 50 is not written anywhere in the record, but 10..99 covers it }
  new(bp, 50);
  bp^.level := 50;
  bp^.medium := 'n';
  writeln('newed medium: ', bp^.medium);
  dispose(bp, 50)
end.
