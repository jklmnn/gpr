--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

with GPR2.Build.Artifacts.File_Part;
with GPR2.Build.Artifacts.Files;
with GPR2.Build.Tree_Db;
with Ada.Text_IO;

package body GPR2.Build.Actions.Ada_Compile.Post_Bind is

   -------------
   -- Command --
   -------------

   overriding function Command (Self : Object)
     return GNATCOLL.OS.Process.Argument_List
   is
      Args : GNATCOLL.OS.Process.Argument_List;
   begin
      if Self.Unit.Has_Part (S_Body) then
         Args.Append ("gcc");
         Args.Append ("-c");
         Args.Append (String (Self.Unit.Main_Body.Source.Value));
         Args.Append ("-o");
         Args.Append (Self.Object_File.String_Value);
      end if;

      return Args;
   end Command;

   -----------------------
   -- Compute_Signature --
   -----------------------

   overriding procedure Compute_Signature (Self : in out Object) is
      use GPR2.Build.Signature;

      UID : constant Actions.Action_Id'Class := Object'Class (Self).UID;
      Art : Artifacts.Files.Object;
   begin
      Self.Signature.Clear;

      --  As the unit has been generated by the binder, it does not belong
      --  to the tree. The consequence is that the unit sources will not be
      --  found as dependencies. Thus, we need to add them explicitly.

      for Kind in S_Spec .. S_Body loop
         if Self.Unit.Has_Part (Kind) then
            Art := Artifacts.Files.Create (Self.Unit.Get (Kind).Source);
            Self.Signature.Update_Artifact (Art.UID, Art.Image, Art.Checksum);
         end if;
      end loop;

      for Dep of Self.Dependencies loop
         Art := Artifacts.Files.Create (Dep);
         Self.Signature.Update_Artifact (Art.UID, Art.Image, Art.Checksum);
      end loop;

      Art := Artifacts.Files.Create (Self.Ali_File);
      Self.Signature.Update_Artifact (Art.UID, Art.Image, Art.Checksum);

      Art := Artifacts.Files.Create (Self.Obj_File);
      Self.Signature.Update_Artifact (Art.UID, Art.Image, Art.Checksum);

      Self.Signature.Store (Self.Tree.Db_Filename_Path (UID));
   end Compute_Signature;

   ----------------
   -- Initialize --
   ----------------

   overriding procedure Initialize
     (Self : in out Object; Src : GPR2.Build.Compilation_Unit.Object)
   is
   begin
      Actions.Ada_Compile.Object (Self).Initialize (Src);
      Self.Unit := Src;
      Self.Traces := Create ("ACTION_ADA_COMPILE_POST_BIND");
   end Initialize;

   -----------------------
   -- On_Tree_Insertion --
   -----------------------

   overriding procedure On_Tree_Insertion
     (Self     : Object;
      Db       : in out GPR2.Build.Tree_Db.Object;
      Messages : in out GPR2.Log.Object)
   is
      Explicit : Boolean;
      Part     : Compilation_Unit.Unit_Location;
      UID : constant Actions.Action_Id'Class := Object'Class (Self).UID;
   begin
      Db.Add_Output
        (UID,
         Artifacts.Files.Create (Self.Obj_File),
         Messages);

      if Messages.Has_Error then
         return;
      end if;

      if Self.Ali_File.Is_Defined then
         Db.Add_Output
           (UID,
            Artifacts.Files.Create (Self.Ali_File),
            Messages);
      end if;

      if Messages.Has_Error then
         return;
      end if;

      for Kind in S_Spec .. S_Body loop
         if Self.Unit.Has_Part (Kind) then
            Explicit := Self.Unit.Main_Part = Kind;
            Part     := Self.Unit.Get (Kind);
            Db.Add_Input
              (UID,
               Artifacts.File_Part.Create (Part.Source, Part.Index),
               Explicit);
         else
            --  ??? Raise an exception ?
            Ada.Text_IO.Put_Line
              ("[ERROR] missing part for unit " & String (Self.Unit.Name));
         end if;
      end loop;
   end On_Tree_Insertion;

   ---------
   -- UID --
   ---------

   overriding function UID (Self : Object) return Actions.Action_Id'Class is
      Result : constant Ada_Compile_Post_Bind_Id :=
                 (Name_Len  => Ada.Strings.Unbounded.Length (Self.Unit_Name),
                  Unit_Name => Name_Type (To_String (Self.Unit_Name)),
                  Ctxt      => Self.Ctxt);
   begin
      return Result;
   end UID;

end GPR2.Build.Actions.Ada_Compile.Post_Bind;
