{ A program-component that is not the main-program-declaration.

  ISO/IEC 10206:1991 6.13 makes a program-block a *sequence* of
  program-components and asks that a processor "should be able to accept the
  program-components of the program-block separately". This is the half that
  is accepted separately: it declares a module and no program, so it can be
  translated on its own and can never be linked on its own, there being
  nothing to enter it through.

  What the other component gets to see is this module's *heading*, and nothing
  else. That is 6.11.1's own division -- the heading declares the exported
  constants, types, variables and procedure headings, and the block declares
  what the module keeps to itself -- so the interface is already written in
  Pascal and a separate translation needs no other artefact. That is what
  tests/extended/sepcomp.pas imports it through.

  `hidden` is why a *name* has to be what crosses. It is a variable of the
  module-block, so a translation holding only the heading does not know it
  exists: the two translations do not agree on how many variables this
  module's activation record has, nor therefore on its type. No index into
  that record could mean the same thing on both sides of the boundary, and
  the compiler puts an externally visible name on each slot another component
  may reach rather than trying to make one. }
module counter;

export counting = (tally, ticks, bump, clear);

{ 6.11.4.2: `output` is not a module's unless the module asks for it. Asking
  is what lets the finalization below write -- and the storage that name
  denotes belongs to the *other* component, so it is reached by a name too. }
import StandardOutput;

var
  tally: integer;
  ticks: integer;
procedure bump(n: integer);
procedure clear;
end;

var
  { Declared by the block and named by no interface, so no other component can
    reach it and no other translation knows it is here. }
  hidden: integer;

{ 6.11.1 makes a heading in a module-heading a `forward` under another name, so
  the block repeats the name alone. }
procedure bump;
begin
  hidden := hidden + 1;
  ticks := hidden;
  tally := tally + n
end;

procedure clear;
begin
  tally := 0;
  hidden := 0;
  ticks := 0
end;

{ 6.2.3.6: the commencement of a module that supplies the main-program-block
  precedes the program's own body, and its finalization follows the program's
  termination. Both are visible across the component boundary, and the golden
  output is what says so -- the 100 is written by nothing in the program. }
to begin do
  begin
    tally := 100;
    hidden := 0;
    ticks := 0
  end;

to end do
  writeln('counter finalizing, tally = ', tally:1);

end.
