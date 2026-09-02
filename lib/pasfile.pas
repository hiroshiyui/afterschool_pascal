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

  **This is the portable layer** (ADR-0114, ADR-0120): ISO/IEC 10206:1991
  throughout, so it would compile under another Extended Pascal as well as
  under this one, and unable to name an error code because `PasError` is on
  the other side of the line. The dialect's `PasFS` removes and renames; this one reads and
  writes. }

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
  before opening for reading; the variable is unbound on the way out, which
  also closes it (§6.7.5.6's "totally-undefined"). Binding a local rather than
  a module-level variable is what makes every routine re-entrant: `visit` in
  ForEachLine may itself call into this module. }

function FileExists;
var f: bindable text; b: BindingType;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  FileExists := binding(f).bound;
  unbind(f)
end;

function LineCount;
var f: bindable text; b: BindingType; n: integer;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  if binding(f).bound then begin
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
var f: bindable text; b: BindingType; k: integer; found: boolean;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  found := false;
  if binding(f).bound and (n >= 1) then begin
    reset(f);
    k := 1;
    while (k < n) and not eof(f) do begin
      readln(f);
      k := k + 1
    end;
    if not eof(f) then begin
      readln(f, line);
      found := true
    end
  end;
  ReadLine := found;
  unbind(f)
end;

function ForEachLine;
var f: bindable text; b: BindingType; l: FileLine;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  if binding(f).bound then begin
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
var f: bindable text; b: BindingType; n: integer; c: char;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  if binding(f).bound then begin
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

{ `content` onto an open file, a chr(10) becoming writeln. Shared by the two
  whole-text writers, which differ only in how the file was opened. }
procedure PutText(var f: text; content: string);
var i: integer;
begin
  for i := 1 to length(content) do
    if content[i] = chr(10) then writeln(f)
    else write(f, content[i])
end;

{ The whole of what the four exported writers do, and they are one routine
  with two flags because they could not be four routines sharing a check.

  **A bindable file cannot cross a parameter.** §6.4.1 makes `bindable` part
  of a *variable-declaration* and not of a type-denoter, so there is no formal
  parameter that accepts one -- `var f: text` compiles and then `bind(f, b)`
  is refused, *"only a variable whose type-denoter says 'bindable' can be
  bound to something outside the program"*. A helper taking the file was the
  obvious shape and is unwritable, so the helper takes the job instead: one
  bindable variable, one check, four callers. }
function Written(path: FilePath; content: string;
                 append, terminated: boolean): boolean;
var f: bindable text; b: BindingType;
begin
  b := binding(f);
  b.name := path;
  bind(f, b);
  { AP 6.4.3.4 (ADR-0240). Nothing is opened on the refusal path, so a file
    that was already there is not truncated by a call that then fails. }
  if not binding(f).writable then begin
    unbind(f);
    exit(false)
  end;
  if append then extend(f) else rewrite(f);
  PutText(f, content);
  if terminated then writeln(f);
  unbind(f);
  Written := true
end;

function WriteAllText;
begin
  WriteAllText := Written(path, content, false, false)
end;

function WriteLine;
begin
  WriteLine := Written(path, line, false, true)
end;

function AppendLine;
begin
  AppendLine := Written(path, line, true, true)
end;

function AppendText;
begin
  AppendText := Written(path, content, true, false)
end;

function CopyFile;
var i, o: bindable text; bi, bo: BindingType; c: char;
begin
  bi := binding(i);
  bi.name := src;
  bind(i, bi);
  { The source has to exist and the destination has to be creatable, and the
    two are different questions with different fields: `bound` for the read
    (E.16) and AP 6.4.3.4's `writable` for the write. Asked in that order and
    both before anything is opened, so a refusal leaves both files alone --
    which the destination's `rewrite` would not have, having truncated it
    before the source was found wanting. }
  if binding(i).bound then begin
    bo := binding(o);
    bo.name := dst;
    bind(o, bo);
    if not binding(o).writable then begin
      unbind(o);
      unbind(i);
      exit(false)
    end;
    reset(i);
    rewrite(o);
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
