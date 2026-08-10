{ ISO 7185 6.1.6: a label is at most four digits. This one is accepted as a
  number by the lexer and rejected as a label here. }
program p;
label 10000;
begin
10000:
end.
