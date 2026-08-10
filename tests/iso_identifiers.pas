{ The compatibility promise of --std=iso7185 (ADR-0033).

  ISO/IEC 10206:1991 reserves word-symbols that ISO 7185 does not, and a valid
  ISO 7185 program may use any of them as an ordinary identifier. This one
  does, and so does selfhost/compiler.pas -- which has a record field named
  `value`. Under the default standard they must all still be names.

  The two `otherwise`s below are the sharp ones: both are the *constant*, and
  telling each from the Extended Pascal construct is one token of lookahead —
  a case label is followed by ':' or ',' or '..', a variant's label by ':' or
  ',', and neither Extended Pascal form is followed by any of those. }
program IsoIdentifiers(output);
const
  otherwise = 3;
  only = 4;
type
  { a variant labelled with the constant, which the variant-part-completer of
    ISO/IEC 10206:1991 would otherwise be mistaken for }
  tagged = record
    case which: integer of
      otherwise: (n: integer);
      only: (c: char)
  end;
var
  value, module, export: integer;
  r: tagged;
begin
  value := 1;
  module := 2;
  export := value + module;
  case export of
    otherwise: writeln('label named otherwise: ', otherwise:1);
    only, 9: writeln('no');
    1, 2: writeln('no')
  end;
  r.which := otherwise;
  r.n := 30;
  writeln('variant labelled otherwise: ', r.n:1);
  writeln('value=', value:1, ' module=', module:1, ' export=', export:1)
end.
