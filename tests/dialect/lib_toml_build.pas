{ PasToml: a document built rather than read, and the three bounds.

  The building half of the interface has no grammar to be judged against, so
  what this asserts is that what it builds **reads back**: every value is put
  into a table, rendered, parsed again, and asked for. That is the only claim
  worth making about a constructor -- a renderer and a parser that agree with
  each other and with nothing else would pass a golden of the rendered text.

  Three things it pins that the reading cases cannot.

  `TomlPut` **replaces in place**, so a program that overwrites a key keeps the
  order it wrote its keys in; `count` is written twice and stays second.

  A key that is not a bare key comes back quoted, and `TomlMember` finds it
  where `TomlPath` cannot -- the dots in `odd key.with dots` are the key's and
  not separators, which is the one place those two readers differ and is
  written down at both.

  And the three bounds are `errFull` and not a trap: nesting past
  `TomlDepthMax`, a key past `TomlKeyMax`, and a dotted key past
  `TomlPathMax`. A library here may not stop its caller (ADR-0120), and a
  document arriving from outside the program is exactly where that matters. }
program lib_toml_build(output);

import PasError; PasToml;

var doc, srv, arr, one, two: TomlPtr; out: TomlChars;

    s: string(1024); e: ErrorCode; st: TomlStamp; at, i: integer;
    r: TomlResult; deep: string(512);

begin
  doc := TomlNewTable;
  TomlPut(doc, 'title', TomlNewText('built by hand'));
  TomlPut(doc, 'count', TomlNewInteger(3));
  TomlPut(doc, 'ratio', TomlNewFloat(0.5));
  TomlPut(doc, 'whole', TomlNewFloat(2.0));
  TomlPut(doc, 'on', TomlNewBoolean(true));

  st.form := tdOffset;
  st.clock.DateValid := true;
  st.clock.TimeValid := true;
  st.clock.year := 2026;
  st.clock.month := 9;
  st.clock.day := 7;
  st.clock.hour := 12;
  st.clock.minute := 0;
  st.clock.second := 30;
  st.nanosecond := 250000000;
  st.offset := 8 * 60;
  TomlPut(doc, 'when', TomlNewStamp(st));

  arr := TomlNewArray;
  TomlAppend(arr, TomlNewInteger(1));
  TomlAppend(arr, TomlNewText('two'));
  TomlPut(doc, 'mixed', arr);

  srv := TomlNewTable;
  TomlPut(srv, 'host', TomlNewText('localhost'));
  TomlPut(srv, 'port', TomlNewInteger(8080));
  TomlPut(doc, 'server', srv);

  arr := TomlNewTableArray;
  one := TomlNewTable;
  TomlPut(one, 'name', TomlNewText('apple'));
  TomlAppend(arr, one);
  two := TomlNewTable;
  TomlPut(two, 'name', TomlNewText('pear'));
  TomlAppend(arr, two);
  TomlPut(doc, 'fruit', arr);

  { A string value assembled in pieces, which is how a caller builds one
    longer than any capacity it can declare. }
  one := TomlNewText('one');
  TomlTextAdd(one, ' and two');
  TomlPut(doc, 'joined', one);

  { A key that is not a bare key, and the replacement of one already there. }
  TomlPut(doc, 'odd key.with dots', TomlNewInteger(1));
  TomlPut(doc, 'count', TomlNewInteger(4));

  TomlCharsNew(out);
  TomlRender(doc, out);
  e := TomlCharsInto(out, s);
  writeln('--- built ---');
  writeln(s);
  writeln('--- keys in order ---');
  for i := 1 to TomlCount(doc) do write('[', TomlKeyAt(doc, i), '] ');
  writeln;

  r := TomlParseChars(out, at);
  writeln('reads back=', r.ok);
  if r.ok then begin
    writeln('count=', TomlIntegerOr(TomlMember(r.val, 'count'), -1):1,
            ' server.port=', TomlIntegerOr(TomlPath(r.val, 'server.port'), -1):1);
    writeln('odd key=',
            TomlIntegerOr(TomlMember(r.val, 'odd key.with dots'), -1):1,
            ' by path=', TomlIntegerOr(TomlPath(r.val, 'odd key.with dots'), -1):1);
    TomlFree(r.val)
  end;
  TomlCharsFree(out);
  TomlFree(doc);

  { The string form of the parser, and the two bounds. }
  r := TomlParse('a = 1', at);
  writeln('TomlParse=', r.ok, ' a=', TomlIntegerOr(TomlMember(r.val, 'a'), -1):1);
  TomlFree(r.val);

  deep := 'a = ';
  for i := 1 to 120 do deep := deep + '[';
  r := TomlParse(deep, at);
  writeln('nesting past the limit=', ErrorText(r.cause));

  deep := '';
  for i := 1 to 300 do deep := deep + 'k';
  r := TomlParse(deep + ' = 1', at);
  writeln('a key of 300 bytes=', ErrorText(r.cause));

  r := TomlParse('a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q = 1', at);
  writeln('seventeen segments=', ErrorText(r.cause))
end.
