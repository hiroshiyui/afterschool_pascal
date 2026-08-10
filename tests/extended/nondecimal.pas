{ ISO/IEC 10206:1991 §6.1.5 adds the extended number to unsigned-integer:

    extended-number = base '#' extended-digit-sequence
    extended-digit  = digit | letter

  The base is a decimal digit-sequence with a value in 2..36, and a letter is
  the digit worth ten more than its position -- so base 36 runs 0..9 then a..z.
  It is a lexical rule and nothing else: what the parser receives is an integer
  literal like any other, which is why `16#ff` may be a constant, a case label
  or a subrange bound with no rule of its own anywhere later.

  Not a valid ISO 7185 program: `#` is not a character of that language. }
program NonDecimal(output);
const
  mask = 16#ffff;
  { a base-2 literal wide enough to be worth writing that way }
  flags = 2#1000000000000001;
type
  nibble = 16#0..16#f;
var
  i: integer;
  n: nibble;

begin
  { every base has the same value written in it }
  writeln(16#ff:1, ' ', 8#377:1, ' ', 2#11111111:1, ' ', 10#255:1);

  { letters are digits, and their case does not matter -- the same rule
    identifiers follow }
  writeln(16#beef:1, ' ', 16#BEEF:1, ' ', 16#BeEf:1);

  { base 36, where every letter is a digit }
  writeln(36#z:1, ' ', 36#10:1, ' ', 36#zz:1);

  { the largest value there is, written in the base that makes it obvious }
  writeln(16#7fffffff:1);

  writeln(mask:1, ' ', flags:1);

  { an extended number is a constant like any other, so it reaches every place
    a constant may go }
  for n := 16#0 to 16#f do
    if n = 16#a then writeln('the tenth nibble is ', n:1);

  i := 8#17;
  case i of
    2#1..2#1110: writeln('no');
    16#f: writeln('fifteen, three ways of writing it');
    otherwise writeln('no')
  end;

  { and the base itself is decimal, always -- 10#16 is sixteen, not twenty-two }
  writeln(10#16:1)
end.
