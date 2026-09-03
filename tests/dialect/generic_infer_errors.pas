{ AP 6.7.3.10.4's refusals (ADR-0254).

  Two of the three are the messages the language already had, which is the
  argument for the rule rather than an accident of it: once the first
  determining position has bound a type parameter, every later actual is an
  ordinary actual of an ordinary formal, and 6.4.6 refuses it in the words it
  refuses every other mismatch in. A second inference rule would have needed a
  second diagnostic saying two positions disagreed, and there is nothing to
  disagree about.

  The one new message is for a call where *nothing* says what a type parameter
  is. `MapKeyAt` in `lib/dialect/pascontainer.pas` is the standing case: its
  key type appears only in the result, and 6.7.1 makes a result-type a
  type-name rather than an actual, so there is nothing to read it off. That
  one writes its key type and this says why. Since ADR-0304 it writes *only*
  that one, the activation being free to write a prefix of its type arguments
  -- so the message has a second reader, `Pair` below, where the prefix is
  written and what is left over is still determined by nothing. }
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

{ Two type parameters, and the second stands in the result exactly as `Pick`'s
  does. Writing the first is admitted (AP 6.7.3.10.4, ADR-0304) and does not
  make the second determinable, so the refusal has to name *which* type
  argument is missing rather than asking for the list again. }
function Pair(T: type; U: type; n: integer): U;
var got: U;
begin
  if n > 0 then Pair := got else Pair := got
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
  writeln(WhenBadFirst('?', good));

  { A written prefix of one, and the type parameter left over is determined by
    nothing. The message names `u` and not the whole list. }
  writeln(Pair(integer, 3):1)
end.
