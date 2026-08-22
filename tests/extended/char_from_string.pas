{ ISO/IEC 10206:1991 6.4.6 f): a value of a string-type may be assigned to a
  variable of the *char-type*. The clause names both -- "T1 and T2 are
  compatible, T1 is a string-type or the char-type, and the length of the value
  of T2 is less than or equal to the capacity of T1" -- and 6.4.5 d) makes a
  string-type and the char-type compatible in either order, so every spelling
  below is a legal assignment and not a coincidence.

  This is Extended Pascal only. ISO 7185 has no such rule: there `c := f` over
  a `packed array [1..1] of char` is refused in both directions, and the case
  under tests/ that would say so cannot be written, because the refusal is
  Sema's and this file is about what CodeGen emits after Sema accepts.

  Every line here compiled to `store i8 <a ptr>, ptr ...` before the fix -- IR
  that clang refuses -- except the substring, which stored chr(0) and said
  nothing. }
program char_from_string(output);

type
  fixed1 = packed array [1..1] of char;

var
  c: char;
  s: string(10);
  v: string(10);
  f: fixed1;
  empty: string(4);

{ A function result is a string value with no variable behind it. }
function initial: string(3);
begin
  initial := 'q'
end;

begin
  s := 'hello';
  v := 'z';
  f := 'k';
  empty := '';

  { A substring of length one. This was the silent case: chr(0), exit 0. }
  c := s[2..2];
  write(c);

  { A variable-string holding one character. }
  c := v;
  write(c);

  { A fixed-string-type of capacity one. }
  c := f;
  write(c);

  { A one-character literal is already a char (6.1.7), so this arm never
    reached the string path and never was broken -- it is here so that a
    change breaking it is caught beside the ones that were. }
  c := 'L';
  write(c);

  { 6.7.6.7's substr, whose result is a string value. }
  c := substr(s, 4, 1);
  write(c);

  { A function-access. }
  c := initial;
  write(c);

  { A concatenation (6.8.3.2). }
  c := v + '';
  write(c);

  { 6.7.6.6's trim. }
  c := trim(v);
  write(c);

  { 6.4.6's last paragraph pads a shorter value with spaces to the capacity of
    the destination, and a char has capacity 1 -- so the null-string gives a
    space rather than being an error. }
  c := empty;
  write('[', c, ']');

  writeln
end.
