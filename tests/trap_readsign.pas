{ §6.9.1 c): "It shall be an error if s is empty" — s being the sequence that
  must form a signed-integer. A sign is not one, so `- 5` offers `-` and then a
  space, and no prefix of that is a signed-integer.

  It is an *error* rather than a syntax rule, so §6.1 f) would permit leaving
  it undetected; this implementation detects it, which is why the message can
  be pinned at all. Its own file because a program that stops stops once. }
program TrapReadSign(input, output);
var i: integer;
begin
  writeln('before');
  read(i);
  writeln(i:1)
end.
