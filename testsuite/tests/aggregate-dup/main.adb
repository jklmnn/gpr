with Ada.Text_IO;
with Ada.Strings.Fixed;

with GPR2.Context;
with GPR2.Log;
with GPR2.Message;
with GPR2.Project.Tree;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;

begin
   Project.Tree.Load (Prj, Create ("demo.gpr"), Ctx);

   if Prj.Has_Messages then
      Text_IO.Put_Line ("Messages found:");

      for C in Prj.Log_Messages.Iterate
        (False, True, True, True, True)
      loop
         declare
            M   : constant Message.Object := Log.Element (C);
            Mes : constant String := M.Format;
            L   : constant Natural :=
                    Strings.Fixed.Index (Mes, "/aggregate-dup");
         begin
            if L /= 0 then
               Text_IO.Put_Line (Mes (L .. Mes'Last));
            else
               Text_IO.Put_Line (Mes);
            end if;
         end;
      end loop;
   end if;
end Main;