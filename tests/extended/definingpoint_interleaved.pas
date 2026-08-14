{ §6.2.2.9: "The defining-point of an identifier or label shall precede all
  applied occurrences of that identifier or label contained by the
  program-block."

  ISO/IEC 10206:1991 §6.2.1 makes a block a *repetition* of the five
  declaration parts in any order, so a variable-declaration-part may follow a
  procedure-and-function-declaration-part and the program below parses. §6.2.2.9
  is what then forbids the use: `zz` is applied inside `late`'s body and defined
  after it.

  It was accepted, because Sema declared every constant, type and variable of a
  block before checking any procedure body -- so by the time a body was walked,
  every variable of the block existed whatever the source order was. ADR-0069
  merged the constant, type and variable parts by source position and made
  `var v: t` before `type t` the forward reference the clause says it is;
  ADR-0088 gave a symbol the machinery to notice an applied occurrence. Neither
  could reach a procedure body, because the bodies were all walked afterwards.
  The procedure part is merged in now too.

  Under --std=iso7185 this program is refused a clause earlier, by §6.2.1's
  fixed order (ADR-0072), which is why the case is here rather than in tests/.

  Everything below the one reported use is a shape that must *not* be reported,
  because a false positive here refuses ordinary Pascal: the compiler is 25,000
  lines of it. }
program DefiningPointInterleaved(output, pf);

{ --- what must be reported --------------------------------------------- }

procedure late;
begin
  { §6.2.2.9: `zz` has no defining-point yet. }
  writeln(zz:1)
end;

var zz: integer;

{ --- and what must not -------------------------------------------------- }

{ A variable declared before the procedure that uses it: the ordinary shape,
  and the one the fix must leave alone. }
var before: integer;

procedure usesBefore;
begin
  before := before + 1
end;

{ A type used by a variable declared after it. §6.2.1's own ISO 7185 order,
  written after a procedure part -- which is legal here and is what makes the
  merge do work rather than reproduce the fixed order. }
type pair = record x, y: integer end;

var p: pair;

procedure usesPair;
begin
  p.x := 1;
  p.y := 2
end;

{ §6.6.1: a heading and its `forward` directive, resumed after an intervening
  variable-declaration-part. The resumption is a procedure-identification, so
  it repeats neither the parameters nor the result type -- and the variable
  written between the two halves is declared by the time the body is walked. }
procedure resumed(k: integer); forward;

var afterForward: integer;

procedure resumed;
begin
  afterForward := k
end;

{ A pointer whose domain is defined further down the *same* type-definition-
  part: §6.2.2.9's one exception, and it must survive the procedure parts on
  either side of the part. }
{ §6.10's parameters must be bound before the first body is checked, because
  §6.5.1 confers bindability on the *declaration* and a body may ask
  binding(f) of one -- and the §6.10 diagnostics must wait for the whole
  block, because a variable-declaration-part may follow a procedure. Both at
  once is what makes the binding happen twice: silently here, and reported
  after the walk. Without the silent pass `pf` is not bindable inside `asks`
  and this file gains an error; without the reported one, `pf` is reported as
  undeclared. }
var pf: text;

procedure asks;
begin
  if binding(pf).bound then writeln('bound')
end;

var afterParam: integer;

type link = ^cell;
     cell = record next: link; v: integer end;

var head: link;

begin
  zz := 1;
  before := 0;
  usesBefore;
  usesPair;
  resumed(7);
  head := nil;
  afterParam := 3;
  asks;
  writeln(before:1, p.x:1, afterForward:1, afterParam:1, head = nil)
end.
