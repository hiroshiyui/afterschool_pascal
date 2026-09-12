{ apconfig -- what `afterschool-pascal.toml` says, in a form a shell can read.

  `tools/pascalcc` is a shell script and a project file is TOML (ADR-0348), so
  the driver read its own configuration with 45 lines of `awk` implementing a
  deliberate subset: `[section]`, `key = "string"`, `key = ["a", "b"]`, `#` to
  the end of the line, and nothing else. That was the honest answer while this
  tree had no TOML reader. It has one now, and a hand-written subset of a
  format is exactly what `lib/dialect/pastoml.pas` exists to retire
  (ADR-0361).

  **The subset was not merely incomplete; it was wrong about documents it
  accepted.** It stripped from the first `#` to the end of the line before
  looking at anything, so `output = "build/demo#1"` silently became
  `build/demo`; and it split an array on every comma, so
  `ldflags = ["-Wl,-rpath,/opt/lib"]` -- one flag a person would really write
  -- was three malformed ones. A build file is the last place a reader should
  guess.

  **It writes one record per line, `key=value`, and nothing else.** The keys
  are the document's own spelling (`build.import-path`), an array is the same
  key repeated once per element in order, and a key that is not in the file
  produces no line at all. The caller therefore never parses TOML and never
  evaluates what this writes: `pascalcc` reads it with `read` and a `case`,
  which is what keeps a project file from being a way to run shell.

  **The schema lives here** rather than in the driver, because this is the
  half that knows *where* a key was written: a syntax error is reported as
  `file:line:column`, and an unknown or mistyped key is reported by name. A
  key nothing here knows is an error and never a silent no-op -- a misspelled
  key in a build file is otherwise found by the build being quietly wrong,
  which is the driver's rule everywhere else.

  Standard output carries the records and standard error carries the
  diagnostics, so a caller reads one and shows the other. }
program apconfig(output);

import PasError; PasFile; PasIO; PasToml;

const
  { The name a project file has (ADR-0348). Used when no argument names one,
    so that `apconfig` in a project directory answers about it. }
  DefaultFile = 'afterschool-pascal.toml';

  { The whole document is read into one string, so that `TomlPositionOf` can
    turn the byte the parser stopped at into a line and a column. A project
    file above this is refused rather than truncated: a reader that quietly
    read a prefix would report a syntax error at the cut. }
  DocMax = 65536;

  { A value as it is written out. Longer than any path, target triple or link
    flag; a document that exceeds it is told so by name. }
  ValueMax = 1024;

  { Room for `<section>.<key>` at the capacities `PasToml` gives a key, so
    that composing one cannot trap and every unknown key can be *named* in
    the message that refuses it. }
  DottedMax = 520;

  { The keys this driver acts on, and the whole of them. Ten, and each is
    what the compiler cannot infer: which source is the program, where the
    executable goes, the optimisation level, the target, the import paths and
    the two flag lists (ADR-0348). No key here lists a module, and none ever
    may -- the import graph is inferred. }
  KeyCount = 10;

type
  DocText = string(DocMax);
  ValueText = string(ValueMax);
  Dotted = string(DottedMax);

var
  { The schema as two parallel arrays: the dotted name, and whether the value
    is a list of strings rather than one. Filled by `Describe` below, which is
    the only place the set of keys is written down. }
  keyName: array [1..KeyCount] of Dotted;
  keyList: array [1..KeyCount] of boolean;
  keyFilled: integer;

  path: FilePath;
  text: DocText;
  buf: TomlChars;
  doc: TomlPtr;
  r: TomlResult;
  size, at: integer;

{ Standard error, which is the only stream a person reads here; standard
  output is the caller's. }
procedure Fail(what: IOLine);
var junk: ErrorCode;
begin
  junk := WriteText(StdErr, 'apconfig: ' + what + chr(10));
  halt(1)
end;

{ The same, for a byte position the parser stopped at. A configuration file's
  reader wants a line and a column, and that conversion is what `buf` is still
  alive for. }
procedure FailAt(atByte: integer; what: ErrText);
var line, col: integer; msg: IOLine;
begin
  buf.PositionOf(atByte, line, col);
  writestr(msg, path, ':', line:1, ':', col:1, ': ', what);
  Fail(msg)
end;

procedure Describe(name: Dotted; list: boolean);
begin
  keyFilled := keyFilled + 1;
  keyName[keyFilled] := name;
  keyList[keyFilled] := list
end;

{ Is this a key the driver acts on, and is its value a list? Answered from the
  table rather than from a chain of comparisons, so that the count above is
  the claim and `KeyCount` fails the program when the two disagree. }
function KnownKey(name: Dotted; var list: boolean): boolean;
var k: integer;
begin
  KnownKey := false;
  for k := 1 to KeyCount do
    if keyName[k] = name then begin
      list := keyList[k];
      KnownKey := true
    end
end;

{ One record. The value must be a string: TOML would read `opt = 2` happily
  and the driver wants `"-O2"`, so the refusal is about the schema and not
  about the format.

  A line break in a value would end the record early and give the caller a
  key it never asked about, so it is refused here rather than escaped -- a
  build file has no use for one, and a reader that invented an escape would
  need a caller that understood it. }
procedure Emit(key: Dotted; v: TomlPtr);
var s: ValueText; e: ErrorCode; k: integer;
begin
  if v.Kind <> tkString then
    Fail(path + ': ' + key + ' is written as a quoted string');
  e := v.TextInto(s);
  if Failed(e) then
    Fail(path + ': ' + key + ' is longer than this reader can carry');
  for k := 1 to length(s) do
    if s[k] = chr(10) then
      Fail(path + ': ' + key + ' holds a line break, which cannot be passed on');
  writeln(key, '=', s)
end;

{ The document, walked as it was written rather than looked up key by key: an
  unknown key is only findable by reading what is *there*, and reporting it is
  the whole reason this refuses a document the compiler would have survived. }
procedure ReadDocument;
var i, j, k: integer; sect, name: TomlKey; full: Dotted;
    v, w: TomlPtr; list: boolean;
begin
  for i := 1 to doc.Count do begin
    sect := doc.KeyAt(i);
    v := doc.At(i);
    if v.Kind <> tkTable then
      Fail(path + ': ' + sect + ' is a key outside any [section]');
    if (sect <> 'project') and (sect <> 'build') and (sect <> 'test') then
      Fail(path + ': unknown section [' + sect + ']');
    for j := 1 to v.Count do begin
      name := v.KeyAt(j);
      w := v.At(j);
      full := sect + '.' + name;
      if not KnownKey(full, list) then
        Fail(path + ': unknown key ' + full);
      if list then begin
        if w.Kind <> tkArray then
          Fail(path + ': ' + full + ' is written as a list of quoted strings');
        for k := 1 to w.Count do
          Emit(full, w.At(k))
      end
      else Emit(full, w)
    end
  end
end;

begin
  keyFilled := 0;
  Describe('project.name', false);
  Describe('project.version', false);
  Describe('build.program', false);
  Describe('build.output', false);
  Describe('build.opt', false);
  Describe('build.target', false);
  Describe('build.import-path', true);
  Describe('build.cflags', true);
  Describe('build.ldflags', true);
  Describe('test.expected', false);

  if argcount >= 1 then path := argument(1) else path := DefaultFile;
  if not ReadAllText(path, text, size) then
    Fail(path + ': there is nothing there to read');
  if size > DocMax then
    Fail(path + ': larger than this reader can hold');

  buf.Init;
  buf.AddText(text);
  r := TomlParseChars(buf, at);
  if not r.ok then FailAt(at, ErrorText(r.cause));
  doc := r.val;
  ReadDocument;
  doc.Free;
  buf.Free
end.
