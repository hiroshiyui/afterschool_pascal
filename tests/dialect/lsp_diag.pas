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
  are the compiler's numbers and the rendered object's are one less. }
program lsp_diag(output);

import PasError; PasJson; PasLspDiag;

var r: DiagResult;
    out: JsonChars;
    s: string(1024);
    e: ErrorCode;
    arr, note, one: JsonPtr;
    d: Diagnostic;

procedure Show(what: DiagText);
var got: DiagResult;
begin
  got := DiagParse(what);
  if got.ok then
    writeln('  line ', got.val.line:1, ' col ', got.val.col:1,
            ' [', got.val.message, ']')
  else
    writeln('  not a diagnostic: ', ErrorText(got.cause))
end;

begin
  writeln('what DiagParse makes of a compilation''s output:');
  Show('hello.pas:12:7: error: ''x'' is not declared');
  Show('hello.pas:1:1: error: a program must have a program-heading');

  { The lines a sweep meets and must skip. }
  Show('');
  Show('no colons here at all');
  Show('hello.pas:12:7: warning: this compiler emits none');
  Show(':12:7: error: an empty path');
  Show('hello.pas:x:7: error: a line that is not a number');
  Show('hello.pas:12: error: a column that is not there');

  { A zero is not a position: both are 1-based at the source. }
  Show('hello.pas:0:7: error: line zero');

  writeln;
  writeln('one diagnostic as the protocol writes it:');
  r := DiagParse('hello.pas:12:7: error: ''x'' is not declared');
  JsonCharsNew(out);
  one := DiagJson(r.val);
  JsonRender(one, out);
  e := JsonCharsInto(out, s);
  writeln('  ', s);
  JsonCharsFree(out);

  writeln;
  writeln('and the notification that carries them:');
  arr := JsonNewArray;
  JsonAppend(arr, one);
  d.line := 3;
  d.col := 1;
  d.message := 'a second one';
  JsonAppend(arr, DiagJson(d));
  note := DiagPublish('file:///tmp/hello.pas', arr);
  JsonCharsNew(out);
  JsonRender(note, out);
  e := JsonCharsInto(out, s);
  writeln('  ', s);
  JsonCharsFree(out);
  JsonFree(note)
end.
