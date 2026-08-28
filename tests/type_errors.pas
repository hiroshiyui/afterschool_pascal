program TypeErrors(output);

{ The rules that make structured types worth having are the ones that reject
  programs. ISO 7185 6.4.5 makes two types the same only when one denoter
  names both, so the two arrays below are different types even though they
  have the same shape. }

type
  vector = array [1..3] of integer;
  link = ^cell;
  cell = record datum: integer end;
  other = ^cell;                { a distinct type denoting the same domain }
  dangling = ^nosuchtype;       { the domain never arrives }

var
  v: vector;
  w: array [1..3] of integer;   { a separate denoter, so a separate type }
  r: record a, b: integer end;
  s: record a, b: integer end;
  n: integer;
  p: link;
  q: other;
  { A subscript is lowered to `i - lo`, so the span has to be a value of the
    integer type; verify/rules.py proves the check is what makes that sound. }
  huge: array [-2000000000..2000000000] of integer;

function Bad: vector;           { 6.6.2: a result type must be simple }
begin
end;

procedure TakesVector(x: vector);
begin
end;

begin
  v := w;                       { different types }
  n := v;                       { array to integer }
  v[1] := r;                    { record to integer }
  n := v[1][2];                 { the component is not an array }
  n := r.missing;               { no such field }
  n := n.a;                     { integer has no fields }
  if r = s then n := 1;         { records have no relational operators }
  writeln(v);                   { only a packed array of char can be written }
  TakesVector(w);               { the argument is not that type }
  with n do n := 1;             { with needs a record }

  p := q;                       { two distinct pointer types }
  n := n^;                      { an integer cannot be dereferenced }
  p := p + p;                   { pointers have no arithmetic }
  if p < q then n := 1;         { and no ordering }
  writeln(p);                   { and no external spelling }
  new(n);                       { new needs a pointer }
  new(p, 1)                     { tag values, but no variant part }
end.
