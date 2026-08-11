{ Everything §6.9.4 calls a *threat* to a protected parameter, and the two
  static rules §6.7.3.1 and §6.7.3.6 put around one. Sema accumulates, so all
  of these are reported in one run. }
program ProtectionErrors(input, output);
type point = record x, y: integer end;
     link = ^point;
     holder = record p: link end;
     buf = record f: text end;
     triple = array [1..3] of integer;
     { an array of pointers: the rule reaches through the component type, and
       a record holding one is not the case that says so — a record checks its
       fields, an array checks its element, and they are separate answers }
     links = array [1..2] of link;

var g: point;
    j: integer;

{ §6.9.4 a): an assignment threatens its target, whether the target is the
  parameter itself or something reached inside it. "Closest-containing"
  (§6.5.1) is why the field and the component are refused too. }
procedure assigns(protected a: integer; protected var r: point;
                  protected var v: triple);
begin
  a := 1;
  r.x := 2;
  v[1] := 3
end;

{ §6.9.4 c): read and readln threaten every variable they read into. }
procedure reads(protected var a: integer);
begin
  read(a)
end;

{ §6.9.4 b): a protected parameter may not be handed to a var parameter that
  is *not* protected — that formal is free to write it. }
procedure writesIt(var a: integer);
begin
  a := 0
end;

procedure hands(protected var a: integer);
begin
  writesIt(a)
end;

{ §6.9.4 i): a `with` does not launder the protection. }
procedure viaWith(protected var r: point);
begin
  with r do x := 9
end;

{ §6.7.3.1: "every type possessed by the associated variable-identifier shall
  be protectable", and §6.4.1 says a file and a pointer are not — nor is
  anything holding one. The standard gives both reasons: a file is modified by
  nearly every operation on it, and a pointer's value can be copied out and
  disposed of through the copy, so protecting the variable protects nothing. }
procedure unprotectable(protected var f: text; protected p: link;
                        protected var h: holder; protected var b: buf;
                        protected var q: links);
begin
  j := j + ord(eof(f)) + ord(p = nil) + ord(h.p = nil) + ord(eof(b.f)) +
       ord(q[1] = nil)
end;

{ §6.7.3.6: "Either both contain protected or neither contains protected."
  Both directions are errors, and the second is the one easier to forget: a
  body that writes its parameter cannot stand in for one that promised not to. }
function guarded(protected var r: point): integer;
begin
  guarded := r.x
end;

function unguarded(var r: point): integer;
begin
  r.x := 0;
  unguarded := 1
end;

procedure wantsGuarded(function f(protected var r: point): integer);
begin
  j := f(g)
end;

procedure wantsPlain(function f(var r: point): integer);
begin
  j := f(g)
end;

begin
  wantsGuarded(unguarded);
  wantsPlain(guarded)
end.
