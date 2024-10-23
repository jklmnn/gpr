--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

limited with GPR2.Build.Actions.Post_Bind;
with GPR2.Build.Artifacts.Files;
with GPR2.Path_Name; use GPR2.Path_Name;
with GPR2.Project.Registry.Attribute;

with Ada.Containers.Hashed_Sets;

with GNATCOLL.OS.Process;
private with GPR2.View_Ids;

package GPR2.Build.Actions.Ada_Bind is

   package PRA renames GPR2.Project.Registry.Attribute;

   type Ada_Bind_Id (<>) is new Actions.Action_Id with private;

   overriding function Image (Self : Ada_Bind_Id) return String;

   overriding function Db_Filename
     (Self : Ada_Bind_Id) return Simple_Name;

   overriding function "<" (L, R : Ada_Bind_Id) return Boolean;

   type Object is new Actions.Object with private;

   Undefined : constant Object;

   overriding function UID (Self : Object) return Actions.Action_Id'Class;

   procedure Initialize
     (Self     : in out Object;
      Main_Ali : Artifacts.Files.Object;
      Context  : GPR2.Project.View.Object);

   overriding function View (Self : Object) return GPR2.Project.View.Object;

   package Path_Name_Sets is
     new Ada.Containers.Hashed_Sets
       (GPR2.Path_Name.Object, Hash => GPR2.Path_Name.Hash,
        Equivalent_Elements => GPR2.Path_Name."=");

   overriding function On_Tree_Insertion
     (Self     : Object;
      Db       : in out GPR2.Build.Tree_Db.Object) return Boolean;

   overriding procedure Compute_Command
     (Self : in out Object;
      Args : out GNATCOLL.OS.Process.Argument_List;
      Env  : out GNATCOLL.OS.Process.Environment_Dict;
      Slot : Positive);

   overriding function Working_Directory
     (Self : Object) return Path_Name.Object;

   function Linker_Options
     (Self : Object) return GNATCOLL.OS.Process.Argument_List;
   --  Get the linker options generated by the binder

   function Generated_Spec (Self : Object) return Artifacts.Files.Object;
   function Generated_Body (Self : Object) return Artifacts.Files.Object;
   function Post_Bind (Self : Object) return Actions.Post_Bind.Object;

private

   use type GPR2.View_Ids.View_Id;

   type Ada_Bind_Id (Name_Len : Natural) is new Actions.Action_Id
     with record
      Ctxt      : GPR2.Project.View.Object;
      Ali_Name  : Filename_Type (1 .. Name_Len);
   end record;

   overriding function Image (Self : Ada_Bind_Id) return String is
     ("[Bind Ada] " & String (Self.Ali_Name) &
        " (" & String (Self.Ctxt.Path_Name.Simple_Name) & ")");

   overriding function Db_Filename
     (Self : Ada_Bind_Id) return Simple_Name is
     (Simple_Name ("bind_ada_" & To_Lower (Self.Ali_Name) & "_"
      & To_Lower (Self.Ctxt.Name) & ".json"));

   overriding function "<" (L, R : Ada_Bind_Id) return Boolean is
     (if L.Ctxt.Id = R.Ctxt.Id then L.Ali_Name < R.Ali_Name
      else L.Ctxt.Id < R.Ctxt.Id);

   type Object is new Actions.Object with record
      Main_Ali    : Artifacts.Files.Object;
      --  ALI file given as argument to the binder
      Output_Spec : Artifacts.Files.Object;
      Output_Body : Artifacts.Files.Object;

      Ctxt        : GPR2.Project.View.Object;
      --  View referenced by the generated compilation unit

      Linker_Opts : GNATCOLL.OS.Process.Argument_List;
      --  Linker options generated by gnatbind in the generated body

      Obj_Deps    : GPR2.Containers.Filename_Set;
      --  List of objects coming from gnatbind it the generated body
   end record;

   function BN (Self : Object) return Simple_Name is
     ("b__" & Self.Main_Ali.Path.Base_Filename);

   overriding procedure Compute_Signature
     (Self   : in out Object;
      Stdout : Unbounded_String;
      Stderr : Unbounded_String);

   overriding function Post_Command
     (Self   : in out Object;
      Status : Execution_Status) return Boolean;

   function Generated_Spec (Self : Object) return Artifacts.Files.Object is
      (Self.Output_Spec);

   function Generated_Body (Self : Object) return Artifacts.Files.Object is
      (Self.Output_Body);

   Undefined : constant Object := (others => <>);

   overriding function View (Self : Object) return GPR2.Project.View.Object is
     (Self.Ctxt);

   function Linker_Options
     (Self : Object) return GNATCOLL.OS.Process.Argument_List is
     (Self.Linker_Opts);

   overriding function Working_Directory
     (Self : Object) return Path_Name.Object is
     (Self.Ctxt.Object_Directory);

end GPR2.Build.Actions.Ada_Bind;
