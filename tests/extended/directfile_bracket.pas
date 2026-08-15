{ 6.4.3.6's direct-access file writes its index-type in brackets --
  `file [T] of C` -- so the ']' that closes it has its own context. }
program DirectFileBracket(output);
type f = file [1..10 of integer;
var g: f;
begin
end.
