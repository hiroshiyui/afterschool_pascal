{ ISO 7185 §6.4.1: a type-definition "shall associate an identifier with a
  type", and §6.2.2.10 puts the required type-identifiers' own defining-points
  in a region enclosing the program. So `char` names the char-type whatever
  else a program calls it, and `type foo = char` gives that one type a second
  name rather than taking its first.

  This compiler records a type's name *on the type*, which is right -- ADR-0017
  makes two structured types the same only when one identifier denotes both, so
  the name is a property of the type object. The simple types are shared
  singletons, though, so the first definition naming one used to claim it: after
  `type foo = char`, a variable declared `char` was *reported* as `foo`. Nothing
  was mis-compiled -- §6.4.1 makes them the same type and every rule agreed --
  but the message named something the program never wrote.

  The required types carry their own names from the outermost scope now, which
  is where §6.2.2.10 says their defining-points are. `text` had done so since it
  was created; the other five had not.

  Both diagnostics below name the type the variable was *declared* with. }
program TypenameAlias(output);
type
  foo = char;
  bar = integer;
var
  a : foo;
  b : char;
  m : bar;
  n : integer;
begin
  a := 'p';
  b := 'q';
  m := 1;
  n := 2;
  b := 1;
  n := 'z'
end.
