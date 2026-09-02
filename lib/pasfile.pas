{ PasFile -- whole files, by name.

  §6.10's `bind`, `reset`, `rewrite` and `extend` already create, read and
  append a file named at run time; what a program had to write out each time
  was the binding, the loop and the eoln bookkeeping, and what it could not
  do at all was find out that a file was missing without stopping. ADR-0172
  gave it the question: `binding(f).bound` is true when the named entity
  exists, asked at the moment of asking. Every routine here that reads asks
  it first and answers false instead of stopping.

  **What "false" means, and what it does not.** False is "nothing is there".
  A file that is there but cannot be opened -- permission, a directory where
  a file was named -- still stops the program at `reset`, because §6.10's
  file procedures have no result and a stop is what a failed open is. The
  routines that write never answer at all: `rewrite` creates and `extend`
  appends whether or not the file existed, and a failure of either is the
  same stop.

  **Lines are what text files hold, and they are capped.** A line longer
  than `FileLineMax` is delivered truncated to it, and the remainder of that line
  is skipped -- `readln` does that -- so a routine over lines never stops on
  a long one and never reports it either. `ReadAllText` is the one routine
  that can say it ran out of room: `size` is the whole file's length, so the
  caller compares it with `dest.capacity`.

  **This is the portable layer** (ADR-0114, ADR-0120) in what it answers --
  unable to name an error code because `PasError` is on the other side of
  the line; the dialect's `PasFS` removes and renames, this one reads and
  writes. It is no longer ISO/IEC 10206:1991 throughout, and has not been
  since AP 6.4.3.4.7's `writable` (ADR-0240) gave the writers something to
  answer with. AP 6.5.1 (ADR-0299) is the second thing it takes from the
  dialect, and it is why the module got **shorter**: every file variable is
  bindable, so the file a routine binds crosses into a helper as `var f: text`
  and the binding is written once. Until then a `var f: text` formal was
  refused by `bind` -- §6.4.1 puts the word in the declaration -- and the four
  writers were one routine with two flags, the helper taking the *job* because
  it could not take the file. (The spelling `type BText = bindable text;
  var f: BText` would have crossed all along, §6.4.1 letting a type-name hand
  the word on; nobody here probed it, which ADR-0299 records.) }

module PasFile;

export PasFile = (PathMax, FilePath, FileLineMax, FileLine,
                  FileExists, LineCount, ReadLine, ForEachLine, ReadAllText,
                  WriteAllText, WriteLine, AppendLine, AppendText, CopyFile);

const
  PathMax = 255;
  FileLineMax = 255;

type
  FilePath = string(PathMax);
  FileLine = string(FileLineMax);

{ Whether something is there under that name. Exactly `binding(f).bound`
  after a `bind`, which is E.16's rule: existence, not readability. }
function FileExists(path: FilePath): boolean;

{ How many lines the file has, or false when nothing is there. An empty file
  has none; a file whose last line ends without a line terminator has that
  line counted, §6.4.3.5 making a text file a sequence of lines. }
function LineCount(path: FilePath; var count: integer): boolean;

{ Line number `n`, counting from 1, into `line`. False when nothing is there
  or the file has fewer than `n` lines, and `line` is then left alone. }
function ReadLine(path: FilePath; n: integer; var line: FileLine): boolean;

{ Hand every line to `visit` in order. False, and no call, when nothing is
  there. §6.7.3.4's procedural parameter is what makes this possible without
  a container for the lines: the caller's procedure sees each one as it is
  read and keeps what it wants. }
function ForEachLine(path: FilePath;
                     procedure visit(line: FileLine)): boolean;

{ The whole file into `dest`, every line terminator as chr(10), and `size`
  the length the whole file has -- so `size > dest.capacity` is how the caller
  learns that `dest` holds a prefix. `dest` may be a string of any capacity.
  False, with `dest` and `size` left alone, when nothing is there. }
function ReadAllText(path: FilePath; var dest: string;
                     var size: integer): boolean;

{ **Every writer here answers whether it wrote**, and until AP 6.4.3.4's
  `writable` field there was nothing for them to answer with (ADR-0240): a
  `rewrite` at a path that cannot be created is a run-time error and *stops
  the program*, so these four were procedures that could not fail and did.
  Five sites in one module is what made the field a demand rather than an
  idea (ADR-0116).

  False means nothing was written and nothing was truncated -- the file is
  left exactly as it was found. It is a probe and not a promise, exactly as
  `bound` is one, so a disc that fills mid-write still stops the program;
  what it covers is every failure the *path* can be blamed for. }

{ Create or truncate the file and write `content` to it, a chr(10) in `content`
  becoming a line terminator. A `content` that does not end in one leaves the
  last line unterminated on the stream; §6.4.3.5 will supply one when the
  file is read back, so `ReadAllText` after `WriteAllText(p, 'a')` reads two
  characters. }
function WriteAllText(path: FilePath; content: string): boolean;

{ Create or truncate the file and write one terminated line. }
function WriteLine(path: FilePath; line: string): boolean;

{ Add one terminated line at the end, creating the file if nothing is there. }
function AppendLine(path: FilePath; line: string): boolean;

{ Add `content` at the end, as WriteAllText writes it, creating the file if
  nothing is there. }
function AppendText(path: FilePath; content: string): boolean;

{ Copy `src` to `dst`, line by line, creating or truncating `dst`. False, and
  `dst` untouched, when nothing is at `src` **or nothing can be written at
  `dst`** -- the second was a stopped program until AP 6.4.3.4, and the one
  this routine's `boolean` had always looked as though it covered. A copy, not
  a rename: the dialect has `PasFS.Rename` for that. }
function CopyFile(src, dst: FilePath): boolean;

end;

{ Every routine binds a local file variable to the name it was given and asks
  before opening; the variable is unbound on the way out, which also closes it
  (§6.7.5.6's "totally-undefined"). Binding a local rather than a module-level
  variable is what makes every routine re-entrant: `visit` in ForEachLine may
  itself call into this module.

  The three helpers take the file itself. AP 6.5.1 makes a `var f: text`
  formal bindable as it stands, so the binding is written here once and each
  routine says only which question it asks of it. }

{ Bind `f` to `path` and nothing more: a name attached, no external entity
  looked at. }
procedure Attach(var f: text; path: FilePath);
var b: BindingType;
begin
  b := binding(f);
  b.name := path;
  bind(f, b)
end;

{ Attach, and say whether something is there under that name -- E.16's
  `bound`, existence and not readability. The file is left bound either way,
  so a caller that reads on a true answer resets the file it asked about. }
function Found(var f: text; path: FilePath): boolean;
begin
  Attach(f, path);
  Found := binding(f).bound
end;

{ Attach and open for writing, `append` choosing `extend` over `rewrite`.
  False when nothing can be written at that name (AP 6.4.3.4.7, ADR-0240),
  and then nothing is opened and `f` is unbound again -- so a file that was
  already there is not truncated by a call that then fails. }
function Opened(var f: text; path: FilePath; append: boolean): boolean;
begin
  Attach(f, path);
  if binding(f).writable then begin
    if append then extend(f) else rewrite(f);
    Opened := true
  end
  else begin
    unbind(f);
    Opened := false
  end
end;

function FileExists;
var f: text;
begin
  FileExists := Found(f, path);
  unbind(f)
end;

function LineCount;
var f: text; n: integer;
begin
  if Found(f, path) then begin
    reset(f);
    n := 0;
    while not eof(f) do begin
      readln(f);
      n := n + 1
    end;
    count := n;
    LineCount := true
  end
  else
    LineCount := false;
  unbind(f)
end;

function ReadLine;
var f: text; k: integer; got: boolean;
begin
  got := false;
  if Found(f, path) and (n >= 1) then begin
    reset(f);
    k := 1;
    while (k < n) and not eof(f) do begin
      readln(f);
      k := k + 1
    end;
    if not eof(f) then begin
      readln(f, line);
      got := true
    end
  end;
  ReadLine := got;
  unbind(f)
end;

function ForEachLine;
var f: text; l: FileLine;
begin
  if Found(f, path) then begin
    reset(f);
    while not eof(f) do begin
      readln(f, l);
      visit(l)
    end;
    ForEachLine := true
  end
  else
    ForEachLine := false;
  unbind(f)
end;

function ReadAllText;
var f: text; n: integer; c: char;
begin
  if Found(f, path) then begin
    reset(f);
    dest := '';
    n := 0;
    { Character by character rather than line by line, so that a line longer
      than FileLineMax is not the one thing this routine silently loses. }
    while not eof(f) do begin
      if eoln(f) then begin
        c := chr(10);
        readln(f)
      end
      else
        read(f, c);
      n := n + 1;
      if n <= dest.capacity then
        dest := dest + c
    end;
    size := n;
    ReadAllText := true
  end
  else
    ReadAllText := false;
  unbind(f)
end;

{ `content` onto an open file, a chr(10) becoming writeln. Shared by the four
  writers, which differ only in how the file was opened and whether a line
  terminator follows. }
procedure PutText(var f: text; content: string);
var i: integer;
begin
  for i := 1 to length(content) do
    if content[i] = chr(10) then writeln(f)
    else write(f, content[i])
end;

{ The four writers, each written out: open through `Opened`, write, unbind.
  They were one routine with two flags until AP 6.5.1, because the helper
  could not take the file -- see the header. }

function WriteAllText;
var f: text;
begin
  if Opened(f, path, false) then begin
    PutText(f, content);
    unbind(f);
    WriteAllText := true
  end
  else
    WriteAllText := false
end;

function WriteLine;
var f: text;
begin
  if Opened(f, path, false) then begin
    PutText(f, line);
    writeln(f);
    unbind(f);
    WriteLine := true
  end
  else
    WriteLine := false
end;

function AppendLine;
var f: text;
begin
  if Opened(f, path, true) then begin
    PutText(f, line);
    writeln(f);
    unbind(f);
    AppendLine := true
  end
  else
    AppendLine := false
end;

function AppendText;
var f: text;
begin
  if Opened(f, path, true) then begin
    PutText(f, content);
    unbind(f);
    AppendText := true
  end
  else
    AppendText := false
end;

function CopyFile;
var i, o: text; c: char;
begin
  { The source has to exist and the destination has to be creatable, and the
    two are different questions with different fields: `bound` for the read
    (E.16) and AP 6.4.3.4's `writable` for the write. Asked in that order and
    both before anything is opened, so a refusal leaves both files alone --
    which the destination's `rewrite` would not have, having truncated it
    before the source was found wanting. }
  if Found(i, src) then begin
    if not Opened(o, dst, false) then begin
      unbind(i);
      exit(false)
    end;
    reset(i);
    { Character by character, for ReadAllText's reason: nothing is lost to
      FileLineMax. }
    while not eof(i) do begin
      if eoln(i) then begin
        writeln(o);
        readln(i)
      end
      else begin
        read(i, c);
        write(o, c)
      end
    end;
    unbind(o);
    CopyFile := true
  end
  else
    CopyFile := false;
  unbind(i)
end;

end.
