{ AP 6.4.15.7 and 6.4.15.9: joining two texts, and walking one element at a
  time (ADR-0189, ADR-0192).

  The two are one case because they are inverses, and the last line is what
  makes it a test rather than a demonstration: **the elements joined back
  together are the original**. That property is what says a grapheme cluster
  boundary is also a boundary of normal form -- if it were not, cutting a text
  into elements would produce pieces that are not in normal form, and rejoining
  them would give something that compares unequal to what was cut.

  The first two lines are the reason 6.4.15.7 has to say "the concatenation of
  the scalar sequences" and not "of the bytes": `b` begins with a combining
  acute, so joining it to `a` composes across the join and the result is one
  byte shorter than the two operands together. }
program text_join(output);

var a, b, joined, walked, g: utf8(64);
    s: string(64);
    n: integer;

begin
  a := 'he';
  b := '́llo';
  s := a; write('a          bytes ', length(s):2);
  s := b; writeln('   b bytes ', length(s):2);

  joined := a + b;
  s := joined;
  writeln('a + b      bytes ', length(s):2, '   elements ', length(joined):2);
  writeln('joined     = ', joined);
  { Byte concatenation would give seven bytes and a value unequal to this. }
  writeln('composed?    ', joined = 'héllo');

  writeln('three      = ', a + b + '!');
  writeln('literal    = ', 'x' + a);

  { 6.4.15.9. The operand is evaluated once, before the first iteration, and
    it is a concatenation here on purpose: the storage it took has to outlive
    the loop that walks it. }
  n := 0;
  walked := '';
  for g in a + b + ' 👨‍👩‍👧' do
    begin
      n := n + 1;
      s := g;
      writeln('  element ', n:2, '  bytes ', length(s):2, '  = ', g);
      walked := walked + g
    end;
  writeln('elements   = ', n:1);
  writeln('rejoined   = ', walked);
  writeln('round trip   ', walked = a + b + ' 👨‍👩‍👧')
end.
