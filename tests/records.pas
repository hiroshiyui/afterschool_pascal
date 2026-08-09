program Records(output);

{ Records, nesting in both directions (a record of arrays, an array of
  records), whole-record assignment, and the `with` statement. }

type
  date = record
    day, month: integer;
    year: integer
  end;

  point = record
    x, y: real
  end;

  person = record
    initial: char;
    born: date;         { a record inside a record }
    scores: array [1..3] of integer
  end;

  roster = array [1..2] of person;   { and an array of records }

var
  d, e: date;
  p: person;
  team: roster;
  q: point;
  i: integer;

procedure ShowDate(when: date);
begin
  write(when.day:2, '/', when.month:2, '/', when.year:5)
end;

procedure Advance(var when: date);
begin
  when.year := when.year + 1
end;

begin
  d.day := 9;
  d.month := 8;
  d.year := 2026;
  write('d = ');
  ShowDate(d);
  writeln;

  { A whole record is copied, component by component. }
  e := d;
  d.year := 1970;
  write('e = ');
  ShowDate(e);
  writeln;

  Advance(e);
  write('advanced: ');
  ShowDate(e);
  writeln;

  { `with` makes the fields visible as bare names. }
  with q do
    begin
      x := 1.5;
      y := -2.5
    end;
  writeln('q = ', q.x:5:2, ' ', q.y:6:2);

  p.initial := 'A';
  p.born := e;
  for i := 1 to 3 do
    p.scores[i] := i * 7;

  { Nested with: the inner one shadows nothing here, but reaches two deep. }
  with p, born do
    writeln('p: ', initial, ' born ', year:5, ' first score ', scores[1]);

  team[1] := p;
  team[2].initial := 'B';
  team[2].born.year := 1999;
  team[2].scores[3] := 42;

  for i := 1 to 2 do
    with team[i] do
      writeln('team[', i, '] = ', initial, ' ', born.year:5, ' ',
              scores[3]:3)
end.
