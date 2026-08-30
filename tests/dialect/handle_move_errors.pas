{ What AP 6.4.12.7 did **not** widen.

  A handle joins the owned pointer in `take`; a file does not and will not.
  A file is `IsMemory` -- several words the runtime is holding -- so there is
  no value in it one variable can stop holding, which is the sentence the
  refusal was written with and which is still true of exactly one of the three
  affine kinds. That is why the test is `IsOwned or IsHandle` and not
  `IsAffine`.

  Sema accumulates, so every one of these is reported in a single run. }
program handle_move_errors(output);

type Stream = handle external 'fclose';
     Node = record v: integer end;
     Own = owned ^Node;

function ExtFopen(path, mode: string): Stream; external 'fopen';

var a, b: Stream; f: text; n: integer; o: Own;

begin
  a := ExtFopen('/dev/null', 'w');

  { A file has no move, and the message says which kinds do. }
  b := take(f);

  { Nor has anything else. }
  b := take(n);

  { The plain copy is still refused, and the message now names all three
    things a handle may be assigned. }
  b := a;

  { `take` still empties a *variable*. }
  b := take(ExtFopen('/dev/null', 'w'));

  { And it still stands only as the whole right side of an assignment to a
    variable of its own type -- so a handle cannot be moved into an argument,
    which is what keeps a moved value owned by exactly one variable. }
  n := ord(take(a) <> nil);

  { The types must be the same one: two handle-types are two types however
    alike their closers. }
  o := take(a);

  writeln(n)
end.
