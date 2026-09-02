{ AP 6.8.9's try-expression at depth (ADR-0297): four fallible routines across
  two modules, each propagating with `try`, and one program recovering at the
  top -- once by asking, once with ValueOr.

  It exists because the roadmap's usability pass asked whether `T ! E` and
  `try` still read well at depth and nothing here had ever put them there:
  the largest client is a server, which must answer every request and so
  never leaves a routine on a failure. This is the other shape, written out
  so the question has evidence rather than an opinion. What it found is in
  the record; the short form is that the chain is four one-line bodies, that
  a cause crosses every level without being named at any of them, and that
  the one thing a reader has to know is that `try` is a *function* leaving
  the block and not a statement guarding one. }
program try_depth(output);

import PasError;
       DepthLow;
       DepthHigh;

{ Recovery at the top, by asking. }
procedure Report(a, b: Pair);
var r: IntResult;
begin
  r := Average(a, b);
  write(a, '+', b, ': ');
  if r.ok then writeln('average ', r.val:1)
  else writeln('failed -- ', ErrorText(r.cause))
end;

begin
  Report('12', '34');   { every level succeeds: (12 + 34) div 2 }
  Report('12', '35');   { the top level fails: 47 is odd }
  Report('1x', '34');   { the bottom level fails, three levels down }
  Report('12', '3-');   { and the second pair fails after the first read }

  { Recovery at the top, by defaulting. }
  writeln(ValueOr(Average('40', '02'), -1):1, ' ',
          ValueOr(Average('4?', '02'), -1):1)
end.
