{ Every diagnostic §6.8.7 needs. Sema accumulates, so one program reaches
  them all; the parse errors are one file apiece, as always. }
program structvalue_errors(output);
type
  vec = array [1..4] of integer;
  pt = record x, y: integer end;
  kinds = (circle, box);
  shape = record n: integer;
            case kind: kinds of
              circle: (r: real);
              box: (w, h: integer)
          end;
  plain = record a: integer end;
  mixed = record x: integer; c: char end;
  colours = set of kinds;
  ft = record f: text end;
  vector(n: integer) = array [1..n] of integer;
var v: vec; p: pt; s: shape; c: colours; q: plain; g: ft; m: mixed; i: integer;

{ §6.8.7.3 NOTE 1 makes one field-value's identifiers denote components of one
  type, because the component-value it carries has a single type. }
procedure fields2;
begin
  m := mixed[x, c: 1]
end;

{ A dynamically bounded array has no compile-time extent, so "every component
  is specified" is not a question this compiler can answer. §6.2.3.2 lets a
  variable declaration compute its discriminants, which is the one way such a
  type reaches a component-value. }
procedure dyn(k: integer);
var d: vector(k) value [1..k: 0];
begin
  writeln(d[1])
end;

begin
  { §6.8.7.2 b): components left over need an array-value-completer. }
  v := vec[1: 1];
  { a selector outside the index type, one given twice, and one that is not
    a constant at all }
  v := vec[0: 1; 1..4: 2];
  v := vec[1: 1; 1: 2; 2..4: 3];
  v := vec[i: 1 otherwise 0];
  { nothing may follow the completer }
  v := vec[1: 1 otherwise 0; 2: 2];
  { §6.8.7.3: a record-value specifies every field, once, and only fields }
  p := pt[x: 1];
  p := pt[x: 1; x: 2; y: 3];
  p := pt[z: 1; y: 2];
  p := pt[x: 1; y: 2 otherwise 3];
  { a component-value must be assignment-compatible with the component }
  p := pt[x, y: 'c'];
  { a record with a variant part must select one, with a tag value of the
    tag type, and the tag-field-identifier must be the one the type has }
  s := shape[n: 1];
  s := shape[n: 1; case kind: 99 of [w: 1; h: 2]];
  s := shape[n: 1; case bad: box of [w: 1; h: 2]];
  { the tag field is given by the 'case', never as a field value; and a
    variant's fields belong to the variant's own value }
  s := shape[n: 1; kind: circle; case kind: circle of [r: 1.0]];
  s := shape[n: 1; w: 2; case kind: box of [w: 1; h: 2]];
  { a record with no variant part cannot select one }
  q := plain[a: 1; case box of [a: 2]];
  { §6.8.7.4's set-value is a *set-constructor*, so a set type takes members
    and never the `selector: value` components of an array- or record-value.
    `colours[]` and `colours[red]` are legal and live in setvalue.pas. }
  c := colours[1: 2];
  { and a type with no structure at all constructs nothing either way }
  i := integer[];
  i := vec[1..4: 0];
  { §6.8.7.1: the type must be one a file component may have }
  g := ft[f: g.f];
  { and it must be a type }
  p := i[x: 1];
  p := nosuch[x: 1];
  fields2;
  dyn(3);
  { §6.8.7.3: the selector of shape's variant part *has* a field-identifier,
    so every variant-part-value for it names that identifier. Appended here
    rather than written beside the two above so that no golden line moves. }
  s := shape[n: 1; case circle of [r: 1.0]];
  writeln(v[1], p.x, s.n, q.a, m.x, i)
end.
