{ PasOS -- why the last operation failed.

  Every binding module here answers `errIO` and nothing finer, and both
  ADR-0122 and ADR-0130 recorded that as the same wall: `errno` is unreachable
  through the foreign-function interface. It is worth being exact about why,
  because the reason is not the one those records assumed. They said it is
  `*__errno_location()` and therefore a returned pointer -- true of glibc, and
  beside the point. C specifies `errno` as a **macro**, so no
  foreign-function interface can bind it: not this one, and not a better one.
  A macro has no linker symbol to name.

  So the answer is `runtime/pasrt.c`, which is where anything not expressible
  in the emitted IR has always gone, and the routine is `pasx_errno` -- the
  runtime's second surface, the one a Pascal *program* may bind rather than
  the one the compiler emits calls to. `runtime/pasrt.c` has the prefix rule.

  **What this module can say and what it cannot.** It can give the number and
  it can give libc's sentence for the number, because `strerror` answers a
  `char *` and ADR-0123's optional string is how one of those comes back. It
  cannot map the number onto PasError's `ErrorCode`, and refusing to is the
  same policy PasFS set over `access`: ENOENT is 2 and EACCES is 13 in a
  header this compiler cannot read, and a number the module cannot check does
  not go in. So a caller branches on the code its binding module gave it and
  *reports* what this one says.

  **The value is only meaningful immediately after a failure.** Nothing clears
  it on success and any intervening call may set it -- C's contract, which
  this does not improve on. Read it in the statement after the one that
  failed. }

module PasOS;

export PasOS = (SysText, LastErrorNumber, ErrorNumberText, LastErrorText);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

const
  { Longer than libc's longest message by enough that a new one cannot reach
    it. It has to be: ADR-0123 makes a value that does not fit the capacity an
    error in 6.4.6's words, so a short capacity would turn a diagnostic
    message into a trap. }
  SysMax = 128;

type
  SysText = string(SysMax);

  { The result of `strerror`, which is a `char *` and may in principle be
    null. ADR-0123 is what lets it come back at all, and the copy is made at
    the call site so no C pointer becomes a value this module holds. }
  OptSysText = ?SysText;

{ The operating system's error number for the last call that failed -- C's
  `errno`, read through the runtime because a macro has no symbol to bind.
  Zero means nothing has set it, which is not the same as "the last call
  succeeded". }
function LastErrorNumber: integer;

{ libc's sentence for a number, in whatever locale libc is in -- which is the
  C locale here, nothing in this language calling `setlocale`. An unrecognised
  number still answers a sentence rather than nothing, `strerror` being
  specified to. }
function ErrorNumberText(n: integer): SysText;

{ The two together: the sentence for the last failure. }
function LastErrorText: SysText;

end;

{ The runtime's program-facing surface. `pasx_` rather than `pas_` because
  ReservedForeignName refuses the whole `pas_` prefix -- those are names the
  emitted module already declares, and LLVM will not take a second one. }
function ExtErrno: integer; external 'pasx_errno';

{ libc, directly. `strerror` is not thread-safe and `strerror_r` has two
  incompatible signatures behind a feature-test macro, which is precisely the
  kind of thing an interface without a header parser must not guess at. }
function ExtStrerror(n: integer): OptSysText; external 'strerror';

function LastErrorNumber;
begin
  LastErrorNumber := ExtErrno
end;

function ErrorNumberText;
var m: OptSysText;
begin
  m := ExtStrerror(n);
  { Null is not an answer `strerror` is specified to give, so this arm is a
    guard rather than a case -- and it says so, instead of answering an empty
    string a caller would print as nothing. }
  if m = nil then ErrorNumberText := 'no message for that error number'
  else ErrorNumberText := m^
end;

function LastErrorText;
begin
  LastErrorText := ErrorNumberText(ExtErrno)
end;

end.
