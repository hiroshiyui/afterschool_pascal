{ ISO 7185 §6.10: "The identifiers contained by the program-parameter-list
  shall be distinct."

  Each program-parameter has a defining-point as a variable-identifier for the
  region that is the program-block, so a repeat is a redeclaration -- but the
  identifiers are *looked up* rather than declared, the variable-declaration-
  part having already made them, so `Declare`'s own duplicate check never sees
  one. The suite's DEV254 is the program that found it.

  Reported against the later occurrence, which is the one a reader would
  delete, and once per repeat. }
program ProgParamDuplicate(output, input, output, f, f);
var f: text;
begin
  writeln('unreachable')
end.
