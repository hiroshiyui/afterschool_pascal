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
                 CellRole, crText, crStatus, crHint, crMessage, crPrompt,
                 crFrame, crMenu, crChosen, ScreenRoles,
                 CellMax, ScreenCell, ScreenCells,
                 KeyKind, kkNone, kkChar, kkEnter, kkBack, kkDelete,
                 kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
                 kkSave, kkQuit, kkBuild, kkUnknown,
                 kkUndo, kkRedo, kkFind, kkAgain, kkReplace, kkGoto, kkCancel,
                 kkFunc, kkMenu,
                 kkOpen, kkNextDoc,
                 Key, Decoder, Editor,
                 EditInit, EditFree, EditPush, EditKey, EditRender,
                 EditDirty, EditLines, EditLine_, EditRow, EditCol,
                 EditName, EditSetName, EditSay, EditSaved, EditFault,
                 EditModal, EditTakeCommand, RowRuns, RowRun,
                 Document, DocMax, EditWhich, EditCount, EditFind,
                 EditGo, EditAdd, EditDirtyCount,
                 DecodeInit, DecodeByte);

import PasError;
       PasStrVec;
       PasParse;
       { **`only`, because this module has a `Fold` of its own** (6.11.2).
         `PasUnicode.Fold` is case folding and this one folds a line for a
         caseless search; 6.11.2 puts every imported name in one scope, so one
         of the two has to give way, and naming what is wanted is better than
         renaming a routine to avoid a name it does not use. }
       PasUnicode only (Scalar, NextScalar, ElementEnd, Columns);

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
  { **How many documents may be open at once** (ADR-0396). A bound in
    ADR-0012's sense: eight is more than a person tracks by name on one status
    line, and the compiler this editor was written for is three
    program-components, so a diagnostic naming one that is not on screen is
    the case it has to cover. }
  DocMax = 8;
  { The bytes one *display column* of drawing may hold. A bound in ADR-0012's
    sense rather than a guess, and since ADR-0395 it has to hold a whole
    **element** and not a box character: a base with three combining marks is
    seven bytes, which is what sixteen is sized for.

    An element longer than this is drawn as the longest run of **whole
    scalars** that fits, so what a cell holds is always a text value -- a cut
    in the middle of a UTF-8 sequence would put bytes on the terminal that are
    not a character at all. An emoji joined out of three people is eighteen
    bytes and comes out as the first of them, which is a visible degradation
    and not a wrong screen. `wide.keys` records it. }
  CellMax = 16;

type
  EditLine = StrItem;
  { **A cell is what a terminal renders in one column**, and it holds the
    *bytes* of that column rather than a byte (ADR-0391). That is the whole of
    what Unicode frames needed: `'┌'` is three bytes and one column, so a row
    indexed by byte could not hold a frame and keep `role[r][c]` pointing at
    what a person sees. Eight is generous for one column and is a bound in
    ADR-0012's sense rather than a guess.

    **An empty cell means the column to its left is two wide** and this is its
    continuation. Nothing in this increment produces one -- a box character is
    one column and the document is read a byte at a time -- but the convention
    is fixed now so that East Asian text does not reshape the type later. }
  ScreenCell = string(CellMax);
  ScreenCells = array [1..ColsMax] of ScreenCell;

  { Still used for assembling a line of *output*, which is bytes. }
  ScreenRow = string(ColsMax);

  { **What a cell is for, which is not what colour it is** (ADR-0389). The
    model names a role and the shell owns the palette, so `ApEdit` still names
    no terminal capability -- it has no terminal in it and now no vocabulary
    from one either -- and a golden holds `sssss` under the status line rather
    than a row of SGR numbers nobody reads. Changing what colour a role is
    touches neither this file nor any recorded screen.

    `crText` is the document and is what a cell is unless something says
    otherwise, which is why it is first. }
  CellRole = (crText, crStatus, crHint, crMessage, crPrompt,
              crFrame, crMenu, crChosen);
  ScreenRoles = array [1..ColsMax] of CellRole;

  { What the caller draws. `rows` and `cols` are what was asked for and are
    what a reader of a golden counts; `at` is the cell the cursor belongs in,
    in the same coordinates, so the shell writes one `CursorTo` and no
    arithmetic of its own. }
  Screen = record
    rows, cols: integer;
    cell: array [1..RowsMax] of ScreenCells;
    { One role per cell, in the same coordinates as `line`. A plane beside the
      characters rather than a record per cell: a `ScreenRow` is a string and
      the whole program is written to treat it as one, and a cell record would
      have made every row a construction. }
    role: array [1..RowsMax] of ScreenRoles;
    atRow, atCol: integer
  end;

  { A key, after the bytes have been put back together. `kkUnknown` is an
    escape sequence this program does not know: it is reported rather than
    dropped, because a key that does nothing and a key that was misread look
    the same to a person and only one of them is a defect here. }
  KeyKind = (kkNone, kkChar, kkEnter, kkBack, kkDelete,
             kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
             kkSave, kkQuit, kkBuild, kkUnknown,
             kkUndo, kkRedo, kkFind, kkAgain, kkReplace, kkGoto, kkCancel,
             kkFunc, kkMenu,
             { **Open a file, and go to the next one open** (ADR-0396). F3
               and F6 are Turbo Pascal's positions, and `tui/README.md` had
               promised F3 would be Open `when there is something for it to
               open` -- which there now is. }
             kkOpen, kkNextDoc);

  Key = record
    kind: KeyKind;
    ch: char;           { only when kind = kkChar }
    { Only when kind = kkFunc. **The function keys are a family and not
      eleven kinds**: a terminal spells them with one number in one sequence,
      and an editor binds them from a table, so the number travels with the
      key rather than being spelled out as a constant apiece. The two that
      *are* bound arrive as `kkSave` and `kkBuild` -- see `DecodeByte`. }
    num: integer
  end;

  { The state between bytes. A terminal sends `ESC [ A` for an up arrow and
    `ESC` alone for the escape key, and nothing but the next byte -- or its
    absence -- tells them apart; this program takes the first reading, which
    is every editor's, and leaves the second to a caller that wants a
    timeout. }
  Decoder = record
    n: integer;         { how many bytes of a sequence are in hand }
    b: array [1..8] of char;
    { The digits between the introducer and the final byte. It has to be
      *accumulated* rather than kept as the last one seen: `ESC [ 3 ~` is
      Delete with one digit and `ESC [ 2 0 ~` is F9 with two, and a decoder
      that overwrote would read F9 as an unknown `0`. }
    par: string(4)
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
    { **Undo continues through me** (ADR-0403). One action of a person's may
      be more than one of the four operations -- replacing a word is a remove
      and an insert, and replacing every word is a great many -- and an undo
      that reversed half of one is not an undo of anything anybody did. It is
      a property of an *entry* and not a fifth operation: what touches the
      buffer is still the four routines, which is the whole of ADR-0387's
      claim. False on every entry a keystroke makes. }
    more: boolean;
    next: EditRecPtr
  end;

  { The editor is modal exactly while it is asking a question, and the two
    questions have one shape: a label, a line the person types, and an answer
    that moves the cursor. **Making it a mode of the model rather than a loop
    in the shell** is ADR-0381's rule met a second time -- a prompt a shell
    owned would be behaviour no session could drive and no golden could
    hold, and it is the half of an editor where a person is most likely to
    notice something wrong. }
  EditMode = (mdEdit, mdFind, mdGoto, mdSaveAs, mdOpen, mdMenu,
              mdReplace, mdWith);

  { The document and where the caller is in it. `top` is the first line drawn,
    so scrolling is a property of the render and not of the cursor. }
  { **A document is everything an editor is editing** (ADR-0396), and a record
    of its own so that changing which one is being edited is *two whole-record
    assignments* and no list of fields written twice. A structured assignment
    is a copy (ADR-0017), so `ed.doc := ed.bank[n]` moves the buffer pointer,
    the cursor, the scroll, the mark and both journals in one statement, and a
    field added here joins them without a second site to remember. That is the
    whole reason the editor *embeds* one rather than indexing an array
    everywhere: `a fact stated twice will disagree with itself` (ADR-0388) is
    the rule, and a save routine beside a load routine is exactly that fact. }
  Document = record
    lines: StrVecPtr;
    row, col: integer;  { 1-based, in the document }
    { The first line drawn and the first *column* drawn, both 1-based.
      Where the window sits is a property of the last drawing and not of
      the document, which is why `EditRender` takes the editor by `var`;
      `left` is `top`'s other axis and arrived with it in mind (ADR-0397). }
    top, left: integer;
    dirty: boolean;
    name: EditLine;
    { The journal. `undos` is what has been done, newest first, and `redos`
      what has been undone; a fresh edit drops `redos` entirely, because a
      document that has changed since has no future left to return to.
      `open` says the newest entry is still taking characters, and it is the
      whole of what makes a typed run one undo instead of eight.

      It is **per document** and has to be: an undo that reached across a
      switch would reverse an edit in a file the person is not looking at. }
    undos, redos: EditRecPtr;
    open: boolean
  end;

  Editor = record
    { The one being edited, and the others. `bank[cur]` is stale while `doc`
      is live -- it is written on the way out of a document and read on the
      way in, and nothing else looks at it. }
    doc: Document;
    bank: array [1..DocMax] of Document;
    cur, docs: integer;
    says: EditLine;     { the message line: what just happened }
    { What is being asked, what has been typed into the question, and the
      last thing searched for -- which outlives the prompt, Ctrl-L being a
      repeat of it. }
    mode: EditMode;
    { Which menu is open and which item is under the bar, both 1-based. They
      are the panel's whole state: at most one panel is open at a time in this
      increment, so there is nothing for a z-order to order and there is no
      stack -- which is a finding rather than an omission (ADR-0391). }
    menu, item: integer;
    prompt: EditLine;
    seek: EditLine;
    { What a replacement puts in `seek`'s place, kept beside it and for its
      reason: `Replace` asks two questions and the first answer has to
      survive the second being typed. }
    repl: EditLine;
    { **What the person asked for that this side does not do**: a write, a
      build, a quit. It is a `Key`, because a menu item is a second spelling
      of a binding and not a second dispatch -- the shell handles it through
      the arms it already has for a key that was typed. Cleared by the
      asking, so it is a request and not a state (ADR-0388's rule, widened
      from save alone). }
    pend: Key;
    hasPend: boolean
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

{ **How a row splits into runs of one role**, which the shell needs to colour
  it and which is therefore a decision rather than a drawing -- so it is here,
  where a session drives it and a golden holds it. `EditFault`'s rule met a
  third time.

  Without this the shell would walk the role plane itself, and *no golden
  could see it*: `tui/run.py` links the shell and never runs it, so a shell
  that painted every row with its first cell's colour would pass the whole
  suite. That is the `doc/sop.md` row this closes rather than widens. }
function RowRuns(var scr: Screen; r: integer): integer;

{ The `n`-th run of row `r`, as a first and last column and the role they
  share. }
procedure RowRun(var scr: Screen; r, n: integer;
                 var first, last: integer; var k: CellRole);

{ Is a question open? **The shell asks before it acts on anything of its
  own**: while the editor is asking something, Ctrl-S and Ctrl-B and Ctrl-Q
  belong to the answer and not to the file, and this is the only thing about
  a prompt the shell is told. }
function EditModal(var ed: Editor): boolean;

{ Did the person just name a document that had none? **Answers true once**,
  and clears -- it is a request the shell takes rather than a flag it reads,
  so a second key cannot save a second time. The shell writes the file and
  calls `EditSaved`; where the name came from is this side's business and the
  writing is that side's, which is the same line ADR-0381 drew for the
  screen. }
function EditTakeCommand(var ed: Editor; var k: Key): boolean;

{ **More than one document at once** (ADR-0396). `EditWhich` and `EditCount`
  are what the status line says; `EditFind` answers which open document has a
  name, or 0, which is what lets a diagnostic about another file be landed on
  rather than only reported; `EditGo` changes which is being edited; `EditAdd`
  starts an empty one and makes it current, answering false where there is no
  room.

  **Filling a new document is still the shell's**, which is ADR-0381's line
  and not a convenience: `EditAdd` then `EditSetName` and `EditPush` is what
  opening a file is, and the bytes are read by the side that has files. }
function EditWhich(var ed: Editor): integer;
function EditCount(var ed: Editor): integer;

{ **How many open documents have changes in them** (ADR-0401), which is a
  different question from `EditDirty` and became one the day there was more
  than one document. `EditDirty` answers about the document *on screen* and
  is what the status line's mark means; this answers about the editor, and
  is what a shell deciding whether to quit has to ask. Before ADR-0396 the
  two were the same question, which is why the guard that asked the first
  one was complete and then quietly was not. }
function EditDirtyCount(var ed: Editor): integer;
function EditFind(var ed: Editor; nm: EditLine): integer;
procedure EditGo(var ed: Editor; n: integer);
function EditAdd(var ed: Editor): boolean;

{ No bytes in hand. }
procedure DecodeInit(var d: Decoder);

{ Offer one byte. Answers true when `k` is a key, and false when more bytes
  are needed -- which is the whole of the interface, because a caller reading
  one byte at a time cannot be asked anything else. }
function DecodeByte(var d: Decoder; c: char; var k: Key): boolean;

end;

const
  Esc = 27;
  { **The frame, in real box characters.** Each is a three-byte string and a
    one-column cell, which is what the cell model bought: a golden shows a box
    and a person sees a box. Written as constants so the set can be swapped
    (for ASCII on a terminal that cannot draw these) in one place. }
  BoxTL = '┌'; BoxTR = '┐'; BoxBL = '└'; BoxBR = '┘';
  BoxH = '─'; BoxV = '│';

  { The menu bar. **An item names a `Key`**, and choosing it feeds that key
    back through `EditKey` -- so a menu adds no action of its own, exactly as a
    bound function key is decoded *as* the key it is bound to. Only what
    exists is listed: a menu of things that do nothing is worse than no menu,
    which is why there is no Help and no File>Open yet. }
  MenuCount = 4;
  ItemMost = 3;   { the longest menu, in items }

  { What the hint bar says. One place, because it is a claim about the
    bindings and the decoder is the other half of that claim -- a key here
    that `DecodeByte` does not answer would be the editor lying about itself
    on every frame. }
  Hints = 'F10 Menu  F3 Open  F2 Save  F9 Build  F6 Next  ^F Find  ^Q Quit';

{ One empty document, which is what `EditInit` starts with and what
  `EditAdd` makes. Written once because both need it and because a field
  added to `Document` must be initialised in one place, not two. }
procedure BlankDoc(var d: Document);
begin
  SVecNew(d.lines, 64);
  d.lines.Push('');
  d.row := 1;
  d.col := 1;
  d.top := 1;
  d.left := 1;
  d.dirty := false;
  d.name := '';
  d.undos := nil;
  d.redos := nil;
  d.open := false
end;

procedure EditInit;
begin
  BlankDoc(ed.doc);
  ed.cur := 1;
  ed.docs := 1;
  ed.says := '';
  ed.mode := mdEdit;
  ed.prompt := '';
  ed.seek := '';
  ed.repl := '';
  ed.menu := 1;
  ed.item := 0;
  ed.hasPend := false;
  ed.pend.kind := kkNone;
  ed.pend.ch := ' ';
  ed.pend.num := 0
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
var i: integer;
begin
  { **Every document and not the current one** (ADR-0396). The bank holds the
    others' buffers and journals, and freeing only what is on screen would
    leak one heap per file the person opened -- which `heap-balance` counts
    and which nothing else here would have noticed. `bank[cur]` is stale
    while `doc` is live, so it is skipped. }
  ed.doc.lines.Free;
  Drop(ed.doc.undos);
  Drop(ed.doc.redos);
  for i := 1 to ed.docs do
    if i <> ed.cur then begin
      ed.bank[i].lines.Free;
      Drop(ed.bank[i].undos);
      Drop(ed.bank[i].redos)
    end;
  ed.docs := 0
end;

{ **Which document is on screen, and how many there are.** Two numbers the
  status line needs and the shell must not derive for itself. }
function EditWhich;
begin
  EditWhich := ed.cur
end;

function EditCount;
begin
  EditCount := ed.docs
end;

{ **The document on screen is live and the bank holds the others** -- `ed.doc`
  is written back into `ed.bank[ed.cur]` only when `EditGo` or `EditAdd` moves
  away from it, so that slot is a stale copy while it is current and must be
  skipped rather than read. `EditFind` above is written the same way and for
  the same reason. }
function EditDirtyCount;
var i, n: integer;
begin
  n := 0;
  if ed.doc.dirty then n := 1;
  for i := 1 to ed.docs do
    if (i <> ed.cur) and ed.bank[i].dirty then n := n + 1;
  EditDirtyCount := n
end;

{ Which open document has this name, or 0. What lets a diagnostic about
  another file be *landed on* rather than only reported. }
function EditFind;
var i: integer;
begin
  EditFind := 0;
  if nm = '' then exit;
  if ed.doc.name = nm then EditFind := ed.cur
  else
    for i := 1 to ed.docs do
      if (i <> ed.cur) and (ed.bank[i].name = nm) then EditFind := i
end;

{ **Change which document is being edited**, and the whole of it is two
  whole-record assignments (ADR-0396). Out of range or already current is a
  no-op rather than an error: the callers are a key and a diagnostic, and
  neither has anything to do with a refusal. }
procedure EditGo;
begin
  if (n >= 1) and (n <= ed.docs) and (n <> ed.cur) then begin
    ed.bank[ed.cur] := ed.doc;
    ed.doc := ed.bank[n];
    ed.cur := n
  end
end;

{ A new empty document, made current. False where there is no room, and the
  caller says so -- this side does not write the message, `EditSay` being the
  one place a message is set. }
function EditAdd;
begin
  EditAdd := false;
  if ed.docs < DocMax then begin
    ed.bank[ed.cur] := ed.doc;
    ed.docs := ed.docs + 1;
    ed.cur := ed.docs;
    BlankDoc(ed.doc);
    EditAdd := true
  end
end;

function EditModal;
begin
  EditModal := ed.mode <> mdEdit
end;

function RowRuns;
var c, n: integer; k: CellRole;
begin
  n := 0;
  c := 1;
  while c <= scr.cols do begin
    n := n + 1;
    k := scr.role[r][c];
    while (c <= scr.cols) and (scr.role[r][c] = k) do c := c + 1
  end;
  RowRuns := n
end;

procedure RowRun;
var c, seen: integer; k2: CellRole;
begin
  { Answers the last run for an `n` past the end rather than nothing, so a
    caller that miscounts paints a row twice instead of leaving a gap of
    whatever the terminal had. }
  first := 1;
  last := scr.cols;
  k := crText;
  c := 1;
  seen := 0;
  while (c <= scr.cols) and (seen < n) do begin
    seen := seen + 1;
    k2 := scr.role[r][c];
    first := c;
    while (c <= scr.cols) and (scr.role[r][c] = k2) do c := c + 1;
    last := c - 1;
    k := k2
  end
end;

function EditTakeCommand;
begin
  k := ed.pend;
  EditTakeCommand := ed.hasPend;
  ed.hasPend := false
end;

procedure EditPush;
begin
  { The line an empty editor starts with is not a line of the document: the
    first push replaces it rather than sitting under it, or every loaded file
    would gain a blank first line. }
  if (ed.doc.lines.Len = 1) and (ed.doc.lines.At(1) = '') then
    ed.doc.lines.Put(1, s)
  else
    ed.doc.lines.Push(s)
end;

function EditDirty;
begin
  EditDirty := ed.doc.dirty
end;

function EditLines;
begin
  EditLines := ed.doc.lines.Len
end;

function EditRow;
begin
  EditRow := ed.doc.row
end;

function EditCol;
begin
  EditCol := ed.doc.col
end;

function EditName;
begin
  EditName := ed.doc.name
end;

function EditLine_;
begin
  if (n < 1) or (n > ed.doc.lines.Len) then EditLine_ := ''
  else EditLine_ := ed.doc.lines.At(n)
end;

procedure EditSetName;
begin
  ed.doc.name := s
end;

procedure EditSay;
begin
  ed.says := s
end;

procedure EditSaved;
begin
  ed.doc.dirty := false
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
{ **Where the element containing byte `at` begins** (ADR-0395), and `at`
  itself when that byte begins one or is past the end.

  `PasUnicode` answers the forward question and not this one, and it is right
  not to: a text has no back-pointer, so the only honest way to a boundary
  behind you is from the front. Lines here are bounded by `LineMax`, so this
  is a walk over at most 255 bytes and is what a left arrow costs.

  A byte that begins no element -- which means the line is not a text value,
  and a person editing a file of arbitrary bytes will meet that -- is stepped
  over one at a time, so this terminates and answers something for every
  input. }
function ElementAt(s: EditLine; at: integer): integer;
var i, e: integer;
begin
  ElementAt := at;
  if (at >= 1) and (at <= length(s)) then begin
    i := 1;
    while i < at do begin
      e := ElementEnd(s, i);
      if e <= i then e := i + 1;
      if e > at then begin
        ElementAt := i;
        i := at
      end
      else i := e
    end
  end
end;

{ Where the element *before* `at` begins, which is one question later: the
  element containing the byte before it. What Backspace and a left arrow
  need. }
function ElementBack(s: EditLine; at: integer): integer;
begin
  if at <= 1 then ElementBack := 1
  else ElementBack := ElementAt(s, at - 1)
end;

{ How many columns the first `n` bytes of a line occupy, which is where the
  cursor goes. Falls back to counting *bytes* where the line is not a text
  value: that is exactly the case where a column has no meaning, and one
  column per byte is what the terminal will do with it. }
function ColumnOf(s: EditLine; n: integer): integer;
var w: integer;
begin
  if n < 1 then n := 1;
  w := Columns(Left(s, n - 1));
  if w < 0 then w := n - 1;
  ColumnOf := w + 1
end;

procedure Clamp(var ed: Editor);
var n: integer; cur: EditLine;
begin
  if ed.doc.row < 1 then ed.doc.row := 1;
  if ed.doc.row > ed.doc.lines.Len then ed.doc.row := ed.doc.lines.Len;
  cur := ed.doc.lines.At(ed.doc.row);
  n := length(cur);
  if ed.doc.col < 1 then ed.doc.col := 1;
  if ed.doc.col > n + 1 then ed.doc.col := n + 1;
  { **And it lands on an element boundary** (ADR-0395). Moving down a line
    keeps the byte and the new line is not the old one, so without this the
    cursor can come to rest inside a character -- where Delete would take the
    joiner out of the middle of an emoji and leave the two halves to join
    with their neighbours. Every other route into `ed.doc.col` is already a
    boundary by construction; this is the one that is not. }
  ed.doc.col := ElementAt(cur, ed.doc.col)
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
  cur := ed.doc.lines.At(row);
  ed.doc.lines.Put(row, Left(cur, col - 1) + s + From(cur, col))
end;

procedure DoRemove(var ed: Editor; row, col, n: integer);
var cur: EditLine;
begin
  cur := ed.doc.lines.At(row);
  ed.doc.lines.Put(row, Left(cur, col - 1) + From(cur, col + n))
end;

procedure DoSplit(var ed: Editor; row, col: integer);
var cur, rest: EditLine; i: integer;
begin
  cur := ed.doc.lines.At(row);
  rest := From(cur, col);
  ed.doc.lines.Put(row, Left(cur, col - 1));
  { `PasStrVec` has no insert, so the lines below move down by one and the
    hole is written into -- what a vector costs, and invisible at the sizes a
    person edits at. }
  ed.doc.lines.Push('');
  for i := ed.doc.lines.Len - 1 downto row + 1 do
    ed.doc.lines.Put(i + 1, ed.doc.lines.At(i));
  ed.doc.lines.Put(row + 1, rest)
end;

procedure DoJoin(var ed: Editor; row: integer);
var i: integer; gone: EditLine;
begin
  ed.doc.lines.Put(row, ed.doc.lines.At(row) + ed.doc.lines.At(row + 1));
  for i := row + 1 to ed.doc.lines.Len - 1 do
    ed.doc.lines.Put(i, ed.doc.lines.At(i + 1));
  { The vector is one shorter, and what came off it is already in the line
    above. `PasStrVec` has no drop, so the value is taken and let go. }
  gone := ed.doc.lines.Pop
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
  Drop(ed.doc.redos);
  if ed.doc.open and (ed.doc.undos <> nil) and (ed.doc.undos^.kind = kind) and
     (ed.doc.undos^.row = row) then begin
    if (kind = ekInsert) and (ed.doc.undos^.col + length(ed.doc.undos^.text) = col) then begin
      ed.doc.undos^.text := ed.doc.undos^.text + s;
      exit
    end
    else if (kind = ekDelete) and (ed.doc.undos^.col = col + length(s)) then begin
      { Backspace: the run grows leftwards, so the entry's column follows it
        and the text goes on the front. }
      ed.doc.undos^.text := s + ed.doc.undos^.text;
      ed.doc.undos^.col := col;
      exit
    end
    else if (kind = ekDelete) and (ed.doc.undos^.col = col) then begin
      { Delete: the run grows rightwards and the column stays where it is. }
      ed.doc.undos^.text := ed.doc.undos^.text + s;
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
  e^.atRow := ed.doc.row;
  e^.atCol := ed.doc.col;
  e^.more := false;
  e^.next := ed.doc.undos;
  ed.doc.undos := e;
  ed.doc.open := true
end;

{ Undo one entry: perform its opposite, move it to the redo stack, and put
  the cursor back where the person was before it. Answers whether the entry
  said the undo goes on -- `Undo` below is the loop, and the two are separate
  so that the reversal of an edit is written once (ADR-0403). }
function UndoOne(var ed: Editor): boolean;
var e: EditRecPtr;
begin
  UndoOne := false;
  e := ed.doc.undos;
  ed.doc.undos := e^.next;
  case e^.kind of
    ekInsert: DoRemove(ed, e^.row, e^.col, length(e^.text));
    ekDelete: DoInsert(ed, e^.row, e^.col, e^.text);
    ekSplit: DoJoin(ed, e^.row);
    ekJoin: DoSplit(ed, e^.row, e^.col)
  end;
  ed.doc.row := e^.atRow;
  ed.doc.col := e^.atCol;
  e^.next := ed.doc.redos;
  ed.doc.redos := e;
  { **Undoing back to what was on disc still counts as a change**, and that
    is deliberate: this editor does not track which entry the last save was
    at, so it says the document differs rather than claiming it does not. The
    honest direction to be wrong in is the one that offers to save. }
  ed.doc.dirty := true;
  UndoOne := e^.more
end;

{ **One action of a person's, however many operations it took** (ADR-0403).
  A keystroke makes one entry and `more` is false on it, so this is the old
  routine for everything that was here before; a replacement makes two and a
  replace-all makes many, and undoing half of one is an undo of nothing
  anybody did. The flag is read off the entry just reversed, which is what
  makes the loop terminate on a journal built by any means at all. }
procedure Undo(var ed: Editor);
begin
  if ed.doc.undos = nil then begin
    ed.says := 'nothing to undo';
    exit
  end;
  while UndoOne(ed) and (ed.doc.undos <> nil) do
    { the entry said the action goes on };
  ed.doc.open := false
end;

{ ...and redo performs the same entry again. There is one description of an
  edit here and not two, which is the reason this is eight lines. }
procedure RedoOne(var ed: Editor);
var e: EditRecPtr;
begin
  e := ed.doc.redos;
  ed.doc.redos := e^.next;
  ed.doc.row := e^.row;
  ed.doc.col := e^.col;
  case e^.kind of
    ekInsert: begin
      DoInsert(ed, e^.row, e^.col, e^.text);
      ed.doc.col := e^.col + length(e^.text)
    end;
    ekDelete: DoRemove(ed, e^.row, e^.col, length(e^.text));
    ekSplit: begin
      DoSplit(ed, e^.row, e^.col);
      ed.doc.row := e^.row + 1;
      ed.doc.col := 1
    end;
    ekJoin: DoJoin(ed, e^.row)
  end;
  e^.next := ed.doc.undos;
  ed.doc.undos := e;
  ed.doc.dirty := true
end;

{ **The same group, forwards.** `Undo` pushes the entries it reversed onto
  the redo stack in the order it took them, so the one that *starts* the
  action is on top and the ones that say `more` are beneath it -- which is
  why this reads the flag off the entry it is about to do next, where `Undo`
  reads it off the one it has just done. Written out rather than made
  symmetrical: the two stacks are the same journal read in opposite
  directions, and pretending otherwise is how an undo and a redo come to
  disagree about what one action was. }
procedure Redo(var ed: Editor);
begin
  if ed.doc.redos = nil then begin
    ed.says := 'nothing to redo';
    exit
  end;
  RedoOne(ed);
  while (ed.doc.redos <> nil) and ed.doc.redos^.more do RedoOne(ed);
  ed.doc.open := false
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
  n := ed.doc.lines.Len;
  for i := 0 to n do begin
    r := row + i;
    if r > n then begin
      r := r - n;
      wrapped := true
    end;
    if i = 0 then start := col else start := 1;
    at := IndexFrom(Fold(ed.doc.lines.At(r)), needle, start);
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
  if again then from := ed.doc.col + 1 else from := ed.doc.col;
  if Seek(ed, ed.seek, ed.doc.row, from, fr, fc, wrapped) then begin
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

{ **Replace every occurrence in the document** (ADR-0403), and answer how
  many. Matching is `Seek`'s -- case-insensitive, 6.1.3's reason -- and what
  goes in is `ed.repl` exactly, so replacing `writeln` with `WriteLn` is a
  thing this can do and a search that could tell them apart is not.

  **It is the four operations and the journal, like every other edit here.**
  A replacement is a remove and an insert at the same place; what makes it
  one action is that every entry but the first says `more`, which is the flag
  ADR-0403 added and the whole of what this feature needed the model to grow.
  Undoing a hundred replacements is one Ctrl-Z, and that is the answer this
  editor gives instead of asking about each one.

  The search for the next match starts past the text just written, which is
  what stops `a` becoming `aa` from running forever; where the replacement is
  *empty* the start does not move and the line does instead, so that
  terminates on the line getting shorter. Both are the same loop and neither
  is a special case. }
procedure ReplaceAll(var ed: Editor);
var r, at, from, n, made, lastr, lastc: integer;
    needle, line, msg: EditLine;
    first: boolean;

  { One operation of the action. **Never joined to a run**: a replacement
    that coalesced with the typing before it would make Ctrl-Z reverse both,
    and `Note`'s three conditions are about a person's fingers and not about
    this. The first entry stops the undo and every one after it continues
    it, which is the direction `UndoOne` reads the flag in. }
  procedure Step(kind: EditKind; row, col: integer; t: EditLine);
  begin
    ed.doc.open := false;
    Note(ed, kind, row, col, t);
    if not first then ed.doc.undos^.more := true;
    first := false
  end;

begin
  if ed.seek = '' then begin
    ed.says := 'nothing to replace';
    exit
  end;
  needle := Fold(ed.seek);
  made := 0;
  first := true;
  lastr := ed.doc.row;
  lastc := ed.doc.col;
  n := ed.doc.lines.Len;
  for r := 1 to n do begin
    from := 1;
    repeat
      line := ed.doc.lines.At(r);
      at := IndexFrom(Fold(line), needle, from);
      if at > 0 then begin
        Step(ekDelete, r, at, substr(line, at, length(ed.seek)));
        DoRemove(ed, r, at, length(ed.seek));
        if ed.repl <> '' then begin
          Step(ekInsert, r, at, ed.repl);
          DoInsert(ed, r, at, ed.repl)
        end;
        made := made + 1;
        lastr := r;
        lastc := at + length(ed.repl);
        from := at + length(ed.repl)
      end
    until at = 0
  end;
  if made = 0 then begin
    writestr(msg, 'not found: ', ed.seek);
    ed.says := msg;
    exit
  end;
  ed.doc.dirty := true;
  { The cursor lands *after* the last replacement, where a person typing it
    by hand would have left it. }
  MoveTo(ed, lastr, lastc);
  if made = 1 then ed.says := '1 replacement'
  else begin
    writestr(msg, made:1, ' replacements');
    ed.says := msg
  end
end;

{ A key while a question is open. **The question owns every one of them**: a
  person typing an answer has not asked for anything else to happen, which is
  what `EditModal` tells the shell and why Ctrl-S does not save from
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
      { **Two questions and one action** (ADR-0403). The first answer has to
        survive the second being typed, which is why it goes into `ed.seek`
        here rather than being held in the prompt -- and putting it there is
        also what makes Ctrl-L after a replace repeat the same search, which
        is what a person would expect and costs nothing to be right about. }
      mdReplace: begin
        if ed.prompt = '' then begin
          ed.mode := mdEdit;
          ed.says := 'nothing to replace'
        end
        else begin
          ed.seek := ed.prompt;
          ed.prompt := '';
          ed.mode := mdWith
        end
      end;
      { An empty answer is a deletion and not a refusal: replacing a word
        with nothing is the commonest thing anyone does with this. }
      mdWith: begin
        ed.mode := mdEdit;
        ed.repl := ed.prompt;
        ReplaceAll(ed)
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
          ed.doc.name := ed.prompt;
          ed.pend.kind := kkSave;
          ed.hasPend := true
        end
      end;
      { **The model makes room and the shell reads the file** (ADR-0396),
        which is ADR-0381's line drawn again: a document is a decision and
        bytes are not. An already-open file is *switched to* rather than
        opened twice -- two buffers over one file would be two answers to
        `is this saved`. }
      mdOpen: begin
        ed.mode := mdEdit;
        if ed.prompt = '' then ed.says := 'no name, nothing to open'
        else if EditFind(ed, ed.prompt) <> 0 then begin
          EditGo(ed, EditFind(ed, ed.prompt));
          ed.says := 'already open'
        end
        else if not EditAdd(ed) then
          ed.says := 'no room for another document'
        else begin
          { The name goes on the new document *here*, as `Save as` puts one on
            this one, so the shell reads it back with `EditName` and holds no
            second copy of it (ADR-0388). }
          ed.doc.name := ed.prompt;
          ed.pend.kind := kkOpen;
          ed.hasPend := true
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

{ **Composite one cell.** Every drawing below goes through this, so clipping
  is written once: a panel that runs off the right edge or past the last row
  is cut rather than trapping, which is what a window narrower than a dialog
  has to do. }
procedure PutCell(var scr: Screen; r, c: integer; s: ScreenCell; k: CellRole);
begin
  if (r >= 1) and (r <= scr.rows) and (c >= 1) and (c <= scr.cols) then begin
    scr.cell[r][c] := s;
    scr.role[r][c] := k
  end
end;

{ ...and one string of *bytes*, a byte to a cell. That is right for the ASCII
  a Pascal source is written in and wrong for anything wider, which is exactly
  the limitation this increment leaves standing and stage two removes. }
procedure PutAt(var scr: Screen; r, c: integer; s: EditLine; k: CellRole);
var i: integer; one: ScreenCell;
begin
  for i := 1 to length(s) do begin
    one := '';
    one := one + s[i];
    PutCell(scr, r, c + i - 1, one, k)
  end
end;

{ The last scalar of a value, which is what a truncated cell may have to give
  back. There is no backwards decoding here for `ElementBack`'s reason, so it
  is a walk from the front over at most `CellMax` bytes. }
function LastScalar(s: ScreenCell): ScreenCell;
var i, j: integer; cp: Scalar;
begin
  LastScalar := '';
  i := 1;
  while i <= length(s) do begin
    j := NextScalar(s, i, cp);
    if j <= i then j := i + 1;
    LastScalar := substr(s, i, j - i);
    i := j
  end
end;

{ **One line of the document, an element to a cell** (ADR-0395).

  This is where a column stops being a byte. A line is walked by element;
  each element goes whole into one cell and the cells its width covers after
  it are the null-string, which `PutRow` skips -- the terminal has already
  advanced past them, so writing a blank there would push the rest of the row
  one column right.

  Three cases the loop has to answer and each was met by probing:

  - an element too long for a cell is cut to whole scalars (`CellMax`);
  - an element of **no** width -- a combining mark with no base, which is what
    the second byte of a broken line looks like -- is added to the cell before
    it rather than given one of its own, and starts a cell only if it is the
    first thing on the line;
  - a **wide** element that would hang over the right edge is dropped rather
    than half-drawn, which is the no-horizontal-scrolling rule made
    element-aware: a terminal handed the first half of a wide character does
    not draw half of it. }
procedure PutLine(var scr: Screen; r: integer; s: EditLine;
                  cols, first: integer);
var i, e, j, k, m, c, w: integer; one, prev: ScreenCell; cp: Scalar; fits: boolean;
begin
  { `c` is the **document's** column and `c - first + 1` is the screen's, so
    the walk is the same walk and only the placing moved (ADR-0397). A cell
    first of the window is stepped over, which is what makes this a scroll
    and not a second renderer. }
  c := 1;
  i := 1;
  while (i <= length(s)) and (c - first + 1 <= cols) do begin
    e := ElementEnd(s, i);
    if (e <= i) or (e > length(s) + 1) then e := i + 1;

    { The element's bytes, cut at a scalar boundary if it does not fit. }
    one := '';
    j := i;
    fits := true;
    while (j < e) and fits do begin
      k := NextScalar(s, j, cp);
      if (k <= j) or (k > e) then k := j + 1;
      if length(one) + (k - j) <= CellMax then begin
        for m := j to k - 1 do one := one + s[m];
        j := k
      end
      else fits := false
    end;

    { A **truncated** element must not end in a scalar of no width. A joiner
      first dangling at the end of a cell is an instruction to join with
      whatever is drawn next, so the cut would reach into the cell beside it
      -- which is the one way this could put something on the terminal that
      is worse than a missing character. }
    while (not fits) and (one <> '') and (Columns(LastScalar(one)) = 0) do
      one := Left(one, length(one) - length(LastScalar(one)));

    w := Columns(one);
    if w < 0 then w := 1;
    if w = 0 then begin
      { No width: it belongs to whatever is already in the cell before it,
        and only if that cell is on the screen. }
      if (c > 1) and (c - first >= 1) then begin
        prev := scr.cell[r][c - first];
        if length(prev) + length(one) <= CellMax then
          PutCell(scr, r, c - first, prev + one, crText)
      end
      else if c = 1 then begin
        PutCell(scr, r, c - first + 1, one, crText);
        c := c + 1
      end
    end
    else if c + w - 1 < first then c := c + w   { wholly left of the window }
    { **Straddling the left edge, and dropped rather than half-drawn**: a
      terminal handed the second column of a wide character does not draw the
      right half of it, and the blank this leaves is what a person reads as
      *there is more over there*. The same rule as the right edge below, one
      line earlier. }
    else if c < first then c := c + w
    else if c - first + w > cols then c := first + cols   { over the right }
    else begin
      PutCell(scr, r, c - first + 1, one, crText);
      for m := 1 to w - 1 do PutCell(scr, r, c - first + 1 + m, '', crText);
      c := c + w
    end;
    i := e
  end
end;

{ A frame, with its title let into the top edge Turbo Pascal's way. The
  inside is *cleared* to the frame's role, which is what makes a panel opaque
  -- a dialog over a document must hide it rather than show through. }
procedure Frame(var scr: Screen; top, left, hgt, wid: integer;
                title: EditLine; k: CellRole);
var r, c: integer;
begin
  for r := top to top + hgt - 1 do
    for c := left to left + wid - 1 do
      PutCell(scr, r, c, ' ', k);
  for c := left + 1 to left + wid - 2 do begin
    PutCell(scr, top, c, BoxH, k);
    PutCell(scr, top + hgt - 1, c, BoxH, k)
  end;
  for r := top + 1 to top + hgt - 2 do begin
    PutCell(scr, r, left, BoxV, k);
    PutCell(scr, r, left + wid - 1, BoxV, k)
  end;
  PutCell(scr, top, left, BoxTL, k);
  PutCell(scr, top, left + wid - 1, BoxTR, k);
  PutCell(scr, top + hgt - 1, left, BoxBL, k);
  PutCell(scr, top + hgt - 1, left + wid - 1, BoxBR, k);
  if title <> '' then
    PutAt(scr, top, left + 2, ' ' + title + ' ', k)
end;

{ The menu bar, written as functions rather than as a table of records
  because Pascal has no array literal and a `case` is what this tree reaches
  for. Adding a menu is four arms and no other change. }
function MenuTitle(m: integer): EditLine;
begin
  case m of
    1: MenuTitle := 'File';
    2: MenuTitle := 'Edit';
    3: MenuTitle := 'Search';
    4: MenuTitle := 'Run';
    otherwise MenuTitle := ''
  end
end;

function MenuItems(m: integer): integer;
begin
  case m of
    1: MenuItems := 3;
    2: MenuItems := 2;
    3: MenuItems := 4;
    4: MenuItems := 1;
    otherwise MenuItems := 0
  end
end;

{ The caption carries the key, which is how a person learns one without
  reading a README -- the hint bar's argument, one layer in. }
function ItemCaption(m, i: integer): EditLine;
begin
  { **Not padded to a common width**, and that is deliberate: what makes a
    panel opaque is `Frame` clearing its interior, and captions padded to the
    box would cover every cell and leave that clearing dead code -- true by
    accident, and silently false the day a caption is shorter. The Search menu
    is the one with three different lengths, which is why the session opens
    it. }
  ItemCaption := '';
  if m = 1 then begin
    if i = 1 then ItemCaption := 'Open  F3'
    else if i = 2 then ItemCaption := 'Save  F2'
    else if i = 3 then ItemCaption := 'Quit  ^Q'
  end
  else if m = 2 then begin
    if i = 1 then ItemCaption := 'Undo  ^Z'
    else if i = 2 then ItemCaption := 'Redo  ^Y'
  end
  else if m = 3 then begin
    if i = 1 then ItemCaption := 'Find  ^F'
    else if i = 2 then ItemCaption := 'Find next  ^L'
    else if i = 3 then ItemCaption := 'Replace  ^R'
    else if i = 4 then ItemCaption := 'Go to line  ^G'
  end
  else if m = 4 then
    if i = 1 then ItemCaption := 'Build  F9'
end;

{ **The item names a key**, and that is the whole of the menu's machinery. }
function ItemKey(m, i: integer): Key;
var k: Key;
begin
  k.ch := ' ';
  k.num := 0;
  k.kind := kkNone;
  if m = 1 then begin
    if i = 1 then k.kind := kkOpen
    else if i = 2 then k.kind := kkSave
    else if i = 3 then k.kind := kkQuit
  end
  else if m = 2 then begin
    if i = 1 then k.kind := kkUndo
    else if i = 2 then k.kind := kkRedo
  end
  else if m = 3 then begin
    if i = 1 then k.kind := kkFind
    else if i = 2 then k.kind := kkAgain
    else if i = 3 then k.kind := kkReplace
    else if i = 4 then k.kind := kkGoto
  end
  else if m = 4 then
    if i = 1 then k.kind := kkBuild;
  ItemKey := k
end;

{ Where a menu's title starts on the bar, so the drop-down lines up under it. }
function MenuAt(m: integer): integer;
var i, c: integer;
begin
  c := 2;
  for i := 1 to m - 1 do c := c + length(MenuTitle(i)) + 2;
  MenuAt := c
end;

{ A key while the menu bar has the keyboard. **One mode and not two**:
  `ed.item = 0` is the bar with nothing dropped and anything above it is the
  drop-down open on that item, which is one integer where a second `EditMode`
  value would have been a second state to keep consistent with it. }
procedure MenuKey(var ed: Editor; k: Key);
var c: Key;
begin
  case k.kind of
    kkLeft: begin
      ed.menu := ed.menu - 1;
      if ed.menu < 1 then ed.menu := MenuCount;
      if ed.item > MenuItems(ed.menu) then ed.item := MenuItems(ed.menu)
    end;
    kkRight: begin
      ed.menu := ed.menu + 1;
      if ed.menu > MenuCount then ed.menu := 1;
      if ed.item > MenuItems(ed.menu) then ed.item := MenuItems(ed.menu)
    end;
    { Down opens the drop-down and then walks it, wrapping. Turbo Pascal's
      behaviour, and the reason `item = 0` is worth having as a value. }
    kkDown: if ed.item = 0 then ed.item := 1
            else begin
              ed.item := ed.item + 1;
              if ed.item > MenuItems(ed.menu) then ed.item := 1
            end;
    kkUp: if ed.item = 0 then ed.item := MenuItems(ed.menu)
          else begin
            ed.item := ed.item - 1;
            if ed.item < 1 then ed.item := MenuItems(ed.menu)
          end;
    kkEnter: if ed.item = 0 then ed.item := 1
             else begin
               c := ItemKey(ed.menu, ed.item);
               ed.mode := mdEdit;
               ed.item := 0;
               { **An item is a second spelling of a binding**, so what it
                 names goes down the path a typed key goes down: the shell's
                 three become a request it takes, and everything else is this
                 side's and is applied here. The recursion is one deep and
                 stays so because no item names a menu key -- which is a
                 property of `ItemKey` and is why that table is small and in
                 one place. }
               if (c.kind = kkSave) or (c.kind = kkQuit) or
                  (c.kind = kkBuild) then begin
                 ed.pend := c;
                 ed.hasPend := true
               end
               else
                 EditKey(ed, c)
             end;
    { Ctrl-C, and F10 a second time, both close. }
    kkCancel, kkMenu: begin
      ed.mode := mdEdit;
      ed.item := 0
    end;
    { **Every remaining kind, named** -- a `case` with no `otherwise` traps on
      a selector no label matches (6.9.3.5, ADR-0018), so a key this arm does
      not list is not ignored, it *stops the editor*. `kkOpen` and `kkNextDoc`
      arrived with ADR-0396 and were not added here, so F3 or F6 with the menu
      open crashed the shipped editor. The bare list is the right shape and an
      `otherwise` would be the wrong fix: it is the trap that says a kind was
      added, and this is the arm that has to say what happens to it. }
    kkNone, kkChar, kkBack, kkDelete, kkHome, kkEnd, kkSave, kkQuit,
    kkBuild, kkUnknown, kkUndo, kkRedo, kkFind, kkAgain, kkReplace, kkGoto,
    kkOpen, kkNextDoc, kkFunc: ;
  end
end;

procedure EditKey;
var cur, rest, one: EditLine; k2: integer; keep: boolean;
    b, e2: integer;   { an element's first and one-past-last byte }
begin
  { **The message is about the last key**, so it is cleared here and set by
    whichever arm has something to say. The alternative -- leaving it until
    something replaces it -- was tried first and the session golden showed
    what is wrong with it: `unknown key` stayed on the screen while the person
    typed, describing a key two keystrokes ago. It also gives the shell the
    behaviour it wants for free: `saved` stands until the next key touches
    the document, which is exactly how long it is true. }
  ed.says := '';

  { A question or a menu owns the keyboard while it is open, and nothing
    below runs. }
  if ed.mode = mdMenu then begin
    MenuKey(ed, k);
    exit
  end;
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
  keep := ed.doc.open;
  ed.doc.open := false;

  cur := ed.doc.lines.At(ed.doc.row);
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
        ed.doc.open := keep;
        Note(ed, ekInsert, ed.doc.row, ed.doc.col, one);
        DoInsert(ed, ed.doc.row, ed.doc.col, one);
        ed.doc.col := ed.doc.col + 1;
        ed.doc.dirty := true
      end
    end;
    kkEnter: begin
      { Split: the tail moves to a new line after this one. It never joins a
        group, so the `keep` above is deliberately not handed back. }
      Note(ed, ekSplit, ed.doc.row, ed.doc.col, '');
      DoSplit(ed, ed.doc.row, ed.doc.col);
      ed.doc.row := ed.doc.row + 1;
      ed.doc.col := 1;
      ed.doc.dirty := true
    end;
    kkBack: begin
      { **Backspace removes an element and not a byte** (ADR-0395). Removing
        one byte of `æ¥` leaves two bytes that are not a character, and the
        undo journal would then hold a fragment that is not one either --
        which is why this is the model's business and not the shell's. `b`
        is where the element before the cursor begins. }
      if ed.doc.col > 1 then begin
        b := ElementBack(cur, ed.doc.col);
        ed.doc.open := keep;
        Note(ed, ekDelete, ed.doc.row, b, substr(cur, b, ed.doc.col - b));
        DoRemove(ed, ed.doc.row, b, ed.doc.col - b);
        ed.doc.col := b;
        ed.doc.dirty := true
      end
      else if ed.doc.row > 1 then begin
        { Join with the line above, and the cursor lands where the join is
          rather than at either end -- which is where the person was
          looking. That column is also what undoes it: a join is reversed by
          splitting at the point the two lines met. }
        rest := ed.doc.lines.At(ed.doc.row - 1);
        k2 := length(rest) + 1;
        Note(ed, ekJoin, ed.doc.row - 1, k2, '');
        DoJoin(ed, ed.doc.row - 1);
        ed.doc.row := ed.doc.row - 1;
        ed.doc.col := k2;
        ed.doc.dirty := true
      end
    end;
    kkDelete: begin
      { The same, forwards: `e` is where the element under the cursor ends. }
      if ed.doc.col <= length(cur) then begin
        e2 := ElementEnd(cur, ed.doc.col);
        if (e2 <= ed.doc.col) or (e2 > length(cur) + 1) then e2 := ed.doc.col + 1;
        ed.doc.open := keep;
        Note(ed, ekDelete, ed.doc.row, ed.doc.col, substr(cur, ed.doc.col, e2 - ed.doc.col));
        DoRemove(ed, ed.doc.row, ed.doc.col, e2 - ed.doc.col);
        ed.doc.dirty := true
      end
      else if ed.doc.row < ed.doc.lines.Len then begin
        { At the end of a line, Delete is the same join Backspace makes from
          the other side -- and `Clamp` has already made `ed.doc.col` exactly
          `length(cur) + 1`, which is where the two lines meet. }
        Note(ed, ekJoin, ed.doc.row, ed.doc.col, '');
        DoJoin(ed, ed.doc.row);
        ed.doc.dirty := true
      end
    end;
    { **The arrows move by element** (ADR-0395), so one press crosses one
      thing a person sees. A byte step would put the cursor inside a
      character, where the next Backspace would break it and the status line
      would name a position no edit can be made at. }
    kkLeft: begin
      if ed.doc.col > 1 then ed.doc.col := ElementBack(cur, ed.doc.col)
      else if ed.doc.row > 1 then begin
        ed.doc.row := ed.doc.row - 1;
        ed.doc.col := length(ed.doc.lines.At(ed.doc.row)) + 1
      end
    end;
    kkRight: begin
      if ed.doc.col <= length(cur) then begin
        e2 := ElementEnd(cur, ed.doc.col);
        if (e2 <= ed.doc.col) or (e2 > length(cur) + 1) then e2 := ed.doc.col + 1;
        ed.doc.col := e2
      end
      else if ed.doc.row < ed.doc.lines.Len then begin
        ed.doc.row := ed.doc.row + 1;
        ed.doc.col := 1
      end
    end;
    kkUp: ed.doc.row := ed.doc.row - 1;
    kkDown: ed.doc.row := ed.doc.row + 1;
    kkHome: ed.doc.col := 1;
    kkEnd: ed.doc.col := length(cur) + 1;
    { **The shell acts on these and the model does not**, which is what keeps
      the model free of files and processes: saving is a write and building
      is an `ArgV.Execute`, and neither is a decision about a document.
      They are still `Key` values because they arrive as bytes among the
      others and the decoder is the one place that knows which. }
    kkUndo: Undo(ed);
    kkRedo: Redo(ed);
    { A prompt starts empty rather than holding the last search: a person who
      wants that presses Ctrl-L, and one who does not would have to clear it
      every time. }
    kkReplace: begin
      ed.mode := mdReplace;
      ed.prompt := ''
    end;
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
    { F10, and Ctrl-O where a terminal keeps F10 for itself. }
    kkMenu: begin
      ed.mode := mdMenu;
      ed.menu := 1;
      ed.item := 0
    end;
    { Decoded, and not bound to anything yet -- said with its number, because
      a key that does nothing and a key that was misread look alike, and F3
      and F10 are the two a Turbo Pascal user will press first. }
    kkFunc: begin
      writestr(rest, 'F', k.num:1, ' is not bound');
      ed.says := rest
    end;
    { **Ctrl-S is the shell's, except when there is no name to save under.**
      Which key writes a file is the shell's business and stays there; *a
      document with no name cannot be written and has to be asked about* is a
      decision about the document, so it is here, where a session drives it
      and a golden holds it. Starting fileless is the ordinary way to write a
      new program since the editor started fileless, so this is the path
      most people meet first. }
    kkSave: if ed.doc.name = '' then begin
      ed.mode := mdSaveAs;
      ed.prompt := ''
    end;
    { **Open asks for a name and Next is immediate.** Neither reads a file:
      one puts a question on the screen and the other is arithmetic over what
      is already open. }
    kkOpen: begin
      ed.mode := mdOpen;
      ed.prompt := ''
    end;
    kkNextDoc:
      if ed.docs < 2 then ed.says := 'only one document is open'
      else if ed.cur = ed.docs then EditGo(ed, 1)
      else EditGo(ed, ed.cur + 1);
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
var r, c, h, n, wide, pcol: integer; s: EditLine; row: ScreenRow;
    num: EditLine; k2: integer; kr: CellRole; prow: integer;
    ans: EditLine;
begin
  { The size the caller asked for, held to what this can draw. **Four rows is
    the least that has a document in it** since ADR-0389 -- the last three
    being the message, the status and the hint bar. }
  if rows > RowsMax then rows := RowsMax;
  if rows < 5 then rows := 5;
  if cols > ColsMax then cols := ColsMax;
  if cols < 8 then cols := 8;
  scr.rows := rows;
  scr.cols := cols;
  h := rows - 4;

  { Every cell is document text until something below says otherwise, which is
    why `crText` is the role's first value and why this is one loop rather
    than a rule at each site. }
  for r := 1 to rows do
    for c := 1 to cols do begin
      scr.cell[r][c] := ' ';
      scr.role[r][c] := crText
    end;

  { Scroll so the cursor is on screen. This is why the editor is a `var`
    parameter of a routine that only draws: where the window sits is a
    property of the last drawing and not of the document, and keeping it
    anywhere else would mean the caller had to know the height. }
  if ed.doc.row < ed.doc.top then ed.doc.top := ed.doc.row;
  if ed.doc.row > ed.doc.top + h - 1 then ed.doc.top := ed.doc.row - h + 1;
  if ed.doc.top < 1 then ed.doc.top := 1;

  { **And sideways** (ADR-0397), which is the same rule on the other axis and
    for the same reason: `left` is where the window sits and that is a
    property of the drawing. The cursor's *column* is what it follows, not its
    byte -- a line of Japanese scrolls by what a person sees. }
  if ed.doc.row <= ed.doc.lines.Len then
    n := ColumnOf(ed.doc.lines.At(ed.doc.row), ed.doc.col)
  else n := 1;
  if n < ed.doc.left then ed.doc.left := n;
  if n > ed.doc.left + cols - 1 then ed.doc.left := n - cols + 1;
  if ed.doc.left < 1 then ed.doc.left := 1;

  for r := 1 to h do begin
    n := ed.doc.top + r - 1;
    if n > ed.doc.lines.Len then s := '~'
    else s := ed.doc.lines.At(n);
    { **A line wider than the window scrolls now** (ADR-0397), where milestone
      one cut it and let the cursor stop at the edge. `PutLine` walks the line
      an element at a time and places each at `c - left + 1`, so what moved is
      where a cell is put and not how the line is read.

      The `~` filler is drawn at column one whatever the window has scrolled
      to: it says *past the end of the document* and is not text at a column,
      so scrolling it away would make a scrolled window look like a longer
      document. }
    if n > ed.doc.lines.Len then PutLine(scr, r + 1, s, cols, 1)
    else PutLine(scr, r + 1, s, cols, ed.doc.left)
  end;

  { The message line, or the question when one is open. **The cursor goes
    into the question**, because a person typing an answer has to see where
    it is going -- and that is the only thing on this screen that is not
    where the document says it is. }
  { **A message and a question are not the same row wearing one name.** The
    editor telling you what happened and the editor waiting for an answer are
    different states, and the role is what says which -- so the plane a golden
    holds changes when the mode does, and a prompt that failed to open is a
    visible difference rather than an invisible one. }
  { **A menu is a mode and is not a question**, so the message line stays a
    message while one is open -- the older test was `mode <> mdEdit`, which
    was exactly right while every mode was a prompt and became wrong the
    moment one was not. }
  { The message line is always a message now: a question is a *box*
    (ADR-0392) and no longer a line at the bottom. }
  for c := 1 to cols do scr.role[rows - 2][c] := crMessage;
  PutAt(scr, rows - 2, 1, Left(ed.says, cols), crMessage);

  { The status line, and it is the same shape a Turbo Pascal one was: what is
    being edited, whether it has been changed, and where the cursor is. }
  s := ed.doc.name;
  if s = '' then s := '(no name)';
  if ed.doc.dirty then s := s + ' *';
  { **Which document, when there is more than one** (ADR-0396). Absent while
    one is open, because a `1/1` on every screen is a number that never says
    anything; present the moment it can differ, which is the first time a
    person can be looking at a file they did not mean to. }
  if ed.docs > 1 then
    writestr(num, ed.cur:1, '/', ed.docs:1, ' ', ed.doc.row:1, ':',
             ed.doc.col:1)
  else writestr(num, ed.doc.row:1, ':', ed.doc.col:1);
  wide := cols - length(num);
  if wide < 1 then wide := 1;
  row := Left(s, wide);
  while length(row) < wide do row := row + ' ';
  for c := 1 to cols do scr.role[rows - 1][c] := crStatus;
  PutAt(scr, rows - 1, 1, Left(row + num, cols), crStatus);

  { **The hint bar** (ADR-0389). The bindings were discoverable by reading
    `tui/README.md`, which is not where a person sits when they are looking at
    the editor. It names the keys this editor has, which are control keys --
    Turbo Pascal's were function keys and those want decoder arms that do not
    exist yet, so this says what is true today rather than what it would like
    to say. It is cut to the window like everything else, so a narrow terminal
    loses the right-hand end rather than wrapping. }
  for c := 1 to cols do scr.role[rows][c] := crHint;
  PutAt(scr, rows, 1, Left(Hints, cols), crHint);

  { **A question is a framed box in the middle of the screen**, which is the
    second user of ADR-0391's primitives and the point of writing them: one
    user can be special-cased and two cannot. It is centred, three rows deep,
    and wide enough for its title -- and it is drawn *after* the document and
    *before* the menu, because a menu opened over a dialog would be the case
    that finally needs a stack and there is deliberately no way to reach it. }
  pcol := 0;
  if (ed.mode = mdFind) or (ed.mode = mdGoto) or (ed.mode = mdSaveAs)
     or (ed.mode = mdOpen) or (ed.mode = mdReplace) or (ed.mode = mdWith) then
  begin
    if ed.mode = mdFind then s := 'Find'
    else if ed.mode = mdReplace then s := 'Replace'
    else if ed.mode = mdWith then s := 'With'
    else if ed.mode = mdSaveAs then s := 'Save as'
    else if ed.mode = mdOpen then s := 'Open'
    else s := 'Go to line';
    wide := 34;
    if wide > cols - 4 then wide := cols - 4;
    if wide < length(s) + 6 then wide := length(s) + 6;
    n := (cols - wide) div 2 + 1;
    if n < 1 then n := 1;
    k2 := (rows - 3) div 2;
    if k2 < 2 then k2 := 2;
    Frame(scr, k2, n, 3, wide, s, crFrame);
    { **The answer is a field, and the field is the one thing on this screen
      that means *the editor is waiting for you*** (ADR-0393). Between
      ADR-0392 and this change `crPrompt` was written by nothing: the prompt
      stopped being a bottom line and became a box, and the box drew its
      contents in its own role -- so a role that is declared, mapped to a
      colour and given a letter in every golden was drawn on no screen, and
      every golden agreed. The whole line inside the frame takes it, so the
      field has edges even when nothing has been typed into it. }
    ans := Left(ed.prompt, wide - 4);
    while length(ans) < wide - 4 do ans := ans + ' ';
    PutAt(scr, k2 + 1, n + 2, ans, crPrompt);
    pcol := n + 2 + length(Left(ed.prompt, wide - 4));
    if pcol > cols then pcol := cols;
    prow := k2 + 1
  end;

  { **The menu bar, always on row 1**, which is where every editor of this
    shape put it. It costs the document a row and that is the trade: a person
    who cannot see that a menu exists does not go looking for one. }
  for c := 1 to cols do scr.role[1][c] := crMenu;
  for c := 1 to MenuCount do begin
    if (ed.mode = mdMenu) and (c = ed.menu) then kr := crChosen
    else kr := crMenu;
    PutAt(scr, 1, MenuAt(c), MenuTitle(c), kr)
  end;

  { ...and the drop-down under its title, which is the first thing on this
    screen that *overlaps* the document -- so it is the first row with two
    roles in it, and the first case `RowRuns` can get wrong. }
  if (ed.mode = mdMenu) and (ed.item > 0) then begin
    wide := 0;
    for c := 1 to MenuItems(ed.menu) do
      if length(ItemCaption(ed.menu, c)) > wide then
        wide := length(ItemCaption(ed.menu, c));
    Frame(scr, 2, MenuAt(ed.menu) - 1, MenuItems(ed.menu) + 2, wide + 4,
          '', crFrame);
    for c := 1 to MenuItems(ed.menu) do begin
      if c = ed.item then kr := crChosen else kr := crFrame;
      PutAt(scr, 2 + c, MenuAt(ed.menu), ' ' + ItemCaption(ed.menu, c) + ' ',
            kr)
    end
  end;

  if pcol > 0 then begin
    scr.atRow := prow;
    scr.atCol := pcol
  end
  else if ed.mode = mdMenu then begin
    { On the bar, or on the chosen item -- a person needs to see where they
      are even where the role plane already says it. }
    if ed.item = 0 then begin
      scr.atRow := 1;
      scr.atCol := MenuAt(ed.menu)
    end
    else begin
      scr.atRow := 2 + ed.item;
      scr.atCol := MenuAt(ed.menu) + 1
    end
  end
  else begin
    scr.atRow := ed.doc.row - ed.doc.top + 2;
    { **`ed.doc.col` is a byte and `atCol` is a column**, and this is the one line
      that converts between them (ADR-0395). The model counts bytes because
      every edit does and because `pascalc` reports a diagnostic's column in
      bytes -- so landing on an error means landing on a byte. What a terminal
      is told is where that byte *appears*. }
    if ed.doc.row <= ed.doc.lines.Len then
      scr.atCol := ColumnOf(ed.doc.lines.At(ed.doc.row), ed.doc.col)
                   - ed.doc.left + 1
    else scr.atCol := ed.doc.col
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
  while ed.doc.row > ln do EditKey(ed, k);
  k.kind := kkDown;
  while (ed.doc.row < ln) and (ed.doc.row < ed.doc.lines.Len) do EditKey(ed, k);
  k.kind := kkHome;
  EditKey(ed, k);
  k.kind := kkRight;
  while (ed.doc.col < cl) and (ed.doc.col <= length(ed.doc.lines.At(ed.doc.row))) do
    EditKey(ed, k)
end;

function EditFault;
var i, start, field, ln, cl: integer; part: EditLine; r: IntResult;
    who: EditLine; at: integer;
begin
  EditFault := false;
  start := 1;
  field := 0;
  ln := 0;
  cl := 0;
  who := '';
  for i := 1 to length(text) do
    if text[i] = chr(10) then
      { One line at a time, and the *first* that is a diagnostic wins: a
        compiler reports many and a person works on one. }
      exit
    else if (text[i] = ':') and (field < 3) then begin
      part := substr(text, start, i - start);
      start := i + 1;
      field := field + 1;
      { **Field one is the file the diagnostic is about, and it was thrown
        away**. The shell compiles `EditName(ed)`, so an error in
        the document itself names it -- but `pascalc` translates the other
        program-components too, and this compiler is three of them, so a
        diagnostic naming a file that is not the one on screen is the
        ordinary case rather than the corner. The cursor used to jump to that
        line number *here*, in whatever was open, and the message arrived
        looking like it had been landed on. }
      if field = 1 then who := part
      else if field = 2 then begin
        r := ParseInt(part);
        if not r.ok then exit;
        ln := r.val
      end
      else if field = 3 then begin
        r := ParseInt(part);
        if not r.ok then exit;
        cl := r.val;
        { A diagnostic about another file is **reported and not landed on**.
          Opening it is a second document and this editor holds one; until it
          holds two, the honest answer is to say where the error is and leave
          the cursor where the person left it. The message carries the
          position it names, because a line number with no file is the thing
          that was wrong before. }
        { **A diagnostic about another *open* document is landed on**
          (ADR-0396), which is what more than one document was for: this
          compiler is three program-components and building one of them
          reports about the others. A file that is not open is still reported
          and not jumped to -- opening it here would be this side reading a
          file, which is the shell's. }
        at := EditFind(ed, who);
        if at <> 0 then begin
          EditGo(ed, at);
          MoveTo(ed, ln, cl);
          ed.says := From(text, start + 1)
        end
        else ed.says := Left(text, start - 1) + From(text, start);
        EditFault := true;
        exit
      end
    end
end;

{ Which function key a CSI parameter names, or 0. **The numbering has gaps**
  -- 16 and 22 are not used -- and this is the table every terminal agrees on
  for the twelve; the SS3 spellings of F1 to F4 are handled where they arrive.
  Written out rather than computed, because the arithmetic that would produce
  it has two discontinuities and would be a puzzle at every reading. }
function FuncOf(par: EditLine): integer;
begin
  if par = '11' then FuncOf := 1
  else if par = '12' then FuncOf := 2
  else if par = '13' then FuncOf := 3
  else if par = '14' then FuncOf := 4
  else if par = '15' then FuncOf := 5
  else if par = '17' then FuncOf := 6
  else if par = '18' then FuncOf := 7
  else if par = '19' then FuncOf := 8
  else if par = '20' then FuncOf := 9
  else if par = '21' then FuncOf := 10
  else if par = '23' then FuncOf := 11
  else if par = '24' then FuncOf := 12
  else FuncOf := 0
end;

{ **A function key that is bound is the key it is bound to.** Which bytes mean
  which key is a question about a terminal, and the decoder is the one place
  that knows -- so F2 arrives as `kkSave` and F9 as `kkBuild`, and nothing
  above this has to learn that Turbo Pascal's Save has two spellings. The
  unbound ones keep their number and are *reported*, for `kkUnknown`'s reason:
  a key that does nothing and a key that was misread look alike to a person. }
procedure FuncKey(var k: Key; n: integer);
begin
  k.num := n;
  if n = 2 then k.kind := kkSave
  else if n = 3 then k.kind := kkOpen
  else if n = 6 then k.kind := kkNextDoc
  else if n = 9 then k.kind := kkBuild
  else if n = 10 then k.kind := kkMenu
  else k.kind := kkFunc
end;

procedure DecodeInit;
begin
  d.n := 0;
  d.par := ''
end;

function DecodeByte;
var b: integer;
begin
  DecodeByte := false;
  k.kind := kkNone;
  k.ch := ' ';
  k.num := 0;
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
    { **Two introducers, because terminals send both.** `ESC [` is CSI and
      `ESC O` is SS3, and F1 to F4 arrive as SS3 on most terminals while F5
      upwards arrive as CSI with a number -- which is why the older reading,
      that anything but `[` is an unknown key, lost every function key on
      every terminal at once. }
    else if (d.n = 2) and (c <> '[') and (c <> 'O') then begin
      d.n := 0;
      k.kind := kkUnknown;
      k.ch := c;
      DecodeByte := true
    end
    else if d.n = 2 then begin
      d.b[2] := c;
      d.par := ''
    end
    else if (d.n >= 3) and (d.b[2] = 'O') then begin
      { SS3, and one byte says which. }
      DecodeByte := true;
      d.n := 0;
      if (c >= 'P') and (c <= 'S') then FuncKey(k, ord(c) - ord('P') + 1)
      else begin
        k.kind := kkUnknown;
        k.ch := c
      end
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
      else if (c >= '0') and (c <= '9') and (length(d.par) < 4) then begin
        { A parameter is still coming: `ESC [ 3 ~` is Delete and
          `ESC [ 2 0 ~` is F9. Stay in the sequence, and *accumulate*. }
        d.n := 3;
        d.par := d.par + c;
        DecodeByte := false
      end
      else if c = '~' then begin
        if d.par = '3' then k.kind := kkDelete
        else if d.par = '1' then k.kind := kkHome
        else if d.par = '4' then k.kind := kkEnd
        else if FuncOf(d.par) > 0 then FuncKey(k, FuncOf(d.par))
        else begin
          k.kind := kkUnknown;
          k.ch := '?'
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
    else if b = 18 then k.kind := kkReplace   { Ctrl-R }
    else if b = 15 then k.kind := kkMenu      { Ctrl-O, for F10's sake }
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
