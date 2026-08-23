{ PasProcess. What is pinned is what can be: the decoding of a wait status,
  against a shell told to exit with a number; that the shell's own 127 is a
  code and not a failure to start; that output written before Run comes out
  before the command's, which is the flush; and that the two clocks move the
  right way. How much time passed is not printed, because it is a property of
  the moment and not of the module. Capture is pinned on what the marker
  has to get right: output with and without a final newline, an empty
  output, a code beside it, a string too short for the whole, and the lines
  of a listing of a directory the program made. }
program lib_process(output, fresh);

import PasError;
       PasStrVec;
       PasProcess;

var r: RunResult; t0, t1: int64; c0, c1: real; i, acc: integer;
    got: string(200); small: string(4); names: StrVecPtr;
    fresh: bindable text; dir: string(255);

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

  report('capture', Capture('printf ''a\nb\n''', got));
  writeln('  [', got, '] length ', length(got):1);
  report('no final newline', Capture('printf ''a\nb''', got));
  writeln('  length ', length(got):1, ' last ', ord(got[length(got)]):1);
  report('empty output', Capture('true', got));
  writeln('  length ', length(got):1);
  report('output and a code', Capture('echo partial; exit 5', got));
  writeln('  [', got, ']');
  report('too short', Capture('echo 0123456789', small));
  writeln('  [', small, ']');
  report('not found', Capture('no-such-command-apascal 2>/dev/null', got));
  SVecNew(names, 2);
  report('lines', CaptureLines('printf ''x\n\ny''', names));
  for i := 1 to SVecLen(names) do
    writeln('  ', i:1, ': [', SVecGet(names, i), ']');
  SVecClear(names);
  { a directory of the harness's own, listed through the shell }
  dir := binding(fresh).name + '.d';
  r := Run('rm -rf ' + dir + ' && mkdir ' + dir + ' && touch ' + dir + '/b ' + dir + '/a ' + dir + '/c');
  report('listing', CaptureLines('ls -1 ' + dir, names));
  for i := 1 to SVecLen(names) do
    writeln('  ', SVecGet(names, i));
  r := Run('rm -rf ' + dir);
  SVecFree(names);

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
