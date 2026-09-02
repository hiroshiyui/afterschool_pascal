{ The schema a library's result types would be productions of, and the one
  generic over them -- the shape `lib/dialect/paserror.pas` takes (ADR-0297).
  It exists to be imported, so that tests/dialect/generic_fallible_import.pas
  can ask whether inference reaches a production made in a *second* module
  by a program that never sees this one's schema name. }
module FallMod;

export FallMod = (Code, failed, refused, Fallible, ValueOr);

type
  Code = (failed, refused);
  { 6.4.7 interns a production per tuple, so `Fallible(integer)` written in
    any component is one type (ADR-0039). }
  Fallible(T: type) = T ! Code;

{ The value of a successful result, or `whenBad` for a failed one. }
function ValueOr(T: type; res: Fallible(T); whenBad: T): T;

end;

function ValueOr;
begin
  if res.ok then ValueOr := res.val else ValueOr := whenBad
end;

end.
