{ AP 6.4.4.1's refusals. }
program pointer_typedisc_errors(output);

type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
     Plain(cap: integer) = array [1..cap] of integer;
     Two(K: type; V: type; cap: integer) = record
       keys: array [1..cap] of K;
       vals: array [1..cap] of V
     end;

var
  { too few type-names for the type discriminants there are }
  a: ^Vec;
  { too many }
  b: ^Vec(integer, char);
  { not a type }
  c: ^Vec(3);
  { a schema with no type discriminant takes none }
  d: ^Plain(integer);
  { two type discriminants and one name: the other stays unbound, and a
    pointer-type whose layout is half-decided is no type at all }
  e: ^Two(integer);
begin
end.
