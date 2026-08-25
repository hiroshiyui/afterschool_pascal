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
  which is "whatever is free", and `Service` reports back the numeric string
  that `Connect` then takes -- so what is printed is that a port was given and
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
  e: ErrorCode;
  i: integer;

begin
  { A socket listening on whatever port is free. }
  e := Listen(srv, 'localhost', '0');
  writeln('listen:      ', ErrorText(e));

  e := Service(srv, port);
  writeln('service:     ', ErrorText(e), ', and a port was given: ',
          port <> '');

  { The other end, to the port just reported. Both ends are strings the whole
    way: nothing here knows whether this is IPv4 or IPv6. }
  e := Connect(cli, 'localhost', port);
  writeln('connect:     ', ErrorText(e));

  e := Accept(srv, conn);
  writeln('accept:      ', ErrorText(e));

  { Two lines out and two in. `srv` is still listening -- accepting a
    connection does not consume the socket that accepted it. }
  e := WriteLine(cli, 'first line');
  e := WriteLine(cli, 'second line');
  for i := 1 to 2 do begin
    e := ReadLine(conn, line);
    writeln('  server got: ', ErrorText(e), ' [', line, ']')
  end;

  { And back the other way, so the connection is shown to be two-directional
    through one handle at each end. }
  e := WriteLine(conn, 'and a reply');
  e := ReadLine(cli, line);
  writeln('  client got: ', ErrorText(e), ' [', line, ']');

  { A line the far end sent without a newline is still a line. }
  e := WriteText(cli, 'no newline at the end');
  cli := nil;                     { AP 6.4.12.2's second form, ADR-0202 }
  e := ReadLine(conn, line);
  writeln('unterminated:', ErrorText(e), ' [', line, ']');

  { ...and then the far end has closed and there is nothing left. }
  e := ReadLine(conn, line);
  writeln('after close: ', ErrorText(e));

  conn := nil;

  { **Writing to a connection the far end has closed is an ErrorCode**, and
    that is a decision rather than a given: the default disposition of SIGPIPE
    ends the process without a diagnostic, which is not an outcome a routine
    answering a code can report, so the runtime ignores the signal where a
    socket is first made. Two writes, because the first goes into the kernel's
    buffer and it is the peer's reset that makes the second fail. }
  e := Connect(cli, 'localhost', port);
  e := Accept(srv, conn);
  conn := nil;
  e := WriteLine(cli, 'into a closed connection');
  e := WriteLine(cli, 'and again');
  writeln('write to closed: ', ErrorText(e));
  cli := nil;

  { A line longer than the string it is going into. The capacity checked is
    the caller's own, read from the actual by 6.4.3.3.3, and the line is gone
    rather than half-delivered. }
  e := Connect(cli, 'localhost', port);
  e := Accept(srv, conn);
  e := WriteLine(cli, 'far too long for four characters');
  e := ReadLine(conn, short);
  writeln('too long:    ', ErrorText(e), ' [', short, ']');
  cli := nil;
  conn := nil;
  srv := nil;

  { A service nobody can resolve, and a port nobody is listening on. The two
    are different codes because a caller reports them differently: one is a
    name that means nothing, the other a machine that would not talk. }
  e := Connect(cli, 'localhost', 'not-a-service-name');
  writeln('bad service: ', ErrorText(e));
  e := Connect(cli, 'localhost', '1');
  writeln('refused:     ', ErrorText(e))
end.
