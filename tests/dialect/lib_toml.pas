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
  buf.AddText(t);
  buf.Add(chr(10))
end;

begin
  buf.Init;
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
    buf.PositionOf(at, line, col);
    writeln('  refused ', r.cause.Text, ' at ', line:1, ':', col:1)
  end
  else begin
    doc := r.val;
    writeln('top-level entries=', doc.Count:1);

    { --- the four string forms ---------------------------------------- }
    e := doc.Member('title').TextInto(s);
    writeln('title=[', s, ']');
    e := doc.Member('lit').TextInto(s);
    writeln('lit=[', s, ']');
    { The newline after the opening delimiter is not content, and the
      line-ending backslash takes the newline and the next line's blanks with
      it -- so this is `one two` and then the newline before the closing
      delimiter, which is. }
    e := doc.Member('multi').TextInto(s);
    writeln('multi=[', s, ']');
    { Two apostrophes inside a run of three are content, which is how a
      literal string holds one. }
    e := doc.Member('mlit').TextInto(s);
    writeln('mlit=[', s, ']');

    { The byte readers, which are what a value too long for any capacity the
      caller can declare is read through -- `TomlTextInto` answers `errFull`
      for one, and these do not. `TomlCharsFull` is the same question asked of
      the buffer a caller is assembling somebody else's document into. }
    a := doc.Member('title');
    writeln('title bytes=', a.TextLen:1,
            ' [2]=', a.TextAt(2), ' [6]=', a.TextAt(6),
            ' not-a-string len=', doc.Member('n1').TextLen:1);
    writeln('document bytes=', buf.Len:1,
            ' [1]=', buf.At(1), ' full=', buf.Full);

    { --- numbers ------------------------------------------------------- }
    writeln('n1=', doc.Member('n1').IntegerOr(-1):1,
            ' n2=', doc.Member('n2').IntegerOr(-1):1,
            ' n3=', doc.Member('n3').IntegerOr(-1):1,
            ' n4=', doc.Member('n4').IntegerOr(-1):1,
            ' n5=', doc.Member('n5').IntegerOr(-1):1);
    { An integer answers TomlFloatOr and a float does not answer
      TomlIntegerOr: 1.5 is not an integer and answering 1 would be a
      different configuration. }
    writeln('f1=', doc.Member('f1').FloatOr(0.0):6:4,
            ' f1 as integer=', doc.Member('f1').IntegerOr(-1):1,
            ' n5 as float=', doc.Member('n5').FloatOr(0.0):6:1);
    writeln('yes=', doc.Member('yes').BooleanOr(false));

    { --- the four date-time forms -------------------------------------- }
    st := doc.Member('d1').StampOr(st);
    writeln('d1 form=', ord(st.form):1, ' y=', st.clock.year:1,
            ' m=', st.clock.month:1, ' d=', st.clock.day:1,
            ' timevalid=', st.clock.TimeValid);
    st := doc.Member('d2').StampOr(st);
    writeln('d2 form=', ord(st.form):1, ' h=', st.clock.hour:1,
            ' ns=', st.nanosecond:1, ' datevalid=', st.clock.DateValid);
    st := doc.Member('d3').StampOr(st);
    writeln('d3 form=', ord(st.form):1, ' offset=', st.offset:1);
    st := doc.Member('d5').StampOr(st);
    writeln('d5 form=', ord(st.form):1, ' offset=', st.offset:1);

    { --- arrays and tables --------------------------------------------- }
    a := doc.Member('list');
    write('list=');
    for i := 1 to a.Count do write(a.At(i).IntegerOr(0):1, ' ');
    writeln;
    writeln('nest[1][2]=',
            doc.Member('nest').At(1).At(2).IntegerOr(-1):1);
    writeln('point.y=', doc.Path('point.y').IntegerOr(-1):1);
    writeln('dotted.a.b=', doc.Path('dotted.a.b').IntegerOr(-1):1,
            ' dotted.a.c=', doc.Path('dotted.a.c').IntegerOr(-1):1);
    writeln('server.port=', doc.Path('server.port').IntegerOr(-1):1,
            ' server.tls.verify=',
            doc.Path('server.tls.verify').BooleanOr(false));

    a := doc.Member('fruit');
    writeln('fruit is a table array=', a.IsTableArray,
            ' count=', a.Count:1);
    e := a.At(2).Path('name').TextInto(s);
    writeln('fruit[2].name=', s);
    { A header under an array of tables names the last element started, which
      is what makes a variety belong to the banana. }
    e := a.At(2).Path('variety.kind').TextInto(s);
    writeln('fruit[2].variety.kind=', s);

    { A key that is not there reads as an empty table, so a reader may ask for
      a whole path without asking whether each step exists. }
    writeln('absent kind=', ord(doc.Path('no.such.thing').Kind):1,
            ' count=', doc.Path('no.such').Count:1,
            ' int=', doc.Path('no.such').IntegerOr(-1):1);

    { --- writing it back ------------------------------------------------ }
    out.Init;
    doc.Render(out);
    e := out.Into(s);
    writeln('--- rendered (code=', ord(e):1, ') ---');
    write(s);
    writeln('--- end ---');
    doc.Free;

    { --- and the claim the file is for ---------------------------------- }
    r := TomlParseChars(out, at);
    writeln('reparse ok=', r.ok);
    if r.ok then begin
      again.Init;
      r.val.Render(again);
      e := again.Into(s2);
      writeln('round trip identical=', s = s2);
      again.Free;
      r.val.Free
    end;
    out.Free
  end;
  buf.Free
end.
