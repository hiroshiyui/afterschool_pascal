{ ISO/IEC 10206:1991 6.7.3.4 and 6.7.3.5: the actual-parameter corresponding to
  a formal procedural or functional parameter "shall be a procedure-name" and
  "shall be a function-name" respectively. 6.7.1 and 6.7.2 spell both the same
  way:

    procedure-name = [ imported-interface-identifier '.' ] procedure-identifier
    function-name  = [ imported-interface-identifier '.' ] function-identifier

  So a qualified name is one of exactly two things the clause admits, and this
  compiler refused it -- "argument 1 of 'call' must be the name of a procedure
  or function" -- because the parser builds `dispatching.show` as a field
  selection and the actual-parameter check only ever accepted a bare
  identifier.

  Under `import ... qualified` there is no workaround, which is what makes this
  worth a case rather than an inconvenience: 6.11.3 puts the unqualified
  spelling out of scope, so a module imported that way could not have any of
  its procedures passed to anything at all.

  The parser cannot tell this from a field selection; Sema can, because it can
  look the base up (ADR-0053). }
program procparam_qualified(output);

import dispatching qualified;

var n: integer;

procedure call(procedure p(k: integer));
begin p(4) end;

procedure callvar(procedure p(var k: integer); var target: integer);
begin p(target) end;

function apply(function f(k: integer): integer): integer;
begin apply := f(5) end;

begin
  { A procedural parameter, named through its interface. }
  call(dispatching.show);

  { A functional one, whose result type has to match as well (6.7.3.5). }
  writeln('apply = ', apply(dispatching.twice):1);

  { And one whose own parameter is a var parameter, so the pair that travels
    is the code address and the frame of the module the procedure was declared
    in -- a level-0 owner, which answers with a global rather than by walking
    the static chain. }
  n := 41;
  callvar(dispatching.bump, n);
  writeln('bumped = ', n:1)
end.
