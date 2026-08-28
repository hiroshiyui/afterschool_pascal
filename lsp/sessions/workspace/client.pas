{ The top of the workspace: a program, with `client.components` beside it
  naming the two modules under it and not naming this file.

  That is the ordinary shape -- a case and its sidecar -- and the answer for
  it is every entry the sidecar holds. The shape it does *not* cover is
  `selfhost/compiler.components`, which sits beside `compiler.pas` and names
  it: there the answer is the prefix, because handing a component its own
  interface is what `tests/run_test.sh` is careful not to do. }
program client(output);

import Middle;

begin
  writeln(Doubled:1)
end.
