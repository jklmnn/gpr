--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-Exception
--

with Ada.Text_IO;

package body GPR2.Reporter.Console is

   ------------
   -- Create --
   ------------

   function Create (Verbosity           : Verbosity_Level := Regular;
                    Use_Full_Pathname   : Boolean := False;
                    Level_Report_Format : Level_Format  := Long) return Object
   is
   begin
      return
        (Verbosity => Verbosity,
         Full_Path => Use_Full_Pathname,
         Level_Fmt => Level_Report_Format);
   end Create;

   ---------------------
   -- Internal_Report --
   ---------------------

   overriding procedure Internal_Report
     (Self : in out Object; Message : GPR2.Message.Object)
   is
      use Ada.Text_IO;
   begin
      Put_Line
        ((case Message.Level is
            when End_User | Hint | Lint => Current_Output,
            when Error | Warning    => Current_Error),
         Message.Format (Self.Full_Path, Self.Level_Fmt));
   end Internal_Report;

   -----------------------
   -- Set_Full_Pathname --
   -----------------------

   procedure Set_Full_Pathname
     (Self : in out Object; Use_Full_Pathname : Boolean)
   is
   begin
      Self.Full_Path := Use_Full_Pathname;
   end Set_Full_Pathname;

   -----------------------------
   -- Set_Level_Report_Format --
   -----------------------------

   procedure Set_Level_Report_Format
     (Self : in out Object; Level_Report_Format : Level_Format)
   is
   begin
      Self.Level_Fmt := Level_Report_Format;
   end Set_Level_Report_Format;

   -------------------
   -- Set_Verbosity --
   -------------------

   procedure Set_Verbosity (Self : in out Object; Verbosity : Verbosity_Level)
   is
   begin
      Self.Verbosity := Verbosity;
   end Set_Verbosity;

   ---------------
   -- Verbosity --
   ---------------

   overriding function Verbosity (Self : Object) return Verbosity_Level is
   begin
      return Self.Verbosity;
   end Verbosity;

end GPR2.Reporter.Console;
