{ A character-string longer than the 255 characters this compiler keeps.

  Neither standard bounds a character-string: 6.1.7 writes it as a sequence
  of string-elements and stops. This compiler keeps 255, and used to truncate
  the rest in silence -- `writeln` of a 300-character literal printed 255 of
  them and said nothing, so the program's output differed from its source
  with nothing to point at. }
program stringtoolong(output);
begin
  writeln('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
end.
