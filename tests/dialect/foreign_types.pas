{ ADR-0121's type mapping, in the direction that refuses. Sema accumulates, so
  one file carries every refusal that is not a parse error.

  The mapping is by *exact* type and not by Base(t), which reverses ADR-0018
  everywhere else in this compiler: `sub` below is an integer subrange and is
  an integer everywhere -- and across this boundary nothing promises its
  values are in range, so it does not cross.

  ADR-0122 added the address rows, and most of what is refused below is
  refused *by that record*: a capacity, a fixed length, and every direction
  that would hand a pointer back. }
program foreign_types(output);
type sub = 1..9;
     colour = (red, green);
     fixed = packed array [1..3] of char;
var i: integer;
    c: char;
    t: string(20);

function pchar(c: char): integer; external 'f1';
function pbool(b: boolean): integer; external 'f2';
function psub(s: sub): integer; external 'f3';
function penum(c: colour): integer; external 'f4';
function rchar(n: integer): char; external 'f6';
function rsub(n: integer): sub; external 'f7';

{ ADR-0122. A `var` parameter crosses, but only of a type that crosses: the
  address is of the actual's storage, and `char` has no agreed width there any
  more than it has as a value. }
function vchar(var c: char): integer; external 'f8';

{ A string crosses as `const char *`, which carries its length in-band -- so
  a capacity is a promise nothing on the other side keeps, and a fixed length
  is one nothing states. One spelling, `string`, and no second rule. }
function pcap(s: string(20)): integer; external 'f9';
function pfix(s: fixed): integer; external 'f10';

{ And no pointer comes back, in either shape. A returned `char *` may be null
  -- `getenv` of a name that is not set is not a failure -- and this language
  has no optional type to say so in (ADR-0109). }
function rstr(n: integer): string(20); external 'f11';
function vstr(var s: string): integer; external 'f12';

{ A procedural parameter is a code-and-link pair on this side (ADR-0030), and
  the link is the half with no image at all. }
function pproc(function g(x: integer): integer): integer; external 'f13';

{ The one string formal here that is *admitted*, so that the rule about the
  actual has something to be checked against: `string` names a `const char` pointer
  and the actual has only to be a string. }
function pstr(s: string): integer; external 'f14';

function twice(x: integer): integer;
begin twice := x + x end;

{ The name is the linker's, so it cannot be empty and cannot be one this
  compiler already emits for something of its own -- LLVM's assembler refuses
  a second declaration of any global however identical the two are. }
function blank(n: integer): integer; external '';
function taken(n: integer): integer; external '_setjmp';
function counter(n: integer): integer; external 'p3';
function entry(n: integer): integer; external 'main';
function runtime(n: integer): integer; external 'pas_new';

begin
  i := 0;
  c := 'a';
  writeln(pchar('a') + pbool(true) + psub(1) + penum(red) + vchar(c));
  writeln(pcap('x') + pfix('abc') + vstr(t));
  writeln(pproc(twice) + pstr(3) + pstr('ok'));
  writeln(ord(rchar(1)) + rsub(1) + length(rstr(1)));
  writeln(blank(1) + taken(1) + counter(1) + entry(1) + runtime(1))
end.
