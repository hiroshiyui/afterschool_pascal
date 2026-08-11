{ ISO/IEC 10206:1991 §6.7.3.1: `protected` before a parameter specification
  says that no statement of the body may *threaten* the parameter (§6.9.4).

  It is a rule about the body and not about how the argument travels — a
  protected `var` parameter is still an address, and a protected value
  parameter is still a copy — so nothing after Sema knows the word was
  written. What it buys is stated in §6.7.3.1's own NOTE 2, and the two halves
  differ: a protected *value* parameter cannot change at all, while a
  protected *var* parameter can still change under the procedure's feet
  through the actual it is bound to. This program shows exactly that. }
program Protection(output);
type point = record x, y: integer end;

var p: point;
    n, k: integer;

{ A protected value parameter is a copy the body may not write. Reading it,
  indexing with it, and passing it on by value are all untouched. }
function scaled(protected v: integer; by: integer): integer;
begin
  by := by + 0;          { an ordinary parameter is still writable }
  scaled := v * by
end;

{ A protected var parameter binds to the caller's variable and promises only
  that *this* body will not write it. }
function sumOf(protected var r: point): integer;
begin
  sumOf := r.x + r.y     { fields may be read through it }
end;

{ §6.9.4 b): passing a protected parameter on as a var argument is a threat
  only when the formal it goes to is *not* protected. So protection forwards,
  and that is what makes the rule usable at all — otherwise a protected
  parameter could not be given to any procedure taking it by reference. }
function forwarded(protected var r: point): integer;
begin
  forwarded := sumOf(r)
end;

{ §6.9.4 i): a `with` is where the name of the record stops being written
  down, so the protection has to travel onto the binding the `with` makes. }
function viaWith(protected var r: point): integer;
begin
  with r do viaWith := x * 100 + y
end;

{ Congruity (§6.7.3.6) makes `protected` part of a procedural parameter's
  signature: "Either both contain protected or neither contains protected."
  So a procedure passed here must itself protect its parameter. }
procedure apply(function f(protected var r: point): integer; var out: integer);
begin
  out := f(p)
end;

{ NOTE 2's other half, made visible: a protected *var* parameter is not a
  constant. `bump` changes the variable `q` is bound to, and the value read
  through `q` afterwards is the new one — protection is a promise about this
  body's own statements, not about the storage. }
procedure bump;
begin
  n := n + 1
end;

function watch(protected var q: integer): integer;
var before: integer;
begin
  before := q;
  bump;                  { changes the very variable q denotes }
  watch := (q - before) * 1000 + q
end;

begin
  p.x := 3; p.y := 4;
  writeln(scaled(6, 7):1);
  writeln(sumOf(p):1);
  writeln(forwarded(p):1);
  writeln(viaWith(p):1);
  apply(sumOf, k);
  writeln(k:1);
  n := 41;
  writeln(watch(n):1);
  writeln(n:1)
end.
