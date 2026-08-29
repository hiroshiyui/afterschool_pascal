{ **An import that names no file** (ADR-0244).

  Every other component case in this corpus carries a `name.components`
  sidecar listing the files, and the compiler is handed each with `--import`.
  This one carries `import_by_name.importpath` instead, which names a
  *directory* -- so what is asserted is that the compiler found the files
  itself, translated them in the right order, and that `tools/pascalcc`
  learned which they were and linked them.

  Three things are pinned and each fails differently.

  **Transitivity.** The program imports `bynamemid` and never mentions
  `bynamebase`; the middle component imports the base one. A resolver that
  walked only the source's own import-part would leave the middle component
  compiled against nothing and the program would not link.

  **Order.** 6.2.3.6 commences a supplying module before the one that imports
  it, and the first two lines of the golden are written by the two `to begin
  do` parts. A resolution that appended a component *before* what it needs
  would print them the other way round, or activate `bynamemid` while
  `baseTally` was still zero.

  **The other half.** Resolution gives the compiler an interface and not an
  object. `--dump-imports` is how the driver is told what to translate, and
  without it this program compiles and fails to link.

  The interface names are the file names, folded and with `.pas` after them,
  which is the convention the search rests on and is stated as one. }
program import_by_name(output);

import bynamemid;

begin
  { `baseTally` is deliberately not written here. 6.11.3 gives an importer the
    constituents of the interfaces it names and nothing else, so the deeper
    component is reachable only through the middle one -- which is what makes
    the chain a chain rather than two imports written in one place. }
  midBump(4);
  writeln('program: mid tally  = ', midTally:1)
end.
