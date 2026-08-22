{ ISO/IEC 10206:1991 6.7.3.2 gives the required schema `string` a paragraph of
  its own when it names a **value** parameter, and it is not the rule every
  other schema-name follows:

    "If the parameter-form of the value-parameter-specification contains a
     schema-name that denotes the schema denoted by the required
     schema-identifier string, then each corresponding actual-parameter
     contained by the activation-point of an activation shall possess a type
     having an underlying-type that is a string-type or the char-type; it
     shall be an error if the values of these underlying-types, associated
     with the values denoted by the actual-parameters, do not all have the same
     length. Within the activation, each corresponding formal-parameter shall
     possess the type produced from the schema string with the tuple having
     that length as its component."

  Two things follow and both were wrong here.

  The actual is an **expression**, not a variable produced from the schema. A
  literal, a one-character literal (6.4.3.3.1 gives the char-type "length 1 and
  capacity 1"), a constant, a concatenation and a function result are all legal
  and were all answered with "needs a variable produced from schema 'string'".
  6.11.6's own Example 10 is one of them -- it writes

      record event('event-module initialization');

  and this compiler refused the standard's own worked example.

  And the formal's capacity is **the length of the value**, not the capacity of
  whatever variable the value came out of: passing a `string(40)` holding three
  characters produces a formal of capacity 3. That is what the last procedure
  here shows, and what tests/extended/string_value_capacity.pas turns into a
  trap.

  What makes the fix small is that the two shapes already coincided. A
  schematic formal travels as an address and one discriminant; EmitString
  already builds an address and a length for any string expression. So the
  caller passes the pair, and the callee's prologue -- which had been copying a
  string object -- builds one instead, of exactly 4 + length bytes. The
  discriminant it stores is the length, which is the clause's tuple. }
program string_value_parameter(output);

var v40: string(40);
    v3: string(3);

const greeting = 'hello';

{ The shape from 6.11.6's Example 10. }
procedure record_event(event_to_record: string);
begin
  writeln('[', event_to_record, '] length ', length(event_to_record):1)
end;

{ Two names in one parameter form. The clause makes unequal lengths an *error*
  rather than a violation, and both actuals here have the same length. }
procedure pair(a, b: string);
begin writeln(a, '/', b, ' ', length(a):1, length(b):1) end;

{ A formal whose capacity is the value's length: `s` holds exactly what it was
  given and nothing more, so a concatenation onto it is measured against that
  length and not against the actual's capacity. }
procedure exact(s: string);
begin writeln(length(s):1) end;

function greet: string(11);
begin greet := 'hi there' end;

procedure through(procedure p(s: string));
begin p('via a procedural parameter') end;

begin
  { A string literal -- the standard's own example. }
  record_event('event-module initialization');

  { A one-character literal, which is a char and not a string. }
  record_event('x');

  { A string constant (6.3, ADR-0068). }
  record_event(greeting);

  { A concatenation, whose value lives in the string arena. }
  record_event('event ' + 'in two halves');

  { A function result. }
  record_event(greet);

  { And a variable, which is the only one of the six that ever worked. }
  v40 := 'from a variable';
  record_event(v40);

  { One parameter form, two actuals of equal length. }
  v3 := 'abc';
  pair(v3, 'xyz');

  { The capacity is the value's length, whatever the actual's capacity is:
    all three of these are the same string and give the same answer. }
  v40 := 'abc';
  exact(v40);
  exact(v3);
  exact('abc');

  { Through a procedural parameter, where the formal's own formal is a string
    value parameter. }
  through(record_event)
end.
