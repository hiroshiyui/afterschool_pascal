{ ADR-0121: there is no default foreign name. This lexer case-folds
  identifiers (6.1.2 makes case insignificant) and a linker matches a symbol
  exactly, so deriving one from the other is a lossy mapping to a name that
  has to be right -- and a silently lossy one would report nothing until the
  link. The parser stops here, so this file carries one message. }
program foreign_noname(output);
function getpid: integer; external;
begin
  writeln(getpid:1)
end.
