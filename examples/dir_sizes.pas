{ Walk a directory tree and report every file's size, like du(1).

  PasDir.ListDir answers the names in a directory, PasFS.Info answers what a
  name is and how big -- one `stat`, and the size is an `int64` because a
  file may be bigger than maxint. Both answer an `ErrorCode` or a fallible
  result rather than stopping the program, so a directory that cannot be
  read is one line of output and not the end of the run. The names are
  sorted before printing; the order the file system gives is neither.

  The tree walked is made by the program itself beside its first argument
  and removed afterwards, so the listing is the same on every machine. Run
  it on a real directory by replacing the main block with `Walk(argument(1), 0)`. }
program dir_sizes(output);

import PasError; PasFS; PasDir; PasFile; PasStrVec;

var root: PathName;
    total: int64;

procedure Walk(path: PathName; depth: integer);
var names: StrVecPtr; k: integer; e: ErrorCode;
    child: PathName; fi: InfoResult;
begin
  SVecNew(names, 16);
  e := ListDir(path, names);
  if Failed(e) then
    writeln(' ':depth, '(cannot list: ', ErrorText(e), ')')
  else begin
    SVecSort(names);
    for k := 1 to SVecLen(names) do begin
      child := path + '/' + SVecGet(names, k);
      fi := Info(child);
      if not fi.ok then
        writeln(' ':depth, SVecGet(names, k), ' ?')
      else if fi.val.kind = fkDirectory then begin
        writeln(' ':depth, SVecGet(names, k), '/');
        Walk(child, depth + 2)
      end
      else begin
        writeln(' ':depth, SVecGet(names, k), ' ', fi.val.size:1);
        total := total + fi.val.size
      end
    end
  end;
  SVecFree(names)
end;

{ rm -r, by the same walk. }
procedure Scrub(path: PathName);
var names: StrVecPtr; k: integer; e: ErrorCode; child: PathName;
    fi: InfoResult;
begin
  SVecNew(names, 16);
  e := ListDir(path, names);
  for k := 1 to SVecLen(names) do begin
    child := path + '/' + SVecGet(names, k);
    fi := Info(child);
    if fi.ok and (fi.val.kind = fkDirectory) then Scrub(child)
    else e := Remove(child)
  end;
  e := RemoveDirectory(path);
  SVecFree(names)
end;

procedure Make(dir: PathName);
var e: ErrorCode; ok: boolean;
begin
  e := MakeDirectory(dir);
  e := MakeDirectory(dir + '/src');
  e := MakeDirectory(dir + '/src/deep');
  ok := WriteAllText(dir + '/README', 'read me' + chr(10));
  ok := WriteAllText(dir + '/src/main.pas', 'program p; begin end.' + chr(10));
  ok := WriteAllText(dir + '/src/deep/note', '');
  ok := WriteAllText(dir + '/src/util.pas', 'module u; end.' + chr(10))
end;

begin
  if argcount >= 1 then root := argument(1) + '.tree'
  else root := 'dir_sizes.tree';
  Make(root);
  total := 0;
  Walk(root, 0);
  writeln('total ', total:1, ' bytes');
  Scrub(root);
  writeln('scrubbed: ', not Exists(root))
end.
