{ --dump-dispatch (ADR-0229): every case-statement in a source whose selector
  is an enumeration, with how many of that enumeration's constants its labels
  name.

  It exists because a case-statement with no matching label *stops the program*
  (ISO 7185 6.9.3.5, ADR-0018), so a constant left off one is a crash and not a
  wrong answer -- and the pair `names N of M` is what makes that findable: a
  constant added to the enumeration moves every M over it at once.

  The flag is ordinary and works on any program, which is what this case pins.
  Covered here: a case naming every constant, one naming a subset, one with an
  `otherwise` (which discharges coverage and is reported so), a subrange label
  spanning several constants, two cases in one routine so the ordinal counts,
  a case nested inside another so that source order and check order differ, a
  selector of a *subrange of* an enumeration, and -- reported by nothing -- a
  case over `char` and one over an integer, neither being an enumeration. }
program dispatch(output);

type
  colour = (red, green, blue, amber, cyan);
  narrow = green..amber;
  { a constant no case-statement names -- not a defect, but a fact worth
    holding, because a constant that stops being named is one something used
    to reach and no longer does }
  flag = (stopped, running, paused);
  { a record whose own `kind` field is what a chain dispatches on }
  tagged = record
    kind: colour;
    ready: boolean
  end;
  { and an enumeration no case-statement mentions at all, which is how
    stdKind looks: dispatched by a comparison and never by a case, so it
    reaches no site and only the *declarations* can find it }
  mode = (fast, slow, idle);

var
  c: colour;
  n: narrow;
  ch: char;
  i: integer;
  f: flag;
  m: mode;
  tg: tagged;
  { an enumeration with no type-definition has no name to report, so the dump
    writes `?` where one would go -- the type is still a type and the site is
    still a site }
  q: (alpha, beta, gamma);

{ every constant named }
procedure Total(x: colour);
begin
  case x of
    red:   writeln('r');
    green: writeln('g');
    blue:  writeln('b');
    amber: writeln('a');
    cyan:  writeln('c')
  end
end;

{ a subset, argued for by the caller and not by the compiler }
procedure Subset(x: colour);
begin
  case x of
    { a range label spans several constants, and each of them counts -- which
      is why the count is taken from the label *ranges* and not from the arms }
    red..green: writeln('warm');
    blue:       writeln('cool')
  end
end;

{ an otherwise discharges coverage; the dump says so rather than counting it }
procedure Completed(x: colour);
begin
  case x of
    red: writeln('r')
    otherwise writeln('other')
  end
end;

{ two in one routine, and the second nested inside the first: source order is
  what the ordinal follows, so the outer one is :1 although it finishes last }
procedure Nested(x: colour);
begin
  case x of
    red, green, blue:
      case x of
        red:   writeln('R');
        green: writeln('G');
        blue:  writeln('B')
      end;
    amber, cyan: writeln('-')
  end
end;

{ a subrange of an enumeration answers for its host (ADR-0018), so the total is
  the host enumeration's and not the subrange's }
procedure OfSubrange(x: narrow);
begin
  case x of
    green: writeln('g');
    amber: writeln('a')
    otherwise writeln('?')
  end
end;

{ two of three named, so the third is unused }
procedure Flagged(x: flag);
begin
  case x of
    stopped: writeln('s');
    running: writeln('r')
    otherwise writeln('?')
  end
end;

{ mode is only ever compared, never dispatched on }
function Quick(x: mode): boolean;
begin
  Quick := x = fast
end;

{ An if-chain is a dispatch too, and a constant left off one is the *opposite*
  failure from a case-statement's: it takes the trailing `else` in silence
  rather than stopping the program. A chain is a shape and not a node -- an if
  whose else-part is another if -- so the head here is the arm that tests no
  tag at all, and all three arms belong to one chain.

  `on kind` is what the dump reports and what tells a dispatch from a lookahead:
  this reads a record's own kind field, where `n = green` below reads a
  variable that merely happens to be of an enumeration. }
function Describe(r: tagged; n: flag): char;
begin
  Describe := '.';
  if r.ready then
    Describe := '!'
  else if r.kind = red then
    Describe := 'r'
  else if (r.kind = green) or (r.kind = blue) then
    Describe := 'g'
  { a chain naming one constant of a type is a question and not a dispatch, so
    this second enumeration is not reported at all }
  else if n = running then
    Describe := 'a'
end;

{ Two chains over one enumeration in one routine, so the ordinal counts as it
  does for case-statements -- and a tag test written under `not`, which is
  found because a condition is one expression however it is spelled. }
function Second(r: tagged): char;
begin
  Second := '.';
  if not (r.kind = red) then
    Second := 'x'
  else if r.kind = green then
    Second := 'y';
  if r.kind = blue then
    Second := 'b'
  else if r.kind = amber then
    Second := 'm'
end;

{ neither of these is an enumeration, and neither is reported }
procedure NotEnums(a: char; b: integer);
begin
  case a of
    'x': writeln('x')
    otherwise writeln('.')
  end;
  case b of
    1: writeln('one')
    otherwise writeln('many')
  end
end;

begin
  c := red; n := green; ch := 'x'; i := 1; f := stopped; m := fast;
  q := alpha;
  { a case-statement in the main program block belongs to no procedure, so the
    site is attributed to the program itself }
  case c of
    red:  writeln('main r');
    green, blue, amber, cyan: writeln('main other')
  end;
  case q of
    alpha: writeln('a');
    beta:  writeln('b')
    otherwise writeln('g')
  end;
  Total(c); Subset(c); Completed(c); Nested(c); OfSubrange(n); NotEnums(ch, i);
  Flagged(f); writeln(Quick(m));
  tg.kind := green; tg.ready := false;
  writeln(Describe(tg, running), Second(tg))
end.
