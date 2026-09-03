{ PasContainer's ceiling, which used to be a trap (ADR-0276).

  `Claimed` clamps a request at `CapMax` -- the library's stated policy where
  that constant is declared is to clamp rather than halt, "because a library
  that halts is a library that cannot be tested" -- and `VecPush` then wrote
  the element anyway. `v^.a[v^.n]` indexed one past the array, and the program
  stopped with

      runtime error: array index out of bounds (1..1000000)

  It cost the language server every document of a million bytes or more, which
  `selfhost/apfront.pas` became the day it passed 992 000. `PasStrVec`, the
  other growable vector here and written for the same job, has had the guard
  since it was written; only this one lacked it.

  Four things are checked and each of them was wrong. That filling past the
  ceiling does not stop the program. That what fits is kept and readable, so
  the loss is a *tail* and not a corruption. That `VecFull` says so, since a
  clamp nothing can ask about is a silent one. And that a push at the ceiling
  is **cheap**: `VecReserve` asked `want > v^.cap`, which is true of every
  request once the capacity is clamped, so it reallocated and copied the whole
  vector on every push and a two-megabyte document never arrived.

  The fourth is why 200 000 pushes are made past the ceiling and not a
  handful. It is the one thing here a golden cannot see -- the output is
  identical either way, only slower -- so what separates them is that each
  push past the ceiling is constant-time with the fix and linear without it:
  40 ms against something over half an hour, which the corpus's 300-second
  backstop reports as a failed case. A duration is a fact about the machine
  that took it (ADR-0270), so this is written to be four orders of magnitude
  apart rather than to be measured. }

program container_ceiling(output);

import PasContainer;

type
  CV = ^Vec(char);

var
  v: CV;
  i: integer;
  intact: boolean;

{ The character the i'th push writes, which is a function of i alone -- so a
  wrong element is a wrong element and not merely a different one. }
function Wanted(i: integer): char;
begin
  Wanted := chr(ord('a') + i mod 26)
end;

begin
  VecInit(CV, v, 4);
  for i := 1 to CapMax + 200000 do
    VecPush(CV, v, Wanted(i));
  writeln('len ', VecLen(CV, v):1, ' of ', CapMax:1);
  writeln('cap ', VecCap(CV, v):1);
  if VecFull(CV, v) then writeln('full') else writeln('NOT FULL');

  { Sampled rather than swept: the claim is that the kept prefix is the one
    that was written, and every thousandth element plus both ends says that as
    well as sixteen million reads would, at a cost the sanitizer run can
    afford. }
  intact := VecGet(char, v, 1) = Wanted(1);
  if VecGet(char, v, CapMax) <> Wanted(CapMax) then intact := false;
  i := 1000;
  while i < CapMax do begin
    if VecGet(char, v, i) <> Wanted(i) then intact := false;
    i := i + 1000
  end;
  if intact then writeln('prefix intact') else writeln('PREFIX DAMAGED');
  VecFree(CV, v);

  { And a vector asked at birth for more than the ceiling is clamped there
    too, rather than being given what it asked for or refused. }
  VecInit(CV, v, CapMax * 2);
  writeln('asked ', CapMax * 2:1, ' got ', VecCap(CV, v):1);
  VecFree(CV, v)
end.
