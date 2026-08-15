{ ISO/IEC 10206:1991 §6.13: an already-translated program-component supplies
  interfaces through its module-headings, so what --import reads is a sequence
  of module-declarations. A program-block is not one of them -- there is
  exactly one main-program-block in a program, and it is this file's.

  The component named here translates cleanly on its own, which is what makes
  the mistake worth a message: nothing about the file is wrong except where it
  was used. }
program ImportProgram(output);
begin
  writeln('unreached')
end.
