{ PasList -- a sequence of strings the block that declares it owns.

  Every other container here is freed by hand: `VecNew` and `VecFree`,
  `SVecNew` and `SVecFree`, and a program that forgets the second leaks. This
  one has no `Free` at all, and cannot need one. The head is an `owned ^` (AP
  6.4.14, ADR-0181), so the chain is disposed when the variable holding it
  ceases to exist -- at the end of the block, on a `goto` out of it, on
  `halt`. A caller writes

      var l: List;
      ListPush(l, 'a');
      ListPush(l, 'b')

  and that is the whole of the lifetime: no `New` to open it, since a fresh
  variable is empty, and no `Free` to close it.

  **What it is not.** There is no index. AP 6.4.14.3 gives an owned pointer no
  copy, so nothing here can hold a second pointer into the chain -- no tail
  pointer, no cursor, no `for` loop walking one -- and every traversal is a
  recursive procedure taking `var`. That makes `ListLen`, `ListGet`,
  `ListAppend` and `ListDrop` O(n), and it is why this module is not a
  replacement for `PasStrVec`: a program wanting indexed access wants the
  vector. What the list has instead is `ListPush` and `ListPop` in constant
  time, and a lifetime it cannot get wrong.

  **What the type forced.** Writing this module against AP 6.4.14 alone found
  that half of it was unwritable: `n := fresh` and `fresh^.next := n` are both
  copies, so push-front and pop-front could not be expressed and the container
  had no constant-time operation at all. AP 6.4.14.6's `take` is the answer
  (ADR-0182) and it is what every routine below turns on -- most visibly in
  `ListPop`, where `l := take(l^.next)` is the entire body: the source is the
  head's own field, so releasing what the target held disposes the head alone
  and the tail lands in `l`.

  The element is a `string(255)`, as `PasStrVec`'s is, and for the reason
  ADR-0116 gives: a schema is parameterised by a value and never by a type, so
  a container must name its element and a caller wanting another copies the
  file. The names are prefixed `List` so a program may import this beside the
  two vectors. }

module PasList;

export PasList = (ListItemMax, ListItem, List,
                  ListPush, ListPop, ListPeek, ListEmpty, ListLen,
                  ListAppend, ListGet, ListDrop, ListClear, ListReverse);

const
  { The capacity of one element, PasStrVec's ItemMax and for its reason. }
  ListItemMax = 255;

type
  ListItem = string(ListItemMax);
  { The chain. `List` is the whole of what a caller names: a node is this
    module's business, and a caller could do nothing with one anyway -- an
    owned pointer cannot be copied out of the chain. }
  List = owned ^ListNode;
  ListNode = record
    item: ListItem;
    next: List
  end;

{ --- the interface ------------------------------------------------------- }

{ Put an item on the front. Constant time, and 6.4.14.6 twice: the fresh node
  takes what `l` held, and `l` takes the fresh node. }
procedure ListPush(var l: List; item: ListItem);

{ Take the first item off the front, false when there is none. Constant time,
  and one assignment. }
function ListPop(var l: List; var item: ListItem): boolean;

{ The first item without removing it.

  `protected` on the four routines that only read the chain is AP 6.4.14.8
  (ADR-0318), and this module is why the clause exists: an owned pointer cannot
  be a value parameter (6.4.14.3), so before it there was one way to accept a
  chain and it granted every caller the right to release it. The word is not a
  convenience here -- it is the difference between a reader and an owner, and
  it is checked. }
function ListPeek(protected var l: List; var item: ListItem): boolean;

function ListEmpty(protected var l: List): boolean;

{ How many. O(n): there is no count to keep, since every routine that would
  maintain one would have to be the only way to reach the chain, and a caller
  holding `var l` is not bound to go through this module. }
function ListLen(protected var l: List): integer;

{ Put an item on the far end. O(n), a tail pointer being a second name for a
  node and 6.4.14.3 having none. }
procedure ListAppend(var l: List; item: ListItem);

{ The i'th item, counting from 1; false when there is no such item, which is
  how a caller learns the length without asking for it. }
function ListGet(protected var l: List; i: integer; var item: ListItem): boolean;

{ Remove and dispose the i'th item; false when there is no such item. }
function ListDrop(var l: List; i: integer): boolean;

{ Dispose the whole chain and leave the variable empty. }
procedure ListClear(var l: List);

{ Reverse in place, by popping from one chain onto another. }
procedure ListReverse(var l: List);

end;

{ --- the two constant-time operations ------------------------------------ }

{ 6.4.14.6 twice: the fresh node takes what `l` held, and `l` takes the fresh
  node. Neither is a copy, and after the second `fresh` is empty -- which is
  what lets the procedure return without abandoning anything. }
procedure ListPush;
var fresh: List;
begin
  new(fresh);
  fresh^.item := item;
  fresh^.next := take(l);
  l := take(fresh)
end;

{ The whole body is one assignment. `take(l^.next)` empties the head's own
  `next` field and yields the tail; the assignment then releases what `l`
  held -- the head, whose successor has just been emptied out of it, so the
  release reaches that one node and stops -- and stores the tail. }
function ListPop;
begin
  if l = nil then
    ListPop := false
  else begin
    item := l^.item;
    l := take(l^.next);
    ListPop := true
  end
end;

function ListPeek;
begin
  if l = nil then
    ListPeek := false
  else begin
    item := l^.item;
    ListPeek := true
  end
end;

function ListEmpty;
begin
  ListEmpty := l = nil
end;

{ --- the walks ----------------------------------------------------------- }

{ Recursive and not a loop, and that is the type rather than a preference: a
  loop would need a second name for a node, and 6.4.14.3 has none. }
function ListLen;
begin
  if l = nil then ListLen := 0 else ListLen := 1 + ListLen(l^.next)
end;

{ Push at the far end. O(n) with no tail pointer, a tail pointer being a
  second name for a node. }
procedure ListAppend;
begin
  if l = nil then begin
    new(l);
    l^.item := item
  end
  else
    ListAppend(l^.next, item)
end;

{ The i'th element, counting from 1. False when there is no such element,
  which is how a caller learns the length without asking for it. }
function ListGet;
begin
  if (l = nil) or (i < 1) then
    ListGet := false
  else if i = 1 then begin
    item := l^.item;
    ListGet := true
  end
  else
    ListGet := ListGet(l^.next, i - 1, item)
end;

{ Remove the i'th element and dispose it. The recursion stops one node early,
  so the assignment's target is the *previous* node's field: `take` empties
  the doomed node's `next` first, the assignment then releases what the field
  held -- that node alone, its successor already emptied out of it -- and
  stores the successor in its place. }
function ListDrop;
begin
  if (l = nil) or (i < 1) then
    ListDrop := false
  else if i = 1 then begin
    l := take(l^.next);
    ListDrop := true
  end
  else
    ListDrop := ListDrop(l^.next, i - 1)
end;

{ Dispose the whole chain. One statement, because the release is recursive:
  the node owns its successor, which owns its successor. }
procedure ListClear;
begin
  if l <> nil then dispose(l)
end;

{ Pop from one chain and push onto another, which reverses. It needs no
  storage of its own beyond the second head, which 6.4.14.3 has already made
  empty -- and `l := take(rev)` at the end is what hands the result back: a
  local owned pointer left holding the chain would release it on the way out,
  so the move is not a tidiness but the return itself. }
procedure ListReverse;
var rev: List; item: ListItem;
begin
  while ListPop(l, item) do
    ListPush(rev, item);
  l := take(rev)
end;

end.
