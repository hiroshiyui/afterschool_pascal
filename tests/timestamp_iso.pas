{ The ISO 7185 gate. §6.7.5.8's `GetTimeStamp`, §6.7.6.9's `date` and `time`
  and §6.4.3.4's `TimeStamp` all belong to ISO/IEC 10206:1991, and all four are
  required *identifiers* — so under ISO 7185 they are simply names nobody
  declared, and the diagnostic has to say the feature is missing rather than
  that the name is (ADR-0049's rule).

  A program declaring its own would compile under both and distinguish
  nothing, which is the fault ADR-0054 and ADR-0056 each met: this one uses
  them undeclared on purpose. }
program timestamp_iso(output);
var t: TimeStamp;
begin
  GetTimeStamp(t);
  writeln(date(t), time(t))
end.
