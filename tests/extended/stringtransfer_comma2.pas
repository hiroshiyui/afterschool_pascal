{ The writestr half of stringtransfer_comma.pas: §6.7.5.5's first comma is
  part of that parameter list too, so a writestr given only the string it
  writes to has nothing to write.

  Its message is the one that had never been reachable. While the comma was
  the parser's rule this statement could not be written, so the check for it
  sat only on the ordinary-write path; ADR-0087 made the case reachable and
  the check had to be written on this one as well. }
program StringTransferComma2(output);
type s8 = string(8);
var s: s8;
begin
  writestr(s);
  writeln(s)
end.
