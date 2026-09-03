{ PasJson writes the shortest number that reads back as the same value
  (ADR-0309).

  What this case asserts is the *round trip*, not a spelling: every value below
  is rendered, parsed back out of the rendered document and compared with the
  value that went in. A golden that pinned the digits would pass just as well
  for a writer that lost them, which is what `examples/json_pretty.out` --
  where the number is read by a person -- is for.

  The spelling is printed too, beside `same=TRUE`, because the point of the
  change is that a person can read it: the round trip alone is satisfied by
  `7.500000000000E-01`. }
program lib_json_number(output);

import PasError; PasJson;

var doc: JsonPtr; at: integer; r: JsonResult;

{ Render `x` as the one member of a document and report two answers about the
  text that came out.

  `reads` is the claim ADR-0309 makes: §6.10.4's `readstr` -- the processor's
  own reader, and the one the writer's search consults -- returns the value
  that went in. It is TRUE for every value here, and that is the property.

  `parses` is `JsonParse` reading its own writer's output, and it is FALSE
  wherever the text carries an exponent, because the parser scales by
  multiplying or dividing by ten once per decade and a decade at a time is not
  a correctly rounded conversion. That is a defect in the *reader* which this
  change made visible and does not fix (ADR-0309); the column is here so that
  the day it is fixed, this golden says so. }
procedure Trip(what: string; x: real);
var v, back: JsonPtr; out: JsonChars; text: string(255); q: JsonResult;
    y, z: real; where: integer;
begin
  v := JsonNewObject;
  JsonPut(v, 'n', JsonNewNumber(x));
  JsonCharsNew(out);
  JsonRender(v, out);
  if JsonCharsInto(out, text) <> errNone then text := '';
  JsonCharsFree(out);
  JsonFree(v);
  { The rendered text is the input to both readers: nothing else is compared,
    and neither reader is shown the value it is meant to arrive at. }
  y := x + 1.0;
  readstr(substr(text, 6, length(text) - 6), y);
  z := x + 1.0;
  q := JsonParse(text, where);
  if q.ok then begin
    back := q.val;
    z := JsonNumberOr(JsonMember(back, 'n'), x + 1.0);
    JsonFree(back)
  end;
  writeln(what, ' -> ', text, ' reads=', y = x, ' parses=', z = x)
end;

{ An integer member is not a real and must not become one: JSON has one number
  type, so a `3` that arrived as `3` is a different message from a `3.0`. }
procedure Whole(what: string; n: integer);
var v: JsonPtr; out: JsonChars; text: string(255);
begin
  v := JsonNewObject;
  JsonPut(v, 'n', JsonNewInteger(n));
  JsonCharsNew(out);
  JsonRender(v, out);
  if JsonCharsInto(out, text) <> errNone then text := '';
  JsonCharsFree(out);
  JsonFree(v);
  writeln(what, ' -> ', text)
end;

begin
  Trip('0.75            ', 0.75);
  Trip('0.1             ', 0.1);
  Trip('one third       ', 1.0 / 3.0);
  Trip('0.1 + 0.2       ', 0.1 + 0.2);
  Trip('zero            ', 0.0);
  Trip('negative        ', -2.5);
  Trip('whole as a real ', 3.0);
  Trip('ten             ', 10.0);
  Trip('very large      ', 1.0e300);
  Trip('very small      ', 1.0e-320);
  Trip('largest         ', 1.7976931348623157e308);
  Trip('smallest normal ', 2.2250738585072014e-308);
  Trip('fixed at the end', 1.0e-6);
  Trip('exponent beyond ', 1.0e-7);
  Trip('twenty zeros    ', 1.0e20);
  Trip('twenty-one      ', 1.0e21);

  Whole('integer 3       ', 3);
  Whole('integer 0       ', 0);
  Whole('integer -7      ', -7);

  { A number the *document* wrote without a fraction stays an integer, and one
    it wrote with a fraction or an exponent is a real. }
  r := JsonParse('{"i":3,"f":3.0,"e":3e0,"big":0.75}', at);
  doc := r.val;
  writeln('reparsed i=', JsonIntegerOr(JsonMember(doc, 'i'), -1):1,
          ' f as int=', JsonIntegerOr(JsonMember(doc, 'f'), -1):1);
  JsonFree(doc)
end.
