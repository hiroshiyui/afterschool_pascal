program TrapNil(output);

{ ISO 7185 §6.5.4 makes it an error to dereference nil. Note what this test
  does *not* claim: a pointer to storage already given back by dispose cannot
  be detected, and nothing here pretends otherwise. Setting a disposed pointer
  to nil is what turns the common case of that mistake into this one. }

type
  cell = record
    value: integer;
    next: ^cell
  end;

var
  p: ^cell;

begin
  new(p);
  p^.value := 7;
  p^.next := nil;
  writeln('p^.value = ', p^.value);

  writeln('walking off the end of the list');
  writeln('next value = ', p^.next^.value)
end.
