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
  - `time` is ISO C and takes a pointer that may be null. Null is a `clong`
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
                     ArgV, NewArgs, AddArg, ArgsLen, DropArgs, Deadline,
                     Execute, ExecuteInto, ExecuteBoth,
                     ExecuteLines, ExecuteToFile,
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

{ --- a command as words, not as a line (ADR-0362) -------------------------

  `Run` and the two captures hand a *string* to a shell, and the shell then
  decides where one word ends and the next begins. That is right for a command
  the program wrote out and wrong for one assembled out of values, because
  every value in it is read as syntax: a path holding an apostrophe closes the
  quoting a caller put round it, and what follows is a command. It is not a
  hypothetical -- `lsp/pasls.pas` quoted a path from its client exactly that
  way and ADR-0362 has the probe that ran a command through it.

  These four are the other interface. The words are carried as words, no shell
  is started, and nothing in an argument means anything. Prefer them wherever
  any part of the command came from outside the program; `Run` stays the right
  answer for a pipeline, a redirection, or a line a person wrote.

  An `ArgV` is a handle (AP 6.4.12): it owns its words, it cannot be copied,
  and it is released when the variable holding it ceases to exist. The words
  are built on the far side because argv is an array of pointers, which
  AP 6.7.7.6.2's boundary cannot spell -- so a caller pushes one string at a
  time and no pointer ever crosses. }
type
  ArgV = handle external 'pasx_argv_free';

{ An empty vector, releasing whatever `v` held -- PasDir.OpenDir's rule, so
  the same variable can be used for a second command without a release
  written out. `errFull` where there was no memory, and `v` is then empty. }
function NewArgs(var v: ArgV): ErrorCode;

{ One word onto the end, copied. `arg` is a string of any capacity, which is
  the point: a path longer than a name (ADR-0291) is a word like any other,
  where a vector of `StrItem` would have cut it at 255.

  The **first** word is the program to run, as it is in argv: it is looked for
  on `PATH` when it holds no `/`, exactly as a shell would look for it, and
  everything after it is an argument and is never looked at again by anyone.

  `errAbsent` when `v` is empty -- there is nothing to add to -- and `errFull`
  at 4096 words or where there was no memory. }
function AddArg(var v: ArgV; arg: string): ErrorCode;

{ How many words are in it. 0 for an empty vector, which is also what
  `Execute` refuses. }
function ArgsLen(protected var v: ArgV): integer;

{ Put the vector back to `keep` words, dropping everything pushed after that.
  `ArgsLen` before is the mark and this is the reset, which is what a caller
  that *speculates* needs: one that pushed a candidate's words and then found
  it was the wrong candidate has no other way back. Answers how many are
  left. }
function DropArgs(var v: ArgV; keep: integer): integer;

{ How long any run of these words may take, in seconds; 0 -- the state a new
  vector is in -- is for ever, which is what a shell allows. When the time is
  up the child is killed and the run answers `errIO`, a child that did not
  exit normally; what was captured before that is kept. A grandchild that
  stays behind holding the pipe is covered too: the audit timed one stalling
  a caller for its whole life (ADR-0363). `errAbsent` for an empty vector. }
function Deadline(var v: ArgV; seconds: integer): ErrorCode;

{ Run the words and wait. The child's streams are this program's, so it
  writes where this one writes; `ok` with its exit code, as `Run` answers.

  `errAbsent` for a vector with no words in it -- there is nothing to run.
  `errIO` where the command could not be started at all, which unlike `Run`
  covers a command that is not there: no shell ran, so there is no shell to
  exit 127. A child killed by a signal is `errIO` as well, having no exit code
  of its own; doc/implementation-defined.md has both. }
function Execute(protected var v: ArgV): RunResult;

{ The same, collecting what the child writes to its standard output into
  `into`, a string of any capacity -- `Capture`'s contract word for word,
  including that what does not fit is read and dropped so the command still
  runs to its end. Its standard error goes where this program's does. }
function ExecuteInto(protected var v: ArgV; var into: string): RunResult;

{ And the same again with the child's standard error joined to its standard
  output, which is what `2>&1` was written for and what no caller can write
  here: there is no shell to read a redirection. A program asking a compiler
  what it makes of a file wants both streams and cannot ask for them any
  other way. }
function ExecuteBoth(protected var v: ArgV; var into: string): RunResult;

{ Both streams a line at a time onto `lines`, each without its newline and cut
  at `ItemMax`; the vector is not cleared first. `CaptureLines`' contract, and
  both streams for the reason `ExecuteBoth` gives -- what a caller reads this
  way is what a command *reported*, and half of that goes to standard error. }
function ExecuteLines(protected var v: ArgV; var lines: StrVecPtr): RunResult;

{ Both streams straight into the file `path` names, created or truncated, and
  nothing captured here. It is for an answer larger than a string a program
  would size for it: a caller asking a compiler for a table reads the file
  afterwards. `errIO` where the child could not be started, which includes a
  path it could not open -- the file is opened by the child, so a refusal is
  a command that never ran rather than one that ran and wrote nowhere. A
  symbolic link at `path` is refused the same way: the name is one this
  program composed, and a link planted there is not what it composed
  (ADR-0363). `errSyntax` for a path holding chr(0). }
function ExecuteToFile(protected var v: ArgV; path: string): RunResult;

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
{ `time_t` and `clock_t` are both `long` on every target this compiler
  admits, and `long` is the target's width: `clong` (AP 6.4.2.7) is what says
  so at the boundary. They were `int64`, which is right on LP64 and reads the
  high word from whatever the register held on i386 -- `Seconds` answered
  7682741216296735854 there, twice in a row, and the first case to *compute*
  with it is what noticed (ADR-0363's case 19). `Seconds` still answers an
  `int64`, the width a caller wants to subtract in. }
function ExtTime(where: clong): clong; external 'time';
function ExtClock: clong; external 'clock';
function ExtSleep(seconds: integer): integer; external 'sleep';
{ `pid_t` is the one POSIX scalar typedef this module binds, and POSIX says
  only that it is a signed integer type. `integer` is the safe direction of
  the two this FFI has: where the typedef is wider, the low word is read and
  a process identifier fits it on every system anybody runs; where `int64`
  were used and the typedef is `int`, the high word would be whatever the
  call left in the register. `time_t` above is `clong` for the same reason
  read the other way: it is a `long`, and a `long` is what `clong` is. }
function ExtGetpid: integer; external 'getpid';
{ A `FILE *` that is always null: pointer-sized, so `csize` (ADR-0364). }
function ExtFflush(stream: csize): integer; external 'fflush';

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

{ --- Execute (ADR-0362) ---------------------------------------------------

  The runtime owns the vector and the child for the reason ADR-0151 gives:
  what would cross otherwise is a `char *[]` and a process identifier, and
  AP 6.4.2.6.2 makes an integer numeric on purpose -- a program could add to
  a pid and wait for it twice. Both are handles instead. }
function ExtArgvNew: ArgV; external 'pasx_argv_new';
function ExtArgvPush(v: ArgV; s: string): integer; external 'pasx_argv_push';
function ExtArgvCount(v: ArgV): integer; external 'pasx_argv_count';
function ExtArgvDrop(v: ArgV; keep: integer): integer;
  external 'pasx_argv_drop';
procedure ExtArgvDeadline(v: ArgV; ms: integer); external 'pasx_argv_deadline';


type
  { the child, and the stream its output arrives on; the closer waits for it,
    so a block that leaves early still leaves no process behind }
  Proc = handle external 'pasx_exec_close';

function ExtExecStart(v: ArgV; capture: integer; path: string;
                      var status: integer): Proc;
  external 'pasx_exec_start';
function ExtExecGetc(p: Proc): integer; external 'pasx_exec_getc';

function NewArgs;
begin
  v := ExtArgvNew;
  if v = nil then NewArgs := errFull else NewArgs := errNone
end;

{ **The empty vector is tested for here and the far side tests for it too**,
  and the second copy is not the duplication it looks like: AP 6.4.12.3 makes
  lending an empty handle to a foreign routine a run-time error, so these
  guards are what stands between a released vector and a stopped program.
  `pasx_argv_push` answers 2 for a null of its own because it is C and cannot
  assume otherwise; that arm is reached through a vector this side let
  through, which is why `AddArg` still has somewhere to put it. }
function AddArg;
var status: integer;
begin
  if v = nil then
    AddArg := errAbsent
  else if HoldsNul(arg) then
    AddArg := errSyntax
  else begin
    status := ExtArgvPush(v, arg);
    if status = 0 then AddArg := errNone
    else if status = 1 then AddArg := errFull
    else AddArg := errAbsent
  end
end;

function ArgsLen;
begin
  if v = nil then ArgsLen := 0 else ArgsLen := ExtArgvCount(v)
end;

function DropArgs;
begin
  if v = nil then DropArgs := 0 else DropArgs := ExtArgvDrop(v, keep)
end;

function Deadline;
begin
  if v = nil then
    Deadline := errAbsent
  else if seconds < 0 then
    Deadline := errRange
  else begin
    { Milliseconds over there; a second here is the grain `Sleep` uses, and a
      run shorter than one is not what a deadline is for. }
    ExtArgvDeadline(v, seconds * 1000);
    Deadline := errNone
  end
end;

{ Every one of the three is this: start the child, read what it writes if
  anything was asked for, and take the status from the release. `Collect` above
  is the same shape over a `popen` stream, and the two are not merged because
  what they have in common is the loop and what they differ in is everything
  round it. }
procedure Spawn(protected var v: ArgV; capture: integer; path: string;
                var r: RunResult; procedure take(ch: char));
var p: Proc; status, c, code: integer;
begin
  status := ExtFflush(0);
  status := 0;
  p := ExtExecStart(v, capture, path, status);
  if p = nil then begin
    if status = 1 then r := errAbsent else r := errIO
  end
  else begin
    if (capture = 1) or (capture = 2) then begin
      c := ExtExecGetc(p);
      while c >= 0 do begin
        take(chr(c));
        c := ExtExecGetc(p)
      end
    end;
    { AP 6.4.12.5 again: the closer waits, and this is what it answered --
      the child's exit code, or -1 where it did not exit normally. }
    code := release(p);
    if code < 0 then r := errIO else r := code
  end
end;

{ `take` is never called, and a procedural parameter has to be something:
   6.7.3.4 gives no way to pass none. }
procedure Discard(ch: char);
begin
end;

function Execute;
var r: RunResult;
begin
  Spawn(v, 0, '', r, Discard);
  Execute := r
end;

{ Both readers keep `Capture`'s contract: `n` counts what the command wrote
  and the copy stops at the capacity, so an over-long answer is a prefix and
  never the trap an over-long assignment would be. }
procedure IntoString(protected var v: ArgV; capture: integer; var into: string;
                     var r: RunResult);
var n: integer;

  procedure keep(ch: char);
  begin
    n := n + 1;
    if n <= into.capacity then into := into + ch
  end;

begin
  into := '';
  n := 0;
  Spawn(v, capture, '', r, keep)
end;

function ExecuteInto;
var r: RunResult;
begin
  IntoString(v, 1, into, r);
  ExecuteInto := r
end;

function ExecuteBoth;
var r: RunResult;
begin
  IntoString(v, 2, into, r);
  ExecuteBoth := r
end;

function ExecuteLines;
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
  Spawn(v, 2, '', r, keep);
  if n > 0 then SVecPush(lines, piece);
  ExecuteLines := r
end;

function ExecuteToFile;
var r: RunResult;
begin
  if HoldsNul(path) then r := errSyntax
  else Spawn(v, 3, path, r, Discard);
  ExecuteToFile := r
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
