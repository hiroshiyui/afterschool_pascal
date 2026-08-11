{ `bindable`, `bind`, `unbind`, `binding` and `BindingType` are all ISO/IEC
  10206:1991's. `bindable` is a word-symbol Extended Pascal *adds*, so under
  ISO 7185 the lexer yields an identifier and the token never appears — which
  is why the message here is about the type-denoter rather than about the word.
  The rest are required *identifiers*, refused where they are resolved. }
program BindingIso(output);
var b: BindingType;
    f: text;
begin
  b := binding(f);
  bind(f, b);
  unbind(f);
  writeln(1)
end.
