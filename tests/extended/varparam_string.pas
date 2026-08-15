{ ISO/IEC 10206:1991 §6.7.3.3 closes with *three* sentences, not two:

    An actual variable parameter shall not denote a field that is the selector
    of a variant-part. An actual variable parameter shall not denote a
    component of a variable where that variable possesses a type that is
    designated packed. An actual variable parameter shall not denote a
    component of a string-type.

  ISO 7185 §6.6.3.3 has only the first two and needs no third: every
  string-type there is a packed array of char, so the packed rule already
  reaches a component of one. What the third sentence adds is the
  *variable*-string, which is not packed and which ISO 7185 does not have.

  §6.5.3.2 is what makes `s[2]` a component of one: "An indexed-variable shall
  denote a component of a variable possessing an array-type or a string-type
  … The string-variable of an indexed-variable shall denote a variable
  possessing a variable-string-type."

  Without the rule this program compiled and printed `azcd`.

  The legal shapes come first, and the fixed-string one matters: it is caught
  by the *packed* sentence, so its message names the rule ISO 7185 also has. }
program VarParamString(output);

var
  s : string(10);
  f : packed array [1..4] of char;
  a : array [1..4] of char;
  n : integer;

procedure bump(var c : char);
begin
  c := 'z'
end;

procedure whole(var t : string);
begin
  n := length(t)
end;

begin
  s := 'abcd';
  a[1] := 'p';

  { Legal: a whole variable-string is not a component of anything. }
  whole(s);

  { Legal: an ordinary array's component is neither packed nor a string. }
  bump(a[1]);

  { §6.7.3.3, third sentence. }
  bump(s[2]);

  { §6.7.3.3, second sentence -- a fixed-string is packed, so this one names
    the rule ISO 7185 has too. }
  bump(f[1]);

  writeln(s, a[1], n:1)
end.
