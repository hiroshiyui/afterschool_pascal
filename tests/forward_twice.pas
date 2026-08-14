{ ISO 7185 §6.6.1 gives three forms: a procedure-heading followed by a
  directive, a procedure-identification followed by a block, and a
  procedure-heading followed by a block. `forward` follows a *heading*; a
  procedure-identification -- the name alone, resuming a forward declaration --
  is followed by the block. The clause says so directly: an identifier declared
  forward "shall have exactly one of its applied occurrences in a
  procedure-identification".

  So a second `forward` leaves two headings and no body. The compiler already
  recognised the resumption exactly -- it is what the "parameters were already
  given" check below is about -- and simply never looked at the directive. }
program ForwardTwice(output);

procedure pp(i : integer); forward;

procedure pp; forward;

procedure pp;
begin
  writeln(i:1)
end;

begin
  pp(1)
end.
