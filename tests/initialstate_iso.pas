{ An initial-state-specifier is ISO/IEC 10206:1991 §6.6 and nothing in ISO 7185,
  so under the default standard it is refused as itself. `value` is not a
  reserved word there — this compiler's own stage-1 source has a field of that
  name — so it arrives as an identifier and the type-denoter is complete
  without it; what makes the message possible is that no valid ISO 7185
  declaration can have an identifier there. }
program InitialStateIso(output);
var n: integer value 1;
begin
  writeln(n:1)
end.
