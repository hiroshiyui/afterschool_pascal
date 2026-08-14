{ ISO 7185 6.6.3.3, its last two sentences: "An actual variable parameter
  shall not denote a field that is the selector of a variant-part. An actual
  variable parameter shall not denote a component of a variable where that
  variable possesses a type that is designated packed."

  ISO/IEC 10206:1991 6.7.3.3 carries both sentences word for word, and adds a
  third about a component of a string-type, so neither check below is gated on
  the standard.

  The BSI suite's DEV129 and DEV130 are one program each for the two, and both
  were accepted here until this landed. The half that keeps the checks honest
  is the accepted list at the bottom: a rule about components is one sentence
  away from banning every array element and every field, so each refusal here
  is paired with the nearest thing that must still compile.

  The one asymmetry worth reading twice is `pa[1].f` against `pa[1]`. 6.4.3.1
  says "if a component is itself structured, the component's representation in
  data-storage shall be packed only if the type of the component is designated
  packed", so packing does not reach a component's own components: `pa[1]`
  possesses `urec`, which no `packed` designates, and a field of it is
  therefore not a component of a packed variable. The multi-dimensional
  abbreviation is not an exception to that, because 6.4.3.2 designates every
  array-type it constructs packed when the original is -- which is why
  `g[1, 1]` is refused and `pa[1].f` is not. }

program VarParamRestrictions(output);

type
  shape = (triangle, rectangle);
  figure = record
             area: integer;
             case s: shape of
               triangle:  (base, height: integer);
               rectangle: (side1, side2: integer)
           end;
  card  = packed array [1..8] of char;
  plain = array [1..8] of char;
  prec  = packed record pf, pg: integer end;
  urec  = record uf, ug: integer end;
  grid  = packed array [1..3, 1..3] of integer;
  parr  = packed array [1..3] of urec;

var
  f:  figure;
  c:  card;
  a:  plain;
  pr: prec;
  ur: urec;
  g:  grid;
  pa: parr;

procedure TakeInt(var x: integer);
begin x := x end;

procedure TakeCh(var x: char);
begin x := x end;

procedure TakeShape(var x: shape);
begin x := x end;

procedure TakeCard(var x: card);
begin x[1] := ' ' end;

procedure TakeFig(var x: figure);
begin x.area := 0 end;

procedure TakeRec(var x: urec);
begin x.uf := 0 end;

begin
  { --- refused: a field that is the selector of a variant-part ----------- }
  TakeShape(f.s);
  { the same selector reached through a with-statement, which is a bare name
    bound to a field rather than a selection with a base to walk }
  with f do TakeShape(s);

  { --- refused: a component of a variable of a type designated packed ---- }
  TakeCh(c[1]);
  TakeInt(pr.pf);
  TakeInt(g[1, 1]);
  TakeRec(pa[1]);

  { --- accepted: the packed variable itself is not a component of one ---- }
  TakeCard(c);
  TakeFig(f);

  { --- accepted: an ordinary field that is not the selector -------------- }
  TakeInt(f.area);
  { a field of an *arm* is not a selector either, only the tag is }
  TakeInt(f.side1);
  TakeInt(ur.uf);

  { --- accepted: a component of a variable that is not packed ------------ }
  TakeCh(a[1]);
  { 6.4.3.1 again: pa is packed, pa[1] is not, so a field of pa[1] is a
    component of an unpacked variable }
  TakeInt(pa[1].uf);

  writeln('ok')
end.
