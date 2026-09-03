{ What AP 6.4.16 and AP 6.9.3.12-13 refuse, and share-nothing is nearly all
  of it.

  ADR-0201 decided that nothing may be reachable from two tasks at once, and
  the enforcement is a rule about **formal parameters** rather than a checker
  over a body: a task can only reach what it was handed, because Pascal has no
  address-of and `new` is the only producer of a pointer. So every refusal
  below but the last two is at a task's heading.

  Sema accumulates, so every one of these is reported in a single run. }
program concurrency_errors(output);

type
  Ints = channel [8] of integer;
  Node = record v: integer end;
  Ptr = ^Node;
  Owner = owned ^Node;
  Stream = handle external 'fclose';
  Holder = record p: Ptr end;
  { A channel carries a *value*, so what it carries is asked the same
    question a task's parameter is. }
  BadChan = channel [4] of Ptr;
  Zero = channel [0] of integer;

var
  c: Ints;
  n: integer;
  t: text;
  q: Ptr;
  h: Stream;

{ A var parameter is the escaping alias this language has never had, arriving
  with no model to govern it -- ADR-0201's rejected `cobegin` in one
  parameter. }
task BadVar(var n: integer);
begin n := 1 end;

{ A pointer is a reference to something the spawning activation owns, and a
  record holding one is no better: the question is asked of the whole type. }
task BadPointer(p: Ptr);
begin p^.v := 1 end;

task BadHolder(h: Holder);
begin h.p^.v := 1 end;

{ An owned pointer and a file have no copy at all, so they are refused twice
  over -- and the message a task gives is the one about crossing rather than
  the one about copying, because that is the question being asked here. }
task BadOwned(o: Owner);
begin end;

task BadFile(f: text);
begin end;

{ A handle that is not a channel is admitted and **moved** in (AP 6.7.8.1,
  ADR-0302), so nothing is refused at this heading. What is refused is the
  actual: it must be written `take`, because a copy would leave two owners. }
task GoodHandle(s: Stream);
begin end;

{ A procedural parameter would carry the activation it runs under, which is
  another task's -- so it is refused for the reason ADR-0201's finding 4 gives
  for the boundary itself. }
task BadProc(procedure f);
begin f end;

{ A task's block is this program's, so it cannot be a foreign routine. }
task BadExternal(k: integer); external 'nothing';

{ AP 6.7.8.2: the formals rule is not the whole rule. Pascal's scope rules let
  a block name a variable of an enclosing one, and a program's variables
  enclose every block in it -- so two activations of this task incrementing one
  global is a race a rule about parameters cannot see. }
task BadShared(c: Ints);
begin n := n + 1; send(c, n) end;

{ What a task may take. }
task Good(c: Ints; k: integer);
begin send(c, k) end;

procedure NotATask(k: integer);
begin end;

begin
  { Only a task may be spawned. }
  spawn NotATask(1);

  { And a task may be started only by a spawn-statement. }
  Good(c, 1);

  { A channel carries a value, so it cannot carry a pointer. }
  send(c, q);

  { `send` and `receive` take a channel. }
  send(n, 1);
  if receive(t, n) then n := 0;

  { `receive` writes what it received, so its second argument is a variable
    and its type is the channel's. }
  if receive(c, 1) then n := 0;
  if receive(c, t) then n := 0;

  { `receive` writes its second argument, so §6.9.4's threats apply to it as
    they do to `read`'s. }
  for n := 1 to 2 do
    if receive(c, n) then n := n;

  { AP 6.7.8.1 (ADR-0302): a handle crosses into a task by a move and the
    spelling is required, so a plain variable is refused and so is a `take` of
    something that is not the formal's type. }
  spawn GoodHandle(h);
  spawn GoodHandle(take(n));

  { A deferred statement runs when the sequence it stands in is completed,
    which is after the join -- so a task spawned there would be joined by
    nothing. }
  defer spawn Good(c, 1);

  writeln(n)
end.
