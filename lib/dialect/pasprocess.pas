{ PasProcess -- the process this program is: running another, waiting, and
  the clock.

  Neither standard models a process. ISO/IEC 10206:1991 §6.7.5.7's `halt`
  stops one and ADR-0084 gave it a status; everything else about being a
  process -- starting a command, sleeping, reading a clock finer than
  §6.7.5.8's second -- is libc's, and this module is the `external`
  declarations for it (ADR-0121) with the numbers each answers made
  meaningful.

  **Five names, all ISO C or POSIX.1, and no header number this module
  cannot check.**

  - `system` is ISO C. What it returns is "implementation-defined" there and
    POSIX makes it a wait status, whose encoding -- the exit code in the
    second byte -- is conventional rather than declared: `WEXITSTATUS` is a
    macro. `ExitCode` below decodes it the way every POSIX libc does, and
    `tests/dialect/lib_process.pas` pins the decoding against `exit 3`, which
    is how a number this module cannot read from a header is checked
    instead.
  - `time` is ISO C and takes a pointer that may be null. Null is an `int64`
    zero through this FFI, as ADR-0151 records a `DIR *` is an `int64` --
    AP §6.7.7.9 c)'s note -- and no address is held afterwards.
  - `clock` is ISO C, and `CLOCKS_PER_SEC` is the one header number here:
    POSIX.1 fixes it at 1 000 000 on XSI-conformant systems, which every
    target this compiler admits is. `CpuSeconds` divides by it and says so.
  - `sleep` is POSIX.1, in whole seconds, and returns how many were left if
    it was interrupted.
  - `getpid` is POSIX.1 and answers a `pid_t`, which is the one place here a
    *typedef* rather than a number had to be judged. The judgement is written
    beside the declaration; what makes it this module's rather than the
    runtime's is that a scalar typedef can be judged at all, where
    `struct stat` and `struct pollfd` cannot (ADR-0186).

  **`Run` flushes first.** §6.10's `output` is buffered by the runtime and a
  child process writes straight to the descriptor, so without this a
  `writeln` before `Run` appeared *after* the command's output. `fflush`
  with a null stream flushes every open stream, and null is the same
  `int64` zero. PasIO records the same interleaving for descriptor writes
  and cannot fix it from its side; this module can, because it knows when
  the other writer starts.

  **`Capture` and `CaptureLines` read what a command writes.** `popen` is
  POSIX.1 and answers a `FILE *`, which is a handle (AP 6.4.12, ADR-0174):
  `Pipe` below is that type with `pclose` as its closer, so the child is
  waited for when the variable dies and the stream is closed by nothing
  else. The stream is read with `fgetc`, a call per character, for the
  reason PasStream gives.

  **Where the exit code comes from.** `pclose` answers the child's wait
  status, and `pclose` is the closer -- so `release(p)` is the whole of it
  (AP 6.4.12.5, ADR-0206): the pipe is closed where the reading stops and
  the result is the child's status, decoded by `ExitCode` exactly as `Run`
  decodes `system`'s.

  It used to be otherwise, and what it used to be is why AP 6.4.12.5
  exists. Every release before that record discarded the closer's result,
  so the status had to travel through the *stream*: the command ran in a
  subshell, the shell printed `$?` behind a marker no text was expected to
  contain -- a newline, then the character 1 -- and the reader split the
  two apart. A program that wrote a control character 1 at the start of a
  line was misread, and a `Capture` of anything binary was a gamble. The
  marker, the subshell and the wrapping are all gone.

  A command that cannot be started at all is `errIO`; one the shell could
  not find is code 127, as with `Run`.

  **What the command wrote is what a caller gets**, to the last newline.
  That did not change and is worth saying, because it *nearly* did: the
  marker was a newline and the character 1, and the newline it ate was the
  wrapper's own, printed by the `printf` after the output. Reading the
  reader as though it stripped the command's last newline is a mistake this
  increment made and a test caught.

  **What is not here.** A pipe *into* a child, its environment, a signal:
  `posix_spawn` takes a `char *const argv[]`, which is the struct-layout
  item of the roadmap. A command is a string the shell reads, exactly what
  `system` and `popen` are. }

module PasProcess;

export PasProcess = (CommandMax, CommandLine, RunResult,
                     Run, Capture, CaptureLines,
                     ExitCode, Sleep, Seconds, CpuSeconds, ProcessId);

import PasError;
       PasStrVec;

const
  CommandMax = 4096;

type
  CommandLine = string(CommandMax);

  { ADR-0120's shape: the exit code, or why there is none. `errIO` is what a
    shell that could not be started answers; a command that ran and failed
    has a code, and the code is the caller's to judge.

    Written by the language since AP 6.4.13 (ADR-0176), which is worth a
    sentence here rather than anywhere else: this record used to spell its
    *payload* `code` and its *reason* `reason`, so `r.code` meant the exit
    status here and the ErrorCode in four other modules of the same library.
    One reader had to know which. The field names are `ok`, `val` and `cause`
    everywhere now, and the collision is gone by construction. }
  RunResult = Fallible(integer);

{ Run `command` through the shell and wait for it. `ok` with the command's
  exit code -- 0 for success by the usual convention, the command's own
  number otherwise -- or `errIO` when no shell could be started at all. A
  command the shell could not find is *not* that: it is the shell exiting
  127, which is a code. }
function Run(command: CommandLine): RunResult;

{ Run `command` and collect everything it writes to its standard output into
  `into`, a string of any capacity: what does not fit is read and dropped, so
  the command still runs to its end and the code is still its own. The
  program's own output is flushed first, as `Run` does. Newlines are kept;
  the command's standard error is not captured and goes where the program's
  does. }
function Capture(command: CommandLine; var into: string): RunResult;

{ The same, a line at a time onto `lines`, each without its newline and cut
  at `ItemMax` characters; a final line without a newline is still a line.
  The vector is not cleared first. A directory listing is
  `CaptureLines('ls -1 dir', names)`, the shell's quoting being the caller's. }
function CaptureLines(command: CommandLine; var lines: StrVecPtr): RunResult;

{ The exit code inside a wait status, as `system` returns one: the second
  byte. A status that is not an exit -- a signal -- decodes to the low byte
  and the caller cannot tell; `Run` is the interface, and this is exported
  for a caller holding a status from elsewhere. }
function ExitCode(status: integer): integer;

{ Wait at least `seconds` seconds. Answers how many were left when the wait
  was cut short, 0 when it was not. }
function Sleep(seconds: integer): integer;

{ Seconds since 1970-01-01T00:00:00Z, as `time` counts them: the value to
  subtract from another of its kind. §6.7.5.8's `GetTimeStamp` is the one to
  use for a *date*. }
function Seconds: int64;

{ Processor time this program has used, in seconds, from `clock` and
  `CLOCKS_PER_SEC`. Wraps after about 72 minutes where `clock_t` is 32 bits;
  on every target this compiler admits it is 64. }
function CpuSeconds: real;

{ The number the operating system knows this program by, from `getpid`.
  Positive, and no other program running at the same moment has it -- which
  is the whole of what it is for here: a program that must choose a file name
  no other *live* process will choose has nothing else to build one from
  (ADR-0242). It says nothing about a process that has exited; the system is
  free to hand the number out again. }
function ProcessId: integer;

end;

function ExtSystem(command: string): integer; external 'system';
function ExtTime(where: int64): int64; external 'time';
function ExtClock: int64; external 'clock';
function ExtSleep(seconds: integer): integer; external 'sleep';
{ `pid_t` is the one POSIX scalar typedef this module binds, and POSIX says
  only that it is a signed integer type. `integer` is the safe direction of
  the two this FFI has: where the typedef is wider, the low word is read and
  a process identifier fits it on every system anybody runs; where `int64`
  were used and the typedef is `int`, the high word would be whatever the
  call left in the register. `time_t` above is `int64` for the opposite
  reason -- it is 64 bits everywhere and a truncated one is wrong in 2038. }
function ExtGetpid: integer; external 'getpid';
function ExtFflush(stream: int64): integer; external 'fflush';

type
  { the child's standard output; pclose waits for the child }
  Pipe = handle external 'pclose';

function ExtPopen(command, mode: string): Pipe; external 'popen';
function ExtFgetc(f: Pipe): integer; external 'fgetc';

const
  NewLine = 10;

const
  { POSIX.1, XSI: "CLOCKS_PER_SEC is defined to be one million". A number a
    header would give and this module writes out, for the reason in the
    header comment. }
  ClocksPerSec = 1000000;

function ExitCode;
begin
  ExitCode := (status div 256) mod 256
end;

function ProcessId;
begin
  ProcessId := ExtGetpid
end;

function Run;
var status: integer; r: RunResult;
begin
  status := ExtFflush(0);
  status := ExtSystem(command);
  if status = -1 then
    r := errIO
  else
    r := ExitCode(status);
  Run := r
end;

{ Both readers are this one loop: every character goes to `take`, and the
  status comes from closing the pipe. Nothing is held back or looked ahead
  at -- which is the shape the marker cost, the old reader having had to
  know the character after every newline before it could hand the newline
  over. }
procedure Collect(command: CommandLine; var r: RunResult;
                  procedure take(ch: char));
var p: Pipe; status, c: integer;
begin
  status := ExtFflush(0);
  p := ExtPopen(command, 'r');
  if p = nil then
    r := errIO
  else begin
    c := ExtFgetc(p);
    while c >= 0 do begin
      take(chr(c));
      c := ExtFgetc(p)
    end;
    { AP 6.4.12.5 (ADR-0206): `pclose` is this handle's closer and this is
      what it answered -- the child's wait status. The variable is empty
      afterwards, so the block's own release finds nothing and the stream is
      closed once, which is what made calling `pclose` by hand impossible
      before. }
    status := release(p);
    if status = -1 then r := errIO
    else r := ExitCode(status)
  end
end;

function Capture;
var r: RunResult; n: integer;

  procedure keep(ch: char);
  begin
    n := n + 1;
    if n <= into.capacity then into := into + ch
  end;

begin
  into := '';
  n := 0;
  Collect(command, r, keep);
  Capture := r
end;

function CaptureLines;
var r: RunResult; piece: StrItem; n: integer;

  procedure keep(ch: char);
  begin
    if ch = chr(NewLine) then begin
      SVecPush(lines, piece);
      piece := '';
      n := 0
    end
    else begin
      n := n + 1;
      if n <= ItemMax then piece := piece + ch
    end
  end;

begin
  piece := '';
  n := 0;
  Collect(command, r, keep);
  if n > 0 then SVecPush(lines, piece);
  CaptureLines := r
end;

function Sleep;
begin
  Sleep := ExtSleep(seconds)
end;

function Seconds;
begin
  Seconds := ExtTime(0)
end;

function CpuSeconds;
begin
  CpuSeconds := ExtClock / ClocksPerSec
end;

end.
