--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

with GPR2.Build.Actions; use GPR2.Build.Actions;
with Ada.Text_IO;        use Ada.Text_IO;
with Ada.Strings.Fixed;

package body GPR2.Build.Process_Manager.JSON is

   -----------------
   -- Collect_Job --
   -----------------

   overriding
   function Collect_Job
      (Self           : in out Object;
       Job            : DG.Node_Id;
       Proc_Handler   : Process_Handler;
       Stdout, Stderr : Unbounded_String)
      return Collect_Status
   is
      Act : constant GPR2.Build.Actions.Object'Class :=
              Self.Tree_Db.Action
                (Self.Tree_Db.Action_Id (Job));
      Job_Summary : constant JSON_Value := Create_Object;
      Cmd         : Unbounded_String;
   begin

      for Arg of Act.Command loop
         Ada.Strings.Unbounded.Append (Cmd, To_Unbounded_String (Arg & " "));
      end loop;

      Set_Field (Val        => Job_Summary,
                 Field_Name => TEXT_ACTION_UID,
                 Field      => Ada.Strings.Fixed.Trim
                   (Act.UID.Image, Ada.Strings.Both));
      Set_Field (Val        => Job_Summary,
                 Field_Name => TEXT_COMMAND,
                 Field      => Ada.Strings.Fixed.Trim
                   (To_String (Cmd), Ada.Strings.Both));

      declare
         Status : Unbounded_String;
      begin
         case Proc_Handler.Status is
            when Running =>

            --  ??? Use a custom exception

               raise Program_Error with
               "The process linked to the action '" & Act.UID.Image &
               "' is still running. Cannot collect the job before it finishes";

            when Finished =>
               Status :=
               To_Unbounded_String
                  (Ada.Strings.Fixed.Trim
                     (Proc_Handler.Process_Status'Img, Ada.Strings.Both));

            when Skipped =>
               Status := To_Unbounded_String ("SKIPPED");

            when Failed_To_Launch =>
               Status := To_Unbounded_String ("FAILED_TO_LAUNCH");
         end case;

         Set_Field (Val        => Job_Summary,
                    Field_Name => TEXT_STATUS,
                    Field      => To_String (Status));
      end;

      Set_Field (Val        => Job_Summary,
                 Field_Name => TEXT_STDOUT,
                 Field      => To_String (Stdout));
      Set_Field (Val        => Job_Summary,
                 Field_Name => TEXT_STDERR,
                 Field      => To_String (Stderr));
      GNATCOLL.JSON.Append (Arr => Self.JSON, Val => Job_Summary);

      return GPR2.Build.Process_Manager.Object (Self).Collect_Job
        (Job, Proc_Handler, Stdout, Stderr);
   end Collect_Job;

   -------------
   -- Execute --
   -------------

   overriding
   procedure Execute
     (Self      : in out Object;
      Tree_Db   : GPR2.Build.Tree_Db.Object_Access;
      Jobs      : Natural := 0)
   is
      JSON_File : constant GPR2.Path_Name.Object :=
                    GPR2.Path_Name.Create_File ("jobs.json");
   begin
      Self.JSON_File := JSON_File;
      GPR2.Build.Process_Manager.Object (Self).Execute (Tree_Db, Jobs);
   end Execute;

   procedure Execute
     (Self      : in out Object;
      Tree_Db   : GPR2.Build.Tree_Db.Object_Access;
      Jobs      : Natural := 0;
      JSON_File : GPR2.Path_Name.Object)
   is
   begin
      if not JSON_File.Is_Defined then
         raise Program_Error with
           "Provided JSON file for the process manager is invalid";
      end if;

      Self.JSON_File := JSON_File;
      GPR2.Build.Process_Manager.Object (Self).Execute (Tree_Db, Jobs);
   end Execute;

   overriding
   procedure Execution_Post_Process (Self : in out Object) is
      File : File_Type;
   begin
      Create (File, Out_File, Self.JSON_File.String_Value);
      Put_Line (File, Write (Create (Self.JSON)) & ASCII.CR & ASCII.LF);
      Close (File);
   end Execution_Post_Process;

end GPR2.Build.Process_Manager.JSON;
