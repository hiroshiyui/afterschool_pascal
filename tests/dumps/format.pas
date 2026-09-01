{ What `pascalc --format` does to a program, pinned (ADR-0279). `format-check`
  proves that formatting *preserves* every source in this tree; nothing there
  says what the output looks like, and this is the one place that does -- so a
  layout rule that changes shows up here as a golden diff and nowhere else.

  Deliberately written badly. Every construct the layout rules know about is
  here with its whitespace wrong: a compound-statement, an if with and without
  an else, an else-if chain, a case-statement with a completer, a record with
  a variant-part, a repeat, a with, a for, a nested procedure, a declaration
  part, a line long enough to need the margin, and comments in each of the
  three places one can stand -- above a thing, beside it, and inside an
  expression.

  And four *spacings*, each of which was wrong until an attempt to format this
  whole repository showed it (ADR-0285). A caret is two constructs and takes a
  space on one of them -- 6.4.4's pointer-type is a prefix and 6.5.4's
  dereference is a postfix. AP 6.4.13's fallible-type is binary and takes a
  space on both sides. 6.9.2.1's empty statement after a case-label's colon
  takes one before the separator. And a blank line inside a parenthesised list
  leaves the list open, so what follows it is still indented. Every one of
  them keeps the token stream, so `format-check` was green for all four and
  this case is the only thing that can hold them. }
program format(output);
type
 colour=(red,green,blue);
 shape=record
 tag:colour;
 case kind:colour of
 red:(radius:integer);
 green,blue:(width,height:integer)
 end;
var
 i,j:integer; c:colour; s:shape;
 total:integer;

function area(protected var v:shape):integer;
begin
 case v.kind of
 red: area:=v.radius*v.radius*3;
 green,blue: area:=v.width*v.height;
 otherwise
 area:=0
 end
end;

{ a nested procedure, and a hanging statement after every then and do }
procedure walk(n:integer);
var k:integer;
 procedure note(x:integer);
 begin
 if x>0 then writeln('  note ',x:1) else writeln('  note none')
 end;
begin
 for k:=1 to n do
 if k=1 then note(k)
 else if k=2 then begin note(k); note(-k) end
 else
 note(0);
 k:=0;
 repeat
 k:=k+1;
 total:=total+k
 until k>=n;
 with s do
 tag:=green
end;

{ the four spacings, which no other case here holds }
type
 node=^item;
 item=record next:node end;
 maybe=node!integer;
 pair=(one,two);
var
 head:node;
 m:maybe;
 pk:pair;

{ a comment introducing the branch it stands before, which takes that
  branch's indent and not the arm's above it }
procedure branches(n:integer);
begin
 if n=0 then
 writeln('zero')
 { the other way }
 else if n=1 then
 writeln('one')
 else
 writeln('many')
end;

procedure grouped(a,b,

 c,d:integer);
begin
 writeln(a+b+c+d:1)
end;

procedure spacings;
begin
 new(head); head^.next:=nil;
 case pk of
 one: ;
 two:writeln('two')
 end;
 dispose(head);
 grouped(1,2,3,4);
 branches(1)
end;

begin
 total:=0;
 s.tag:=red; s.kind:=red; s.radius:=4;
 writeln('area ',area(s):1); { beside the statement it belongs to }
 for c:=red to blue do
 case c of
 red:writeln('red');
 green:writeln('green');
 blue:writeln('blue')
 end;
 walk(3);
 i:=1; j:=2;
 writeln('sum ',i{ inside an expression }+j:1,' total ',total:1);
 total:=i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j+i+j;
 writeln('long ',total:1)
end.
