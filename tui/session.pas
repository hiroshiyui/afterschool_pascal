{ A session, replayed against the editor with no terminal anywhere near it.

  This is the program `tui/run.py` builds and drives, and it is the reason
  the editor can be held to a golden at all (ADR-0381): `ApEdit` decides what
  a key does and what the screen looks like, and this feeds it keys off
  standard input and prints the screens it draws. What a session compares is
  therefore **what a person would have seen**, frame by frame, and not an
  internal.

  It is a program of the tree's own and not a test fixture in disguise: the
  editor's shell (`tui/apide.pas`) drives exactly these routines with
  `PasTerm.ReadKey` in front of them and `PasTerm.CursorTo` behind, so a
  session exercises the same code a person does. The two differ in where the
  bytes come from and nowhere else.

  **The script is directives and not raw bytes**, because a golden holding a
  literal ESC is a file no diff reads aloud -- `tests/dialect/lib_term.pas`
  met that first and answered it the same way. One directive per line:

    name  <text>     what the status line calls the document
    push  <text>     append a line, as loading a file does
    size  <r> <c>    the terminal to draw for
    keys  <text>     every character of <text>, as bytes
    esc   <text>     ESC [ <text>, so `esc A` is an up arrow
    ctrl  <letter>   the control byte for that letter: `ctrl S` is Ctrl-S
    draw             render, and print what was drawn
    say   <text>     what the shell would have put on the message line
    fault <text>     a compiler's output, landed on as Ctrl-B lands on it

  A line that is none of these stops the program, since a directive nobody
  implements is a session that asserts less than it appears to (`tests/spec/`
  makes the same refusal for the same reason). }

program session(input, output);

import PasError;
       PasStrVec;
       ApEdit;

var
  ed: Editor;
  dec: Decoder;
  scr: Screen;
  line: EditLine;
  rows, cols: integer;

{ The first word of a directive, and what follows it. Split at the first
  blank, so a `push` of a line with blanks in it keeps them. }
function Word1(s: EditLine): EditLine;
var i: integer;
begin
  i := 1;
  while (i <= length(s)) and (s[i] <> ' ') do i := i + 1;
  if i = 1 then Word1 := ''
  else Word1 := substr(s, 1, i - 1)
end;

function Rest(s: EditLine): EditLine;
var i: integer;
begin
  i := 1;
  while (i <= length(s)) and (s[i] <> ' ') do i := i + 1;
  if i >= length(s) then Rest := ''
  else Rest := substr(s, i + 1, length(s) - i)
end;

{ One byte into the decoder, and the key it completes into the editor. The
  shell's loop is these three lines. }
procedure Feed(c: char);
var k: Key;
begin
  if DecodeByte(dec, c, k) then
    EditKey(ed, k)
end;

procedure FeedAll(s: EditLine);
var i: integer;
begin
  for i := 1 to length(s) do Feed(s[i])
end;

{ The screen, with a border so that a trailing blank is visible in the golden
  -- a line that ends in spaces and one that does not are different drawings
  and a diff of bare text cannot show which is which. }
{ One letter per role (ADR-0389). **A golden holds what a cell is for**, and
  a letter is what makes that readable: `sssss` under the status line says the
  thing a row of SGR numbers would have hidden. Every constant is named, so a
  fifth role stops this program rather than printing as a blank. }
function RoleChar(k: CellRole): char;
begin
  case k of
    crText: RoleChar := '.';
    crStatus: RoleChar := 's';
    crHint: RoleChar := 'h';
    crMessage: RoleChar := 'm';
    crPrompt: RoleChar := 'p';
  end
end;

procedure Print;
var r, c: integer; bar: ScreenRow;
begin
  bar := '';
  for c := 1 to scr.cols do bar := bar + '-';
  writeln('+', bar, '+');
  for r := 1 to scr.rows do begin
    line := scr.line[r];
    while length(line) < scr.cols do line := line + ' ';
    writeln('|', line, '|')
  end;
  writeln('+', bar, '+');
  { The roles, in the same coordinates, so a reader can lay one block over
    the other. Printed always rather than only when something is coloured: a
    plane that appeared and disappeared would be a golden whose *shape*
    carried information, and the frame where it vanished would be the one
    nobody noticed. }
  writeln('+', bar, '+');
  for r := 1 to scr.rows do begin
    line := '';
    for c := 1 to scr.cols do line := line + RoleChar(scr.role[r][c]);
    writeln('|', line, '|')
  end;
  writeln('+', bar, '+');
  writeln('cursor ', scr.atRow:1, ',', scr.atCol:1)
end;

var w, arg: EditLine; n: integer;
begin
  EditInit(ed);
  DecodeInit(dec);
  rows := 8;
  cols := 24;

  while not eof(input) do begin
    readln(line);
    w := Word1(line);
    arg := Rest(line);
    if (w = '') or (w = '#') then
      { a blank line and a comment, so a session can be read }
    else if w = 'name' then EditSetName(ed, arg)
    else if w = 'say' then EditSay(ed, arg)
    else if w = 'fault' then begin
      if not EditFault(ed, arg) then
        EditSay(ed, 'no diagnostic in that')
    end
    else if w = 'push' then EditPush(ed, arg)
    else if w = 'keys' then FeedAll(arg)
    else if w = 'ctrl' then begin
      if length(arg) >= 1 then Feed(chr(ord(arg[1]) - 64))
    end
    else if w = 'esc' then begin
      Feed(chr(27));
      Feed('[');
      FeedAll(arg)
    end
    else if w = 'size' then begin
      readstr(arg, rows, cols)
    end
    else if w = 'draw' then begin
      EditRender(ed, rows, cols, scr);
      Print
    end
    else begin
      writeln('session: unknown directive ', w);
      halt
    end
  end;

  { What the document became, after every frame has been compared. A session
    that only drew could pass over an editor that draws one thing and holds
    another. }
  writeln('lines ', EditLines(ed):1, ' dirty ', EditDirty(ed));
  for n := 1 to EditLines(ed) do
    writeln('  ', n:1, ': [', EditLine_(ed, n), ']');
  EditFree(ed)
end.
