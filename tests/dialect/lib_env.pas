{ ADR-0123 end to end: a library module binds C by name, a pointer comes back,
  and what the program holds is an optional of its own.

  The environment is written by the program first, so nothing here depends on
  how the harness was started. }
program lib_env(output);

import PasError;
       PasEnv;

var v: OptEnvText;
    e: ErrorCode;

procedure Show(what: string(12); o: OptEnvText);
begin
  write(what, ' = ');
  if o = nil then writeln('(unset)') else writeln('''', o^, '''')
end;

begin
  Show('before     ', Lookup('PASCAL_LIBENV'));
  writeln('defined      = ', Defined('PASCAL_LIBENV'));
  writeln('or default   = ''', LookupOr('PASCAL_LIBENV', 'fallback'), '''');

  e := Define('PASCAL_LIBENV', 'set to this');
  writeln('define       = ', Failed(e));
  Show('after      ', Lookup('PASCAL_LIBENV'));
  writeln('or default   = ''', LookupOr('PASCAL_LIBENV', 'fallback'), '''');

  { The distinction the whole record exists for: set-to-nothing is not unset. }
  e := Define('PASCAL_LIBENV', '');
  writeln('empty set    = ', Defined('PASCAL_LIBENV'));
  writeln('empty length = ', length(Lookup('PASCAL_LIBENV')^):1);

  e := Undefine('PASCAL_LIBENV');
  writeln('undefine     = ', Failed(e));
  writeln('defined      = ', Defined('PASCAL_LIBENV'));

  { unsetenv does not fail on a name that was not there, and this module does
    not invent a failure it was not told about. }
  e := Undefine('PASCAL_LIBENV');
  writeln('again        = ', Failed(e))
end.
