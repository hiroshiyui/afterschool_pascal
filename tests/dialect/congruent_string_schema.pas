{ A schematic string value formal may stand where a produced string type is
  written (AP 6.7.3.6, ADR-0290), so one routine serves every capacity.

  ISO/IEC 10206:1991 6.7.3.6 a) 4) offers three ways two value-parameter-
  sections match, and each names *both* headings: both parameter-forms a
  schema-name, or both a type-name of the same type, or both a type-name
  produced from the same schema. The mixed pair -- a schema-name against a
  type produced from it -- is in none of them, so `Hash(key: string)` could
  not be handed to a formal written `function h(k: Key200)` however plainly
  it would have worked.

  It works because a string is the one schema whose values carry the
  discriminant the schematic form needs: 6.4.3.3.3 makes a string value a
  length and that many characters, so a value parameter of `string(200)` and
  one of `string` are both a pointer and a length (ADR-0051, ADR-0115) and
  the two headings call the same way. That is why the rule is this narrow --
  `Box(5)` passes its address alone where `Box` passes an address and a
  discriminant, and the pair below would be a call through the wrong
  signature. }
program congruent_string_schema(output);
type Key63 = string(63);
     Key200 = string(200);
var short: Key63; long: Key200;

{ one pair, no capacity written }
function Hash(key: string): integer;
var i, h: integer;
begin
  h := 0;
  for i := 1 to length(key) do h := (h * 31 + ord(key[i])) mod 1000003;
  Hash := h
end;

function Eq(a, b: string): boolean;
begin Eq := a = b end;

{ two callers whose procedural formals name two different produced types --
  neither of which the pair above mentions }
function Reduce63(k: Key63; function h(x: Key63): integer): integer;
begin Reduce63 := h(k) end;

function Same200(a, b: Key200;
                 function e(x, y: Key200): boolean): boolean;
begin Same200 := e(a, b) end;

{ And it is **contravariant** one level in, which is what a nested procedural
  parameter needs. `Drive` declares its parameter's inner formal schematically
  and hands `Hash` over; `TakesFixed`, the routine passed as that parameter,
  calls what it received through a formal naming a produced type. So the
  schematic routine is the one being passed *inside*, and the pair to compare
  is this one reversed -- congruity is asked of the actual's inner heading
  against the declared one. It read the same way round until this rule had a
  direction, and nothing could have noticed while it was symmetric. }
function TakesFixed(function r(y: Key63): integer): integer;
begin TakesFixed := r('abcd') end;

function Drive(function outer(function inner(x: string): integer): integer):
               integer;
begin Drive := outer(Hash) end;

begin
  short := 'abc';
  long := 'abc';
  writeln('one hash, two capacities: ',
          Reduce63(short, Hash):1, ' ', Hash(long):1);
  writeln('one equality: ', Same200(long, long, Eq),
          ' ', Same200(long, 'other', Eq));
  writeln('contravariant one level in: ', Drive(TakesFixed):1)
end.
