{ PasDir -- reading a directory.

  The last row of doc/roadmap.md's "What blocks the library", and the module
  the four FFI increments were aiming at. What it needed from the language was
  a type for a `DIR *` -- an address the *callee* owns, which AP 6.7.7.9 c)
  kept out until the handle-type (AP 6.4.12, ADR-0174) -- and after that,
  nothing.

  **It does not use ADR-0187, and that is worth saying, because ADR-0187 is the
  record that struck this item off the roadmap.** An `external` function may
  now answer an optional of a record, so a program may declare `struct dirent`
  and receive a copy of one at the call. A *library* may not, and the rule is
  ADR-0185's fifth decision: `struct dirent` is a different struct on two
  systems -- glibc puts an `unsigned short` and an `unsigned char` before
  `d_name`, macOS a 64-bit seek offset and two 16-bit fields, and POSIX itself
  requires only `d_ino` and `d_name`, in any order -- so a field list written
  here would be one platform's layout in a module that has to run where nobody
  here can build. `pasx_dir_next` reads the member instead, compiled by the C
  compiler of the target against the target's own header. ADR-0188 records the
  two rules meeting.

  **`opendir` and `closedir` are bound directly** and need no runtime routine,
  because neither has a struct in its signature. So the handle is this module's
  and only the member access is the runtime's, which is as small as the
  dependency gets.

  **What an entry is, PasFS answers.** There is no kind here. `d_type` is not
  POSIX -- it is invisible under `_POSIX_C_SOURCE`, which is what the runtime's
  POSIX half is compiled with -- and where it exists it is `DT_UNKNOWN` on
  filesystems that do not carry it. So a caller wanting to know composes:
  `PasFS.Info(dir + '/' + name)`, which is one `stat` and an honest answer.

  **The order is the file system's**, which is neither sorted nor stable, and
  `.` and `..` are entries like any others. `NextEntry` gives every entry; `ListDir`
  is the convenience and skips those two, so an empty vector means an empty
  directory.

  **A directory changed while it is being read** has no answer here and none in
  POSIX: whether an entry created or removed after `OpenDir` appears is
  unspecified. Read a directory you are also modifying and the result is
  whatever the file system does.

  Like every module under lib/dialect/ it is dialect-only: `external` is
  admitted by this dialect alone (ADR-0117's containment), and
  ADR-0119 makes a dialect module unimportable by a conformance-mode program. }

module PasDir;

export PasDir = (EntryNameMax, EntryName, Dir, OpenDir, NextEntry, CloseDir, ListDir);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;
       PasFS;
       PasStrVec;

const
  { POSIX's NAME_MAX, which is 255 on every system this runs on. _POSIX_NAME_MAX
    is 14 and is a floor nobody has been at for thirty years. A name longer than
    this is reported as `errFull` by the runtime, which knows the length -- not
    truncated, and not the trap an over-long copy would be. }
  EntryNameMax = 255;

type
  { An open directory this program owns; `closedir` is what releases it
    (AP 6.4.12.1), so the variable's block is the stream's lifetime. }
  Dir = handle external 'closedir';

  { One entry's name -- a name and not a path, so it holds no separator and
    the caller joins it to the directory it came from. It is StrVec's ItemMax
    exactly, which is why `ListDir` pushes one without a conversion, and it is
    the capacity at which `NextEntry` cannot answer `errFull`. A caller wanting a
    shorter string may pass one and be told. }
  EntryName = string(EntryNameMax);

  { How the name stops being a C pointer (ADR-0123). Not exported: a caller
    sees an EntryName, and the copy is made at the call site. }
  OptEntryName = ?EntryName;

{ Open a directory for reading. `errIO` where the operating system refused,
  which covers a path that is not there and a path that is not a directory --
  PasFS.Exists and PasFS.Info are how a caller tells those apart, and
  PasOS.LastErrorText is the sentence. What `d` held before is released first,
  whichever way this answers. }
function OpenDir(var d: Dir; path: PathName): ErrorCode;

{ The next entry's name into `name`, which is a string of the caller's own
  capacity -- StreamReadLine's shape, so an EntryName is a convenience and
  not an obligation.

  `errNone` and `name` holds it; `errAbsent` when the directory is exhausted,
  which is the ordinary end of a loop and not a failure; `errFull` for a name
  longer than `name` can hold, whose entry is consumed rather than retried,
  there being no way to put one back; `errIO` for anything else.

      while NextEntry(d, nm) = errNone do writeln(nm)

  **The capacity is checked on the far side**, by the routine that measured the
  name, so an over-long one is a code and never the trap an over-long copy
  would be. That is the one place a library can close doc/sop.md §7's "a
  foreign string of unstated length has no safe reception": the length *is*
  stated, to whoever holds the pointer.

  `name` is set to the null-string on every answer but `errNone`. }
function NextEntry(var d: Dir; var name: string): ErrorCode;

{ Release the directory now rather than at the block's end, and leave `d`
  empty. Harmless on an empty one.

  AP 6.4.12.2's second form of assignment: `d := nil` releases what the
  variable holds and leaves it empty. It was `opendir` of the empty path until
  ADR-0202, the type having had one form of assignment and that one from an
  external function, which cost a refused system call and a stale errno. This
  module and PasStream are the two callers that argued for the form. }
procedure CloseDir(var d: Dir);

{ Every entry of a directory onto `names`, in the file system's own order,
  with `.` and `..` left out -- so an empty vector means an empty directory.

  The vector must have been created with `SVecNew` and is not cleared first,
  which is PasProcess.CaptureLines's contract for the same type. A failure
  part-way leaves what was read: the answer is the failure's code, and the
  entries already pushed are still there. `errNone` when the directory was
  read to its end. }
function ListDir(path: PathName; var names: StrVecPtr): ErrorCode;

end;

{ The directive, kept to this module. `opendir` and `closedir` are C's own --
  neither has a struct in its signature, so neither needs the runtime -- while
  the one call that reads a member of `struct dirent` does. }
function ExtOpendir(path: string): Dir; external 'opendir';

{ The runtime's, and ADR-0185's fifth decision is why (see the header). It
  answers libc's own storage, valid until the next call, which ADR-0123's
  optional copies at the call site before that matters. `cap` is checked over
  there because the length is known over there: 0 with a name, 1 exhausted,
  2 refused, 3 too long. }
function ExtDirNext(d: Dir; cap: integer;
                    var status: integer): OptEntryName;
  external 'pasx_dir_next';

function OpenDir;
begin
  d := ExtOpendir(path);
  if d = nil then OpenDir := errIO else OpenDir := errNone
end;

function NextEntry;
var got: OptEntryName; status: integer;
begin
  status := 0;
  { the caller's capacity and not EntryNameMax: what must not be exceeded is the
    string this answer is going into, and 6.4.3.3.3 makes that readable }
  got := ExtDirNext(d, name.capacity, status);
  name := '';
  { The value decides the successful case and the code decides the rest: a
    routine answering 0 with no name would be a defect over there, and reading
    `got^` for it is the trap that says so rather than a null-string entry. }
  if got = nil then begin
    if status = 1 then NextEntry := errAbsent
    else if status = 3 then NextEntry := errFull
    else NextEntry := errIO
  end
  else begin
    name := got^;
    NextEntry := errNone
  end
end;

procedure CloseDir;
begin
  { 6.4.12.2's second form: the release is the assignment's (ADR-0202) }
  d := nil
end;

function ListDir;
var d: Dir; e: ErrorCode; nm: EntryName;
begin
  { `d` is a local of this activation, so the directory is closed when ListDir
    returns -- by every path out of it, including the failures below. That is
    what the handle-type is for and it is why nothing here says CloseDir. }
  e := OpenDir(d, path);
  if e = errNone then begin
    e := NextEntry(d, nm);
    while e = errNone do begin
      if (nm <> '.') and (nm <> '..') then SVecPush(names, nm);
      e := NextEntry(d, nm)
    end;
    { reaching the end is how a listing succeeds }
    if e = errAbsent then e := errNone
  end;
  ListDir := e
end;

end.
