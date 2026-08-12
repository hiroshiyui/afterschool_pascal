{ ISO/IEC 10206:1991 §6.8.7 structured-value-constructors: a primary that
  denotes a value of a named array or record type. }
program structvalue(output);
type
  vec   = array [1..4] of integer;
  mat   = array [1..2] of vec;
  pt    = record x, y: integer end;
  pts   = array [1..2] of pt;
  kinds = (circle, box);
  shape = record
            n: integer;
            case kind: kinds of
              circle: (r: real);
              box: (w, h: integer)
          end;
  { An arm's field-list is a field-list, so an arm may hold a variant part of
    its own — and a variant-part-value nests exactly as the type does. }
  outer = (leaf, node);
  inner = (red, green);
  tree  = record
            id: integer;
            case tag: outer of
              leaf: (n: integer);
              node: (case hue: inner of
                       red:   (heat: integer);
                       green: (cool: integer))
          end;
  { §6.6 NOTE 3: an initial-state-specifier may be a component-value, and a
    type-name hands the initial state on to every variable of that type. }
  stars = packed array [1..8] of char value [1..8: '*'];

var
  v: vec; m: mat; p: pt; a: pts; s: shape; t: tree;
  banner: stars;
  origin: pt value [x: 0; y: 0];
  i, j, calls: integer;

procedure show(q: pt);
begin write('(', q.x:1, ',', q.y:1, ')') end;

{ A component-value is emitted once and copied into every component the
  selector names, so this is called once for the four components below. }
function bump: integer;
begin calls := calls + 1; bump := calls end;

begin
  { §6.8.7.2: the selector is a case-constant-list, so it may be a range or a
    list, and the array-value-completer gives every component not named. }
  v := vec[1: 10; 2..3: 20 otherwise 0];
  write('v'); for i := 1 to 4 do write(' ', v[i]:1); writeln;

  { A component-value may itself be a structured value, and takes the type of
    the component it is for rather than naming one. }
  m := mat[1: vec[otherwise 7]; 2: vec[1..4: 8]];
  write('m');
  for i := 1 to 2 do for j := 1 to 4 do write(' ', m[i][j]:1);
  writeln;

  p := pt[x: 1; y: 2];
  write('p '); show(p); writeln;

  { §6.8.7.3 NOTE 1: one field-value may name several fields, and they all
    then have the same type and the same value. }
  a := pts[1: pt[x: 3; y: 4]; 2: pt[x, y: 9]];
  write('a '); show(a[1]); show(a[2]); writeln;

  { A variant-part-value with a tag-field-identifier stores the tag; without
    one the variant part is tagless and nothing is stored. }
  s := shape[n: 1; case kind: box of [w: 6; h: 7]];
  writeln('s ', s.n:1, ' ', ord(s.kind):1, ' ', s.w:1, ' ', s.h:1);

  s := shape[n: 2; case circle of [r: 1.5]];
  writeln('s ', s.n:1, ' ', ord(s.kind):1, ' ', s.r:1:1);

  t := tree[id: 7; case tag: node of
              [case hue: green of [cool: 42]]];
  writeln('t ', t.id:1, ' ', ord(t.tag):1, ' ', ord(t.hue):1, ' ', t.cool:1);

  { A structured value is a primary, so it may be an actual value parameter. }
  show(pt[x: 5; y: 6]); writeln;

  writeln('b [', banner, ']');
  write('o '); show(origin); writeln;

  calls := 0;
  v := vec[1..4: bump];
  write('c ', calls:1);
  for i := 1 to 4 do write(' ', v[i]:1);
  writeln
end.
