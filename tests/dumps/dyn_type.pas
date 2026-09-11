{ --dump-ast over AP 6.7.11's trait-object-type (ADR-0408, ADR-0409). A dump
  stops after the *parse*, and that is what this case is for: what the parser
  builds is the same node wherever the denoter stands, and Sema then accepts
  it in the two positions 6.7.11.1 permits and refuses it in the rest
  (`tests/dialect/dyn_positions.pas` holds those). So the shape below is the
  whole of what the syntax decides, with none of what the position decides
  mixed into it.

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
