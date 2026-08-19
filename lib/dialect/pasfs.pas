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

  **What it cannot tell you is why.** A failure here is `errIO` and nothing
  finer, because `errno` is not reachable: glibc spells it
  `*__errno_location()`, a function returning `int *`, and a pointer result is
  the thing ADR-0122 does not admit. So "the file was not there" and "the
  directory is not writable" arrive as one code. That is a real cost of the
  narrowness and it is written here rather than discovered; the first thing the
  increment after ADR-0122 buys is the ability to say which.

  **And it cannot read a header.** `access` takes R_OK, W_OK and X_OK, which
  are numbers a C header would have supplied and an FFI without a header parser
  cannot see. F_OK is 0 and 0 is 0 everywhere, so `Exists` is offered and the
  other three are not -- writing 4 and 2 into a Pascal source would be
  asserting a value this module has no way to check. }

module PasFS;

export PasFS = (MaxPath, PathName,
                Remove, Rename, MakeDirectory, RemoveDirectory, Exists);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

const
  { Long enough for Linux's PATH_MAX, which is 4096, and for the shorter
    limits every other system has. A number this module *can* check, unlike
    the `access` modes above: an over-long path is refused by the assignment
    that builds it rather than truncated at the boundary. }
  MaxPath = 4096;

type
  { The type the five routines below take. Exported so a caller can declare a
    variable of it; a caller passing a literal or a shorter string needs
    nothing, ADR-0115 having made a variable-string a value parameter. }
  PathName = string(MaxPath);

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

end.
