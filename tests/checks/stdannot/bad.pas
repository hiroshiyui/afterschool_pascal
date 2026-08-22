{ @std:pascal -- a misspelling. Reported rather than ignored: an annotation
  that silently did nothing would compile the file under a standard its author
  had said it was not. }
program bad(output);
begin writeln('unreachable') end.
