{ 6.9.4 b) for a formal produced from a schema, which had no refusal at all
  until ADR-0412.

  The arm that reports this was written for a formal with an ordinary type
  and never for a schematic one, so a `protected var s: string` could be
  handed to another routine's `var s: string` and written through there --
  6.5.1's protection defeated with no diagnostic. It went unseen because the
  *other* face of the same missing call is 6.7.3.1's advice, and that is
  never given about an exported routine: every routine of this shape in the
  tree was exported, until PasJson's methods, which are exported by nothing
  (AP 6.7.10.5).

  One file rather than one per message because Sema accumulates. }
program protected_schema(output);

type vector(n: integer) = array [1..n] of real;

procedure sinkString(var s: string);
begin s := 'x' end;

procedure sinkVector(var v: vector);
begin v[1] := 1.0 end;

{ a) the string schema, which is the shape the library met }
procedure passString(protected var s: string);
begin sinkString(s) end;

{ b) a schema the program declared, so the rule is not `string`'s }
procedure passVector(protected var v: vector);
begin sinkVector(v) end;

{ c) through a procedural parameter, whose formal is schematic too }
procedure passVia(procedure p(var v: vector); protected var v: vector);
begin p(v) end;

var t: string(8);
begin
  passString(t);
  writeln(t)
end.
