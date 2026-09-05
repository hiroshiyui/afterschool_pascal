{ PasFS -- the file system as an operating system offers it, reached by
  ADR-0122's string boundary.

  This module is the first user of a foreign *pointer*, and it was written to
  hold one claim: **a string crosses as a `const char` pointer and nothing
  comes back as one.** Most of what is below takes a path and answers a
  number, which is exactly the shape ADR-0122 admits, and it was not a
  coincidence that the operations here were the ones with that shape:
  `getcwd`, `readlink` and `strerror` all hand a pointer back and were absent
  for that reason and not because they had been forgotten.

  **Three of them are here now and the claim survived**, which is worth more
  than the claim did. `WorkingDirectory` and `LinkTarget` are `getcwd` and
  `readlink` (ADR-0132), and what they hand back is *the caller's own buffer
  coming home* -- ADR-0129's slice lends the storage and ADR-0123's optional
  copies the characters out at the call site, so no C pointer becomes a value
  this module holds. `TemporaryPath` is the third and the one exception to the
  shape (ADR-0243): what it names cannot be reached from Pascal at all, so the
  runtime answers, and the pointer that comes back is read once and copied in
  the same statement.

  Like every module under lib/dialect/ it is **dialect-only**: `external` is
  this dialect's and no standard has it, so nothing here would compile under
  another Pascal (ADR-0121 decision 5). Until ADR-0232 that was two facts --
  the directive needed `--std=afterschool`, and ADR-0119 made a dialect module
  unimportable by a conformance-mode program -- and with one language the
  second has nothing to say; the first is why the directory is separate.

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
                { 6.11.2: an enumerated type's values are constants of their
                  own and are exported one by one -- the type name alone
                  carries none of them, which is why PasError lists all six
                  of its codes beside ErrorCode. }
                FileKind, fkRegular, fkDirectory, fkOther,
                FileInfo, InfoResult,
                Remove, Rename, MakeDirectory, RemoveDirectory, Exists,
                WorkingDirectory, LinkTarget, Info, TemporaryPath);

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
    only succeeding or failing -- and since AP 6.4.13 the language writes the
    record, so `ok`, `val` and `cause` are its field names here and in every
    other module (ADR-0176). }
  PathResult = Fallible(PathName);

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

  { What a path names. `fkOther` is deliberately one arm and not six: this
    module answers what a program deciding *what to do next* needs, and the
    difference between a socket and a block device is not that. }
  FileKind = (fkRegular, fkDirectory, fkOther);

  { The three answers one `stat` gives, together because one call gives them
    and because asking twice would let the file change in between. `modified`
    counts seconds the way PasProcess.Seconds does -- 6.7.6.9's TimeStamp is
    what a program wanting fields rather than a count should convert it to. }
  FileInfo = record
    size: int64;
    modified: int64;
    kind: FileKind
  end;

  InfoResult = Fallible(FileInfo);

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

{ What the path names, how long it is, and when it last changed.

  **This asks the runtime and not C**, and that is ADR-0185's fifth decision
  rather than a convenience. The answer lives in `struct stat`, which AP
  6.7.7.6.2 would let this module declare and cross -- and `struct stat` is not
  the same struct on two systems, so the declaration would be one platform's
  layout written into a module that has to work on machines nobody here can
  build for. `pasx_file_info` is compiled by the C compiler *of the target*,
  reading that machine's own header, which is where a layout question can
  actually be answered. A program with a struct of its own should declare it
  and let `foreign-layout` check the claim; a library may not make one.

  `errAbsent` is nothing there, and `errIO` anything else -- most often a path
  through a directory the caller may not search. }
function Info(path: PathName) = r: InfoResult;

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

{ A path in `dir` that names nothing else, `prefix` in front of it.

  **The file is created, empty, and is the caller's from that moment**
  (ADR-0243). That is the whole difference between this and composing a name
  from `PasProcess.ProcessId`: a name is unique against every process running
  *now*, and a name whose file exists is unique against the ones that have
  already exited too. Nothing removes it -- `Remove` it when you are done with
  it, or it is a file in `dir` for ever.

  `dir` is where, and a trailing separator is optional; `prefix` is the front
  of the name and may be empty. What follows it is eight hexadecimal digits
  and nothing else, so a caller wanting an extension puts it in the prefix and
  gets it in the middle, or renames what it was given.

  `errFull` where the composed path would be longer than `MaxPath`, `errIO`
  where `dir` is not a directory the program may write, or where the names
  were all taken. }
function TemporaryPath(dir, prefix: PathName) = r: PathResult;

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

{ The runtime's, not C's, and ADR-0185's fifth decision is why -- see Info.
  Three out-parameters rather than a struct, so this module makes no claim
  about a layout it could not check on the machine it will run on. 0 is
  success, 1 is nothing there, 2 is refused. }
function ExtFileInfo(path: string;
                     var size, mtime: int64;
                     var kind: integer): integer; external 'pasx_file_info';

{ The two that lend a buffer. A slice supplies the pointer *and* the size from
  one parameter (ADR-0129), so each of these headings has one formal fewer than
  its C counterpart. `getcwd` answers its own argument or null, which is an
  optional string (ADR-0123); `readlink` answers a count. }
{ The runtime's again, and for a reason unlike Info's. `mkstemp` takes a
  `char *` it *modifies*, and the only mutable storage this interface lends is
  a slice -- which supplies a pointer and a count, so a one-argument C function
  cannot be reached through it. What is behind this name is ISO C rather than
  `mkstemp`: C11 7.21.5.3's exclusive `fopen` mode, tried in a loop. 0 with the
  name, 2 refused, 3 too long for the capacity given. }
function ExtTempName(dir, prefix: string; cap: integer;
                     var status: integer): OptPathName;
                     external 'pasx_temp_name';

function ExtGetcwd(var b: array of char): OptPathName; external 'getcwd';
function ExtReadlink(path: string;
                     var b: array of char): csize; external 'readlink';

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

function Info;
var size, mtime: int64; kind, rc: integer; got: FileInfo;
begin
  size := 0;
  mtime := 0;
  kind := 0;
  rc := ExtFileInfo(path, size, mtime, kind);
  if rc = 1 then
    r := errAbsent
  else if rc <> 0 then
    r := errIO
  else begin
    got.size := size;
    got.modified := mtime;
    { The runtime answers 1, 2 or 3 and this is where that stops being a
      number. An arm for each, rather than an ordinal conversion, because a
      value the far side invented is not a value of an enumerated type until
      something here says which one it is -- the same reason AP 6.7.7.4
      refuses an enumeration at the boundary outright. }
    if kind = 1 then got.kind := fkRegular
    else if kind = 2 then got.kind := fkDirectory
    else got.kind := fkOther;
    r := got
  end
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
    r := errFull
  else
    r := got^
end;

function TemporaryPath;
var got: OptPathName; st: integer;
begin
  got := ExtTempName(dir, prefix, MaxPath, st);
  if got = nil then
    if st = 3 then r := errFull else r := errIO
  else
    r := got^
end;

function LinkTarget;
var b: PathBuffer; n: int64; t: PathName;
begin
  n := ExtReadlink(path, b);
  if n < 0 then
    r := errIO
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
    r := errFull
  else begin
    { One assignment rather than a loop: PathBuffer is a packed array of char
      and therefore a string-type (6.4.3.2), so this is a whole-string
      assignment and the substring after it takes the part `readlink` wrote. }
    t := b;
    r := t[1..trunc(n)]
  end
end;

end.
