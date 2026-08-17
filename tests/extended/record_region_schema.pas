{ ISO/IEC 10206:1991 6.4.3.3's region reaches a schema-name too. §6.4.8's
  type-inquiry and §6.4.9's discriminants change nothing about it: the clause
  is about which region a spelling belongs to, and a schema-name written inside
  a record is subject to it exactly as a type-name is (ADR-0112).

  `ok` is here for the same reason it is in tests/record_region_field.pas --
  a schema-name that is nobody's field still produces a type. }
program RecordRegionSchema(output);
type
  vec(n: integer) = array [1..n] of integer;
  cell = vec(2);

  r = record
        a   : vec(3);
        vec : integer;
        ok  : cell
      end;
var
  x: r;
begin
  writeln('unreached ', x.vec)
end.
