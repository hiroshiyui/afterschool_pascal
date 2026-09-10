{ The editor, with no terminal in it.

  **This module is the whole of what the IDE decides**, and it decides it
  without reading a byte from a descriptor or writing one to it: a key comes
  in as a value, and what comes out is a *screen* -- rows by columns of
  characters, with the cursor's cell -- which the caller may put on a terminal
  or compare against a golden.

  That split is why the program is testable at all (ADR-0381). `ctest` has no
  terminal; a case that wanted one would need a pseudo-terminal binding, which
  ADR-0262 declined on the grounds that such a case becomes a test of the
  binding rather than of the program. Rendering to a buffer costs nothing and
  moves every decision this program makes to the side of the line a golden can
  reach: what is left outside is the shell, which reads `PasTerm.ReadKey` and
  writes `PasTerm.CursorTo`, and which `doc/sop.md` 7 says nothing checks.

  **The screen is the unit of comparison and not the buffer.** A test that
  asserted the buffer would pass on an editor that edits correctly and draws
  nothing; what a person notices is the drawing, so that is what a session
  diffs. The buffer is reached through the screen, which is the same
  arrangement `lsp/run.py` has with a document -- a conversation is compared,
  not an internal.

  **A key is decoded here too**, because which bytes mean which key is a
  question about a terminal and not about a descriptor: `PasTerm.ReadKey`
  answers one byte and says so, and an arrow arrives as three. The decoder is
  a state machine over bytes rather than a lookahead, since a program that is
  handed one byte at a time cannot look ahead.

  What is *not* here: display width, which AP 6.4.15 NOTE 14 leaves out of
  this language, so a column is a byte and a program drawing East Asian text
  will draw it wrongly and this says so; and any notion of the terminal's
  size changing, which is `SIGWINCH` and has no shape in this language --
  the caller passes the size it wants drawn on every render. }

module ApEdit;

export ApEdit = (ColsMax, RowsMax, LineMax, EditLine, ScreenRow, Screen,
                 KeyKind, kkNone, kkChar, kkEnter, kkBack, kkDelete,
                 kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
                 kkSave, kkQuit, kkBuild, kkUnknown,
                 kkUndo, kkRedo, kkFind, kkAgain, kkGoto, kkCancel,
                 Key, Decoder, Editor,
                 EditInit, EditFree, EditPush, EditKey, EditRender,
                 EditDirty, EditLines, EditLine_, EditRow, EditCol,
                 EditName, EditSetName, EditSay, EditSaved, EditFault,
                 EditPrompting, EditTakeSave,
                 DecodeInit, DecodeByte);

import PasError;
       PasStrVec;
       PasParse;

const
  { A screen wider or taller than this is drawn to these bounds and the rest
    of the terminal is left alone. 200x80 covers every terminal a person
    edits in; a fixed bound is what ADR-0012 asks for, and it is checked
    where the size arrives rather than trusted. }
  ColsMax = 400;
  RowsMax = 200;
  { A line longer than this cannot be held, which is `PasStrVec`'s own bound
    (`ItemMax`) and not a second one -- the buffer is a StrVec, so saying a
    larger number here would be saying it twice and wrongly. }
  LineMax = ItemMax;

type
  EditLine = StrItem;
  ScreenRow = string(ColsMax);

  { What the caller draws. `rows` and `cols` are what was asked for and are
    what a reader of a golden counts; `at` is the cell the cursor belongs in,
    in the same coordinates, so the shell writes one `CursorTo` and no
    arithmetic of its own. }
  Screen = record
    rows, cols: integer;
    line: array [1..RowsMax] of ScreenRow;
    atRow, atCol: integer
  end;

  { A key, after the bytes have been put back together. `kkUnknown` is an
    escape sequence this program does not know: it is reported rather than
    dropped, because a key that does nothing and a key that was misread look
    the same to a person and only one of them is a defect here. }
  KeyKind = (kkNone, kkChar, kkEnter, kkBack, kkDelete,
             kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
             kkSave, kkQuit, kkBuild, kkUnknown,
             kkUndo, kkRedo, kkFind, kkAgain, kkGoto, kkCancel);

  Key = record
    kind: KeyKind;
    ch: char            { only when kind = kkChar }
  end;

  { The state between bytes. A terminal sends `ESC [ A` for an up arrow and
    `ESC` alone for the escape key, and nothing but the next byte -- or its
    absence -- tells them apart; this program takes the first reading, which
    is every editor's, and leaves the second to a caller that wants a
    timeout. }
  Decoder = record
    n: integer;         { how many bytes of a sequence are in hand }
    b: array [1..8] of char
  end;

  { **What one edit was**, which is the whole of what undo and redo know.
    Four kinds is the complete set and that is a claim about the editor
    rather than a convenience: every change `EditKey` makes to a document is
    an insertion or a removal of text within one line, or the split of one
    line into two, or the join of two into one. A fifth kind would mean the
    editor had learned an operation the journal cannot describe -- which is
    the failure this shape makes impossible to introduce quietly, since the
    only routines that touch the buffer are the four below.

    `row` and `col` are where the edit happened and `text` is what went in or
    came out, so **one entry both reverses the edit and performs it again**:
    redo is not a second mechanism with a second set of bugs. `atRow`/`atCol`
    is where the cursor was *before* the edit, which is where undo puts it
    back -- a person undoing a typed word is looking at where they started
    typing it, not at where they stopped. }
  EditKind = (ekInsert, ekDelete, ekSplit, ekJoin);
  EditRecPtr = ^EditRec;
  EditRec = record
    kind: EditKind;
    row, col: integer;
    text: EditLine;
    atRow, atCol: integer;
    next: EditRecPtr
  end;

  { The editor is modal exactly while it is asking a question, and the two
    questions have one shape: a label, a line the person types, and an answer
    that moves the cursor. **Making it a mode of the model rather than a loop
    in the shell** is ADR-0381's rule met a second time -- a prompt a shell
    owned would be behaviour no session could drive and no golden could
    hold, and it is the half of an editor where a person is most likely to
    notice something wrong. }
  EditMode = (mdEdit, mdFind, mdGoto, mdSaveAs);

  { The document and where the caller is in it. `top` is the first line drawn,
    so scrolling is a property of the render and not of the cursor. }
  Editor = record
    lines: StrVecPtr;
    row, col: integer;  { 1-based, in the document }
    top: integer;
    dirty: boolean;
    name: EditLine;
    says: EditLine;     { the message line: what just happened }
    { The journal. `undos` is what has been done, newest first, and `redos`
      what has been undone; a fresh edit drops `redos` entirely, because a
      document that has changed since has no future left to return to.
      `open` says the newest entry is still taking characters, and it is the
      whole of what makes a typed run one undo instead of eight. }
    undos, redos: EditRecPtr;
    open: boolean;
    { What is being asked, what has been typed into the question, and the
      last thing searched for -- which outlives the prompt, Ctrl-L being a
      repeat of it. }
    mode: EditMode;
    prompt: EditLine;
    seek: EditLine;
    { A name was just given to a document that had none, and the write has not
      happened yet -- the shell's half, which this is how it hears about.
      Cleared by the asking, so it is a request and not a state. }
    wantSave: boolean
  end;

{ An editor holding one empty line, which is what an empty document is: a
  buffer with no lines has no cursor position, and every operation below
  would need an arm for it. }
procedure EditInit(var ed: Editor);

{ Give back the buffer. A second call is harmless. }
procedure EditFree(var ed: Editor);

{ Append a line, as loading a file does. It does not move the cursor and does
  not mark the document dirty -- what is loaded is what is on disc. }
procedure EditPush(var ed: Editor; s: EditLine);

{ Apply one key. Everything the editor *does* is here, so a session that
  feeds keys and renders exercises all of it. }
procedure EditKey(var ed: Editor; k: Key);

{ Draw. `rows` and `cols` are the terminal's, clamped to the bounds above;
  the last row is the status line and the one before it is what the editor
  has to say, so a document is drawn into `rows - 2`. }
procedure EditRender(var ed: Editor; rows, cols: integer; var scr: Screen);

{ Answers about the editor, so a caller need not reach into the record. }
function EditDirty(var ed: Editor): boolean;
function EditLines(var ed: Editor): integer;
function EditRow(var ed: Editor): integer;
function EditCol(var ed: Editor): integer;
function EditName(var ed: Editor): EditLine;
function EditLine_(var ed: Editor; n: integer): EditLine;

{ The document's name, and what the editor is saying. Both are the shell's to
  set -- it is the half that knows about files and about running a compiler. }
procedure EditSetName(var ed: Editor; s: EditLine);
procedure EditSay(var ed: Editor; s: EditLine);

{ What is on screen is what is on disc, so the status line stops saying
  otherwise. The shell calls it after a write that answered true, and only
  then: an editor that cleared the mark before knowing the write had happened
  would be lying at exactly the moment a person is deciding whether to quit. }
procedure EditSaved(var ed: Editor);

{ Land on the first diagnostic in `text`, which is a compiler's whole output.
  Answers false where there is none to land on.

  **This is here and not in the shell**, and that is the rule rather than a
  convenience: the shell is bytes in and bytes out, and *where the cursor goes
  when a compiler complains* is a decision -- so it belongs where a session
  can drive it and a golden can hold it. The shell would otherwise be the one
  place with behaviour nothing checks.

  The shape is `file:line:col: message`, which is every diagnostic this
  compiler writes and, since ADR-0293, every trap as well. A line that is not
  one is passed over rather than landing the cursor somewhere arbitrary. }
function EditFault(var ed: Editor; text: EditLine): boolean;

{ Is a question open? **The shell asks before it acts on anything of its
  own**: while the editor is asking something, Ctrl-S and Ctrl-B and Ctrl-Q
  belong to the answer and not to the file, and this is the only thing about
  a prompt the shell is told. }
function EditPrompting(var ed: Editor): boolean;

{ Did the person just name a document that had none? **Answers true once**,
  and clears -- it is a request the shell takes rather than a flag it reads,
  so a second key cannot save a second time. The shell writes the file and
  calls `EditSaved`; where the name came from is this side's business and the
  writing is that side's, which is the same line ADR-0381 drew for the
  screen. }
function EditTakeSave(var ed: Editor): boolean;

{ No bytes in hand. }
procedure DecodeInit(var d: Decoder);

{ Offer one byte. Answers true when `k` is a key, and false when more bytes
  are needed -- which is the whole of the interface, because a caller reading
  one byte at a time cannot be asked anything else. }
function DecodeByte(var d: Decoder; c: char; var k: Key): boolean;

end;

const
  Esc = 27;

procedure EditInit;
begin
  SVecNew(ed.lines, 64);
  SVecPush(ed.lines, '');
  ed.row := 1;
  ed.col := 1;
  ed.top := 1;
  ed.dirty := false;
  ed.name := '';
  ed.says := '';
  ed.undos := nil;
  ed.redos := nil;
  ed.open := false;
  ed.mode := mdEdit;
  ed.prompt := '';
  ed.seek := '';
  ed.wantSave := false
end;

{ Give a journal back. Written once and called three times -- freeing the
  editor, and dropping the redo stack whenever a fresh edit makes it
  unreachable, which is the moment those records stop being anything. }
procedure Drop(var p: EditRecPtr);
var q: EditRecPtr;
begin
  while p <> nil do begin
    q := p^.next;
    dispose(p);
    p := q
  end
end;

procedure EditFree;
begin
  SVecFree(ed.lines);
  Drop(ed.undos);
  Drop(ed.redos)
end;

function EditPrompting;
begin
  EditPrompting := ed.mode <> mdEdit
end;

function EditTakeSave;
begin
  EditTakeSave := ed.wantSave;
  ed.wantSave := false
end;

procedure EditPush;
begin
  { The line an empty editor starts with is not a line of the document: the
    first push replaces it rather than sitting under it, or every loaded file
    would gain a blank first line. }
  if (SVecLen(ed.lines) = 1) and (SVecGet(ed.lines, 1) = '') then
    SVecSet(ed.lines, 1, s)
  else
    SVecPush(ed.lines, s)
end;

function EditDirty;
begin
  EditDirty := ed.dirty
end;

function EditLines;
begin
  EditLines := SVecLen(ed.lines)
end;

function EditRow;
begin
  EditRow := ed.row
end;

function EditCol;
begin
  EditCol := ed.col
end;

function EditName;
begin
  EditName := ed.name
end;

function EditLine_;
begin
  if (n < 1) or (n > SVecLen(ed.lines)) then EditLine_ := ''
  else EditLine_ := SVecGet(ed.lines, n)
end;

procedure EditSetName;
begin
  ed.name := s
end;

procedure EditSay;
begin
  ed.says := s
end;

procedure EditSaved;
begin
  ed.dirty := false
end;

{ The first `n` characters, and everything from the `i`th. Both answer the
  null-string where the standard's substring would not exist at all: 6.5.6
  requires an index and a length that name characters the value has, and
  every editing operation below is naturally written with an empty half at
  one end or the other. Writing the guard once here is what keeps `EditKey`
  readable, and it is the same reason `PasText` has `TrimStart`. }
function Left(s: EditLine; n: integer): EditLine;
begin
  if n <= 0 then Left := ''
  else if n >= length(s) then Left := s
  else Left := substr(s, 1, n)
end;

function From(s: EditLine; i: integer): EditLine;
begin
  if i <= 1 then From := s
  else if i > length(s) then From := ''
  else From := substr(s, i, length(s) - i + 1)
end;

{ Put the cursor somewhere that exists. Called after every movement rather
  than at each site, because the six ways to move share one rule -- a column
  is 1..length+1, the last being the position after the final character where
  typing appends. }
procedure Clamp(var ed: Editor);
var n: integer;
begin
  if ed.row < 1 then ed.row := 1;
  if ed.row > SVecLen(ed.lines) then ed.row := SVecLen(ed.lines);
  n := length(SVecGet(ed.lines, ed.row));
  if ed.col < 1 then ed.col := 1;
  if ed.col > n + 1 then ed.col := n + 1
end;

{ A jump, and it is `MoveTo` because `GoTo` folds to a word-symbol -- every
  one of the 45 is reserved (6.1.2). Declared here because the search and the
  go-to-line prompt land the cursor with it and both are written above the
  key handler it is built out of. }
procedure MoveTo(var ed: Editor; ln, cl: integer); forward;

{ **The four things that can happen to a document, with no journal in them.**
  Every editing arm below is one of these and one `Note`, and that is what
  makes the journal complete by construction instead of by inspection: an arm
  that reached into the buffer itself would be an edit undo could not
  reverse, and after this there is no longer a way to write one by accident.
  These are the routines the four `EditKind`s name, one for one. }
procedure DoInsert(var ed: Editor; row, col: integer; s: EditLine);
var cur: EditLine;
begin
  cur := SVecGet(ed.lines, row);
  SVecSet(ed.lines, row, Left(cur, col - 1) + s + From(cur, col))
end;

procedure DoRemove(var ed: Editor; row, col, n: integer);
var cur: EditLine;
begin
  cur := SVecGet(ed.lines, row);
  SVecSet(ed.lines, row, Left(cur, col - 1) + From(cur, col + n))
end;

procedure DoSplit(var ed: Editor; row, col: integer);
var cur, rest: EditLine; i: integer;
begin
  cur := SVecGet(ed.lines, row);
  rest := From(cur, col);
  SVecSet(ed.lines, row, Left(cur, col - 1));
  { `PasStrVec` has no insert, so the lines below move down by one and the
    hole is written into -- what a vector costs, and invisible at the sizes a
    person edits at. }
  SVecPush(ed.lines, '');
  for i := SVecLen(ed.lines) - 1 downto row + 1 do
    SVecSet(ed.lines, i + 1, SVecGet(ed.lines, i));
  SVecSet(ed.lines, row + 1, rest)
end;

procedure DoJoin(var ed: Editor; row: integer);
var i: integer; gone: EditLine;
begin
  SVecSet(ed.lines, row, SVecGet(ed.lines, row) + SVecGet(ed.lines, row + 1));
  for i := row + 1 to SVecLen(ed.lines) - 1 do
    SVecSet(ed.lines, i, SVecGet(ed.lines, i + 1));
  { The vector is one shorter, and what came off it is already in the line
    above. `PasStrVec` has no drop, so the value is taken and let go. }
  gone := SVecPop(ed.lines)
end;

{ Put an edit in the journal, joining it to the newest entry where it
  *continues* one.

  **What may coalesce is exactly a run a person would call one action**:
  characters typed left to right, backspaces taken right to left, and forward
  deletes taken in place. A split or a join never joins a group, because
  undoing half a line's worth of typing together with a structural change is
  not an action anybody performed. The three conditions are written out
  rather than folded together: they are three different arithmetics on the
  same two numbers, and reading `col` as one of them where another was meant
  is the defect this shape is most likely to have. }
procedure Note(var ed: Editor; kind: EditKind; row, col: integer; s: EditLine);
var e: EditRecPtr;
begin
  { A new edit is a new present, so what had been undone can no longer be
    returned to. That is every editor's rule, and it is why redo is a stack
    that gets emptied rather than a second journal that has to be kept
    consistent with this one. }
  Drop(ed.redos);
  if ed.open and (ed.undos <> nil) and (ed.undos^.kind = kind) and
     (ed.undos^.row = row) then begin
    if (kind = ekInsert) and (ed.undos^.col + length(ed.undos^.text) = col) then begin
      ed.undos^.text := ed.undos^.text + s;
      exit
    end
    else if (kind = ekDelete) and (ed.undos^.col = col + length(s)) then begin
      { Backspace: the run grows leftwards, so the entry's column follows it
        and the text goes on the front. }
      ed.undos^.text := s + ed.undos^.text;
      ed.undos^.col := col;
      exit
    end
    else if (kind = ekDelete) and (ed.undos^.col = col) then begin
      { Delete: the run grows rightwards and the column stays where it is. }
      ed.undos^.text := ed.undos^.text + s;
      exit
    end
  end;
  new(e);
  e^.kind := kind;
  e^.row := row;
  e^.col := col;
  e^.text := s;
  { Called before the arm moves the cursor, so this is where the person was.
    Getting that order wrong puts the cursor one keystroke ahead on every
    undo, which is the kind of wrongness a golden shows and a reading does
    not. }
  e^.atRow := ed.row;
  e^.atCol := ed.col;
  e^.next := ed.undos;
  ed.undos := e;
  ed.open := true
end;

{ Undo one entry: perform its opposite, move it to the redo stack, and put
  the cursor back where the person was before it. }
procedure Undo(var ed: Editor);
var e: EditRecPtr;
begin
  if ed.undos = nil then begin
    ed.says := 'nothing to undo';
    exit
  end;
  e := ed.undos;
  ed.undos := e^.next;
  case e^.kind of
    ekInsert: DoRemove(ed, e^.row, e^.col, length(e^.text));
    ekDelete: DoInsert(ed, e^.row, e^.col, e^.text);
    ekSplit: DoJoin(ed, e^.row);
    ekJoin: DoSplit(ed, e^.row, e^.col)
  end;
  ed.row := e^.atRow;
  ed.col := e^.atCol;
  e^.next := ed.redos;
  ed.redos := e;
  { **Undoing back to what was on disc still counts as a change**, and that
    is deliberate: this editor does not track which entry the last save was
    at, so it says the document differs rather than claiming it does not. The
    honest direction to be wrong in is the one that offers to save. }
  ed.dirty := true
end;

{ ...and redo performs the same entry again. There is one description of an
  edit here and not two, which is the reason this is eight lines. }
procedure Redo(var ed: Editor);
var e: EditRecPtr;
begin
  if ed.redos = nil then begin
    ed.says := 'nothing to redo';
    exit
  end;
  e := ed.redos;
  ed.redos := e^.next;
  ed.row := e^.row;
  ed.col := e^.col;
  case e^.kind of
    ekInsert: begin
      DoInsert(ed, e^.row, e^.col, e^.text);
      ed.col := e^.col + length(e^.text)
    end;
    ekDelete: DoRemove(ed, e^.row, e^.col, length(e^.text));
    ekSplit: begin
      DoSplit(ed, e^.row, e^.col);
      ed.row := e^.row + 1;
      ed.col := 1
    end;
    ekJoin: DoJoin(ed, e^.row)
  end;
  e^.next := ed.undos;
  ed.undos := e;
  ed.dirty := true
end;

{ Case-insensitive, and that is the one thing this editor knows about the
  language it edits: 6.1.3 folds every letter of an identifier, so a person
  searching for `writeln` means `WriteLn` as well and would call it a defect
  if they did not get it. The fold is ASCII's because a column here is a byte
  (AP 6.4.15 NOTE 14 puts display width outside this language), so a
  non-ASCII letter is compared as the bytes it is written in. }
function Fold(s: EditLine): EditLine;
var i: integer; r: EditLine;
begin
  r := '';
  for i := 1 to length(s) do
    if (s[i] >= 'A') and (s[i] <= 'Z') then
      r := r + chr(ord(s[i]) + 32)
    else
      r := r + s[i];
  Fold := r
end;

{ The first index at or after `from` at which `pat` occurs in `s`, or 0.
  Both are already folded by the caller: folding here would fold the needle
  once per line. }
function IndexFrom(s, pat: EditLine; from: integer): integer;
var i, j: integer; ok: boolean;
begin
  IndexFrom := 0;
  if pat = '' then exit;
  if from < 1 then from := 1;
  for i := from to length(s) - length(pat) + 1 do begin
    ok := true;
    for j := 1 to length(pat) do
      if s[i + j - 1] <> pat[j] then ok := false;
    if ok then begin
      IndexFrom := i;
      exit
    end
  end
end;

{ Where `pat` next occurs at or after (row, col), wrapping round the end of
  the document. `wrapped` is answered separately because a person who is not
  told has no way to tell the second match from the first one again -- which
  is the one thing about a search that is genuinely confusing when it is
  missing.

  The loop runs to `n` inclusive and so examines the starting line twice: once
  from `col` and once, after the wrap, from its beginning. That is what makes
  a match *earlier on the same line* findable, and it is the off-by-one this
  routine exists to get right once. }
function Seek(var ed: Editor; pat: EditLine; row, col: integer;
              var fr, fc: integer; var wrapped: boolean): boolean;
var n, i, r, start, at: integer; needle: EditLine;
begin
  Seek := false;
  wrapped := false;
  fr := row;
  fc := col;
  if pat = '' then exit;
  needle := Fold(pat);
  n := SVecLen(ed.lines);
  for i := 0 to n do begin
    r := row + i;
    if r > n then begin
      r := r - n;
      wrapped := true
    end;
    if i = 0 then start := col else start := 1;
    at := IndexFrom(Fold(SVecGet(ed.lines, r)), needle, start);
    if at > 0 then begin
      fr := r;
      fc := at;
      Seek := true;
      exit
    end
  end
end;

{ Search for what was last asked for. `again` is Ctrl-L, which starts one
  character further on so that a repeat advances instead of finding the match
  it is already sitting on. }
procedure FindFrom(var ed: Editor; again: boolean);
var fr, fc, from: integer; wrapped: boolean; msg: EditLine;
begin
  if ed.seek = '' then begin
    ed.says := 'nothing to find again';
    exit
  end;
  if again then from := ed.col + 1 else from := ed.col;
  if Seek(ed, ed.seek, ed.row, from, fr, fc, wrapped) then begin
    MoveTo(ed, fr, fc);
    if wrapped then ed.says := 'search wrapped'
  end
  else begin
    { The cursor stays where it was. An editor that moved it on a failed
      search would have lost the person's place to tell them nothing. }
    writestr(msg, 'not found: ', ed.seek);
    ed.says := msg
  end
end;

{ A key while a question is open. **The question owns every one of them**: a
  person typing an answer has not asked for anything else to happen, which is
  what `EditPrompting` tells the shell and why Ctrl-S does not save from
  inside a search. }
procedure PromptKey(var ed: Editor; k: Key);
var r: IntResult; msg: EditLine;
begin
  if k.kind = kkChar then begin
    if length(ed.prompt) < LineMax then ed.prompt := ed.prompt + k.ch
  end
  else if k.kind = kkBack then
    ed.prompt := Left(ed.prompt, length(ed.prompt) - 1)
  else if k.kind = kkCancel then begin
    { **Escape would be the Turbo Pascal key and it cannot be used**, which is
      a fact about this decoder rather than a preference: `DecodeByte` is
      handed one byte at a time and an arrow is `ESC [ A`, so a bare Escape
      and the start of an arrow are the same byte and only a timeout tells
      them apart. The decoder's own comment takes the first reading; this is
      the first place that costs anything, and Ctrl-C is what it costs. }
    ed.mode := mdEdit;
    ed.says := 'cancelled'
  end
  else if k.kind = kkEnter then begin
    case ed.mode of
      mdFind: begin
        ed.mode := mdEdit;
        ed.seek := ed.prompt;
        FindFrom(ed, false)
      end;
      { **A name is not judged here**, and that is the division of labour:
        whether a path can be written is something only the write finds out,
        and this side has no file in it at all. An empty answer is the one
        thing it can judge, since it would name nothing. }
      mdSaveAs: begin
        ed.mode := mdEdit;
        if ed.prompt = '' then
          ed.says := 'a document needs a name to be saved'
        else begin
          ed.name := ed.prompt;
          ed.wantSave := true
        end
      end;
      mdGoto: begin
        ed.mode := mdEdit;
        r := ParseInt(ed.prompt);
        if r.ok then
          { Past the end lands on the last line rather than nowhere --
            `Clamp`'s rule, which the arrows already had. }
          MoveTo(ed, r.val, 1)
        else begin
          writestr(msg, 'not a line number: ', ed.prompt);
          ed.says := msg
        end
      end;
      { Unreachable -- `EditKey` sends nothing here in edit mode -- and named
        anyway, an if-chain over an enumeration being the shape ADR-0145 is
        about. }
      mdEdit: ;
    end
  end
end;

procedure EditKey;
var cur, rest, one: EditLine; k2: integer; keep: boolean;
begin
  { **The message is about the last key**, so it is cleared here and set by
    whichever arm has something to say. The alternative -- leaving it until
    something replaces it -- was tried first and the session golden showed
    what is wrong with it: `unknown key` stayed on the screen while the person
    typed, describing a key two keystrokes ago. It also gives the shell the
    behaviour it wants for free: `saved` stands until the next key touches
    the document, which is exactly how long it is true. }
  ed.says := '';

  { A question owns the keyboard while it is open, and nothing below runs. }
  if ed.mode <> mdEdit then begin
    PromptKey(ed, k);
    exit
  end;

  { **Every key that is not more of the same run closes the group.** The
    default is to close and an arm that wants to go on coalescing says so by
    handing `keep` back, which is the safe direction to be wrong in: forget
    it and an undo comes out smaller than the person expected, which they can
    see and repeat; the other way round gives them one that swallows an
    action they never performed, which they cannot get back. }
  keep := ed.open;
  ed.open := false;

  cur := SVecGet(ed.lines, ed.row);
  case k.kind of
    kkChar: begin
      { A line that is full swallows the key rather than losing its tail:
        `StrItem` is a fixed capacity and 6.4.6's assignment would truncate,
        which loses a character the person can see nothing of. Saying so is
        the message line's job. }
      if length(cur) >= LineMax then
        ed.says := 'line is full'
      else begin
        one := '';
        one := one + k.ch;
        ed.open := keep;
        Note(ed, ekInsert, ed.row, ed.col, one);
        DoInsert(ed, ed.row, ed.col, one);
        ed.col := ed.col + 1;
        ed.dirty := true
      end
    end;
    kkEnter: begin
      { Split: the tail moves to a new line after this one. It never joins a
        group, so the `keep` above is deliberately not handed back. }
      Note(ed, ekSplit, ed.row, ed.col, '');
      DoSplit(ed, ed.row, ed.col);
      ed.row := ed.row + 1;
      ed.col := 1;
      ed.dirty := true
    end;
    kkBack: begin
      if ed.col > 1 then begin
        ed.open := keep;
        Note(ed, ekDelete, ed.row, ed.col - 1, substr(cur, ed.col - 1, 1));
        DoRemove(ed, ed.row, ed.col - 1, 1);
        ed.col := ed.col - 1;
        ed.dirty := true
      end
      else if ed.row > 1 then begin
        { Join with the line above, and the cursor lands where the join is
          rather than at either end -- which is where the person was
          looking. That column is also what undoes it: a join is reversed by
          splitting at the point the two lines met. }
        rest := SVecGet(ed.lines, ed.row - 1);
        k2 := length(rest) + 1;
        Note(ed, ekJoin, ed.row - 1, k2, '');
        DoJoin(ed, ed.row - 1);
        ed.row := ed.row - 1;
        ed.col := k2;
        ed.dirty := true
      end
    end;
    kkDelete: begin
      if ed.col <= length(cur) then begin
        ed.open := keep;
        Note(ed, ekDelete, ed.row, ed.col, substr(cur, ed.col, 1));
        DoRemove(ed, ed.row, ed.col, 1);
        ed.dirty := true
      end
      else if ed.row < SVecLen(ed.lines) then begin
        { At the end of a line, Delete is the same join Backspace makes from
          the other side -- and `Clamp` has already made `ed.col` exactly
          `length(cur) + 1`, which is where the two lines meet. }
        Note(ed, ekJoin, ed.row, ed.col, '');
        DoJoin(ed, ed.row);
        ed.dirty := true
      end
    end;
    kkLeft: begin
      if ed.col > 1 then ed.col := ed.col - 1
      else if ed.row > 1 then begin
        ed.row := ed.row - 1;
        ed.col := length(SVecGet(ed.lines, ed.row)) + 1
      end
    end;
    kkRight: begin
      if ed.col <= length(cur) then ed.col := ed.col + 1
      else if ed.row < SVecLen(ed.lines) then begin
        ed.row := ed.row + 1;
        ed.col := 1
      end
    end;
    kkUp: ed.row := ed.row - 1;
    kkDown: ed.row := ed.row + 1;
    kkHome: ed.col := 1;
    kkEnd: ed.col := length(cur) + 1;
    { **The shell acts on these and the model does not**, which is what keeps
      the model free of files and processes: saving is a write and building
      is a `PasProcess.Execute`, and neither is a decision about a document.
      They are still `Key` values because they arrive as bytes among the
      others and the decoder is the one place that knows which. }
    kkUndo: Undo(ed);
    kkRedo: Redo(ed);
    { A prompt starts empty rather than holding the last search: a person who
      wants that presses Ctrl-L, and one who does not would have to clear it
      every time. }
    kkFind: begin
      ed.mode := mdFind;
      ed.prompt := ''
    end;
    kkAgain: FindFrom(ed, true);
    kkGoto: begin
      ed.mode := mdGoto;
      ed.prompt := ''
    end;
    { Nothing is open, so there is nothing to cancel -- said rather than
      ignored, for `kkUnknown`'s reason. }
    kkCancel: ed.says := 'nothing to cancel';
    { **Ctrl-S is the shell's, except when there is no name to save under.**
      Which key writes a file is the shell's business and stays there; *a
      document with no name cannot be written and has to be asked about* is a
      decision about the document, so it is here, where a session drives it
      and a golden holds it. Starting fileless is the ordinary way to write a
      new program since the editor became `afterschool`, so this is the path
      most people meet first. }
    kkSave: if ed.name = '' then begin
      ed.mode := mdSaveAs;
      ed.prompt := ''
    end;
    kkQuit, kkBuild: ;
    { A sequence nothing here knows. Reported **with the byte in it**,
      because a key that does nothing and a key that was misread look alike
      to a person -- and because the first thing anybody asks is *which*
      key. It earned that on its first run under a real terminal: Ctrl-Q
      arrived as something else, and a message saying only `unknown key`
      could not say what. }
    kkUnknown: begin
      writestr(rest, 'unknown key ', ord(k.ch):1);
      ed.says := rest
    end;
    kkNone: ;
  end;
  Clamp(ed)
end;

procedure EditRender;
var r, h, n, wide, pcol: integer; s: EditLine; row: ScreenRow; num: EditLine;
begin
  { The size the caller asked for, held to what this can draw. Three rows is
    the least that has a document in it, the last two being the message and
    the status. }
  if rows > RowsMax then rows := RowsMax;
  if rows < 3 then rows := 3;
  if cols > ColsMax then cols := ColsMax;
  if cols < 8 then cols := 8;
  scr.rows := rows;
  scr.cols := cols;
  h := rows - 2;

  { Scroll so the cursor is on screen. This is why the editor is a `var`
    parameter of a routine that only draws: where the window sits is a
    property of the last drawing and not of the document, and keeping it
    anywhere else would mean the caller had to know the height. }
  if ed.row < ed.top then ed.top := ed.row;
  if ed.row > ed.top + h - 1 then ed.top := ed.row - h + 1;
  if ed.top < 1 then ed.top := 1;

  for r := 1 to h do begin
    n := ed.top + r - 1;
    if n > SVecLen(ed.lines) then s := '~'
    else s := SVecGet(ed.lines, n);
    { No horizontal scrolling: a line wider than the window is cut, and the
      cursor stops at the last column rather than following the text off the
      edge. It is a milestone-one limitation and a person meets it on a long
      line, so the *cursor* is what says so rather than a message. }
    scr.line[r] := Left(s, cols)
  end;

  { The message line, or the question when one is open. **The cursor goes
    into the question**, because a person typing an answer has to see where
    it is going -- and that is the only thing on this screen that is not
    where the document says it is. }
  pcol := 0;
  if ed.mode = mdEdit then
    scr.line[rows - 1] := Left(ed.says, cols)
  else begin
    if ed.mode = mdFind then s := 'Find: '
    else if ed.mode = mdSaveAs then s := 'Save as: '
    else s := 'Line: ';
    s := s + ed.prompt;
    scr.line[rows - 1] := Left(s, cols);
    pcol := length(s) + 1
  end;

  { The status line, and it is the same shape a Turbo Pascal one was: what is
    being edited, whether it has been changed, and where the cursor is. }
  s := ed.name;
  if s = '' then s := '(no name)';
  if ed.dirty then s := s + ' *';
  writestr(num, ed.row:1, ':', ed.col:1);
  wide := cols - length(num);
  if wide < 1 then wide := 1;
  row := Left(s, wide);
  while length(row) < wide do row := row + ' ';
  scr.line[rows] := Left(row + num, cols);

  if pcol > 0 then begin
    scr.atRow := rows - 1;
    scr.atCol := pcol
  end
  else begin
    scr.atRow := ed.row - ed.top + 1;
    scr.atCol := ed.col
  end;
  if scr.atCol > cols then scr.atCol := cols
end;

{ Move to a position, through the keys rather than by writing the fields -- and
  it is `MoveTo` because `GoTo` folds to a word-symbol, every one of the 45
  being reserved (6.1.2). A
  jump is then the same thing as a person arriving with the arrows -- the
  clamping is `Clamp`'s, once, and a line number past the end of the document
  lands on the last line instead of nowhere. }
procedure MoveTo;
var k: Key;
begin
  k.ch := ' ';
  k.kind := kkUp;
  while ed.row > ln do EditKey(ed, k);
  k.kind := kkDown;
  while (ed.row < ln) and (ed.row < SVecLen(ed.lines)) do EditKey(ed, k);
  k.kind := kkHome;
  EditKey(ed, k);
  k.kind := kkRight;
  while (ed.col < cl) and (ed.col <= length(SVecGet(ed.lines, ed.row))) do
    EditKey(ed, k)
end;

function EditFault;
var i, start, field, ln, cl: integer; part: EditLine; r: IntResult;
begin
  EditFault := false;
  start := 1;
  field := 0;
  ln := 0;
  cl := 0;
  for i := 1 to length(text) do
    if text[i] = chr(10) then
      { One line at a time, and the *first* that is a diagnostic wins: a
        compiler reports many and a person works on one. }
      exit
    else if (text[i] = ':') and (field < 3) then begin
      part := substr(text, start, i - start);
      start := i + 1;
      field := field + 1;
      if field = 2 then begin
        r := ParseInt(part);
        if not r.ok then exit;
        ln := r.val
      end
      else if field = 3 then begin
        r := ParseInt(part);
        if not r.ok then exit;
        cl := r.val;
        MoveTo(ed, ln, cl);
        ed.says := From(text, start + 1);
        EditFault := true;
        exit
      end
    end
end;

procedure DecodeInit;
begin
  d.n := 0
end;

function DecodeByte;
var b: integer;
begin
  DecodeByte := false;
  k.kind := kkNone;
  k.ch := ' ';
  b := ord(c);

  { Inside a sequence: `ESC [` and then one byte says which key, or a digit
    and a `~`. Anything else ends the sequence as `kkUnknown` -- the state is
    dropped rather than kept, because a decoder that waits for a byte that
    never comes stops the editor. }
  if d.n > 0 then begin
    d.n := d.n + 1;
    if d.n > 8 then begin
      d.n := 0;
      k.kind := kkUnknown;
      k.ch := c;
      DecodeByte := true
    end
    else if (d.n = 2) and (c <> '[') then begin
      d.n := 0;
      k.kind := kkUnknown;
      k.ch := c;
      DecodeByte := true
    end
    else if d.n >= 3 then begin
      DecodeByte := true;
      d.n := 0;
      if c = 'A' then k.kind := kkUp
      else if c = 'B' then k.kind := kkDown
      else if c = 'C' then k.kind := kkRight
      else if c = 'D' then k.kind := kkLeft
      else if c = 'H' then k.kind := kkHome
      else if c = 'F' then k.kind := kkEnd
      else if (c >= '0') and (c <= '9') then begin
        { A parameter is still coming: `ESC [ 3 ~` is Delete. Stay in the
          sequence. }
        d.n := 3;
        d.b[3] := c;
        DecodeByte := false
      end
      else if c = '~' then begin
        if d.b[3] = '3' then k.kind := kkDelete
        else if d.b[3] = '1' then k.kind := kkHome
        else if d.b[3] = '4' then k.kind := kkEnd
        else begin
          k.kind := kkUnknown;
          k.ch := d.b[3]
        end
      end
      else begin
        k.kind := kkUnknown;
        k.ch := c
      end
    end
  end
  else if b = Esc then begin
    d.n := 1;
    d.b[1] := c
  end
  else begin
    DecodeByte := true;
    { The control keys this editor binds. Ctrl-letter is the letter's ordinal
      less 64, which is how a terminal has sent it since ASCII, and the three
      chosen are the three a Turbo Pascal user reaches for: save, quit, and
      build. }
    if b = 19 then k.kind := kkSave           { Ctrl-S }
    else if b = 17 then k.kind := kkQuit      { Ctrl-Q }
    else if b = 2 then k.kind := kkBuild      { Ctrl-B }
    { The six milestone two adds, and each is the letter a Turbo Pascal user
      reaches for: undo and redo, find and find-again, go to a line, and the
      one that closes a question -- which is Ctrl-C and not Escape, for the
      reason `PromptKey` gives. }
    else if b = 26 then k.kind := kkUndo      { Ctrl-Z }
    else if b = 25 then k.kind := kkRedo      { Ctrl-Y }
    else if b = 6 then k.kind := kkFind       { Ctrl-F }
    else if b = 12 then k.kind := kkAgain     { Ctrl-L }
    else if b = 7 then k.kind := kkGoto       { Ctrl-G }
    else if b = 3 then k.kind := kkCancel     { Ctrl-C }
    else if (b = 13) or (b = 10) then k.kind := kkEnter
    else if (b = 8) or (b = 127) then k.kind := kkBack
    else if b < 32 then begin
      k.kind := kkUnknown;
      k.ch := c
    end
    else begin
      k.kind := kkChar;
      k.ch := c
    end
  end
end;

end.
