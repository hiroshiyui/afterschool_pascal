{ 6.4.2.4: "The value denoted by the first subrange-bound shall not be greater
  than the value denoted by the second subrange-bound." Where both fold, Sema
  says so before the program runs; where one is a bound 6.2.3.8 b) evaluates at
  the block's commencement, this is where it can be said.

  It is checked at the *declaration* and not left to the first store, and the
  difference is a block that declares such a variable and never assigns to it:
  every store into an empty subrange traps anyway, so the store would report
  eventually or not at all. `dynbounds_empty.pas` is the same clause for an
  array, whose message this one is written beside. }
program DynBoundsSubrangeEmpty(output);
procedure p(m: integer);
var y: 2..m;
begin
  writeln('unreached ', y:1)
end;
begin
  writeln('before');
  p(1)
end.
