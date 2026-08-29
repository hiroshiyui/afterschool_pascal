{ --dump-symbols (ADR-0239): every name a source declares, with its kind, the
  position of the *name* and how deeply it nests -- what a tool asks this
  compiler about a program, where --dump-sema is what a person reads.

  Covered here: the four declaration parts interleaved, so that the written
  order this reports is visibly not the order the parts hold them in
  (ISO/IEC 10206:1991 6.2.1, 6.2.2.9); an enumerated type's constants and a
  record's fields as children of the name they were written under; a variant
  part, whose tag-field and arms are fields of the one record at one depth; a
  schema, which says so ahead of whatever denoter it produces; an inline
  denoter in a variable-declaration, which declares names of its own; a
  forward declaration and the completion that follows it, reported once
  because they are one routine (6.6.1); an external procedure, which has no
  body to nest under it; and a nested function, whose own declarations are its
  children.

  The positions are the point. Each is the identifier's own -- not the
  word-symbol that opened the declaration -- because a caller holding the
  source slices `len` characters there to recover the spelling the programmer
  wrote, the string pool holding only the folded one. }
program symbols(output);

const first = 1;

type
  colour = (red, green, blue);

var early: integer;

const second = 2;

type
  point = record
    x, y: integer
  end;

  { A variant part: the tag-field and every arm's fields are fields of this
    one record, at one depth, because an outline has no name for the nesting
    an arm would add. }
  shape = record
    name: packed array [1..8] of char;
    case tag: colour of
      red: (radius: integer);
      green: (w, h: integer);
      blue: (
        case inner: boolean of
          true: (deep: integer);
          false: ()
      )
  end;

  { A type-denoter with no defining-point in it contributes no children. }
  count = 1..99;
  colours = set of colour;
  link = ^point;
  row = array [1..4] of integer;

  { A schema says so ahead of its denoter: the formal discriminants are the
    distinguishing fact about it. }
  buffer(n: integer) = record
    used: integer;
    data: array [1..n] of char
  end;

var
  origin: point;
  { An inline denoter declares names too, and they are children of the
    variable rather than of a type-definition there is none of. }
  anon: record
    left, right: integer
  end;
  mood: (calm, cross);

procedure later(k: integer); forward;

function twice(k: integer): integer;
var doubled: integer;
  function half(m: integer): integer;
  begin
    half := m div 2
  end;
begin
  doubled := k + k;
  twice := doubled + half(0)
end;

{ The completion, and the only place this name is reported: the forward
  declaration above is the same routine and this is where its body is. }
procedure later;
const inside = 3;
var sum: integer;
begin
  sum := k + inside;
  if sum > 0 then writeln(sum:1)
end;

{ AP 6.7.7: no body, so nothing nests under it. }
procedure trace(n: integer); external 'pas_nothing_at_all';

var last: integer;

begin
  last := first + second;
  writeln(twice(last):1);
  later(0)
end.
