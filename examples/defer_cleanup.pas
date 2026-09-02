{ `defer`: write the cleanup beside the thing it undoes.

  A scratch directory is made, a file is written into it, and both are
  removed on the way out -- whichever way the block is left. `defer S`
  (ADR-0175) arms S to run when the enclosing statement-sequence
  completes, in the reverse of the order the defers were written; a normal
  end, an `exit` and a `try` that fails all run it. The Stream is a handle
  and closes itself when its variable dies. Uses PasFS (MakeDirectory,
  Remove, RemoveDirectory, Exists) and PasStream (OpenWrite, WriteLine). }
program defer_cleanup(output);

import PasError; PasFS; PasStream;

var dir: PathName;

procedure WorkIn(dir: PathName; early: boolean);
var s: Stream; e: ErrorCode; path: PathName;
begin
  e := MakeDirectory(dir);
  if Failed(e) then begin
    writeln('  cannot make a directory: ', ErrorText(e));
    exit
  end;
  defer writeln('  after cleanup, directory exists: ', Exists(dir));
  defer e := RemoveDirectory(dir);

  path := dir + '/notes.txt';
  e := OpenWrite(s, path);
  if Failed(e) then exit;
  defer e := Remove(path);
  defer s := nil;                { close the stream before removing the file }

  e := WriteLine(s, 'first line');
  writeln('  wrote a file; it exists: ', Exists(path));
  if early then begin
    writeln('  leaving early');
    exit
  end;
  e := WriteLine(s, 'second line');
  writeln('  reached the end of the block')
end;

begin
  { Somewhere writable: beside the first argument if there is one. }
  if argcount >= 1 then dir := argument(1) + '.d'
  else dir := 'defer_cleanup.d';
  writeln('run to the end:');
  WorkIn(dir, false);
  writeln('leave early:');
  WorkIn(dir, true)
end.
