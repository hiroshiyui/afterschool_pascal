{ ISO/IEC 10206:1991 §6.8.8.1: "The value and type of a constant-access shall be
  the value and type, respectively, either of the constant-name of the
  constant-access or of the indexed-constant, field-designated-constant, or
  substring-constant of the constant-access-component."

  So `row = grid[2]` gives row the value §6.8.8.2 says the indexed-constant
  denotes, and `B = H.b` gives B the value §6.8.8.3 says the
  field-designated-constant denotes. Both are the clause's own examples one
  step on -- §6.3's Examples has `UnitDistance = Unit.r` and
  `column1 = BlankCard[1]`, and those two are *scalar* components, which is
  exactly the half that worked.

  A structured one did not. §6.8.7's constructor has no LLVM initialiser, so
  its constant is a zeroed global filled by the prologue of the block that
  defined it (ADR-0069) -- and the test for "the block that defined it" was
  whether the folded node is the written expression, which a constant-access is
  not. So the component's node was memoised into a global of its own that
  nothing ever filled, and every one of these names read as all-zero, silently:
  `row[i]` printed 0 where `grid[2][i]` printed the right number, in one
  program.

  Not every component: a string, a set and a whole-constant alias were right,
  and they are here as the controls that say the fix is about the one case.

  Extended Pascal only: ISO 7185 §6.3's `constant` is a signed literal or a
  name, so there is no constant-access in it at all. }
program ConstAccessComponent(output);

type
  inner  = array [1..3] of integer;
  outer  = array [1..2] of inner;
  rs     = record nm: string(8); n: integer end;
  holder = record a: rs; b: rs end;
  st     = set of 1..9;
  sets   = record p: st; q: st end;

const
  grid = outer[1: inner[1:1; 2:2; 3:3]; 2: inner[1:4; 2:5; 3:6]];
  { §6.8.8.2's indexed-constant, selecting a component that is itself an array }
  row  = grid[2];
  { and a second name for the same component, to show the two do not fight
    over one storage }
  row2 = grid[2];
  { §6.8.8.3's field-designated-constant, selecting a record }
  H    = holder[a: rs[nm: 'one'; n: 1]; b: rs[nm: 'two'; n: 2]];
  B    = H.b;
  { a component of a component, which is the same rule twice }
  BN   = H.b.nm;
  { the controls: a whole-constant alias, a string component and a set
    component were all correct before the fix and must stay so }
  same = grid;
  A2   = H.a;
  S    = sets[p: st[1,2]; q: st[3,4]];
  SQ   = S.q;

var i: integer;

begin
  for i := 1 to 3 do write(row[i]:1);
  write(' ');
  for i := 1 to 3 do write(row2[i]:1);
  writeln;
  writeln(B.nm, ' ', B.n:1);
  writeln(BN, ' ', A2.nm, ' ', A2.n:1);
  for i := 1 to 3 do write(same[1][i]:1);
  writeln;
  for i := 1 to 9 do if i in SQ then write(i:1);
  writeln
end.
