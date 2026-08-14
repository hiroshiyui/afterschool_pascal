{ ISO/IEC 10206:1991 6.5.1 and 6.7.6.8 NOTE 2: a program can read the binding
  it was started with.

  Two clauses meet here, and neither was implemented until this program was
  written -- in either compiler, and with every oracle agreeing, because no
  program in the corpus had ever asked a program-parameter about its binding.

  6.5.1 is the first: "The variable-identifier shall possess the bindability
  denoted by the type-denoter, unless the variable-identifier is a
  program-parameter or a module-parameter, in which case the
  variable-identifier shall possess the bindability that is bindable." So none
  of the parameters below says `bindable` and all of them are; writing the word
  is not how a program-parameter becomes bindable, being one is. This compiler
  used to refuse `binding(a)` here with "'a' is not bindable".

  6.7.6.8 NOTE 2 is the second: the value binding returns "can also be used to
  determine the result of any binding of program-parameters prior to activation
  of the main program (see 6.12)". So a parameter that was given a command-line
  argument is *bound*, and its name is that argument. The runtime answered
  false and an empty name.

  Together they are the only channel either standard gives a program to its own
  command line. 6.10 and 6.12 bind the program-parameters before the program is
  activated and offer nothing else -- which is why the compiler in
  selfhost/compiler.pas takes the standard it is compiling for as a *file*
  (ADR-0033). This is what could replace that.

  What it cannot assert is the argument text: the harness passes two paths in a
  temporary directory that differs every run. So the properties are asserted
  instead -- bound or not, how long, and how the name ends -- which is the same
  care ADR-0076 took over the required real constants and ADR-0065 over the
  clock. }
program BindProgParam(output, a, b, c);

var
  { No `bindable` on any of these, which is the point: 6.5.1 confers it. }
  a, b, c: text;
  bnd: BindingType;
  n: integer;

{ Write the last k characters of a string, or the whole of it when it is
  shorter. 6.7.6.7's substr is an error when the range leaves the string, so
  the length is tested first rather than the result clamped afterwards.

  A procedure rather than a function because 6.7.2 makes a result-type a
  type-name: the canonical-string-type has no name to write, and naming a
  fixed capacity would be the wrong type to return. It still never writes down
  the implementation-defined capacity that BindingType's `name` field has.

  It takes the *record* and not the field, and that is the standard's doing
  rather than a preference. 6.4.3.4 requires BindingType to be "a record-type
  designated packed", and 6.7.3.3 says an actual variable parameter "shall not
  denote a component of a variable where that variable possesses a type that is
  designated packed" -- so `WriteTail(bnd, 5)` is not a legal call, and
  this file made it twice from the day it was written (ADR-0052) with every
  oracle agreeing. A whole packed variable may be passed by reference; only a
  component may not.

  What that costs is the schematic formal `var s: string` this took before,
  which tests/extended/string.pas demonstrates instead. `var` rather than a
  value parameter is still ADR-0052's rule: a variable-string by value would
  have to convert its argument. }
procedure WriteTail(var b: BindingType; k: integer);
begin
  if length(b.name) < k then write(b.name)
  else write(substr(b.name, length(b.name) - k + 1, k))
end;

begin
  { --- the arguments the harness supplied ---------------------------------- }
  bnd := binding(a);
  writeln('a bound: ', bnd.bound);
  write('a name ends: '); WriteTail(bnd, 5); writeln;
  { The name is a real path the harness chose, so its length varies; that it is
    non-empty is the part that is the feature. }
  writeln('a name non-empty: ', length(bnd.name) > 0);

  bnd := binding(b);
  writeln('b bound: ', bnd.bound);
  write('b name ends: '); WriteTail(bnd, 5); writeln;

  { --- one the harness did not supply -------------------------------------- }
  { 6.12's NOTE 2: a program-parameter is "not necessarily bound when the
    program is activated". Nothing was passed for `c`, so it is unbound -- and
    that is how a program counts the arguments it was given, there being no
    other way to ask. }
  bnd := binding(c);
  writeln('c bound: ', bnd.bound);
  writeln('c name length: ', length(bnd.name):1);

  n := 0;
  if binding(a).bound then n := n + 1;
  if binding(b).bound then n := n + 1;
  if binding(c).bound then n := n + 1;
  writeln('arguments given: ', n:1);

  { --- unbind clears the binding made before activation --------------------- }
  { 6.7.5.6: "If the attempt is successful, the variable shall become
    totally-undefined." Not bound to anything is part of that, and it has to
    include a binding the program did not make -- otherwise `bound` would stay
    true with nothing behind it. }
  unbind(a);
  writeln('a bound after unbind: ', binding(a).bound);

  { --- and the program may bind one to a name it computed ------------------- }
  bnd := binding(a);
  bnd.name := '/tmp/apascal_bindprogparam.txt';
  bind(a, bnd);
  bnd := binding(a);
  writeln('a rebound: ', bnd.bound, ' ', bnd.name);
  rewrite(a);
  writeln(a, 'written through a rebound program parameter');
  reset(a);
  readln(a, bnd.name);
  writeln('read back: ', bnd.name);
  unbind(a);
  writeln('a bound at the end: ', binding(a).bound)
end.
