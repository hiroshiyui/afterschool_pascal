{ What a direct-access file may not do, and what a sequential one may not. }
program DirectFileErrors(output, t, s, f);
var t: text;
    s: file of integer;
    f: file [1..10] of integer;
    i: integer;
    b: boolean;
begin
  { §6.4.3.6 gives only a file-type with an index-type a position at all, so
    the three seeks, `update`, `position`, `LastPosition` and `empty` all
    refuse a sequential file — and `text` most of all, which §6.4.3.6 excludes
    by name. }
  seekread(s, 1);
  seekwrite(t, 1);
  seekupdate(s, 1);
  update(s);
  i := position(s);
  i := lastposition(t);
  b := empty(s);
  { §6.7.5.2: the position shall be assignment-compatible with the index type,
    which is what makes it a *value of that type* rather than a count. }
  seekread(f, 'x');
  { ...and the arity is fixed: a seek takes a file and a position, update and
    extend take a file alone. }
  seekread(f);
  update(f, 1);
  { §6.4.3.6's index-type is an ordinal type, because §6.7.6.6 returns a value
    of it and §6.7.5.2 takes one. }
  writeln(i:1, b)
end.
