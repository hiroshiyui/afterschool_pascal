{ AP 6.7.5.9: `exit` terminates the activation of the block it stands in, and
  `exit(e)` first assigns e to that block's function result (ADR-0177).

  Every claim here is *observed*: what a block leaves behind is read back
  rather than asserted. The file case reopens the file, the defer cases print
  from the armed statement, and the two result spellings are printed by the
  caller, which is the only place a result can be seen at all.

  `exit` in the main-program-block is the one exit not tested here, because it
  ends the program: tests/dialect/exit_module.pas is that, where a module's
  finalization is what proves it was the ordinary end and not a halt. }
program exit(output, fresh);

type
  Reason = (tooLong, notDigits);
  Number = integer ! Reason;

var
  fresh: bindable text;
  base: string(255);
  t: bindable text;
  bt: BindingType;
  line: string(120);
  i: integer;

procedure show(what: string);
begin
  bt := binding(t);
  bt.name := base;
  bind(t, bt);
  reset(t);
  write(what, ':');
  if eof(t) then write(' [empty]');
  while not eof(t) do begin
    readln(t, line);
    write(' [', line, ']')
  end;
  writeln;
  unbind(t)
end;

{ An early return with nothing to hand back: the guard that every procedure
  otherwise writes as an `if` around its whole body. }
procedure classify(n: integer);
begin
  if n < 0 then begin
    writeln('classify ', n:1, ': negative');
    exit
  end;
  if n = 0 then exit;
  writeln('classify ', n:1, ': positive')
end;

{ 6.7.2's unnamed result, assigned by `exit(e)` and by nothing else -- so this
  function also witnesses that an exit-statement discharges "at least one
  assignment to the function-identifier". }
function firstAbove(n: integer): integer;
var k: integer;
begin
  for k := 1 to 100 do
    if k * k > n then exit(k);
  firstAbove := 0
end;

{ 6.7.2's *other* half: a result-variable-specification asks for a statement
  threatening the result variable, and `exit(e)` names neither spelling. }
function tally(n: integer) = total: integer;
var k: integer;
begin
  total := 0;
  for k := 1 to n do begin
    total := total + k;
    if total > 6 then exit(total * 100)
  end
end;

{ AP 6.4.13's shorthand reached through the exit: the value decides the arm,
  so `exit(notDigits)` sets the cause and `exit(v)` the value, and neither
  names a field. }
function parse(s: string): Number;
var k, acc: integer;
begin
  if length(s) > 4 then exit(tooLong);
  acc := 0;
  for k := 1 to length(s) do begin
    if not (s[k] in ['0'..'9']) then exit(notDigits);
    acc := acc * 10 + (ord(s[k]) - ord('0'))
  end;
  exit(acc)
end;

procedure report(what: string; r: Number);
begin
  write(what, ': ');
  if r.ok then writeln('value ', r.val:1)
  else writeln('cause ', ord(r.cause):1)
end;

{ A statement armed in the sequence the exit leaves. Leaving a
  statement-sequence by an exit does not complete it, so 6.9.3.11.2 b) is what
  runs the armed statement -- at the termination of the activation, which is
  where the exit is going. }
procedure armed(n: integer);
var k: integer;
begin
  for k := 1 to n do begin
    defer writeln('  armed: iteration ', k:1, ' released');
    writeln('  armed: iteration ', k:1);
    if k = 2 then exit
  end;
  writeln('  armed: fell off the end')
end;

{ ...and the file the block owns, closed on the way out. The write is only in
  the file if the epilogue the exit branches to flushed it. }
procedure writes;
var f: bindable text;
    fb: BindingType;
begin
  fb := binding(f);
  fb.name := base;
  bind(f, fb);
  rewrite(f);
  defer writeln('  writes: released');
  writeln(f, 'written before the exit');
  exit;
  writeln(f, 'not reached')
end;

begin
  { the harness's own per-run path, so nothing here names a fixed file }
  base := binding(fresh).name;

  classify(-2);
  classify(0);
  classify(5);

  writeln('firstAbove(10) = ', firstAbove(10):1);
  writeln('firstAbove(30) = ', firstAbove(30):1);

  writeln('tally(2) = ', tally(2):1);
  writeln('tally(9) = ', tally(9):1);

  report('123', parse('123'));
  report('12x', parse('12x'));
  report('123456', parse('123456'));

  writeln('armed(1):');
  armed(1);
  writeln('armed(4):');
  armed(4);

  writeln('writes:');
  writes;
  show('  the file');

  { an exit inside a loop of the main-program-block leaves the program, and
    what follows it is never reached }
  for i := 1 to 3 do begin
    writeln('main: iteration ', i:1);
    if i = 2 then exit
  end;
  writeln('main: not reached')
end.
