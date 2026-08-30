{ Where a schema is asked to produce a type and cannot, and the three places
  that ask (ADR-0045, ADR-0209). Each names the *position* rather than the
  schema alone, because `no type is produced from schema 'broken'` on its own
  says nothing about which declaration is being refused.

  The last of them is the other refusal: a schema that produces a type nothing
  can describe, which is a discriminant that does not bound the last thing in
  the type. }
program schemadomains(output);
type
  { A schema whose body cannot resolve at all: the message fires once per
    position that asks for a production, and never at the schema itself. }
  broken(n: integer) = array [1..nosuch] of integer;

  { ...for this pointer domain. }
  pb = ^broken;

  { ...and a schema that resolves and describes nothing: 6.4.7's descriptor
    can bound an array and can bound the *last* field of a record, and `tail`
    is after the bounded one. }
  rec(n: integer) = record a: array [1..n] of integer; tail: integer end;
  prec = ^rec;

var m: integer;

{ 6.4.2.5's restricted-type names a type. The parser has already refused
  anything that is not an identifier; what is left for Sema is an identifier
  that denotes something else, which it can only know by looking the name up
  (ADR-0044's rule, met again). }
type notatype = restricted m;

procedure locals;
  { ...for this variable's type. A discriminant that is not a constant makes
    this a dynamic production, which is the arm that reports. }
  var v: broken(m);
begin end;

begin
end.
