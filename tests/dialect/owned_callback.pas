{ AP 6.4.14.9's fourth paragraph: the routine a procedural formal-parameter
  denotes was denoted before the activation existed.

  ADR-0326 closed the third way a block reaches an owner by asking CanName of
  the routine handed over. Asked of a *formal* parameter it answered from the
  formal's own defining-point, which is inside the block -- so the ordinary
  callback shape, a routine lending a borrow of its own local to the routine
  it was handed, was refused:

      procedure Holder(procedure k);
      var p: ON;
      begin new(p); Runner(p^, k) end;

  Whatever is bound to `k` was denoted at an activation-point of `Holder`, in
  a block whose activation is a proper ancestor of this one, so it cannot name
  this activation's `p`. Both paragraphs had it, the callee form as much as
  the argument form. }
program owned_callback(output);

type
  N = record v: integer end;
  ON = owned ^N;

procedure Runner(protected var m: N; procedure k);
begin k; writeln('runner ', m.v:1) end;

procedure Bare(procedure k);
begin k end;

procedure Show(protected var m: N);
begin writeln('show ', m.v:1) end;

procedure Quiet;
begin writeln('quiet') end;

{ 1. the argument form: the borrow and Holder's own procedural formal at one
     activation-point }
procedure Holder(procedure k);
var p: ON;
begin
  new(p);
  p^.v := 7;
  Runner(p^, k)
end;

{ 2. the callee form: the activated block *is* the formal }
procedure Direct(procedure r(protected var m: N));
var p: ON;
begin
  new(p);
  p^.v := 8;
  r(p^)
end;

{ 3. the with-statement form, both halves -- the block activated in the body
     is the formal, and the routine handed to it is too }
procedure Held(procedure k; procedure r(protected var m: N));
var p: ON;
begin
  new(p);
  p^.v := 9;
  with p^ do begin
    Bare(k);
    r(p^);
    writeln('held ', v:1)
  end
end;

begin
  Holder(Quiet);
  Direct(Show);
  Held(Quiet, Show)
end.
