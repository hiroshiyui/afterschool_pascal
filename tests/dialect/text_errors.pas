{ What AP 6.4.15 refuses, and why each refusal is a rule rather than an
  omission (ADR-0189, ADR-0191).

  The theme is that a text is not a string. It shares a string's
  *representation* -- a length and that many bytes -- and none of its rules,
  because an element of a text is an extended grapheme cluster and an element
  of a string is a char. Every refusal below follows from that one sentence. }
program text_errors(input, output);

var
  t, u: utf8(32);
  s: string(32);
  c: char;
  i: integer;
  bad: utf8(0);

begin
  { 6.4.15.6: one operand normalised and the other not would be compared as
    bytes and answer *wrongly*, which is worse than refusing. }
  if t = s then writeln('no');

  { 6.4.15.9: three sequences live in one value -- bytes, scalar values and
    elements -- so an integer index would have to choose silently which, and
    an index over elements cannot be constant-time. }
  c := t[1];
  s := t[1..2];

  { The same clause, for the required functions that are about a position or a
    run of characters. `length` is the one that does follow, in elements. }
  i := index(t, 'x');
  s := substr(t, 1, 2);

  { 6.4.15.7 admits a text and a character-string and refuses a *string*, for
    6.4.15.6's reason: one side normalised and the other not would need a
    conversion, and `+` has nowhere to report that it failed. }
  t := t + s;

  { The same sentence from the other side: two texts and a literal are fine,
    so this line is here to show what the refusal above is not about. }
  t := t + u + 'ok';

  { 6.4.15.9's iteration: an element is a sequence of characters, so the
    control variable cannot be a char. }
  for c in t do writeln(c);

  { 6.4.15.11: reading yields bytes whose validity is not the program's to
    guarantee, so the conversion belongs where a failure can be reported. }
  read(t)
end.
