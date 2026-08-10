{ A goto to a label in an *enclosing* block (ISO 7185 6.8.2.4). It abandons
  every activation between here and the target, which is what makes it a
  different thing from the local goto of tests/goto.pas rather than a longer
  one -- the stack is cut back, and the abandoned blocks' files are closed.

  6.8.1 allows it only to a label at the top level of the enclosing block's
  statement part: the only place an activation that is still alive can be
  re-entered. Everything else about where a goto may land is the same prefix
  test the local form uses. }
program GotoNonLocal(output);
label 1;
var n: integer;

{ --- straight out, through two intervening blocks ---------------------- }
procedure Level1;
label 2;
  procedure Level2;
    procedure Level3;
    begin
      writeln('  level 3 jumps');
      goto 2
    end;
  begin
    writeln(' level 2');
    Level3;
    writeln(' level 2 is not resumed')
  end;
begin
  writeln('level 1');
  Level2;
  writeln('level 1 is not resumed');
2:
  writeln('level 1 landed')
end;

{ --- out of a *recursive* procedure. The target is the activation the
      jumping procedure was declared in -- the one it was called from -- and
      not the outermost one, which is the same rule every access to an
      enclosing frame follows. Only the innermost `returned into` is missing
      from the output, so the jump left exactly one activation early. --- }
procedure Rec(depth: integer);
label 3;
  procedure Bail;
  begin
    writeln('  bail called at depth ', depth:1);
    goto 3
  end;
begin
  if depth < 3 then Rec(depth + 1) else Bail;
  writeln('  returned into depth ', depth:1);
3:
  writeln('  leaving depth ', depth:1)
end;

{ --- and out of an activation that is *not* on the jumping procedure's
      static chain. `Jump` is passed to `Call` as a procedural parameter
      (ADR-0030) and invoked from there, so the frames abandoned are Call's
      and Jump's -- and Call's is reached from nothing Jump can see. This is
      the case that decides whether the abandoned frames are found by walking
      the static chain, which would miss it, or dynamically. --- }
procedure Call(procedure p);
begin
  writeln('  inside Call');
  p;
  writeln('  Call is not resumed')
end;

procedure Deep(k: integer);
label 5;
  procedure Jump;
  begin
    writeln('  jumping out of Deep(', k:1, ')');
    goto 5
  end;
begin
  if k > 1 then Deep(k - 1) else Call(Jump);
  writeln('  past the call in Deep(', k:1, ')');
5:
  writeln('  leaving Deep(', k:1, ')')
end;

{ --- two nested procedures jumping into the program's own block, at the same
      label. One label, two gotos: the target block dispatches on the label
      rather than on the goto, so it learns of this one twice and must carry
      it once. --- }
procedure First;
begin
  writeln('  First jumps into the program block');
  goto 1
end;

procedure Second;
begin
  writeln('  Second jumps to the same label');
  goto 1
end;

begin
  Level1;
  Rec(1);
  Deep(3);
  n := 0;
1:
  n := n + 1;
  writeln('program landed, n = ', n:1);
  if n = 1 then First;
  if n = 2 then Second;
  writeln('program done')
end.
