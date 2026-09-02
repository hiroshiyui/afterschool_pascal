{ AP 6.7.3.10.4's refusals (ADR-0254).

  Two of the three are the messages the language already had, which is the
  argument for the rule rather than an accident of it: once the first
  determining position has bound a type parameter, every later actual is an
  ordinary actual of an ordinary formal, and 6.4.6 refuses it in the words it
  refuses every other mismatch in. A second inference rule would have needed a
  second diagnostic saying two positions disagreed, and there is nothing to
  disagree about.

  The one new message is for a call where *nothing* says what a type parameter
  is. `VecGet` and `MapGet` in `lib/dialect/pascontainer.pas` are the standing
  case: their element type appears only in the result, and 6.7.1 makes a
  result-type a type-name rather than an actual, so there is nothing to read
  it off. Those two keep their type arguments, and this says why. }
program generic_infer_errors(output);

type
  Code = (failed, refused);
  Fallible(T: type) = T ! Code;
  IntFallible = Fallible(integer);

function ValueOr(T: type; res: Fallible(T); whenBad: T): T;
begin
  if res.ok then ValueOr := res.val else ValueOr := whenBad
end;

{ T stands in the result and nowhere an actual can reach. }
function Pick(T: type; n: integer): T;
var got: T;
begin
  if n > 0 then Pick := got else Pick := got
end;

procedure Swap(T: type; var a, b: T);
var held: T;
begin
  held := a; a := b; b := held
end;

{ The default first, so the *value* determines T and the result is then held
  to Fallible(T). This call was accepted with exit 0 until ADR-0297: the
  production `Fallible(T)` read its own discriminant instead of the bound T,
  came out with no value type, and Assignable answered yes to a nil side. }
function WhenBadFirst(T: type; whenBad: T; res: Fallible(T)): T;
begin
  if res.ok then WhenBadFirst := res.val else WhenBadFirst := whenBad
end;

var
  good: IntFallible;
  i: integer;
  c: char;

begin
  good := 7;
  i := 1;
  c := 'x';

  { Nothing determines T. }
  writeln(Pick(3):1);

  { The first determining position binds T to integer; the second actual is
    then an ordinary one and is refused as any other mismatch is. }
  Swap(i, c);

  { A count that is neither form: short of the written one and long for the
    inferred one, so it is read as the written one and says so. }
  writeln(ValueOr(good):1);

  { The default binds T to char; `good` is a Fallible(integer) and is refused
    as the mismatch it is, in the words a mismatch has always had. }
  writeln(WhenBadFirst('?', good))
end.
