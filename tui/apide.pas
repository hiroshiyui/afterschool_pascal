{ The editor a person runs.

  **Everything this program decides is in `ApEdit`**, and everything here is
  the terminal: bytes off a descriptor into the decoder, and a screen out
  through `PasTerm`'s sequences (ADR-0381). The split is what makes the
  editor testable at all -- `tui/session.pas` drives the same routines from a
  script and a golden compares what they drew -- and it is what leaves this
  file small enough to read in one sitting.

  So **this file is the part no oracle here reaches**, and `doc/sop.md` 7 says
  so: `ctest` has no terminal, and a case that wanted one would need a
  pseudo-terminal binding, which ADR-0262 declined. What is checked by hand,
  and what a person notices immediately if it breaks, is that the terminal is
  returned to how it was found.

  **It never mixes with 6.10's `write`.** `input` and `output` are buffered
  streams that read ahead, and a key here is a byte off a descriptor: a
  program using both loses characters to whichever buffered first, which is
  `PasTerm`'s own limitation and cannot be fixed from this side. So every
  byte out goes through `PasIO.WriteText`, and this program declares no file
  parameters at all.

  Milestone one, and the keys are the ones a Turbo Pascal user reaches for:

    Ctrl-S   save         Ctrl-Q   quit        Ctrl-B   build
    arrows, Home, End, Enter, Backspace, Delete

  What building does is run the compiler over the file and land the cursor on
  the first diagnostic, which is the whole of why an IDE is worth having and
  is the one thing here that is not editing. }

program apide(output);

import PasError;
       PasIO;
       PasStrVec;
       PasTerm;
       PasFile;
       PasProcess;
       ApEdit;

const
  { What to run for Ctrl-B. `pascalc` writes `file:line:col: error: message`
    to its standard *output* and stops at the first stage that failed, which
    is exactly what this wants: the position, and nothing to link. }
  Compiler = 'pascalc';
  Sink = '/dev/null';

var
  ed: Editor;
  dec: Decoder;
  scr: Screen;
  { The command line's, and `Load`'s. **It is not the document's name** --
    that is the model's and is read back with `EditName` (ADR-0388), so that a
    save-as cannot leave the two disagreeing. }
  path: FilePath;
  rows, cols: integer;
  running, asked: boolean;
  e: ErrorCode;

{ One row of the drawing, put where it belongs and padded to the window's
  width so that what a shorter line replaces is erased rather than left
  showing. `ClearLine` would be a second sequence per row and this is one. }
{ **The palette, and it lives here** (ADR-0389). The model says what a cell
  is for and this says what that looks like, so changing the scheme changes
  neither `ApEdit` nor one recorded screen -- a role is a fact and a colour is
  a preference. The scheme is Turbo Pascal's in spirit: the document plain,
  the chrome reversed out of it.

  A row is one colour today because that is what the roles are; a row of mixed
  roles is what a panel will bring, and `PutRow` will then break the row into
  runs instead of taking the first cell's. It takes the first cell's *and says
  so*, rather than pretending to be general. }
procedure RoleColour(k: CellRole; var fg, bg: Colour);
begin
  case k of
    crText: begin fg := clDefault; bg := clDefault end;
    { The status line is what Turbo Pascal put in reverse video, and it is the
      one row a person looks at without meaning to. }
    crStatus: begin fg := clBlack; bg := clCyan end;
    crHint: begin fg := clBlack; bg := clWhite end;
    { A message is the editor speaking and a question is the editor waiting,
      so they do not look alike -- which is the whole reason the model tells
      them apart. }
    crMessage: begin fg := clYellow; bg := clDefault end;
    crPrompt: begin fg := clBlack; bg := clYellow end;
    { A panel's frame and the menu bar, and the item under the cursor in
      reverse of the bar -- Turbo Pascal's own scheme. }
    crFrame: begin fg := clCyan; bg := clBlue end;
    crMenu: begin fg := clBlack; bg := clCyan end;
    crChosen: begin fg := clWhite; bg := clBlue end;
  end
end;

{ One row, **a run at a time**. The split is the model's (`RowRuns`/`RowRun`,
  ADR-0391) and not this side's, which is what lets a golden hold it: the
  harness links this program and never runs it, so a shell that painted every
  row with one colour would pass the whole suite.

  A run is written on its own rather than the row being assembled, because a
  row of box characters is three bytes a column and `IOMax` is 4096 -- a
  worst case of many runs would overflow one line where a run cannot. }
procedure PutRow(r: integer);
var i, lo, hi, c: integer; out: IOLine; e2: ErrorCode;
    k: CellRole; fg, bg: Colour;
begin
  for i := 1 to RowRuns(scr, r) do begin
    RowRun(scr, r, i, lo, hi, k);
    RoleColour(k, fg, bg);
    out := CursorTo(r, lo) + SetColour(fg, bg);
    { A continuation cell is the null-string and contributes nothing, which
      is right: the terminal has already advanced past the wide cell that
      owns it. }
    for c := lo to hi do out := out + scr.cell[r][c];
    out := out + ResetColour;
    e2 := WriteText(StdOut, out)
  end
end;

{ The whole frame. The cursor is hidden across it, or the terminal draws it
  at every intermediate position and the screen crawls. }
procedure Draw;
var r: integer; e2: ErrorCode;
begin
  if TermSize(StdOut, rows, cols) <> errNone then begin
    rows := 24;
    cols := 80
  end;
  EditRender(ed, rows, cols, scr);
  e2 := WriteText(StdOut, HideCursor);
  { The first cell's role stands for the row, which is true of every row this
    editor draws today and is checked by nothing -- a `doc/sop.md` §7 row
    until panels make it false and `PutRow` has to split a row into runs. }
  for r := 1 to scr.rows do PutRow(r);
  e2 := WriteText(StdOut, CursorTo(scr.atRow, scr.atCol));
  e2 := WriteText(StdOut, ShowCursor)
end;

{ Load, if there is anything there. A path that names nothing is not an
  error: it is a new file, which is what an editor is for. }
procedure Load;
var n, i: integer; line: EditLine;
begin
  EditSetName(ed, path);
  if not LineCount(path, n) then begin
    EditSay(ed, 'new file');
    n := 0
  end;
  for i := 1 to n do
    if ReadLine(path, i, line) then EditPush(ed, line)
end;

{ Save. Written a line at a time rather than as one value, because the whole
  document has no bound this program may assume -- a string long enough for
  every file is a number somebody would have to pick, and `AppendLine` needs
  none. What it costs is an open per line, which is invisible at the sizes a
  person edits and would not be for a generated file. }
procedure Save;
var i: integer; ok: boolean; msg: EditLine; path: FilePath;
begin
  { **The name is the model's, and this reads it rather than keeping a second
    copy** (ADR-0388). It used to hold a `path` of its own beside `ed.name`,
    set once from the command line -- two names for one thing, and save-as is
    what made them able to disagree: the person answers a prompt, the model
    knows the new name and the shell would have gone on writing the old one.
    A fact stated twice is a fact that will disagree with itself.

    There is no guard for an empty name here any more, because there is no
    longer a way to arrive with one: Ctrl-S on an unnamed document opens the
    prompt instead of reaching this at all. }
  path := EditName(ed);
  ok := WriteAllText(path, '');
  i := 1;
  while ok and (i <= EditLines(ed)) do begin
    ok := AppendLine(path, EditLine_(ed, i));
    i := i + 1
  end;
  if ok then begin
    writestr(msg, 'saved ', EditLines(ed):1, ' line(s)');
    EditSay(ed, msg);
    EditSaved(ed)
  end
  else
    EditSay(ed, 'could not write ' + path)
end;

{ Compile, and land on the fault. `Execute` and never `Run`: a path is a
  value and `system` would let a file named `a'; rm -rf /; echo '.pas` run in
  its own name, which is ADR-0362 and cost this project a real defect over
  LSP. The words go in as words. }
procedure Build;
var v: ArgV; r: RunResult; out: IOLine;
begin
  { The compiler is handed a path, so there has to be one, and the diagnostic
    a compiler gives for an empty argument is about the compiler and not about
    this document. **Ctrl-S now names one**, so the advice is a key that works
    rather than a restart. }
  if EditName(ed) = '' then begin
    EditSay(ed, 'this document has no name -- Ctrl-S to give it one');
    exit
  end;
  e := NewArgs(v);
  if e = errNone then e := AddArg(v, Compiler);
  if e = errNone then e := AddArg(v, EditName(ed));
  if e = errNone then e := AddArg(v, '-o');
  if e = errNone then e := AddArg(v, Sink);
  if e <> errNone then begin
    EditSay(ed, 'could not build the command');
    exit
  end;
  out := '';
  r := ExecuteInto(v, out);
  if not r.ok then begin
    EditSay(ed, 'could not run ' + Compiler + ': ' + ErrorText(r.cause));
    exit
  end;
  { **Where the cursor goes is the model's** and not this file's (ADR-0381):
    the shell is bytes in and bytes out, and a session drives `EditFault`
    with a compiler's output to hold what it does. }
  if r.val = 0 then
    EditSay(ed, 'compiled')
  else if not EditFault(ed, out) then
    EditSay(ed, 'it did not compile, and said nothing this could read')
end;

{ What the model asked for and does not do itself: a write, a build, a quit.
  One place, because a menu item and a typed key produce the same request. }
procedure Obey(k: Key);
begin
  if k.kind = kkSave then Save
  else if k.kind = kkBuild then Build
  else if k.kind = kkQuit then running := false
end;

var c: char; k: Key; e2: ErrorCode; cmd: Key;
begin
  if argcount >= 1 then path := argument(1) else path := '';
  EditInit(ed);
  DecodeInit(dec);
  { **No file is a new document and not a usage error.** It used to answer
    with what looked like a usage line, which is the wrong thing to say to a
    person who typed `afterschool` on purpose: the editor starts on an empty
    unnamed buffer, and Ctrl-S is the only thing that then needs a name. }
  if path <> '' then Load
  else EditSay(ed, 'a new document -- Ctrl-Q to quit');

  { The terminal, and putting it back. `defer` is what makes the restore
    unconditional (AP 6.9.3.11): every way out of this block below -- the
    loop ending, a `halt`, a trap -- runs these, in the reverse of the order
    they were armed. Raw mode is restored by the runtime at exit as well
    (ADR-0262), and the alternate screen is not: nothing but this program
    knows it entered one. }
  e := EnterRaw(StdIn);
  if e <> errNone then begin
    e2 := WriteText(StdErr, 'afterschool: this is not a terminal' + chr(10));
    halt(1)
  end;
  defer e2 := WriteText(StdOut, ShowCursor);
  defer e := LeaveRaw;
  e2 := WriteText(StdOut, EnterScreen);
  defer e2 := WriteText(StdOut, LeaveScreen);

  running := true;
  asked := false;
  Draw;
  while running do begin
    e := ReadKey(StdIn, c);
    if e <> errNone then
      running := false
    else if DecodeByte(dec, c, k) then begin
      { **A question owns the keyboard while it is open** (ADR-0387). Ctrl-S
        inside a search is part of what is being searched for, not a write to
        disc, and Ctrl-Q there must not quit -- so the shell asks the model
        whether it is asking something and, if it is, does nothing of its own
        with the key. It is the only thing about a prompt the shell knows,
        and keeping it to one question is what stops the mode leaking out of
        the model it belongs to. }
      if EditModal(ed) then begin
        asked := false;
        EditKey(ed, k);
        { **The answer to `Save as:` is a name, and writing it is this side's
          half** (ADR-0388). The model takes the request once and clears it,
          so a second key cannot write a second time -- and the write is here
          because a file is, which is the line ADR-0381 drew for the screen
          and this is the same one. }
        { **A menu choice and a keystroke arrive the same way** (ADR-0391):
          the model hands back a `Key` it does not act on itself, and this
          dispatches it through the arms it already has. `Save` after a
          `Save as:` answer is the same request as `File > Save`. }
        if EditTakeCommand(ed, cmd) then Obey(cmd)
      end
      else if k.kind = kkQuit then begin
        { A document with changes in it takes two presses, and the second has
          to be the *next* key -- which is what `asked` being cleared below
          says. An editor that quit on one press over unsaved work is the one
          thing a person never forgives. }
        if (not EditDirty(ed)) or asked then running := false
        else begin
          asked := true;
          EditSay(ed, 'modified -- Ctrl-Q again to quit')
        end
      end
      else begin
        asked := false;
        { Ctrl-S is this side's only when there is a name to write under. With
          none the model is asked instead, and it opens the question -- so the
          key does the same thing either way from where a person sits, which
          is the point. }
        if (k.kind = kkSave) and (EditName(ed) <> '') then Save
        else if k.kind = kkBuild then Build
        else begin
          EditKey(ed, k);
          if EditTakeCommand(ed, cmd) then Obey(cmd)
        end
      end;
      if running then Draw
    end
  end;
  EditFree(ed)
end.
