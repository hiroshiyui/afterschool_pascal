{ AP 6.7.3.6 (ADR-0290) lets a schematic *string value* formal stand where the
  declared formal names a type produced from that schema, so one
  `Hash(key: string)` serves a map keyed at any capacity. These are its three
  edges. The rule is deliberately narrow and each edge is refused for a reason
  the acceptance rests on, so this file is the argument that the widening did
  not become a general one by accident.

  The **direction**: a fixed formal never stands for a schematic one. Its slot
  has a capacity the caller is not bound by, and the first longer actual is
  6.4.6's store error at run time.

  The **schema**: only a string travels the same way in both forms, its values
  carrying a length (6.4.3.3.3), so `string(200)` and `string` are both a
  pointer and a length. `Box(5)` passes an address alone where `Box` passes an
  address and a discriminant -- the pair would be a call through the wrong
  signature.

  The **passing mode**: only a value parameter. A var one binds to storage and
  states no length, which is the boundary ISO/IEC 10206:1991 6.7.3.3 already
  draws for its own reason.

  This is a separate file from procparams.pas deliberately: that one is
  6.6.3.6's congruity as ISO 7185 wrote it, and these three are what this
  dialect adds to it. }
program congruity_edges(output);
type
  Key63 = string(63);
  Box(k: integer) = record a: array [1..k] of integer end;
  B5 = Box(5);

function Fixed63(key: Key63): integer;
begin
  Fixed63 := length(key)
end;

function GenBox(x: Box): integer;
begin
  GenBox := x.a[1]
end;

procedure VarGen(var key: string);
begin
  key := 'q'
end;

procedure WantsSchematic(function h(x: string): integer);
begin
end;

procedure WantsBox(function g(z: B5): integer);
begin
end;

procedure WantsVarFixed(procedure g(var x: Key63));
begin
end;

begin
  WantsSchematic(Fixed63);
  WantsBox(GenBox);
  WantsVarFixed(VarGen)
end.
