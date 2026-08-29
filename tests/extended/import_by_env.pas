{ The same resolution as `import_by_name.pas`, reached through the
  **environment** rather than through a flag (ADR-0244).

  This is the shape a compiler that has been *installed* is used in: a program
  is written anywhere, `AFTERSCHOOL_PASCAL_PATH` says where the library went,
  and no command line mentions either. Turbo Pascal called the same thing its
  unit directories, and the reason it is a variable and not only a flag is
  that a flag has to be repeated on every line.

  Its sidecar exercises what only a variable can hold: two directories
  separated by a colon, an **empty** entry -- which is skipped rather than
  taken for the working directory, since that is what POSIX says of `PATH` and
  is a surprise nobody wants from a compiler -- and a trailing separator on
  one of the directories, since a person writes a directory both ways and the
  compiler puts it right in the one place both arrive at.

  The first entry names a directory that has nothing in it, so the second is
  what answers: a search that stopped at the first directory rather than at
  the first *file* would not compile this. }
program import_by_env(output);

import bynamemid;

begin
  midBump(10);
  writeln('program: mid tally  = ', midTally:1)
end.
