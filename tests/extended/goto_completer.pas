{ ISO/IEC 10206:1991 §6.9.3.5 spells the completer

    case-statement-completer = 'otherwise' statement-sequence

  and §6.9.1 is ISO 7185 §6.8.1 word for word: a label of a statement S may
  occur in a goto G only if a) S contains G, b) S is a statement of a
  statement-sequence containing G, or c) S is a statement of the block's
  statement-part.

  So the completer is the *third* statement-sequence in the language, after the
  compound-statement and the repeat-statement -- and it is the only one with no
  node of its own, its statements hanging off the case statement that carries
  it. A rule written against the node's kind therefore cannot see it: a label
  here read as if it sat at the case statement's own level, and a goto outside
  could enter it, which is DEV191's deviation with the destination moved.

  Both legal directions come first. b) reaches a label at the completer's top
  level from a goto the completer contains; c) reaches the block's own level
  from inside it. Only entering from outside is refused. }
program GotoCompleter(output);
label 1, 2, 3;
var x : integer;
begin
  x := 9;

  { §6.9.1 b): the goto and the label are both in the completer's sequence. }
  case x of
    1: writeln('one')
  otherwise
    if x > 0 then goto 1;
    writeln('skipped');
1:  writeln('b: reached')
  end;

  { §6.9.1 c): out of the completer to the block's own statement-part. }
  case x of
    1: writeln('one')
  otherwise
    goto 2
  end;
2:
  writeln('c: left');

  { §6.9.1: none of the three. The completer's sequence does not contain this
    goto, and the label is not a statement of the block's statement-part. }
  goto 3;
  case x of
    1: writeln('one')
  otherwise
3:  writeln('entered')
  end
end.
