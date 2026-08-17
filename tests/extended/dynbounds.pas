{ ISO/IEC 10206:1991 6.4.2.4 writes `subrange-bound = expression`, and 6.2.3.8
  b) puts "each actual-discriminant-part or subrange-bound not contained by a
  schema-definition and closest-contained by ... the block" in the block's
  commencement -- *after* the formal value parameters are attributed. So a
  bound may be a parameter, and the array it bounds is sized when the procedure
  is entered (ADR-0113).

  ISO 7185 6.4.2.4 writes `subrange-type = constant '..' constant` instead, so
  none of this is that language and tests/dynbounds_iso.pas is the same program
  refused. }
program DynBounds(output);

{ The plainest form, and twice, so that nothing can be sized once and reused. }
procedure plain(m: integer);
var a: array [1..m] of integer; i: integer;
begin
  for i := 1 to m do a[i] := i * i;
  writeln('plain ', m:1, ' ', a[1]:1, ' ', a[m]:1)
end;

{ A group of names shares one denoter and gets two descriptors: each variable
  is sized on entry from the same expression, and they are different types
  because each reads storage of its own. }
procedure group(m: integer);
var a, b: array [1..m] of integer; i: integer;
begin
  for i := 1 to m do begin a[i] := i; b[i] := i * 10 end;
  writeln('group ', a[m]:1, ' ', b[m]:1)
end;

{ Two bounds in one denoter, written both ways round: an array of an array,
  and the abbreviation 6.4.3.2 makes equivalent to it. }
procedure nested(m, k: integer);
var g: array [1..m] of array [1..k] of integer;
    h: array [1..m, 1..k] of integer;
    i, j: integer;
begin
  for i := 1 to m do
    for j := 1 to k do begin
      g[i][j] := i * 100 + j;
      h[i, j] := i * 100 + j
    end;
  writeln('nested ', g[m][k]:1, ' ', h[m, k]:1)
end;

{ Neither end need be a constant, and the bound is an *expression* rather than
  a name -- which is the whole of what 6.4.2.4 changed. }
procedure both(lo, hi: integer);
var a: array [lo..hi + 1] of integer; i: integer;
begin
  for i := lo to hi + 1 do a[i] := i;
  writeln('both ', a[lo]:1, ' ', a[hi + 1]:1)
end;

{ Each activation is sized for itself: the descriptor lives in this
  invocation's frame and is reached down the static chain like anything else
  (ADR-0016). If one activation's storage were shared the inner calls would
  overwrite it and the unwinding would print the wrong lengths. }
procedure recur(n: integer);
var a: array [1..n] of integer; i: integer;
begin
  for i := 1 to n do a[i] := n * 10 + i;
  if n > 1 then recur(n - 1);
  writeln('recur ', n:1, ' ', a[n]:1)
end;

{ A bound out of a constant expression is still a constant, so this array is an
  ordinary one and the two names share a type -- which `p := q` is what proves.
  The offer of a dynamic bound is made to every variable and taken by very
  few. }
const size = 3;
procedure constant_still;
var p, q: array [1..size * 2] of integer;
begin
  p[6] := 42;
  q := p;
  writeln('constant ', q[6]:1)
end;

begin
  plain(4);
  plain(2);
  group(3);
  nested(2, 3);
  both(5, 7);
  recur(3);
  constant_still
end.
