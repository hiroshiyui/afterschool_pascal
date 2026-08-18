{ ADR-0121's type mapping, in the direction that refuses. Sema accumulates, so
  one file carries every refusal that is not a parse error.

  The mapping is by *exact* type and not by Base(t), which reverses ADR-0018
  everywhere else in this compiler: `sub` below is an integer subrange and is
  an integer everywhere -- and across this boundary nothing promises its
  values are in range, so it does not cross. }
program foreign_types(output);
type sub = 1..9;
     colour = (red, green);
var i: integer;

function pchar(c: char): integer; external 'f1';
function pbool(b: boolean): integer; external 'f2';
function psub(s: sub): integer; external 'f3';
function penum(c: colour): integer; external 'f4';
function pvar(var n: integer): integer; external 'f5';
function rchar(n: integer): char; external 'f6';
function rsub(n: integer): sub; external 'f7';

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
  writeln(pchar('a') + pbool(true) + psub(1) + penum(red) + pvar(i));
  writeln(ord(rchar(1)) + rsub(1));
  writeln(blank(1) + taken(1) + counter(1) + entry(1) + runtime(1))
end.
