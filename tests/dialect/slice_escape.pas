{ ADR-0143: 6.4.9's type-inquiry names a slice type, so "a type that cannot be
  named" was not true.

  AP 6.7.3.9.2 confines a slice-parameter-type to a formal parameter's own
  denoter, and its NOTE argued the rule needs one test rather than a list of
  positions, because *a type that cannot be named cannot be created anywhere
  the list might have missed*. ISO/IEC 10206:1991 6.4.9 supplies the name:

      type-inquiry = 'type' 'of' type-inquiry-object .

  denotes the type its object *possesses*, and the clause's own worked example
  is a var parameter with a local variable declared from it. The dialect
  contains Extended Pascal, so `type of a` is available wherever a slice formal
  is in scope -- and every position 6.7.3.9.2 lists was reachable through it:
  a variable, a type-definition, a record field, an array component, a pointer
  domain and a file component were all accepted, each holding a two-word
  descriptor that nothing had filled in. `length` of one answered -1.

  The refusal is in ResolveInquiry, which is the one place that closes all six,
  because a type-inquiry is the only denoter that can produce a slice type
  without writing `array of`. The NOTE was right that one test suffices and
  wrong about where it already was.

  So this file reports **two** diagnostics and not six: each names an inquiry,
  and the four positions below the type-definition are closed by `t2` never
  becoming a slice rather than by a complaint of their own. They are written
  out anyway, because what a later reader needs to know is which positions the
  hole reached, and a file that lists them is what says so.

  Found by a specification audit, from the standard's own example. }
program SliceEscape(output);
type vec = array [1..4] of integer;

procedure Positions(var a: array of integer);
type
  t2 = type of a;             { 6.7.3.9.2: not a type-definition }
  pt = ^t2;                   { ...nor a pointer domain }
var
  v: type of a;               { ...nor a variable }
  r: record f: t2 end;        { ...nor a record's field }
  t: array [1..2] of t2;      { ...nor an array's component }
  f: file of t2;              { ...nor a file's component }
  q: pt;
begin
end;

{ And the inquiry still means what it means for every type that is not a
  slice, which is the half a fix in the wrong direction breaks. }
procedure Ordinary(var a: vec);
var b: type of a; i: integer;
begin
  for i := 1 to 4 do b[i] := a[i] * 2;
  writeln(b[1], ' ', b[4])
end;

var arr: vec;
begin
  arr[1] := 1; arr[4] := 4;
  Ordinary(arr)
end.
