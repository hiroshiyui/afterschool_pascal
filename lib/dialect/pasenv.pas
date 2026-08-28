{ PasEnv -- the process environment, reached by ADR-0123's optional.

  This module is the first user of a foreign *result*, and it is here to hold
  one claim still: **null is absence, and absence is a value the language can
  hold.** `Lookup` of a name that is not set answers `nil` -- not an error, not
  an empty string, and not a trap -- which is the distinction ADR-0122 could
  not make and the reason ADR-0123 exists.

  It is the third binding module and, like the other two, is **dialect-only**:
  `external` is admitted by this dialect alone (ADR-0117's containment), and
  no standard Pascal would compile the declarations below.

  **`putenv` is deliberately absent.** It keeps the pointer it is handed and
  the environment then refers to it forever -- which is exactly the hazard
  doc/sop.md §7 records against ADR-0122, and this compiler's string arena
  would reclaim that storage at the end of the statement. `setenv` copies, so
  `Define` below is safe in a way `putenv` could not be made safe. It is the
  first place the registered blind spot has decided an interface. }

module PasEnv;

export PasEnv = (MaxValue, EnvText, OptEnvText,
                 Lookup, LookupOr, Defined, Define, Undefine);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

const
  { A capacity the copy needs somewhere of a known size to go into, and one
    the caller can see: a value longer than this is an *error* at the moment
    it is read, in 6.4.6's words, rather than a truncation nothing reports.
    Generous enough for a PATH, which is what usually decides. }
  MaxValue = 4096;

type
  EnvText = string(MaxValue);
  { The answer, and the whole point of the module. `nil` is "not set"; an
    EnvText of length zero is "set to nothing"; they are different states and
    a caller can tell them apart. }
  OptEnvText = ?EnvText;

{ The value of a variable, or nil where there is none. }
function Lookup(name: EnvText): OptEnvText;

{ The value, or the caller's own answer where there is none -- for a caller
  with a sensible default that does not want to branch. The same shape
  PasMathX's RealOr has, and for the same reason. }
function LookupOr(name, whenUnset: EnvText): EnvText;

{ Whether the variable is set at all, including to the empty string. }
function Defined(name: EnvText): boolean;

{ Set a variable, replacing any value it had. `errIO` where the operating
  system refused -- which for setenv means an empty or malformed name, or no
  memory. }
function Define(name, val: EnvText): ErrorCode;

{ Remove a variable. Removing one that was not there is not a failure, which
  is unsetenv's own rule and not this module's invention. }
function Undefine(name: EnvText): ErrorCode;

end;

{ The directives, kept to this module: an exported constituent's linkage name
  is composed from the interface and the constituent spelling (6.13), and a
  foreign name is whatever the program wrote. }
function ExtGetenv(name: string): OptEnvText; external 'getenv';
function ExtSetenv(name, val: string; overwrite: integer): integer;
  external 'setenv';
function ExtUnsetenv(name: string): integer; external 'unsetenv';

function Refused(rc: integer): ErrorCode;
begin
  if rc = 0 then Refused := errNone else Refused := errIO
end;

function Lookup;
begin
  Lookup := ExtGetenv(name)
end;

function LookupOr;
var v: OptEnvText;
begin
  v := ExtGetenv(name);
  if v = nil then LookupOr := whenUnset else LookupOr := v^
end;

function Defined;
var v: OptEnvText;
begin
  v := ExtGetenv(name);
  Defined := v <> nil
end;

function Define;
begin
  Define := Refused(ExtSetenv(name, val, 1))
end;

function Undefine;
begin
  Undefine := Refused(ExtUnsetenv(name))
end;

end.
