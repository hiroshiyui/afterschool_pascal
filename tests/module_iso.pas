{ ISO 7185 has no modules, and none of the five words §6.1.2 of ISO/IEC
  10206:1991 adds for them is reserved here — `module`, `export`, `import`,
  `only` and `qualified` are ordinary identifiers, and this program uses all
  five as such. Under `--std=extended` it would not compile at all, which is
  ADR-0033's point: a source is written in one language or the other.

  The refusal of a module itself is not here but in the driver: `module` at the
  start of a program-component is an identifier under ISO 7185, so what the
  parser says is that a program must begin with `program`. }
program ModuleIso(output);
var module, export, import, only, qualified: integer;
begin
  module := 1;
  export := 2;
  import := 3;
  only := 4;
  qualified := 5;
  writeln(module + export + import + only + qualified:1)
end.
