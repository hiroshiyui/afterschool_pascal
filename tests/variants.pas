program Variants(output);

{ Variant records — the shape the self-hosted compiler's own AST node will
  have: a tag saying which kind of node this is, and a different set of fields
  for each kind, all sharing one block of storage. }

type
  nodekind = (litnode, negnode, addnode, mulnode);

  { A tree of small integer expressions, held in an array because pointers
    are not in the language yet. A child is an index into that array. }
  node = record
    line: integer;
    case kind: nodekind of
      litnode:          (value: integer);
      negnode:          (operand: integer);
      addnode, mulnode: (lhs, rhs: integer)
  end;

  number = 1..2;

  { A tagless variant part: the type is given, but no field stores it. The
    program is then responsible for knowing which arm is live. }
  scalar = record
    case number of
      1: (asInteger: integer);
      2: (asReal: real)          { forces the storage to be 8-aligned }
  end;

var
  tree: array [1..7] of node;
  count: integer;
  s: scalar;
  copy: node;

function Make(k: nodekind; line: integer): integer;
begin
  count := count + 1;
  tree[count].kind := k;
  tree[count].line := line;
  Make := count
end;

function Eval(n: integer): integer;
begin
  { The tag says which fields are live, so the case and the variant part
    line up exactly. }
  with tree[n] do
    case kind of
      litnode: Eval := value;
      negnode: Eval := -Eval(operand);
      addnode: Eval := Eval(lhs) + Eval(rhs);
      mulnode: Eval := Eval(lhs) * Eval(rhs)
    end
end;

procedure Show(n: integer);
begin
  with tree[n] do
    case kind of
      litnode: write(value);
      negnode: begin write('-('); Show(operand); write(')') end;
      addnode: begin write('('); Show(lhs); write(' + '); Show(rhs);
                     write(')') end;
      mulnode: begin write('('); Show(lhs); write(' * '); Show(rhs);
                     write(')') end
    end
end;

var
  a, b, c, d, root: integer;

begin
  count := 0;

  { (3 + 4) * -(5) }
  a := Make(litnode, 10);  tree[a].value := 3;
  b := Make(litnode, 11);  tree[b].value := 4;
  c := Make(addnode, 12);  tree[c].lhs := a;  tree[c].rhs := b;
  d := Make(litnode, 13);  tree[d].value := 5;
  root := Make(negnode, 14);
  tree[root].operand := d;
  root := Make(mulnode, 15);
  tree[root].lhs := c;
  tree[root].rhs := 5;      { the negnode made just above }

  Show(root);
  write(' = ');
  writeln(Eval(root));

  { Every node is the same size whichever arm is live. }
  writeln('nodes built: ', count, '  root line: ', tree[root].line);

  { A whole record with a variant part copies all of it. }
  copy := tree[c];
  tree[c].lhs := 99;
  writeln('copied lhs: ', copy.lhs, '  original now: ', tree[c].lhs);

  { A tagless variant: the same storage read as either arm. }
  s.asReal := 2.5;
  writeln('as real: ', s.asReal:4:2);
  s.asInteger := 42;
  writeln('as integer: ', s.asInteger)
end.
