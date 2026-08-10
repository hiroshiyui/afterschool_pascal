program CodegenEdges(output);
{ Four things the rest of the suite left uncovered, each found by mutating the
  stage-1 code generator and noticing that nothing went red (ADR-0025).

  They are ordinary Pascal, and the C++ compiler is held to this output too --
  the point of a case like this is that it is the *same* golden file for both
  compilers, so neither can drift from it alone. }

const
  { A signed real constant: the sign is folded into the constant rather than
    into the literal, and a textual backend has to print it back. }
  freezing = -40.5;

type
  shape = (circle, square);
  { A real inside a variant: the shared storage must be aligned for it, and the
    record's size must include the tail that alignment adds. There is no fixed
    part on purpose -- with one, an even number of words before the variant
    would align it by accident and the record would come out the right size
    however the storage was laid out. }
  figure = record
    case kind: shape of
      circle: (radius: real);
      square: (side: integer)
  end;
  { Two fields and seven bytes of padding after them, so the size of the record
    is larger than the sum of its parts. }
  padded = record
    weight: real;
    grade: char
  end;
  row = array [1..2] of padded;

var
  a, b: figure;
  { Declared after b on purpose: it is the next slot in the activation record,
    so a whole-variable copy that is too long lands on it. }
  sentinel: integer;
  p, q: row;
  c: char;
  n: integer;

begin
  sentinel := 12345;
  a.kind := circle;
  a.radius := 2.5;
  b := a;
  writeln('variant copy: ', b.radius:3:1, ' ', sentinel:1);

  { An array of padded records: the element stride is the *padded* size, so a
    copy measured without the padding stops inside the last element. }
  p[1].weight := 1.5;  p[1].grade := 'A';
  p[2].weight := 2.5;  p[2].grade := 'B';
  q[1].weight := 0.0;  q[1].grade := '-';
  q[2].weight := 0.0;  q[2].grade := '-';
  q := p;
  writeln('padded copy: ', q[1].grade, q[2].grade, ' ', q[2].weight:3:1);

  { char is 0..255 (ADR-0018), so it orders as an unsigned ordinal. Every
    comparison below straddles 127, which is the only place it shows. }
  if chr(200) > chr(100) then writeln('char order: ok')
  else writeln('char order: WRONG');
  n := 0;
  for c := chr(120) to chr(200) do
    n := n + ord(c);
  writeln('char loop: ', n:1);

  writeln('negative real constant: ', freezing:6:1)
end.
