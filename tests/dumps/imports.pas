{ **--dump-imports**: the program-components this source needs, in the order
  their activations must commence, one to a line (ADR-0244).

  It is the half of resolution a compiler cannot do. `pascalc` finds the file
  that supplies an `import` name and reads its heading; something still has to
  translate that file and link the result, and the something is
  `tools/pascalcc`. Writing the answer down in the compiler's own words is
  what keeps a build tool from reading Pascal to work it out -- the mistake
  ADR-0229, ADR-0230 and ADR-0239 each moved something off.

  Nothing here names a file or a directory. `dumpimports.pas` sits beside this
  source and the source's own directory is the first thing searched, so the
  whole of the configuration is the spelling of the name. }
program imports(output);

import dumpimports;

begin
  writeln(Doubled(21):1)
end.
