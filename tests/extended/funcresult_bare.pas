{ A parameterless function whose result lives in memory, called by writing its
  name.

  ISO 7185 §6.8.2.2 makes a bare function-identifier a call — Pascal has no
  empty argument list, so `mk` and `mk()` are not two spellings, there is only
  the one. Every other call in the language arrives at CodeGen as a `Call` node,
  and ADR-0055 hung the result storage off that node: a result living in memory
  is built in a frame slot the *caller* owns, and the call's value is that
  slot's address.

  A bare name is not a `Call` node. It is a `VarRef` whose symbol happens to be
  a function, and it therefore got no slot — so `emitAddress` answered with the
  address of `sym`, which is a *function* and has no storage, and the call was
  never emitted at all. Every program below printed zeros or the null-string.

  Nothing caught it. `funcresult.pas` gives every function a parameter, because
  a function that computes something from nothing is a strange thing to write
  on purpose — which is exactly why the shape has to be written on purpose
  here. The suite was green, both compilers agreed, and stage 2 equalled stage
  3 while this was wrong. }
program FuncResultBare(output);
type
  point  = record x, y: integer end;
  vec3   = array [1..3] of integer;
  name   = string(20);

var p: point; v: vec3; s: name; i: integer;

function origin = r: point;
begin r.x := 3; r.y := 4 end;

function ramp = out: vec3;
var j: integer;
begin for j := 1 to 3 do out[j] := j * 7 end;

function greeting = t: name;
begin t := 'hello world' end;

{ The same shape one level down, so the slot is a nested block's frame rather
  than the program's global one (ADR-0053). }
function shifted = r: point;
  function base = b: point;
  begin b.x := 10; b.y := 20 end;
begin r := base; r.x := r.x + 1 end;

begin
  { Assigned whole. }
  p := origin;
  writeln('record ', p.x:1, ' ', p.y:1);

  v := ramp;
  write('array ');
  for i := 1 to 3 do write(' ', v[i]:1);
  writeln;

  s := greeting;
  writeln('string [', s, '] ', length(s):1);

  { ...and used directly, which is §6.8.6's function-access over a bare name:
    the same slot, selected from rather than copied out of. }
  writeln('field  ', origin.y:1);
  writeln('index  ', ramp[2]:1);
  writeln('len    ', length(greeting):1);

  p := shifted;
  writeln('nested ', p.x:1, ' ', p.y:1)
end.
