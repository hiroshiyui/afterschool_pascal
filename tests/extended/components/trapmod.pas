module TrapMod;
export TrapMod = (Third);

{ ADR-0293: a trap in a separately translated component names *that*
  component's file. The file constant is one per translation, so a program
  importing this module reports the subscript here and not a line of its own. }

function Third(k: integer): integer;
end;

var
  t: array [1..3] of integer;

function Third;
begin
  Third := t[k]
end;

to begin do begin
  t[1] := 1; t[2] := 2; t[3] := 3
end;
end.
