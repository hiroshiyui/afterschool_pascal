{ §6.10 binds `input` to the standard input, and §6.6.5.2's `rewrite(f)` puts
  a file into the generating mode with f.L empty — it discards the file. The
  standard input is not a file this program may discard, and it cannot be
  repositioned either, so there is no honest effect to give this statement.

  §6.11.4.2's counterpart in ISO/IEC 10206:1991 makes the effect on the
  standard files implementation-defined; ISO 7185 leaves it to §6.10's
  implementation-defined binding. Either way the answer has to be written
  down, and `doc/implementation-defined.md` entry E.32 is where — this
  program is what makes the entry checkable rather than asserted.

  The companion `reset(input)` is *not* an error: it is the one operation of
  the three that has a defensible meaning, and `tests/resetinput.pas` pins it
  leaving the file exactly as it is (ADR-0073). }
program TrapRewriteInput(input, output);
begin
  writeln('before');
  rewrite(input);
  writeln('unreachable')
end.
