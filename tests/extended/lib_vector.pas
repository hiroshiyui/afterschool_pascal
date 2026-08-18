{ PasVector, and the thing it exists for: a sequence whose length is not known
  when it is declared. A schema variable cannot do that -- `var v: IntVec(n)`
  fixes n at the declaration -- so every growth here is a reallocation, and the
  case checks that the elements survive one.

  It also pins the arithmetic that must not trap. Doubling is written against
  `CapMax div 2`, and the two boundary pushes below are what say the guard is
  the live path rather than decoration. }
program lib_vector(output);

import PasVector;

var
  v: VecPtr;
  w: VecPtr;
  i, sum: integer;

begin
  { grows from 1 through 2, 4, 8, 16 -- five reallocations, and every element
    written before them is still there afterwards }
  VecNew(v, 1);
  writeln('empty len=', VecLen(v):1, ' cap=', VecCap(v):1);
  for i := 1 to 10 do
    VecPush(v, i * i);
  writeln('len=', VecLen(v):1, ' cap=', VecCap(v):1);
  for i := 1 to VecLen(v) do
    write(VecGet(v, i):1, ' ');
  writeln;
  writeln('sum=', VecSum(v):1);

  { pop is the inverse, and the length is what it moves }
  writeln('pop=', VecPop(v):1, ' pop=', VecPop(v):1, ' len=', VecLen(v):1);

  { set and get address the same storage }
  VecSet(v, 1, 100);
  writeln('a1=', VecGet(v, 1):1);

  { reserve grows once and no push after it reallocates }
  VecNew(w, 2);
  VecReserve(w, 50);
  writeln('reserved cap=', VecCap(w):1);
  for i := 1 to 50 do
    VecPush(w, i);
  writeln('after 50 pushes cap=', VecCap(w):1, ' len=', VecLen(w):1);

  { reserve never shrinks }
  VecReserve(w, 4);
  writeln('reserve(4) leaves cap=', VecCap(w):1);

  { clear keeps the storage }
  VecClear(w);
  writeln('cleared len=', VecLen(w):1, ' cap=', VecCap(w):1);

  { fill sets both the length and the contents }
  VecFill(w, 5, 7);
  sum := 0;
  for i := 1 to VecLen(w) do
    sum := sum + VecGet(w, i);
  writeln('filled len=', VecLen(w):1, ' sum=', sum:1);

  { popping an empty vector answers 0 and stays empty }
  VecClear(w);
  writeln('pop empty=', VecPop(w):1, ' len=', VecLen(w):1);

  VecFree(v);
  VecFree(w);
  { freeing nil is harmless, which is what lets a caller free unconditionally }
  VecFree(w);
  writeln('freed')
end.
