{ `halt(n)` -- this processor's exit status, and its only language extension
  beyond the underscore in an identifier.

  ISO/IEC 10206:1991 §6.7.5.7 gives `halt` no parameters, and neither standard
  models a process exit status at all: a program that completes normally, a
  program that calls `halt`, and a program stopped by an error are all just
  "no further processing" as far as clause 3.6 is concerned. So there is no
  spelling to take from the standard here, which is the test every other
  extension in this project has been refused by.

  It is added because a compiler written in Pascal has to be able to say that
  it failed. `pascalc` is that compiler, and without this
  `pascalc bad.pas && clang bad.ll ...` runs the linker on a file that was
  never written (ADR-0084).

  No conforming program's meaning changes, and this file cannot show that
  directly -- what it shows is the boundary: `halt` alone still means what
  §6.7.5.7 says, and `halt(1)` was a compile-time error until this landed.
  `tests/extended/required_errors.pas` holds the two forms still refused.

  The status itself is checked by the harness rather than by this program:
  halt_status.err is empty, so run_test.sh requires a *non-zero* exit and
  compares what was written before it. }
program HaltStatus(output);

var i: integer;

procedure Deeper;
var f: text;
begin
  { §6.7.5.7 makes a halt leave every block without running its epilogue, so
    the runtime closes what these blocks opened -- the same obligation a
    non-local goto discharges, through the same list (ADR-0032). A status
    changes nothing about that, which is the point of putting the halt three
    frames deep rather than in the main block. }
  rewrite(f);
  writeln(f, 'a file this block will never close itself');
  writeln('about to halt from a nested block');
  halt(3)
end;

procedure Outer;
var g: text;
begin
  rewrite(g);
  writeln(g, 'and neither will this one');
  Deeper;
  writeln('not reached')
end;

begin
  { The status is an ordinary integer expression, not a literal: nothing about
    it is special to the parser, and Sema asks only that it be an integer. }
  i := 1;
  writeln('status will be ', i + 2:1);
  Outer;
  writeln('not reached either')
end.
