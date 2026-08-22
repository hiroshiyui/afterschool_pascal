{ §6.9.4 b) for §6.7.3.7.3's variable conformant array, which §6.5.1 names in
  its own cross-reference: "No statement shall threaten (see 6.9.4) a
  variable-access closest-containing a protected variable-identifier (see
  6.7.3.1, 6.7.3.7.1, and 6.11.3)."

  §6.7.3.7.1 is there because a conformant-array-parameter-specification may
  itself say `protected`, and §6.7.3.7.3 is what makes b) reach the actual:
  "Each actual-parameter corresponding to a formal variable parameter shall be
  a variable-access". A formal variable parameter is what a variable
  conformant array is, so handing a protected variable to an unprotected one
  is the same defeat of the protection that `writesIt` is in
  protected_errors.pas -- and it was accepted, silently, until this case.

  The value form is not a threat and is not listed here: §6.7.3.7.2 attributes
  the expression's value to a variable of the activation, so nothing of the
  actual is written. `conformant_threatens_result.pas` is what pins that half,
  a function relying on the value form staying no threat.

  Extended Pascal only: ISO 7185 has conformant arrays but no `protected`. }
program ProtectedConformant(output);
type triple = array [1..3] of integer;
     nest = record t: triple end;

{ Free to write what it is handed -- that is the whole objection. }
procedure writesConf(var a: array [lo..hi: integer] of integer);
begin
  a[lo] := 0
end;

{ Protected, so it may hand its parameter only to a formal that is protected
  too; §6.9.4 b)'s "that is not protected" is the base case. }
procedure guardedConf(protected var a: array [lo..hi: integer] of integer);
begin
  writeln(a[lo]:1)
end;

procedure hands(protected var v: triple; protected var n: nest);
begin
  writesConf(v);
  { §6.9.4 h): a threat to a component is a threat to the variable containing
    it, so the field selection does not launder the protection either. }
  writesConf(n.t);
  { Legal, and here to show the refusal is about the formal and not about
    conformant arrays: this one promises not to write. }
  guardedConf(v)
end;

{ §6.7.3.7.1: "If the conformant-array-parameter-specification contains
  protected, then the variable-identifier shall be designated protected", so a
  protected conformant array is under the rule as an *actual* as well. }
procedure passesOn(protected var a: array [lo..hi: integer] of integer);
begin
  writesConf(a)
end;

var g: triple; h: nest;
begin
  g[1] := 1;
  h.t[1] := 2;
  hands(g, h);
  passesOn(g)
end.
