{ ISO/IEC 10206:1991 §6.6's initial-state-specifier:

    type-denoter            = [ 'bindable' ] ( ... ) [ initial-state-specifier ]
    initial-state-specifier = 'value' component-value .

  "The initial state specified by an initial-state-specifier shall be the state
  bearing the value denoted by the component-value", and §6.2.3.5: "Each
  variable contained by an activation of a block ... shall be created in its
  initial state within the commencement of the activation."

  Two things follow that this program is written to show. The specifier belongs
  to the *type-denoter* and not to the declaration, so a type definition hands
  it to every variable of that type; and it is attributed at every *activation*,
  so a local of a procedure is initialised again on each call rather than once. }
program InitialState(output);
const base = 10;

type count = integer value 7;
     { a type-name denotes "the type, bindability and initial state" of its
       definition (§6.4.1), so this inherits `count`'s }
     tally = count;
     colour = (red, green, blue);
     { a record's fields may each carry one, and then the record has an initial
       state without one of its own being written }
     point = record
               x: integer value 1;
               y: integer value 2
             end;
     { ...and a record with a nested record picks up that record's, too }
     line = record
              a: point;
              b: point;
              tag: colour value blue
            end;

var i: count;
    j: tally;
    { §6.8.2's *nonvarying*, which is not "the compiler folds it": what matters
      is that the expression reads nothing that can change. So an operator and
      a required function are both allowed here. }
    k: integer value base * 2 + 1;
    c: char value chr(base * 6 + 5);
    o: colour value succ(red);
    s: set of 1..9 value [2, 4..6];
    p: ^point value nil;
    r: real value 1.5;
    b: boolean value 3 > 2;
    q: point;
    l: line;
    { one denoter for the group, so one value for both names }
    u, v: integer value 99;

{ §6.2.3.5 excludes a formal parameter from being created in an initial state:
  a value parameter is the *argument's* value, and a var parameter is the
  caller's variable. This one's type is a record whose fields each carry a
  specifier, which is the only shape where the difference shows — the argument
  would otherwise be silently replaced by the field defaults. }
procedure viaParam(q: point; var r: point);
begin
  writeln('param ', q.x:1, q.y:1, ' ', r.x:1, r.y:1)
end;

{ Each activation is created in the initial state, so this prints the same
  number every time however many times it is called — which is the whole
  difference between an initial state and an initialisation done once. }
procedure counted;
var n: integer value 41;
begin
  n := n + 1;
  writeln('n ', n:1)
end;

{ ...including through recursion, where the inner activation's initial state is
  attributed while the outer one's variable already holds something else. }
procedure nested(depth: integer);
var local: integer value 5;
begin
  local := local + depth;
  if depth > 0 then nested(depth - 1);
  writeln('depth ', depth:1, ' local ', local:1)
end;

begin
  writeln(i:1, ' ', j:1, ' ', k:1);
  writeln(c, ' ', ord(o):1, ' ', r:3:1, ' ', b);
  writeln(2 in s, ' ', 3 in s, ' ', 5 in s, ' ', p = nil);
  writeln(q.x:1, q.y:1, ' ', l.a.x:1, l.a.y:1, l.b.x:1, l.b.y:1, ' ',
          ord(l.tag):1);
  writeln(u:1, ' ', v:1);
  q.x := 8; q.y := 9;
  viaParam(q, l.b);
  counted; counted; counted;
  nested(2)
end.
