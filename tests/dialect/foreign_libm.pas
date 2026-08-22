{ The three libm names the compiler used to keep for itself, in the one program
  that proves the fix: it calls `arctan`, `abs` of a complex and `arg` of a
  complex -- which is what made the emitter declare `atan`, `hypot` and `atan2`
  -- *and* declares all three as foreign routines of its own, in the same
  compilation.

  Before the wrappers this file did not compile. LLVM refuses a second
  declaration of any global however identical the two are, so the emitted
  module and the program were asking for the same name and the assembler
  stopped; ADR-0121 turned that into a diagnostic and reserved five names.
  Three of them are gone now: the emitter calls `pas_atan`, `pas_atan2` and
  `pas_hypot`, which are three lines of runtime/pasrt.c, and the names belong
  to the program.

  The two still reserved are in tests/dialect/foreign_types.pas, and neither
  can move. `main` is the entry point. `_setjmp` has to be called in the frame
  `longjmp` returns to (6.8.2.4's non-local goto, 6.9.2.4 under Extended
  Pascal), so a wrapper would return before the jump ever happened -- which is
  a fact about setjmp and not about this compiler. }
program foreign_libm(output);

function hypot(x, y: real): real; external 'hypot';
function atan2(y, x: real): real; external 'atan2';
function atan(x: real): real; external 'atan';

var
  z: complex;

begin
  z := cmplx(3.0, 4.0);

  { The compiler's own uses: 6.7.6.2 makes `abs` of a complex its magnitude and
    `arg` its argument, and each yields a real. }
  writeln('complex abs = ', abs(z):0:1);
  writeln('complex arg = ', arg(z):0:4);
  writeln('arctan 1    = ', arctan(1.0):0:4);

  { ...and the program's, on the same three C functions, reached by name. }
  writeln('hypot 3 4   = ', hypot(3.0, 4.0):0:1);
  writeln('atan2 4 3   = ', atan2(4.0, 3.0):0:4);
  writeln('atan 1      = ', atan(1.0):0:4)
end.
