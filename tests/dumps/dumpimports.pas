{ A module a program in this same directory imports **without naming a file**
  (ADR-0244), and a dump case in its own right: a source that imports nothing
  reports no components, which is the other direction of the flag and the one
  a golden can only state by being empty.

  It is here rather than in a subdirectory because the search path's first
  entry is the *source's own directory*, always -- so `dumpimports.pas` beside
  `imports.pas` is the zero-configuration case, with no flag and no
  environment variable involved at all. }
module dumpimports;

export dumpimports = (Doubled);

function Doubled(n: integer): integer;
end;

function Doubled;
begin
  Doubled := n * 2
end;

end.
