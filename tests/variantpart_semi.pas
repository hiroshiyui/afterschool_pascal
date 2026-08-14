{ ISO 7185 §6.4.3.3 writes the field-list as

    field-list = [ ( fixed-part [ ';' variant-part ] | variant-part ) [ ';' ] ]

  so the ';' between a fixed-part and a variant-part is part of the production,
  where the trailing one is inside brackets and so is optional. This compiler
  accepted the record below: the field loop simply ended when no ';' followed
  and the caller parsed the variant part regardless.

  The suite's DEV266 is the program that found it, and no program in this
  corpus had ever left the semicolon out -- which is why writing one always
  looked required. }
program VariantPartSemi(output);
var
  rec: record
         a: integer
         case selector: boolean of
           true:  (b: integer);
           false: (c: integer)
       end;
begin
  rec.a := 1;
  writeln(rec.a:1)
end.
