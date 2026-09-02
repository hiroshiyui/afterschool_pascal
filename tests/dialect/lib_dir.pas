{ PasDir end to end (ADR-0188): a directory is a handle the program owns, an
  entry's name comes back as a copy, and nothing here names `struct dirent`.

  The scratch path comes from a program-parameter's binding (6.5.1 and 6.7.6.8
  NOTE 2), because the harness passes paths in a temporary directory that
  differs every run -- so the directory's *name* cannot be asserted and its
  contents can.

  **Every listing below is sorted before it is printed.** The order `readdir`
  gives is the file system's, which is neither sorted nor stable, so a golden
  holding it would be a golden about ext4 rather than about this module. }
program lib_dir(output, scratch, other);

import PasError;
       PasFS;
       PasStrVec;
       PasDir;

var scratch, other: text;
    a, b, d: PathName;
    e: ErrorCode;
    names: StrVecPtr;
    { not `dir`: the module exports a *type* of that spelling, and a variable
      would take it inside every block declaring one -- the same collision
      lib_fs.pas's `fi` avoids against the function `Info`. }
    walk: Dir;
    nm: EntryName;
    { deliberately shorter than any name in this directory but `.` and `..` }
    tiny: string(2);
    k, seen, dots: integer;
    fi: InfoResult;
    f: bindable text; bt: BindingType;

{ A file of one line at `path`, closed before anything asks about it --
  §6.7.5.6's unbind is what closes one. }
procedure make(path: PathName);
begin
  bt := binding(f);
  bt.name := path;
  bind(f, bt);
  rewrite(f);
  writeln(f, 'x');
  unbind(f)
end;

{ Opened, read to its end and closed by leaving this block: `walk` is a local
  handle, so the release is the activation's and nothing here says CloseDir.
  That is the whole reason the directory is a handle-type. }
function CountEntries(path: PathName): integer;
var walk: Dir; nm: EntryName; n: integer; e: ErrorCode;
begin
  n := 0;
  if OpenDir(walk, path) = errNone then begin
    e := NextEntry(walk, nm);
    while e = errNone do begin
      n := n + 1;
      e := NextEntry(walk, nm)
    end
  end;
  CountEntries := n
end;

begin
  a := binding(scratch).name;
  b := binding(other).name;
  d := b + '.dirtest';

  { An earlier program in the same harness run may have left this behind, and
    an assertion that depends on what ran first is not an assertion. }
  e := Remove(d + '/alpha');
  e := Remove(d + '/beta');
  e := Remove(d + '/gamma');
  e := RemoveDirectory(d + '/sub');
  e := RemoveDirectory(d);

  { --- an empty directory --- }
  e := MakeDirectory(d);
  writeln('made          = ', ErrorText(e));
  SVecNew(names, 8);
  writeln('empty list    = ', ErrorText(ListDir(d, names)));
  writeln('empty count   = ', SVecLen(names):1);

  { ...which is not the same as having no entries at all: `.` and `..` are
    there, and `NextEntry` gives them where `ListDir` leaves them out. }
  writeln('with dots     = ', CountEntries(d):1);

  { --- three files and a subdirectory --- }
  make(d + '/alpha');
  make(d + '/gamma');
  make(d + '/beta');
  e := MakeDirectory(d + '/sub');

  SVecClear(names);
  writeln('list          = ', ErrorText(ListDir(d, names)));
  writeln('count         = ', SVecLen(names):1);
  SVecSort(names);
  for k := 1 to SVecLen(names) do
    writeln('  [', k:1, '] ', SVecGet(names, k));

  { What an entry *is* comes from PasFS and not from here: `d_type` is not
    POSIX, so the module answers a name and the caller composes one `stat`. }
  for k := 1 to SVecLen(names) do begin
    fi := Info(d + '/' + SVecGet(names, k));
    write('  kind ', SVecGet(names, k), ' = ');
    if not fi.ok then writeln(ErrorText(fi.cause))
    else if fi.val.kind = fkDirectory then writeln('directory')
    else if fi.val.kind = fkRegular then writeln('regular')
    else writeln('other')
  end;

  { --- the iterator itself, and the two entries ListDir leaves out --- }
  writeln('iterated      = ', CountEntries(d):1);
  seen := 0;
  dots := 0;
  writeln('opened        = ', ErrorText(OpenDir(walk, d)));
  e := NextEntry(walk, nm);
  while e = errNone do begin
    seen := seen + 1;
    if (nm = '.') or (nm = '..') then dots := dots + 1;
    e := NextEntry(walk, nm)
  end;
  { The end of a directory is `errAbsent` -- the ordinary end of a loop, and
    not a failure a caller has to sort out from one. }
  writeln('ended         = ', ErrorText(e));
  writeln('entries       = ', seen:1, ', of which dots = ', dots:1);

  { Released now rather than at the block's end. `walk = nil` is the only
    comparison a handle has, and it is how a caller asks whether it is open. }
  CloseDir(walk);
  writeln('closed        = ', walk = nil);

  { --- a caller's string that is too short --- }
  { `NextEntry` writes into a string of the caller's own capacity, and the length
    is checked by the side that measured it -- so this is a code and not the
    trap an over-long copy would be. The entry is consumed: the four names
    below are what is left of the six. }
  writeln('short open    = ', ErrorText(OpenDir(walk, d)));
  seen := 0;
  e := NextEntry(walk, tiny);
  while (e = errNone) or (e = errFull) do begin
    if e = errFull then seen := seen + 1;
    e := NextEntry(walk, tiny)
  end;
  writeln('too long      = ', seen:1, ' of 6 did not fit ', tiny.capacity:1);
  CloseDir(walk);

  { --- the failing directions --- }
  writeln('no such dir   = ', ErrorText(OpenDir(walk, d + '/not-there')));
  { A file is not a directory, and this module cannot say which refusal it
    was -- PasFS.Info is where a caller asks. }
  writeln('a file        = ', ErrorText(OpenDir(walk, d + '/alpha')));

  { --- cleared away, so a second run of the harness starts as this one did --- }
  e := Remove(d + '/alpha');
  e := Remove(d + '/beta');
  e := Remove(d + '/gamma');
  e := RemoveDirectory(d + '/sub');
  writeln('removed       = ', ErrorText(RemoveDirectory(d)));
  SVecFree(names)
end.
