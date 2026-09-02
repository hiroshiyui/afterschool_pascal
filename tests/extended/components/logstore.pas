{ A module exporting one bindable variable and one that is not, so a program
  importing it `qualified` reaches both through ISO/IEC 10206:1991 6.11.3's
  qualified name.

  §6.11.4 lets a module export a variable, and §6.4.1 makes bindability a
  property the *type-denoter* denotes — so under ISO/IEC 10206:1991 `logfile`
  below is bindable and `plainfile` is not, and the difference had to survive
  being exported, being imported, and being written as `logging.logfile`.
  Nothing had ever asked: bindability was read off the root of a designator
  and a qualified name has no root, so both would have been answered the same
  way.

  AP 6.5.1 (ADR-0299) makes every file variable bindable, so both are now.
  tests/extended/bind_qualified.pas binds the first and bind_qualified_plain.pas
  the second, each through the qualified name; the word on `logfile` is kept
  so the two spellings stay side by side. }
module logstore;

export logging = (logfile, plainfile);

var
  logfile: bindable text;
  plainfile: text;
end;

end.
