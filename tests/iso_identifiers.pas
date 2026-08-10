{ The compatibility promise of --std=iso7185 (ADR-0033).

  ISO/IEC 10206:1991 reserves word-symbols that ISO 7185 does not, and a valid
  ISO 7185 program may use any of them as an ordinary identifier. This one
  does, and so does selfhost/compiler.pas -- which has a record field named
  `value`. Under the default standard they must all still be names.

  The case label below is the sharp one: `otherwise` there is a *constant*, and
  telling that from the Extended Pascal construct is one token of lookahead —
  a case label is followed by ':' or ',' or '..', and an otherwise-part is not. }
program IsoIdentifiers(output);
const
  otherwise = 3;
  only = 4;
var
  value, module, export: integer;
begin
  value := 1;
  module := 2;
  export := value + module;
  case export of
    otherwise: writeln('label named otherwise: ', otherwise:1);
    only, 9: writeln('no');
    1, 2: writeln('no')
  end;
  writeln('value=', value:1, ' module=', module:1, ' export=', export:1)
end.
