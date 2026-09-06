{ The dialect's surface, for the server rather than for the compiler.

  `lsp/sessions/` had no source carrying anything added after the text model,
  so `outline` and `diagnostics` were only ever asked about constructs the
  language had in version 2. A trait is what found that: two node kinds in a
  block's declaration list, read through the procedure arm, and
  `--dump-symbols` stopped the compiler on every source with one (ADR-0349).

  Everything here is *declared* and little is executed: what the two tools
  answer is a question about declarations, so this is a list of them. }
program dialect(output);

type
  Point = record x, y: integer end;
  Digit = 1..9;
  Name  = string(16);
  Owner = owned ^Point;
  Maybe = ?integer;
  Vec(n: integer) = array [1..n] of integer;
  IntChan = channel [4] of integer;

trait Sortable;
  function Before(p: Self; q: Self): boolean;
end;

impl Sortable for Point;
  function Before;
  begin Before := p.x < q.x end;
end;

impl Sortable for integer;
  function Before;
  begin Before := p < q end;
end;

var
  chan: IntChan;
  who:  Name;
  opt:  Maybe;
  own:  Owner;

task Worker(c: IntChan; rounds: integer);
var k, got: integer;
begin
  for k := 1 to rounds do
    select
      receive(c, got): ;
      after 100: ;
    end
end;

function Bigger(T: Sortable type; a, b: T): T;
begin
  if Before(a, b) then Bigger := b else Bigger := a
end;

procedure Sum(protected var xs: array of char; var total: integer);
var k: integer;
begin
  total := 0;
  for k := 1 to length(xs) do total := total + ord(xs[k])
end;

var t: task; i, j: integer;
begin
  new(own);
  own^.x := 1;
  who := 'outline';
  opt := 3;
  i := 4; j := 7;
  writeln(Bigger(i, j):1, ' ', who, ' ', opt^:1);
  spawn t := Worker(chan, 1);
  send(chan, 1);
  wait(t)
end.
