{ @std:iso7185 -- `value` is an ordinary identifier here and a word-symbol in
  Extended Pascal, so this program compiles only if the annotation was read. }
program iso(output);
var value: integer;
begin value := 7; writeln(value:1) end.
