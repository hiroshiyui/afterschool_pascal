{ A module whose *path* passes 255 characters, which is a different bound from
  the one the directory next door tests.

  `--dump-uses` writes a file table at its head, one row per file, and the row
  naming this one holds an absolute path. The server read that dump with
  `PasProcess.CaptureLines`, whose contract is to cut every line at `ItemMax`
  -- 255, and right for the 40 000 short rows that follow. So the path came
  back cut, `PathToUri` escaped what was left, and go-to-definition answered a
  location in a file nobody named, with nothing on either stream to say so
  (ADR-0292).

  Reaching it needs a real file at such a path, which the compiler could not
  even open until ADR-0291. This module only has to declare something worth
  going to. }
module Far;

export Far = (FarAnswer);

function FarAnswer: integer;

end;

function FarAnswer;
begin
  FarAnswer := 11
end;

end.
