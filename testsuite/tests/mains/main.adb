--
--  Copyright (C) 2019-2023, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Strings.Fixed;
with Ada.Text_IO;

with GPR2.Context;
with GPR2.Log;
with GPR2.Path_Name;
with GPR2.Project.Tree;
with GPR2.Project.View;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   procedure Display (Prj : Project.View.Object);

   function Filter_Path (Filename : Path_Name.Full_Name) return String;

   -------------
   -- Display --
   -------------

   procedure Display (Prj : Project.View.Object) is
   begin
      Text_IO.Put (String (Prj.Name) & " ");
      Text_IO.Set_Col (10);
      Text_IO.Put_Line (Prj.Qualifier'Img);

      for M of Prj.Executables loop
         Text_IO.Put_Line (Filter_Path (M.Dir_Name & String (M.Base_Name)));
      end loop;
   end Display;

   -----------------
   -- Filter_Path --
   -----------------

   function Filter_Path (Filename : Path_Name.Full_Name) return String is
      D : constant String := "mains";
      I : constant Positive := Strings.Fixed.Index (Filename, D);
   begin
      return Filename (I .. Filename'Last);
   end Filter_Path;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;
   Log : GPR2.Log.Object;

begin
   for J in 1 .. 12 loop
      declare
         Num : constant String := J'Image;
         Prj_File : constant String :=
           "prj/demo" & Num (Num'First + 1 .. Num'Last) & ".gpr";
      begin
         Project.Tree.Load (Prj, Create (Filename_Type (Prj_File)), Ctx);
         Prj.Update_Sources (Messages => Log);
         Display (Prj.Root_Project);

         Prj.Log_Messages.Output_Messages (Information => False);
         Log.Output_Messages;
      end;
   end loop;
end Main;
