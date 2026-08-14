program FileErrors(output, missing);

{ The rules that make a file type worth having are the ones that reject
  programs. A file is not a value: ISO 7185 gives it no assignment (§6.8.2.2),
  no relational operators (§6.7.2.5), and no way to be a value parameter
  (§6.6.3.3), because its position, its buffer and the operating system's
  handle are one object rather than something that can be copied. }

type
  rec = record a: integer end;
  { 6.6.3.2: "The type possessed by the formal-parameter shall be one that is
    permitted as the component-type of a file-type" -- so a type *containing*
    a file has no copy either, and is not a value parameter. }
  book = record id: integer; log: text end;
  logged = record
    a: integer;
    case tagged: boolean of
      { A variant's field is a component of the record too, so `file of logged`
        below is refused for the same reason a fixed field would refuse it.
        This arm is also refused *in its own right*: the arms share one block
        of storage and a file's storage is not just bytes — the runtime gives
        it a heap buffer and a place on the list of open files — so two arms
        holding files cannot both be set up at one address. §6.4.3.4 permits
        it and this compiler does not. }
      true:  (log: text);
      false: (b: integer)
  end;

var
  f, g: text;
  n: integer;
  r: rec;
  { 6.4.3.5: a file's component may be anything that is not itself a file, at
    any depth -- a file has no value to copy, so one inside another could not
    be read, written, or positioned. }
  nested: file of text;
  buried: file of array [1..2] of logged;

procedure ByValueRec(b: book);  { 6.6.3.2: and one that merely holds a file }
begin
end;

procedure ByValue(h: text);     { 6.6.3.2: a file must be a var parameter }
begin
end;

function Returns: text;         { 6.6.2: a result type must be simple }
begin
end;

begin
  f := g;                       { a file has no assignment }
  if f = g then n := 1;         { and no relational operators }
  read(f, r);                   { a record has no external representation }
  read(n + 1);                  { read needs somewhere to put what it reads }
  reset(n);                     { and reset needs a file }
  get(17);
  put(f, f);                    { put takes exactly one file }
  n := f^ + 1;                  { the buffer variable of a text file is char }
  new(f);                       { new needs a pointer }
  writeln(f, r)                 { a record cannot be written either }
end.
