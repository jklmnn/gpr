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

--  This package defines a source Object. This source object is shared with all
--  loaded project tree.

with Ada.Calendar;

with GPR2.Unit;
with GPR2.Unit.List;
with GPR2.Path_Name;
with GPR2.Source_Info;

package GPR2.Source is

   --  use type GPR2.Unit.Library_Unit_Type;

   type Object is new Source_Info.Object with private;

   Undefined : constant Object;
   --  This constant is equal to any object declared without an explicit
   --  initializer.

   overriding function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function "<" (Left, Right : Object) return Boolean;

   overriding function "=" (Left, Right : Object) return Boolean;
   --  A source object is equal if it is the same unit for unit based language,
   --  and if it is the same filename otherwise.

   function Path_Name (Self : Object) return Path_Name.Object
     with Pre => Self.Is_Defined;
   --  Returns the path-name for the given source

   function Timestamp (Self : Object; ALI : Boolean) return Ada.Calendar.Time
     with Pre => Self.Is_Defined;
   --  Returns last modification time for this source
   --  If Ali is True then timestamp returned as it is rounded in ALI files.

   function Check_Timestamp (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Check is the timestamp kept in the object corresponds to source filename
   --  timestamp.

   function Create
     (Filename : GPR2.Path_Name.Object;
      Language : Language_Id;
      Kind     : GPR2.Unit.Library_Unit_Type) return Object'Class
     with Pre  => Filename.Is_Defined and then Language /= Ada_Language,
          Post => Create'Result.Is_Defined;
   --  Constructor for a non-Ada source object

   function Create_Ada
     (Filename      : GPR2.Path_Name.Object;
      Units         : GPR2.Unit.List.Object) return Object'Class
     with Pre  => Filename.Is_Defined and then not Units.Is_Empty,
          Post => Create_Ada'Result.Is_Defined;
   --  Constructor for a multi-unit Ada source object.
   --  Information in Units parameter came from filenames and
   --  project information only. It can be different from function
   --  Units call results because Separate Ada units can be
   --  determined only on parsing source files.

   function Create_Ada
     (Filename      : GPR2.Path_Name.Object;
      Unit          : GPR2.Unit.Object;
      Is_RTS_Source : Boolean) return Object'Class
     with Pre  => Filename.Is_Defined and then Unit.Is_Defined,
     Post => Create_Ada'Result.Is_Defined;
   --  Constructor for a single-unit Ada source object

private

   function To_ALI_Timestamp (Stamp : Calendar.Time) return Calendar.Time;
   --  Round Timestamp to the precision used in ALI file. On windows use first
   --  greater time with an even number of second.

   type Object is new Source_Info.Object with record
      Path_Name : GPR2.Path_Name.Object;
      Timestamp : Calendar.Time := No_Time;
      Ada_Key   : Unbounded_String;
   end record;

   Undefined : constant Object :=
                 Object'(Source_Info.Undefined
                         with others => <>);

   overriding function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

   function Timestamp (Self : Object; ALI : Boolean) return Ada.Calendar.Time
   is (if ALI then To_ALI_Timestamp (Self.Timestamp) else Self.Timestamp);

   function Path_Name (Self : Object) return GPR2.Path_Name.Object is
     (Self.Path_Name);

end GPR2.Source;
