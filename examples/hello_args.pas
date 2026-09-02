{ Hello, with arguments.

  Turbo Pascal had ParamCount and ParamStr; here they are `argcount` and
  `argument(k)` (AP 6.7.6.10), and `argument(k)` is an ordinary string.
  Nothing is imported. Run it as

      pascalcc hello_args.pas -o hello_args && ./hello_args /tmp/a.txt b

  The test harness runs every case with two scratch paths in a directory
  of its own, so what is printed is the count and the last component of
  each path -- never the directory, which differs on every run. }
program hello_args(output);

type Name = string(255);

var k: integer;

{ The part of a path after its last '/'. `s[i..j]` is Extended Pascal's
  substring (6.5.6); `string` as a parameter type takes a value of any
  capacity, so a literal or `argument(k)` both fit. }
function BaseName(path: string): Name;
var i: integer;
begin
  i := length(path);
  while (i > 0) and (path[i] <> '/') do
    i := i - 1;
  BaseName := path[i + 1..length(path)]
end;

begin
  writeln('Hello from a program given ', argcount:1, ' argument(s).');
  for k := 1 to argcount do
    writeln('  ', k:1, ': ', BaseName(argument(k)))
end.
