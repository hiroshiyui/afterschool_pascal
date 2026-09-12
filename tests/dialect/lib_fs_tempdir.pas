{ PasFS.TemporaryDirectory (ADR-0363): a directory of the program's own,
  made under a directory it names, private to this user, and taken away
  again. It is the answer for a program that wants *several* files with
  names of its choosing: `TemporaryPath` makes one file exclusively, and a
  second name composed beside it in a shared directory is a name somebody
  else may have planted a link at first.

  Its own case rather than a paragraph in lib_fs.pas, and the reason has
  since gone: that program takes a program-parameter, and `lib-coverage` ran
  every case with none, so nothing past its first statement was measured
  there. The sweep passes the arguments now (ADR-0378) and this case stands
  on TemporaryDirectory alone. }
program lib_fs_tempdir(output);

import PasError;
       PasFS;

var
  tdir, inner: PathResult;
  inf: InfoResult;
  e: ErrorCode;
  long: PathName;
  i: integer;

begin
  tdir := TemporaryDirectory('.', 'fsdir-');
  if tdir.ok then begin
    writeln('made      = ', Exists(tdir.val));
    inf := Info(tdir.val);
    if inf.ok then writeln('is dir    = ', inf.val.kind = fkDirectory);
    writeln('chosen    = ', length(tdir.val) - length('./fsdir-'):1,
            ' characters');
    { A file inside, by a name of the caller's choosing -- the point. }
    inner := TemporaryPath(tdir.val, 'mine-');
    writeln('child     = ', inner.ok);
    if inner.ok then begin
      e := Remove(inner.val);
      writeln('rm child  = ', e.Text)
    end;
    e := RemoveDirectory(tdir.val);
    writeln('rmdir     = ', e.Text);
    writeln('gone      = ', Exists(tdir.val))
  end
  else
    writeln('failed    = ', tdir.cause.Text);

  { Where it cannot be made: a directory that is not there, and a name that
    would not fit. }
  writeln('nowhere   = ',
          TemporaryDirectory('./no-such-dir-here', 'p-').cause.Text);
  long := '.';
  for i := 1 to 30 do long := long + '/0123456789abcdefghij';
  writeln('too long  = ', TemporaryDirectory(long, 'p-').cause.Text)
end.
