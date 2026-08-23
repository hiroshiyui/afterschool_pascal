{ PasStream -- buffered input and output on a stream the program owns.

  PasIO moves bytes through a descriptor and cannot create a file, because
  `open`'s O_WRONLY and O_CREAT are header numbers this FFI cannot read. ISO
  C's `fopen` takes its mode as a *string* -- "r", "w", "a" -- and answers a
  `FILE *`, which AP 6.7.7.9 c) kept out until there was a type for it. The
  handle-type (AP 6.4.12, ADR-0174) is that type, and this module is the
  first library built on it: the stream is a `Stream`, a variable the program
  owns, closed when the variable dies -- at the block's end, on a `goto` out
  of it, on `halt` -- and closed again by nothing.

  **The shape a handle forces.** A handle cannot be a Pascal function's
  result and cannot be copied, so every routine here takes the stream as a
  `var` parameter and `Open*` fill one the caller declared. What a caller
  writes is

      var s: Stream;
      if OpenWrite(s, 'notes.txt') = errNone then ...

  and nothing else about `s` is the caller's business: `s <> nil` asks whether
  it is open, and that is the only comparison the type has.

  **Close.** AP 6.4.12.2 gives a handle exactly one assignment, from an
  external function of its type, and the release happens on that assignment.
  There is no `s := nil`, so `Close` here is that assignment with a function
  that answers null: `fopen` of the empty path, which POSIX refuses with
  ENOENT. It releases what `s` held and leaves it empty, and it costs one
  failed system call and a stale `errno` -- `PasOS.LastErrorText` read after
  `Close` names the empty path and not whatever failed before it. The
  roadmap carries the spelling that would remove this.

  **Lines and capacity.** `ReadLine` reads up to and including the next
  newline, stores what fits in the caller's string, and discards the rest of
  the line rather than handing it to the next call: a line is a line, and a
  string too short for it loses the tail, as `readln` into a string does.
  The end of the stream is a `false` answer with nothing read; a final line
  without a newline is still a line. Characters are read one at a time with
  `fgetc`, because `fgets` takes an `int` count and `fread` a pair of sizes,
  and this FFI has no way to write either signature without a number it
  would have to check. `FILE *` buffers for it, so the cost is a call, not a
  system call, per character.

  **What is not here.** Seeking, binary reads into a buffer, and sharing a
  stream with the standard's own `output`: §6.10's files are the runtime's
  streams and these are libc's, and the two buffer separately. `Flush`
  exists for the moment a program writes through one and reads back through
  the other. }

module PasStream;

export PasStream = (Stream, LineMax, StreamLine,
                    OpenRead, OpenWrite, OpenAppend, Close,
                    WriteText, WriteLine, ReadLine, Flush);

import PasError;
       PasFS;

const
  { The capacity of StreamLine. ReadLine is bounded by the caller's own
    string and not by this. }
  LineMax = 4096;

type
  { A stream this program owns; `fclose` is what releases it (AP 6.4.12.1). }
  Stream = handle external 'fclose';
  StreamLine = string(LineMax);

{ Open an existing file for reading; `errIO` where the operating system
  refused, which covers a path that is not there. What `s` held before is
  released first, whichever way this answers. }
function OpenRead(var s: Stream; path: PathName): ErrorCode;

{ Create or truncate a file and open it for writing. }
function OpenWrite(var s: Stream; path: PathName): ErrorCode;

{ Open a file for writing at its end, creating it if it is not there. }
function OpenAppend(var s: Stream; path: PathName): ErrorCode;

{ Release the stream now rather than at the block's end, and leave `s`
  empty. Harmless on an empty one. See the header for what it costs. }
procedure Close(var s: Stream);

{ Write a string's characters, nothing appended. `errIO` on a refusal, which
  for a buffered stream is usually reported late -- by `Flush` or `Close`
  rather than here. A stream that is not open is a run-time error, AP
  6.4.12.4's, and the message names the lend. }
function WriteText(var s: Stream; text: StreamLine): ErrorCode;

{ The string and then a newline. }
function WriteLine(var s: Stream; text: StreamLine): ErrorCode;

{ The next line into `line`, without its newline, as far as it fits; the rest
  of a longer line is discarded. `false` at the end of the stream, when
  nothing was read. }
function ReadLine(var s: Stream; var line: string): boolean;

{ Hand what the stream has buffered to the operating system. }
function Flush(var s: Stream): ErrorCode;

end;

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(text: string; f: Stream): integer; external 'fputs';
function ExtFputc(c: integer; f: Stream): integer; external 'fputc';
function ExtFgetc(f: Stream): integer; external 'fgetc';
function ExtFflush(f: Stream): integer; external 'fflush';

const
  { ISO C's EOF is "a negative integer constant", and -1 everywhere this
    compiler admits; the tests below ask `< 0` and never the number. }
  NewLine = 10;

function Opened(var s: Stream): ErrorCode;
begin
  if s = nil then Opened := errIO
  else Opened := errNone
end;

function OpenRead;
begin
  s := ExtFopen(path, 'r');
  OpenRead := Opened(s)
end;

function OpenWrite;
begin
  s := ExtFopen(path, 'w');
  OpenWrite := Opened(s)
end;

function OpenAppend;
begin
  s := ExtFopen(path, 'a');
  OpenAppend := Opened(s)
end;

procedure Close;
begin
  { the one assignment 6.4.12.2 admits, with an answer that is always null:
    the release is the assignment's, and the empty path opens nothing }
  s := ExtFopen('', 'r')
end;

function WriteText;
begin
  if ExtFputs(text, s) < 0 then WriteText := errIO
  else WriteText := errNone
end;

function WriteLine;
var e: ErrorCode;
begin
  e := WriteText(s, text);
  if e = errNone then
    if ExtFputc(NewLine, s) < 0 then e := errIO;
  WriteLine := e
end;

function ReadLine;
var c, n: integer;
begin
  line := '';
  n := 0;
  c := ExtFgetc(s);
  while (c >= 0) and (c <> NewLine) do begin
    n := n + 1;
    if n <= line.capacity then
      line := line + chr(c);
    c := ExtFgetc(s)
  end;
  { a read that found the end at once is the end; one that found characters
    or a newline first was a line, the last one when there is no newline }
  ReadLine := (n > 0) or (c = NewLine)
end;

function Flush;
begin
  if ExtFflush(s) < 0 then Flush := errIO
  else Flush := errNone
end;

end.
