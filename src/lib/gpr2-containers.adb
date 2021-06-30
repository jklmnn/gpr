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

with GNAT.String_Split;

package body GPR2.Containers is

   generic
      type Item (<>) is new String;
      with package List is
        new Ada.Containers.Indefinite_Vectors (Positive, Item);
   function Create_G
     (Value     : Item;
      Separator : Item) return List.Vector;

   ------------
   -- Create --
   ------------

   function Create_G
     (Value     : Item;
      Separator : Item) return List.Vector
   is
      use GNAT.String_Split;

      Result : List.Vector;
      Slices : Slice_Set;
   begin
      Create (Slices, String (Value), String (Separator), Mode => Multiple);

      for K in 1 .. Slice_Count (Slices) loop
         declare
            Value : constant Item := Item (Slice (Slices, K));
         begin
            if Value /= "" then
               Result.Append (Value);
            end if;
         end;
      end loop;

      return Result;
   end Create_G;

   pragma Style_Checks (Off);

   function Create
     (Value     : Value_Type;
      Separator : Value_Not_Empty) return Containers.Value_List
   is
      function Internal is
        new Create_G (Value_Type, GPR2.Containers.Value_Type_List);
   begin
      return Internal (Value, Separator);
   end Create;

   function Create
     (Value     : Name_Type;
      Separator : Name_Type) return Containers.Name_List
   is
      function Internal is
        new Create_G (Name_Type, GPR2.Containers.Name_Type_List);
   begin
      return Internal (Value, Separator);
   end Create;

   pragma Style_Checks (On);

   -----------
   -- Image --
   -----------

   function Image (Values : Value_List) return String is
      Result : Unbounded_String;
      First  : Boolean := True;
   begin
      Append (Result, '(');

      for V of Values loop
         if not First then
            Append (Result, ", ");
         end if;

         Append (Result, '"' & String (V) & '"');
         First := False;
      end loop;

      Append (Result, ')');

      return To_String (Result);
   end Image;

   function Image (Values : Source_Value_List) return String is
      L : Value_List;
   begin
      for V of Values loop
         L.Append (V.Text);
      end loop;

      return Image (L);
   end Image;

   ----------------------
   -- Value_Or_Default --
   ----------------------

   function Value_Or_Default
     (Map     : Name_Value_Map;
      Key     : Name_Type;
      Default : Value_Type := No_Value) return Value_Type
   is
      C : constant Name_Value_Map_Package.Cursor := Map.Find (Key);
   begin
      if Name_Value_Map_Package.Has_Element (C) then
         return Map (C);
      else
         return Default;
      end if;
   end Value_Or_Default;

end GPR2.Containers;
