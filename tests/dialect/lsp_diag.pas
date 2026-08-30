{ PasLspDiag: a compiler diagnostic, in the Language Server Protocol's shape.

  Three things this pins, and the first two are the ones a server gets wrong.

  **A line that is not a diagnostic is the ordinary case.** Most of what a
  compilation writes is not one, so `DiagParse` answering `errSyntax` is not a
  failure path -- it is the path a sweep takes on nearly every line, and a
  server that treats it as an error reports the compiler's own progress
  messages as problems in the user's file.

  **The protocol counts from zero.** `ErrorAt` writes 1-based line and column;
  LSP is 0-based in both. The golden holds the converted numbers, so an
  off-by-one in either direction changes it.

  **A `Diagnostic` holds what the compiler said.** The conversion happens in
  `DiagJson` and nowhere else, which is why the parsed values printed below
  are the compiler's numbers and the rendered object's are one less.

  **And the column is converted as well as the line**, which is the fourth
  thing and the one that needs a witness rather than a claim. `ErrorAt` counts
  **bytes**; a Position.character counts **UTF-16 code units** unless the
  client negotiated otherwise. A line holding nothing above U+007F converts to
  itself, so every other case in this file would pass with the conversion
  deleted -- the section below is the one that would not. `Utf16Column` is
  1-based on both sides deliberately: it converts the unit and nothing else,
  and `DiagJson` still owns the single subtraction. }
program lsp_diag(output);

import PasError; PasJson; PasLspDiag;

var r: DiagResult;
    out: JsonChars;
    s: string(1024);
    e: ErrorCode;
    arr, note, one, two: JsonPtr;
    d: Diagnostic;

procedure Show(what: DiagText);
var got: DiagResult;
begin
  got := DiagParse(what);
  if got.ok then begin
    write('  line ', got.val.line:1, ' col ', got.val.col:1, ' ');
    { The severity word is printed, not the number: what this case is about is
      the compiler's own wording reaching the protocol, and a 1 or a 2 here
      would be the same golden for both until DiagJson is reached below. }
    case got.val.severity of
      dsError:   write('error');
      dsWarning: write('warning')
    end;
    writeln(' [', got.val.message, ']')
  end
  else
    writeln('  not a diagnostic: ', ErrorText(got.cause))
end;

{ The conversion, printed as the pair it is: what the compiler said, and what
  the protocol is told. }
procedure ShowCol(what: string; line: DiagLine; col: integer);
begin
  writeln('  ', what, ' byte ', col:2, ' -> utf-16 ', Utf16Column(line, col):2)
end;

{ The whole object, so that the 0-based subtraction and the unit conversion are
  seen composing rather than separately. }
procedure Render(what: string; d: Diagnostic; line: DiagLine; enc: PosEncoding);
var v: JsonPtr;
    b: JsonChars;
    text: string(1024);
    junk: ErrorCode;
begin
  v := DiagJson(d, line, enc);
  JsonCharsNew(b);
  JsonRender(v, b);
  junk := JsonCharsInto(b, text);
  writeln('  ', what, '  ', text);
  JsonCharsFree(b);
  JsonFree(v)
end;

begin
  writeln('what DiagParse makes of a compilation''s output:');
  Show('hello.pas:12:7: error: ''x'' is not declared');
  Show('hello.pas:1:1: error: a program must have a program-heading');
  { The second severity (ADR-0272). This line stood among the ones a sweep
    must *skip*, with the message `this compiler emits none` -- which was true
    when it was written and is exactly the kind of case a new severity has to
    come back and move. }
  Show('hello.pas:12:7: warning: ''b'' is declared here and never used');

  { The lines a sweep meets and must skip. Every one of them is malformed:
    the severity word is no longer what separates a diagnostic from a line of
    ordinary output. }
  Show('');
  Show('no colons here at all');
  Show('hello.pas:12:7: note: no third severity, so this is not one');
  Show(':12:7: error: an empty path');
  Show('hello.pas:x:7: error: a line that is not a number');
  Show('hello.pas:12: error: a column that is not there');

  { A zero is not a position: both are 1-based at the source. }
  Show('hello.pas:0:7: error: line zero');

  writeln;
  writeln('one diagnostic as the protocol writes it:');
  r := DiagParse('hello.pas:12:7: error: ''x'' is not declared');
  JsonCharsNew(out);
  { No line to convert with, so the byte column comes back unchanged -- which
    is what every caller that never meets a non-ASCII line sees. }
  one := DiagJson(r.val, '', peUtf16);
  JsonRender(one, out);
  e := JsonCharsInto(out, s);
  writeln('  ', s);
  JsonCharsFree(out);

  { ...and the same object for the other severity, which is the whole of what
    3.17's DiagnosticSeverity 2 changes: one number, and every other field
    the same. Printed rather than asserted about, because a severity that
    reached `Diagnostic` and not the JSON would look right everywhere else.

    A second variable, because `one` is appended to the notification below and
    is owned by it from then on -- overwriting it here would leak the object
    and `heap-balance` would say so. }
  r := DiagParse('hello.pas:3:5: warning: ''b'' is declared here and never used');
  JsonCharsNew(out);
  two := DiagJson(r.val, '', peUtf16);
  JsonRender(two, out);
  e := JsonCharsInto(out, s);
  writeln('  ', s);
  JsonCharsFree(out);
  JsonFree(two);

  writeln;
  writeln('a byte column, as a UTF-16 code unit column:');
  { The compiler's own answer for this line, measured rather than assumed:
    `pascalc` reports column 22 for `zz`, because the e-acute is two bytes.
    UTF-16 counts it as one, so the protocol's column is 21. }
  ShowCol('e-acute before the error   ', '  writeln(''héllo''); zz := 1', 22);
  { Nothing above U+007F: every unit is a byte and the answer is the input.
    This is the row that makes the conversion invisible almost everywhere. }
  ShowCol('the same line without it   ', '  writeln(''hello''); zz := 1', 21);
  { U+1F600 is four bytes of UTF-8 and a *surrogate pair* in UTF-16, so it is
    the one character that makes the protocol's column larger than a scalar
    count would give. Two bytes fewer, one unit more. }
  ShowCol('an astral character        ', '  writeln(''😀''); zz := 1', 20);
  { A column *inside* a scalar. The compiler pointed at a byte and there is no
    code unit at that position, so what comes back is the byte column. }
  ShowCol('inside the e-acute         ', '  writeln(''héllo''); zz := 1', 14);
  { Column 1 is column 1 under every encoding. }
  ShowCol('the start of a line        ', '  writeln(''héllo'')', 1);
  { A column past the end of what was handed over, which is also what an empty
    line produces: one unit per byte, and the compiler's column back. }
  ShowCol('past the end of the line   ', 'ab', 7);
  ShowCol('no line at all             ', '', 7);
  { A byte no well-formed UTF-8 sequence begins with. A source file may hold
    one and the compiler read it as a byte, so this counts it as one. }
  ShowCol('an ill-formed byte         ', 'a' + chr(255) + 'bc', 4);

  writeln;
  writeln('and the same diagnostic under each encoding:');
  d.line := 3;
  d.col := 22;
  { Every field, including the one ADR-0272 added: a `Diagnostic` built here
    rather than parsed has no severity until this says so. }
  d.severity := dsError;
  d.message := 'undeclared identifier ''zz''';
  Render('utf-16 (the default)', d,
         '  writeln(''héllo''); zz := 1', peUtf16);
  Render('utf-8  (negotiated) ', d,
         '  writeln(''héllo''); zz := 1', peUtf8);

  writeln;
  writeln('and the notification that carries them:');
  arr := JsonNewArray;
  JsonAppend(arr, one);
  d.line := 3;
  d.col := 1;
  d.severity := dsWarning;
  d.message := 'a second one';
  JsonAppend(arr, DiagJson(d, '', peUtf16));
  note := DiagPublish('file:///tmp/hello.pas', arr);
  JsonCharsNew(out);
  JsonRender(note, out);
  e := JsonCharsInto(out, s);
  writeln('  ', s);
  JsonCharsFree(out);
  JsonFree(note)
end.
