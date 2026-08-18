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
  forming the value, because forming it would trap (ADR-0014). }

module PasText;

export PasText = (TextMax, TextLine, Parts,
                  TrimStart, TrimEnd, TrimAll,
                  Split, Join, CountChar,
                  TryParseInt, ParseIntOr, IntToStr);

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

function IntToStr;
var t: TextLine;
begin
  writestr(t, n:1);
  IntToStr := t
end;

end.
