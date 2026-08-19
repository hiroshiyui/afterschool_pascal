{ PasFS -- the file system as an operating system offers it, reached by
  ADR-0122's string boundary.

  This module is the first user of a foreign *pointer*, and it exists to hold
  one claim still: **a string crosses as a `const char` pointer and nothing
  comes back as one.** Everything below takes a path and answers a number,
  which is exactly the shape ADR-0122 admits -- and it is not a coincidence
  that the operations here are the ones with that shape. `getcwd`, `readlink`
  and `strerror` all hand a pointer back and are absent for that reason, not
  because they were forgotten.

  Like every module under lib/dialect/ it is **dialect-only**, twice over:
  `external` is admitted under --std=afterschool alone (ADR-0117's
  containment), and ADR-0119 makes a dialect module unimportable by a
  conformance-mode program (ADR-0121 decision 5).

  **What it cannot tell you is why, and PasOS can.** A failure here is `errIO`
  and nothing finer, so "the file was not there" and "the directory is not
  writable" arrive as one code. That is deliberate rather than a limit now:
  the code is the closed set a `case` can cover, and the *sentence* is
  `PasOS.LastErrorText`, read in the statement after the one that failed
  (ADR-0131). What this module still cannot do is map one to the other, ENOENT
  and EACCES being numbers in a header it cannot read.

  The paragraph that stood here said `errno` was unreachable because glibc
  spells it `*__errno_location()` and a pointer result is what ADR-0122 does
  not admit. That was true and was not the reason: C specifies `errno` as a
  **macro**, so it has no linker symbol for any foreign-function interface to
  bind, and the answer was always `runtime/pasrt.c`.

  **And it cannot read a header.** `access` takes R_OK, W_OK and X_OK, which
  are numbers a C header would have supplied and an FFI without a header parser
  cannot see. F_OK is 0 and 0 is 0 everywhere, so `Exists` is offered and the
  other three are not -- writing 4 and 2 into a Pascal source would be
  asserting a value this module has no way to check. }

module PasFS;

export PasFS = (MaxPath, PathName, PathResult,
                Remove, Rename, MakeDirectory, RemoveDirectory, Exists,
                WorkingDirectory, LinkTarget, PathOr);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

const
  { Long enough for Linux's PATH_MAX, which is 4096, and for the shorter
    limits every other system has. A number this module *can* check, unlike
    the `access` modes above: an over-long path is refused by the assignment
    that builds it rather than truncated at the boundary. }
  MaxPath = 4096;

type
  { The type the routines below take. Exported so a caller can declare a
    variable of it; a caller passing a literal or a shorter string needs
    nothing, ADR-0115 having made a variable-string a value parameter. }
  PathName = string(MaxPath);

  { ADR-0120's shape, for the two routines that answer a path rather than
    only succeeding or failing. The tag is spelled `ok` in every result record
    in this library; the payload's name is each record's own. }
  PathResult = record
    case ok: boolean of
      true:  (path: PathName);
      false: (code: ErrorCode)
    end;

  { The buffer the two of them lend to C, and it is **packed** deliberately.
    ADR-0125 refuses a slice of a packed array of char -- `b[1..n]` there is
    6.5.6's substring -- but the whole array still binds to a slice formal,
    and being a string-type is what lets one assignment turn 4096 characters
    into a string instead of 4096 concatenations. }
  PathBuffer = packed array [1..MaxPath] of char;

  { `getcwd`'s result: the buffer it was handed, or null where it would not
    fit. Not exported -- a caller sees a PathResult, and the optional is how
    the pointer stops being one at the call site (ADR-0123). }
  OptPathName = ?PathName;

{ A routine with nothing to return still has to be able to fail, and ADR-0120's
  result record cannot serve it: the safety there comes from the *payload*
  being what sets the tag, and an arm with no payload has nothing to set it
  with. So these answer an ErrorCode directly, `errNone` being success -- which
  is the reading PasError's own comment on errNone already asks for. }

{ Delete a file. `errIO` where the operating system refused, which covers a
  path that was not there. }
function Remove(path: PathName): ErrorCode;

{ Move a file, within one file system. `rename` across file systems fails
  rather than copying, and this cannot say which failure it was. }
function Rename(oldPath, newPath: PathName): ErrorCode;

{ Create a directory, readable by all and writable by its owner. The mode is
  not a parameter because a caller would have to write the octal permission
  bits as a decimal number, there being no octal literal in either standard --
  and a number nothing here can check is what this module is trying not to
  have. }
function MakeDirectory(path: PathName): ErrorCode;

{ Delete a directory. It must be empty; a directory that is not is a refusal
  like any other. }
function RemoveDirectory(path: PathName): ErrorCode;

{ Whether the path names something at all. This is `access(path, F_OK)`, and
  the answer is a boolean rather than a result because the failure *is* the
  answer -- there is nothing else it could mean. }
function Exists(path: PathName): boolean;

{ The process's current working directory.

  This is the first routine here whose C counterpart answers a **pointer**,
  and it needed no new mechanism: `getcwd` writes into a buffer the caller
  owns and returns that same buffer or null, so ADR-0129's slice lends it the
  storage and ADR-0123's optional copies the characters back at the call site.
  No C pointer becomes a value this module holds.

  `errIO` covers a directory that has been removed underneath the process, and
  `errFull` a path longer than MaxPath. }
function WorkingDirectory = r: PathResult;

{ What a symbolic link points at, unfollowed.

  `errIO` where the path is not a link or cannot be read. **`errFull` where the
  answer filled the buffer exactly**, which is the one place this module has to
  guess: `readlink` does not terminate what it writes and answers the number of
  bytes placed, so a result equal to the capacity means "possibly truncated"
  and cannot be told from one that just fits. Reporting the ambiguous case as a
  failure is the safe direction; the alternative silently returns a path that
  may be short. }
function LinkTarget(path: PathName) = r: PathResult;

{ The path of a successful result, or `whenBad` for a failed one. Reading
  `path` here is safe for the reason the dialect makes it safe: the read is
  inside the arm the tag selects. }
function PathOr(r: PathResult; whenBad: PathName): PathName;

end;

{ The directive, kept to this module. An exported constituent's linkage name is
  composed from the interface and the constituent spelling (6.13); a foreign
  name is whatever the program wrote, so the two can never be the same routine
  and a binding module always has this pair of layers. }
function ExtRemove(path: string): integer; external 'remove';
function ExtRename(a, b: string): integer; external 'rename';
function ExtMkdir(path: string; mode: integer): integer; external 'mkdir';
function ExtRmdir(path: string): integer; external 'rmdir';
function ExtAccess(path: string; mode: integer): integer; external 'access';

{ The two that lend a buffer. A slice supplies the pointer *and* the size from
  one parameter (ADR-0129), so each of these headings has one formal fewer than
  its C counterpart. `getcwd` answers its own argument or null, which is an
  optional string (ADR-0123); `readlink` answers a count. }
function ExtGetcwd(var b: array of char): OptPathName; external 'getcwd';
function ExtReadlink(path: string;
                     var b: array of char): int64; external 'readlink';

{ Every one of the five reports the same way: 0 or -1, with the reason in an
  errno this cannot read. }
function Refused(rc: integer): ErrorCode;
begin
  if rc = 0 then Refused := errNone else Refused := errIO
end;

function Remove;
begin
  Remove := Refused(ExtRemove(path))
end;

function Rename;
begin
  Rename := Refused(ExtRename(oldPath, newPath))
end;

function MakeDirectory;
begin
  { 493 is 0o755. Written as a decimal because neither standard has an octal
    literal, and named here so the next reader does not have to work it out. }
  MakeDirectory := Refused(ExtMkdir(path, 493))
end;

function RemoveDirectory;
begin
  RemoveDirectory := Refused(ExtRmdir(path))
end;

function Exists;
begin
  { F_OK, and the one `access` mode whose value a header is not needed for. }
  Exists := ExtAccess(path, 0) = 0
end;

function WorkingDirectory;
var b: PathBuffer; got: OptPathName;
begin
  { The whole array, so the size C is given is MaxPath and is one this
    compiler computed. }
  got := ExtGetcwd(b);
  if got = nil then
    { ERANGE and anything else arrive alike, so the code is the one that says
      a bound was reached: a path this module cannot hold is the overwhelmingly
      likely reading, and PasOS.LastErrorText is where the difference is. }
    r.code := errFull
  else
    r.path := got^
end;

function LinkTarget;
var b: PathBuffer; n: int64; t: PathName;
begin
  n := ExtReadlink(path, b);
  if n < 0 then
    r.code := errIO
  else if n = MaxPath then
    { Filled exactly, and `readlink` writes no terminator -- so this cannot be
      told from a target that happens to be MaxPath characters long. Reported
      as a failure, that being the safe direction.

      **No test reaches this arm and none can here.** MaxPath is 4096 because
      Linux's PATH_MAX is, and the kernel will not create a link whose target
      is longer than PATH_MAX - 1 -- so `readlink` cannot fill the buffer this
      module lends it. The guard is against a system whose limit is larger,
      which is a number this module cannot read any more than it can read
      O_WRONLY. Written because being wrong in the other direction returns a
      truncated path as though it were whole. }
    r.code := errFull
  else begin
    { One assignment rather than a loop: PathBuffer is a packed array of char
      and therefore a string-type (6.4.3.2), so this is a whole-string
      assignment and the substring after it takes the part `readlink` wrote. }
    t := b;
    r.path := t[1..trunc(n)]
  end
end;

function PathOr;
begin
  if r.ok then PathOr := r.path else PathOr := whenBad
end;

end.
