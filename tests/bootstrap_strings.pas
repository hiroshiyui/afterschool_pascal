program BootstrapStrings(input, output);

{ The strings the stage-1 compiler will be written with, exercised the way it
  will use them: read identifiers from a text file, recognise keywords, intern
  them in a symbol table, and emit text with the names interpolated.

  ISO 7185 has no string type — only string literals and
  `packed array [1..n] of char`, where the length is part of the type. This is
  the length-plus-buffer record that ADR-0012 calls option A, and this program
  is the evidence for that decision rather than an illustration of it: if the
  discipline did not work, it would fail to compile. }

const
  strMax = 32;   { the longest name the compiler keeps }
  litMax = 12;   { the width every keyword literal is written to }
  maxSym = 16;

type
  strLen = 0..strMax;
  str = record
    len: strLen;
    ch: packed array [1..strMax] of char
  end;
  { One fixed width for every keyword literal. This is the whole cost of
    option A: a literal cannot be handed to a procedure unless its type
    matches, so keywords are padded to a common width in the source. }
  lit = packed array [1..litMax] of char;
  symIndex = 0..maxSym;

var
  symName: array [1..maxSym] of str;
  symCount: symIndex;
  word: str;
  i, words, keywords: integer;
  c: char;

procedure StrClear(var s: str);
begin
  s.len := 0
end;

procedure StrAppend(var s: str; c: char);
begin
  if s.len < strMax then begin
    s.len := s.len + 1;
    s.ch[s.len] := c
  end
end;

procedure StrWrite(var f: text; var s: str);
var k: integer;
begin
  for k := 1 to s.len do
    write(f, s.ch[k])
end;

function StrSame(var a, b: str): boolean;
var k: integer; ok: boolean;
begin
  ok := a.len = b.len;
  k := 1;
  while ok and (k <= a.len) do begin
    ok := a.ch[k] = b.ch[k];
    k := k + 1
  end;
  StrSame := ok
end;

{ Comparing against a padded literal. The trailing blanks are where the
  keyword ends — note that `and` short-circuits (ADR-0010), which is what
  keeps l[n] from being read at n = 0. }
function StrSameAsLit(var s: str; l: lit): boolean;
var n, k: integer; ok: boolean;
begin
  n := litMax;
  while (n > 0) and (l[n] = ' ') do
    n := n - 1;
  ok := n = s.len;
  k := 1;
  while ok and (k <= n) do begin
    ok := l[k] = s.ch[k];
    k := k + 1
  end;
  StrSameAsLit := ok
end;

function IsKeyword(var s: str): boolean;
begin
  IsKeyword := StrSameAsLit(s, 'begin       ') or
               StrSameAsLit(s, 'end         ') or
               StrSameAsLit(s, 'procedure   ') or
               StrSameAsLit(s, 'var         ')
end;

{ The symbol table: find a name or add it. This is the operation a compiler
  does most, and it needs only comparison. }
function Intern(var s: str): symIndex;
var k: symIndex; found: symIndex;
begin
  found := 0;
  for k := 1 to symCount do
    if (found = 0) and StrSame(symName[k], s) then
      found := k;
  if (found = 0) and (symCount < maxSym) then begin
    symCount := symCount + 1;
    symName[symCount] := s;   { a record assignment copies every component }
    found := symCount
  end;
  Intern := found
end;

{ Emitting IR needs no string type at all: the pieces are written straight
  out. This is why the compiler's own text handling is lighter than its
  string-heavy reputation suggests. }
procedure EmitGlobal(var f: text; var name: str; slot: integer);
begin
  write(f, '@');
  StrWrite(f, name);
  write(f, ' = global i32 ', slot:1, ', align 4');
  writeln(f)
end;

begin
  symCount := 0;
  words := 0;
  keywords := 0;

  { The lexer's inner loop: accumulate a word one character at a time. The
    characters arrive from the buffer variable, so nothing here needs a string
    to exist before it is built. }
  while not eof do begin
    while not eoln do begin
      if input^ = ' ' then
        get(input)
      else begin
        StrClear(word);
        while (not eoln) and (input^ <> ' ') do begin
          StrAppend(word, input^);
          get(input)
        end;
        words := words + 1;
        if IsKeyword(word) then
          keywords := keywords + 1
        else
          i := Intern(word)
      end
    end;
    readln
  end;

  writeln('words ', words:1, ' keywords ', keywords:1,
          ' distinct identifiers ', symCount:1);

  for i := 1 to symCount do
    EmitGlobal(output, symName[i], i - 1)
end.
