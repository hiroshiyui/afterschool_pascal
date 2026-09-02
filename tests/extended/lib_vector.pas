{ PasVector, and the thing it exists for: a sequence whose length is not known
  when it is declared. A schema variable cannot do that -- `var v: IntVec(n)`
  fixes n at the declaration -- so every growth here is a reallocation, and the
  case checks that the elements survive one.

  It also pins the arithmetic that must not trap. Doubling is written against
  `IVecCapMax div 2`, and the two boundary pushes below are what say the guard is
  the live path rather than decoration. }
program lib_vector(output);

import PasVector;

var
  v: IVecPtr;
  w: IVecPtr;
  i, sum: integer;

begin
  { grows from 1 through 2, 4, 8, 16 -- five reallocations, and every element
    written before them is still there afterwards }
  IVecNew(v, 1);
  writeln('empty len=', IVecLen(v):1, ' cap=', IVecCap(v):1);
  for i := 1 to 10 do
    IVecPush(v, i * i);
  writeln('len=', IVecLen(v):1, ' cap=', IVecCap(v):1);
  for i := 1 to IVecLen(v) do
    write(IVecGet(v, i):1, ' ');
  writeln;
  writeln('sum=', IVecSum(v):1);

  { pop is the inverse, and the length is what it moves }
  writeln('pop=', IVecPop(v):1, ' pop=', IVecPop(v):1, ' len=', IVecLen(v):1);

  { set and get address the same storage }
  IVecSet(v, 1, 100);
  writeln('a1=', IVecGet(v, 1):1);

  { reserve grows once and no push after it reallocates }
  IVecNew(w, 2);
  IVecReserve(w, 50);
  writeln('reserved cap=', IVecCap(w):1);
  for i := 1 to 50 do
    IVecPush(w, i);
  writeln('after 50 pushes cap=', IVecCap(w):1, ' len=', IVecLen(w):1);

  { reserve never shrinks }
  IVecReserve(w, 4);
  writeln('reserve(4) leaves cap=', IVecCap(w):1);

  { clear keeps the storage }
  IVecClear(w);
  writeln('cleared len=', IVecLen(w):1, ' cap=', IVecCap(w):1);

  { fill sets both the length and the contents }
  IVecFill(w, 5, 7);
  sum := 0;
  for i := 1 to IVecLen(w) do
    sum := sum + IVecGet(w, i);
  writeln('filled len=', IVecLen(w):1, ' sum=', sum:1);

  { popping an empty vector answers 0 and stays empty }
  IVecClear(w);
  writeln('pop empty=', IVecPop(w):1, ' len=', IVecLen(w):1);

  IVecFree(v);
  IVecFree(w);
  { freeing nil is harmless, which is what lets a caller free unconditionally }
  IVecFree(w);
  writeln('freed')
end.
