{ Boundaries that the ordinary corpus never reaches: the full range of char as
  an index type, an *unpacked* array of char (which is not a string type), and
  an index spanning exactly maxint -- one value too many. }
program edges(output);
type bychar = array [char] of integer;
     loose = array [1..3] of char;
     tight = packed array [1..3] of char;
     huge = array [0..maxint] of char;
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
