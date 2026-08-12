{ A file need not be an entire variable.

  ISO 7185 §6.5.1's own declaration example is

      pooltape : array [1..4] of FileOfInteger;

  and §6.5.5's own buffer-variable example is `pooltape[2]^`. Both compilers
  accepted that and neither prepared the file: `pas_file_init` was emitted only
  for a frame variable whose *own* type was a file, so a file inside an array
  or a record kept a zeroed `struct pas_file`, and the first `f^` read a null
  buffer pointer. A clean compile and a SIGSEGV, in both standards and at every
  optimisation level.

  Nothing in the corpus had ever declared one. Every file that mentioned an
  array of files was a *negative* test checking that a file's component may not
  contain a file — so every oracle agreed, exactly as it did for the three
  gaps before this one.

  The block prologue now walks each variable's type and prepares every file it
  contains; the epilogue closes them the same way, which is what flushes them. }
program filecomponents(output);

type
  FileOfInteger = file of integer;
  { A record holding a file, and an array of those — so the walk has to
    recurse through both shapes and in both orders. }
  logbook = record
    id: integer;
    entries: FileOfInteger
  end;

var
  pooltape: array [1..4] of FileOfInteger;
  books: array [1..2] of logbook;
  single: logbook;
  grid: array [1..2] of array [1..2] of FileOfInteger;
  lines: array [1..2] of text;
  i, j: integer;

begin
  { §6.5.1's example, written and read back. }
  for i := 1 to 4 do
    begin
      rewrite(pooltape[i]);
      pooltape[i]^ := i * i;
      put(pooltape[i])
    end;
  write('pooltape');
  for i := 1 to 4 do
    begin
      reset(pooltape[i]);
      write(' ', pooltape[i]^:1)
    end;
  writeln;

  { A file inside a record, and inside a record inside an array. }
  single.id := 7;
  rewrite(single.entries);
  single.entries^ := 70;
  put(single.entries);
  reset(single.entries);
  writeln('single   ', single.id:1, ' ', single.entries^:1);

  for i := 1 to 2 do
    begin
      books[i].id := i;
      rewrite(books[i].entries);
      books[i].entries^ := i * 100;
      put(books[i].entries)
    end;
  write('books   ');
  for i := 1 to 2 do
    begin
      reset(books[i].entries);
      write(' ', books[i].id:1, ':', books[i].entries^:1)
    end;
  writeln;

  { Two dimensions, so the walk nests a loop inside a loop. }
  for i := 1 to 2 do
    for j := 1 to 2 do
      begin
        rewrite(grid[i][j]);
        grid[i][j]^ := i * 10 + j;
        put(grid[i][j])
      end;
  write('grid    ');
  for i := 1 to 2 do
    for j := 1 to 2 do
      begin
        reset(grid[i][j]);
        write(' ', grid[i][j]^:1)
      end;
  writeln;

  { A `text` component has a line structure, so it takes the other branch of
    the runtime's one implementation — and its buffer variable is the byte
    inside the file record rather than an allocated one. }
  for i := 1 to 2 do
    begin
      rewrite(lines[i]);
      writeln(lines[i], 'line ', i:1)
    end;
  for i := 1 to 2 do
    begin
      reset(lines[i]);
      write('text     ');
      while not eoln(lines[i]) do
        begin
          write(lines[i]^);
          get(lines[i])
        end;
      writeln
    end
end.
