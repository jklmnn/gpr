with Ada.Strings.Fixed;
with Ada.Text_IO;

with GPR2.Build.Source.Sets;
with GPR2.Context;
with GPR2.Log;
with GPR2.Path_Name;
with GPR2.Project.Tree;
with GPR2.Project.View;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   procedure Check (Project_Name : Filename_Type);
   --  Do check the given project's sources

   procedure Output_Filename (Filename : Path_Name.Full_Name);
   --  Remove the leading tmp directory

   -----------
   -- Check --
   -----------

   procedure Check (Project_Name : Filename_Type) is
      Prj  : Project.Tree.Object;
      Ctx  : Context.Object;
      View : Project.View.Object;
      Log  : GPR2.Log.Object;
   begin
      Project.Tree.Load (Prj, Create (Project_Name), Ctx);
      Prj.Log_Messages.Output_Messages (Information => False);

      Prj.Update_Sources (Messages => Log);

      Log.Output_Messages (Information => False);

      View := Prj.Root_Project;
      Text_IO.Put_Line ("Project: " & String (View.Name));

      for Source of View.Sources loop
         declare
            U : constant Optional_Name_Type := Source.Unit.Name;
         begin
            Output_Filename (Source.Path_Name.Value);

            Text_IO.Set_Col (18);
            Text_IO.Put ("language: " & Image (Source.Language));

            Text_IO.Set_Col (33);
            Text_IO.Put ("Kind: " & Source.Kind'Image);

            if U /= "" then
               Text_IO.Put ("   unit: " & String (U));
            end if;

            Text_IO.New_Line;
         end;
      end loop;
   exception
      when GPR2.Project_Error =>
         Prj.Log_Messages.Output_Messages (Information => False);
   end Check;

   ---------------------
   -- Output_Filename --
   ---------------------

   procedure Output_Filename (Filename : Path_Name.Full_Name) is
      S : constant String := String (Filename);
      Test : constant String := "source-list-malformed";
      I : constant Positive := Strings.Fixed.Index (S, Test);
   begin
      Text_IO.Put (" > " & S (I + Test'Length + 1 .. S'Last));
   end Output_Filename;

begin
   Check ("demo.gpr");
end Main;