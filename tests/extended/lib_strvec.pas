{ PasStrVec, and what it is for: the lines of a file. ForEachLine hands each
  line to a procedure, and §6.7.3.4 lets that procedure be a *nested* one --
  which sees the vector it pushes onto in its enclosing block. That is the
  whole of how a file becomes a sequence here, with no container in PasFile
  and no closure in the language.

  The sort is checked for order on a size that crosses the merge/insert
  boundary in the module, and on the two sizes -- zero and one -- that must
  do nothing. Stability is a property of the merge and not observable from
  outside: two strings that compare equal under `<` are indistinguishable to
  every other routine here, so there is nothing for a golden to hold. The file names come from `fresh`, as lib_file's do. }
program lib_strvec(output, fresh);

import PasStrVec;
       PasFile;

var
  fresh: bindable text;
  p: FilePath;
  v, w: StrVecPtr;
  i, n: integer;
  joined: string(40);
  buf: FileLine;   { ForEachLine's buffer, and so the bound on a line }
  ok: boolean;

{ nested, so it can reach `v` }
procedure keep(line: string);
begin SVecPush(v, line) end;

procedure dump(what: string(8); u: StrVecPtr);
var k: integer;
begin
  write(what, ' (', SVecLen(u):1, '/', SVecCap(u):1, '):');
  for k := 1 to SVecLen(u) do write(' [', SVecGet(u, k), ']');
  writeln
end;

begin
  { --- growth from a small capacity, and the accessors --- }
  SVecNew(v, 1);
  for i := 1 to 5 do SVecPush(v, 'item' + chr(ord('0') + i));
  dump('pushed', v);
  writeln('pop: ', SVecPop(v), ' then ', SVecLen(v):1, ' left');
  SVecSet(v, 2, 'changed');
  writeln('get 2: ', SVecGet(v, 2), ' indexof changed: ', SVecIndexOf(v, 'changed'):1,
          ' indexof none: ', SVecIndexOf(v, 'none'):1);
  { §6.7.2.5: the shorter operand is padded, so a trailing space is equal }
  writeln('padded equal: ', SVecIndexOf(v, 'item1 '):1);
  SVecReserve(v, 100);
  writeln('reserved: ', SVecCap(v):1, ' len ', SVecLen(v):1);
  SVecClear(v);
  writeln('cleared: ', SVecLen(v):1, ' pop of empty: [', SVecPop(v), ']');

  { --- split and join are inverses, and join reports the whole length --- }
  SVecSplit(v, 'a,b,,d', ',');
  dump('split', v);
  n := SVecJoin(v, ',', joined);
  writeln('joined: [', joined, '] ', n:1);
  SVecClear(v);
  SVecSplit(v, '', ',');
  writeln('split of empty: ', SVecLen(v):1, ' [', SVecGet(v, 1), ']');
  SVecClear(v);
  for i := 1 to 10 do SVecPush(v, 'abcdefgh');
  n := SVecJoin(v, '-', joined);
  writeln('truncated join: length ', length(joined):1, ' of ', n:1,
          ' fits=', n <= joined.capacity);

  { --- sort: order, stability, and a size past the insertion cutoff --- }
  SVecClear(v);
  for i := 1 to 20 do
    SVecPush(v, 'k' + chr(ord('a') + (i * 7) mod 5) + ' #' + chr(ord('0') + i mod 10));
  SVecSort(v);
  dump('sorted', v);
  ok := true;
  for i := 2 to SVecLen(v) do
    if SVecGet(v, i) < SVecGet(v, i - 1) then ok := false;
  writeln('ascending: ', ok);
  SVecNew(w, 4);
  SVecSort(w);
  SVecPush(w, 'only');
  SVecSort(w);
  dump('tiny', w);
  SVecFree(w);
  writeln('freed: ', w = nil);

  { --- a file's lines, through a nested procedure --- }
  p := binding(fresh).name + '.lib_strvec';
  { A writer answers now (AP 6.4.3.4, ADR-0240) and a function call is not a
    statement, so what was a bare call is a reported one. }
  writeln('wrote: ',
          WriteAllText(p, 'pear' + chr(10) + 'apple' + chr(10) + 'fig'
                       + chr(10)));
  SVecClear(v);
  ok := ForEachLine(p, buf, keep);
  dump('read', v);
  SVecSort(v);
  n := SVecJoin(v, ' < ', joined);
  writeln('sorted lines: ', joined);
  SVecFree(v)
end.
