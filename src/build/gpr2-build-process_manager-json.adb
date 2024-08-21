--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

with GNATCOLL.OS.Process;
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
       Job            : in out Actions.Object'Class;
       Proc_Handler   : Process_Handler;
       Stdout, Stderr : Unbounded_String)
      return Collect_Status
   is
      Job_Summary : constant JSON_Value := Create_Object;
      Env_Summary : JSON_Value;
      Cmd         : Unbounded_String;
      Args        : GNATCOLL.OS.Process.Argument_List;
      Env         : GNATCOLL.OS.Process.Environment_Dict;

   begin
      if not Job.View.Is_Externally_Built then
         Job_Summary.Set_Field (TEXT_ACTION_UID, Job.UID.Image);

         Job.Compute_Command (Args, Env);

         for Arg of Args loop
            if Length (Cmd) > 0 then
               Append (Cmd, " ");
            end if;

            Append (Cmd, Arg);
         end loop;

         Job_Summary.Set_Field (TEXT_COMMAND, Cmd);

         if not Env.Is_Empty then
            Env_Summary := Create_Object;

            for C in Env.Iterate loop
               declare
                  Key  : constant UTF8_String :=
                           GNATCOLL.OS.Process.Env_Dicts.Key (C);
                  Elem : constant UTF8_String :=
                           GNATCOLL.OS.Process.Env_Dicts.Key (C);
               begin
                  Env_Summary.Set_Field (Key, Elem);
               end;
            end loop;

            Job_Summary.Set_Field (TEXT_ENV, Env_Summary);
         end if;

         Job_Summary.Set_Field (TEXT_CWD, Job.Working_Directory.String_Value);

         case Proc_Handler.Status is
            when Running =>
               --  ??? Use a custom exception
               raise Program_Error with
                 "The process linked to the action '" & Job.UID.Image &
                 "' is still running. Cannot collect the job before it " &
                 "finishes";

            when Finished =>
               Job_Summary.Set_Field
                 (TEXT_STATUS,
                  Ada.Strings.Fixed.Trim
                    (Proc_Handler.Process_Status'Image, Ada.Strings.Left));

            when Skipped =>
               Job_Summary.Set_Field (TEXT_STATUS, "SKIPPED");

            when Failed_To_Launch =>
               Job_Summary.Set_Field (TEXT_STATUS, "FAILED_TO_LAUNCH");
         end case;

         Job_Summary.Set_Field (TEXT_STDOUT, Stdout);
         Job_Summary.Set_Field (TEXT_STDERR, Stderr);

         GNATCOLL.JSON.Append (Self.JSON, Job_Summary);
      end if;

      return GPR2.Build.Process_Manager.Object (Self).Collect_Job
        (Job, Proc_Handler, Stdout, Stderr);
   end Collect_Job;

   -------------
   -- Execute --
   -------------

   overriding
   procedure Execute
     (Self         : in out Object;
      Tree_Db      : GPR2.Build.Tree_Db.Object_Access;
      Jobs         : Natural := 0;
      Verbosity    : Execution_Verbosity := Minimal;
      Stop_On_Fail : Boolean := True)
   is
      JSON_File : constant GPR2.Path_Name.Object :=
                    GPR2.Path_Name.Create_File ("jobs.json");
   begin
      Self.JSON_File := JSON_File;
      GPR2.Build.Process_Manager.Object (Self).Execute
        (Tree_Db, Jobs, Verbosity, Stop_On_Fail);
   end Execute;

   procedure Execute
     (Self         : in out Object;
      Tree_Db      : GPR2.Build.Tree_Db.Object_Access;
      Jobs         : Natural := 0;
      JSON_File    : GPR2.Path_Name.Object;
      Verbosity    : Execution_Verbosity := Minimal;
      Stop_On_Fail : Boolean := True)
   is
   begin
      if not JSON_File.Is_Defined then
         raise Program_Error with
           "Provided JSON file for the process manager is invalid";
      end if;

      Self.JSON_File := JSON_File;
      GPR2.Build.Process_Manager.Object (Self).Execute
        (Tree_Db, Jobs, Verbosity, Stop_On_Fail);
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
