{ Boundaries that the ordinary corpus never reaches: the full range of char as
  an index type, an *unpacked* array of char (not a string type), and an index
  spanning maxint + 1 -- one too many, maxint itself being legal (ADR-0289). }
program edges(output);
type bychar = array [char] of integer;
     loose = array [1..3] of char;
     tight = packed array [1..3] of char;
     huge = array [-1..maxint] of char;
     { The other half of the same boundary: the elements bound above counts
       *values* and this counts bytes. Two nested maxint arrays of a four-byte
       element want 1.8e19 of them, which is past what a size can hold -- and
       the sum is a second way there, where each field fits and the pair does
       not. Neither program allocates anything: a type-definition is enough. }
     inner = array [1..maxint] of integer;
     outer = array [1..maxint] of inner;
     nearly = array [1..maxint] of array [1..580000000] of integer;
     pair = record x, y: nearly end;
     { And the two propagation paths: a type built *on* one already too large,
       where the size is not recomputed but carried outwards -- once as an
       array's element and once as a record's first field, which is the only
       position that makes a later field round up against it. }
     worse = array [1..2] of outer;
     firstbad = record x: outer; y: integer end;
     { anonymous, so a diagnostic must spell its bounds out rather than print
       a name -- which is the only place char's last value is observable }
var a: bychar; l: loose; t: tight; h: huge; b: boolean;
    anon: array [char] of integer;
begin
  anon := 1;
  t := l;
  b := l = t;
  write(l);
  a['x'] := 1;
  h[0] := 'x';
  write(a['x'], b, t)
end.
