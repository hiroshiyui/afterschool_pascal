{ ADR-0118's trap: reading a field whose variant is not active.

  §6.5.3.3 makes this an error (Annex D.2) and §3.1 permits leaving an error
  undetected, which both conformance modes do -- so this same program under
  a Pascal without ADR-0118's rule prints a bit pattern instead of stopping,
  and that is
  conforming. The dialect detects it.

  The read is the *last* statement so that everything before it is known to
  have run: a trap that fired early would produce the same exit status and a
  shorter .out, and the golden is what tells those apart. }
program TrapVariantRead(output);
type Outcome = (ok, bad);
     Res = record
       case tag: Outcome of
         ok:  (num: integer);
         bad: (msg: string(32))
       end;
var r: Res;
begin
  r.num := 42;
  writeln('active arm reads back: ', r.num:1);
  r.msg := 'now the tag says bad';
  writeln('and so does this one:  ', r.msg);
  writeln('reading the inactive arm:');
  writeln(r.num:1);
  writeln('not reached')
end.
