{ The other half of ISO/IEC 10206:1991 6.7.3.2's string rule, which is easy to
  read past: the formal possesses "the type produced from the schema string
  with the tuple having **that length** as its component" -- the length of the
  *value*, not the capacity of the variable it came out of.

  So `s` below has capacity 3, because the value it was handed is three
  characters long, even though `v` has room for forty. Storing ten characters
  into it is 6.4.6's refusal and stops the program.

  This compiler gave the formal the actual's capacity, so the assignment
  succeeded and the program printed a ten-character string from a formal the
  standard says has room for three. Nothing else can see that: length() reports
  the value's length under either reading, and the capacity is observable only
  by overflowing it. }
program string_value_capacity(output);

var v: string(40);

procedure show(s: string);
begin
  writeln('length ', length(s):1);
  { Fits the actual's capacity of 40 and not the value's length of 3. }
  s := 'abcdefghij';
  writeln('must not print: ', s)
end;

begin
  v := 'abc';
  show(v)
end.
