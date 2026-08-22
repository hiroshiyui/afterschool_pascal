{ ISO/IEC 10206:1991 6.4.6, the error list, c): "it shall be an error if T1 and
  T2 are compatible, T1 is a string-type or the char-type, and the length of
  the value of T2 is greater than the capacity of T1".

  A char has capacity one, so a two-character value does not fit. Annex D makes
  this an error rather than a violation, so a processor is permitted to leave
  it undetected; this one reports it, as it does for every other string
  destination -- the capacity check is `pas_str_fits` and the char destination
  reaches the same call as a fixed and a variable string do.

  Extended Pascal only: ISO 7185 refuses the assignment outright. }
program trap_char_capacity(output);
var
  c: char;
  s: string(10);
begin
  s := 'hi';
  writeln('before');
  c := s;
  writeln('unreachable: ', c)
end.
