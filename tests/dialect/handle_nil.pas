{ AP 6.4.12.2's second form of assignment: `h := nil` (ADR-0202).

  A handle is released when the variable holding it dies, and until this landed
  that was the only way -- 6.4.12.2 gave the type exactly one assignment, from
  an external function of its own type, so a program could not close a stream
  before its block ended except by opening another one. Both libraries built on
  the handle did exactly that: `PasStream.Close` and `PasDir.Close` each opened
  the *empty path*, which POSIX refuses, for an assignment whose answer is
  always null. One refused system call and a stale errno apiece, and a
  diagnostic that named the wrong path.

  `nil` is not a value of a handle-type; it is the empty state, which is why
  6.4.12.2 already admitted it on the right of `=`. The assignment releases
  what the variable holds and leaves it empty, which is what the block exit
  does and what `pas_handle_set` already did -- so this is one Sema arm and no
  lowering.

  The loop is the evidence that the release happens. Two thousand streams
  through one variable, each closed by `h := nil`: `tests/run_test.sh` runs
  every case under `ulimit -n 256`, so without the release this stops at about
  the two hundred and fiftieth. That is the same argument `str_arena_loop.pas`
  makes for the string arena, and it needs the same thing to be true of the
  harness -- a bound low enough that exhausting it is cheap.

  The path is the harness's own per-run one, taken from a bindable
  program-parameter the way `lib_stream.pas` takes it. }
program handle_nil(output, fresh);

type Stream = handle external 'fclose';

function Open(path, mode: string): Stream; external 'fopen';

var fresh: bindable text;
    path: string(255);
    s: Stream;
    i, opened: integer;

begin
  path := binding(fresh).name;

  { Something to open. The stream is closed by the assignment below, which is
    what makes the file complete -- fputs is buffered until the close. }
  s := Open(path, 'w');
  writeln('created:     ', s <> nil);
  s := nil;

  s := Open(path, 'r');
  writeln('opened:      ', s <> nil);

  s := nil;
  writeln('closed:      ', s = nil);

  { Releasing an empty handle is not an error: the runtime releases what the
    variable holds, and it holds nothing. }
  s := nil;
  writeln('and again:   ', s = nil);

  { And the variable is usable afterwards, which is the whole point -- a
    library's Close leaves an object its caller may open again. }
  s := Open(path, 'r');
  writeln('reopened:    ', s <> nil);
  s := nil;

  { Two thousand opens through one variable. Every one is closed by the
    assignment below it, so the descriptor table never grows. }
  opened := 0;
  for i := 1 to 2000 do begin
    s := Open(path, 'r');
    if s <> nil then opened := opened + 1;
    s := nil
  end;
  writeln('opened 2000: ', opened:1)
end.
