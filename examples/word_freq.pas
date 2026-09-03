{ Word frequencies of standard input, with a generic map and a generic vector.

  `Map(K, V)` in PasContainer is one module written once over whatever key and
  value types the program names -- a schema with a type parameter (ADR-0209).
  A container is a pointer and grows by reallocating, so every routine that
  may grow takes it as `var`. The map asks for a hash and an equality of its
  key as procedural parameters; `StrHash`/`StrEq` are the module's own pair
  for strings, and they are schematic, so they serve a key of any capacity
  (ADR-0290). Where the arguments already say what the types are they are left
  out of the call (ADR-0254, ADR-0304), and here that is every one of them.

  **The key type is this program's own, and it is the line buffer's**
  (ADR-0310). A word is a piece of a line, so a word cannot be longer than
  `LineMax`, and a key that cannot be too long needs no guard before it is
  put. That costs `LineMax` bytes a slot, which is the trade being made here
  and is worth stating: the alternative is a smaller key and a test before
  every `MapPut`, which drops a long word without saying so. The map has no
  key bound of its own -- `PasContainer.MapKey` is a ready-made key type for a
  program that wants one, not a limit.

  `PasSort.SortIndexed` puts the distinct words in order without ever seeing
  one: it is handed `less` and `swap` over the positions, and those two reach
  the vector. The map's own order is the table's.

  Run it as

      pascalcc word_freq.pas -o freq && ./freq < some.txt }
program word_freq(input, output);

import PasContainer; PasSort;

const
  LineMax = 1024;      { the whole of what this program bounds }

type
  WordText = string(LineMax);
  CountMap = ^Map(WordText, integer);
  WordVec = ^Vec(WordText);

var
  counts: CountMap;
  words: WordVec;
  line, word: WordText;
  k, start: integer;

procedure Count(w: WordText);
var n: integer;
begin
  n := MapGet(counts, w, 0, StrHash, StrEq);
  if n = 0 then VecPush(words, w);        { first sighting }
  MapPut(counts, w, n + 1, StrHash, StrEq)
end;

function Earlier(i, j: integer): boolean;
begin
  Earlier := VecGet(WordText, words, i) < VecGet(WordText, words, j)
end;

procedure Exchange(i, j: integer);
var t: WordText;
begin
  t := VecGet(WordText, words, i);
  VecSet(words, i, VecGet(WordText, words, j));
  VecSet(words, j, t)
end;

begin
  MapInit(counts, 64);
  VecInit(words, 64);
  while not eof do begin
    readln(line);
    start := 0;
    for k := 1 to length(line) + 1 do
      if (k > length(line)) or (line[k] = ' ') then begin
        if start > 0 then Count(line[start..k - 1]);
        start := 0
      end
      else if start = 0 then
        start := k
  end;
  SortIndexed(VecLen(words), Earlier, Exchange);
  for k := 1 to VecLen(words) do begin
    word := VecGet(WordText, words, k);
    writeln(MapGet(counts, word, 0, StrHash, StrEq):4, ' ', word)
  end;
  writeln(MapCount(counts):1, ' distinct words');
  VecFree(words);
  MapFree(counts)
end.
