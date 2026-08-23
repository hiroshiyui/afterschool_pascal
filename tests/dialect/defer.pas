{ AP 6.9.3.11: a defer-statement arms a statement, and what it arms runs when
  the statement-sequence it stands in is completed -- or when the activation
  terminates, if control leaves the sequence some other way (ADR-0175).

  Every release below is *observed* rather than asserted: the file cases read
  the file back, and the ordering cases print. The names are built from
  `fresh`, the harness's own per-run path. `halt` is the one exit not tested
  here, because it ends the program: tests/dialect/defer_halt.pas is that. }
program defer(output, fresh);

label 9;

type Stream = handle external 'fclose';

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(s: string; f: Stream): integer; external 'fputs';

var
  fresh: bindable text;
  base: string(255);
  i, k: integer;
  p: ^integer;
  t: bindable text;
  bt: BindingType;
  line: string(120);

procedure show(path: string; what: string);
begin
  bt := binding(t);
  bt.name := path;
  bind(t, bt);
  if binding(t).bound then begin
    reset(t);
    write(what, ':');
    if eof(t) then write(' [empty]');
    while not eof(t) do begin
      readln(t, line);
      write(' [', line, ']')
    end;
    writeln
  end
  else
    writeln(what, ': nothing there');
  unbind(t)
end;

{ the reverse of the order they are written, and after the statements that
  follow them }
procedure order;
begin
  writeln('  first');
  defer writeln('  armed first');
  defer writeln('  armed second');
  writeln('  last')
end;

{ a compound is a statement-sequence, so a defer in a loop body runs once per
  iteration -- with the values that iteration had }
procedure perIteration;
var n: integer;
begin
  for n := 1 to 3 do begin
    defer writeln('  end of iteration ', n:1);
    writeln('  iteration ', n:1)
  end
end;

{ only what was armed runs: a defer-statement not executed arms nothing }
procedure conditional(c: boolean);
begin
  if c then defer writeln('  the conditional one ran');
  writeln('  conditional(', c, ') body')
end;

{ an inner sequence completes before the outer one }
procedure nested;
begin
  defer writeln('  outer');
  begin
    defer writeln('  inner');
    writeln('  inner body')
  end;
  writeln('  outer body')
end;

{ a deferred statement may write to a file the block owns: it runs before the
  block's files are closed, which is what makes `defer` usable for the thing
  it is for }
procedure writes(path: string);
var f: bindable text; fb: BindingType; h: Stream;
begin
  fb := binding(f);
  fb.name := path;
  bind(f, fb);
  rewrite(f);
  defer writeln(f, 'deferred');
  writeln(f, 'body');
  { and lend a handle the block owns, for the same reason }
  h := ExtFopen(path + '.h', 'w');
  defer k := ExtFputs('lent by a deferred statement', h)
end;

{ a non-local goto abandons two activations, and each runs what it armed,
  innermost first (ADR-0032's obligation, discharged the same way) }
procedure inner;
begin
  defer writeln('  inner armed');
  writeln('  inner body');
  goto 9
end;

procedure jumper;
begin
  defer writeln('  jumper armed');
  inner;
  writeln('  not reached')
end;

{ a *local* goto leaves the sequence without completing it, so what it armed
  waits for the activation to terminate -- late, and not lost }
procedure localGoto;
label 1;
var n, seen: integer;
begin
  seen := 0;
  for n := 1 to 2 do begin
    { `seen` and not `n`: what a control-variable holds after its
      for-statement is left is 6.9.3.9's question and not this case's }
    seen := n;
    defer writeln('  loop armed at ', seen:1);
    if n = 1 then goto 1
  end;
1:
  writeln('  after the local goto')
end;

{ the statement is read when it runs, not when it is armed }
procedure readsLate;
var n: integer;
begin
  n := 1;
  defer writeln('  n at the end is ', n:1);
  n := 99
end;

{ a deferred statement runs before the function's result is taken, so it may
  still adjust it. Reading the function identifier would be a recursive call
  (6.7.2), which is what the result variable is for. }
function counted = r: integer;
begin
  r := 1;
  defer r := r + 100
end;

{ what defer is for, in the shape a program actually writes }
procedure heap;
begin
  new(p);
  p^ := 42;
  defer dispose(p);
  writeln('  the heap variable holds ', p^:1)
end;

begin
  base := binding(fresh).name;

  writeln('order:');            order;
  writeln('per iteration:');    perIteration;
  writeln('conditional:');      conditional(true); conditional(false);
  writeln('nested:');           nested;
  writeln('reads late:');       readsLate;
  writeln('function result: ', counted:1);
  writeln('heap:');             heap;

  writeln('files:');
  writes(base + '.defer');
  show(base + '.defer', '  the text file');
  show(base + '.defer.h', '  the handle''s file');

  writeln('goto:');
  jumper;
9:
  writeln('  after the jump');

  writeln('local goto:');       localGoto;

  { the program's own block is a statement-sequence like any other }
  defer writeln('the program''s own, last of all');
  for i := 1 to 2 do writeln('main ', i:1)
end.
