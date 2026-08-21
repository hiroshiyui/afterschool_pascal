{ Annex B: `array of T` as a formal parameter's type is ADR-0125's slice, and a
  conformance mode gives the answer it gave before the dialect existed --
  §6.6.3.1 makes a formal parameter's type a type *identifier*, and a denoter
  written out in full is not one. Refused by the grammar rather than by a rule
  about the dialect, which is what "spelled in a position a conforming program
  could not have written it" buys. }
program slice_refused_iso(output);
procedure sum(var a: array of integer);
begin
end;
begin
end.
