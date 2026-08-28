{ What §6.5.6 and §6.8.6.5 refuse, and each refusal's reason.

  Sema accumulates, so these share a file — unlike a grammar refusal, which
  stops the parser at the first one. }
program SubstringErrors(output);
type name = string(20);
var s: name; n: integer; a: array [1..4] of integer;

function greeting = t: name;
begin t := 'hello' end;

procedure bump(var t: name);
begin t := t + '!' end;

{ §6.5.6's last sentence: "A reference or an access to a substring of a
  variable shall constitute a reference or access, respectively, to the
  variable." So a substring stays *inside* the variable exactly as a subscript
  does — and §6.5.1's rule about a protected variable therefore reaches through
  one. Without that, `t[1..2] := 'zz'` is a way to write to a protected
  parameter, and both compilers had a mutation survive a green suite for want
  of this program. }
procedure guard(protected var t: name);
begin
  t[1..2] := 'zz'
end;

begin
  s := 'abcdef';

  { §6.5.6's string-variable must possess a string-type, and ADR-0125 gives
    `a[i..j]` over an array to the slice instead -- so what is refused here is
    no longer the notation but what `write` will take: a slice is not a value
    it has a form for. }
  writeln(a[1..2]);

  { The index-expressions "shall possess the integer-type" — not an ordinal
    type, because a string's index-domain is 1..length and no type names it. }
  writeln(s['a'..'c']);

  { §6.7.3.3 NOTE 3: an actual variable parameter cannot denote a
    substring-variable, because its type is a new fixed-string-type different
    from every named type — so no formal can have been declared with it. }
  bump(s[1..3]);

  { §6.8.6.5's substring of a function-access is a *value*: the base is not a
    designator, so the substring is not one either, and there is nothing to
    assign to. }
  greeting[1..2] := 'ab';

  n := 1;
  writeln(n:1);
  guard(s)
end.
