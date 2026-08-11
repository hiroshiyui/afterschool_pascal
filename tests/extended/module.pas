{ ISO/IEC 10206:1991 §6.11's modules, and §6.13's program-components.

  A module has two halves — a module-heading that says what it exports and a
  module-block that implements it — and §6.11.1 lets them be written as one
  component or as two. Both forms are here: `counter` is written whole, and
  `queue` is split into an `interface` component and an `implementation` one.

  The words `interface` and `implementation` are *directives* (§6.1.5, §6.1.6),
  which means they are ordinary identifiers in the one position each may
  occupy — exactly as `forward` is (§6.1.4). So modules reserve five
  word-symbols and not seven, and this program declares a variable called
  `interface` to prove it.

  §6.2.3.6 activates every module that supplies the main-program-block before
  the program's own body and finalises them afterwards, in the reverse order.
  Written order is a legal activation order and no sort produced it: §6.2.2.9
  already requires a module-heading to precede everything that imports its
  interface, so a supplier is always textually earlier than what it supplies. }
module counter(output);
  { §6.11.2: an export-part introduces an identifier that denotes an
    *interface*, and §6.2.2.2 makes that a region which "shall not be a part of
    the program text" — so exporting a name does not change how visible it is
    inside the module, and the only way in from outside is an import. }
  export counting = (bump, reset_to, protected total);

  const start = 10;
  { `total` is exported protected, so the program may read it and may not
    write to it. The module itself still can: §6.11.2 makes the protection a
    property of the *constituent*, not of the variable. }
  var total: integer;

  { §6.11.1's procedure-and-function-heading-part: the heading is written here
    and the body belongs to the module-block. That is the `forward` mechanism
    under another name, which is why the body below repeats the name alone and
    still sees the parameter `by`. }
  procedure bump(by: integer);
  procedure reset_to(n: integer);
end;
  procedure bump;
  begin total := total + by end;

  procedure reset_to;
  begin total := n end;

  { §6.11.1's two `to` parts. Each takes a single *statement*, so the `begin`
    a reader expects is part of the word-symbol rather than the start of a
    compound — which is why the initialization below needs a `begin ... end`
    of its own to hold two statements. }
  to begin do total := start;
  to end do writeln('counter ends at ', total:1);
end.

{ The heading alone. §6.11.1: "An interface-directive shall occur in a
  module-heading of a module-declaration if and only if a module-block does not
  occur in the module-declaration." }
module queue interface;
  export
    queueing = (item, put_one, take_one, count => waiting);
  { §6.11.3: `only` makes the import list exhaustive rather than a set of
    renamings, so `reset_to` and `total` do not arrive here. }
  import counting only (bump);

  type item = 1..99;
  var count: integer;
  procedure put_one(x: item);
  function take_one: item;
end.

{ ...and the block, as a separate program-component. §6.2.2.12 makes every
  defining-point of the heading a defining-point of the block as well, so
  `item`, `count` and `bump` are all in scope here without being written
  again. }
module queue implementation;
  const capacity = 8;
  var buf: array [1..capacity] of item;
      head, tail: integer;

  procedure put_one;
  begin
    buf[tail] := x;
    tail := tail mod capacity + 1;
    count := count + 1;
    { the imported procedure, called from another module's block }
    bump(x)
  end;

  function take_one;
  begin
    take_one := buf[head];
    head := head mod capacity + 1;
    count := count - 1
  end;

  to begin do begin head := 1; tail := 1; count := 0 end;
end.

program Modules(output);
{ §6.2.1 puts an import-part at the head of every block, not only a module's.
  §6.11.3's `qualified` says the imported names arrive *only* as `i.x` and
  never bare, which is what lets `queueing.count` coexist with a local one. }
import
  counting;
  queueing qualified;

var interface, implementation: integer;
    k: integer;
    it: queueing.item;

begin
  { §6.11.3 introduces the interface-identifier whether or not the import was
    qualified, so a name may always be written the long way. }
  writeln('start ', total:1, ' ', counting.total:1);

  reset_to(0);
  for k := 1 to 4 do
    queueing.put_one(k * 3);
  writeln('waiting ', queueing.waiting:1, ' total ', total:1);

  it := queueing.take_one;
  writeln('took ', it:1, ' then ', queueing.waiting:1);

  { `interface` and `implementation` are identifiers, not word-symbols. }
  interface := 1;
  implementation := 2;
  writeln('words ', interface:1, implementation:1)
end.
