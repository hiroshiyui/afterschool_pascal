{ AP 6.4.14.2 (ADR-0320): the schema domain is admitted only where the produced
  type holds nothing that must itself be released, and everything else the
  clause says about an owned pointer is unchanged. }
program owned_schema_errors(output);

type
  Vec(cap: integer) = record n: integer; a: array [1..cap] of integer end;
  OV = owned ^Vec;

  { Refused: the walk the clause is about is exactly what a file needs. }
  Files(cap: integer) = record f: array [1..cap] of text end;
  OF_ = owned ^Files;

  Own2 = owned ^Node;
  Node = record k: integer end;
  { Refused: an owned pointer inside is released by walking too. }
  Kids(cap: integer) = record a: array [1..cap] of Own2 end;
  OK_ = owned ^Kids;

  Stream = handle external 'fclose';
  { Refused: a handle is affine for the same reason. }
  Handles(cap: integer) = record h: array [1..cap] of Stream end;
  OH = owned ^Handles;

{ 6.4.14.3 is untouched by the amendment: a value parameter is still a copy. }
procedure ByValue(v: OV);
begin end;

{ and a result still has no variable to release it }
function Make(cap: integer): OV;
begin end;

procedure Run;
var v, w: OV;
begin
  new(v, 4);
  w := v;                     { no copy, and `take` is the only right side }
  writeln(v = w)              { and only nil is a comparand }
end;

begin
  Run
end.
