{ A function's result as the actual for a structured value parameter.

  ISO 7185 6.6.3.2 and ISO/IEC 10206:1991 6.6.3.2 both say a value parameter's
  actual shall be an *expression* whose value is assignment-compatible with the
  formal, and 6.7.1 makes a function-designator an expression. So `f(g)` where
  g returns a record is legal, and it was refused: "argument 1 of 'f' is r and
  needs a variable".

  The refusal was written from the implementation's side. A structured value
  parameter is copied, so Sema listed what it could copy *from* -- a designator,
  a string literal, a structured-value-constructor, a memory constant -- and a
  call was not on the list because isDesignator answers false for one. That
  answer is right, and it is right for a *var* parameter, where a call has no
  variable to bind. For a value parameter it decides the wrong question.

  **The compiler disagreed with itself**, which is what makes this a defect
  rather than a restriction: `q := MakePoint` already copies a record out of a
  call's storage, because ADR-0055 gives a structured result caller-supplied
  storage and ADR-0056 lets a call carry selectors. Assignment did the copy and
  a parameter refused it, and the two are the same memcpy from the same
  address. Same shape as ADR-0077's `mod`, where the folder and the emitted
  code disagreed about a rule both implemented.

  Every line below is a construct that did not compile. }
program CallResultParam(output);

type
  Point = record x, y: integer end;
  Triple = array [1..3] of integer;
  Label8 = packed array [1..8] of char;
  Boxed = record name: Label8; p: Point end;

function MakePoint(a, b: integer): Point;
var r: Point;
begin
  r.x := a;
  r.y := b;
  MakePoint := r
end;

function MakeTriple(k: integer): Triple;
var t: Triple; i: integer;
begin
  for i := 1 to 3 do
    t[i] := k * i;
  MakeTriple := t
end;

function MakeBoxed(n: Label8; a, b: integer): Boxed;
var w: Boxed;
begin
  w.name := n;
  w.p := MakePoint(a, b);
  MakeBoxed := w
end;

{ the value parameters that could not be reached }
function SumPoint(p: Point): integer;
begin
  SumPoint := p.x + p.y
end;

function SumTriple(t: Triple): integer;
var i, s: integer;
begin
  s := 0;
  for i := 1 to 3 do
    s := s + t[i];
  SumTriple := s
end;

function Describe(w: Boxed): integer;
begin
  Describe := w.p.x * 100 + w.p.y
end;

{ a value parameter is a *copy*: the callee may assign to it and the caller
  must not see it. Worth pinning here because the actual is now a temporary,
  and copying from a temporary is the case where getting it wrong is invisible. }
function Clobber(p: Point): integer;
begin
  p.x := 999;
  Clobber := p.x
end;

var
  q: Point;
  n: integer;

begin
  { the refusal, one construct per line }
  writeln('record from a call:  ', SumPoint(MakePoint(3, 4)):1);
  writeln('array from a call:   ', SumTriple(MakeTriple(2)):1);
  writeln('nested call:         ', Describe(MakeBoxed('outer   ', 5, 6)):1);

  { a call as one argument among several, so the argument positions have to
    stay aligned when one of them is a copied temporary }
  writeln('between two others:  ',
          SumPoint(MakePoint(1, 2)) + SumTriple(MakeTriple(1)):1);

  { the temporary is copied, not aliased }
  q := MakePoint(7, 8);
  n := Clobber(q);
  writeln('clobber returned:    ', n:1, ' and q.x is still ', q.x:1);

  { and the same through a call actual rather than a variable }
  writeln('clobber of a call:   ', Clobber(MakePoint(11, 12)):1);

  { what already worked, kept so a fix in the wrong direction fails too }
  writeln('from a variable:     ', SumPoint(q):1);
  writeln('field of a call:     ', MakePoint(9, 1).x:1);
  writeln('assigned from call:  ', q.y:1)
end.
