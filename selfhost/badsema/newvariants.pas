{ The diagnostics of `new(p, c1, ..., cn)` and `dispose(p, c1, ..., cn)`
  (ISO 7185 6.6.5.3). Sema accumulates, so one file carries all of them --
  but each `new` stops at its first bad tag value, so each gets its own call. }
program newvariants(output);
type
  e = (a, b, c);
  f = (x, y);
  { one nested level, so "no more nested variant parts" is reachable }
  rec = record
    case t: e of
      a: (i: integer;
          case u: f of
            x: (p: char);
            y: (q: real));
      b: (r: real)
  end;
  { a record with no variant part at all, which is a different mistake from
    one tag value too many }
  flat = record only: integer end;
  link = ^rec;
  plain = ^integer;
  simple = ^flat;
var
  n: link;
  m: plain;
  s: simple;
  v: integer;
begin
  { not a constant }
  v := 1;
  new(n, v);
  { the wrong type for the tag }
  new(n, 3);
  { a value of the right type that selects no variant of this record }
  new(n, c);
  { one level too many: the `b` arm has no variant part of its own }
  new(n, b, x);
  { two levels too many, through the arm that does have one }
  new(n, a, x, y);
  { a pointer whose domain is not a record at all }
  new(m, a);
  { a record, but one with no variant part }
  new(s, a);
  { and the same list is checked for dispose }
  dispose(n, v);
  dispose(m, a);
  { the plain forms still work, so the file is about the tag values only }
  new(n);
  new(n, a, y);
  dispose(n, a, y)
end.
