{ §6.4.7 requires an ordinal-type-*name*, so an anonymous type is refused by
  the parser rather than by Sema -- a discriminant's type has to be something
  a reader can see at a glance. }
program SchemaFormalType(output);
type v(n: 1..9) = array [1..n] of real;
begin end.
