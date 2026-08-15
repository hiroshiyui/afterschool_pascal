{ A perfectly good program, and that is the point: it is valid on its own and
  is therefore something a reader might plausibly hand to --import. §6.13's
  program-components are modules; a program-block is what a component may not
  contain. }
program DeclaresAProgram(output);
begin
  writeln('this component is a program')
end.
