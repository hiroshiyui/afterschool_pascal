{ What the parser makes of AP 6.7.3.10's type parameter, with and without
  AP 6.7.3.10.5's category (ADR-0266).

  The dump writes `type-parameter` and then the parameter-form as the source
  spelled it -- one of the four category identifiers, or `type` where none was
  written. Nothing else in this corpus reaches a generic heading, so without
  this case the word after `type-parameter` is a thing no golden holds.

  --dump-ast rather than --dump-all: a generic declaration is never
  instantiated here, so Sema has nothing to annotate on it (AP 6.7.3.10.2),
  and the token section would bury the two lines this case is about. }
program p(output);

function Sum(Elem: numeric type; a, b: Elem): Elem;
begin Sum := a + b end;

function Span(Elem: ordinal type; lo, hi: Elem): integer;
begin Span := ord(hi) - ord(lo) end;

function Larger(Elem: ordered type; a, b: Elem): Elem;
begin if a > b then Larger := a else Larger := b end;

function Alike(Elem: equatable type; a, b: Elem): boolean;
begin Alike := a = b end;

function Id(Elem: type; a: Elem): Elem;
begin Id := a end;

begin
  writeln(Sum(1, 2):1)
end.
