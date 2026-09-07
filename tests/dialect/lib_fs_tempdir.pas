{ PasFS.TemporaryDirectory (ADR-0363): a directory of the program's own,
  made under a directory it names, private to this user, and taken away
  again. It is the answer for a program that wants *several* files with
  names of its choosing: `TemporaryPath` makes one file exclusively, and a
  second name composed beside it in a shared directory is a name somebody
  else may have planted a link at first.

  Its own case rather than a paragraph in lib_fs.pas, because that program
  takes a program-parameter and `lib-coverage` runs every case with none --
  so nothing past its first statement is ever measured there. }
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
      writeln('rm child  = ', ErrorText(e))
    end;
    e := RemoveDirectory(tdir.val);
    writeln('rmdir     = ', ErrorText(e));
    writeln('gone      = ', Exists(tdir.val))
  end
  else
    writeln('failed    = ', ErrorText(tdir.cause));

  { Where it cannot be made: a directory that is not there, and a name that
    would not fit. }
  writeln('nowhere   = ',
          ErrorText(TemporaryDirectory('./no-such-dir-here', 'p-').cause));
  long := '.';
  for i := 1 to 30 do long := long + '/0123456789abcdefghij';
  writeln('too long  = ', ErrorText(TemporaryDirectory(long, 'p-').cause))
end.
