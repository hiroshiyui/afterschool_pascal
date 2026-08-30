{ AP 6.4.12.6 (ADR-0255): a *factory* -- a function of this program answering a
  handle, which until this clause only an `external` one could.

  What it is for is in `lib/`, where every producer of a stream, a directory or
  a pipe makes the caller declare a variable and pass it as a `var` parameter,
  because receiving one was refused. It costs no new lowering: a handle is a
  type whose values do not travel in a register, so a function answering one
  already receives the address of the variable the result is to occupy, and the
  assignment inside the function-block is 6.4.12.2's own assignment made
  through that address. The value is therefore born in the variable that will
  own it and is never held anywhere else, which is what the last sentence of
  6.4.12.2 exists to prevent.

  Every release below is *observed* rather than assumed, as `handle.pas` does
  it: `fputs` is buffered until `fclose`, so reading the file back is what says
  the closer ran. The two claims a reader should look for are the last two --
  a factory over a factory, which passes the destination on so there is no
  intermediate handle at any depth, and re-assignment through a factory, which
  must release what the variable held. The second is where a lowering that
  stored the answer *again* after the call would be caught: it would release
  what the callee had just written into that same slot. }
program factory_handle(output, fresh);

type
  OutFile = handle external 'fclose';

function ExtFopen(path, mode: string): OutFile; external 'fopen';
function ExtFputs(s: string; f: OutFile): integer; external 'fputs';

var
  fresh: bindable text;
  a, b: string(255);
  t: bindable text;
  bt: BindingType;
  line: string(80);
  k: integer;

procedure show(path: string; what: string);
begin
  bt := binding(t);
  bt.name := path;
  bind(t, bt);
  if binding(t).bound then begin
    reset(t);
    if eof(t) then writeln(what, ': [empty]')
    else begin
      readln(t, line);
      writeln(what, ': [', line, ']')
    end
  end
  else
    writeln(what, ': nothing there');
  unbind(t)
end;

{ The factory itself. }
function Create(path: string): OutFile;
begin
  Create := ExtFopen(path, 'w')
end;

{ A factory over a factory: `%res` is passed straight through and this block
  holds no handle of its own. }
function CreateVia(path: string): OutFile;
begin
  CreateVia := Create(path)
end;

{ 6.4.12.2's second form written as a result, which is what makes the
  construct usable: a producer that could not report failure would be worse
  than the `var` parameter it replaces. }
function CreateOrNot(path: string; really: boolean): OutFile;
begin
  if really then CreateOrNot := ExtFopen(path, 'w')
  else CreateOrNot := nil
end;

{ The caller owns what the factory answered, and the block's exit releases it. }
procedure owns(path: string);
var f: OutFile;
begin
  f := Create(path);
  writeln('open: ', f <> nil);
  k := ExtFputs('made by the factory', f);
  show(path, 'before exit')
end;

procedure ownsVia(path: string);
var f: OutFile;
begin
  f := CreateVia(path);
  k := ExtFputs('made two deep', f)
end;

{ The crux. The second call must release what the first left in `f`, and the
  release happens inside the callee -- through the caller's own address --
  rather than at this statement. }
procedure again(p, q: string);
var f: OutFile;
begin
  f := Create(p);
  k := ExtFputs('first', f);
  f := Create(q);
  k := ExtFputs('second', f);
  show(p, 'first, after reassignment');
  show(q, 'second, still open')
end;

procedure empty(path: string);
var f: OutFile;
begin
  f := CreateOrNot(path, false);
  writeln('answered nothing: ', f = nil);
  f := CreateOrNot(path, true);
  writeln('then something: ', f <> nil);
  k := ExtFputs('after the nil', f)
end;

begin
  a := binding(fresh).name + '.factory.a';
  b := binding(fresh).name + '.factory.b';

  owns(a);
  show(a, 'after exit');

  ownsVia(b);
  show(b, 'two deep, after exit');

  again(a, b);
  show(b, 'second, after exit');

  empty(a);
  show(a, 'after the nil answer')
end.
