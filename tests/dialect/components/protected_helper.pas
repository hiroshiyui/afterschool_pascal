{ A separately translated component (6.13) whose interface exports a routine
  with a `var` parameter its body never writes through.

  Two of ADR-0283's guards are here rather than in the importer. 6.11.1 makes
  the export-part the interface, so whether some importer passes `Shown` as a
  procedural actual is a question this component cannot answer -- and 6.6.3.6
  would then compare the formal-parameter-lists with `protected` in them. So
  an exported routine is never advised, however plainly its own body reads.

  `Hidden` is the control: same shape, same unwritten parameter, not exported,
  and it is the one this file is warned about. Without the export guard both
  would be named; without `curFile = mainFile` the *importer* would be told
  about both. }
module protected_helper(output);

export protected_helper = (Shown);

function Shown(var v: integer): integer;

end;

function Shown;
begin
  Shown := v + 1
end;

function Hidden(var v: integer): integer;
begin
  Hidden := v + 2
end;

procedure Unused;
var k: integer;
begin
  k := Hidden(k)
end;

end.
