{ AP 6.7.7.6.2 in the direction that refuses (ADR-0184). Sema accumulates, so
  one file carries every refusal here.

  The rule is not a list of forbidden types but a list of admitted ones, and
  what admits them is a single property: the field's layout must be one C
  computes the same way. Everything below fails that in one of three ways --
  a representation this compiler invented, a value set the callee could step
  outside of, or a direction where C's ABI would have to be consulted. }
program foreign_record_errors(output);

type
  colour = (red, green);
  sel = 1..2;

  { The fixed part is fine; the variant part is not. What an arm is laid over
    is `[k x iN]`, a shape chosen here (ADR-0028) and not one C's union rule
    produces -- and the tag is a field C has no member for. }
  varying = record
    head: integer;
    case tag: sel of
      1: (a: integer);
      2: (b: real)
  end;

  { A value set with byte patterns that are not values of it. The callee
    writes through the address and nothing runs CheckedForStore over what it
    left, which is ADR-0129's reason and applies here unchanged. }
  withEnum = record c: colour end;
  withBool = record ok: boolean end;
  withSub  = record n: sel end;

  { A representation this compiler chose. A string is a length beside a
    buffer, a set is 256 bits, a pointer is one word but not one C agrees is
    a pointer to anything, and a file is `struct pas_file`. }
  withString = record s: string(8) end;
  withSet    = record s: set of char end;
  withFile   = record f: text end;

  { The rule one level down is the same rule, and the field the diagnostic
    names is the inner one -- that being the field the program has to change. }
  inner  = record ok: integer; flag: boolean end;
  nested = record head: int64; body: inner end;

  { And an array of a component that does not cross, at either depth. }
  withArray = record v: array [1..2] of colour end;

  { Two fields fail, and one diagnostic is written: the message names the
    *first*, which is what a program fixing them one at a time wants. }
  withTwo = record bad1: boolean; bad2: colour end;

  { The one below that is admitted, so the file states the rule from both
    sides: a record of two integers crosses as a `var` parameter. }
  plain = record a, b: integer end;

procedure TakesVariant(var r: varying);   external 'ext_variant';
procedure TakesEnum(var r: withEnum);     external 'ext_enum';
procedure TakesBool(var r: withBool);     external 'ext_bool';
procedure TakesSub(var r: withSub);       external 'ext_sub';
procedure TakesString(var r: withString); external 'ext_string';
procedure TakesSet(var r: withSet);       external 'ext_set';
procedure TakesFile(var r: withFile);     external 'ext_file';
procedure TakesNested(var r: nested);     external 'ext_nested';
procedure TakesArray(var r: withArray);   external 'ext_array';
procedure TakesTwo(var r: withTwo);       external 'ext_two';

{ The direction, not the type: `plain` crosses, and by value it does not.
  How a struct is copied into a call is a fact about C's ABI, and ADR-0030 is
  the standing rule that nothing here may depend on one. }
procedure ByValue(r: plain);              external 'ext_byvalue';

{ Nor back. A struct returned by value is the same ABI question asked in the
  other direction, and it is refused by the rule about results. }
function Returns: plain;                  external 'ext_result';

var v: varying; e: withEnum; b: withBool; s: withSub;
    st: withString; se: withSet; fl: withFile; n: nested;
    ar: withArray; tw: withTwo; pl: plain;

begin
  TakesVariant(v);
  TakesEnum(e);
  TakesBool(b);
  TakesSub(s);
  TakesString(st);
  TakesSet(se);
  TakesFile(fl);
  TakesNested(n);
  TakesArray(ar);
  TakesTwo(tw);
  ByValue(pl);
  pl := Returns
end.
