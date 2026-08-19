{ PasIO -- descriptor input and output, and the first user of ADR-0129's
  buffer.

  Every module under lib/dialect/ before this one takes a string and answers a
  number, because that was the whole of what ADR-0122 admitted. This one moves
  **bytes**, which is what the FFI was being built towards: a slice crosses as
  the pair `(ptr, i64)` and `read` and `write` take exactly that, so the count
  the operating system is given is one the compiler computed from the
  designator and checked against the array. A caller cannot ask for more than
  the buffer holds, because there is no parameter through which to ask.

  Like every module here it is **dialect-only**, twice over: `external` and
  `array of T` are admitted under --std=afterschool alone (ADR-0117's
  containment), and ADR-0119 makes a dialect module unimportable by a
  conformance-mode program.

  **Three narrownesses, and each is a number this module cannot check.**

  - **Only O_RDONLY.** `open` needs O_WRONLY, O_CREAT and O_TRUNC to create
    anything, and those are header numbers an FFI without a header parser
    cannot see -- PasFS's own policy, arrived at over `access`'s R_OK, W_OK
    and X_OK. O_RDONLY is 0, which is the one flag value a header is not
    needed for, so this module reads files and writes only to descriptors that
    were already open.
  - **It cannot say why.** A failure is `errIO` and nothing finer, because
    `errno` is `*__errno_location()` and a returned pointer is what ADR-0122
    does not admit. Same wall PasFS records, and it is still the first thing
    the next increment would buy.
  - **It does not share a descriptor with the standard's own I/O.** 6.9 and
    6.10's `read` and `write` go through the runtime's buffered streams;
    everything here is a descriptor and unbuffered. Writing to `StdOut` from
    both interleaves by whichever flushed last, which is not a defect in
    either and cannot be fixed from this side. Use a descriptor the program
    opened, or accept the ordering. }

module PasIO;

export PasIO = (StdIn, StdOut, StdErr, IOMax, IOLine,
                FdResult, CountResult,
                OpenRead, Close, ReadInto, WriteFrom, WriteAll, WriteText,
                AtEnd, CountOr, ResultText);

{ 6.11.1 puts the import-part inside the module-block, after the export-part.
  PasFS supplies PathName rather than this module declaring a second one: a
  program that opens a file here and removes it there should not have two path
  types alike. }
import PasError;
       PasFS;

const
  { POSIX fixes these three and a header is not needed for them, which is why
    they are the only descriptor numbers written out anywhere here. }
  StdIn  = 0;
  StdOut = 1;
  StdErr = 2;

  { The capacity of IOLine, and the size of the buffer WriteText builds in.
    Not a limit on ReadInto or WriteFrom, which take the caller's own array
    and are bounded by it. }
  IOMax = 4096;

type
  IOLine = string(IOMax);

  { ADR-0120's shape twice, because with no generics a payload type is part of
    the layout and one record cannot carry both. The tag is spelled `ok` in
    every result record here; the payload's name is each record's own. }
  FdResult = record
    case ok: boolean of
      true:  (fd: integer);
      false: (openCode: ErrorCode)
    end;

  CountResult = record
    case ok: boolean of
      true:  (count: integer);
      false: (code: ErrorCode)
    end;

{ Open an existing file for reading. `errIO` where the operating system
  refused, which covers a path that is not there and one that may not be read.

  There is no OpenWrite, and the reason is above: creating a file needs flag
  values this module has no way to check. }
function OpenRead(path: PathName) = r: FdResult;

{ Close a descriptor. Closing one this module did not open is allowed and is
  the caller's business; closing one twice is refused by the operating system
  and arrives as `errIO`. }
function Close(fd: integer): ErrorCode;

{ Read into the caller's buffer, at most `length(buf)` bytes, and answer how
  many arrived. **A short answer is not a failure**: a pipe hands over what it
  has, and zero means the end of the input, which `AtEnd` is the name for.
  Nothing outside the first `count` components is written. }
function ReadInto(fd: integer; var buf: array of char) = r: CountResult;

{ Write the buffer, and answer how many bytes were taken. **A short answer is
  not a failure here either**, which is the classic way to lose data: use
  WriteAll unless the count is what you wanted. }
function WriteFrom(fd: integer; protected var buf: array of char) = r: CountResult;

{ Write the whole buffer, calling `write` again for whatever it did not take.
  This is the routine to use; WriteFrom is the primitive it is built from and
  is exported so the short write is visible rather than hidden. }
function WriteAll(fd: integer; protected var buf: array of char): ErrorCode;

{ Write a string's characters, with no terminator and nothing appended. The
  characters are copied into a buffer of this module's own because a string is
  not an array of char -- 6.4.3.3's length word is in front of them, which is
  why ADR-0125 has no slice of a string. }
function WriteText(fd: integer; s: IOLine): ErrorCode;

{ Whether a successful read reached the end of the input -- `ok` and a count
  of zero. A failed result is not at the end and answers false, because
  "nothing more to read" and "the read was refused" are different things and a
  caller that conflates them loops. }
function AtEnd(r: CountResult): boolean;

{ The count of a successful result, or `whenBad` for a failed one. Reading
  `count` here is safe for the reason the dialect makes it safe: the read is
  inside the arm the tag selects. }
function CountOr(r: CountResult; whenBad: integer): integer;

{ A result as a sentence, for a caller assembling a message rather than
  branching. }
function ResultText(r: CountResult) = t: ErrText;

end;

{ The directive, kept to this module. A slice formal is what makes these three
  headings possible: `read` and `write` take (fd, ptr, size_t) and answer
  ssize_t, and `var b: array of char` supplies the middle two of those three
  arguments from one parameter (ADR-0129). }
function ExtOpen(path: string; flags: integer): integer; external 'open';
function ExtClose(fd: integer): integer; external 'close';
function ExtRead(fd: integer; var b: array of char): int64; external 'read';
function ExtWrite(fd: integer;
                  protected var b: array of char): int64; external 'write';

{ A count that came back from the kernel, made into a result. The narrowing is
  safe and not merely checked: what `read` and `write` answer is bounded by the
  length they were given, and that length is a Pascal `integer` -- so `trunc`
  cannot reject a value either of them can produce. It would reject a value
  neither can, which is the reason to write it rather than assume. }
function Counted(n: int64) = r: CountResult;
begin
  if n < 0 then r.code := errIO else r.count := trunc(n)
end;

function OpenRead;
var fd: integer;
begin
  { O_RDONLY. See the module's own comment for why it is the only flag here. }
  fd := ExtOpen(path, 0);
  if fd < 0 then r.openCode := errIO else r.fd := fd
end;

function Close;
begin
  if ExtClose(fd) = 0 then Close := errNone else Close := errIO
end;

function ReadInto;
begin
  r := Counted(ExtRead(fd, buf))
end;

function WriteFrom;
begin
  r := Counted(ExtWrite(fd, buf))
end;

function WriteAll;
var done, n: integer; r: CountResult; e: ErrorCode;
begin
  done := 0;
  e := errNone;
  n := length(buf);
  while (done < n) and (e = errNone) do begin
    { A slice of a slice: what is left to write, from where the last call
      stopped. ADR-0125 lets a slice formal bind to another slice, so this
      needs no index arithmetic outside the designator. }
    r := WriteFrom(fd, buf[done + 1..n]);
    if r.ok then
      { A write that takes nothing is not progress, and looping on it would
        not terminate. The operating system does not do this to a regular
        file or a pipe; refusing to spin is cheaper than proving it cannot. }
      if r.count > 0 then done := done + r.count else e := errIO
    else
      e := r.code
  end;
  WriteAll := e
end;

function WriteText;
var b: array [1..IOMax] of char; k, n: integer;
begin
  n := length(s);
  for k := 1 to n do b[k] := s[k];
  { b[1..0] is the empty slice, so a zero-length write needs no arm of its
    own. It does not reach the operating system: WriteAll's loop is `while
    done < n` and there is nothing to write, so no `write` is made. Use
    WriteFrom for the call itself. }
  WriteText := WriteAll(fd, b[1..n])
end;

function AtEnd;
begin
  AtEnd := r.ok and (r.count = 0)
end;

function CountOr;
begin
  if r.ok then CountOr := r.count else CountOr := whenBad
end;

function ResultText;
begin
  if r.ok then t := 'read or wrote what was asked'
  else t := ErrorText(r.code)
end;

end.
