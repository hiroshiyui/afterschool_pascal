program FileErrors(output, missing);

{ The rules that make a file type worth having are the ones that reject
  programs. A file is not a value: ISO 7185 gives it no assignment (§6.8.2.2),
  no relational operators (§6.7.2.5), and no way to be a value parameter
  (§6.6.3.3), because its position, its buffer and the operating system's
  handle are one object rather than something that can be copied. }

type
  rec = record a: integer end;

var
  f, g: text;
  n: integer;
  r: rec;
  binary: file of integer;      { only text files are implemented }

procedure ByValue(h: text);     { 6.6.3.3: a file must be a var parameter }
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
