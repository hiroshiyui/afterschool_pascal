{ ADR-0121: `external` says where the body is, and a completion is a
  declaration whose heading was already read -- so a completion cannot be one.
  It could not be made to work either: an exported constituent's linkage name
  is composed from the interface and the constituent spelling (6.13), a
  foreign name is whatever the program wrote, and the importing component
  would look up the one this translation never emitted. Declare it once.

  The two messages after the first are the ordinary complaint about a forward
  declaration with no body: refusing this one leaves it uncompleted, and both
  headings are in the block's procedure part. }
program foreign_completion(output);
procedure sync; forward;
procedure sync; external 'sync';
begin
end.
