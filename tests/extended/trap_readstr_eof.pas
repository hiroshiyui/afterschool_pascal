{ ISO/IEC 10206:1991 §6.7.5.5: "It shall be an error if the equivalent of
  eof(f) is true upon completion."

  The auxiliary text file holds the string's characters followed by the line
  marker `writeln(f, e)` appends, so eof is false whenever every variable had
  a representation to read. Reading a char at the line marker yields a space
  and steps past it, which is how a readstr with one value too many runs off
  the end without any single read failing -- and is why the condition is
  stated at *completion* rather than at each variable. }
program TrapReadStrEof(output);
var i: integer; c: char;
begin
  writeln('before');
  readstr('1', i, c);
  writeln('unreachable ', i:1, c)
end.
