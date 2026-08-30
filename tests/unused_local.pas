{ AP: a local variable declared and never named (ADR-0272).

  The first diagnostic in this compiler that is not an error, and the case
  that says so: the program compiles, runs, prints, and exits 0, and the
  compiler has something to say about it anyway. `unused_local.warn` holds
  what it said.

  Every shape the warning deliberately does *not* fire on is here too, so the
  golden is a statement about the exclusions as much as about the message --
  a case that only showed the message firing would leave every false positive
  free to arrive unnoticed. }
program unused_local(output);

var
  { A variable of the program's own block is at level 0 and is never warned
    about: a module's may be exported and used only by an importer, and a
    program's may be a program-parameter that 6.5.1 binds externally. }
  quiet: integer;

{ A parameter is never warned about: what formals a routine has is decided by
  its callers and by 6.11.1's heading, not by its body. `unwanted` is ignored
  on purpose. }
procedure Keeps(wanted, unwanted: integer);
var
  used: integer;
  { The one this case is about. }
  forgotten: integer;
begin
  used := wanted * 2;
  writeln('kept ', used:1)
end;

{ A variable named only by a *nested* block still counts as used: 6.2.2.9 has
  the nested bodies walked before the enclosing statement part, so by the time
  this block ends the use has been recorded. }
procedure Outer;
var
  reachedFromInside: integer;

  procedure Inner;
  begin
    reachedFromInside := reachedFromInside + 1
  end;

begin
  reachedFromInside := 0;
  Inner;
  writeln('inner ', reachedFromInside:1)
end;

{ A variable that is only ever *assigned* counts as used. NoteUse does not
  know whether an occurrence was a designator or an expression, and this case
  pins that reading so a later dead-store warning is written as a new thing
  rather than as a change of mind here. }
procedure OnlyWritten;
var sink: integer;
begin
  sink := 1;
  writeln('written')
end;

begin
  quiet := 0;
  Keeps(3, 4);
  Outer;
  OnlyWritten;
  writeln('done ', quiet:1)
end.
