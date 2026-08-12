{ ISO/IEC 10206:1991 §6.7.5.5 makes `readstr` and `writestr` required
  *identifiers*, not word-symbols -- so the feature reserves nothing, and a
  valid ISO 7185 program may use both names for whatever it likes. This is
  that program, and it is compiled under `--std=iso7185`.

  It is only half a gate, and the half it is not is worth saying. Under
  `--std=extended` these two names *are* claimed: the parser recognises them
  by spelling, exactly as it recognises `read` and `write`, because it has no
  scope to ask whether the program declared its own. ADR-0060 records that as
  a deviation rather than a design. Here the names are ordinary, which is what
  this file pins. }
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
