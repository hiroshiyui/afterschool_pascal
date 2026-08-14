{ ISO 7185 §6.6.5.3 asks for different things of the two procedures:

    new(p)      shall create a new variable ... and shall attribute to p ...
    dispose(q)  shall remove the identifying-value denoted by the expression q

  So `q` is an expression -- a function-designator is one as much as a variable
  is -- while `p` has to be somewhere to store. This compiler required a
  variable of both, and the suite's CONF129 is the program that found it.

  ADR-0019 stores nil back into the pointer after a dispose, which is stricter
  than the standard asks. There is nothing to store into here, and nothing that
  could read it back; the second half of this program is what keeps that
  behaviour pinned for the case where there *is* a variable. }
program DisposeExpression(output);
type
  recptr = ^rec;
  rec = record
          i: integer;
          next: recptr
        end;
var head, spare: recptr;

function follow(p: recptr): recptr;
begin
  follow := p^.next
end;

begin
  new(head);
  new(head^.next);
  head^.next^.i := 7;
  writeln('before ', head^.next^.i:1);
  { The argument is a call, so there is no variable to clear afterwards. }
  dispose(follow(head));
  head^.next := nil;
  dispose(head);
  writeln('disposed');

  { And where the argument *is* a variable, nil goes back into it -- so this
    dereference stops the program rather than reading freed storage. }
  new(spare);
  dispose(spare);
  spare^.i := 1;
  writeln('unreachable')
end.
