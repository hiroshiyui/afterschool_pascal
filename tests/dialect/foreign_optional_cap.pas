{ ADR-0123: the capacity is what makes a returned pointer copyable, and a
  value that does not fit is an error rather than a truncation.

  It is 6.4.6's error and it is reported in 6.4.6's words, because it is the
  same rule -- a string longer than the capacity of the variable it is being
  stored into -- and the only difference is that this value came from further
  away. `pas_str_store_var` is the same routine an ordinary assignment uses. }
program foreign_optional_cap(output);

type Small = string(4);
     OptSmall = ?Small;

function getenv(name: string): OptSmall; external 'getenv';
function setenv(name, val: string; overwrite: integer): integer;
  external 'setenv';

var rc: integer;
    v: OptSmall;

begin
  { Written by the program, so the length is this file's and not the
    environment the harness happened to have. }
  rc := setenv('PASCAL_ADR0123_CAP', 'fits', 1);
  v := getenv('PASCAL_ADR0123_CAP');
  writeln('fits       = ''', v^, '''');

  rc := setenv('PASCAL_ADR0123_CAP', 'does not fit', 1);
  writeln('about to read a value longer than the capacity:');
  v := getenv('PASCAL_ADR0123_CAP');
  writeln('not reached ', v^)
end.
