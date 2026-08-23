{ PasProcess. What is pinned is what can be: the decoding of a wait status,
  against a shell told to exit with a number; that the shell's own 127 is a
  code and not a failure to start; that output written before Run comes out
  before the command's, which is the flush; and that the two clocks move the
  right way. How much time passed is not printed, because it is a property of
  the moment and not of the module. }
program lib_process(output);

import PasError;
       PasProcess;

var r: RunResult; t0, t1: int64; c0, c1: real; i, acc: integer;

procedure report(what: string(24); r: RunResult);
begin
  write(what, ': ');
  if r.ok then writeln('code ', r.code:1)
  else writeln('failed, ', ErrorText(r.reason))
end;

begin
  writeln('before the command');
  report('echo', Run('echo from the shell'));
  report('true', Run('true'));
  report('exit 3', Run('exit 3'));
  report('exit 200', Run('exit 200'));
  report('false', Run('false'));
  report('not found', Run('no-such-command-apascal 2>/dev/null'));
  writeln('decode 768: ', ExitCode(768):1, ' decode 0: ', ExitCode(0):1);

  t0 := Seconds;
  c0 := CpuSeconds;
  acc := 0;
  for i := 1 to 5000000 do
    acc := (acc + i) mod 1000003;
  c1 := CpuSeconds;
  writeln('epoch plausible: ', t0 > 1700000000);
  writeln('cpu advanced: ', c1 > c0, ' positive: ', c0 >= 0.0);
  writeln('slept: ', Sleep(1):1, ' left');
  t1 := Seconds;
  writeln('clock advanced: ', t1 - t0 >= 1)
end.
