{ AP 6.7.8 (ADR-0365): a module-heading holds routine headings and a task has
  a body, so a task is declared in the module-block and never exported. }
module m interface;
export m = (Go);
task Go(n: integer);
end.
