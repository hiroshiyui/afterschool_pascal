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
  writeln('PasFS.Remove            ', Remove(n).Text);
  writeln('PasFS.Rename            ', Rename(n, 'x').Text,
          ' / ', Rename('x', n).Text);
  writeln('PasFS.MakeDirectory     ', MakeDirectory(n).Text);
  writeln('PasFS.RemoveDirectory   ', RemoveDirectory(n).Text);
  ir := Info(n);
  writeln('PasFS.Info              ', ir.ok, ' ', ir.cause.Text);
  pr := LinkTarget(n);
  writeln('PasFS.LinkTarget        ', pr.ok, ' ', pr.cause.Text);
  pr := TemporaryPath(n, 'p');
  writeln('PasFS.TemporaryPath     ', pr.ok, ' ', pr.cause.Text);
  pr := TemporaryPath('.', n);
  writeln('PasFS.TemporaryPath     ', pr.ok, ' ', pr.cause.Text, ' (prefix)');
  pr := TemporaryDirectory(n, 'p');
  writeln('PasFS.TemporaryDirectory ', pr.ok, ' ', pr.cause.Text);
  writeln('PasDir.OpenDir          ', OpenDir(d, n).Text);
  ot := Lookup(n);
  writeln('PasEnv.Lookup           ', ot = nil);
  writeln('PasEnv.Define           ', Define(n, 'v').Text,
          ' / ', Define('k', n).Text);
  writeln('PasEnv.Undefine         ', Undefine(n).Text);
  fr := OpenRead(n);
  writeln('PasIO.OpenRead          ', fr.ok, ' ', fr.cause.Text);
  writeln('PasStream.OpenRead      ', StreamOpenRead(st, n).Text);
  writeln('PasStream.OpenWrite     ', StreamOpenWrite(st, n).Text);
  writeln('PasStream.OpenAppend    ', StreamOpenAppend(st, n).Text);
  writeln('PasNet.NetConnect       ', NetConnect(so, n, '80').Text,
          ' / ', NetConnect(so, 'localhost', n).Text);
  writeln('PasNet.NetListen        ', NetListen(so, n, '0').Text);
  writeln('all nineteen answered')
end.
