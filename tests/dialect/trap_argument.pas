{ AP 6.7.6.10: "it shall be an error if k is not in 1..argcount". The harness
  gives every program two arguments; the third is the error. }
program trap_argument(output);
begin
  writeln('count ', argcount:1);
  writeln(argument(argcount + 1))
end.
