{ What the run-time tuple comparison does *not* excuse. §6.4.6 d) is about two
  types produced from the same schema; everything else is still decided here,
  and a tuple that is known is still known. }
program SchemaAssignErrors(output);
type vector(n: integer) = array [1..n] of real;
     other(m: integer) = array [1..m] of real;
     plain = array [1..3] of real;

var a: vector(3);
    b: vector(4);
    c: other(3);
    p: plain;
    r: real;

procedure two(var v: vector; var w: other);
var d: vector(3);
begin
  { Both tuples are known, so §6.4.6 a) decides it and there is nothing to
    defer: two productions of one schema with different tuples are two types. }
  a := b;

  { Two schemata are two schemata however alike their bodies are. §6.4.8's
    identity rule is keyed by the schema as well as the tuple. }
  a := c;
  v := w;

  { A produced type is a type of its own, not the type its body was written
    as: name equivalence (ISO 7185 §6.4.5) is untouched by any of this. }
  p := a;
  a := p;
  v := p;

  { A generic type is still an array, so it has none of the other meanings a
    deferred comparison might be mistaken for. }
  r := v;
  v := r;
  if v = w then writeln('never')
end;

begin
  two(a, c)
end.
