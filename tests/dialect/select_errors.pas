{ AP 6.9.3.15: what a select-statement refuses (ADR-0313).

  Sema accumulates, so one file reports them all. The two that matter most are
  the ones a spelling rule makes possible: `send` and `receive` are required
  identifiers, so an arm naming one the *program* declared is refused rather
  than quietly meaning the required operation (ADR-0087); and `after` is
  reserved inside this construct and nowhere else, so an arm that is none of
  the three is named rather than read as a call. }
program select_errors(output);

type Ints = channel [4] of integer;
     Reals = channel [2] of real;

const two = 2;

var c: Ints; r: Reals; n: integer; x: real; ok: boolean; t: task;

{ A program may declare its own `receive`, and keeps it (6.1.3) -- so it is
  not a channel operation there. Declared in a block of its own, because a
  program-level one would shadow the required identifier in every select
  below and each of them would report this one mistake instead of its own. }
procedure Shadowed;
  function receive(a, b: integer): boolean;
  begin receive := a = b end;
begin
  select
    receive(c, n): writeln('no')
  end
end;

task Nothing(ch: Ints; k: integer);
begin send(ch, k) end;

procedure Nowhere(protected var pn: integer);
begin
  { A select arm writes through its second argument, so §6.9.4's threats
    apply to it as they do to `read`'s. }
  select
    receive(c, pn): writeln('no')
  end
end;

{ AP 6.4.12.3: an external function is where a handle is born, so this is the
  one way to write a channel that is not a variable -- selfhost/badsema's own
  answer to the same question for `send` and `receive`. }
function Made: Ints; external 'pasx_no_such_channel';

{ What a receive answers is written through, so §6.9.4 reaches the target as
  well as the value. }
procedure NoTarget(protected var pb: boolean);
begin
  select
    pb := receive(c, n): writeln('no')
  end
end;

begin
  { An arm is one of three things and this is none of them. }
  select
    listen(c, n): writeln('no')
  end;

  Shadowed;

  { A channel is what an arm waits on. }
  select
    send(n, 1): writeln('no')
  end;

  { An arm takes a channel and a value, and no other number of them. }
  select
    send(c): writeln('no');
    send(c, 1, 2): writeln('no')
  end;

  { An arm takes a channel *variable*, and a function-access is not one. }
  select
    receive(Made, n): writeln('no')
  end;

  { A receive writes into a variable, and a value is not one. }
  select
    receive(c, 1): writeln('no')
  end;

  { And so is what it answers. }
  select
    two := receive(c, n): writeln('no')
  end;

  { A receive writes the channel's own element type; a send takes anything
    assignable to it. }
  select
    send(r, 'text'): writeln('no');
    send(c, x): writeln('no')
  end;
  select
    receive(c, x): writeln('no')
  end;

  { What a receive answers is boolean, it is written to a variable, and only
    a receive answers anything at all. }
  select
    n := receive(c, n): writeln('no')
  end;
  select
    ok := send(c, 1): writeln('no')
  end;
  select
    x := receive(c, n): writeln('no')
  end;

  { A deadline is a whole number of milliseconds. }
  select
    receive(c, n): writeln('no');
    after x: writeln('no')
  end;

  { Two deadlines are one deadline, and `otherwise` is a deadline of zero. }
  select
    receive(c, n): writeln('no');
    after 10: writeln('no');
    after 20: writeln('no')
  end;
  select
    receive(c, n): writeln('no');
    after 10: writeln('no');
  otherwise writeln('no')
  end;

  { A select with nothing to wait for waits for nothing. }
  select
    after 10: writeln('no')
  end;

  { A task is not a channel: AP 6.9.3.14's wait is how one is waited for, and
    it is not selectable (ADR-0313). }
  select
    receive(t, n): writeln('no')
  end;

  { AP 6.9.3.11: a deferred statement runs after the join, so a task spawned
    in a select arm of one would be joined by nothing -- the arms are walked
    for that refusal exactly as a case-statement's are. }
  defer
    select
      receive(c, n): spawn Nothing(c, 1);
    otherwise writeln('no')
    end;

  Nowhere(n);
  NoTarget(ok);
  writeln(ok)
end.
