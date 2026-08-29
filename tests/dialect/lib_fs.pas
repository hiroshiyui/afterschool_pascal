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
    a, b, d, d2: PathName;
    tmp, tmp2: PathResult;
    e: ErrorCode;
    fi: InfoResult;   { not `info`: the module exports a function of that name }
    sized: bindable text; bt: BindingType;

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
  { A directory of its own for the temporary-path probe, so what it leaves in
    the directory is countable and nothing else is in there to be mistaken for
    it. }
  d2 := b + '.tmpdir';

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
  if e = errIO then writeln('branched      = errIO');

  { --- what a path names (ADR-0185) ---------------------------------------

    `Info` is the one routine here whose answer lives in a `struct stat`, and
    the one that deliberately does **not** cross one. AP 6.7.7.6.2 would let
    this module declare the struct; ADR-0185's fifth decision is that a
    library may not, because that declaration is one platform's and `lib/` has
    to work where nobody here can build it. So the runtime is asked, and its C
    is compiled by the C compiler of the machine being built for.

    The size is what this program wrote, so it is a number a golden can hold.
    The times are not, and are not printed. }
  { A length is only a fact once the file is closed, and §6.7.5.6's unbind is
    what closes one -- so this is written through a *bindable* variable of its
    own rather than through `scratch`, which the harness bound and which stays
    open until the block ends. }
  bt := binding(sized);
  bt.name := a + '.sized';
  bind(sized, bt);
  rewrite(sized);
  write(sized, 'twelve chars');
  unbind(sized);
  fi := Info(a + '.sized');
  if fi.ok then begin
    writeln('info size     = ', fi.val.size:1);
    if fi.val.kind = fkRegular then writeln('info kind     = regular')
  end
  else
    writeln('info failed   = ', ErrorText(fi.cause));

  said('mkdir for dir = ', MakeDirectory(d));
  fi := Info(d);
  if fi.ok and (fi.val.kind = fkDirectory) then
    writeln('dir kind      = directory');
  said('rmdir for dir = ', RemoveDirectory(d));

  { Nothing there is errAbsent and not errIO, which is the one distinction
    `pasx_file_info` draws for this module -- it costs a second `access` and
    is what lets a caller tell "no such file" from "you may not look". }
  fi := Info(a + '.nothing-here');
  writeln('absent        = ', ErrorText(fi.cause));

  e := Remove(a + '.sized');

  { **A temporary path**, which is the one routine here whose *answer* cannot
    be written in a golden -- the name has eight hexadecimal digits chosen
    from a clock (ADR-0243). So what is asserted is every property of it that
    is not the spelling: that it came back at all, that the directory asked
    for is the directory it is in, that the prefix is at the front, that the
    file **exists** -- which is the whole difference between this and
    composing a name, since a name whose file exists stays taken after this
    process has gone -- that a second call answers a different name, and that
    `Remove` takes it away again.

    A directory nothing may write in is `errIO`, and the message is the
    module's usual one: this cannot see an errno. }
  e := RemoveDirectory(d2);
  said('mkdir for temp= ', MakeDirectory(d2));
  tmp := TemporaryPath(d2, 'probe-');
  tmp2 := TemporaryPath(d2, 'probe-');
  if tmp.ok and tmp2.ok then begin
    writeln('temp in dir   = ',
            substr(tmp.val, 1, length(d2)) = d2);
    writeln('temp prefix   = ',
            substr(tmp.val, length(d2) + 2, 6) = 'probe-');
    writeln('temp length   = ', length(tmp.val) - length(d2) - 1:1);
    writeln('temp exists   = ', Exists(tmp.val));
    writeln('temp differs  = ', tmp.val <> tmp2.val);
    said('temp removed  = ', Remove(tmp.val));
    writeln('temp gone     = ', Exists(tmp.val));
    e := Remove(tmp2.val)
  end
  else begin
    { Each asked separately, because `.cause` may only be read on the arm the
      tag selects and either of the two may be the one that failed. Making the
      counter stand still is what puts the *second* here: every one of the
      4 096 tries then finds the name the first call created, which is the
      demonstration that C11's exclusive mode is exclusive. }
    if not tmp.ok then writeln('temp failed   = ', ErrorText(tmp.cause));
    if not tmp2.ok then writeln('temp2 failed  = ', ErrorText(tmp2.cause))
  end;
  said('rmdir for temp= ', RemoveDirectory(d2));
  writeln('temp nowhere  = ',
          ErrorText(TemporaryPath(d2, 'probe-').cause))
end.
