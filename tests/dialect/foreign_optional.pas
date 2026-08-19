{ ADR-0123's reason for existing: a foreign function may answer a pointer, and
  the pointer may be null.

  ADR-0122 refused the whole result direction over exactly this. `getenv` of a
  name that is not set answers NULL in the ordinary course of things -- it is
  not a failure and there is nothing to report -- so copying from it would have
  had to trap on a normal answer, and answering the empty string would have
  conflated "not set" with "set to nothing". An optional is where null lives,
  and the C pointer never becomes a Pascal value: the copy is made at the call
  site and what the program holds is a string of its own.

  The environment is written by the program first, with `setenv`, so nothing
  here depends on how the harness was started. `setenv` and not `putenv`: the
  second one *keeps* the pointer it is handed, which is the hazard
  doc/sop.md §7 records and which this compiler's arena would lose at the end
  of the statement. }
program foreign_optional(output);

type
  EnvText = string(64);
  OptValue = ?EnvText;

{ 6.7.2 makes a result-type a type-identifier, so the optional is named rather
  than written out here -- which reads better anyway. }
function getenv(name: string): OptValue; external 'getenv';
function setenv(name, val: string; overwrite: integer): integer;
  external 'setenv';
function unsetenv(name: string): integer; external 'unsetenv';
function strerror(code: integer): OptValue; external 'strerror';

var v: OptValue;
    rc: integer;

procedure Show(what: string(10); o: OptValue);
begin
  write(what, ' = ');
  if o = nil then writeln('(unset)') else writeln('''', o^, '''')
end;

begin
  Show('before   ', getenv('PASCAL_ADR0123'));

  rc := setenv('PASCAL_ADR0123', 'a value', 1);
  writeln('setenv     = ', rc:1);
  Show('after    ', getenv('PASCAL_ADR0123'));

  { An empty value is *set*, and is not the same answer as unset. That is the
    distinction a language without an optional type cannot make. }
  rc := setenv('PASCAL_ADR0123', '', 1);
  v := getenv('PASCAL_ADR0123');
  writeln('empty set  = ', (v <> nil), ' length ', length(v^):1);

  rc := unsetenv('PASCAL_ADR0123');
  Show('unset    ', getenv('PASCAL_ADR0123'));

  { A routine that never answers null, read without asking -- which is allowed
    and is still checked, exactly as a pointer dereference is. The text is a
    property rather than a string: strerror's wording belongs to the C library
    and to the locale, so asserting it would be asserting someone else's
    message (the care ADR-0076 took over the real constants). }
  writeln('strerror   = ', (length(strerror(2)^) > 0))
end.
