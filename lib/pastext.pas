{ PasText -- splitting, joining and parsing.

  PasStrings answers questions *about* one string and returns one string.
  PasText is where a string becomes several and back, which needs somewhere to
  put them: `Parts` is a schema array of strings, and the caller owns it. That
  shape is why this module could not have been written before the fix that
  landed with it -- a schema whose component contains a variable-string stopped
  the compiler.

  Two names are deliberately not here. `trim` and `substr` are **required
  identifiers** of ISO/IEC 10206:1991 (Annex C), so a module exporting either
  would force every caller to choose between the export and the standard
  function. `TrimEnd` below does what required `trim` does and exists only so
  the three trimming routines read alike; a caller happy with `trim` should use
  it.

  Parsing is written out by hand rather than through `readstr`, and that is the
  one decision here worth defending. 6.9.1's read of an integer takes the
  longest prefix that is a number and it is an **error** when there is none --
  it stops the program (ADR-0076). A library cannot offer "parse this if it is a
  number" on top of something that halts when it is not, so TryParseInt inspects
  the characters itself and answers false. It also detects overflow *before*
  forming the value, because forming it would trap (ADR-0014).

  `RealToStr` uses `readstr` and does not contradict that, which is worth
  stating because the two sit twenty lines apart. It reads back a string it
  has just written itself, out of digits and a point and an exponent, to find
  out whether that spelling names the value it started from; nothing a caller
  wrote reaches it. The rule is *never `readstr` on a caller's text*, and not
  *never `readstr`*.

  It is here rather than in `PasJson`, which is where ADR-0309 built it,
  because it stopped having one caller: `PasToml` renders the same doubles
  into a different format and would otherwise hold a second copy of a
  hundred-line search, which is the shape this repository treats as a defect
  in itself -- a copy free to drift. What is format-specific is what the two
  callers keep, and what is arithmetic is here. }

module PasText;

export PasText = (TextMax, TextLine, Parts,
                  TrimStart, TrimEnd, TrimAll,
                  Split, Join, CountChar,
                  TryParseInt, ParseIntOr, IntToStr, RealToStr);

const
  TextMax = 255;

type
  TextLine = string(TextMax);
  { A schematic formal takes its bounds from the actual (ADR-0040), so one
    compiled Split serves every size of destination and `dest.cap` reads what
    the caller declared. }
  Parts(cap: integer) = array [1..cap] of TextLine;

{ `s` without leading spaces. }
function TrimStart(s: TextLine): TextLine;

{ `s` without trailing spaces -- what required `trim` does, spelled to match
  its two neighbours. }
function TrimEnd(s: TextLine): TextLine;

{ `s` without leading or trailing spaces. }
function TrimAll(s: TextLine): TextLine;

{ Split `s` at every occurrence of `sep`, writing the pieces into `dest` from
  1 upwards and setting `count` to how many were written.

  Adjacent separators produce empty pieces and so does a separator at either
  end, which is what makes `Split` and `Join` inverse: n separators give n + 1
  pieces. An empty `s` gives one piece, the empty string.

  When there are more pieces than `dest` has room for, the first `dest.cap` are
  written and `count` is `dest.cap`. The caller detects that by comparing
  `count` with `CountChar(s, sep) + 1`, which is the piece count `s` would have
  produced; nothing is reported, because a library that halts cannot be tested. }
procedure Split(s: TextLine; sep: char; var dest: Parts; var count: integer);

{ The first `count` pieces of `src`, separated by `sep`. The inverse of Split
  for any `s` short enough to survive the round trip. }
function Join(var src: Parts; count: integer; sep: char): TextLine;

{ How many times `c` occurs in `s`. }
function CountChar(s: TextLine; c: char): integer;

{ Parse an optionally-signed decimal integer occupying the whole of `s` after
  surrounding spaces are ignored. Answers false and leaves `v` alone when `s`
  is empty, holds anything but digits and one optional sign, or names a value
  outside -maxint..maxint. Never traps and never halts. }
function TryParseInt(s: TextLine; var v: integer): boolean;

{ TryParseInt's value, or `whenBad` when it answers false. }
function ParseIntOr(s: TextLine; whenBad: integer): integer;

{ `n` in decimal, no padding. }
function IntToStr(n: integer): TextLine;

{ `x` as the **shortest decimal that reads back as `x`** (ADR-0309): the
  spelling a person expects, rather than the one 6.10.3.4.1's default width
  produces. `0.75` is `0.75` here and `7.500000000000E-01` there, and both
  name the same double.

  Nothing in it converts anything. `writestr` is 6.10's own formatting
  (ADR-0057) and `readstr` is 6.10.4's own reading, so the routine asks the
  processor for `x` at a precision, asks it to read that back, and keeps the
  first spelling that returns the value it started from. What it decides is
  how many digits to ask for and where to put the point -- ECMAScript's
  `Number::toString` rule, a fixed form while the point sits within the
  digits and an exponent outside that.

  **A value with no decimal representation answers what `writestr` wrote for
  it** -- `INF`, `NAN` -- because there is nothing else to answer and because
  a caller embedding one in a document is producing something no reader of
  that format will take back. A caller that must not emit one asks first: an
  infinity is `abs(x) > maxreal` and a NaN is `not (x = x)`, which is
  **not** `x <> x` -- see the note in this module's body. }
function RealToStr(x: real): TextLine;

end;

function TrimStart;
var i: integer; t: TextLine;
begin
  i := 1;
  while (i <= length(s)) and (s[i] = ' ') do
    i := i + 1;
  t := '';
  while i <= length(s) do begin
    t := t + s[i];
    i := i + 1
  end;
  TrimStart := t
end;

function TrimEnd;
var last, i: integer; t: TextLine;
begin
  last := length(s);
  while (last >= 1) and (s[last] = ' ') do
    last := last - 1;
  t := '';
  for i := 1 to last do
    t := t + s[i];
  TrimEnd := t
end;

function TrimAll;
var first, last, i: integer; t: TextLine;
begin
  first := 1;
  while (first <= length(s)) and (s[first] = ' ') do
    first := first + 1;
  last := length(s);
  while (last >= first) and (s[last] = ' ') do
    last := last - 1;
  t := '';
  for i := first to last do
    t := t + s[i];
  TrimAll := t
end;

function CountChar;
var i, n: integer;
begin
  n := 0;
  for i := 1 to length(s) do
    if s[i] = c then n := n + 1;
  CountChar := n
end;

procedure Split;
var i, k: integer; t: TextLine; room: boolean;
begin
  k := 0;
  t := '';
  room := true;
  for i := 1 to length(s) do
    if room then
      if s[i] = sep then begin
        if k < dest.cap then begin
          k := k + 1;
          dest[k] := t;
          t := ''
        end
        else
          room := false
      end
      else
        t := t + s[i];
  { the piece after the last separator, which has no separator to close it }
  if room and (k < dest.cap) then begin
    k := k + 1;
    dest[k] := t
  end;
  count := k
end;

function Join;
var i, j: integer; t: TextLine;
begin
  t := '';
  for i := 1 to count do begin
    if i > 1 then t := t + sep;
    for j := 1 to length(src[i]) do
      t := t + src[i][j]
  end;
  Join := t
end;

function TryParseInt;
var i, acc, digit: integer; neg, ok, any: boolean; b: TextLine;
begin
  b := TrimAll(s);
  i := 1;
  neg := false;
  if (length(b) >= 1) and ((b[1] = '+') or (b[1] = '-')) then begin
    neg := b[1] = '-';
    i := 2
  end;
  acc := 0;
  ok := true;
  any := false;
  while (i <= length(b)) and ok do begin
    if (b[i] >= '0') and (b[i] <= '9') then begin
      digit := ord(b[i]) - ord('0');
      { the guard is *before* the multiply, because forming a value above
        maxint traps rather than wrapping }
      if acc > (maxint - digit) div 10 then
        ok := false
      else begin
        acc := acc * 10 + digit;
        any := true
      end
    end
    else
      ok := false;
    i := i + 1
  end;
  if ok and any then begin
    if neg then v := -acc else v := acc;
    TryParseInt := true
  end
  else
    TryParseInt := false
end;

function ParseIntOr;
var got: integer;
begin
  if TryParseInt(s, got) then ParseIntOr := got
  else ParseIntOr := whenBad
end;

{ The default form with its leading blank stripped -- what `PasJson` wrote for
  every real until ADR-0309, and what is still written for a value the
  shortest-form search cannot answer for. }
procedure PlainReal(x: real; var s: string(64));
var f: string(64); k: integer;
begin
  writestr(f, x);
  k := 1;
  while (k <= length(f)) and (f[k] = ' ') do k := k + 1;
  s := substr(f, k, length(f) - k + 1)
end;

{ The shortest decimal that reads back as `x` (ADR-0309).

  `writestr` is still 6.10's own formatting (ADR-0057) and `readstr` is
  §6.10.4's own reading, so nothing here converts anything: the loop asks the
  processor for `x` at a precision, asks it to read that back, and keeps the
  first spelling that returns the value it started from. What this routine
  decides is only how many digits to ask for and where to put the point.

  **The default form was never wrong.** `7.500000000000E-01` is a JSON number
  by RFC 8259 §6 -- `number = [minus] int [frac] [exp]`, and `exp` admits a
  capital `E`, a sign and leading zeros -- and it is a TOML float by that
  format's own grammar, whose exponent is zero-prefixable for the same reason.
  So this is legibility and not correctness. What it costs a reader is that
  0.75 does not look like 0.75.

  **Where the point goes** is ECMAScript's `Number::toString` algorithm, from
  ECMA-262, JSON being that language's notation: with `n` the
  position of the point relative to the digits, a fixed form when
  `-6 < n <= 21` and an exponent otherwise. It is kept for every caller and
  not only for JSON, because what the rule is *for* is a person reading the
  number, and that reader is the same one whichever format the digits end up
  in. That is what makes 10 print as
  `10` rather than `1E+01` and 1e-7 print as `1E-7` rather than as six zeros
  and a digit.

  **Where the search starts** is what makes it cheap. Asking from one digit
  upwards costs a `writestr` and a `readstr` per digit, and a value needing
  seventeen of them pays seventeen of each -- 27 microseconds a number,
  measured. It starts at fifteen instead, and stripping the trailing zeros off
  the answer is what recovers the short spellings: if a decimal of k <= 15
  digits reads back as `x`, then rounding `x` to fifteen digits *is* that
  decimal with zeros after it, because a normalised double lies within
  2^-53 = 1.1e-16 of it relatively and half a fifteenth-digit step is 5e-16.
  So one probe answers for 0.75, and four is the worst case. Measured at
  1.0 probes a number over a spread of quarters and 2.6 over the reciprocals
  of the first hundred thousand integers: 5.8 microseconds a number.

  That argument needs the relative half-ulp, so it holds for a normalised
  value and not for a denormal, whose ulp is relatively large. A denormal
  therefore starts the search at one digit, where the shortest answer is found
  by looking for it.

  **`readstr` here is safe for the reason this module's heading says it is not
  elsewhere.** §6.9.1's read stops the program when what it is given is not a
  number (ADR-0076), which is why `TryParseInt` twenty lines away inspects the
  characters by hand. What is handed to it here is a string this routine has
  just built out of digits, a point and an exponent -- never a caller's text --
  and the one value that could not be spelled as a number is refused above.
  The two are worth reading together: the rule is not *never `readstr`*, it is
  *never `readstr` on something a caller wrote*. }
procedure ShortestReal(x: real; var s: string(64));
var f, t: string(64); digits: string(40);
    ex, p, k, n, w: integer; neg, done: boolean; y: real;
begin
  s := '';
  { A value with no decimal representation for the clause to describe. No
    format whose numbers this renders has a spelling for one -- JSON has
    neither, TOML has `inf` and `nan` and this is not where they are written --
    so it arrives from a program that computed it, and `readstr` would stop the
    program on what `writestr` wrote for it.

    **`not (x = x)` and not `x <> x`, which is what this asked until it was
    probed.** The two are the same question about every value this language
    has a literal for and not about a NaN: `<>` on reals emits `fcmp one`,
    which is *ordered* not-equal and therefore false when either operand is
    unordered, so `x <> x` is false for a NaN and the guard could not fire.
    `=` emits `fcmp oeq`, which is false for a NaN too, and negating it is
    true. The scan below then ran off the end of what `writestr` wrote for a
    NaN -- `NAN` has no `E` in it -- and stopped the program with an index out
    of bounds inside this library. Whether `<>` ought to be the negation of `=`
    for a value neither standard contemplates is a question about the
    *compiler*, and it is in `doc/sop.md` section 7; this line does not depend
    on the answer. }
  if not (x = x) or (abs(x) > maxreal) then PlainReal(x, s)
  else begin
    done := false;
    if (x <> 0.0) and (abs(x) < 2.2250738585072014E-308) then p := 1
    else p := 15;
    while (p <= 18) and not done do begin
      { §6.10.3.4.1's floating-point form is `ExpDigits + 17` wide by default
        and `TotalWidth - ExpDigits - 5` places after the point, so a width of
        `p + 6` asks for p significant digits where the exponent costs two
        characters and p - 1 where it costs three. The loop runs to 18 so that
        seventeen digits are reachable in the second case; which count arrived
        is read off the string rather than assumed. }
      writestr(f, x:(p + 6));
      neg := f[1] = '-';
      digits := '';
      k := 2;
      while (k <= length(f)) and (f[k] <> 'E') do begin
        if f[k] <> '.' then digits := digits + f[k];
        k := k + 1
      end;
      ex := 0;
      w := 1;
      if f[k + 1] = '-' then w := -1;
      k := k + 2;
      while k <= length(f) do begin
        ex := ex * 10 + (ord(f[k]) - ord('0'));
        k := k + 1
      end;
      ex := ex * w;
      n := length(digits);
      if (ex >= -6) and (ex <= 20) then begin
        if ex >= n - 1 then begin
          t := digits;
          for k := 1 to ex - n + 1 do t := t + '0'
        end
        else if ex >= 0 then
          t := substr(digits, 1, ex + 1) + '.'
               + substr(digits, ex + 2, n - ex - 1)
        else begin
          t := '0.';
          for k := 1 to -ex - 1 do t := t + '0';
          t := t + digits
        end;
        { Only a fraction's zeros: the zeros a large exponent padded the
          integer part with are the value. }
        if index(t, '.') > 0 then begin
          while t[length(t)] = '0' do t := substr(t, 1, length(t) - 1);
          if t[length(t)] = '.' then t := substr(t, 1, length(t) - 1)
        end
      end
      else begin
        while (n > 1) and (digits[n] = '0') do n := n - 1;
        t := substr(digits, 1, 1);
        if n > 1 then t := t + '.' + substr(digits, 2, n - 1);
        t := t + 'E';
        if ex < 0 then begin t := t + '-'; ex := -ex end
        else t := t + '+';
        writestr(f, ex:1);
        t := t + f
      end;
      if neg then t := '-' + t;
      readstr(t, y);
      if y = x then begin
        s := t;
        done := true
      end;
      p := p + 1
    end;
    { Unreachable for a finite value -- seventeen significant digits identify
      every double -- and written out because the alternative to an answer
      here is no answer at all. }
    if not done then PlainReal(x, s)
  end
end;

{ The interface's one name over the two above. The search writes into a
  `string(64)` because that is what the widest spelling of a double needs --
  seventeen digits, a point, a sign, `E`, a sign and three exponent digits is
  twenty-five -- and the caller is handed a `TextLine`, which is this module's
  shape everywhere else. }
function RealToStr;
var s: string(64);
begin
  ShortestReal(x, s);
  RealToStr := s
end;

function IntToStr;
var t: TextLine;
begin
  writestr(t, n:1);
  IntToStr := t
end;

end.
