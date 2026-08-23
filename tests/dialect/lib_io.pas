{ ADR-0129 end to end: a library module binds `read` and `write` by name, a
  buffer travels as an address and a count, and the program never writes the
  count.

  **The two halves of this program are in the order they are for a reason the
  module documents.** PasIO writes to a descriptor and 6.10's `write` goes to
  a buffered stream, so the two interleave by whichever flushed last. Every
  descriptor write here happens before Pascal has written anything at all,
  which is the only ordering that does not depend on how `output` is buffered
  -- and it is the caveat in PasIO's own comment, demonstrated rather than
  asserted.

  The scratch path comes from a program-parameter's binding (6.5.1 and 6.7.6.8
  NOTE 2), because the harness passes paths in a temporary directory that
  differs every run. }
program lib_io(output, scratch, missing);

import PasError;
       PasFS;
       PasIO;

var scratch, missing: text;
    path, gone: PathName;
    buf: array [1..64] of char;
    r: CountResult;
    o: FdResult;
    e: ErrorCode;
    i, fd: integer;

procedure said(what: string(16); e: ErrorCode);
begin
  write(what);
  if Failed(e) then writeln(ErrorText(e)) else writeln('done')
end;

procedure got(what: string(16); r: CountResult);
begin
  write(what);
  if r.ok then writeln(r.val:1, ' bytes') else writeln(ErrorText(r.cause))
end;

begin
  { ---- descriptor writes, before `output` holds anything ---- }

  e := WriteText(StdOut, 'one: ');
  e := WriteText(StdOut, 'two');
  e := WriteText(StdOut, chr(10));

  { The empty string, so b[1..0] is the empty slice and the pair crosses with
    a count of zero. ADR-0125 makes a[4..3] empty and this is that. }
  e := WriteText(StdOut, '');

  { The empty slice reaching `write` itself, which WriteText does not do --
    its loop has nothing to iterate. The pair crosses with a count of zero and
    the operating system answers zero. }
  r := WriteFrom(StdOut, buf[1..0]);

  for i := 1 to 5 do buf[i] := chr(64 + i);
  buf[6] := chr(10);
  e := WriteAll(StdOut, buf[1..6]);

  { ---- everything below is reported through 6.10's write ---- }

  path := binding(scratch).name;
  gone := binding(missing).name;

  { An earlier case in the same run may have left a file at either path, so
    the fixture clears the one that must not exist. }
  e := Remove(gone);

  { Written by Pascal, then reopened for reading, which is what puts the
    characters on the disk -- a text file being written closes at block exit
    and this program has not reached one. }
  rewrite(scratch);
  write(scratch, 'hello, world');
  reset(scratch);

  got('empty write   = ', r);

  o := OpenRead(path);
  if not o.ok then begin
    said('open          = ', o.cause);
    halt
  end;
  fd := o.val;
  writeln('open          = done');

  { Five bytes, because the slice says five. `read` is not told how big the
    array is and has no parameter through which it could be. }
  r := ReadInto(fd, buf[1..5]);
  got('short read    = ', r);
  write('bytes         = ');
  for i := 1 to CountOr(r, 0) do write(buf[i]);
  writeln;

  { The whole array, so the count is its extent and the rest of the file
    arrives. }
  r := ReadInto(fd, buf);
  got('rest          = ', r);
  write('bytes         = ');
  for i := 1 to CountOr(r, 0) do write(buf[i]);
  writeln;

  r := ReadInto(fd, buf);
  got('at the end    = ', r);
  if AtEnd(r) then writeln('AtEnd         = yes');

  { WriteAll's failing exit: the descriptor was opened for reading, so `write`
    refuses and the loop stops on the code rather than on the count. The
    *retry* branch beside it -- a short write, then another call -- is not
    reachable from here: a regular file never takes fewer bytes than it was
    given, and a pipe blocks rather than truncating. Said in the commit
    message rather than left to be discovered. }
  for i := 1 to 4 do buf[i] := 'x';
  said('write to ro   = ', WriteAll(fd, buf[1..4]));

  said('close         = ', Close(fd));
  said('close again   = ', Close(fd));

  { The failing direction. The reason is errIO and cannot be finer, errno
    being behind a pointer result ADR-0122 does not admit. }
  o := OpenRead(gone);
  if not o.ok then said('open missing  = ', o.cause);

  { A read on a descriptor that is not open. }
  r := ReadInto(fd, buf);
  got('read closed   = ', r);
  writeln('text          = ', ResultText(r));

  { AtEnd asked of a *failed* result, which is where its first conjunct earns
    its keep: `and` short-circuits, so `r.val` is never read on a result
    whose tag says there is no count -- and under ADR-0118 reading it would
    trap rather than answer a stale integer. Two rules holding each other up. }
  if AtEnd(r) then writeln('failed at end = yes')
  else writeln('failed at end = no');

  { A count is a value like any other, and the default is what a failed
    result answers with. }
  writeln('CountOr       = ', CountOr(r, -7):1)
end.
