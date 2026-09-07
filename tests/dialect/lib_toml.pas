{ PasToml: a TOML document read, navigated and written back.

  The document below is written to hold one of everything TOML v1.0.0 has, so
  that a reading of the format can be checked against it rather than against
  the parser: bare, quoted and dotted keys; all four string forms with their
  escapes and their two trimming rules; integers in four bases with
  underscores; floats with a fraction, an exponent, and the three values this
  language has no literal for; all four date-time forms; arrays over lines and
  with a trailing comma; inline tables; sub-tables; and arrays of tables.

  **The last thing it does is the strongest claim in the file.** What the
  renderer wrote is parsed again and rendered again, and the two must be equal
  byte for byte -- which no single assertion above it makes, and which is the
  property a program editing a configuration depends on. It is the same claim
  `format-check` makes about the compiler's own formatter (ADR-0284), one
  format over.

  What it deliberately does not assert is how a non-finite float or a date is
  spelled by the *processor*: `inf`, `nan` and `1979-05-27T07:32:00Z` are
  written by this module out of TOML's own grammar, so the golden is about
  TOML and not about the host C library. `tests/dialect/lib_json_nan.pas` is
  where the other question is asked. }
program lib_toml(output);

import PasError; PasToml;

var r: TomlResult; at, line, col, i: integer;
    doc, a: TomlPtr; buf, out, again: TomlChars;
    s, s2: string(2048); e: ErrorCode; st: TomlStamp;

{ One line of the document, since a source cannot hold a newline in a string
  literal and building the buffer a line at a time is what a program reading a
  file does anyway. }
procedure Feed(t: string);
begin
  TomlCharsAddLine(buf, t);
  TomlCharsAdd(buf, chr(10))
end;

begin
  TomlCharsNew(buf);
  Feed('# a configuration');
  Feed('title = "TOML \"demo\""');
  Feed('lit = ''C:\path\no-escape''');
  Feed('multi = """');
  Feed('one \');
  Feed('     two');
  Feed('"""');
  Feed('mlit = ''''''a''b''''''');
  Feed('n1 = 1_000');
  Feed('n2 = 0x7fff_ffff');
  Feed('n3 = 0o755');
  Feed('n4 = 0b1010');
  Feed('n5 = -17');
  Feed('f1 = 3.1415');
  Feed('f2 = 6.626e-34');
  Feed('f3 = inf');
  Feed('f4 = -inf');
  Feed('f5 = nan');
  Feed('f6 = 1.0');
  Feed('yes = true');
  Feed('d1 = 1979-05-27');
  Feed('d2 = 07:32:00.5');
  Feed('d3 = 1979-05-27T07:32:00');
  Feed('d4 = 1979-05-27 07:32:00Z');
  Feed('d5 = 1979-05-27T00:32:00-07:00');
  Feed('list = [ 1, 2,');
  Feed('        3, ]  # over two lines, with a trailing comma');
  Feed('nest = [[1, 2], ["a"]]');
  Feed('point = { x = 1, y = 2 }');
  Feed('dotted.a.b = 9');
  Feed('dotted.a.c = 10');
  Feed('');
  Feed('[server]');
  Feed('host = "localhost"');
  Feed('port = 8080');
  Feed('');
  Feed('[server.tls]');
  Feed('verify = true');
  Feed('');
  Feed('[[fruit]]');
  Feed('name = "apple"');
  Feed('[[fruit]]');
  Feed('name = "banana"');
  Feed('[fruit.variety]');
  Feed('kind = "cavendish"');

  r := TomlParseChars(buf, at);
  writeln('parse ok=', r.ok);
  if not r.ok then begin
    TomlPositionOf(buf, at, line, col);
    writeln('  refused ', ErrorText(r.cause), ' at ', line:1, ':', col:1)
  end
  else begin
    doc := r.val;
    writeln('top-level entries=', TomlCount(doc):1);

    { --- the four string forms ---------------------------------------- }
    e := TomlTextInto(TomlMember(doc, 'title'), s);
    writeln('title=[', s, ']');
    e := TomlTextInto(TomlMember(doc, 'lit'), s);
    writeln('lit=[', s, ']');
    { The newline after the opening delimiter is not content, and the
      line-ending backslash takes the newline and the next line's blanks with
      it -- so this is `one two` and then the newline before the closing
      delimiter, which is. }
    e := TomlTextInto(TomlMember(doc, 'multi'), s);
    writeln('multi=[', s, ']');
    { Two apostrophes inside a run of three are content, which is how a
      literal string holds one. }
    e := TomlTextInto(TomlMember(doc, 'mlit'), s);
    writeln('mlit=[', s, ']');

    { The byte readers, which are what a value too long for any capacity the
      caller can declare is read through -- `TomlTextInto` answers `errFull`
      for one, and these do not. `TomlCharsFull` is the same question asked of
      the buffer a caller is assembling somebody else's document into. }
    a := TomlMember(doc, 'title');
    writeln('title bytes=', TomlTextLen(a):1,
            ' [2]=', TomlTextAt(a, 2), ' [6]=', TomlTextAt(a, 6),
            ' not-a-string len=', TomlTextLen(TomlMember(doc, 'n1')):1);
    writeln('document bytes=', TomlCharsLen(buf):1,
            ' [1]=', TomlCharsAt(buf, 1), ' full=', TomlCharsFull(buf));

    { --- numbers ------------------------------------------------------- }
    writeln('n1=', TomlIntegerOr(TomlMember(doc, 'n1'), -1):1,
            ' n2=', TomlIntegerOr(TomlMember(doc, 'n2'), -1):1,
            ' n3=', TomlIntegerOr(TomlMember(doc, 'n3'), -1):1,
            ' n4=', TomlIntegerOr(TomlMember(doc, 'n4'), -1):1,
            ' n5=', TomlIntegerOr(TomlMember(doc, 'n5'), -1):1);
    { An integer answers TomlFloatOr and a float does not answer
      TomlIntegerOr: 1.5 is not an integer and answering 1 would be a
      different configuration. }
    writeln('f1=', TomlFloatOr(TomlMember(doc, 'f1'), 0.0):6:4,
            ' f1 as integer=', TomlIntegerOr(TomlMember(doc, 'f1'), -1):1,
            ' n5 as float=', TomlFloatOr(TomlMember(doc, 'n5'), 0.0):6:1);
    writeln('yes=', TomlBooleanOr(TomlMember(doc, 'yes'), false));

    { --- the four date-time forms -------------------------------------- }
    st := TomlStampOr(TomlMember(doc, 'd1'), st);
    writeln('d1 form=', ord(st.form):1, ' y=', st.clock.year:1,
            ' m=', st.clock.month:1, ' d=', st.clock.day:1,
            ' timevalid=', st.clock.TimeValid);
    st := TomlStampOr(TomlMember(doc, 'd2'), st);
    writeln('d2 form=', ord(st.form):1, ' h=', st.clock.hour:1,
            ' ns=', st.nanosecond:1, ' datevalid=', st.clock.DateValid);
    st := TomlStampOr(TomlMember(doc, 'd3'), st);
    writeln('d3 form=', ord(st.form):1, ' offset=', st.offset:1);
    st := TomlStampOr(TomlMember(doc, 'd5'), st);
    writeln('d5 form=', ord(st.form):1, ' offset=', st.offset:1);

    { --- arrays and tables --------------------------------------------- }
    a := TomlMember(doc, 'list');
    write('list=');
    for i := 1 to TomlCount(a) do write(TomlIntegerOr(TomlAt(a, i), 0):1, ' ');
    writeln;
    writeln('nest[1][2]=',
            TomlIntegerOr(TomlAt(TomlAt(TomlMember(doc, 'nest'), 1), 2), -1):1);
    writeln('point.y=', TomlIntegerOr(TomlPath(doc, 'point.y'), -1):1);
    writeln('dotted.a.b=', TomlIntegerOr(TomlPath(doc, 'dotted.a.b'), -1):1,
            ' dotted.a.c=', TomlIntegerOr(TomlPath(doc, 'dotted.a.c'), -1):1);
    writeln('server.port=', TomlIntegerOr(TomlPath(doc, 'server.port'), -1):1,
            ' server.tls.verify=',
            TomlBooleanOr(TomlPath(doc, 'server.tls.verify'), false));

    a := TomlMember(doc, 'fruit');
    writeln('fruit is a table array=', TomlIsTableArray(a),
            ' count=', TomlCount(a):1);
    e := TomlTextInto(TomlPath(TomlAt(a, 2), 'name'), s);
    writeln('fruit[2].name=', s);
    { A header under an array of tables names the last element started, which
      is what makes a variety belong to the banana. }
    e := TomlTextInto(TomlPath(TomlAt(a, 2), 'variety.kind'), s);
    writeln('fruit[2].variety.kind=', s);

    { A key that is not there reads as an empty table, so a reader may ask for
      a whole path without asking whether each step exists. }
    writeln('absent kind=', ord(TomlKindOf(TomlPath(doc, 'no.such.thing'))):1,
            ' count=', TomlCount(TomlPath(doc, 'no.such')):1,
            ' int=', TomlIntegerOr(TomlPath(doc, 'no.such'), -1):1);

    { --- writing it back ------------------------------------------------ }
    TomlCharsNew(out);
    TomlRender(doc, out);
    e := TomlCharsInto(out, s);
    writeln('--- rendered (code=', ord(e):1, ') ---');
    write(s);
    writeln('--- end ---');
    TomlFree(doc);

    { --- and the claim the file is for ---------------------------------- }
    r := TomlParseChars(out, at);
    writeln('reparse ok=', r.ok);
    if r.ok then begin
      TomlCharsNew(again);
      TomlRender(r.val, again);
      e := TomlCharsInto(again, s2);
      writeln('round trip identical=', s = s2);
      TomlCharsFree(again);
      TomlFree(r.val)
    end;
    TomlCharsFree(out)
  end;
  TomlCharsFree(buf)
end.
