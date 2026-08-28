{ ISO/IEC 10206:1991 §6.9.3.5 and §6.4.3.4 both write the completer as

      [ [ ';' ] case-statement-completer ]
      [ [ ';' ] variant-part-completer ]

  — the inner bracket makes the separator before `otherwise` optional, and
  §6.9.3.5's own Example 1 omits it, ending an arm with `end` and writing
  `otherwise` on the next line. Both forms were refused: the parser broke out
  of the arm loop whenever a `;` did not follow, and then wanted `end`.

  The corpus had only ever written the `;`, in both constructs, which is why
  nothing caught it. Under ISO 7185 `otherwise` is an ordinary identifier and
  never this token at all, which a companion case pinned until ADR-0232: with
  one language every word-symbol §6.1.2 adds is reserved for every source, so
  there is no longer a reading in which this token is a name. }
program otherwise_nosemi(output);

type
  colour = (red, green, blue);
  { §6.4.3.4's completer with no separator before it. }
  shape = record
            n: integer;
            case tag: colour of
              red:   (r: integer);
              green: (g: integer)
            otherwise (other: char)
          end;

var
  s: shape;
  i, j: integer;

begin
  { §6.9.3.5's own Example 1, transcribed — a `begin ... end` arm followed
    directly by `otherwise`, with no semicolon between them. }
  i := 7;
  j := 0;
  case j of
    -maxint..-1, 1..maxint: i := i div j;
    0 : begin
          writeln('divide by zero!');
          i := 0
        end
    otherwise i := 1; writeln('unreachable')
  end;
  writeln('case  ', i:1);

  { The same, with the separator present — both spellings mean one thing. }
  case i of
    9: writeln('no');
    otherwise writeln('semi  present')
  end;

  { And the completer-only form, which has no arm to be separated from. }
  case i of
    otherwise writeln('completer only')
  end;

  s.tag := blue;
  s.other := 'z';
  s.n := 4;
  writeln('variant ', s.n:1, ' ', ord(s.tag):1, ' ', s.other)
end.
