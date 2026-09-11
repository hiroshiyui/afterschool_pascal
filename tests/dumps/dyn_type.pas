{ --dump-ast over AP 6.7.11's trait-object-type (ADR-0408). A dump stops after
  the *parse*, which is the whole reason this case can exist at all: the type
  is refused by Sema in every position (6.7.11.3 is marked `[not yet
  implemented]` and `tests/dialect/dyn_positions.pas` holds the refusals), so
  a dump is the only place its shape can be read.

  Both spellings are here. `dyn shape` is the ordinary one; `dyn other.shape`
  is 6.11.3's qualified name, which a trait needs because a trait may be
  imported -- and no dialect case can reach that branch, a qualified name
  being resolved by the pass this dump stops before. }
program dyn_type(output);

type
  D = dyn shape;
  Q = dyn other.shape;

begin
end.
