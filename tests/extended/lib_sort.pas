{ PasSort, including the part that is the whole point: SortIndexed never sees an
  element. The parallel-array case below sorts two arrays at once by the first
  one's order, which no interface taking an array could have done -- and it is
  the reason a sort is expressible here at all, schemata parameterising a type by
  a value rather than by another type. }
program lib_sort(output);

import PasSort;

const N = 9;

type Nine = IntVector(N);

var
  v: Nine;
  key: Nine;
  tag: Nine;
  i: integer;
  target: integer;

function Ascending(x, y: integer): boolean;
begin
  Ascending := x < y
end;

function Descending(x, y: integer): boolean;
begin
  Descending := x > y
end;

{ The two closures SortIndexed needs to sort `key` and `tag` together: `less`
  reads only `key`, and `swap` exchanges the same position in both. }
function KeyLess(i, j: integer): boolean;
begin
  KeyLess := key[i] < key[j]
end;

procedure PairSwap(i, j: integer);
var t: integer;
begin
  t := key[i]; key[i] := key[j]; key[j] := t;
  t := tag[i]; tag[i] := tag[j]; tag[j] := t
end;

{ For LowerBound: the first position whose element is >= target. Closes over
  both, so the predicate is a question about the array and not about an
  element passed to it. }
function AtLeastTarget(i: integer): boolean;
begin
  AtLeastTarget := v[i] >= target
end;

procedure Show(protected a: IntVector; n: integer);
var i: integer;
begin
  for i := 1 to n do write(a[i]:3);
  writeln
end;

begin
  { Duplicates, an already-largest first element and an already-smallest last
    one, so a sort that merely reversed would not agree here. }
  v[1] := 5; v[2] := 3; v[3] := 9; v[4] := 1; v[5] := 9;
  v[6] := 2; v[7] := 8; v[8] := 3; v[9] := 7;

  writeln('unsorted:');
  Show(v, N);

  SortInts(v, Ascending);
  writeln('ascending:');
  Show(v, N);

  { Already sorted: heapsort must leave it alone rather than disturb it. }
  SortInts(v, Ascending);
  writeln('again:');
  Show(v, N);

  SortInts(v, Descending);
  writeln('descending:');
  Show(v, N);

  { n = 0 and n = 1 through the generic entry, where both heap loops must fail
    their bounds and neither closure may be called -- `key` and `tag` have not
    been assigned yet, so a sort that read one here would read an undefined
    value and a sort that wrote one would be caught by the assignments below. }
  SortIndexed(0, KeyLess, PairSwap);
  SortIndexed(1, KeyLess, PairSwap);
  writeln('n=0 and n=1 called nothing:');

  { Two arrays sorted as one. `tag` records where each key started, so the line
    printed after the sort says whether the payload followed its key. }
  key[1] := 40; key[2] := 10; key[3] := 30; key[4] := 50; key[5] := 20;
  key[6] := 70; key[7] := 60; key[8] := 90; key[9] := 80;
  for i := 1 to N do tag[i] := i;

  SortIndexed(N, KeyLess, PairSwap);
  writeln('keys:');
  Show(key, N);
  writeln('tags followed their keys:');
  Show(tag, N);

  { LowerBound over the ascending array: a value present, one absent between two
    others, one below everything and one above everything. }
  SortInts(v, Ascending);
  writeln('ascending again:');
  Show(v, N);

  target := 1;  writeln('lower bound of 1  is ', LowerBound(N, AtLeastTarget):1);
  target := 3;  writeln('lower bound of 3  is ', LowerBound(N, AtLeastTarget):1);
  target := 4;  writeln('lower bound of 4  is ', LowerBound(N, AtLeastTarget):1);
  target := 0;  writeln('lower bound of 0  is ', LowerBound(N, AtLeastTarget):1);
  target := 99; writeln('lower bound of 99 is ', LowerBound(N, AtLeastTarget):1);

  { An empty range: the answer is one past the end, which is where a value
    would be inserted. }
  writeln('lower bound over n=0 is ', LowerBound(0, AtLeastTarget):1)
end.
