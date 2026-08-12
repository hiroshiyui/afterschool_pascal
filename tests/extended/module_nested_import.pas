{ ISO/IEC 10206:1991 §6.2.1 puts an import-part at the head of *every* block,
  not only a program's or a module's — and §6.2.2.13 makes a module supply a
  block when the block "contains an applied occurrence of an interface-
  identifier" of it. A procedure's block is contained by the main-program-block,
  so importing inside a procedure makes that module a supplier of the program,
  and §6.2.3.6 must commence it.

  This program is here because none existed. The compiler recorded the supply
  against the *procedure* that wrote the import, where the activation set never
  looked, so the module was resolved, compiled, linked — and never commenced.
  The symptom is silence: no initialization-part output, and every imported
  variable read at its zero. A clean compile and a wrong answer, which is why
  no oracle caught it. }
module counter(output);
  export tally = (bump, total);
  var total: integer;
  procedure bump;
end;
  procedure bump;
  begin total := total + 1 end;
  { §6.11.1's initialization-part and finalization-part. Whether these run at
    all is the whole of what this program tests. }
  to begin do
    begin writeln('counter commences'); total := 100 end;
  to end do
    writeln('counter finalises with ', total:1);
end.

{ A second module, imported by a procedure of the *first* module's importer —
  §6.2.2.13's "or if A supplies a module that supplies B" reached the long way
  round, through a nested block rather than a module heading. }
module greeting(output);
  export salutation = (greet);
  procedure greet;
end;
  procedure greet;
  begin writeln('greeting commences elsewhere') end;
  to begin do
    writeln('greeting commences');
end.

program module_nested_import(output);

{ The import is here, inside a procedure — not at the top of the program. }
procedure count_twice;
import tally;
begin
  bump;
  bump;
  writeln('total is ', total:1)
end;

procedure inner;

  { And here, one block deeper still: a procedure inside a procedure. }
  procedure deepest;
  import salutation;
  begin
    greet
  end;

begin
  deepest
end;

begin
  count_twice;
  inner
end.
