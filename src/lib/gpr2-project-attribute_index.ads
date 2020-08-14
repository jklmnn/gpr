------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                       Copyright (C) 2020, AdaCore                        --
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

--  This object represents an atribute index. Such index can be "others" or any
--  string representing a lnagugage or a source filename for example.

with GPR2.Source_Reference.Value;

package GPR2.Project.Attribute_Index is

   type Object is new Source_Reference.Value.Object with private;

   overriding function "=" (Left, Right : Object) return Boolean;
   --  Returns True if the attribute's index is equal to Value taking into
   --  account the case-sensitivity of the index.

   Undefined : constant Object;

   Any       : constant Object;
   --  Represents any indexex values

   overriding function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function Create
     (Index          : Source_Reference.Value.Object;
      Is_Others      : Boolean;
      Case_Sensitive : Boolean) return Object
     with Pre  => Index.Is_Defined,
          Post => Create'Result.Is_Defined;

   function Create
     (Value          : Value_Type;
      Case_Sensitive : Boolean := False) return Object
     with Post => Create'Result.Is_Defined;

   function Is_Others (Self : Object) return Boolean
     with Pre => Self.Is_Defined;

   function Is_Any_Index (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if the attribute can be returned from the set for any
   --  index in a request. Main case to use such attributes is to get attribute
   --  with default value from the set when the default value defined for any
   --  index.

   function Is_Case_Sensitive (Self : Object) return Boolean
     with Pre => Self.Is_Defined;

   function Value
     (Self          : Object;
      Preserve_Case : Boolean := True) return Value_Type
     with Pre => Self.Is_Defined;

   procedure Set_Case
     (Self              : in out Object;
      Is_Case_Sensitive : Boolean)
     with Pre => Self.Is_Defined;

private

   type Object is new Source_Reference.Value.Object with record
      Is_Others      : Boolean := False;
      Case_Sensitive : Boolean := True;
   end record
     with Dynamic_Predicate =>
       (if Object.Is_Others
        then Source_Reference.Value.Object (Object).Text = "others");

   Undefined : constant Object :=
                 (Source_Reference.Value.Undefined with others => <>);

   Any       : constant Object :=
                 (Source_Reference.Value.Object
                    (Source_Reference.Value.Create
                       (Filename => "/any",
                        Line     => 0,
                        Column   => 0,
                        Text     => (1 => ASCII.NUL))) with others => <>);

   overriding function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

   function Is_Others (Self : Object) return Boolean is (Self.Is_Others);

   function Is_Any_Index (Self : Object) return Boolean is (Self = Any);

   function Create
     (Index          : Source_Reference.Value.Object;
      Is_Others      : Boolean;
      Case_Sensitive : Boolean) return Object
   is (Index with Is_Others, Case_Sensitive);

   function Create
     (Value          : Value_Type;
      Case_Sensitive : Boolean := False) return Object
   is
     (Create (Source_Reference.Value.Object
              (Source_Reference.Value.Create
               (Source_Reference.Builtin, Value)),
              False, Case_Sensitive));

   function Is_Case_Sensitive (Self : Object) return Boolean is
     (Self.Case_Sensitive);

   function Value
     (Self          : Object;
      Preserve_Case : Boolean := True) return Value_Type
   is
     (if Preserve_Case
      then Self.Text
      else Ada.Characters.Handling.To_Lower (Self.Text));

end GPR2.Project.Attribute_Index;
