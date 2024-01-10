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
   Ctx.Include ("MyVAR2", "whatever");
   Ctx.Include ("MyVAR3", "");

   Project.Tree.Load (Prj, Create ("demo.gpr"), Ctx);

exception
   when GPR2.Project_Error =>
      if Prj.Has_Messages then
         Text_IO.Put_Line ("Messages found:");

         for C in Prj.Log_Messages.Iterate
           (False, False, True, True, True)
         loop
            declare
               M : constant Message.Object := Log.Element (C);
            begin
               Text_IO.Put_Line (M.Format);
            end;
         end loop;
      end if;
end Main;