{ A defer-statement in a module's initialization: armed and run there, before
  the program's block commences (AP 6.9.3.11, 6.2.3.6). }
program defer_module(output);

import defer_counter;

begin
  writeln('program: n is ', Count:1);
  defer writeln('program: deferred');
  writeln('program: body')
end.
