{ AP 6.7.7.11 scopes "one linker symbol, one external-declaration" to **one
  program-component**, and this program is the second component.

  The compiler enforced it over the whole compilation instead (ADR-0147), so a
  program could not bind a C function that any module it imported happened to
  bind privately -- and as `lib/` grew, that surface grew with it: a program
  importing PasNet could not name `pasx_socket_fd`, PasProcess `popen`, PasIO
  `read`. The diagnostic named the *module's* routine, which the program
  cannot see and did not write.

  The clause is right and the check was wrong. A foreign declaration in an
  imported component contributes nothing to this component's module: the
  client calls the module's Pascal routine by its linkage name, and the
  foreign call sits in the module's own object.

  **Except once**, which is the second half of this case. AP 6.7.3.10.2
  translates an instantiation in the component that named the types, so
  `Doubled(1)` below emits the generic's body *here* -- and with it a
  `declare` for `strlen`, beside the one this program's own heading emits. Two
  declarations of one global is what LLVM refuses. The second is dropped at
  emission rather than the program being refused, which is where the problem
  belongs: Sema asks the clause's question about a component, and the emitter
  asks its own about a module. }
program foreign_shared_symbol(output);

import SharedForeign;

{ The same linker symbol the imported module binds, under a name of this
  program's own choosing. }
function MyLength(s: string): int64; external 'strlen';

begin
  { The generic, whose body calls the module's own binding of the symbol --
    translated here, so this module declares `strlen` for it. }
  writeln('generic : ', Doubled(1):1);
  { And this program's own binding of the same symbol. }
  writeln('direct  : ', trunc(MyLength('abcde')):1);
  writeln('both    : ', trunc(MyLength('')) = 0)
end.
