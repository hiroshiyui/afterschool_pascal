{ The same program as tests/extended/dynbounds.pas's first procedure, in the
  other language. ISO 7185 6.4.2.4 is

    subrange-type = constant '..' constant

  where ISO/IEC 10206:1991 6.4.2.4 writes `subrange-bound = expression`, so a
  parameter is a bound in one standard and not in the other. The offer of a
  dynamic bound is not made under --std=iso7185 at all, and the message is the
  one this position has always given (ADR-0113). }
program DynBoundsIso(output);
procedure p(m: integer);
var a: array [1..m] of integer;
begin
  a[1] := 1;
  writeln(a[1])
end;
begin p(3) end.
