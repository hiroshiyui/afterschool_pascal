{ Where §6.6's initial-state-specifier may not go, and what its value may not
  be. Two of these are the standard's own rules and two are this compiler's,
  and the messages say which. }
program InitialStateErrors(output);
type colour = (red, green, blue);
     { §6.4.7 makes a schema body a type-denoter, so the word parses there —
       and a schema definition is spelled as a type definition, which is why
       this needs a reason of its own rather than "not here". Every tuple
       produces its own type, so the value would have to be attributed once
       per production. }
     vec(n: integer) = array [1..n] of real value 0.0;

var n: integer;
    { §6.8.2: the value shall be nonvarying, so it may not read a variable... }
    a: integer value n + 1;
    { §6.6 NOTE 3: the specifier belongs to the whole type-denoter, so
      `array [1..8] of char value '*'` is a violation — the value is for the
      array and a char is not one. §6.4.3.2 makes it so by forbidding a
      component-type from carrying one at all, which is why the component's
      denoter stops before the word and the array's takes it. }
    c: array [1..8] of char value '*';
    { the value still has to fit the type it initialises }
    d: colour value 3;
    { §6.4.3.6 gives a file the initial state totally-undefined, and a file has
      no value to bear in any case }
    f: text value 0;
    { §6.5.1 makes a variant's initial state conditional on the selector's own,
      which is not settled where the field is written }
    g: record
         case colour of
           red: (u: integer value 1);
           green, blue: (w: real)
       end;
    e: record m: integer end value 0;

function twice(x: integer): integer;
begin
  twice := x * 2
end;

{ §6.8.2 makes a *required* function nonvarying with nonvarying arguments and
  says nothing of the kind about a declared one, whose body may read anything —
  so this is refused where `chr(65)` is not. }
procedure late;
var m: integer value twice(2);
begin
  writeln(m:1)
end;

var w: vec(2);

begin
  n := 1;
  writeln(a:1);
  late
end.
