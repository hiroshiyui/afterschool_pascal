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

  **What is not here.** Arguments as a list, a pipe to or from the child,
  its environment, a signal: `popen` returns a `FILE *` and `posix_spawn`
  takes a `char *const argv[]`, and AP §6.7.7.9 c) is where both stop. A
  command is a string the shell reads, exactly what `system` is. }

module PasProcess;

export PasProcess = (CommandMax, CommandLine, RunResult,
                     Run, ExitCode, Sleep, Seconds, CpuSeconds);

import PasError;

const
  CommandMax = 4096;

type
  CommandLine = string(CommandMax);

  { ADR-0120's shape: the exit code, or why there is none. `errIO` is what a
    shell that could not be started answers; a command that ran and failed
    has a code, and the code is the caller's to judge. }
  RunResult = record
    case ok: boolean of
      true:  (code: integer);
      false: (reason: ErrorCode)
    end;

{ Run `command` through the shell and wait for it. `ok` with the command's
  exit code -- 0 for success by the usual convention, the command's own
  number otherwise -- or `errIO` when no shell could be started at all. A
  command the shell could not find is *not* that: it is the shell exiting
  127, which is a code. }
function Run(command: CommandLine): RunResult;

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
    r.reason := errIO
  else
    r.code := ExitCode(status);
  Run := r
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
