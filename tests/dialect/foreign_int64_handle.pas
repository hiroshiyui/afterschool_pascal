{ AP §6.7.7.9 c) forbids an external-declaration whose result "is an address of
  storage the callee owns", and says that is where the specification stops and
  ADR-0109's memory-safety model begins. This program is that program, and it
  is accepted: §6.7.7.8 admits an `int64` result for `ssize_t` (ADR-0128), a
  pointer fits in 64 bits, and no processor can tell a count from an address.

  So the prohibition is a requirement on the *program*, unenforced and
  unenforceable — Annex C.7, and ADR-0151, which is what found it. §7 of
  doc/roadmap.md had recorded the opaque handle as the item that *forces* the
  memory-safety fork and as the reason the fork had not been started; the
  handle was never blocked, and every property the model would have given it is
  absent here rather than pending.

  A KNOWN_GAP in verify/'s sense, and it fails in both directions: if the
  dialect ever gains a handle type and refuses this, the case fails and the
  record above stops being true.

  `opendir` and `closedir` are libc, and `.` is a directory in whatever
  directory the harness runs from. }
program foreign_int64_handle(output);

function ExtOpendir(path: string): int64; external 'opendir';
function ExtClosedir(handle: int64): integer; external 'closedir';

var d, alias: int64; rc: integer;

begin
  d := ExtOpendir('.');
  if d = 0 then
    writeln('opendir failed, and that is not what this case is about')
  else begin
    writeln('a DIR* crossed the boundary as int64');
    { A handle is a value here, so it copies. Nothing says one is unique, and
      closing through either of these closes the one stream. }
    alias := d;
    { And it is a *number*, because AP §6.4.2.6.2 makes int64 numeric on
      purpose. Arithmetic on an open directory stream is a legal statement. }
    d := d + 8;
    d := d - 8;
    writeln('it copied, and arithmetic on it was legal');
    rc := ExtClosedir(alias);
    writeln('closedir through the copy returned ', rc:1);
    { Closing it again is a double free that aborts the process, and this case
      stops here rather than showing it: what is being pinned is that the
      language permits everything above, not that libc notices afterwards. }
    writeln('and nothing in the language prevented any of it')
  end
end.
