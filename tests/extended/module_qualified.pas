{ ISO/IEC 10206:1991 §6.11.3's qualified name, in every position one can be
  written, and §6.11.4.2's two required interfaces.

  `i.x` and `r.f` are one production, and only the *symbol* the base resolves
  to parts them — so each of these positions is its own path through Sema. The
  one place the parser can decide alone is a call: `a.b(` has exactly one
  reading, because there is no procedure type in the type part and so a record
  field is never followed by `(`.

  §6.11.2's export-clause may itself hold a qualified name, which is how a
  module re-exports what it imported `qualified` — the standard's own example 3
  does it, and `first..last` below is the range form of the same thing. }
module base interface;
  export
    b = (rank, low, mid, high, weigh, tally, seen, note, run);
  type rank = (low, mid, high);
  const run = 4;
  var seen: integer;
  function weigh(r: rank): integer;
  function tally: integer;
  procedure note(n: integer);
end.

module base implementation;
  function weigh;
  begin weigh := ord(r) * 10 end;

  function tally;
  begin tally := seen end;

  procedure note;
  begin seen := seen + n end;

  to begin do seen := 0;
end.

{ A module that re-exports two of `base`'s constituents by the two qualified
  forms an export-list allows: a name, and a range between two of them.

  The import here is deliberately *not* `qualified`. §6.11.2 a) requires an
  export-range to be within the scope of a defining-point of each value's
  principal identifier, and §6.11.3's last paragraph gives a qualified import's
  names a defining-point for the import-specification alone — so under
  `qualified` the principal identifiers are not in scope and the range is
  refused. The interface-identifier `b` is introduced either way, which is what
  lets the clause still be written the long way. }
module relay interface;
  export
    r = (b.weigh => scale, b.low .. b.high);
  import b;
end.

module relay implementation;
end.

{ §6.11.4.2: `input` and `output` are the constituents of the two required
  interfaces, and importing one is what makes the file accessible in *this*
  block. This module lists neither as a module-parameter and reaches both
  entirely through the import. }
module echo interface;
  export e = (copy_line);
  import StandardInput; StandardOutput;
  procedure copy_line;
end.

module echo implementation;
  procedure copy_line;
  var c: char;
  begin
    while not eoln do begin
      read(c);
      write(c)
    end;
    readln;
    writeln(' <- echoed')
  end;
end.

program ModuleQualified(input, output);
import
  b qualified;
  r;
  e;

{ A qualified *constant* in a constant context: the bound is folded, which is a
  different path from reading one in an expression. And a qualified *type*
  name, which the parser decides on its own because a type-denoter has no
  record to select a field of. }
var a: array [1 .. b.run] of integer;
    k: b.rank;
    i: integer;

begin
  { a qualified function call *with arguments* — the form with its own
    lookahead in the parser }
  writeln('call   ', b.weigh(b.high):1, ' ', scale(mid):1);

  { a qualified parameterless function, written with no argument list at all:
    the selection itself is the call }
  b.note(7);
  writeln('paramless ', b.tally:1);

  { a qualified variable, read and then *written* — an assignment target is a
    designator, which is a different question from being a value }
  writeln('read   ', b.seen:1);
  b.seen := 100;
  b.note(1);
  writeln('write  ', b.seen:1);

  { the export-range's constituents arrived under their own names }
  for k := low to high do
    write(ord(k):1, ' ');
  writeln;

  { the folded constant really is the bound }
  for i := 1 to b.run do
    a[i] := i * i;
  writeln('bound  ', b.run:1, ' ', a[b.run]:1);

  { and the module that reached input and output only by importing the
    required interfaces }
  copy_line
end.
