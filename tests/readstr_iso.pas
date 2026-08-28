{ ISO/IEC 10206:1991 §6.7.5.5 makes `readstr` and `writestr` required
  *identifiers*, not word-symbols -- so the feature reserves nothing, and a
  program may use both names for whatever it likes. This is that program.

  The `_iso` in the name is what it was: one of a pair, compiled under
  `--std=iso7185` against a companion under `--std=extended`, from when this
  compiler had modes. ADR-0232 removed them and the companion; the name is
  kept because moving a case renames it, and what the case asks is unchanged
  and is now asked of the one language. }
program ReadStrIso(output);
var writestr: integer;

procedure readstr(n: integer);
begin
  writeln('readstr ', n:1)
end;

begin
  writestr := 5;
  readstr(writestr);
  writeln('writestr ', writestr:1)
end.
