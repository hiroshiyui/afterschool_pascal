{ Word frequencies of standard input, with a generic map and a generic vector.

  `Map(K, V)` in PasContainer is one module written once over whatever key and
  value types the program names -- a schema with a type parameter (ADR-0209).
  A container is a pointer and grows by reallocating, so every routine that
  may grow takes it as `var`. The map's key type must implement `Key` -- a
  hash and an equality -- and this program says how its own does, once, in
  the `impl` below (ADR-0355); `StrHash`/`StrEq` are the module's own pair for
  strings, schematic so they serve a key of any capacity (ADR-0290), and the
  implementation is two lines calling them. Where the arguments already say
  what the types are they are left out of the call (ADR-0254, ADR-0304), and
  here that is every one of them.

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

{ What the map needs of a key, said once for this program's key type. It
  stands before the map type below because AP 6.4.7.2 checks the bound where
  the type is produced. }
impl Key for WordText;
  function Hash;
  begin Hash := StrHash(k) end;
  function Same;
  begin Same := StrEq(a, b) end;
end;

type
  { `owned` (AP 6.4.14), so the program block owns both and neither is freed
    by hand: leaving the block releases them, and there is no spelling for a
    second name to dangle from. The word costs nothing here and the two calls
    it replaced are gone from the foot of this program.

    It reads as an ordinary generic instantiation because it is one --
    `PasContainer` is written once for both, its reallocation being
    `v := take(fresh)`, which is the move at an owned type argument and the
    assignment at any other (ADR-0323). }
  CountMap = owned ^Map(WordText, integer);
  WordVec = owned ^Vec(WordText);

var
  counts: CountMap;
  words: WordVec;
  line, word: WordText;
  k, start: integer;

procedure Count(w: WordText);
var n: integer;
begin
  n := MapGet(counts, w, 0);
  if n = 0 then VecPush(words, w);        { first sighting }
  MapPut(counts, w, n + 1)
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
    writeln(MapGet(counts, word, 0):4, ' ', word)
  end;
  writeln(MapCount(counts):1, ' distinct words')
end.
