{ What AP 6.4.9 refuses about a variable-access, and where each restriction
  comes from (ADR-0215). }
program typeinquiry_access_errors(output);

type arr = array [1..3] of integer;
     Point = record x, y: integer end;

const c = arr[1: 10; 2: 20; 3: 30];

var s: string(10);
    j: integer;

    { §6.8.8's constant-access reads a component and denotes a value, not a
      variable — the same predicate every other position asks, so the refusal
      needed nothing of its own. A function-access cannot arise here: the
      selector production has no `(`, so `type of f(1)` never becomes one. }
    bad1: type of c[1];

    { §6.5.6's substring-variable *is* a variable-access, and what it possesses
      is §6.4.3.3.1's canonical-string-type: a pointer and a length with no
      storage behind them. `var x: string` is refused one clause earlier for
      the same reason, and a program that got one this way ran until its first
      assignment and stopped at a capacity of zero. }
    bad2: type of s[1..3];

{ §6.4.9's restriction on a parameter-identifier applies to the *root* of the
  access: the list closest-containing the object is q's, and k's defining-point
  as a parameter-identifier is in outer's. The bare-name form of this is in
  tests/extended/typeinquiry_errors.pas (ADR-0134). }
procedure outer(k: Point; procedure q(x: type of k.x));
begin
  j := j + 1
end;

{ §6.7.3.1: "The parameter-form ... shall not contain an applied occurrence of
  the parameter-identifier", and the occurrence is at the root here too. }
procedure selfNamed(x: type of x.y);
begin
  j := j + 1
end;

begin
  j := 0;
  writeln(j:1)
end.
