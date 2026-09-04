{ PasList -- the module AP 6.4.14 and 6.4.14.6 were built for.

  What this case adds to owned.pas and take.pas, which observe the release
  through a stream, is that the chain crosses a **module boundary**: the node
  type is this module's business and never exported, the caller names only
  `List`, and the caller's own block is what releases what it holds. Each
  translation emits its own release routine -- `@ownrelN` is `define
  internal` -- so the two do not collide.

  `BuiltAndAbandoned` is the point of the type: fifty nodes per call, four
  thousand calls, and no `Free` anywhere in this program. **No oracle here can
  assert on the bytes** -- every one of them reads what a program prints, and a
  leak prints nothing (doc/sop.md 7) -- so the count is chosen to make the
  difference large enough to see by hand. Peak RSS is 5.8 MB; with the block's
  release suppressed in the compiler it is 58 MB, which is the mutation that
  killed this case and the only way it can be killed. }

program lib_list(output);

import PasList;

var
  l, other: List;
  s: ListItem;
  i: integer;

procedure ShowAll(protected var q: List; label_: ListItem);
var k: integer; item: ListItem;
begin
  write(label_);
  for k := 1 to ListLen(q) do
    if ListGet(q, k, item) then write(' ', item);
  writeln
end;

{ the block owns `local`, so leaving it disposes the chain -- there is no
  Free to call and none to forget }
procedure BuiltAndAbandoned;
var local: List; k: integer;
begin
  for k := 1 to 50 do ListPush(local, 'x')
end;

begin
  writeln('fresh is empty: ', ListEmpty(l));

  ListPush(l, 'b');
  ListPush(l, 'a');
  ListAppend(l, 'c');
  ShowAll(l, 'built:');
  writeln('len ', ListLen(l):1);

  if ListPeek(l, s) then writeln('peek ', s);
  if ListPop(l, s) then writeln('pop ', s);
  ShowAll(l, 'after pop:');

  ListPush(l, 'a');
  ListReverse(l);
  ShowAll(l, 'reversed:');

  if ListDrop(l, 2) then writeln('dropped the second');
  ShowAll(l, 'after drop:');
  writeln('drop past the end: ', ListDrop(l, 9));

  { a move between two variables of the type is what take is for, and the
    module needs no routine of its own for it }
  other := take(l);
  ShowAll(other, 'moved:');
  writeln('the old head is empty: ', ListEmpty(l));

  ListClear(other);
  writeln('cleared: ', ListEmpty(other), ' len ', ListLen(other):1);

  for i := 1 to 4000 do BuiltAndAbandoned;
  writeln('4000 chains built and abandoned, every one released by its block')
end.
