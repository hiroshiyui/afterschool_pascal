{ The required functions whose arity or argument types this corpus had never
  been wrong about, plus the two other places a written value is measured
  against a type it has to match.

  `calls.pas` beside this one covers 6.7.6's ordinary transfer and arithmetic
  functions; these are the string ones (6.7.6.7), `binding` (6.7.6.8),
  `cmplx` (6.7.6.3) and 6.8.7.2's array-value. }
program requiredargs(output);
type vec = array [1..3] of integer;
var
  s: string(10);
  b: BindingType;
  z: complex;
  flag: boolean;
  arr: vec;
  i: integer;
begin
  { 6.7.6.8: one argument, and it is a bindable variable. }
  b := binding(s, s);
  { 6.7.6.7: two strings. }
  i := index(s);
  { ...and a string with one or two positions. }
  s := substr(s);
  { 6.7.6.3: two arguments, and both of them numeric. }
  z := cmplx(flag, flag);
  { 6.8.7.2: an array-value's case-constants are of the array's index-type. }
  arr := vec['a': 1 otherwise 0]
end.
