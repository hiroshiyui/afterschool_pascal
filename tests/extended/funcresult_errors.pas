{ What ISO/IEC 10206:1991 §6.7.2 refuses. Sema accumulates, so one run reports
  all of them.

  The two rules about writing the result are *exclusive*, which is why one flag
  answers both: with a result-variable-specification the block "shall contain
  no assignment-statement" to the function-identifier, and without one it shall
  contain at least one. And each has a second half asking that the result be
  written, in the word its own form uses: *assigns* for a function identifier
  and 6.9.4's weaker *threatens* for a result variable. }
program FuncResultErrors(output);
type
  holder  = record f: text; n: integer end;
  btext   = bindable text;
  bpoint  = bindable record x: integer end;
  point   = record x, y: integer end;

var p: point;

{ §6.7.2: a result may not be a file, nor contain one. `containsFile` is
  precisely the standard's "having any component whose type-denoter is not
  permissible as a component-type of a file-type". }
function afile: text;
begin end;

function holds: holder;
begin end;

{ ...nor be bindable: binding names something outside the program, and a value
  with no name cannot be pointed at anything. }
function bound: btext;
begin end;

function boundrec: bpoint;
begin end;

{ With a result variable the function identifier is not the way to write the
  result. }
function named(a: integer) = r: point;
begin r.x := a; named := p end;

{ ...and without one, something has to be. }
function silent: point;
begin end;

{ With one, something has to *threaten* it, which is the weaker word (6.9.4)
  and the other half of the same sentence. `mute` threatens nothing at all and
  is reported; `spoken` assigns nothing either and is **not**, because 6.9.4 b)
  makes an actual var parameter a threat -- which is the whole difference
  between the two words, and the reason this needs a flag of its own rather
  than the assignment one (ADR-0134). }
function mute = q: point;
begin end;

procedure fill(var v: point);
begin v.x := 1; v.y := 2 end;

function spoken = q: point;
begin fill(q) end;

{ A function whose body assigns a *sibling* function's result never assigns its
  own. This is the shape the never-assigns check was written for, and it found
  one in selfhost/compiler.pas the day it landed.

  Since ADR-0094 the sibling assignment is itself refused: §6.8.2.2 requires
  the function-block of the assignment's function-identifier to *contain* the
  assignment, and `other`'s block does not contain `silent`'s. Both messages
  are here, and they are two rules rather than one -- the second would still
  fire if the body assigned nothing at all. }
function other: integer;
begin silent := p end;

begin
  writeln(other:1)
end.
