{ ISO/IEC 10206:1991 6.4.6, the error list, c): "it shall be an error if T1 and
  T2 are compatible, T1 is a string-type or the char-type, and the length of
  the value of T2 is greater than the capacity of T1".

  6.7.3.2 holds a value parameter's actual to assignment-compatibility, so
  this is the same rule at a call as at an assignment -- and the same check,
  `pas_str_fits`, because the padded value a call builds is stored by the
  routine an assignment stores through. Nothing about the destination being a
  parameter changes the error or the message.

  It is a *run-time* error and not a refusal, because the actual here is a
  variable-string whose length the compiler does not know; a literal too long
  for the formal is refused where it is written.

  Extended Pascal only: ISO 7185 has neither 6.4.5 d) nor a string-type, so
  the call would not be legal in the first place. }
program trap_param_capacity(output);
type five = packed array [1..5] of char;
var s: string(10);
procedure show(t: five);
begin writeln('unreachable: [', t, ']') end;
begin
  s := 'abcdefg';
  writeln('before');
  show(s);
  writeln('unreachable')
end.
