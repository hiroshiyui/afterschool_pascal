{ What ISO 7185 §6.6.5.4 and §6.9.5 refuse.

  §6.6.5.4's requirements are four: a is an array-type *not* designated packed,
  z is an array-type designated packed, their component-types are the same, and
  the index is assignment-compatible with a's index-type. Each has a case here,
  and so does the argument order — which differs between the two procedures and
  is the thing most likely to be written the other way round.

  Sema accumulates rather than bailing, so every message below comes from one
  run. }
program transfer_errors(output);
type
  unpacked = array [1..10] of char;
  small    = packed array [1..5] of char;
  ints     = packed array [1..3] of integer;
  { Two separately written component types are different types (§6.4.5), which
    is what "the component-types ... shall be the same" turns on. }
  other    = array [1..10] of record x: integer end;
  alike    = packed array [1..5] of record x: integer end;
var
  a: unpacked;
  z: small;
  n: ints;
  o: other;
  k: alike;
  i: integer;
  f: file of integer;
begin
  { The arrays the wrong way round: pack takes the unpacked one first. }
  pack(z, 1, a);
  { A packed array where an unpacked one belongs, and the reverse. }
  pack(a, 1, a);
  unpack(z, z, 1);
  { Component types that are not the same type, however alike they look. }
  pack(o, 1, k);
  { An index that is not assignment-compatible with a's index-type. }
  pack(a, 'c', z);
  { Values rather than variables: §6.6.5.4 asks for a variable-access of each. }
  pack(a, 1, 'abcde');
  { The wrong number of arguments. }
  pack(a, 1);
  unpack(z, a, 1, 2);
  { §6.9.5: page takes a text file, and a `file of` is not one. }
  page(f);
  page(i);
  page(output, output);
  writeln(z, n[1]:1, i:1)
end.
