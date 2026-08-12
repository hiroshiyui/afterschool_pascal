{ The same clause from the other side. ISO 7185 §6.6.2 lists what a function
  may return — a simple type or a pointer type — and has no
  result-variable-specification at all, so both halves of ISO/IEC 10206:1991
  §6.7.2 are refused here.

  The two refusals happen in different passes, which is why the result variable
  is not in this file: `= r` is a *syntax* error under ISO 7185, and the parser
  stops at its first one, so nothing Sema says about the result type below
  would ever be compared. tests/funcresult_iso_var.pas is that program.

  §6.6.2's list is stated the standard's way round rather than as "not
  something that lives in memory": a set lives in a register and would pass
  that test while still not being a result type this language allows. }
program FuncResultIso(output);
type
  point = record x, y: integer end;
  vec3  = array [1..3] of integer;
  digs  = set of 0..9;

function asrecord: point;
begin end;

function asarray: vec3;
begin end;

function asset: digs;
begin end;

begin
  writeln('unreachable')
end.
