{ The other program-component. It stores through the `bad` arm, so the tag no
  longer selects `num`, and then asks the module to read `num`.

  Compiled with the module under one mode this is either unchecked (both
  Extended Pascal) or a trap (both dialect). Compiled under two modes it was
  neither: the module's guard ran against a tag this component never stored and
  let the read through. That mixture no longer links. }
program User(output);

import Parts;

var a: Answer; n: integer;

begin
  a.msg := 'boom';
  { into a variable first, so a trap in Peek leaves no half-written line and
    the two matched builds differ in the whole of their output }
  n := Peek(a);
  writeln('peek ', n:1)
end.
