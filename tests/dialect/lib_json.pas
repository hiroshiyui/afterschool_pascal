{ PasJson: a JSON document read, navigated, built and written back.

  The roadmap named this as the one library gap with a named client — every
  Language Server Protocol message is a JSON object — and as the kind of gap
  that needs no language feature. What it did need was ADR-0216: this is the
  first module in the library to instantiate a generic imported from another,
  and until that fix the component linked to nothing. }
program lib_json(output);

import PasError; PasJson;

var r: JsonResult; at: integer;
    doc, arr, obj, m: JsonPtr;
    buf, out: JsonChars;
    s: string(255); e: ErrorCode; i: integer;
    { wider than a line, and narrower than one: the two sides of the
      capacity JsonCharsInto promises to honour. }
    wide: string(1024); narrow: string(16);

begin
  { --- reading ---------------------------------------------------------- }
  r := JsonParse('{"id":7,"ok":true,"none":null,"pi":3.5,' +
                 '"list":[1,2,3],"s":"a\"b\\c\tdé"}', at);
  writeln('parse ok=', r.ok);
  doc := r.val;
  writeln('kind=', ord(JsonKindOf(doc)):1, ' members=', JsonCount(doc):1);
  writeln('id=', JsonIntegerOr(JsonMember(doc, 'id'), -1):1,
          ' ok=', JsonBooleanOr(JsonMember(doc, 'ok'), false),
          ' none=', JsonIsNull(JsonMember(doc, 'none')));
  writeln('pi=', JsonNumberOr(JsonMember(doc, 'pi'), 0.0):5:2,
          ' pi as int=', JsonIntegerOr(JsonMember(doc, 'pi'), -1):1);

  m := JsonMember(doc, 'list');
  write('list=');
  for i := 1 to JsonCount(m) do write(JsonIntegerOr(JsonAt(m, i), 0):1, ' ');
  writeln;

  { Every escape RFC 8259 §7 has, and the one that is two escapes and one
    character. `é` is é, two bytes of UTF-8, so the byte length is one
    more than the number of characters. }
  m := JsonMember(doc, 's');
  e := JsonTextInto(m, s);
  writeln('s bytes=', JsonTextLen(m):1, ' code=', ord(e):1,
          ' [2]=', JsonTextAt(m, 2));

  { A member that is not there is nil, and every reader answers for nil rather
    than trapping — which is what lets a client read an optional field without
    asking first. }
  writeln('absent kind=', ord(JsonKindOf(JsonMember(doc, 'nope'))):1,
          ' int=', JsonIntegerOr(JsonMember(doc, 'nope'), -1):1);

  { --- writing it back --------------------------------------------------- }
  JsonCharsNew(out);
  JsonRender(doc, out);
  e := JsonCharsInto(out, s);
  writeln('render=', s);
  JsonCharsFree(out);
  JsonFree(doc);

  { --- building ---------------------------------------------------------- }
  obj := JsonNewObject;
  JsonPut(obj, 'jsonrpc', JsonNewText('2.0'));
  JsonPut(obj, 'id', JsonNewInteger(1));
  arr := JsonNewArray;
  JsonAppend(arr, JsonNewInteger(10));
  JsonAppend(arr, JsonNewBoolean(false));
  JsonAppend(arr, JsonNewNull);
  JsonPut(obj, 'params', arr);
  { Replacing a member keeps its position, so a round trip does not reorder. }
  JsonPut(obj, 'id', JsonNewInteger(2));
  JsonCharsNew(out);
  JsonRender(obj, out);
  e := JsonCharsInto(out, s);
  writeln('built=', s);
  JsonCharsFree(out);
  JsonFree(obj);

  { --- a document that does not fit in one string ------------------------- }
  JsonCharsNew(buf);
  JsonCharsAddLine(buf, '["');
  for i := 1 to 300 do JsonCharsAddLine(buf, 'x');
  JsonCharsAddLine(buf, '"]');
  r := JsonParseChars(buf, at);
  writeln('long ok=', r.ok, ' len=', JsonTextLen(JsonAt(r.val, 1)):1);
  JsonFree(r.val);
  JsonCharsFree(buf);

  { --- what is refused ---------------------------------------------------- }
  r := JsonParse('{"a":1,}', at);
  writeln('trailing comma ok=', r.ok, ' cause=', ErrorText(r.cause));
  r := JsonParse('01', at);
  writeln('leading zero  ok=', r.ok, ' at=', at:1);
  { RFC 8259 §7: a control character below U+0020 may not appear unescaped.
    Without the check the byte goes into the string and the parse *succeeds*,
    which is the only refusal here whose absence produces a document rather
    than a different error. }
  r := JsonParse('"a' + chr(10) + 'b"', at);
  writeln('raw control   ok=', r.ok);
  r := JsonParse('{"a":1} {"b":2}', at);
  writeln('two values    ok=', r.ok);
  r := JsonParse('"\uD800"', at);
  writeln('lone surrogate ok=', r.ok);
  r := JsonParse('[1,2', at);
  writeln('unclosed      ok=', r.ok);

  { --- a document longer than a line -------------------------------------- }
  { `JsonCharsInto` asks whether the document fits the *caller's* capacity,
    and used to build the answer through a `string(LineMax)` accumulator --
    so a document between 256 characters and the caller's capacity passed the
    guard and then stopped the program at `a string of length 256 does not fit
    a capacity of 255`. Nothing here had rendered one that long: every case
    above fits a line. This renders 320-odd characters into a `string(1024)`
    and prints its length, which is the number the guard promised. }
  obj := JsonNewArray;
  for at := 1 to 40 do
    JsonAppend(obj, JsonNewText('12345'));
  JsonCharsNew(buf);
  JsonRender(obj, buf);
  e := JsonCharsInto(buf, wide);
  writeln('long render   code=', ErrorText(e), ' len=', length(wide):1);
  { And the guard itself still fires, into a target that genuinely cannot
    hold it -- both directions, since answering errFull always would satisfy
    one of them. }
  e := JsonCharsInto(buf, narrow);
  writeln('into a small  code=', ErrorText(e));
  JsonCharsFree(buf);
  JsonFree(obj)
end.
