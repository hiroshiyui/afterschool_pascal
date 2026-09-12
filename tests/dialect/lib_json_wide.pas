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
  out.Init;
  v.Render(out);
  writeln('new text: ', out.Len:1);
  out.Free;

  { TextAdd: and appended to, by another one }
  v.TextAdd(w);
  out.Init;
  v.Render(out);
  writeln('after add: ', out.Len:1);
  out.Free;
  v.Free;

  { JsonParse: a whole document that fits in one string, and does not fit in
    a line }
  w := '{"k":"';
  for i := 1 to N do w := w + 'y';
  w := w + '"}';
  r := JsonParse(w, at);
  writeln('parse ok=', r.ok, ' at=', at:1);
  doc := r.val;
  e := doc.Member('k').TextInto(back);
  writeln('read back ok=', e = errNone, ' len=', length(back):1);
  doc.Free;

  { AddText: the buffer takes one too }
  b.Init;
  b.AddText(w);
  writeln('buffer: ', b.Len:1);
  b.Free;

  { and the narrow actuals still pass }
  line := 'still a line';
  v := JsonNewText(line);
  v.TextAdd('!');
  out.Init;
  v.Render(out);
  writeln('narrow: ', out.Len:1);
  out.Free;
  v.Free
end.
