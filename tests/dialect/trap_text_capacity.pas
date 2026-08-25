{ AP 6.4.15.5: a value that does not fit the capacity is an error, and it is
  a different error from an ill-formed one because a program can act on the
  difference -- one is a fault in the data and the other in the capacity that
  was declared (ADR-0191).

  The capacity is in **bytes** (6.4.15.1), so a text of capacity 8 holds two
  Japanese characters and not eight: the count that fits is a property of the
  value and not of the type, which is the whole reason this error exists. }
program trap_text_capacity(output);

var small: utf8(8); wide: utf8(64);

begin
  wide := '日本語';
  writeln('three characters, ', length(wide):1, ' elements');
  writeln('about to store them into a capacity of ', small.capacity:1,
          ' bytes');
  small := wide;
  writeln('unreachable ', length(small):1)
end.
