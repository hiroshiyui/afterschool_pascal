{ Word frequencies of standard input, with a generic map and a vector.

  `Map(K, V)` in PasContainer is one module written once over whatever
  key and value types the program names -- a schema with a type parameter
  (ADR-0209). A container is a pointer and grows by reallocating, so every
  routine that may grow takes it as `var`. The map asks for a hash and an
  equality of its key as procedural parameters; `StrHash`/`StrEq` are the
  module's own pair for strings. Where the arguments already say what the
  types are they are left out of the call (ADR-0254); `MapGet` names its
  result type because nothing else does. PasStrVec keeps the distinct words
  so they can be sorted -- the map's own order is the table's. Run it as

      pascalcc word_freq.pas -o freq && ./freq < some.txt }
program word_freq(input, output);

import PasContainer; PasStrVec;

type
  CountMap = ^Map(MapKey, integer);

var
  counts: CountMap;
  words: StrVecPtr;
  line, word: string(4096);
  k, start: integer;

procedure Count(w: MapKey);
var n: integer;
begin
  n := MapGet(CountMap, integer, counts, w, 0, StrHash, StrEq);
  if n = 0 then SVecPush(words, w);       { first sighting }
  MapPut(counts, w, n + 1, StrHash, StrEq)
end;

begin
  MapInit(CountMap, counts, 64);
  SVecNew(words, 64);
  while not eof do begin
    readln(line);
    start := 0;
    for k := 1 to length(line) + 1 do
      if (k > length(line)) or (line[k] = ' ') then begin
        if start > 0 then begin
          word := line[start..k - 1];
          { a MapKey holds KeyMax characters, and a longer assignment
            would stop the program -- so an over-long word is skipped }
          if length(word) <= KeyMax then Count(word)
        end;
        start := 0
      end
      else if start = 0 then
        start := k
  end;
  SVecSort(words);
  for k := 1 to SVecLen(words) do
    writeln(MapGet(CountMap, integer, counts, SVecGet(words, k), 0,
                   StrHash, StrEq):4, ' ', SVecGet(words, k));
  writeln(MapCount(CountMap, counts):1, ' distinct words');
  SVecFree(words);
  MapFree(CountMap, counts)
end.
