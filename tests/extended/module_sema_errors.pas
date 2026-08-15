{ Three rules about modules that Sema rather than the parser decides, in one
  file because Sema accumulates its errors where the parser stops at the first.

  6.11.2's export-range is written between two *constants* -- an export-list
  may name a range of them, and a name that is not a constant cannot bound one.

  6.11.1's module-parameters are 6.10's program-parameters under another name,
  so each shall be a variable the module declares; `input` and `output` are the
  two the standard supplies and need no declaration.

  A module's activation lasts as long as the program (6.2.3.6), so its
  variables outlive any stack -- which is why a discriminant of one has to be
  constant, where 6.2.3.2 lets an ordinary block compute one on entry
  (ADR-0053). }
module m(nosuch);
export
  mi = (a..b);

type vec(n: integer) = array [1..n] of integer;
var a, b: integer;
    k: integer;
    v: vec(k);
end;
end.
