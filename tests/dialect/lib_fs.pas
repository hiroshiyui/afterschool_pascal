{ ADR-0122 end to end: a library module binds C by name, a path travels as a
  `const char` pointer, and the program never sees one.

  The scratch path comes from a program-parameter's binding (6.5.1 and
  6.7.6.8 NOTE 2), because the harness passes two paths in a temporary
  directory that differs every run -- so the *names* cannot be asserted and
  the effects can. }
program lib_fs(output, scratch, other);

import PasError;
       PasFS;

var scratch, other: text;
    a, b, d: PathName;
    e: ErrorCode;

procedure say(what: string(16); ok: boolean);
begin
  write(what);
  if ok then writeln('yes') else writeln('no')
end;

procedure said(what: string(16); e: ErrorCode);
begin
  write(what);
  if Failed(e) then writeln(ErrorText(e)) else writeln('done')
end;

begin
  a := binding(scratch).name;
  b := binding(other).name;
  d := b + '.dir';

  { Every program in a harness run is handed the *same* two scratch paths, and
    an earlier one may have left a file at either. So the fixture starts by
    clearing them, which is a use of Remove before it is demonstrated and is
    the honest way round: an assertion that depends on what ran first is not
    an assertion. }
  e := Remove(a);
  e := Remove(b);
  say('exists before = ', Exists(a));

  { Made by Pascal, so what the foreign side is asked about is a real file. }
  rewrite(scratch);
  writeln(scratch, 'contents');
  say('exists after  = ', Exists(a));

  said('rename        = ', Rename(a, b));
  say('old gone      = ', Exists(a));
  say('new there     = ', Exists(b));

  said('remove        = ', Remove(b));
  say('removed       = ', Exists(b));

  { The failing direction, and the one place this module's narrowness shows:
    the reason is errIO and cannot be finer, errno being behind a pointer
    result that ADR-0122 does not admit. }
  said('remove again  = ', Remove(b));

  said('mkdir         = ', MakeDirectory(d));
  say('dir there     = ', Exists(d));
  said('mkdir again   = ', MakeDirectory(d));
  said('rmdir         = ', RemoveDirectory(d));
  say('dir gone      = ', Exists(d));

  { A code is a value like any other, so a caller may branch on it. }
  e := Remove(d);
  if e = errIO then writeln('branched      = errIO')
end.
