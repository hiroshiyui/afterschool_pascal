{ ISO 7185 §6.2.1 fixes the order of a block's declaration parts.

      block = label-declaration-part constant-definition-part
              type-definition-part variable-declaration-part
              procedure-and-function-declaration-part statement-part .

  Each of the five is optional, appears at most once, and only after the ones
  before it. ISO/IEC 10206:1991 §6.2.1 makes the same five a *repetition* in
  any order — which §6.2.2.9 then needs, a defining-point having to precede its
  applied occurrences — and `tests/extended/declorder.pas` is that program.

  ADR-0069 taught Sema to read the parts in written order, having found it
  imposing ISO 7185's fixed order on Extended Pascal. It went one step further
  than that and stopped checking the order in *either* standard, and nothing
  noticed for the same reason as ever: three ISO programs in the corpus were
  themselves out of order, so they went on passing, and no program was there to
  fail (ADR-0072).

  Every error below is a part that cannot stand where it is written. The
  procedure-and-function-declaration-part is the one that may repeat, because
  the grammar makes it a list of procedures rather than a part per procedure. }
program declorder_iso_errors(output);

const
  first = 1;

type
  small = 1..9;

var
  a: small;

{ A second constant-definition-part. One `const` reads a whole run of
  definitions, so a second keyword is a second *part* and not a continuation. }
const
  second = 2;

{ A type-definition-part after the variables. }
type
  other = 1..4;

{ And a variable-declaration-part after that. }
var
  b: other;

procedure one;
begin
end;

{ Two procedures in a row are one part and legal — this is the case the rule
  must not refuse. }
procedure two;
begin
end;

{ A label-declaration-part is first of all five, so anywhere but the top is
  wrong however little else there is. }
label
  1;

begin
  a := first;
  b := second;
  1: writeln(a:1, b:1)
end.
