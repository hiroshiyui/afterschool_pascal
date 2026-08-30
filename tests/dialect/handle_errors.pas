{ AP 6.4.12: what a handle refuses, and each refusal's reason. A handle is
  owned (ADR-0151): it has the file variable's refusals through the same
  predicate -- predicate-callers sweeps those 21 positions -- and three of its
  own, which are the ones written out here. Sema accumulates, so one file. }
program handle_errors(output);
type
  Dir = handle external 'closedir';
  Other = handle external 'closedir';
  Bad = handle external '';
  Own = handle external 'pas_handle_done';
  NoOpt = ?Dir;
function ExtOpendir(path: string): Dir; external 'opendir';
{ 6.8.5 makes a function-designator's parameter list optional, so this one is
  written as a bare name -- and 6.4.12.2's two sentences must reach it the
  same way they reach ExtOpendir above (ADR-0180). }
function ExtOpencwd: Dir; external 'opendir_probe';
function ExtReaddir(d: Dir): int64; external 'readdir';
function ExtRewinddir(var d: Dir): integer; external 'rewinddir';
{ AP 6.4.12.6 (ADR-0255) admits this and it is here to produce *no*
  diagnostic: a function of this program may answer a handle, which until that
  clause only an `external` one could. What it may not answer is a structure
  holding one -- a handle result has exactly one destination and the address
  can be handed to the callee, and a record has none this compiler can hand
  over. }
function Mine(path: string): Dir;
begin Mine := ExtOpendir(path) end;
type Boxed = record h: Dir end;
function InARecord: Boxed;
begin end;
{ And 6.4.12.6's own refusal, which is 6.4.12.2's read through 6.8.2.2's other
  spelling: a factory may assign its result nil or a call of its own type, and
  a handle *variable* is neither -- it is owned, and a second name for it would
  release one resource twice. }
function FromAVariable: Dir;
var z: Dir;
begin FromAVariable := z end;
procedure ByValue(d: Dir);
begin end;
var d, e: Dir; o: Other; n: int64; k: integer; boxA, boxB: Boxed;
begin
  d := ExtOpendir('.');
  e := d;
  d := e;
  o := ExtOpendir('.');
  n := ExtReaddir(ExtOpendir('.'));
  k := ExtRewinddir(d);
  if d = e then writeln('same');
  if d < nil then writeln('less');
  if d = nil then writeln('empty');
  ByValue(d);
  n := ExtReaddir(o);
  { A structure holding a handle has the affine type's refusals, and is told
    which kind it holds rather than being told about a file it has not got. }
  boxA := boxB;
  { the bare spelling of a handle-valued external, in the one position it may
    stand and then in two it may not. The first line is legal and is here so
    that the two are compared rather than only the refusals tested. }
  d := ExtOpencwd;
  n := ExtReaddir(ExtOpencwd);
  if ExtOpencwd = nil then writeln('empty');
  writeln(n)
end.
