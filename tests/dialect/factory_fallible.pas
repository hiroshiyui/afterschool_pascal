{ AP 6.4.13.5 (ADR-0256): `function Open(p: Path): Stream ! ErrorCode`.

  This is the one item `doc/roadmap.md` carried with a named cost, and the cost
  was named correctly in one direction and not the other. What it said: the
  arms of a fallible-type are a variant part, they share storage, and a handle
  in one would have its closer clobbered by the other -- so the arms have to be
  laid beside one another instead, and every gate comparing offsets moves. Two
  of those gates turn out not to move at all, because neither reads a source
  that declares a fallible-type. What it did not say is that admitting the type
  is not enough: the record then contains something with no copy, so it needs
  an assignment rule of its own, and `try` has to be refused on it.

  The claims here, in order.

  A factory answers a stream **or a reason**, which is the whole point -- a
  producer that could answer only nil would be worse than the `var` parameter
  and status code every module in `lib/` uses today.

  The value is built **in the caller's variable**. There is no copy at the
  assignment: the callee is handed this variable's address and its own
  `Open := ExtFopen(...)` stores through it, which is 6.4.12.2's assignment one
  frame in. A memcpy here would be ADR-0150's double free with a handle in
  place of a file -- two records, each holding a slot the runtime is tracking,
  each released at the end of its own block.

  The handle inside the arm is **released when the block ends**, and that is
  observed rather than assumed: `fputs` is buffered until `fclose`, so reading
  the file back is what says the closer ran.

  And re-assigning through the factory releases what the variable held, which
  is the claim a lowering that stored the answer *again* after the call would
  fail: it would release what the callee had just written into that same slot. }
program factory_fallible(output, fresh);

type
  Stream = handle external 'fclose';
  Code = (noPath, refused);
  Opened = Stream ! Code;

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(s: string; f: Stream): integer; external 'fputs';

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

{ The factory. Both arms are written through 6.4.13.3's shorthand, which says
  which outcome it means by what it is given. }
function Open(path: string): Opened;
begin
  if path = '' then Open := noPath
  else Open := ExtFopen(path, 'w')
end;

{ A factory over a factory: the destination is passed on, so this block holds
  no record and no handle of its own. }
function OpenVia(path: string): Opened;
begin
  OpenVia := Open(path)
end;

procedure uses_(path: string);
var r: Opened;
begin
  r := Open(path);
  writeln('ok: ', r.ok);
  if r.ok then k := ExtFputs('written through the factory', r.val);
  show(path, 'before exit')
end;

procedure viaTwo(path: string);
var r: Opened;
begin
  r := OpenVia(path);
  if r.ok then k := ExtFputs('two deep', r.val)
end;

{ The crux: the second call must release what the first left in `r`. }
procedure again(p, q: string);
var r: Opened;
begin
  r := Open(p);
  k := ExtFputs('first', r.val);
  r := Open(q);
  k := ExtFputs('second', r.val);
  show(p, 'first, after reassignment');
  show(q, 'second, still open')
end;

{ The case the side-by-side layout exists for, and the one a test of this
  feature is worth nothing without.

  The value arm holds an open stream; then a *cause* is written into the same
  record. Laid apart, the cause has bytes of its own and the handle is
  untouched, so the variable still owns an open stream and the block's exit
  closes it. Laid over one another -- which is what every other variant part
  in this language is -- the cause would be written across the front of the
  `struct pas_handle` the runtime is holding, and the epilogue would close
  whatever was left there.

  Nothing else here reaches it: the failing call in `failed` writes a cause
  over a handle that was never opened, so the bytes it corrupts are zero
  either way. That distinction is why this procedure exists separately. }
procedure causeOverValue(path: string);
var r: Opened;
begin
  r := Open(path);
  k := ExtFputs('open when the cause arrived', r.val);
  r := refused;
  writeln('now a cause: ', r.ok = false)
end;

procedure failed;
var r: Opened;
begin
  r := Open('');
  writeln('ok: ', r.ok);
  if not r.ok then writeln('cause is nopath: ', r.cause = noPath)
end;

begin
  a := binding(fresh).name + '.ffact.a';
  b := binding(fresh).name + '.ffact.b';

  failed;

  uses_(a);
  show(a, 'after exit');

  viaTwo(b);
  show(b, 'two deep, after exit');

  again(a, b);
  show(b, 'second, after exit');

  causeOverValue(a);
  show(a, 'value survived the cause')
end.
