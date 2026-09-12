{ PasNet: a TCP connection, over the loopback interface, in one program
  (ADR-0203).

  **This talks to itself, and it has to.** Every other oracle here compares
  what a program printed; a network test that needed a second machine, or a
  server left running, would be a test of the environment. A listening socket
  and a connection to it live in one activation, and the whole exchange is
  four calls -- which works because `listen` completes the handshake in the
  backlog before anything calls `accept`, so a single thread of control can be
  both ends. That is also the honest limit of the module: serving two clients
  at once needs something this language has not got (ADR-0201).

  **No port number appears in the output.** The program asks for service `'0'`,
  which is "whatever is free", and `s.Service` reports back the numeric string
  that `NetConnect` then takes -- so what is printed is that a port was given and
  never which. A test that named one would fail on a machine where something
  else held it.

  The last three blocks are the failures a caller must be able to tell apart:
  the far end closing (`errAbsent`, the ordinary end of a loop), a line longer
  than the string it is going into (`errFull`, and the line is gone), a
  service that does not resolve (`errAbsent`) and a port nobody is listening
  on (`errIO`). }
program lib_net(output);

import PasError;
       PasNet;

var
  srv, cli, conn: Socket;
  port: ServiceName;
  line: NetLine;
  short: string(4);
  { two characters, which no ephemeral port fits }
  tiny: string(2);
  e: ErrorCode;
  i, tries: integer;

begin
  { A socket listening on whatever port is free. }
  e := NetListen(srv, 'localhost', '0');
  writeln('listen:      ', ErrorText(e));

  e := srv.Service(port);
  writeln('service:     ', ErrorText(e), ', and a port was given: ',
          port <> '');

  { The same question asked with nowhere to put the answer. `Service` checks
    the *caller's* capacity and not `ServiceMax`, §6.4.3.3.3 making that
    readable, so this is `errFull` and not a truncated port -- and the
    ephemeral range is five digits, which two cannot hold. Until this was
    written the arm had no case: a mutation turning its `errFull` into
    `errIO` left the whole suite green. }
  e := srv.Service(tiny);
  writeln('no room:     ', ErrorText(e), ' [', tiny, ']');

  { The other end, to the port just reported. Both ends are strings the whole
    way: nothing here knows whether this is IPv4 or IPv6. }
  e := NetConnect(cli, 'localhost', port);
  writeln('connect:     ', ErrorText(e));

  e := NetAccept(srv, conn);
  writeln('accept:      ', ErrorText(e));

  { Two lines out and two in. `srv` is still listening -- accepting a
    connection does not consume the socket that accepted it. }
  e := cli.WriteLine('first line');
  e := cli.WriteLine('second line');
  for i := 1 to 2 do begin
    e := conn.ReadLine(line);
    writeln('  server got: ', ErrorText(e), ' [', line, ']')
  end;

  { And back the other way, so the connection is shown to be two-directional
    through one handle at each end. }
  e := conn.WriteLine('and a reply');
  e := cli.ReadLine(line);
  writeln('  client got: ', ErrorText(e), ' [', line, ']');

  { A line the far end sent without a newline is still a line. }
  e := cli.WriteText('no newline at the end');
  cli := nil;                     { AP 6.4.12.2's second form, ADR-0202 }
  e := conn.ReadLine(line);
  writeln('unterminated:', ErrorText(e), ' [', line, ']');

  { ...and then the far end has closed and there is nothing left. }
  e := conn.ReadLine(line);
  writeln('after close: ', ErrorText(e));

  conn := nil;

  { **Writing to a connection the far end has closed is an ErrorCode**, and
    that is a decision rather than a given: the default disposition of SIGPIPE
    ends the process without a diagnostic, which is not an outcome a routine
    answering a code can report, so the runtime ignores the signal where a
    socket is first made.

    **What is asserted is that the program survives, and that is the whole
    of what this language decides.** Whether a write is refused, and how many
    writes later, is the kernel's and not this processor's. This case learned
    that twice. It first wrote exactly twice, which was Linux's answer read as
    though it were every kernel's; the bound of a hundred that replaced it was
    the same bet at a larger number, and macOS lost it on run 34307309352 --
    a hundred writes of twenty-five bytes fit in a send buffer, so no reset
    was ever seen and the golden's `the operation was refused` became
    `no error`.

    So the outcome is no longer in the golden. What is: this line is reached
    at all. If SIGPIPE were not ignored the process would end without a
    diagnostic at the first refused write -- which is Linux's second -- and
    nothing below would print. That makes the claim deterministic where the
    signal exists and vacuous where the kernel never refuses, which is the
    right way round: a test may not assert a kernel's buffering. }
  e := NetConnect(cli, 'localhost', port);
  e := NetAccept(srv, conn);
  conn := nil;
  tries := 0;
  repeat
    e := cli.WriteLine('into a closed connection');
    tries := tries + 1
  until Failed(e) or (tries >= 100);
  writeln('write to closed: a code came back and the program is still here');
  cli := nil;

  { A line longer than the string it is going into. The capacity checked is
    the caller's own, read from the actual by 6.4.3.3.3, and the line is gone
    rather than half-delivered. }
  e := NetConnect(cli, 'localhost', port);
  e := NetAccept(srv, conn);
  e := cli.WriteLine('far too long for four characters');
  e := conn.ReadLine(short);
  writeln('too long:    ', ErrorText(e), ' [', short, ']');
  cli := nil;
  conn := nil;
  srv := nil;

  { A service nobody can resolve, and a port nobody is listening on. The two
    are different codes because a caller reports them differently: one is a
    name that means nothing, the other a machine that would not talk. }
  e := NetConnect(cli, 'localhost', 'not-a-service-name');
  writeln('bad service: ', ErrorText(e));
  e := NetConnect(cli, 'localhost', '1');
  writeln('refused:     ', ErrorText(e))
end.
