{ ADR-0122: a C string carries its length in-band, as the NUL, and a Pascal
  string containing one has no image on the other side of the boundary. The
  copy traps rather than truncating: a path silently cut short is exactly the
  class of thing every other check here traps on (ADR-0017, ADR-0018,
  ADR-0019), and it is the one safety property this increment can claim. }
program foreign_string_nul(output);

function atoi(s: string): integer; external 'atoi';

var s: string(8);

begin
  s := '12' + chr(0) + '34';
  writeln('length       = ', length(s):1);
  writeln(atoi(s):1)
end.
