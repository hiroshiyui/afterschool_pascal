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
  path: FilePath;
  rows, cols: integer;
  running, asked: boolean;
  e: ErrorCode;

{ One row of the drawing, put where it belongs and padded to the window's
  width so that what a shorter line replaces is erased rather than left
  showing. `ClearLine` would be a second sequence per row and this is one. }
procedure PutRow(r: integer; s: ScreenRow; width: integer);
var out: IOLine; e2: ErrorCode;
begin
  while length(s) < width do s := s + ' ';
  out := CursorTo(r, 1) + s;
  e2 := WriteText(StdOut, out)
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
  for r := 1 to scr.rows do PutRow(r, scr.line[r], scr.cols);
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
var i: integer; ok: boolean; msg: EditLine;
begin
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
  e := NewArgs(v);
  if e = errNone then e := AddArg(v, Compiler);
  if e = errNone then e := AddArg(v, path);
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

var c: char; k: Key; e2: ErrorCode;
begin
  if argcount >= 1 then path := argument(1) else path := '';
  EditInit(ed);
  DecodeInit(dec);
  if path <> '' then Load
  else EditSay(ed, 'apide <file.pas>');

  { The terminal, and putting it back. `defer` is what makes the restore
    unconditional (AP 6.9.3.11): every way out of this block below -- the
    loop ending, a `halt`, a trap -- runs these, in the reverse of the order
    they were armed. Raw mode is restored by the runtime at exit as well
    (ADR-0262), and the alternate screen is not: nothing but this program
    knows it entered one. }
  e := EnterRaw(StdIn);
  if e <> errNone then begin
    e2 := WriteText(StdErr, 'apide: this is not a terminal' + chr(10));
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
      if k.kind = kkQuit then begin
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
        if k.kind = kkSave then Save
        else if k.kind = kkBuild then Build
        else EditKey(ed, k)
      end;
      if running then Draw
    end
  end;
  EditFree(ed)
end.
