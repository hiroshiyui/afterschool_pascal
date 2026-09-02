{ AP 6.4.7's type-valued discriminant, produced with an argument spelled like
  the discriminant itself (ADR-0297).

  `Box(T)` below names the program's own `T`, which is `char`. The production
  used to declare the discriminant `T` into the body's scope *before* reading
  the argument, so the argument found the discriminant -- a type that had no
  type yet -- and `item` was resolved over nil: `--dump-sema` printed
  `field item : ?` and the code generator stopped on a nil dereference. It
  was invisible for as long as nobody wrote the collision, and every generic
  whose type parameter shares the schema's spelling writes it, because
  `function ValueOr(T: type; res: Fallible(T); ...)` produces `Fallible(T)`
  with a `T` in scope. Only the first production of a tuple is affected: an
  interned one is found before any of this runs, which is why
  generic_fallible.pas never met it. }
program schema_typearg_shadow(output);

type
  T = char;
  Box(T: type) = record item: T end;
  CB = Box(T);
  { The same collision one level in: the argument is the discriminant of the
    enclosing production. }
  Pair(T: type) = record first: Box(T); second: T end;
  CP = Pair(T);

var
  b: CB;
  p: CP;

begin
  b.item := 'x';
  p.first.item := 'y';
  p.second := 'z';
  writeln(b.item, p.first.item, p.second)
end.
