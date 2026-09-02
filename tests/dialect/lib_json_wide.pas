{ PasJson's one-piece string parameters, handed strings wider than the
  module's own `JsonLine`.

  `LineMax` is 255 and was the capacity of every formal a caller handed a
  whole string to, so a caller holding a wider string met a *trap* -- not a
  truncation and not a diagnostic: `a string of length 300 does not fit a
  capacity of 255`, and the program stopped. The formals are schematic since
  ADR-0291, so the capacity is the caller's.

  The narrow half at the end is the claim in the other direction: a formal
  that stopped taking a literal or a `JsonLine` would be a worse bound than
  the one it replaced. }
program lib_json_wide(output);

import PasError; PasJson;

const
  N = 300;

type
  Wide = string(1024);

var v, doc: JsonPtr;
    b, out: JsonChars;
    w, back: Wide;
    line: JsonLine;
    r: JsonResult;
    at, i: integer;
    e: ErrorCode;

begin
  w := '';
  for i := 1 to N do w := w + 'x';
  writeln('handed over: ', length(w):1);

  { JsonNewText: a value parameter wider than a line }
  v := JsonNewText(w);
  JsonCharsNew(out);
  JsonRender(v, out);
  writeln('new text: ', JsonCharsLen(out):1);
  JsonCharsFree(out);

  { JsonTextAdd: and appended to, by another one }
  JsonTextAdd(v, w);
  JsonCharsNew(out);
  JsonRender(v, out);
  writeln('after add: ', JsonCharsLen(out):1);
  JsonCharsFree(out);
  JsonFree(v);

  { JsonParse: a whole document that fits in one string, and does not fit in
    a line }
  w := '{"k":"';
  for i := 1 to N do w := w + 'y';
  w := w + '"}';
  r := JsonParse(w, at);
  writeln('parse ok=', r.ok, ' at=', at:1);
  doc := r.val;
  e := JsonTextInto(JsonMember(doc, 'k'), back);
  writeln('read back ok=', e = errNone, ' len=', length(back):1);
  JsonFree(doc);

  { JsonCharsAddLine: the buffer takes one too }
  JsonCharsNew(b);
  JsonCharsAddLine(b, w);
  writeln('buffer: ', JsonCharsLen(b):1);
  JsonCharsFree(b);

  { and the narrow actuals still pass }
  line := 'still a line';
  v := JsonNewText(line);
  JsonTextAdd(v, '!');
  JsonCharsNew(out);
  JsonRender(v, out);
  writeln('narrow: ', JsonCharsLen(out):1);
  JsonCharsFree(out);
  JsonFree(v)
end.
