{ `--range` refuses a span it cannot use, rather than widening to the whole
  file (ADR-0284). Silently formatting everything where a fragment was asked
  for is the kind of answer that gets diagnosed as an editor fault; one test
  decides it and one message covers every way of getting it wrong -- a letter
  in the span, no colon, a zero, a second colon, or the ends the wrong way
  round. This case sends the last of those. }
program rangerefused(output);
begin
  writeln('never formatted')
end.
