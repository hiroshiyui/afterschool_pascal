{ A direct-access file is ISO/IEC 10206:1991 §6.4.3.6's, and the index-type in
  brackets is the whole of what says so — the parser can therefore recognise
  the construct under either standard and refuse it under the one that has no
  such thing. The five procedures and three functions are required
  *identifiers* rather than word-symbols, so they are refused where the call is
  checked, exactly as the complex functions are. }
program DirectFileIso(output, f);
var f: file [1..10] of integer;
begin
  seekread(f, 1);
  writeln(position(f):1)
end.
