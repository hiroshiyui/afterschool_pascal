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

  { 6.4.15.7 is concatenation and is not implemented yet (AP 5.6). What a
    program meets until it is, is the ordinary arithmetic refusal. }
  t := t + u;

  { 6.4.15.11: reading yields bytes whose validity is not the program's to
    guarantee, so the conversion belongs where a failure can be reported. }
  read(t)
end.
