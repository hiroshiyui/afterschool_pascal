{ ISO/IEC 10206:1991 6.9.4 e): "S is a procedure-statement that specifies
  activation of the required procedure new, and V is the variable-access p".
  So `new(p)` threatens p -- which is 6.7.5.3 saying it another way, since that
  clause "shall attribute to p" the identifying-value of the created variable.

  6.7.2 requires a function-block to contain "at least one statement
  threatening" its result variable, and reads 6.9.4's list to decide. With e)
  missing from that list, a function that *allocates* its result rather than
  assigning to it was refused -- "never writes to its result variable" -- and
  there was no way to write a constructor at all: the result is a pointer, so
  `res := something` needs the something, which is what new is for.

  Extended Pascal only. ISO 7185 has no result-variable-specification: there a
  function assigns to its own identifier, and 6.6.2's requirement is syntactic
  containment of an assignment, which no `new` has ever satisfied or needed to. }
program new_threatens_result(output);

type
  { link before node: 6.4.4 lets a domain-type name a type not yet defined,
    and it has to here, because ADR-0017's name equivalence makes `^node`
    written inside the record a *different* type from link. }
  link = ^node;
  node = record
    value_: integer;
    next: link
  end;
  couple = record head, tail: link end;

{ The whole point: `new(res)` is the only statement that writes res. }
function cons(v: integer; rest: link) = res: link;
begin
  new(res);
  res^.value_ := v;
  res^.next := rest
end;

{ A result reached through a component counts too -- 6.9.4 h) makes a threat to
  a component a threat to the variable containing it. }
function pair(a, b: integer) = res: couple;
begin
  new(res.head);
  res.head^.value_ := a;
  res.head^.next := nil;
  new(res.tail);
  res.tail^.value_ := b;
  res.tail^.next := nil
end;

var
  list: link;
  p: link;
  two: couple;

begin
  list := cons(1, cons(2, cons(3, nil)));
  p := list;
  while p <> nil do begin
    write(p^.value_:1);
    p := p^.next
  end;
  writeln;
  two := pair(8, 9);
  writeln(two.head^.value_:1, two.tail^.value_:1)
end.
