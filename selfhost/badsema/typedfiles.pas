{ The diagnostics of a non-text file (ISO 7185 6.4.3.5, 6.6.5.2). A `text` has
  a line structure and an external representation of numbers; a `file of T` has
  neither, so everything that belongs to the first is refused on the second.
  Sema accumulates, so one file carries all of them. }
program typedfiles(output);
type
  point = record x, y: integer end;
  bad = record f: text end;
var
  nums: file of integer;
  pts: file of point;
  { 6.4.3.5: a component may not be, or contain, a file -- at any depth, and
    a variant's field is as much a component as the fixed part's }
  nested: file of text;
  buried: file of array [1..2] of bad;
  n: integer;
  c: char;
  b: boolean;

begin
  rewrite(nums);
  { only a text file has lines to finish }
  writeln(nums);
  writeln(nums, 1);
  { and no component of any file is formatted: write(f, e) is f^ := e; put(f) }
  write(nums, n:4);
  { a component is one value of the file's own type, and nothing else }
  write(nums, 'x');
  write(pts, n);
  reset(nums);
  { the same two rules on the way in }
  readln(nums);
  read(nums, c);
  read(pts, n);
  { eoln asks about a line; eof asks about the file, so only the first is out }
  b := eoln(nums);
  b := eof(nums)
end.
