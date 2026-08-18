{ ADR-0117's containment, applied to ADR-0121: `external` is a dialect feature
  and neither conformance mode has it. The word stays an ordinary identifier
  under all three -- 6.1.4 makes a directive an identifier in the one position
  it may occupy -- so nothing about what --std=extended accepts moved except
  this one construct being named and refused. }
program foreign_refused(output);
function cbrt(x: real): real; external 'cbrt';
begin
  writeln(cbrt(27.0):0:1)
end.
