program SetsInRecords(output);
{ A set is a *value* (ADR-0028), so it sits in a record like an integer does --
  and that is the one place the hand-written layout rules have to agree with
  LLVM's. A whole-record copy and `new` are the only two things that use
  LlSize/LlAlign, so a set that is measured as 16 bytes instead of 32, or
  aligned to 8 instead of 16, shows up here and nowhere else.

  The member at ordinal 250 is the point: it lives in the *top* 64 bits of the
  256-bit word, which is exactly what a short copy loses. }

type
  box = record
    tag: char;              { forces the set to a padded offset }
    s: set of char;
    trailer: integer        { so a short copy loses this too }
  end;
  link = ^box;

var
  a, b: box;
  p: link;
  high: char;

procedure Take(v: box);     { a value parameter is a copy of the whole record }
begin
  writeln('by value: ', v.tag, ' ', high in v.s, ' ', v.trailer:1)
end;

begin
  high := chr(250);
  a.tag := 'x';
  a.s := ['a', high];
  a.trailer := 4321;

  writeln('direct: ', a.tag, ' ', high in a.s, ' ', a.trailer:1);

  b := a;                   { whole-variable assignment: a memcpy of LlSize }
  writeln('copied: ', b.tag, ' ', high in b.s, ' ', b.trailer:1);

  Take(a);

  new(p);                   { a heap block of LlSize bytes }
  p^ := a;
  writeln('heap: ', p^.tag, ' ', high in p^.s, ' ', p^.trailer:1);
  { and the parts of it are still reachable one at a time }
  p^.s := p^.s + ['z'];
  writeln('grown: ', 'z' in p^.s, ' ', high in p^.s, ' ', 'a' in p^.s);
  dispose(p);

  { a set inside an array of records, so the stride depends on the size too }
  writeln('done')
end.
