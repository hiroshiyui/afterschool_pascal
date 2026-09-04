{ AP 6.4.14.6: `take` is the dialect's move, and what it is for is that an
  owned pointer has no copy (ADR-0182).

  Without it a chain of owned nodes can be pushed at the far end and read and
  nothing else: `n := fresh` and `fresh^.next := n` are both copies, so
  push-front and pop-front were unwritable. Every operation was O(n) and there
  was no insertion or removal at the head at all -- which is what writing
  PasList over AP 6.4.14 found.

  The release is observed and not assumed, here as in owned.pas: a stream
  inside a node is buffered until fclose, so reading the file back says
  whether the node was disposed. }
program take(output, scratch);
type
  List = owned ^Node;
  Node = record key: integer; next: List end;
  Stream = handle external 'fclose';
  HeldPtr = owned ^Held;
  Held = record s: Stream; next: HeldPtr end;
var
  l, spare: List; i: integer;
  scratch: bindable text; bnd: BindingType; line: string(60);
function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(t: string; s: Stream): integer; external 'fputs';

procedure PushFront(var n: List; k: integer);
var fresh: List;
begin
  new(fresh);
  fresh^.key := k;
  fresh^.next := take(n);
  n := take(fresh)
end;

{ the whole of pop-front, in one statement: the source is the head's own
  field, so what the target held is disposed with its successor already
  emptied out of it, and the tail lands in n }
procedure PopFront(var n: List);
begin
  if n <> nil then n := take(n^.next)
end;

procedure Show(protected var n: List);
begin
  if n <> nil then begin write(' ', n^.key:1); Show(n^.next) end
end;

function Len(protected var n: List): integer;
begin
  if n = nil then Len := 0 else Len := 1 + Len(n^.next)
end;

procedure ReadBack;
begin
  bnd := binding(scratch);
  bnd.name := 'take_scratch.tmp';
  bind(scratch, bnd);
  reset(scratch);
  readln(scratch, line);
  writeln('read back: ', line);
  unbind(scratch)
end;

{ a node holding a stream, pushed and then popped: the pop must dispose it,
  which closes the stream, which flushes what was written through it }
procedure WriteAndDrop(text_: string);
var h, fresh: HeldPtr; k: integer;
begin
  new(fresh);
  fresh^.s := ExtFopen('take_scratch.tmp', 'w');
  k := ExtFputs(text_, fresh^.s);
  fresh^.next := take(h);
  h := take(fresh);
  { and now drop it, while the block goes on running }
  h := take(h^.next);
  ReadBack
end;

begin
  for i := 1 to 5 do PushFront(l, i * 11);
  write('pushed front:'); Show(l); writeln(' len ', Len(l):1);

  PopFront(l);
  write('one popped:'); Show(l); writeln(' len ', Len(l):1);

  { a move between two variables of the type, which is what take is }
  spare := take(l);
  write('moved to spare:'); Show(spare);
  writeln(' and l is empty: ', l = nil);

  { and back, over a variable that already holds something -- the assignment
    releases what the target held first, so nothing is abandoned }
  PushFront(l, 99);
  l := take(spare);
  write('moved back:'); Show(l); writeln(' len ', Len(l):1);

  { take of an empty variable is empty, and is not an error }
  PopFront(spare);
  writeln('empty spare: ', spare = nil);

  WriteAndDrop('closed by the pop that dropped it')
end.
