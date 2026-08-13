{ §6.1.9's lexical alternatives, the half that is required.

  The clause has two sentences and they say different things. "All processors
  that have the required characters in their character set shall provide both
  the reference representations and the alternative representations, and the
  corresponding tokens or separators shall not be distinguished" is a *shall*.
  "Provision of the reference representations, and of the alternative token @,
  shall be implementation-defined" then carves out exactly two things: the
  reference tokens themselves, and `@`. So `(.` and `.)` are required of this
  compiler and `@` is not, which is why `@` is refused in `torture.pas` and
  these are accepted here. ISO/IEC 10206:1991 §6.1.11 is the same clause word
  for word.

  `doc/implementation-defined.md` had them the other way round, as an
  implementation-defined choice this compiler had made — which is not a choice
  the standard offers. It also listed a double quote among the tokens, which
  comes from reading an extraction of the PDF: the standard writes the pointer
  symbol as an up-arrow, and the arrow comes out of the text layer as a quote.

  "Shall not be distinguished" is the part with teeth, and it is what the
  fourth line below pins: a `[` may be closed by a `.)`. Nothing after the
  lexer is told which spelling arrived, so there is nothing that *could*
  distinguish them — which is the implementation of the rule rather than a
  consequence of it.

  The tokenisation hazard is `(.1..3.)`. Maximal munch takes `..` before it
  takes `.)`, so that is five tokens and not four; and `3.` is not a real,
  because a real needs digits on both sides of its point (§6.1.5). Both were
  already true of `[1..3]` — what is new is only that the brackets are two
  characters each. }
program LexAlternatives(output);

type
  colour = (red, green, blue);

var
  a: array (.1..3.) of integer;
  m: array (.1..2, 1..2.) of integer;
  s: set of colour;
  r: record f: array (.1..2.) of integer end;
  i, j: integer;

begin
  for i := 1 to 3 do
    a(.i.) := i * i;
  writeln('array: ', a(.1.):1, a(.2.):1, a(.3.):1);

  { A reference bracket closed by an alternative one, and the other way
    round. §6.1.9 does not pair them; it says the tokens are the same. }
  a[2.) := 40;
  a(.3] := 90;
  writeln('mixed: ', a[1]:1, ' ', a(.2.):1, ' ', a[3]:1);

  for i := 1 to 2 do
    for j := 1 to 2 do
      m(.i, j.) := i * 10 + j;
  writeln('two dimensions: ', m(.1, 2.):1, ' ', m(.2, 1.):1);

  { A set constructor, where the brackets are the whole of the syntax. }
  s := (.red, blue.);
  writeln('set: ', red in s, green in s, blue in s);

  { And the characters still mean what they always did where they are not
    together: a parenthesised expression, a field selector, and the point that
    ends the program. }
  i := (1 + 2) * 3;
  r.f(.1.) := 7;
  r.f(.2.) := 8;
  writeln('parentheses: ', i:1, ' field: ', r.f(.1.):1, r.f(.2.):1)
end.
