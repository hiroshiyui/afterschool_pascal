{ AP 6.4.14.1: the domain of an owned pointer is a type *identifier*, for
  §6.4.4's own reason -- the name may be one defined later in the same type
  part, which is what lets a type own a variable of its own type.

  Its own file because the parser stops at its first error, and its own
  directory rather than in selfhost/badparse/, whose corpus was ISO 7185, where
  `owned ^` is not a construct at all (ADR-0181). }
program owned_domain(output);
type
  Node = record key: integer end;
var p: owned ^42;
begin
  writeln('unreachable')
end.
