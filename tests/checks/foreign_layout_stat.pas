{ A worked example for the foreign-layout gate, and the struct that made the
  gate necessary (ADR-0185).

  `struct stat` is what a program actually wants to declare and is the hardest
  thing to declare correctly: glibc/x86-64 gives it 144 bytes with **two
  holes** -- four bytes after `st_gid` that the header spells `__pad0`, and
  twenty-four at the end that it spells `__glibc_reserved` -- and a program
  that omits either has every field after it silently wrong. Nothing in the
  language can catch that. The gate can, by handing the offsets this compiler
  computed to a C compiler holding <sys/stat.h>.

  **It is a gate fixture and not a test case**, and it lives here rather than
  under tests/dialect/ for the reason `@cplatform` exists: this declaration is
  glibc's, `struct stat` is a different struct on macOS, and a case that ran
  would print a wrong number there rather than being skipped. The gate skips
  it and says so; a program that ran could not.

  **This is also what a library module may not contain**, which is ADR-0184's
  closing decision. `PasFS` answers about a file through a `pasx_` routine in
  the runtime, because a module has to work on machines nobody here can check,
  and a declaration checked only where it was written is not that. What this
  file demonstrates is the facility as a *program* should use it: declare the
  struct you need, say what you claim it is, and let the build tell you when
  you are on a machine where the claim is false. }
program foreign_layout_stat(output);

type
  { @cstruct: StatBuf = struct stat, <sys/stat.h>  @cplatform: linux-glibc }
  StatBuf = record
    dev:      int64;                 { @cfield: st_dev }
    ino:      int64;                 { @cfield: st_ino }
    nlink:    int64;                 { @cfield: st_nlink }
    mode:     integer;               { @cfield: st_mode }
    uid:      integer;               { @cfield: st_uid }
    gid:      integer;               { @cfield: st_gid }
    pad0:     integer;               { @cfield: - }
    rdev:     int64;                 { @cfield: st_rdev }
    size:     int64;                 { @cfield: st_size }
    blksize:  int64;                 { @cfield: st_blksize }
    blocks:   int64;                 { @cfield: st_blocks }
    atsec:    int64;                 { @cfield: st_atim }
    atnsec:   int64;                 { @cfield: - }
    mtsec:    int64;                 { @cfield: st_mtim }
    mtnsec:   int64;                 { @cfield: - }
    ctsec:    int64;                 { @cfield: st_ctim }
    ctnsec:   int64;                 { @cfield: - }
    reserved: array [1..3] of int64  { @cfield: - }
  end;

function ExtStat(path: string; var buf: StatBuf): integer; external 'stat';

var buf: StatBuf;

begin
  if ExtStat('/etc/hostname', buf) = 0 then
    writeln(buf.size:1)
end.
