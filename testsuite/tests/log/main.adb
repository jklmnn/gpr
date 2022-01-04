------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                     Copyright (C) 2019-2022, AdaCore                     --
--                                                                          --
-- This is  free  software;  you can redistribute it and/or modify it under --
-- terms of the  GNU  General Public License as published by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for more details.  You should have received  a copy of the  GNU  --
-- General Public License distributed with GNAT; see file  COPYING. If not, --
-- see <http://www.gnu.org/licenses/>.                                      --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Text_IO; use Ada.Text_IO;

with GPR2.Log;
with GPR2.Message;
with GPR2.Source_Reference;

procedure Main is
   use GPR2;

   procedure Display_Status (Log : GPR2.Log.Object);
   --  Display log status

   --------------------
   -- Display_Status --
   --------------------

   procedure Display_Status (Log : GPR2.Log.Object) is
   begin
      New_Line;
      Put_Line ("Log is empty: " & Boolean'Image (Log.Is_Empty));

      Put_Line
        ("Has_Element (info) "
           & Boolean'Image (Log.Has_Element (Information => True,
                                             Warning     => False,
                                             Error       => False,
                                             Read        => False,
                                             Unread      => True)));
      Put_Line
        ("Has_Element (warn) "
           & Boolean'Image (Log.Has_Element (Information => False,
                                             Warning     => True,
                                             Error       => False,
                                             Read        => False,
                                             Unread      => True)));
      Put_Line
        ("Has_Element (error) "
           & Boolean'Image (Log.Has_Element (Information => False,
                                             Warning     => False,
                                             Error       => True,
                                             Read        => False,
                                             Unread      => True)));
      Put_Line
        ("Has_Element (read) "
           & Boolean'Image (Log.Has_Element (Information => True,
                                             Warning     => True,
                                             Error       => True,
                                             Read        => True,
                                             Unread      => False)));
      Put_Line
        ("Has_Element (unread) "
           & Boolean'Image (Log.Has_Element (Information => True,
                                             Warning     => True,
                                             Error       => True,
                                             Read        => False,
                                             Unread      => True)));
   end Display_Status;

   Log : GPR2.Log.Object;

begin
   Put_Line ("Log is empty: " & Boolean'Image (Log.Is_Empty));

   Log.Append
     (Message.Create
        (Message.Warning, "test warning",
         Source_Reference.Create ("/ada/prj1.gpr", 1, 2)));
   Log.Append
     (Message.Create
        (Message.Error, "test error",
         Source_Reference.Create ("/ada/prj2.gpr", 2, 3)));
   Log.Append
     (Message.Create
        (Message.Information, "test information",
         Source_Reference.Create ("/ada/prj3.gpr", 3, 4)));

   Display_Status (Log);

   --  Read errors

   for E in Log.Iterate (Error       => True,
                         Warning     => False,
                         Information => False,
                         Read        => False,
                         Unread      => True)
   loop
      Put_Line (Log (E).Format);
   end loop;

   Display_Status (Log);

   --  Read warning

   for E in Log.Iterate (Error       => False,
                         Warning     => True,
                         Information => False,
                         Read        => False,
                         Unread      => True)
   loop
      Put_Line (Log (E).Format);
   end loop;

   Display_Status (Log);

   --  Read information

   for E in Log.Iterate (Error       => False,
                         Warning     => False,
                         Information => True,
                         Read        => False,
                         Unread      => True)
   loop
      Put_Line (Log (E).Format);
   end loop;

   Display_Status (Log);
end Main;
