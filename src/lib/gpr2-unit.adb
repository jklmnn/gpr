------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                    Copyright (C) 2019-2021, AdaCore                      --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Strings.Maps.Constants;

package body GPR2.Unit is

   -----------------------
   -- Set_Separate_From --
   -----------------------

   procedure Set_Separate_From (Self : in out Object; Name : Name_Type) is
   begin
      Self.Sep_From := To_Unbounded_String (String (Name));
      Self.Kind     := S_Separate;
   end Set_Separate_From;

   -----------------
   -- Update_Kind --
   -----------------

   procedure Update_Kind (Self : in out Object; Kind : Library_Unit_Type) is
   begin
      Self.Kind := Kind;
   end Update_Kind;

   ---------------------
   -- Valid_Unit_Name --
   ---------------------

   function Valid_Unit_Name
     (Unit_Name : Name_Type;
      On_Error  : access procedure (Message : String) := null) return Boolean
   is
      use Ada.Strings.Maps;

      function Not_Valid return String is
        ("unit '" & String (Unit_Name)  & "' not valid, ");

      procedure Error (Message : String);

      -----------
      -- Error --
      -----------

      procedure Error (Message : String) is
      begin
         if On_Error /= null then
            On_Error (Message);
         end if;
      end Error;

   begin
      --  Must start with a letter

      if not Is_In
        (Unit_Name (Unit_Name'First),
         Constants.Letter_Set or To_Set ("_"))
      then
         Error (Not_Valid & "should start with a letter or an underscore");
         return False;
      end if;

      --  Cannot have dot and underscores one after anothers and should
      --  contains only alphanumeric characters.

      for K in Unit_Name'First + 1 .. Unit_Name'Last loop
         declare
            Two_Chars : constant Name_Type := Unit_Name (K - 1 .. K);
         begin
            if Two_Chars = "_." then
               Error (Not_Valid & "cannot contain dot after underscore");
               return False;

            elsif Two_Chars = "__" then
               Error (Not_Valid & "two consecutive underlines not permitted");
               return False;

            elsif Two_Chars = "._" then
               Error (Not_Valid & "cannot contain underscore after dot");
               return False;

            elsif Two_Chars = ".." then
               Error (Not_Valid & "two consecutive dots not permitted");
               return False;

            elsif not Characters.Handling.Is_Alphanumeric (Unit_Name (K))
              and then Unit_Name (K) not in '.' | '_'
            then
               Error (Not_Valid & "should have only alpha numeric characters");
               return False;
            end if;
         end;
      end loop;

      return True;
   end Valid_Unit_Name;

end GPR2.Unit;
