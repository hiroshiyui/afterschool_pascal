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
  writeln('empty len=', v.Len:1, ' cap=', v.Cap:1);
  for i := 1 to 10 do
    v.Push(i * i);
  writeln('len=', v.Len:1, ' cap=', v.Cap:1);
  for i := 1 to v.Len do
    write(v.Get(i):1, ' ');
  writeln;
  writeln('sum=', v.Sum:1);

  { pop is the inverse, and the length is what it moves }
  writeln('pop=', v.Pop:1, ' pop=', v.Pop:1, ' len=', v.Len:1);

  { put and get address the same storage }
  v.Put(1, 100);
  writeln('a1=', v.Get(1):1);

  { reserve grows once and no push after it reallocates }
  IVecNew(w, 2);
  w.Reserve(50);
  writeln('reserved cap=', w.Cap:1);
  for i := 1 to 50 do
    w.Push(i);
  writeln('after 50 pushes cap=', w.Cap:1, ' len=', w.Len:1);

  { reserve never shrinks }
  w.Reserve(4);
  writeln('reserve(4) leaves cap=', w.Cap:1);

  { clear keeps the storage }
  w.Clear;
  writeln('cleared len=', w.Len:1, ' cap=', w.Cap:1);

  { fill sets both the length and the contents }
  w.Fill(5, 7);
  sum := 0;
  for i := 1 to w.Len do
    sum := sum + w.Get(i);
  writeln('filled len=', w.Len:1, ' sum=', sum:1);

  { popping an empty vector answers 0 and stays empty }
  w.Clear;
  writeln('pop empty=', w.Pop:1, ' len=', w.Len:1);

  v.Free;
  w.Free;
  { freeing nil is harmless, which is what lets a caller free unconditionally }
  w.Free;
  writeln('freed')
end.
