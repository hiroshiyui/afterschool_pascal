program Nesting(output);

{ Nested procedures reaching outward through the static chain. The last case
  is the one that separates a correct implementation from a plausible one: a
  nested procedure inside a *recursive* one must see the locals of the
  invocation it was called from, not of the outermost or the innermost. }

var
  top: integer;

procedure Outer(a: integer);
var
  b: integer;

  procedure Middle(c: integer);
  var
    d: integer;

    procedure Inner(e: integer);
    begin
      writeln('inner: top=', top, ' a=', a, ' b=', b,
              ' c=', c, ' d=', d, ' e=', e);
      b := b + e          { assignment three levels out }
    end;

  begin
    d := c * 10;
    Inner(c + 1);
    writeln('middle: b=', b)
  end;

begin
  b := a * 2;
  Middle(a + 5);
  writeln('outer: b=', b)
end;

procedure Down(n: integer);

  procedure Show;
  begin
    write(n:2)     { n belongs to this invocation of Down }
  end;

begin
  Show;
  if n > 0 then
    Down(n - 1);
  Show
end;

procedure Shadow;
var
  top: integer;    { shadows the global of the same name }
begin
  top := 7;
  writeln('inner top=', top)
end;

begin
  top := 100;
  Outer(7);

  Down(3);
  writeln;

  Shadow;
  writeln('global top=', top)
end.
