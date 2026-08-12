(* ISO/IEC 10206:1991 §6.2.1: the declaration parts of a block, in any order
   and as often as they like. The standard's production makes the block an
   import-part, then a *repetition* of the label, constant, type, variable and
   procedure-and-function parts in any order, then the statement-part.

   ISO 7185 §6.2.1 fixes that order — const, then type, then var — and Sema had
   been imposing it on both standards by checking every constant before every
   type. §6.2.2.9 then requires a defining-point to precede each applied
   occurrence of it, so *written* order is the only order that can be right,
   and this program compiles only if that is the order used (ADR-0069).

   It is the first thing a structured constant needs, since one names a type.

   This comment is bracketed the other way because the standard's production
   is written with braces, and a Pascal comment does not nest. *)
program declorder(output);

type
  colour = (red, green, blue);

{ A constant naming an enumeration constant: `red` exists only after the type
  part above, which under ISO 7185's fixed order could never happen. }
const
  favourite = green;
  count     = 3;

{ A second type part, using the constant part between the two. }
type
  tally = array [colour] of integer;
  small = 1..count;

var
  t: tally;
  s: small;

{ A third const part, after a variable part, naming a type from the first. }
const
  brightest = blue;

var
  c: colour;

begin
  for c := red to blue do
    t[c] := ord(c) * 10;
  s := count;
  writeln(ord(favourite):1, ' ', ord(brightest):1, ' ', s:1);
  writeln(t[red]:1, ' ', t[green]:1, ' ', t[blue]:1)
end.
