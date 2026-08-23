{ §6.7.3.4 and §6.7.3.5: a procedural or functional parameter whose own
  formal is a variable-string *value* parameter. ADR-0115 makes such a
  parameter travel as a pair -- the value's address and its length -- and the
  callee's prologue pads it into its own slot. A call through a procedural
  parameter has to state the callee's type, and the writer it used was a copy
  of the one the defining side uses that had not learned the pair: it wrote
  `void (ptr, ptr)` where the call passed three arguments, and clang refused
  the module. Nothing in the corpus had handed a string-taking procedure to
  another procedure. A library wanting `ForEachLine(path, visit)` did. }
program procparam_string(output);
type line = string(12);

procedure each(procedure visit(l: line));
begin
  visit('hello');
  visit('a longer one');   { exactly the capacity }
  visit('')
end;

procedure show(l: line);
begin writeln('[', l, '] ', length(l):1) end;

{ §6.7.3.5's functional parameter, with a string formal and a string result }
function twice(function f(s: line): line): line;
begin twice := f(f('ab')) end;

function dup(s: line): line;
begin dup := s + s end;

{ and a fixed string, which 6.7.3.2 pads at the call (ADR-0171) }
type five = packed array [1..5] of char;
procedure padded(procedure p(s: five));
begin p('xy') end;
procedure showfive(s: five);
begin writeln('[', s, ']') end;

begin
  each(show);
  writeln(twice(dup));
  padded(showfive)
end.
