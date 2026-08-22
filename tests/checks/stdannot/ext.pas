(* @std:extended -- the other comment delimiter, and a construct only Extended
   Pascal has. 6.1.8 makes the two forms indistinguishable after the lexer. *)
program ext(output);
var s: string(5);
begin s := 'hi'; writeln(s) end.
