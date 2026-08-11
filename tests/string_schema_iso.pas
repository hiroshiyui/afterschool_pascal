{ ...and `string(5)` under ISO 7185, which the parser stops at: a
  discriminated-schema is Extended Pascal syntax, so the refusal comes before
  any question about what `string` denotes. This lives in its own file because
  the parser reports one error and stops. }
program StringSchemaIso(output);
var s: string(5);
begin
  writeln(1)
end.
