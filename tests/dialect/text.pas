{ AP 6.4.15's text-type: what a program holds when it means the characters
  rather than the octets (ADR-0189, ADR-0191).

  Four properties this pins, and the second is the one the whole model exists
  for:

  - the capacity is in **bytes** and `length` counts **elements**, so the two
    are different numbers for the same value (6.4.15.8);
  - a value is normalised where it is constructed, so two spellings of one
    character are one value and `=` is byte equality *and* canonical
    equivalence at once (6.4.15.2, 6.4.15.6);
  - an element is an extended grapheme cluster, so a family emoji joined by
    zero-width joiners is one element and a Hangul syllable is one however it
    was written (6.4.15.3);
  - a field-width pads to a count of elements and not of bytes (6.4.15.10).

  The literals below are exact: `composed` holds U+00E9 and `decomposed` holds
  `e` followed by U+0301, which is why their source lengths differ and their
  values do not. }
program text(output);

type Name = utf8(64);
     { The field is `title` and not `name`: 6.4.3.3 makes a record type a
       region, so a field spelled like the type would shadow it inside this
       very denoter (ADR-0112). }
     Tagged = record title: Name; n: integer end;

var
  composed, decomposed, hangul, hangulJamo, family, flag: Name;
  { 6.4.8 makes one schema with one tuple one type however often it is
    written, so this is `Name` and not a second type alike it -- the intern
    table `string` has always used, reached by the same route. }
  again: utf8(64);
  bytes: string(64);
  opt: ?Name;
  rec: Tagged;

{ 6.4.15.1 gives `utf8` the same one discriminant `string` has and in the same
  position, so a schematic formal reads its capacity from the actual -- the
  descriptor path of ADR-0040, shared and not copied. }
procedure Report(label_: string; var t: utf8);
begin
  bytes := t;
  writeln(label_, ' elements ', length(t):2,
          '  bytes ', length(bytes):2,
          '  capacity ', t.capacity:3)
end;

begin
  composed := 'héllo';
  decomposed := 'héllo';
  hangul := '한';
  hangulJamo := '한';
  family := '👨‍👩‍👧';
  flag := '🇯🇵';

  Report('composed  ', composed);
  Report('decomposed', decomposed);
  Report('hangul    ', hangul);
  Report('hangul-jamo', hangulJamo);
  Report('family    ', family);
  Report('flag      ', flag);

  { 6.4.15.6 NOTE: both operands are in normal form, so comparing their bytes
    *is* comparing their characters. The two spellings above are one value. }
  writeln;
  writeln('composed = decomposed  ', composed = decomposed);
  writeln('hangul = jamo spelling ', hangul = hangulJamo);
  writeln('composed = literal     ', composed = 'héllo');
  writeln('composed < flag        ', composed < flag);
  writeln('composed <> hangul     ', composed <> hangul);
  writeln('composed <= composed   ', composed <= composed);
  writeln('flag > composed        ', flag > composed);
  writeln('flag >= flag           ', flag >= flag);

  { The same type, written a second time: 6.4.8's identity, and the assignment
    is between two values of one type rather than a conversion. }
  again := composed;
  writeln('again = composed       ', again = composed);

  { 6.4.15.10: the width is a count of elements. `family` is one element and
    eighteen bytes, so a width of 5 pads it with four spaces -- which a width
    counted in bytes could not have done. }
  writeln;
  writeln('|', family:5, '|');
  writeln('|', composed:8, '|');

  { A text nested in something else. Both of these reach the store through a
    different door than an assignment-statement does -- an optional writes its
    value half (ADR-0123) and a structured-value builds its component where the
    variable already is (ADR-0061) -- and 6.4.15.2's invariant has to be
    established at each. There is nothing special about a text here, which is
    the point: it is a value with a capacity, so it goes wherever one goes. }
  writeln;
  opt := 'hi';
  if opt <> nil then begin
    bytes := opt^;
    writeln('in an optional  = ', bytes, '  elements ', length(opt^):1)
  end;
  rec := Tagged[title: composed; n: 7];
  bytes := rec.title;
  writeln('in a record     = ', bytes, '  n ', rec.n:1);

  { The way back out: bytes from a text are well-formed by 6.4.15.2, so a
    variable-string takes them with nothing to check. }
  bytes := decomposed;
  writeln;
  writeln('round trip ', bytes)
end.
