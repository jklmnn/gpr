--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

with GPR2.Build.Artifacts.File_Part;
with GPR2.Build.Artifacts.Files;
with GPR2.Build.Tree_Db;
with GPR2.Message;
with GPR2.Project.Attribute;
with GPR2.Project.Attribute_Index;
with GPR2.Project.View.Set;
with GPR2.Utils.Hash;

package body GPR2.Build.Actions.Ada_Compile is

   package PAI renames GPR2.Project.Attribute_Index;

   function Artifacts_Base_Name
     (Unit : GPR2.Build.Compilation_Unit.Object) return Simple_Name;

   function Lookup
     (V          : GPR2.Project.View.Object;
      BN         : Simple_Name;
      In_Lib_Dir : Boolean;
      Must_Exist : Boolean) return GPR2.Path_Name.Object;
   --  Look for BN in V's hierarchy of object/lib directories

   function Get_Attr
     (V       : GPR2.Project.View.Object;
      Name    : Q_Attribute_Id;
      Idx     : Language_Id;
      Default : Value_Type) return Value_Type;

   -------------------------
   -- Artifacts_Base_Name --
   -------------------------

   function Artifacts_Base_Name
     (Unit : GPR2.Build.Compilation_Unit.Object) return Simple_Name
   is
      Main : constant Compilation_Unit.Unit_Location :=
               Unit.Main_Part;
      BN   : constant Simple_Name := Simple_Name (Main.Source.Base_Name);

   begin
      if Main.Index = No_Index then
         return BN;
      else
         declare
            Img : constant String := Main.Index'Image;
            Sep : constant String :=
                    Get_Attr (Main.View,
                              PRA.Compiler.Multi_Unit_Object_Separator,
                              Ada_Language,
                              "~");
         begin
            return BN & Simple_Name (Sep & Img (Img'First + 1 .. Img'Last));
         end;
      end if;
   end Artifacts_Base_Name;

   -----------------------
   -- Compare_Signature --
   -----------------------

   overriding procedure Compare_Signature
     (Self     : in out Object;
      Messages : in out GPR2.Log.Object)
   is
      use Build.Signature;
      use Utils.Hash;

      Db_File : constant Path_Name.Object :=
                  Self.Tree.Db_Filename_Path (Self.UID);
   begin
      Self.Signature := Load (Db_File, Messages);

      if Self.Signature.Coherent then
         Self.Signature.Set_Valid_State (True);
      else
         Self.Signature.Set_Valid_State (False);

         return;
      end if;

      for Input of Self.Tree.Inputs (Self.UID) loop
         declare
            Checksum : constant Hash_Digest :=
                         Self.Signature.Artifact_Checksum (Input.UID);
         begin
            if not (Input.Checksum = Checksum)
            then
               Self.Signature.Set_Valid_State (False);
               Messages.Append
                 (Message.Create
                    (Message.Information,
                     "not up-to-date",
                     Input.SLOC));
            end if;
         end;
      end loop;

      for Output of Self.Tree.Outputs (Self.UID) loop
         declare
            Checksum : constant Hash_Digest :=
                         Self.Signature.Artifact_Checksum (Output.UID);
         begin
            if not (Output.Checksum = Checksum)
            then
               Self.Signature.Set_Valid_State (False);
               Messages.Append
                 (Message.Create
                    (Message.Information,
                     "not up-to-date",
                     Output.SLOC));
            end if;
         end;
      end loop;

   end Compare_Signature;

   -----------------------
   -- Compute_Signature --
   -----------------------

   overriding procedure Compute_Signature (Self : in out Object) is
      use GPR2.Build.Signature;
   begin
      for Input of Self.Tree.Inputs (Self.UID) loop
         Self.Signature.Update_Artifact
           (Input.UID, Input.Image, Input.Checksum);
      end loop;

      for Output of Self.Tree.Outputs (Self.UID) loop
         Self.Signature.Update_Artifact
           (Output.UID, Output.Image, Output.Checksum);
      end loop;

      Self.Signature.Store (Self.Tree.Db_Filename_Path (Self.UID));
   end Compute_Signature;

   ------------
   -- Create --
   ------------

   function Create
     (Src : GPR2.Build.Compilation_Unit.Object) return Object
   is
      UID    : constant Ada_Compile_Id :=
                 (Name_Len  => Src.Name'Length,
                  Unit_Name => Src.Name,
                  Ctxt      => Src.Main_Part.View);
      Result : Object :=
                 (Input_Len => UID.Name_Len,
                  UID       => UID,
                  others    => <>);
      BN     : constant Simple_Name := Artifacts_Base_Name (Src);
      O_Suff : constant Simple_Name :=
                 Simple_Name
                   (Get_Attr
                      (Result.UID.Ctxt,
                       PRA.Compiler.Object_File_Suffix,
                       Ada_Language,
                       ".o"));

   begin
      --  ??? Once we can save/restore, we shouldn't need this lookup, or
      --  at least we need it only when signature is incorrect

      --  Lookup existing obj file in the hierarchy
      Result.Obj_File := Lookup
        (Result.UID.Ctxt, BN & O_Suff,
         In_Lib_Dir => False,
         Must_Exist => True);

      --  If not found, set the value to the object created after compilation
      if not Result.Obj_File.Is_Defined then
         Result.Obj_File := Lookup
           (Result.UID.Ctxt, BN & O_Suff,
            In_Lib_Dir => False,
            Must_Exist => False);
      end if;

      Result.Ali_File :=  Lookup
        (Result.UID.Ctxt, BN & ".ali",
         In_Lib_Dir => True,
         Must_Exist => True);

      if not Result.Ali_File.Is_Defined then
         Result.Ali_File :=  Lookup
           (Result.UID.Ctxt, BN & ".ali",
            In_Lib_Dir => True,
            Must_Exist => False);
      end if;

      return Result;
   end Create;

   --------------
   -- Get_Attr --
   --------------

   function Get_Attr
     (V       : GPR2.Project.View.Object;
      Name    : Q_Attribute_Id;
      Idx     : Language_Id;
      Default : Value_Type) return Value_Type
   is
      Attr : constant GPR2.Project.Attribute.Object :=
               V.Attribute (Name, PAI.Create (Idx));
   begin
      if Attr.Is_Defined then
         return Attr.Value.Text;
      else
         return Default;
      end if;
   end Get_Attr;

   ------------
   -- Lookup --
   ------------

   function Lookup
     (V          : GPR2.Project.View.Object;
      BN         : Simple_Name;
      In_Lib_Dir : Boolean;
      Must_Exist : Boolean) return GPR2.Path_Name.Object
   is
      Todo      : GPR2.Project.View.Set.Object;
      Done      : GPR2.Project.View.Set.Object;
      Current   : GPR2.Project.View.Object := V;
      Candidate : GPR2.Path_Name.Object;

   begin
      loop
         if In_Lib_Dir and then Current.Is_Library then
            Candidate := Current.Library_Ali_Directory.Compose (BN);
            exit when not Must_Exist or else Candidate.Exists;
         end if;

         Candidate := Current.Object_Directory.Compose (BN);
         exit when not Must_Exist or else Candidate.Exists;

         if Current.Is_Extending then
            Todo.Union (Current.Extended);
            Todo.Difference (Done);
         end if;

         if Todo.Is_Empty then
            return GPR2.Path_Name.Undefined;
         else
            Done.Include (Current);
            Current := Todo.First_Element;
            Todo.Delete_First;
         end if;
      end loop;

      return Candidate;
   end Lookup;

   -----------------------
   -- On_Tree_Insertion --
   -----------------------

   overriding procedure On_Tree_Insertion
     (Self     : Object;
      Db       : in out GPR2.Build.Tree_Db.Object;
      Messages : in out GPR2.Log.Object)
   is
      Unit     : constant Compilation_Unit.Object := Self.Input_Unit;
      Explicit : Boolean;
      Part     : Compilation_Unit.Unit_Location;
   begin
      Db.Add_Output
        (Self.UID,
         Artifacts.Files.Create (Self.Obj_File),
         Messages);

      if Messages.Has_Error then
         return;
      end if;

      if Self.Ali_File.Is_Defined then
         Db.Add_Output
           (Self.UID,
            Artifacts.Files.Create (Self.Ali_File),
            Messages);
      end if;

      if Messages.Has_Error then
         return;
      end if;

      for Kind in S_Spec .. S_Body loop
         if Unit.Has_Part (Kind) then
            Explicit := Unit.Main_Part = Kind;
            Part     := Unit.Get (Kind);
            Db.Add_Input
              (Self.UID,
               Artifacts.File_Part.Create (Part.Source, Part.Index),
               Explicit);
         end if;
      end loop;

      for Sep of Unit.Separates loop
         Db.Add_Input
           (Self.UID,
            Artifacts.File_Part.Create (Sep.Source, Sep.Index),
            False);
      end loop;
   end On_Tree_Insertion;

end GPR2.Build.Actions.Ada_Compile;
