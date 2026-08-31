{ A statement written after one that leaves is a remark and not an error
  (ADR-0272's second warning): the program compiles, runs, and prints exactly
  what it would have printed without the dead statements.

  Five statements leave -- 6.9.2.4's goto, 6.7.5.7's halt, AP 6.7.5.9's exit,
  AP 6.7.5.10's break and AP 6.7.5.11's continue -- each written here after
  a statement that has something after it, in the three places 6.9.2.1 puts a
  statement-sequence: a compound-statement, a repeat-statement and 6.9.3.5's
  case-statement-completer.

  Three more things the rule says are written here too, because not one of
  them is visible from a single dead statement.

  A **labelled** statement is reachable however it was arrived at, so a run of
  dead statements ends at one -- and a *second* run after that label has to be
  reported, which is what says the label restored something rather than the
  first report having merely used itself up.

  A run is reported **once**, since naming every statement in it is a
  paragraph about a single mistake.

  And the **empty** statement a doubled separator leaves behind is nobody's
  mistake and is never named. }
program unreachable(output);
label 2, 3;
var i, n: integer;

function leaves(k: integer): integer;
begin
  if k = 0 then begin
    exit(10);
    writeln('function: after an exit')
  end;
  leaves := k
end;

{ 6.9.2.1 lets a statement be empty and a doubled separator writes one, so
  `exit; ;` puts an empty statement exactly where a dead statement would
  stand. Reporting it would be a complaint about punctuation: the run is
  named at the first statement somebody actually wrote.

  The `;` before an `end` is *not* this shape -- the parser leaves nothing
  behind for it at all, which --dump-ast of this file shows -- so the doubled
  one is the only way to write the case. }
procedure trailing;
begin
  writeln('trailing: before the exit');
  exit; ;
  writeln('trailing: after the exit')
end;

procedure loops;
var j: integer;
begin
  for j := 1 to 4 do begin
    if j = 3 then begin
      break;
      writeln('loop: after a break')
    end;
    if j = 1 then begin
      continue;
      writeln('loop: after a continue');
      writeln('loop: and again, which is the same mistake')
    end;
    writeln('loop: body ', j:1)
  end
end;

procedure completer(k: integer);
label 1;
begin
  case k of
    1: writeln('case: one');
    otherwise
      writeln('case: otherwise');
      goto 1;
      writeln('case: after a goto');
1:
      writeln('case: reached by its label')
  end
end;

begin
  writeln('function: ', leaves(0):1);
  trailing;
  loops;
  completer(9);

  n := 0;
  repeat
    n := n + 1;
    writeln('repeat: ', n:1);
    goto 2;
    writeln('repeat: after a goto');
2:
    writeln('repeat: reached by its label')
  until n = 1;

  for i := 1 to 1 do ;
  goto 3;
  writeln('main: after a goto');
3:
  writeln('main: reached by its label');
  writeln('halting');
  halt;
  writeln('main: after a halt')
end.
