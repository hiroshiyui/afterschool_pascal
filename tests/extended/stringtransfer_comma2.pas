{ The writestr half of stringtransfer_comma.pas: §6.7.5.5's first comma is
  part of that parameter list too. }
program StringTransferComma2(output);
type s8 = string(8);
var s: s8;
begin
  writestr(s 1);
  writeln(s)
end.
