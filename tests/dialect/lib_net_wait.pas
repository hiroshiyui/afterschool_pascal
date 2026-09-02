{ NetWait: one thread of control serving more than one connection
  (ADR-0205).

  **What this pins is the thing a server could not do before.** ADR-0203 left
  `PasNet` able to accept, serve and close one connection at a time, because
  `NetReadLine` blocks and a server holding two clients cannot know which of them
  has spoken. Here client two speaks and client one says nothing, so a server
  reading them in turn would stop on client one and never reach the line that
  is waiting -- which makes this a test that **hangs** when `NetWait` is wrong,
  rather than one that prints the wrong thing.

  **The sockets live in the array.** A handle has exactly two assignments
  (AP 6.4.12.2) and neither is `a := b`, so nothing is ever copied into
  `watch`: `NetListen` and `NetAccept` are handed the element itself, and the array
  owns what they put there. Slot 1 is the listening socket and the rest are
  connections, which is what lets one `NetWait` answer both "somebody has
  arrived" and "somebody has spoken" -- to `poll` they are one question.

  **An empty slot is a hole, and needs no compaction.** Closing a connection
  is `watch[k] := nil` (ADR-0202) and `NetWait` skips what is empty.

  The whole exchange is in one activation, for `lib_net.pas`'s reason: a test
  that needed a second machine would be a test of the environment. }
program lib_net_wait(output);

import PasError;
       PasNet;

const
  Slots = 3;        { 1 is the listener; 2 and 3 are connections }
  Patience = 2000;  { a limit and not a promise, in milliseconds }
  Rounds = 8;       { so a wrong answer ends the program instead of the suite }

var
  watch: SocketList(Slots);
  ready: array [1..Slots] of boolean;
  cli: array [1..2] of Socket;
  port: ServiceName;
  line: NetLine;
  e: ErrorCode;
  k, free, round, closed: integer;
  idle: SocketList(2);
  quiet: array [1..2] of boolean;
  clock: TimeStamp;
  before, after, elapsed: integer;

begin
  { **The timeout is a wait and not a poll**, which nothing else here can see:
    a `NetWait` that ignored it would answer the same in every case below,
    because both ends are in this program and whatever was written has already
    arrived. A server whose readiness call did not wait would burn a
    processor, and this is the only shape that catches it -- an empty list, so
    there is nothing that could ever become ready, and a clock either side.

    §6.7.6.9's `GetTimeStamp` is second-resolution, so the wait is asked for in
    whole seconds' worth and the assertion is the weak one it can carry. }
  GetTimeStamp(clock);
  before := clock.minute * 60 + clock.second;
  e := NetWait(idle, 1200, quiet);
  GetTimeStamp(clock);
  after := clock.minute * 60 + clock.second;
  elapsed := after - before;
  if elapsed < 0 then elapsed := elapsed + 3600;   { over a minute boundary }
  writeln('idle wait: ', ErrorText(e), ', nothing ready: ',
          not (quiet[1] or quiet[2]));
  writeln('and it did wait: ', elapsed >= 1);
  writeln;

  e := NetListen(watch[1], 'localhost', '0');
  writeln('listen:    ', ErrorText(e));
  e := NetService(watch[1], port);
  writeln('service:   ', ErrorText(e), ', a port was given: ', port <> '');

  for k := 1 to 2 do begin
    e := NetConnect(cli[k], 'localhost', port);
    writeln('connect ', k:1, ':  ', ErrorText(e))
  end;

  { Only the second client says anything -- and it says two lines in one
    write, which is what puts the second of them in the runtime's buffer with
    the descriptor left quiet.  Nothing but `NetWait` can find that line. }
  e := NetWriteText(cli[2], 'from two' + chr(10) + 'and again' + chr(10));
  writeln('two has spoken twice at once, one is silent');
  writeln;

  closed := 0;
  round := 0;
  while (closed < 2) and (round < Rounds) do begin
    round := round + 1;
    e := NetWait(watch, Patience, ready);
    if Failed(e) then begin
      writeln('wait: ', ErrorText(e));
      closed := 2
    end
    else begin
      { Somebody arrived: the connection goes in the first free slot. }
      if ready[1] then begin
        free := 0;
        for k := 2 to Slots do
          if (free = 0) and (watch[k] = nil) then free := k;
        if free = 0 then writeln('arrived, and no room for it')
        else begin
          e := NetAccept(watch[1], watch[free]);
          writeln('accepted into slot ', free:1, ': ', ErrorText(e))
        end
      end;

      { And whoever spoke is read.  Nothing here waits on a particular one. }
      for k := 2 to Slots do
        if ready[k] then begin
          e := NetReadLine(watch[k], line);
          if e = errAbsent then begin
            writeln('slot ', k:1, ' closed by the far end');
            watch[k] := nil;
            closed := closed + 1
          end
          else begin
            writeln('slot ', k:1, ' said: ', line);
            { The other half of the conversation, driven by what was heard. }
            if line = 'from two' then begin
              e := NetWriteLine(cli[1], 'from one');
              writeln('  so one speaks')
            end
            else if line = 'and again' then begin
              cli[2] := nil;
              writeln('  that one was buffered, and two goes away')
            end
            else if line = 'from one' then begin
              cli[1] := nil;
              writeln('  so one goes away too')
            end
          end
        end
    end
  end;

  writeln;
  writeln('closed:    ', closed:1);
  writeln('in rounds: ', round < Rounds)
end.
