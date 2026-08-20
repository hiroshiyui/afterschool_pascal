{ ADR-0143: a slice cannot be assigned, and until this was written the compiler
  silently wrote outside an array.

  AP 6.4.5 makes two slices compatible when their component types are the same,
  for parameter passing. `Assignable` is asked by the assignment statement as
  well, and a slice reached the end of that function, where the answer is
  `tb^.kind = fb^.kind` -- true for any two slices *whatever their component
  types*, since the kind is `tySlice` either way and nothing looked at `elem`.

  What made it worse than a wrong answer is what CodeGen then did. A slice
  formal is a var parameter, so `AddressOfSym` took the var-parameter branch
  and dereferenced the slot, yielding the address of the caller's array DATA
  rather than of the two-word descriptor. The assignment then copied
  sizeof(ptr, i32) bytes from one array's contents into the other's:

      var small: array [1..1] of integer;      -- four bytes
          big:   array [1..8] of integer;
      procedure q(var p: array of integer; var r: array of integer);
      begin p := r end;
      ...  q(small, big)

  wrote sixteen bytes over a four-byte array and its neighbours, exited 0, and
  did so at both -O0 and -O2.

  This is ADR-0058's sentence a third time -- a permission granted in a shared
  predicate leaks to every caller -- and the second time for this same
  permission. ADR-0139 wrote the refusal for the relational operators and
  stopped there; assignment is the other caller, and it was the one that could
  corrupt memory rather than emit invalid IR.

  The message is the slice's own rather than the general one, because the
  general one ends by advising a named type shared by both, and AP 6.7.3.9.2
  gives a slice type no name to declare: the reader would be sent after
  something that cannot exist.

  Found by a specification audit, which enumerated every clause of
  ISO/IEC 10206:1991 that says "compatible" and probed each against a slice.
  6.4.6 was one of two that reach one; 6.8.3.5 was the other, and it was
  already closed. }
program SliceAssign(output);
var
  a: array [1..8] of integer;
  b: array [1..8] of integer;
  c: array [1..8] of char;

{ two slice formals of the same component type: the shape that corrupted }
procedure Two(var p: array of integer; var r: array of integer);
begin
  p := r
end;

{ and of different component types, which the kind comparison also allowed }
procedure Mixed(var p: array of integer; var r: array of char);
begin
  p := r
end;

{ a whole array into a slice, and a slice into a whole array: neither is an
  assignment either, and each reaches the check from its own side }
procedure FromArray(var p: array of integer);
begin
  p := a
end;

procedure ToArray(var p: array of integer);
begin
  b := p
end;

begin
  Two(a, b);
  Mixed(a, c);
  FromArray(a);
  ToArray(a)
end.
