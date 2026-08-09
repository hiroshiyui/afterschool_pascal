program Pointers(output);

{ Pointers, new/dispose, and the recursive types they exist for. A pointer's
  domain may name a type defined later in the same type part (ISO 7185 §6.4.4)
  — the only forward reference in the language, and the reason a record can
  contain a pointer to itself. }

type
  link = ^cell;        { cell is not declared until the next line }

  cell = record
    value: integer;
    next: link
  end;

  nodekind = (litnode, addnode, mulnode);

  tree = ^node;
  node = record
    case kind: nodekind of
      litnode:          (value: integer);
      addnode, mulnode: (lhs, rhs: tree)   { a variant holding pointers }
  end;

var
  head, p: link;
  i: integer;
  root: tree;

{ Build 3 -> 2 -> 1 -> nil by pushing onto the front. }
procedure Push(var list: link; v: integer);
var
  fresh: link;
begin
  new(fresh);
  fresh^.value := v;
  fresh^.next := list;
  list := fresh
end;

function Length(list: link): integer;
var
  n: integer;
begin
  n := 0;
  while list <> nil do
    begin
      n := n + 1;
      list := list^.next
    end;
  Length := n
end;

function Leaf(v: integer): tree;
var
  t: tree;
begin
  new(t);
  t^.kind := litnode;
  t^.value := v;
  Leaf := t
end;

function Branch(k: nodekind; l, r: tree): tree;
var
  t: tree;
begin
  new(t);
  t^.kind := k;
  t^.lhs := l;
  t^.rhs := r;
  Branch := t
end;

function Eval(t: tree): integer;
begin
  case t^.kind of
    litnode: Eval := t^.value;
    addnode: Eval := Eval(t^.lhs) + Eval(t^.rhs);
    mulnode: Eval := Eval(t^.lhs) * Eval(t^.rhs)
  end
end;

{ Free the whole tree, deepest first. }
procedure Release(t: tree);
begin
  if t <> nil then
    begin
      if t^.kind <> litnode then
        begin
          Release(t^.lhs);
          Release(t^.rhs)
        end;
      dispose(t)
    end
end;

begin
  head := nil;
  writeln('empty: ', Length(head), ' head = nil: ', head = nil);

  for i := 1 to 3 do
    Push(head, i);
  writeln('length: ', Length(head));

  write('list:');
  p := head;
  while p <> nil do
    begin
      write(p^.value:3);
      p := p^.next
    end;
  writeln;

  { A pointer assignment shares the variable; it does not copy it. }
  p := head;
  p^.value := 99;
  writeln('shared: ', head^.value, ' same cell: ', p = head);

  { Give the list back one cell at a time. }
  while head <> nil do
    begin
      p := head;
      head := head^.next;
      dispose(p)
    end;
  writeln('after dispose: ', Length(head));

  { (2 + 3) * 4, on the heap. }
  root := Branch(mulnode, Branch(addnode, Leaf(2), Leaf(3)), Leaf(4));
  writeln('tree = ', Eval(root));
  Release(root);
  writeln('released')
end.
