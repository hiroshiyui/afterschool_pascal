{ ISO 7185 §6.2.2.11: "Whatever an identifier or label denotes at its
  defining-point shall be denoted at all applied occurrences of that identifier
  or label."

  §6.2.2.10 puts the required identifiers' defining-points in a region
  enclosing the program, so a program may declare its own -- and once it has,
  that is what the name denotes for the whole of the block. A program that
  declares `ord` a variable has no `ord` function in it.

  A required function was recognised by *spelling* when the name resolved to
  something that could not be called, so `var ord: array [1..3] of integer`
  and `ord('a')` both worked, in one block, meaning two different things. The
  required *procedures* never had this: their path reports here, which is the
  asymmetry §6.2.2.10 does not license -- it names "procedures, and functions"
  in one sentence.

  tests/required_shadow.pas is the half where the declaration is a function
  and the call is therefore the program's own. }
program RequiredShadowErrors(output);
const
  abs = 7;                        { a required function, redeclared as a const }
type
  sqrt = integer;                 { and as a type }
var
  ord : array [1..3] of integer;  { and as a variable }
  n, m : integer;
  p : ^integer;
  new : integer;                  { a required procedure, for the symmetry }

begin
  ord[1] := 1;
  new := 2;
  n := ord('a');
  m := abs(-3);
  n := sqrt(9);
  new(p)
end.
