{ PasStrings -- the string operations neither standard provides.

  ISO/IEC 10206:1991 6.7.6 gives `length`, `index`, `substr`, `trim` and the
  `EQ`/`LT` family, and 6.8.3.5 gives the padding comparisons. What it does not
  give is case conversion, a prefix test, padding to a width, or replacement --
  the operations a program that reads a line and decides something about it
  needs on its first page.

  Three conventions govern every function here, and each is forced rather than
  chosen. ADR-0114 writes them out with the probes that found them; the short
  form:

  - **A read-only string parameter is `protected s: string`** -- the bare
    schema-name, which is a schematic formal and therefore travels as an
    address and a capacity (ADR-0040). It is not a value parameter because a
    variable-string may not be one (ADR-0052), and it is not grouped with a
    second string because a parameter group naming a schema gives its names one
    type, which would force two arguments to the same capacity.

  - **An argument must be a string *variable*.** Neither a literal nor another
    function's result is a variable produced from the schema, so `StartsWith(v,
    'hello')` and `Upper(Reverse(v))` are both unwritable today and the caller
    assigns to a named variable first. This is ADR-0052's deviation seen from
    the outside and is the largest thing standing between this library and a
    comfortable one.

  - **A function accumulates into a local and assigns its identifier once.**
    6.8.2.2 makes every *read* of the identifier a recursive call, so
    `Upper := Upper + c` is a recursion rather than an append; the other way to
    accumulate is a result-variable-specification, and 6.11.1 makes a heading
    in a module-heading a `forward`, whose body cannot see that name.

  A result is `Line`, a fixed-capacity string the interface exports so a caller
  has something to declare. Every function whose result can grow -- `PadLeft`,
  `PadRight`, `Times`, `Replace` -- can therefore be asked for more than
  `LineMax` characters, and 6.4.6 makes that an error at the store rather than
  a truncation. The width and count parameters are the caller's to bound. }

module PasStrings;

export PasStrings = (
  LineMax, Line,
  Upper, Lower,
  StartsWith, EndsWith, IndexOf,
  PadLeft, PadRight, Times, Reverse, Replace);

const
  LineMax = 255;

type
  Line = string(LineMax);

function Upper(protected s: string): Line;
function Lower(protected s: string): Line;

function StartsWith(protected s: string; protected prefix: string): boolean;
function EndsWith(protected s: string; protected suffix: string): boolean;

{ The position of the first occurrence of `needle` in `s`, or 0 when there is
  none. A null needle occurs at 1, which is what makes `IndexOf(s, n) > 0` and
  "n is a substring of s" the same question for every n. }
function IndexOf(protected s: string; protected needle: string): integer;

{ `s` padded with spaces to `w` characters, on the left and on the right. A
  string already that long or longer is returned unchanged -- these pad and do
  not truncate, so nothing here can lose a character. }
function PadLeft(protected s: string; w: integer): Line;
function PadRight(protected s: string; w: integer): Line;

{ `s` repeated `n` times; the null string for n <= 0. }
function Times(protected s: string; n: integer): Line;

function Reverse(protected s: string): Line;

{ Every occurrence of `needle` in `s` replaced by `repl`, scanning left to
  right and never rescanning what a replacement produced. A null needle
  matches nothing here, which is the one place this disagrees with `IndexOf`
  above: the alternative is an insertion between every pair of characters, and
  no caller wants it. }
function Replace(protected s: string;
                 protected needle: string;
                 protected repl: string): Line;

end;

{ 6.1.3 case-folds identifiers, so `chr(ord(c) - ord('a') + ord('A'))` is the
  whole of the conversion and no table is needed. `char` is a byte and nothing
  consults the locale (a documented decision), so this converts ASCII and
  passes every other byte through -- which is the honest behaviour to expose
  until the text model of ADR-0109 is settled. }

function Upper;
var t: Line; i: integer;
begin
  t := '';
  for i := 1 to length(s) do
    if (s[i] >= 'a') and (s[i] <= 'z') then
      t := t + chr(ord(s[i]) - ord('a') + ord('A'))
    else
      t := t + s[i];
  Upper := t
end;

function Lower;
var t: Line; i: integer;
begin
  t := '';
  for i := 1 to length(s) do
    if (s[i] >= 'A') and (s[i] <= 'Z') then
      t := t + chr(ord(s[i]) - ord('A') + ord('a'))
    else
      t := t + s[i];
  Lower := t
end;

function StartsWith;
var i: integer; ok: boolean;
begin
  { A prefix longer than the string cannot be one, and the loop below would
    index past the end asking. }
  ok := length(prefix) <= length(s);
  if ok then
    for i := 1 to length(prefix) do
      if s[i] <> prefix[i] then ok := false;
  StartsWith := ok
end;

function EndsWith;
var i, d: integer; ok: boolean;
begin
  ok := length(suffix) <= length(s);
  if ok then begin
    { The offset that aligns the suffix with the tail of s. }
    d := length(s) - length(suffix);
    for i := 1 to length(suffix) do
      if s[d + i] <> suffix[i] then ok := false
  end;
  EndsWith := ok
end;

function IndexOf;
var i, j, last: integer; found: boolean;
begin
  found := length(needle) = 0;
  IndexOf := 0;
  if found then
    IndexOf := 1
  else begin
    { The last position at which the needle can still fit. Computed rather than
      tested inside the loop, so a needle longer than s makes this smaller than
      1 and the loop does not run at all. }
    last := length(s) - length(needle) + 1;
    i := 1;
    while (i <= last) and then not found do begin
      found := true;
      for j := 1 to length(needle) do
        if s[i + j - 1] <> needle[j] then found := false;
      if found then IndexOf := i;
      i := i + 1
    end
  end
end;

function PadLeft;
var t: Line; i: integer;
begin
  t := '';
  for i := length(s) + 1 to w do t := t + ' ';
  PadLeft := t + s
end;

function PadRight;
var t: Line; i: integer;
begin
  t := s;
  for i := length(s) + 1 to w do t := t + ' ';
  PadRight := t
end;

function Times;
var t: Line; i: integer;
begin
  t := '';
  for i := 1 to n do t := t + s;
  Times := t
end;

function Reverse;
var t: Line; i: integer;
begin
  t := '';
  for i := length(s) downto 1 do t := t + s[i];
  Reverse := t
end;

function Replace;
var t: Line; i, j, last: integer; hit: boolean;
begin
  t := '';
  if length(needle) = 0 then
    t := s
  else begin
    last := length(s) - length(needle) + 1;
    i := 1;
    while i <= length(s) do begin
      hit := i <= last;
      if hit then
        for j := 1 to length(needle) do
          if s[i + j - 1] <> needle[j] then hit := false;
      if hit then begin
        t := t + repl;
        { Past the match, so a replacement is never rescanned. }
        i := i + length(needle)
      end
      else begin
        t := t + s[i];
        i := i + 1
      end
    end
  end;
  Replace := t
end;

end.
