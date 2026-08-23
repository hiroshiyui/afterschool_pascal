{ AP 6.4.12: a handle-type. A foreign routine's answer that is an address of
  storage the callee owns -- a FILE *, a DIR * -- and whose contents are not
  characters, which AP 6.7.7.9 c) kept out until there was a type for it
  (ADR-0174). The type is owned the way a file variable is (ADR-0151): no
  copy, no comparison but with nil, released when the variable dies, and
  released by the routine the type names.

  Every release below is *observed*, not assumed: fputs is buffered until
  fclose, so reading the file back says whether the closer ran. The names
  are built from `fresh`, the harness's own per-run path. }
program handle(output, fresh);

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

{ released at the block's exit }
procedure writer(path: string);
var f: OutFile;
begin
  f := ExtFopen(path, 'w');
  writeln('open: ', f <> nil);
  k := ExtFputs('written in writer', f);
  show(path, 'before exit')
end;

{ the nil answer: a failed open is an empty handle, and nothing to release }
procedure opener(path: string);
var f: OutFile;
begin
  f := ExtFopen(path, 'r');
  writeln('missing opens: ', f <> nil, ', empty: ', f = nil)
end;

{ reassignment releases what the variable held }
procedure twice(p, q: string);
var f: OutFile;
begin
  f := ExtFopen(p, 'w');
  k := ExtFputs('first', f);
  f := ExtFopen(q, 'w');
  k := ExtFputs('second', f);
  show(p, 'first, after reassignment');
  show(q, 'second, still open')
end;

{ a non-local goto leaves the block without its epilogue, and the jump
  releases what it abandons (ADR-0032's obligation) }
procedure jumper(path: string);
label 9;
  procedure inner;
  var f: OutFile;
  begin
    f := ExtFopen(path, 'w');
    k := ExtFputs('before the goto', f);
    goto 9
  end;
begin
  inner;
  writeln('not reached');
9:
  show(path, 'after goto')
end;

{ a handle may be passed by reference, and the callee lends it on }
procedure lend(var f: OutFile);
begin
  k := ExtFputs('lent', f)
end;

procedure viavar(path: string);
var f: OutFile;
begin
  f := ExtFopen(path, 'w');
  lend(f)
end;

begin
  a := binding(fresh).name + '.handle.a';
  b := binding(fresh).name + '.handle.b';
  writer(a);
  show(a, 'after exit');
  opener(binding(fresh).name + '.handle.absent');
  twice(a, b);
  show(b, 'second, after exit');
  jumper(a);
  viavar(b);
  show(b, 'lent, after exit')
end.
