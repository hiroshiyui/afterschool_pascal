{ A returned pointer that is not a string, and it turned out there was nothing
  to build. `getcwd` answers `char *` and `readlink` answers a count, and both
  write into a buffer the **caller** owns -- so ADR-0129's slice lends the
  storage and ADR-0123's optional copies the characters back at the call site.
  No mechanism was added for either.

  What is asserted here is the round trip rather than any particular path: a
  link is made by binding `symlink` in this program, so the target compared
  against is one this file wrote. }
program lib_path(output, scratch, link);

import PasError;
       PasFS;

{ Bound here rather than in PasFS: `symlink` is a *creating* operation and the
  module's routines that create take a mode this FFI cannot check. It needs
  none, so it could be offered; it is not, because this file is a test and not
  a place to grow an interface. }
function ExtSymlink(target, linkpath: string): integer; external 'symlink';

var scratch, link: text;
    a, b: PathName;
    r: PathResult;
    e: ErrorCode;

procedure yes(what: string(16); ok: boolean);
begin
  write(what);
  if ok then writeln('yes') else writeln('no')
end;

procedure showed(what: string(16); r: PathResult);
begin
  write(what);
  if r.ok then writeln('[', r.val, ']') else writeln(ErrorText(r.cause))
end;

begin
  a := binding(scratch).name;
  b := binding(link).name;

  { An earlier case in the same run may have left either behind. }
  e := Remove(a);
  e := Remove(b);

  { The working directory. Its value is the harness's, so what is asserted is
    that there is one and that it is absolute. }
  r := WorkingDirectory;
  yes('cwd ok        = ', r.ok);
  yes('cwd absolute  = ', r.ok and (length(r.val) > 0) and (r.val[1] = '/'));

  { A link whose target this file chose, so the comparison is exact. The
    target need not exist -- a symbolic link does not check. }
  yes('symlink made  = ', ExtSymlink('/no/such/place', b) = 0);
  showed('link target   = ', LinkTarget(b));

  { A plain file is not a link, and `readlink` says so. }
  rewrite(scratch);
  writeln(scratch, 'ordinary');
  reset(scratch);
  showed('not a link    = ', LinkTarget(a));

  { And the default a caller supplies for the failing case. }
  r := LinkTarget(a);
  writeln('PathOr        = ', PathOr(r, 'nothing there'));

  e := Remove(b);
  yes('link removed  = ', not Exists(b))
end.
