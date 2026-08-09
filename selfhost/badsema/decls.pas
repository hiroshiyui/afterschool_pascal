{ Declarations: types, constants, and the forward/completion rules. }
program decls(output, notafile);
const bad = notaconstant;
type unknown = nosuchtype;
     weird = array [real] of integer;
     colour = (red, green);
     rec = record
       case colour of
         nosuchconstant: (a: integer);
         1: (b: integer)
     end;
var notafile: integer;
    v: rec;
function noresult; begin noresult := 1 end;
procedure never; forward;
procedure twice; begin end;
procedure twice; begin end;
procedure later(x: integer); forward;
procedure later(y: integer); begin write(y) end;
begin
  write(v.a)
end.
