{ §6.4.2.2 b)'s three constants are required *identifiers*, not word-symbols,
  so a program may declare its own — and its own is what the names then mean.
  They are declared in the outermost scope, which is what makes shadowing them
  an ordinary redeclaration rather than a special rule. }
program realconsts_shadow(output);
const maxreal = 7;
type minreal = (a, b, c);
var epsreal: minreal;
begin
  epsreal := b;
  writeln(maxreal:1, ' ', ord(epsreal):1)
end.
