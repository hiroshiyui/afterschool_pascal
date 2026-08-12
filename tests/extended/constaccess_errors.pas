{ What a constant-access is not, and what §6.8.8 makes an error.

  §6.5.1's variable-accesses are entire-variables, components and identified-
  variables. A constant-access has the same three selector forms and a constant
  at the bottom of them, so it is a *value* however deeply it is selected into —
  and every rule wanting a variable refuses it through the message it already
  had (ADR-0069).

  The two errors §6.8.8 does add are found at compile time here, because a
  constant's index and a constant's tag are both constants: D.88's index
  outside the array, D.91's substring outside the string, and D.90's component
  of an inactive variant.

  Sema accumulates rather than bailing, so every message below comes from one
  run. }
program constaccess_errors(input, output);
type
  vec   = array [1..4] of integer;
  point = record x, y: integer end;
  shape = record
            case round: boolean of
              true:  (r: integer);
              false: (w, h: integer)
          end;
const
  squares = vec[1: 1; 2: 4; 3: 9; 4: 16];
  origin  = point[x: 0; y: 0];
  circle  = shape[case round: true of [r: 5]];
  hex     = '0123456789';

{ D.88: outside the index-type there is no component to denote. D.91 is the
  same sentence for a substring, and §6.8.8.4 adds that the first index may
  not exceed the second. }
const
  outside = squares[7];
  short   = hex[0..4];
  crossed = hex[6..3];
  { D.90: the variant the value did not select has no component. }
  hidden  = circle.w;

var
  v: vec;
  i: integer;

procedure byref(var a: vec);
begin
  a[1] := 0
end;

{ §6.8.2: an expression naming a variable is not nonvarying, so it is not a
  constant-expression however structured it looks. }
const
  varying = vec[1: i; 2: 0; 3: 0; 4: 0];

begin
  { §6.8.2.2's assignment-statement wants a variable-access. Selecting into a
    constant does not produce one — `isDesignator` asks the base, and the base
    is a constant. }
  squares[1] := 0;
  origin.x := 1;

  { §6.6.3.3: an actual var parameter is a variable-access. }
  byref(squares);

  { §6.9.1: so is a read-parameter. }
  read(squares[1]);

  { §6.9.3.10 introduces constant-field-identifiers, which denote values —
    the `with` itself is legal and constaccess.pas uses one. }
  with origin do
    x := 1;

  { A constant-access is not a variable even when it is the whole of one. }
  v := squares;
  writeln(v[1]:1, i:1)
end.
