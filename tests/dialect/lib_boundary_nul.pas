{ A value that came from outside is refused as a code, never trapped
  (ADR-0363's rule, applied to every routine in this library that hands
  outside text across the boundary).

  A string crossing to a foreign routine may not hold chr(0), and ADR-0122
  makes the crossing a run-time error -- right for a program's own value,
  wrong for one an editor, a client or a file supplied, because one such
  value then stops the whole program. The security audit that followed
  ADR-0363 asked nineteen routines across six modules and every one
  stopped. This program asks the same nineteen and every one must answer.

  What is pinned is the *answer's kind*: errSyntax where a code is the
  result, false or nil where the result is a fact about something that a
  name holding chr(0) cannot be. The one thing this program must not do is
  end early -- a line missing below is a routine that trapped. }
program lib_boundary_nul(output);

import PasError;
       PasFS;
       PasDir;
       PasEnv;
       PasIO;
       PasStream;
       PasNet;

var
  n: PathName;
  d: Dir;
  st: Stream;
  so: Socket;
  fr: FdResult;
  ir: InfoResult;
  pr: PathResult;
  ot: OptEnvText;

begin
  n := 'a' + chr(0) + 'b';
  writeln('PasFS.Exists            ', Exists(n));
  writeln('PasFS.Remove            ', ErrorText(Remove(n)));
  writeln('PasFS.Rename            ', ErrorText(Rename(n, 'x')),
          ' / ', ErrorText(Rename('x', n)));
  writeln('PasFS.MakeDirectory     ', ErrorText(MakeDirectory(n)));
  writeln('PasFS.RemoveDirectory   ', ErrorText(RemoveDirectory(n)));
  ir := Info(n);
  writeln('PasFS.Info              ', ir.ok, ' ', ErrorText(ir.cause));
  pr := LinkTarget(n);
  writeln('PasFS.LinkTarget        ', pr.ok, ' ', ErrorText(pr.cause));
  pr := TemporaryPath(n, 'p');
  writeln('PasFS.TemporaryPath     ', pr.ok, ' ', ErrorText(pr.cause));
  pr := TemporaryPath('.', n);
  writeln('PasFS.TemporaryPath     ', pr.ok, ' ', ErrorText(pr.cause), ' (prefix)');
  pr := TemporaryDirectory(n, 'p');
  writeln('PasFS.TemporaryDirectory ', pr.ok, ' ', ErrorText(pr.cause));
  writeln('PasDir.OpenDir          ', ErrorText(OpenDir(d, n)));
  ot := Lookup(n);
  writeln('PasEnv.Lookup           ', ot = nil);
  writeln('PasEnv.Define           ', ErrorText(Define(n, 'v')),
          ' / ', ErrorText(Define('k', n)));
  writeln('PasEnv.Undefine         ', ErrorText(Undefine(n)));
  fr := OpenRead(n);
  writeln('PasIO.OpenRead          ', fr.ok, ' ', ErrorText(fr.cause));
  writeln('PasStream.OpenRead      ', ErrorText(StreamOpenRead(st, n)));
  writeln('PasStream.OpenWrite     ', ErrorText(StreamOpenWrite(st, n)));
  writeln('PasStream.OpenAppend    ', ErrorText(StreamOpenAppend(st, n)));
  writeln('PasNet.NetConnect       ', ErrorText(NetConnect(so, n, '80')),
          ' / ', ErrorText(NetConnect(so, 'localhost', n)));
  writeln('PasNet.NetListen        ', ErrorText(NetListen(so, n, '0')));
  writeln('all nineteen answered')
end.
