{ AP 6.4.14.6 through a generic container: `VecFree` does not instantiate at an
  owned type argument, and this is the case that says so (ADR-0337).

  PasContainer is written once for both kinds of pointer -- the client says
  `^Vec(T)` or `owned ^Vec(T)` at its own type line and the module does not
  know which (ADR-0323). Two of its routines are the exception, and are refused
  rather than adapted: `VecFree` and `MapFree` end by assigning nil, which
  6.4.14.6 refuses for an owned pointer because `dispose` is that spelling.

  Nothing is lost by the refusal, which is why it is documented instead of
  fixed: an owned vector is released when its block ends, so a client that
  writes the word calls nothing here. What must not happen is the refusal
  arriving with no explanation of whose call it was, and the second line is
  that -- the activation is in this program and the assignment is in a
  component the program never opened. }
program owned_container_free(output);
import PasContainer;
type OVec = owned ^Vec(integer);
var v: OVec;
begin
  VecInit(v, 4);
  VecPush(v, 1);
  writeln(VecLen(v));
  VecFree(v)
end.
