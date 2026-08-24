{ AP 6.4.12.2 admits exactly one form of assignment to a handle variable: an
  assignment-statement whose expression is a function-designator of an
  external-declaration answering that type. §6.8.5 makes a function-designator's
  actual-parameter-list optional, so a *parameterless* external is that
  designator written as a bare name -- and it was refused, while the same
  clause's other sentence, that such a designator may stand nowhere else, did
  not reach the bare spelling at all (ADR-0180).

  `tmpfile` is the parameterless one libc has: it answers a `FILE *` that
  `fclose` releases, which is exactly what a handle-type is for.

  What is observed here is that the bare spelling is a live handle -- written
  to, and its position read back -- and that the second assignment released
  the first rather than leaking or freeing twice. The release machinery is
  untouched by this change and is observed by tests/dialect/handle.pas; the
  refusals in the other positions are tests/dialect/handle_errors.pas. }
program handle_bare_call(output);

type
  Stream = handle external 'fclose';

function ExtTmpfile: Stream; external 'tmpfile';
function ExtFputs(s: string; f: Stream): integer; external 'fputs';
function ExtFtell(f: Stream): int64; external 'ftell';
function ExtFflush(f: Stream): integer; external 'fflush';

var k: integer;

{ one block, two handles: the second assignment releases the first
  (6.4.12.3's third case), and the block's end releases the second }
procedure writes;
var f: Stream;
    n: int64;
begin
  f := ExtTmpfile;
  writeln('opened: ', f <> nil);
  k := ExtFputs('twelve chars', f);
  k := ExtFflush(f);
  n := ExtFtell(f);
  writeln('after writing: ', n:1);

  f := ExtTmpfile;
  writeln('reopened: ', f <> nil);
  n := ExtFtell(f);
  writeln('fresh stream at: ', n:1)
end;

{ a handle that is never assigned is empty, and the bare call is what fills
  it -- so this says the assignment happened rather than that nil was kept }
procedure empties;
var f: Stream;
begin
  writeln('before: ', f = nil);
  f := ExtTmpfile;
  writeln('after: ', f = nil)
end;

begin
  writes;
  empties;
  writeln('returned')
end.
