{ AP 6.8.9: `try(x)` is the value of x where x succeeded, and where it did not
  it assigns x's cause to the enclosing function's result and terminates that
  activation (ADR-0178).

  So every claim here is about a function that *did not run to its end*, and
  each is observed rather than asserted: the caller prints the result, the
  armed statements print from inside themselves, and the file case reopens the
  file and reads back what the epilogue flushed.

  The refusals are tests/dialect/try_errors.pas, and what the two conformance
  modes say about the name is tests/extended/try_refused.pas and
  tests/try_refused_iso.pas. }
program try(output, fresh);

type
  Reason = (tooLong, notDigits, notEven);
  Number = integer ! Reason;
  Word = string(20) ! Reason;
  Holder = record r: Number end;
  Pair = array [1..2] of Number;

var
  fresh: bindable text;
  base: string(255);
  h: Holder;
  pr: Pair;
  n: Number;
  t: bindable text;
  bt: BindingType;
  line: string(120);

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

procedure report(what: string; r: Number);
begin
  write(what, ': ');
  if r.ok then writeln('value ', r.val:1)
  else writeln('cause ', ord(r.cause):1)
end;

{ The producer. Nothing here is new -- it is ADR-0176's fallible-type used the
  way it has been used since it landed. }
function parse(s: string): Number;
var k, acc: integer;
begin
  if length(s) > 4 then parse := tooLong
  else begin
    acc := 0;
    for k := 1 to length(s) do begin
      if not (s[k] in ['0'..'9']) then begin
        parse := notDigits;
        exit
      end;
      acc := acc * 10 + (ord(s[k]) - ord('0'))
    end;
    parse := acc
  end
end;

function halve(n: integer): Number;
begin
  if odd(n) then halve := notEven else halve := n div 2
end;

{ The construct itself: a caller that only wants the value, and says once what
  to do about not getting it. AP 6.4.13's shorthand is what turns the cause
  into this function's own result, so `try` names no field either. }
function doubled(s: string): Number;
begin
  doubled := try(parse(s)) * 2
end;

{ Two tries in one expression, and the second is not reached when the first
  leaves -- which is what makes this a transfer of control and not a value. }
function sum(a, b: string): Number;
begin
  writeln('  sum: entered');
  sum := try(parse(a)) + try(parse(b));
  writeln('  sum: reached the end')
end;

{ A result-type that is not fallible at all. Nothing here requires one: the
  cause has to be assignment-compatible with the result and nothing more, so
  a function answering the cause-type takes it directly. }
function whyNot(s: string): Reason;
var n: integer;
begin
  n := try(parse(s));
  whyNot := notEven          { unreachable where the parse failed }
end;

function firstFour(s: string): Word;
begin
  if length(s) > 4 then firstFour := tooLong else firstFour := s
end;

{ ...and a value-type that is a string, which travels by address. The construct
  needed nothing for it: what a try yields is a field of a record. }
function shout(s: string): Word;
var w: string(20);
begin
  w := try(firstFour(s));
  shout := w + '!'
end;

{ A try inside a loop, in a function that recurses. The binding is a frame
  slot, so each activation has its own and each site has its own. }
function stepDown(n: integer): Number;
var k, acc: integer;
begin
  acc := 0;
  for k := 1 to 2 do
    acc := acc + try(halve(n + 2 * (k - 1)));
  if n > 4 then acc := acc + try(stepDown(n - 4));
  stepDown := acc
end;

{ 6.9.3.11.2 b): leaving by a try does not complete the statement-sequence, so
  what runs the armed statement is the termination of the activation -- which
  is where the try is going. }
function armed(n: integer): Number;
var k: integer;
begin
  defer writeln('  armed: block released');
  for k := 1 to 2 do begin
    defer writeln('  armed: iteration ', k:1, ' released');
    writeln('  armed: iteration ', k:1);
    armed := try(halve(n + 2 * (k - 1)))
  end;
  writeln('  armed: fell off the end')
end;

{ ...and the file the block owns, flushed and closed on the way out. The line
  is only in the file if the epilogue the try branches to did that. }
function writes(n: integer): Number;
var f: bindable text;
    fb: BindingType;
begin
  fb := binding(f);
  fb.name := base;
  bind(f, fb);
  rewrite(f);
  writeln(f, 'written before the try');
  writes := try(halve(n));
  writeln(f, 'written after the try')
end;

{ The operand need not be a call. These four are the designators a fallible
  value is usually reached through, and each is the address the binding takes
  rather than something evaluated -- so nothing here is copied. }
function viaVariable(r: Number): Number;
begin
  viaVariable := try(r) + 10
end;

function viaField(var h: Holder): Number;
begin
  viaField := try(h.r) + 20
end;

function viaIndex(var a: Pair; i: integer): Number;
begin
  viaIndex := try(a[i]) + 30
end;

function viaWith(var h: Holder): Number;
begin
  with h do viaWith := try(r) + 40
end;

{ A try leaves *one* activation, and it is the one the statement stands in. }
function outer(n: integer): Number;

  function inner(k: integer): Number;
  begin
    inner := try(halve(k)) + 1000
  end;

var r: Number;
begin
  r := inner(n);
  if r.ok then writeln('  outer: inner answered ', r.val:1)
  else writeln('  outer: inner failed with ', ord(r.cause):1);
  outer := 7
end;

begin
  base := binding(fresh).name;

  report('doubled 21', doubled('21'));
  report('doubled 2x', doubled('2x'));
  report('doubled 123456', doubled('123456'));

  report('sum 1+2', sum('1', '2'));
  report('sum 1+x', sum('1', 'x'));
  report('sum x+1', sum('x', '1'));

  writeln('whyNot 12 = ', ord(whyNot('12')):1);
  writeln('whyNot 1x = ', ord(whyNot('1x')):1);

  writeln('shout abc = ', shout('abc').val);
  writeln('shout abcdef cause = ', ord(shout('abcdef').cause):1);

  report('stepDown 8', stepDown(8));
  report('stepDown 9', stepDown(9));

  writeln('armed(4):');
  report('  armed 4', armed(4));
  writeln('armed(5):');
  report('  armed 5', armed(5));

  writeln('writes(4):');
  report('  writes 4', writes(4));
  show('  the file');
  writeln('writes(5):');
  report('  writes 5', writes(5));
  show('  the file');

  writeln('outer(4):');
  report('  outer 4', outer(4));
  writeln('outer(5):');
  report('  outer 5', outer(5));

  n.val := 1;
  report('viaVariable ok', viaVariable(n));
  n.cause := notEven;
  report('viaVariable no', viaVariable(n));
  h.r.val := 2;
  report('viaField ok', viaField(h));
  h.r.cause := notEven;
  report('viaField no', viaField(h));
  pr[1].val := 3;
  pr[2].cause := tooLong;
  report('viaIndex ok', viaIndex(pr, 1));
  report('viaIndex no', viaIndex(pr, 2));
  h.r.val := 4;
  report('viaWith ok', viaWith(h));
  h.r.cause := notDigits;
  report('viaWith no', viaWith(h))
end.
