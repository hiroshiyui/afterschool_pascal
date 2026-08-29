{ What --dump-uses does about a file that does not check (ADR-0246).

  Every other dump here is guarded by `not errorSeen`, because it shows one
  stage's result and a stage that failed has none. This one is not a result;
  it is one line per name, and Sema accumulates its diagnostics rather than
  stopping at the first -- so a source with three mistakes in it has resolved
  everything else correctly, and that is most of the file.

  It matters because of who asks. An editor asks where a name is declared
  exactly while the file is being edited into shape, which is to say while it
  does not compile; a go-to-definition that went blank on the first typo
  would be a go-to-definition nobody could use. --dump-symbols answers the
  same objection by stopping before Sema (ADR-0239) and this one cannot, a
  defining-point being Sema's to know.

  The golden below therefore holds diagnostics and `use` lines interleaved on
  one stream -- no standard Pascal program has a second one -- and the case
  carries a `.status` sidecar saying the compiler is expected to exit 1. Read
  the diagnostics as part of the subject and not as noise: what is being
  pinned is that `total`, `flag` and `count` are all still answered while
  three other names are not.

  `abs` is here for one word of vocabulary. A required *function* is a symbol
  in the region enclosing the program (6.2.2.10) and its kind is `required`;
  it is not a type, so naming one in a type-denoter is refused -- and this is
  the only position in which that word reaches the dump at all, since
  LookupUser turns the marker back into nil everywhere else (ADR-0087). }
program uses_broken(output);

type t = abs;

var
  total: integer;
  flag: boolean;
  count: integer;

begin
  total := 1;
  count := total + 1;
  flag := count > undeclared;
  total := notafunction(count);
  writeln(total, count, flag)
end.
