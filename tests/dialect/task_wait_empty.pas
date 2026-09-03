{ AP 6.9.3.14: waiting on an empty task-variable is an error (ADR-0312).

  It is the treatment `send` gives an empty channel-variable and it reaches
  the same routine, AP 6.4.12.4's lend, which is why the message is that one.
  Answering quietly was the alternative and it is worse: a variable a program
  forgot to spawn into would then read as a task that had finished, which is
  the answer a program wants least. Releasing an empty handle stays harmless,
  and so does waiting twice -- what is refused is asking about an activation
  that was never commenced. }
program task_wait_empty(output);
var t: task;
begin
  writeln('before');
  wait(t);
  writeln('after')
end.
