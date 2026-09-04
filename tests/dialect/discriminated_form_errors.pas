{ AP 6.7.3.1.1 and 6.7.2.1: what the discriminated form does not admit.
  Sema accumulates, so one file.

  Each refusal is a rule stated over *types*, answering here because what the
  form denotes is a type. None of them is new and none is about the spelling
  -- which is the argument for the clause: the addition is a fourth way to
  write a type-denoter in a position that required a name, and nothing else
  moved (ADR-0324). }
program discriminated_form_errors(output);

type Box(n: integer) = record a: array [1..n] of integer end;

var s6: string(6); b4: Box(4); k: integer;

{ §6.7.3.3: a variable parameter's actual must possess the formal's type, and
  the tuple is part of the type. }
procedure Fill(var x: string(5));
begin x := 'ab' end;

procedure Put(var x: Box(3));
begin x.a[1] := 1 end;

{ §6.4.7: the discriminants of a discriminated-schema are constants. A formal
  whose capacity is not known where it is declared is what §6.7.3.1's
  schema-name alternative is for, and it is spelled `x: string`. }
procedure Loose(x: string(k));
begin writeln(x) end;

{ AP 6.4.3.3.2: a capacity is a positive number, wherever it is written. }
procedure Empty_(x: string(0));
begin writeln(x) end;

{ §6.4.7 again: the tuple is the schema's whole tuple. }
procedure Short_(x: Box(1, 2));
begin writeln('unreached') end;

{ §6.7.3.6: two parameter-forms denoting two types are not congruous. }
procedure Six(var z: string(6));
begin z := 'ab' end;

procedure Apply(procedure f(var z: string(5)));
var five: string(5);
begin five := ''; f(five) end;

{ The four headings above are refused where they are written, so their
  formals have no type and calling them would report the consequence of a
  fault already named. Only the two whose headings are correct are called
  here, and each is refused at the call for the type rule it breaks. }
begin
  Fill(s6);
  Put(b4);
  Apply(Six);
  writeln(k:1)
end.
