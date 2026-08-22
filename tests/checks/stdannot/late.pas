program late(output);
{ @std:iso7185 -- after the first token, so it is prose and not an annotation.
  This file is Extended Pascal by default and uses `value` as a word-symbol
  would not permit, so it must FAIL: the header rule is what is being pinned. }
var value: integer;
begin value := 1; writeln(value:1) end.
