{ The tagged variant record, in a module of its own so that the module under
  test can reach it WITHOUT exporting it (ADR-0142).

  That separation is the whole point of this corpus. A module that exports the
  record type is locked by the type constituent alone, whichever way the
  parameter walk goes -- which is what a first attempt at this test did, and
  the mutation caught it passing without the fix. }
module TagBase;

export TagBase = (Sel, isI, isR, Tagged);

type
  Sel = (isI, isR);
  Tagged = record
    case k: Sel of
      isI: (i: integer);
      isR: (r: real)
    end;

end;
end.
