{ §6.7.5.8's and §6.7.6.9's names are required *identifiers*, not word-symbols,
  so a program may declare its own and win — the rule ADR-0049 met first with
  `complex` and `re`. These four are the ones most likely to collide: `date`
  and `time` are ordinary English, and a program that had them under ISO 7185
  must still compile under this standard.

  Declaring one hides the required meaning entirely, which is why nothing here
  can call the built-in versions. That is §6.1.3's rule, not a limitation. }
program timestamp_redeclared(output);
type TimeStamp = (early, late);
var date: integer; GetTimeStamp: char;

function time(x: integer): integer;
begin
  time := x * 2
end;

var when: TimeStamp;
begin
  date := 7;
  GetTimeStamp := 'z';
  when := late;
  writeln(date, ' ', GetTimeStamp, ' ', time(21), ' ', ord(when))
end.
