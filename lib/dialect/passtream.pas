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
      if StreamOpenWrite(s, 'notes.txt') = errNone then ...

  and nothing else about `s` is the caller's business: `s <> nil` asks whether
  it is open, and that is the only comparison the type has.

  **`Close`** is `s := nil`, AP 6.4.12.2's second form of assignment: the
  variable releases what it holds and is empty afterwards, ready to be opened
  again. It was `fopen` of the empty path until ADR-0202 -- the type had one
  form of assignment, from an external function, so closing early meant
  opening something that would fail. That cost a refused system call and a
  stale `errno`, and `PasOS.LastErrorText` read after `s.Close` named the empty
  path rather than whatever had actually failed. This module and `PasDir` are
  the two callers that argued for the form.

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
  streams and these are libc's, and the two buffer separately. `Flush` exists
  for the moment a program writes through one and reads back through the
  other. }

module PasStream;

{ **What a client is given is the types, and the types carry their routines**
  (AP 6.7.10.5, ADR-0411). Six names are exported where eleven were: `Stream`
  has an implementation in the block below, and an implementation is selected
  from the *type* of the receiver rather than from a name in scope
  (AP 6.7.10.2), so none of its routines is an exported name and none can
  collide with another module's. That is what retired the `Stream` prefix from
  five of them: `StreamWriteText` is `WriteText`, `StreamWriteLine` is
  `WriteLine`, `StreamReadLine` is `ReadLine`, `StreamFlush` is `Flush` and
  `StreamClose` is `Close` -- the first four spelled as `PasNet`'s `Socket`
  and `PasTls`'s `Connection` spell them, so a byte stream reads one way
  wherever it came from.

  What stays exported is what a caller has to name **before there is a
  receiver to select from**: the type, its two bounds, and the three routines
  that make a stream rather than act on one. `StreamOpenRead`,
  `StreamOpenWrite` and `StreamOpenAppend` each take their `Stream` as
  somewhere to put an answer, so there is nothing yet for AP 6.7.10.2 to
  select from; they keep the prefix for §6.11.2's reason, being names in one
  scope with every other module's. `PasNet`'s `NetConnect` and `NetListen` are
  the same decision one library over.

  `ReadLine` answers a `boolean` where `Socket`'s answers an `ErrorCode`, and
  that is lib/dialect/README.md's first rule rather than an inconsistency: the
  end of a file is not a failure, where a far end that closed is something a
  caller may want to tell from a refusal. }

export PasStream = (Stream, StreamLineMax, StreamLine,
                    StreamOpenRead, StreamOpenWrite, StreamOpenAppend);

import PasError;
       PasFS;

const
  { The capacity of StreamLine. `Stream.ReadLine` is bounded by the caller's
    own string and not by this. }
  StreamLineMax = 4096;

type
  { A stream this program owns; `fclose` is what releases it (AP 6.4.12.1). }
  Stream = handle external 'fclose';
  StreamLine = string(StreamLineMax);

{ Open an existing file for reading; `errIO` where the operating system
  refused, which covers a path that is not there. What `s` held before is
  released first, whichever way this answers. }
function StreamOpenRead(var s: Stream; path: PathName): ErrorCode;

{ Create or truncate a file and open it for writing. }
function StreamOpenWrite(var s: Stream; path: PathName): ErrorCode;

{ Open a file for writing at its end, creating it if it is not there. }
function StreamOpenAppend(var s: Stream; path: PathName): ErrorCode;

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

function Opened(protected var s: Stream): ErrorCode;
begin
  if s = nil then Opened := errIO
  else Opened := errNone
end;

function StreamOpenRead;
begin
  if HoldsNul(path) then exit(errSyntax);
  s := ExtFopen(path, 'r');
  StreamOpenRead := Opened(s)
end;

function StreamOpenWrite;
begin
  if HoldsNul(path) then exit(errSyntax);
  s := ExtFopen(path, 'w');
  StreamOpenWrite := Opened(s)
end;

function StreamOpenAppend;
begin
  if HoldsNul(path) then exit(errSyntax);
  s := ExtFopen(path, 'a');
  StreamOpenAppend := Opened(s)
end;

{ --- the stream ----------------------------------------------------------- }

impl Stream;

  { Write a string's characters, nothing appended. `errIO` on a refusal, which
    for a buffered stream is usually reported late -- by `Flush` or `Close`
    rather than here. A stream that is not open is a run-time error, AP
    6.4.12.4's, and the message names the lend. }
  function WriteText(protected var s: Stream; text: StreamLine): ErrorCode;
  begin
    if ExtFputs(text, s) < 0 then WriteText := errIO
    else WriteText := errNone
  end;

  { The string and then a newline. }
  function WriteLine(protected var s: Stream; text: StreamLine): ErrorCode;
  var e: ErrorCode;
  begin
    e := s.WriteText(text);
    if e = errNone then
      if ExtFputc(NewLine, s) < 0 then e := errIO;
    WriteLine := e
  end;

  { The next line into `line`, without its newline, as far as it fits; the rest
    of a longer line is discarded. `false` at the end of the stream, when
    nothing was read. }
  function ReadLine(protected var s: Stream; var line: string): boolean;
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

  { Hand what the stream has buffered to the operating system. }
  function Flush(protected var s: Stream): ErrorCode;
  begin
    if ExtFflush(s) < 0 then Flush := errIO
    else Flush := errNone
  end;

  { Release the stream now rather than at the block's end, and leave `s`
    empty. Harmless on an empty one. See the header for what it costs. }
  procedure Close(var s: Stream);
  begin
    { 6.4.12.2's second form: the assignment releases what the variable holds
      and leaves it empty. It was `ExtFopen('', 'r')` until ADR-0202 -- an
      assignment whose answer is always null, costing a refused system call and
      a stale errno, because until then the type had one form of assignment and
      it had to come from an external function }
    s := nil
  end;
end;

end.
