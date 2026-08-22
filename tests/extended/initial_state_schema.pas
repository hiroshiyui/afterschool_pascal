{ ISO/IEC 10206:1991 6.4.1 writes the initial-state-specifier after any of the
  four bases a type-denoter may have:

    type-denoter = [ 'bindable' ] ( type-name | new-type | type-inquiry
                                    | discriminated-schema )
                     [ initial-state-specifier ] .

  -- and "If an initial-state-specifier occurs in a type-denoter, the
  type-denoter shall denote the initial state that is denoted by the
  initial-state-specifier". A discriminated-schema is one of the four, so
  `string(4) value 'jk'` gives its variables an initial state exactly as
  `s4 value 'jk'` does, and 6.2.3.5 creates each of them in it.

  The two spellings disagreed. Resolving the denoter checked the value and
  reported a bad one, and then nothing asked for the state: a *global* was
  merely zeroed, and a **local** was left reading whatever its frame slot
  held -- `writeln(t)` wrote several kilobytes of stack.

  A group shares one denoter and so shares one initial state, which is what
  `p, q` below is for. }
program initial_state_schema(output);

type
  s4 = string(4);

var
  viaSchema: string(4) value 'jk';
  viaName:   s4 value 'jk';
  p, q:      string(6) value 'shared';

procedure locals;
var
  t: string(4) value 'jk';
  u: s4 value 'jk';
  { A group of locals, to show the sharing is not a property of being global. }
  a, b: string(6) value 'shared';
begin
  writeln('t=[', t, ']', length(t):1);
  writeln('u=[', u, ']', length(u):1);
  writeln('a=[', a, ']  b=[', b, ']')
end;

begin
  writeln('viaSchema=[', viaSchema, ']', length(viaSchema):1);
  writeln('viaName=[', viaName, ']', length(viaName):1);
  writeln('p=[', p, ']  q=[', q, ']');
  locals
end.
