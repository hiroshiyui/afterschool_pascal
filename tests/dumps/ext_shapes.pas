{ The tree shapes only ISO/IEC 10206:1991 has, for the dump walkers.

  Companion to iso_shapes.pas: that one covers what both standards share, this
  one covers what --std=extended adds and what therefore has walker arms no ISO
  program can reach -- a module and its two parts, an export- and import-list, a
  schema and its discriminants, a string type, an otherwise-part in both places
  it may appear, and the operators §6.1.2 adds.

  Written as one file holding two program-components (§6.13), which is what
  tests/extended/module.pas does and what lets a module be dumped at all. }
module shapes_mod(output);
  export
    shaping = (tally, bump, protected total);

  type tally = 1 .. 99;
  var total: integer;

  procedure bump(by: tally);
end;

  procedure bump;
  begin
    total := total + by
  end;

  to begin do total := 0;
  to end do writeln('total ', total : 1);
end.

program shapes_ext(output);
import shaping;

const
  cap = 4;

type
  { §6.4.7's schema, and §6.4.8's production of a type from it. }
  vector(len: integer) = array [1 .. len] of integer;
  vec4 = vector(cap);
  name = string(16);
  colour = (red, green, blue);
  small = 1 .. 9;
  { §6.8.7.4's set-value names its type, which is what lets it be checked where
    it is written rather than where it is stored (ADR-0066). }
  hue = set of colour;
  { §6.4.2.5: a restricted type has its underlying type's values and almost
    none of its operations (ADR-0058). }
  counted = restricted integer;
  { §6.4.3.4's variant-part-completer: an arm with no labels, selected by every
    tag value the labelled arms leave (ADR-0034). A *range* label is Extended
    Pascal's too (ADR-0035), so both are here. }
  token = record
            case kind: small of
              1 .. 3:    (n: integer);
              4:         (c: colour);
              otherwise  (s: real)
          end;

var
  v: vec4;
  t: token;
  s: name;
  i, k: integer;
  cc: colour;
  b: boolean;
  x: real;
  h: hue;
  z: complex;
  ct: counted;
  pt: ^token;

{ §6.4.9's type-inquiry, and a second declaration part: §6.2.1 lets the five
  parts repeat in any order, so a type may be declared after the variable it
  inquires about (ADR-0069). }
type
  likeI = type of i;
var
  i2: likeI;

{ A schematic formal parameter: one body serves every length, the tuple
  travelling beside the address (ADR-0040). }
procedure fill(var q: vector; with_: integer);
var m: integer;
begin
  for m := 1 to q.len do q[m] := with_
end;

begin
  fill(v, 7);
  s := 'shapes';
  h := hue[red, blue];
  z := cmplx(1.0, 2.0);
  ct := 3;
  pt := nil;
  i2 := 9;
  i := 2;
  x := 2 ** 3;
  k := 2 pow 3;
  b := (i > 0) and then (v[i] = 7);
  b := b or else (i < 0);
  t.kind := 5;
  t.s := 1.5;
  { §6.9.3.5's otherwise-part, which retired "ISO 7185 has no else and none is
    invented" (ADR-0033). The `;` before it is optional (§6.9.3.5 Example 1). }
  case i of
    1: writeln('one');
    2: writeln('two')
    otherwise writeln('many')
  end;
  { §6.9.3.9.3's set-member-iteration, the other iteration-clause. }
  for cc in [red, blue] do write(ord(cc) : 2);
  writeln;
  { §6.7.5.5's two: the only statements whose first argument is a string
    rather than a file, which the AST records in a field of its own and the
    walkers therefore write through a path nothing else takes. }
  writestr(s, i : 3, ' ', k : 2);
  readstr(s, i);
  writeln(s, ' ', v[1] : 1, ' ', x : 4 : 1, ' ', b);
  writeln(re(z) : 3 : 1, ' ', i2 : 1, ' ', ord(red in h) : 1)
end.
