{ Every warning is guarded by `warnOn`, which every --dump flag clears, and
  until this case nothing compared a dump of a program that would otherwise
  have been warned about: no source under tests/dumps/ warned at all, so
  dropping the guard from either warning left all 790 cases green.

  ADR-0272 learned the rule from --dump-dispatch -- a dump has a reader
  parsing a fixed grammar and an unannounced line is a parse error in
  something with no reason to expect one -- and then pinned it nowhere. This
  program is what pins it: it declares a local nothing names, writes a
  statement after an exit, and has a function that writes its result on one
  path and not another, so an unguarded warning would put three lines into the
  stream this case compares byte for byte. }
program warnings(output);

procedure both;
var used, forgotten: integer;
begin
  used := 1;
  writeln(used:1);
  exit;
  writeln('after the exit')
end;

function maybe(n: integer): integer;
begin
  if n > 0 then maybe := n
end;

begin
  both;
  writeln(maybe(1):1)
end.
