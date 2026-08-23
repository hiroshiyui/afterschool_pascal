{ PasProcess -- the process this program is: running another, waiting, and
  the clock.

  Neither standard models a process. ISO/IEC 10206:1991 §6.7.5.7's `halt`
  stops one and ADR-0084 gave it a status; everything else about being a
  process -- starting a command, sleeping, reading a clock finer than
  §6.7.5.8's second -- is libc's, and this module is the `external`
  declarations for it (ADR-0121) with the numbers each answers made
  meaningful.

  **Four names, all ISO C or POSIX.1, and no header number this module
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
  status -- and `pclose` is the closer, whose result AP 6.4.12.1 discards.
  Calling it by hand would leave the variable owning an address already
  released, which 6.4.12.3 forbids. So the status travels through the
  stream instead: the command is run in a subshell and the shell prints
  `$?` after it, behind a marker no text contains (a newline, then the
  character 1), and the reader takes the code from the marker and the
  output from before it. The marker is what the program wrote only if it
  wrote a control character 1 at the start of a line, which `Capture`
  would then misread; that is the cost, and the roadmap carries the
  language change that would remove it. A command that cannot be started
  at all is `errIO`; one the shell could not find is code 127, as with
  `Run`.

  **What is not here.** A pipe *into* a child, its environment, a signal:
  `posix_spawn` takes a `char *const argv[]`, which is the struct-layout
  item of the roadmap. A command is a string the shell reads, exactly what
  `system` and `popen` are. }

module PasProcess;

export PasProcess = (CommandMax, CommandLine, RunResult,
                     Run, Capture, CaptureLines,
                     ExitCode, Sleep, Seconds, CpuSeconds);

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
  RunResult = integer ! ErrorCode;

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

end;

function ExtSystem(command: string): integer; external 'system';
function ExtTime(where: int64): int64; external 'time';
function ExtClock: int64; external 'clock';
function ExtSleep(seconds: integer): integer; external 'sleep';
function ExtFflush(stream: int64): integer; external 'fflush';

type
  { the child's standard output; pclose waits for the child }
  Pipe = handle external 'pclose';

function ExtPopen(command, mode: string): Pipe; external 'popen';
function ExtFgetc(f: Pipe): integer; external 'fgetc';

const
  NewLine = 10;
  Marker = 1;    { the character after the newline that ends the output }

const
  { POSIX.1, XSI: "CLOCKS_PER_SEC is defined to be one million". A number a
    header would give and this module writes out, for the reason in the
    header comment. }
  ClocksPerSec = 1000000;

function ExitCode;
begin
  ExitCode := (status div 256) mod 256
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

{ The command wrapped so that the shell reports the status after the
  output. The subshell is what makes `exit 3` a code rather than the end of
  the shell before the printf. }
function Wrapped(command: CommandLine): CommandLine;
begin
  Wrapped := '( ' + command + ' ); printf ''\n\001%d'' "$?"'
end;

{ Both readers are this one loop: every character before the marker goes to
  `take`, and the digits after it are the code. `c` is the character read
  and `prev` the one before it, because the marker is two characters and
  the newline before it belongs to the marker, not to the output -- so a
  newline is handed over only once the character after it is known. }
procedure Collect(command: CommandLine; var r: RunResult;
                  procedure take(ch: char));
var p: Pipe; status, c, code: integer; seen, pending: boolean;
begin
  status := ExtFflush(0);
  p := ExtPopen(Wrapped(command), 'r');
  if p = nil then
    r := errIO
  else begin
    seen := false;
    pending := false;
    code := 0;
    c := ExtFgetc(p);
    while c >= 0 do begin
      if seen then begin
        if (c >= ord('0')) and (c <= ord('9')) then
          code := code * 10 + (c - ord('0'))
      end
      else if pending then begin
        pending := false;
        if c = Marker then seen := true
        else begin
          take(chr(NewLine));
          if c = NewLine then pending := true
          else take(chr(c))
        end
      end
      else if c = NewLine then pending := true
      else take(chr(c));
      c := ExtFgetc(p)
    end;
    if seen then r := code
    else r := errIO
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
