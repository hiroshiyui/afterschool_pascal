program NestedVariants(output);
{ ISO 7185 6.4.3.3: an arm's field-list is a field-list like any other, so it
  may end with a variant part of its own, to any depth. This compiler used to
  reject that (ADR-0018 recorded the gap); ADR-0026 closes it.

  The record below is the shape that makes the layout interesting: the second
  level has a `real` in one arm and a `char` in another, so the shared storage
  has to be aligned and sized for the largest arm at *both* levels. }

type
  kind = (leaf, branch);
  weight = (light, heavy);
  shade = (red, blue);

  node = record
    id: integer;
    case k: kind of
      leaf: (value: real);
      branch: (count: integer;
               case w: weight of
                 light: (feather: char);
                 heavy: (stones: integer; ounces: real))
  end;

  { A tagless nested part, and one nested two deep, so neither form is left
    uncompiled. `case T of` has the tag as a type but not as a field. }
  deep = record
    tag: char;
    case integer of
      1: (a: integer;
          case boolean of
            true: (b: char;
                   case colour: shade of
                     red: (r: integer);
                     blue: (s: real));
            false: (c: real));
      2: (d: char)
  end;

var
  n: node;
  d: deep;

begin
  n.id := 7;
  n.k := branch;
  n.count := 2;
  n.w := heavy;
  n.stones := 14;
  n.ounces := 0.5;
  writeln('heavy: ', n.id:1, ' ', n.count:1, ' ', n.stones:1, ' ',
          n.ounces:3:1);

  { the other arm of the nested part shares the same storage }
  n.w := light;
  n.feather := 'q';
  writeln('light: ', n.id:1, ' ', n.count:1, ' ', n.feather);

  { the outer arm, which the nested part is not part of }
  n.k := leaf;
  n.value := 1.25;
  writeln('leaf: ', n.id:1, ' ', n.value:4:2);

  d.tag := 'x';
  d.a := 3;
  d.b := 'y';
  d.colour := blue;
  d.s := 2.5;
  writeln('deep: ', d.tag, d.b, ' ', d.a:1, ' ', d.s:3:1);
  d.colour := red;
  d.r := 11;
  writeln('deep: ', d.a:1, ' ', d.r:1)
end.
