{ What §6.4.9 refuses, and the two restrictions that come from elsewhere. }
program TypeInquiryErrors(output);
type point = record x, y: integer end;
     vector(n: integer) = array [1..n] of integer;

var a: point;
    f: text;
    j: integer;

    { the object must exist... }
    p: type of nosuch;
    { ...and be a variable. A type name is exactly the thing a type-denoter
      usually is, which is why naming one here is the mistake to expect. }
    q: type of point;
    { a constant is not a variable either }
    r: type of maxint;

{ §6.7.3.1: "The parameter-form ... shall not contain an applied occurrence of
  the parameter-identifier." Without that rule the name would find itself. }
procedure selfNamed(x: type of x);
begin
  j := j + 1
end;

{ A procedural parameter's own formals are descriptors: §6.6.3.1 gives them no
  frame and no scope, because the frame they will occupy belongs to whatever
  procedure is eventually passed. So one of them cannot be a type-inquiry's
  object — there is no variable to possess a type. }
procedure outer(procedure inner(y: point; z: type of y));
begin
  j := j + 1
end;

{ A schematic formal's type has no tuple: its bounds live in a descriptor
  belonging to that one parameter, so a second name reading them would have to
  share the descriptor rather than the type. Refused rather than given a type
  whose bounds it cannot read. }
procedure generic(var v: vector; var w: type of v);
begin
  j := j + 1
end;

{ §6.4.2.1: "A type-inquiry in an ordinal-type shall denote an ordinal-type."
  A record is not one, so it cannot index an array. }
var bad: array [type of a] of integer;

begin
  j := 0;
  writeln(j:1)
end.
