{ PasText. Split and Join are checked as inverses rather than one example at a
  time, and the parser is checked on what it must *refuse* -- which is the half
  a happy-path test misses, and the half that matters because the alternative
  to refusing is trapping. }
program lib_text(output);

import PasText;

type Eight = Parts(8);
     Two = Parts(2);

var
  p: Eight;
  small: Two;
  n, i, v: integer;
  ok: boolean;

{ Split then Join must give back what went in. }
procedure RoundTrip(s: TextLine; sep: char);
var q: Eight; k: integer; back: TextLine;
begin
  Split(s, sep, q, k);
  back := Join(q, k, sep);
  write('  "', s, '" -> ', k:1, ' pieces -> "', back, '"');
  if back = s then writeln('  same') else writeln('  DIFFERENT')
end;

begin
  writeln('trimming');
  writeln('  start "', TrimStart('   abc  '), '|"');
  writeln('  end   "', TrimEnd('   abc  '), '|"');
  writeln('  all   "', TrimAll('   abc  '), '|"');
  writeln('  empty "', TrimAll('     '), '|"');

  writeln('splitting');
  Split('a,b,c', ',', p, n);
  write('  3 pieces: ', n:1, ' ->');
  for i := 1 to n do write(' "', p[i], '"');
  writeln;

  { n separators give n + 1 pieces, so the ends and the doubles are all empty }
  Split(',a,,b,', ',', p, n);
  write('  with empties: ', n:1, ' ->');
  for i := 1 to n do write(' "', p[i], '"');
  writeln;

  Split('', ',', p, n);
  writeln('  empty string gives ', n:1, ' piece');

  Split('nosep', ',', p, n);
  writeln('  no separator gives ', n:1, ' piece: "', p[1], '"');

  { more pieces than the destination holds: the first cap are written }
  Split('a,b,c,d,e', ',', small, n);
  write('  into Parts(2): ', n:1, ' ->');
  for i := 1 to n do write(' "', small[i], '"');
  writeln('   would have been ', CountChar('a,b,c,d,e', ',') + 1:1);

  writeln('round trips');
  RoundTrip('a,b,c', ',');
  RoundTrip(',a,,b,', ',');
  RoundTrip('single', ',');
  RoundTrip('', ',');
  RoundTrip('x y z', ' ');

  writeln('counting');
  writeln('  commas in "a,b,,c" = ', CountChar('a,b,,c', ','):1);
  writeln('  z in "a,b,,c"      = ', CountChar('a,b,,c', 'z'):1);

  writeln('parsing what should work');
  ok := TryParseInt('123', v);       writeln('  "123"        ', ok, ' ', v:1);
  ok := TryParseInt('  42  ', v);    writeln('  "  42  "     ', ok, ' ', v:1);
  ok := TryParseInt('-7', v);        writeln('  "-7"         ', ok, ' ', v:1);
  ok := TryParseInt('+7', v);        writeln('  "+7"         ', ok, ' ', v:1);
  ok := TryParseInt('0', v);         writeln('  "0"          ', ok, ' ', v:1);
  ok := TryParseInt('2147483647', v);writeln('  maxint       ', ok, ' ', v:1);
  ok := TryParseInt('-2147483647', v);writeln('  -maxint      ', ok, ' ', v:1);

  writeln('parsing what must be refused, not trapped');
  v := -999;
  ok := TryParseInt('', v);          writeln('  ""           ', ok, ' ', v:1);
  ok := TryParseInt('abc', v);       writeln('  "abc"        ', ok, ' ', v:1);
  ok := TryParseInt('12x', v);       writeln('  "12x"        ', ok, ' ', v:1);
  ok := TryParseInt('-', v);         writeln('  "-"          ', ok, ' ', v:1);
  ok := TryParseInt('1 2', v);       writeln('  "1 2"        ', ok, ' ', v:1);
  { one past maxint, which would trap if it were formed before being checked }
  ok := TryParseInt('2147483648', v);writeln('  maxint+1     ', ok, ' ', v:1);
  ok := TryParseInt('99999999999', v);writeln('  far over     ', ok, ' ', v:1);

  writeln('defaulting and formatting');
  writeln('  ParseIntOr("55", 0)  = ', ParseIntOr('55', 0):1);
  writeln('  ParseIntOr("no", -1) = ', ParseIntOr('no', -1):1);
  writeln('  IntToStr(0)      = "', IntToStr(0), '"');
  writeln('  IntToStr(-4096)  = "', IntToStr(-4096), '"');
  writeln('  IntToStr(maxint) = "', IntToStr(maxint), '"');

  { round trip through both directions }
  ok := TryParseInt(IntToStr(-12345), v);
  writeln('  IntToStr then TryParseInt: ', ok, ' ', v:1)
end.
