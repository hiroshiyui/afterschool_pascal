program NewVariants(output);
{ ISO 7185 6.6.5.3: `new(p, c1, ..., cn)` creates a variable with the variants
  those tag values select -- one value per nested variant part, outermost
  first -- and `dispose(p, c1, ..., cn)` gives it back. This compiler used to
  reject the form (ADR-0019 recorded the gap); ADR-0027 closes it.

  What the *smaller* allocation saves is not observable from a conforming
  program, so what this checks is that it is **sufficient**. That is harder to
  test than it looks: malloc rounds its chunks up, so a record short by a few
  bytes still fits and nothing goes wrong. The sizes below are therefore
  deliberately coarse -- two hundred bytes of fixed part, four hundred in the
  selected arm, four thousand in the one not selected -- so that getting the
  offset or the arm wrong is short by hundreds of bytes rather than by eight,
  and a hundred live records make the overrun land on a neighbour. }

type
  kind = (leaf, branch);
  weight = (light, heavy);

  node = record
    { a fixed part with some size to it, so an allocation that forgets to
      count it is visibly short }
    header: array [1..50] of integer;
    id: integer;
    case k: kind of
      leaf: (value: real);
      branch: (count: integer;
               case w: weight of
                 light: (few: array [1..100] of integer);
                 heavy: (many: array [1..1000] of integer))
  end;
  link = ^node;

var
  p, q: link;
  kept: array [1..100] of link;
  i, j, wrong: integer;

begin
  { the outer level only }
  new(p, leaf);
  p^.id := 1;
  p^.k := leaf;
  p^.value := 2.5;
  writeln('leaf: ', p^.id:1, ' ', p^.value:3:1);

  { both levels, choosing the narrow arm at the second }
  new(q, branch, light);
  q^.id := 2;
  q^.k := branch;
  q^.count := 3;
  q^.w := light;
  q^.few[100] := 4;
  writeln('light: ', q^.id:1, ' ', q^.count:1, ' ', q^.few[100]:1);
  dispose(q, branch, light);
  dispose(p, leaf);

  { and the one-argument form still allocates the whole record }
  new(p);
  p^.id := 5;
  p^.k := branch;
  p^.count := 6;
  p^.w := heavy;
  p^.many[1000] := 7;
  writeln('whole: ', p^.id:1, ' ', p^.count:1, ' ', p^.many[1000]:1);
  dispose(p);

  { a hundred live records, each allocated for the narrow arm and filled to
    its last byte, then all read back }
  for i := 1 to 100 do begin
    new(kept[i], branch, light);
    kept[i]^.id := i;
    kept[i]^.k := branch;
    kept[i]^.count := i * 2;
    kept[i]^.w := light;
    for j := 1 to 50 do
      kept[i]^.header[j] := i * 1000 + j;
    for j := 1 to 100 do
      kept[i]^.few[j] := i * 10000 + j
  end;
  wrong := 0;
  for i := 1 to 100 do begin
    if kept[i]^.id <> i then wrong := wrong + 1;
    if kept[i]^.count <> i * 2 then wrong := wrong + 1;
    for j := 1 to 50 do
      if kept[i]^.header[j] <> i * 1000 + j then wrong := wrong + 1;
    for j := 1 to 100 do
      if kept[i]^.few[j] <> i * 10000 + j then wrong := wrong + 1
  end;
  writeln('hundred selected allocations, wrong fields: ', wrong:1);
  for i := 1 to 100 do
    dispose(kept[i], branch, light)
end.
