{ AP 6.4.16 and 6.9.3.13: what a channel-type and the two operations on it
  refuse (ADR-0268).

  Both operations take the channel *first* and a variable or value second,
  which is `read` and `write`'s order -- and both require the first argument
  to be a designator, because there is one object and the statement acts on
  it rather than on a copy. An `external` function answering a channel is the
  only way to write a channel-valued expression that is not one, which is why
  it is here. }
program channels(output);
type ch = channel [4] of integer;
var
  n: integer;
  { The capacity is part of the type, so it is a constant-expression and a
    variable is not one. }
  bad: channel [n] of integer;
  c: ch;
  v: integer;
  ok: boolean;

{ AP 6.4.12.3: an external function is where a handle is born, so this is the
  one way to write a channel that is not a variable. }
function mk: ch; external 'pasx_no_such_channel';

begin
  send(c);
  ok := receive(c);
  send(mk, 1);
  ok := receive(mk, v)
end.
