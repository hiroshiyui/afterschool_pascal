{ PasList -- a sequence of strings the block that declares it owns.

  Every other container here is freed by hand: `VecNew` and `VecFree`,
  `SVecNew` and `StrVecPtr`'s `Free`, and a program that forgets the second
  leaks. This
  one has no `Free` at all, and cannot need one. The head is an `owned ^` (AP
  6.4.14, ADR-0181), so the chain is disposed when the variable holding it
  ceases to exist -- at the end of the block, on a `goto` out of it, on
  `halt`. A caller writes

      var l: List;
      l.Push('a');
      l.Push('b')

  and that is the whole of the lifetime: no `New` to open it, since a fresh
  variable is empty, and no `Free` to close it.

  **What it is not.** There is no index. AP 6.4.14.3 gives an owned pointer no
  copy, so nothing here can hold a second pointer into the chain -- no tail
  pointer, no cursor, no `for` loop walking one -- and every traversal is a
  recursive procedure taking `var`. That makes `Len`, `Get`, `Append` and
  `Drop` O(n), and it is why this module is not a replacement for
  `PasStrVec`: a program wanting indexed access wants the vector. What the
  list has instead is `Push` and `Pop` in constant time, and a lifetime it
  cannot get wrong.

  **What the type forced.** Writing this module against AP 6.4.14 alone found
  that half of it was unwritable: `n := fresh` and `fresh^.next := n` are both
  copies, so push-front and pop-front could not be expressed and the container
  had no constant-time operation at all. AP 6.4.14.6's `take` is the answer
  (ADR-0182) and it is what every routine below turns on -- most visibly in
  `Pop`, where `l := take(l^.next)` is the entire body: the source is the
  head's own field, so releasing what the target held disposes the head alone
  and the tail lands in `l`.

  The element is a `string(255)`, as `PasStrVec`'s is, and for the reason
  ADR-0116 gives: a schema is parameterised by a value and never by a type, so
  a container must name its element and a caller wanting another copies the
  file. The three names that stay exported are prefixed `List` so a program
  may import this beside the two vectors. }

module PasList;

{ **What a client is given is the type, and the type carries its routines**
  (AP 6.7.10.5, ADR-0411). Three names are exported where thirteen were:
  `List` has an implementation in the block below, and an implementation is
  selected from the *type* of the receiver rather than from a name in scope
  (AP 6.7.10.2), so none of its routines is an exported name and none can
  collide with another module's. That is what retired the `List` prefix from
  ten of them: `ListPush` is `Push`, `ListLen` is `Len`, `ListGet` is `Get`
  and `ListClear` is `Clear` -- the spellings `PasVector`, `PasMap` and
  `PasStrVec` already use, every one of them a collision §6.11.2's one scope
  would have refused to two exported names (ADR-0412).

  Nothing stays exported but the type, its element type and the element's
  bound. There is no constructor here to be exported for want of a receiver,
  a fresh variable being an empty list already, and every one of the ten
  routines takes the chain it acts on as its first parameter. }

export PasList = (ListItemMax, ListItem, List);

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

end;

{ --- the chain ------------------------------------------------------------ }

impl List;

  { Put an item on the front. Constant time, and 6.4.14.6 twice: the fresh
    node takes what `l` held, and `l` takes the fresh node. Neither is a copy,
    and after the second `fresh` is empty -- which is what lets the procedure
    return without abandoning anything. }
  procedure Push(var l: List; item: ListItem);
  var fresh: List;
  begin
    new(fresh);
    fresh^.item := item;
    fresh^.next := take(l);
    l := take(fresh)
  end;

  { Take the first item off the front, false when there is none. Constant
    time, and one assignment.

    That one assignment is the whole body. `take(l^.next)` empties the head's
    own `next` field and yields the tail; the assignment then releases what
    `l` held -- the head, whose successor has just been emptied out of it, so
    the release reaches that one node and stops -- and stores the tail. }
  function Pop(var l: List; var item: ListItem): boolean;
  begin
    if l = nil then
      Pop := false
    else begin
      item := l^.item;
      l := take(l^.next);
      Pop := true
    end
  end;

  { The first item without removing it.

    `protected` on the four routines that only read the chain is AP 6.4.14.8
    (ADR-0318), and this module is why the clause exists: an owned pointer
    cannot be a value parameter (6.4.14.3), so before it there was one way to
    accept a chain and it granted every caller the right to release it. The
    word is not a convenience here -- it is the difference between a reader
    and an owner, and it is checked. }
  function Peek(protected var l: List; var item: ListItem): boolean;
  begin
    if l = nil then
      Peek := false
    else begin
      item := l^.item;
      Peek := true
    end
  end;

  { Whether there is nothing in it. }
  function Empty(protected var l: List): boolean;
  begin
    Empty := l = nil
  end;

  { How many. O(n): there is no count to keep, since every routine that would
    maintain one would have to be the only way to reach the chain, and a
    caller holding `var l` is not bound to go through this module.

    Recursive and not a loop, and that is the type rather than a preference: a
    loop would need a second name for a node, and 6.4.14.3 has none. The
    recursive call names the routine rather than the receiver, here and in the
    three below: inside the implementation a method's own name is in scope, and
    for a **function** that is the only spelling there is -- `l^.next.Len`
    within `Len` is *cannot select a field of a value of type list, and no
    routine of that name is implemented for it*, the implementation carrying
    it not being complete yet (§6.2.2.9). }
  function Len(protected var l: List): integer;
  begin
    if l = nil then Len := 0 else Len := 1 + Len(l^.next)
  end;

  { Put an item on the far end. O(n), a tail pointer being a second name for a
    node and 6.4.14.3 having none. }
  procedure Append(var l: List; item: ListItem);
  begin
    if l = nil then begin
      new(l);
      l^.item := item
    end
    else
      Append(l^.next, item)
  end;

  { The i'th item, counting from 1; false when there is no such item, which is
    how a caller learns the length without asking for it. }
  function Get(protected var l: List; i: integer; var item: ListItem): boolean;
  begin
    if (l = nil) or (i < 1) then
      Get := false
    else if i = 1 then begin
      item := l^.item;
      Get := true
    end
    else
      Get := Get(l^.next, i - 1, item)
  end;

  { Remove and dispose the i'th item; false when there is no such item. The
    recursion stops one node early, so the assignment's target is the
    *previous* node's field: `take` empties the doomed node's `next` first,
    the assignment then releases what the field held -- that node alone, its
    successor already emptied out of it -- and stores the successor in its
    place. }
  function Drop(var l: List; i: integer): boolean;
  begin
    if (l = nil) or (i < 1) then
      Drop := false
    else if i = 1 then begin
      l := take(l^.next);
      Drop := true
    end
    else
      Drop := Drop(l^.next, i - 1)
  end;

  { Dispose the whole chain and leave the variable empty. One statement,
    because the release is recursive: the node owns its successor, which owns
    its successor. }
  procedure Clear(var l: List);
  begin
    if l <> nil then dispose(l)
  end;

  { Reverse in place, by popping from one chain onto another. It needs no
    storage of its own beyond the second head, which 6.4.14.3 has already made
    empty -- and `l := take(rev)` at the end is what hands the result back: a
    local owned pointer left holding the chain would release it on the way
    out, so the move is not a tidiness but the return itself. }
  procedure Reverse(var l: List);
  var rev: List; item: ListItem;
  begin
    while l.Pop(item) do
      rev.Push(item);
    l := take(rev)
  end;
end;

end.
