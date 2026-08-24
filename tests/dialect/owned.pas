{ AP 6.4.14: `owned ^T` gives a created variable an owner (ADR-0181).

  What the type is for is the hole ADR-0151's *lifetime* half left open: a
  variable created by `new` and identified by an ordinary pointer exists in no
  activation, so 6.4.12.3's release list reaches nothing of it, and a program
  that forgets `dispose` never releases what it holds. Under a 64-descriptor
  limit a loop opening one stream per heap record reported "empty" at the 62nd
  iteration; the same loop with the record owned runs 3000 times.

  The release is *observed* here and not assumed: fputs is buffered until
  fclose, so reading a file back says whether the closer ran. }
program owned(output, scratch);
type
  { the domain is a name defined later, which is 6.4.4's exception and what
    lets a type own a variable of its own type (AP 6.4.14.1) }
  NodePtr = owned ^Node;
  Node = record key: integer; next: NodePtr end;
  Stream = handle external 'fclose';
  Box = record s: Stream end;
  BoxPtr = owned ^Box;
  Holder = record tag: integer; b: BoxPtr end;
  Bank = array [1..3] of BoxPtr;
  { `owned` is not reserved: this program uses the spelling as a type name,
    and the two readings never meet because only `owned ^` is the dialect's }
  owned = integer;
var
  head: NodePtr; i, k: integer; plain: owned;
  scratch: bindable text; bnd: BindingType; line: string(60);
function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(t: string; s: Stream): integer; external 'fputs';

{ traversal is a recursive procedure taking `var`, because a loop would need a
  second pointer and a second pointer is a copy (AP 6.4.14 NOTE 1) }
procedure Push(var n: NodePtr; key: integer);
begin
  if n = nil then begin
    new(n);
    n^.key := key
  end
  else
    Push(n^.next, key)
end;

function Len(var n: NodePtr): integer;
begin
  if n = nil then Len := 0 else Len := 1 + Len(n^.next)
end;

function Sum(var n: NodePtr): integer;
begin
  if n = nil then Sum := 0 else Sum := n^.key + Sum(n^.next)
end;

{ the block owns `q`, so leaving it disposes the Box and closes the stream
  inside it -- neither of which this procedure says a word about }
procedure WriteThrough(text_: string);
var q: BoxPtr;
begin
  new(q);
  q^.s := ExtFopen('owned_scratch.tmp', 'w');
  k := ExtFputs(text_, q^.s)
end;

{ an owned pointer reached through a record field, and through an array
  element: WalkFiles walks a record's fields and loops over an array's
  components, so the release arrives at each of them by the same route a file
  inside one does }
procedure ThroughRecord(text_: string);
var h: Holder;
begin
  h.tag := 1;
  new(h.b);
  h.b^.s := ExtFopen('owned_scratch.tmp', 'w');
  k := ExtFputs(text_, h.b^.s)
end;

procedure ThroughArray(text_: string);
var slots: Bank; j: integer;
begin
  for j := 1 to 3 do new(slots[j]);
  { only one of the three writes; all three are released on the way out }
  slots[2]^.s := ExtFopen('owned_scratch.tmp', 'w');
  k := ExtFputs(text_, slots[2]^.s)
end;

procedure ReadBack;
begin
  bnd := binding(scratch);
  bnd.name := 'owned_scratch.tmp';
  bind(scratch, bnd);
  reset(scratch);
  readln(scratch, line);
  writeln('read back: ', line);
  unbind(scratch)
end;

begin
  { a fresh owned pointer is empty, and it is the prologue that says so and
    not the stack's last occupant (AP 6.4.14.3) }
  writeln('fresh: ', head = nil);
  plain := 41;
  writeln('a type named owned: ', plain + 1:1);

  for i := 1 to 5 do Push(head, i * i);
  writeln('length ', Len(head):1, ', sum ', Sum(head):1);
  writeln('first ', head^.key:1, ' second ', head^.next^.key:1);

  { dispose is the early release, and it reaches the whole list: one routine
    per domain, calling itself down the chain (AP 6.4.14 NOTE 2) }
  dispose(head);
  writeln('after dispose: ', head = nil);

  { and the list may be built again over the same variable }
  Push(head, 7);
  writeln('rebuilt length ', Len(head):1);

  WriteThrough('closed by the block that owned it');
  ReadBack;

  { new over a non-empty owned pointer is a release point, so the first box's
    stream is closed and its text flushed before the second is made }
  new(head);
  head^.key := 0;
  WriteThrough('first');
  new(head);
  ReadBack;

  ThroughRecord('closed through a record field');
  ReadBack;
  ThroughArray('closed through an array element');
  ReadBack
end.
