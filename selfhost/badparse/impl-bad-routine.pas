{ AP 6.7 (ADR-0338): a routine inside an implementation-declaration is an
  ordinary procedure- or function-declaration, so its own parse can fail --
  and the loop that reads them has to notice, rather than going on to read
  the digest of a heading nobody has (ADR-0411). }
program p;
type Point = record x: integer end;
impl Point;
  function Len(protected var me: Point: integer;
  begin Len := me.x end;
end;
begin end.
