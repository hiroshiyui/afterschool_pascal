{ AP 6.4.14.9 as ADR-0326 amended it: a routine reaches what it cannot name.

  The clause refuses a borrow lent to a routine that can *name* the owner, and
  its NOTE 1 claimed that with 6.4.14.7 the pair was exhaustive -- an owned
  pointer's only names being the variable, a variable parameter bound to it,
  and a component of what contains it. The enumeration is right and the
  inference was not: a block can *cause* a release without naming the owner,
  by activating a §6.7.3.4 procedural parameter that can. That is the third
  way, and it was there from ADR-0030.

      procedure Runner(var m: N; procedure k);
      begin k; writeln(m.v:1) end;          -- m is freed storage

  It compiled, printed a garbage value and exited 0.

  Both halves of the clause had it, because both asked only about the callee.
  Sema accumulates, so one file. }
program owned_procparam_errors(output);

type
  N = record v: integer end;
  ON = owned ^N;

{ Cannot name anything of Holder's -- which is the whole point: the old rule
  looked at this heading and found nothing to refuse. }
procedure Runner(protected var m: N; procedure k);
begin k; writeln(m.v:1) end;

procedure Bare(procedure k);
begin k end;

{ Declared here rather than inside Holder, which is the point: a routine
  nested in the owner's block can name the owner whatever its body does, so
  the only routine that may be handed alongside a borrow of p is one declared
  outside Holder. }
procedure Quiet; begin writeln('quiet') end;

{ A routine that takes one and reaches nothing. }
procedure Harmless(protected var m: N; procedure k);
begin writeln(m.v:1) end;

procedure Holder;
var p: ON;
  { can name p, so handing it anywhere a borrow of p goes is the fault }
  procedure Killer; begin dispose(p) end;
begin
  new(p);
  p^.v := 7;
  { 1. the argument form: the borrow and the reaching routine at one call }
  Runner(p^, Killer);
  { 2. and it is the *routine* that decides, not what it is passed to --
       Harmless never calls k, and a rule that admitted this would be a flow
       analysis (ADR-0277's boundary, one construct over) }
  Harmless(p^, Killer);
  { 3. the with-statement form: the binding is live for the whole body, so a
       call anywhere in it that hands on a routine reaching p is the same
       fault one activation further on }
  with p^ do begin
    Bare(Killer);
    writeln(v:1)
  end;
  { 4. and a procedural actual that resolved to nothing. The name is reported
       by 6.7.3.4's own check and this pass must survive it -- a symbol that
       is nil is a question about a routine there is no routine to ask. }
  Runner(p^, NoSuchRoutine);
  { 5. and what must still compile: the same shapes with a routine that
       cannot name p }
  Runner(p^, Quiet);
  with p^ do Bare(Quiet)
end;

{ 6. the boundary of AP 6.4.14.9's fourth paragraph (ADR-0332). A procedural
     formal of the block that *declares* the owner cannot reach it, being
     bound before that activation exists -- but a formal of a block nested one
     deeper can, because the actual is denoted inside the block that declares
     the owner. `Nested`'s k is bound at a call in Outer, where Killer2 is in
     scope. }
procedure Outer;
var p: ON;
  procedure Killer2; begin dispose(p) end;
  procedure Nested(procedure k);
  begin Runner(p^, k) end;
begin
  new(p);
  p^.v := 7;
  Nested(Killer2)
end;

begin Holder; Outer end.
