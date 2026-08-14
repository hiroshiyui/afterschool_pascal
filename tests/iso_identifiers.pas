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
  { §6.4.3.3 requires the case-constants to be exactly the tag-type's values,
    and a tag-type is a type-*identifier*, so the pair needs a name. }
  pair = otherwise..only;
  { a variant labelled with the constant, which the variant-part-completer of
    ISO/IEC 10206:1991 would otherwise be mistaken for }
  tagged = record
    case which: pair of
      otherwise: (n: integer);
      only: (c: char)
  end;
var
  value, module, export, bindable: integer;
  r: tagged;

{ `protected` is the sharpest of the thirteen to place, because Extended
  Pascal's use of it is exactly here: §6.7.3.1 writes a formal parameter as
  `[ protected ] identifier-list ':' type`, so under that standard this
  heading is the word-symbol followed by a missing parameter name. Under
  ISO 7185 it is the name. `bindable` above is the other one no program in
  this corpus had ever written as an identifier. }
function twice(protected: integer): integer;
begin
  twice := protected * 2
end;

{ `pow` is a word-symbol of the other standard too, and nothing distinguishes
  this function from any other -- which is the point: reserving a spelling
  before the feature needing it lands would break programs like this one. }
function pow(b, e: integer): integer;
var i, acc: integer;
begin
  acc := 1;
  for i := 1 to e do
    acc := acc * b;
  pow := acc
end;
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
  writeln('a function named pow: ', pow(2, 8):1);
  bindable := 21;
  writeln('a parameter named protected: ', twice(bindable):1);
  writeln('value=', value:1, ' module=', module:1, ' export=', export:1)
end.
