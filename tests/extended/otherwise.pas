{ ISO/IEC 10206:1991's `otherwise` part of a case statement, the first
  Extended Pascal feature (ADR-0033).

  ISO 7185 has no default arm at all: a selector matching no label is an error,
  and this compiler traps on it (ADR-0018). Extended Pascal gives that case
  something to do instead, so the two forms differ only in what the default arm
  of the same switch holds.

  This file is not a valid ISO 7185 program -- `otherwise` is an identifier in
  that language -- which is why it lives in tests/extended/. }
program OtherwisePart(output);
type
  colour = (red, green, blue);
var
  i: integer;
  c: colour;
  ch: char;

begin
  { the ordinary shape: some labels, and a default }
  for i := 1 to 5 do
    case i of
      1: writeln('one');
      2, 3: writeln('two or three');
      otherwise
        write('other: ');
        writeln(i:1)
    end;

  { a statement-sequence, not a single statement, so `begin`/`end` is not
    needed to put two statements after it }
  case 9 of
    1: writeln('no');
    otherwise
      write('a');
      write('b');
      writeln('c')
  end;

  { `otherwise` followed by nothing is an empty statement -- a legal way to
    say "and otherwise do nothing". This is the case that must *not* trap, and
    the reason the tree records that an otherwise-part is present rather than
    that it is non-empty. }
  case 9 of
    1: writeln('no');
    otherwise
  end;
  writeln('the empty otherwise fell through');

  { the selector is any ordinal type, exactly as in ISO 7185 }
  for c := red to blue do
    case c of
      red: writeln('red');
      otherwise writeln('not red')
    end;

  ch := 'q';
  case ch of
    'a', 'e', 'i', 'o', 'u': writeln('vowel');
    otherwise writeln('consonant')
  end;

  { a trailing `;` before `end` is an empty statement in the sequence, and the
    arms before an otherwise are unaffected by it being there }
  case 2 of
    1: writeln('no');
    2: writeln('the arm still wins over the otherwise');
    otherwise writeln('no');
  end
end.
