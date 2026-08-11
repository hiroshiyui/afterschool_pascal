{ §6.4.7 NOTE 2: a tuple that leaves an index range empty produces no type, and
  §6.7.5.3 makes supplying such a tuple to `new` a dynamic-violation. The
  discriminant here reaches an array *inside* a record (ADR-0045), so what this
  pins is that the walk that makes the check descends into the record's tail
  exactly as it descends into an array's component. }
program TrapSchemaRecord(output);
type buffer(cap: integer) = record
       len: integer;
       data: packed array [1..cap] of char
     end;
     bp = ^buffer;

var p: bp;
    n: integer;

begin
  n := 4;
  new(p, n);
  p^.len := 0;
  writeln('made ', p^.cap:1);
  dispose(p);

  { Written as `new(p, 0)` this would be refused where the type is produced;
    reaching it through a variable is what leaves the check to run time. }
  n := 0;
  new(p, n);
  writeln('unreachable ', p^.cap:1)
end.
