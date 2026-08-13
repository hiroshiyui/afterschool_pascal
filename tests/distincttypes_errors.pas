{ Two types written alike are two types, and the message has to say so.

  §6.4.1 of both standards is the rule: "Each occurrence of a new-type shall
  denote a type that is distinct from any other new-type." ISO/IEC 10206:1991
  spells the same sentence over activations. So `a: record x: integer end` and
  `b: record x: integer end` possess different types, and §6.4.6's first
  alternative — the two shall be the same type — is not met.

  The rule was enforced correctly and reported uselessly. `Type::name()` writes
  an anonymous type the way the source wrote it, so both sides of the message
  printed the same characters:

    cannot assign record x end to a variable of type record x end

  which is accurate, names the rule nowhere, and reads like a compiler bug. The
  file case beside the assignment check had already been given a message of its
  own for exactly this fault, and the comment there says why; nothing had
  noticed that the general case has it too.

  Nothing could notice, and one thing looked straight at it. `type_errors.pas`
  compares two alike-looking records, so its golden `.err` file has held a
  message of this shape since structured types landed — with nothing to
  distinguish a message that reports a rule from one that explains it, and
  `difftest.sh`, the one oracle that sees a diagnostic at all, comparing two
  compilers that were unhelpful in the same way and reporting that they agreed.

  What this pins is the whole of the new behaviour, which is two sentences
  rather than one:

  - Where both types are anonymous there is something to do about it, so the
    message says it: declare one named type and give it to both.
  - Where both are type-*names* that print alike — `t` inside a procedure that
    redefines a `t` from the program — the reason is identical, but repeating
    "give it a name" would be no advice. That half is left off.

  And it pins where the sentence is added: an assignment, an assignment to a
  function's result, a relational operator, a var parameter and a value
  parameter. Five messages name two types; a sixth that named two lengths does
  not, because two different lengths never print alike.

  The last statement below is the case that pins where the sentence is *not*
  added, and it is the one `type_errors.pas` already had. A relational operator
  reports two different faults: operands that are not compatible — where being
  written alike is the whole reason, and naming the type fixes it — and
  operands whose *kind* has no such operator, which two types written alike
  necessarily share. §6.7.2.5 gives a record no relational operators at all, so
  a message about `a = b` that offered to name the type would be offering a
  cure for something else. }
program distincttypes_errors(output);

type
  t  = array [1..3] of integer;
  pi = ^integer;

var
  { Anonymous on both sides: each `record ... end` is a new-type of its own. }
  a: record x: integer end;
  b: record x: integer end;
  { Likewise for two pointer-types written the same way. §6.4.4's domain is a
    type-identifier, but the pointer-type itself is a new-type each time. }
  p: ^integer;
  q: ^integer;
  g: t;
  op: pi;

  { Two denoters written alike whose spelling is 263 characters — past the 255
    the two compilers share as the longest name they can compare, `strMax` in
    `selfhost/compiler.pas` and `kTypeNameCompareLimit` beside the note in
    `src/sema.cpp`. The Pascal compiler asks "do these print alike" by
    rendering both through a buffer of that size, so a longer spelling is a
    question it cannot answer; the C++ therefore declines to answer it either,
    because a diagnostic the two disagree about is worse than one neither
    gives. One level fewer is 247 characters and does carry the note. }
  deep1: array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of integer;
  deep2: array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of array [1..1] of array [1..1] of
         array [1..1] of integer;

{ A block that redefines both names. Everything below denotes the inner type,
  and everything passed in from the program block denotes the outer one --
  which is what makes the two spellings collide without either being wrong. }
procedure inner;

type
  t  = array [1..3] of integer;
  pi = ^integer;

var
  l: t;

  procedure takesvar(var v: t);
  begin
    v[1] := 0
  end;

  procedure takesval(v: t);
  begin
    l := v
  end;

  { §6.6.2 admits a simple- or pointer-type as a result-type, so the collision
    has to be arranged with the pointer pair rather than the arrays. }
  function outerp: pi;
  begin
    outerp := op
  end;

begin
  l := g;
  takesvar(g);
  takesval(g);
  if outerp = nil then
    writeln
end;

begin
  a := b;
  if p = q then
    writeln;
  inner;
  if a = b then
    writeln;
  deep1 := deep2
end.
