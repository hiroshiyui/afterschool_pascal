{ ISO/IEC 10206:1991 §6.4.7 puts no restriction on where a discriminant may
  reach inside a schema body; this compiler's descriptor does. A descriptor can
  describe a type whose *size* depends on the discriminants only while every
  offset *inside* it stays a constant — so a record may hold a dynamically
  bounded array as its **last** field, and only as its last (ADR-0045).

  That is the shape the required schema `string` has: a length beside a buffer
  whose capacity is the discriminant. }
program SchemaRecord(output);
type buffer(cap: integer) = record
       len: integer;
       data: packed array [1..cap] of char
     end;
     bp = ^buffer;

     { A record with a dynamic tail may itself be the component of a
       dynamically bounded array, and the tail may be a record with a tail of
       its own: every level is a size, and no level is an offset. }
     table(rows, wide: integer) = array [1..rows] of
       record
         mark: char;
         cell: array [1..wide] of integer
       end;

     { The case that distinguishes a correct stride from a plausible one: the
       component is 4 + cap bytes of content and 4-aligned, so with cap = 5 a
       size of 9 and a stride of 12 are different numbers. `table` above cannot
       tell them apart — its rows are a multiple of 4 however wide they are. }
     list(rows, cap: integer) = array [1..rows] of
       record
         len: integer;
         data: packed array [1..cap] of char
       end;

var s: buffer(8);
    t: buffer(8);
    p: bp;
    g: table(2, 3);
    l: list(3, 5);
    i, j, n: integer;

{ The tail of a `buffer` is a `packed array [1..cap] of char`, which is what
  ISO 7185 §6.4.3.2 makes a string type — so writing it whole and comparing it
  against a literal both read the length out of the tuple, exactly as they do
  for a schema that produces one directly. }
procedure quote(var b: buffer);
begin
  write('"', b.data, '"');
  { §6.7.2.5 compares strings of one length, and the length here is the
    tuple's — so the literal has to be `cap` characters long, and a `buffer` of
    another capacity would stop the program rather than compare short. }
  if b.data = 'abcdefgh' then writeln(' = abcdefgh') else writeln(' <>')
end;

procedure append(var b: buffer; c: char);
begin
  b.len := b.len + 1;
  b.data[b.len] := c
end;

{ One compiled body serves every capacity: `b.cap` reads the tuple the actual
  brought, and `b.data` is at the same constant offset in all of them. }
procedure show(var b: buffer);
var i: integer;
begin
  write(b.cap:1, '/', b.len:1, ' ');
  for i := 1 to b.len do write(b.data[i]);
  writeln
end;

{ The generic form of the same thing: neither bound is known here, so the
  stride between rows is `dynSize` of a record whose own size is dynamic —
  computed, rounded to the component's alignment, and used as the multiplier
  the array code already had. }
procedure grid(var m: table);
var i, j: integer;
begin
  for i := 1 to m.rows do begin
    write('<', m[i].mark);
    for j := 1 to m.wide do write(m[i].cell[j]:4);
    writeln('>')
  end
end;

{ ...and generically, where the stride is `dynSize` rather than LLVM's own
  layout. A `list(3, 5)` written out in full is laid out by the target and
  would stride correctly whatever this compiler believed; only here does the
  rounding have to be right. }
procedure rows(var m: list);
var i, j: integer;
begin
  for i := 1 to m.rows do begin
    write('[', m[i].len:1, ' ');
    for j := 1 to m.cap do write(m[i].data[j]);
    writeln(']')
  end
end;

begin
  s.len := 0;
  append(s, 'h'); append(s, 'i');
  show(s);

  { §6.4.6 a): one schema with one tuple is one type, so this is an ordinary
    whole-variable assignment — of a record whose size the tuple decides. }
  t := s;
  append(t, '!');
  show(t); show(s);

  { §6.4.4's domain may be a bare schema-name, and §6.7.5.3's tuple sizes the
    allocation: the header in front of the variable holds `cap`, and the
    record's size is read from it (ADR-0043). }
  new(p, 20);
  p^.len := 0;
  for i := 1 to 5 do append(p^, chr(ord('a') + i - 1));
  show(p^);
  dispose(p);

  { §6.2.3.2: a discriminant evaluated when the block is entered sizes the
    storage the same way. }
  n := 3;
  new(p, n);
  p^.len := 0;
  append(p^, 'x');
  show(p^);
  dispose(p);

  { An array whose component is a record with a dynamic tail: the stride is the
    component's size rounded up to its alignment, which is what a static array
    of records already does. }
  for i := 1 to 2 do begin
    g[i].mark := chr(ord('A') + i - 1);
    for j := 1 to 3 do g[i].cell[j] := i * 10 + j
  end;
  for i := 1 to 2 do begin
    write(g[i].mark);
    for j := 1 to 3 do write(g[i].cell[j]:4);
    writeln
  end;
  grid(g);

  { Every row is written before any is read, so a stride that is one byte too
    small overwrites the row before it and the reads come back wrong. }
  for i := 1 to 3 do begin
    l[i].len := i;
    for j := 1 to 5 do l[i].data[j] := chr(ord('a') + (i - 1) * 5 + j - 1)
  end;
  for i := 1 to 3 do begin
    write(l[i].len:2, ' ');
    for j := 1 to 5 do write(l[i].data[j]);
    writeln
  end;

  rows(l);

  s.data := 'abcdefgh'; quote(s);
  s.data := 'zzzzzzzz'; quote(s);

  writeln('done ', g.rows:1, g.wide:1, l.rows:1, l.cap:1)
end.
