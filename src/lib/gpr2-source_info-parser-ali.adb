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

with Ada.Calendar.Formatting;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;

with GNATCOLL.Utils;

with GPR2.Path_Name;
with GPR2.Project.Unit_Info;
with GPR2.Project.Source.Artifact;
with GPR2.Project.Tree;
with GPR2.Project.View;
with GPR2.Source_Info.Parser.Registry;

package body GPR2.Source_Info.Parser.ALI is

   Handle : Object;

   Scan_ALI_Error : exception;

   function "+" (Item : String) return Unbounded_String
                 renames To_Unbounded_String;

   procedure Compute
     (Self   : in out Object;
      Data   : in out Source_Info.Object'Class;
      Source : GPR2.Path_Name.Object;
      LI     : Path_Name.Object'Class;
      U_Ref  : in out GPR2.Unit.Object;
      View   : Project.View.Object);
   --  Parse single ALI file

   procedure Union
     (Target : in out Dependency_Maps.Map; Source : Dependency_Maps.Map);

   package IO is

      use Ada.Streams;

      Size_Chunk : constant := 2_048;
      --  Size of the chunk read by the implementation

      type Handle is record
         FD      : Stream_IO.File_Type;
         Buffer  : Stream_Element_Array (1 .. Size_Chunk);
         Current : Stream_Element_Offset := -1;
         Last    : Stream_Element_Offset := -1;
         Line    : Positive := 1;
         At_LF   : Boolean := False;
      end record;

      procedure Open
        (File     : in out Handle;
         Filename : GPR2.Path_Name.Object'Class)
        with Post => Stream_IO.Is_Open (File.FD)
        and then File.Current = 0
        and then File.Last >= 0;
      --  Open Filename and initialize the corresponding handle

      procedure Close (File : in out Handle)
        with Post => not Stream_IO.Is_Open (File.FD);

      function Get_Token
        (File          : in out Handle;
         Stop_At_LF    : Boolean := False;
         May_Be_Quoted : Boolean := False) return String
        with Pre => Stream_IO.Is_Open (File.FD);
      --  Get next token on the file.
      --  If Stop_At_LF is True, then no token will be read after the current
      --  line is finished; calling again with Stop_At_LF => False (through a
      --  call to Next_Line for instance) allows further reading.
      --  The result is "" if either we got LF in Stop_At_LF mode, or EOF.

      procedure Next_Line (File : in out Handle; Header : in out Character)
        with Pre => Stream_IO.Is_Open (File.FD);
      --  Skips to the next (non-empty) line and sets Header.
      --  If no such line exists, Header is set to NUL.

      function At_LF (File : Handle) return Boolean;

   end IO;

   --------
   -- IO --
   --------

   package body IO is

      procedure Fill_Buffer (File : in out Handle)
        with Inline, Post => File.Current = 0;
      --  Read a chunk of data in the buffer or nothing if there is no more
      --  data to read.

      -----------
      -- At_LF --
      -----------

      function At_LF (File : Handle) return Boolean is
        (File.At_LF);

      -----------
      -- Close --
      -----------

      procedure Close (File : in out Handle) is
      begin
         Stream_IO.Close (File.FD);
      end Close;

      -----------------
      -- Fill_Buffer --
      -----------------

      procedure Fill_Buffer (File : in out Handle) is
      begin
         Stream_IO.Read (File.FD, File.Buffer, File.Last);
         File.Current := 0;
      end Fill_Buffer;

      ---------------
      -- Get_Token --
      ---------------

      function Get_Token
        (File          : in out Handle;
         Stop_At_LF    : Boolean := False;
         May_Be_Quoted : Boolean := False) return String
      is
         function Next_Char return Character with Inline;
         --  Get next char in buffer

         subtype Content_Index is Natural range 0 .. 1_024;
         subtype Content_Range is Content_Index range 1 .. Content_Index'Last;

         Tok : String (Content_Range);
         Cur : Content_Index := 0;
         C   : Character     := ASCII.NUL;

         Quoted : Boolean := False;
         QN     : Natural := 0;

         procedure Get_Word with Inline;
         --  Read a word, result will be in Tok (Tok'First .. Cur)

         function Is_Separator return Boolean;
         --  The C character is separator

         function Is_Space return Boolean is
           (C in ' ' | ASCII.HT | ASCII.CR | ASCII.LF | ASCII.EOT);
         --  The C character is space

         --------------
         -- Get_Word --
         --------------

         procedure Get_Word is
         begin
            loop
               C := Next_Char;

               if Is_Separator then
                  File.Current := File.Current - 1;
                  exit;

               else
                  Cur := Cur + 1;
                  Tok (Cur) := C;
               end if;
            end loop;
         end Get_Word;

         ------------------
         -- Is_Separator --
         ------------------

         function Is_Separator return Boolean is
         begin
            if Quoted then
               if C = '"' then
                  QN := QN + 1;
                  if QN = 2 then
                     Cur := Cur - 1;
                     QN := 0;
                  end if;

               elsif QN = 1 then
                  if Is_Space then
                     return True;
                  else
                     Cur := Cur + 1;
                     Tok (Cur) := C;

                     raise Scan_ALI_Error with
                       "Wrong quoted format of '" & Tok (Tok'First .. Cur)
                       & ''';
                  end if;
               end if;

               return False;

            else
               return Is_Space;
            end if;
         end Is_Separator;

         ---------------
         -- Next_Char --
         ---------------

         function Next_Char return Character is
         begin
            if File.Current = File.Last then
               if Stream_IO.End_Of_File (File.FD) then
                  --  Nothing more to read
                  return ASCII.EOT;
               else
                  Fill_Buffer (File);
               end if;
            end if;

            File.Current := File.Current + 1;
            return Character'Val (File.Buffer (File.Current));
         end Next_Char;

      begin
         Read_Token : loop
            if Stop_At_LF and then File.At_LF then
               return "";
            end if;

            File.At_LF := False;

            C := Next_Char;

            Cur := 1;
            Tok (Cur) := C;

            if May_Be_Quoted and then C = '"' then
               Quoted := True;
            end if;

            if not Is_Space then
               Get_Word;
               exit Read_Token;

            elsif C = ASCII.EOT then
               Cur := 0;
               exit Read_Token;

            elsif C = ASCII.LF then
               File.At_LF := True;
               File.Line := File.Line + 1;
            end if;
         end loop Read_Token;

         return Tok (1 .. Cur);
      end Get_Token;

      ---------------
      -- Next_Line --
      ---------------

      procedure Next_Line (File : in out Handle; Header : in out Character) is
         Old_Line : constant Positive := File.Line;
         At_LF    : constant Boolean  := File.At_LF;
         Current  : constant Stream_Element_Offset := File.Current;
      begin
         loop
            declare
               Tok : constant String := Get_Token (File);
            begin
               if Tok = "" then
                  Header := ASCII.NUL;
                  return;

               elsif File.Line > Old_Line
                 or else (At_LF and then File.Line = Old_Line)
                 --  This second condition is for the case we hit LF in a
                 --  previous call to Get_Token, with Stop_At_LF => True.
                 --  The line number will then be unchanged.
                 or else (Current = 0 and then File.Line = 1)
               --  This third condition is for the special case of the very
               --  first read.
               then
                  Header := Tok (1);
                  return;
               end if;
            end;
         end loop;
      end Next_Line;

      ----------
      -- Open --
      ----------

      procedure Open
        (File     : in out Handle;
         Filename : GPR2.Path_Name.Object'Class) is
      begin
         Stream_IO.Open (File.FD, Stream_IO.In_File, Filename.Value);
         Fill_Buffer (File);
         File.Line := 1;
      end Open;

   end IO;

   -----------------
   -- Clear_Cache --
   -----------------

   overriding procedure Clear_Cache (Self : not null access Object) is
   begin
      Self.Cache.Clear;
   end Clear_Cache;

   -------------
   -- Compute --
   -------------

   procedure Compute
     (Self   : in out Object;
      Data   : in out Source_Info.Object'Class;
      Source : GPR2.Path_Name.Object;
      LI     : Path_Name.Object'Class;
      U_Ref  : in out GPR2.Unit.Object;
      View   : Project.View.Object)
   is
      use all type GPR2.Unit.Library_Unit_Type;

      A_Handle : IO.Handle;

      --  Unit data

      subtype CU_Index is Natural range 0 .. 2;

      LI_Idx  : constant Unit_Index  := Unit_Index (U_Ref.Index);
      B_Name  : constant Simple_Name := Source.Simple_Name;
      U_Name  : Unbounded_String;
      S_Name  : Unbounded_String;
      U_Kind  : GPR2.Unit.Library_Unit_Type;
      U_Flags : GPR2.Unit.Flags_Set         := GPR2.Unit.Default_Flags;
      Main    : GPR2.Unit.Main_Type         := GPR2.Unit.None;
      L_Type  : GPR2.Unit.Library_Item_Type := GPR2.Unit.Is_Package;
      Withs   : Source_Reference.Identifier.Set.Object;

      CUs     : array (CU_Index range 1 .. 2) of GPR2.Unit.Object;
      CU_TS   : array (CU_Index range 1 .. 2) of Ada.Calendar.Time;
      CU_CS   : array (CU_Index range 1 .. 2) of Word;
      CU_BN   : array (CU_Index range 1 .. 2) of Unbounded_String;
      --  Units' corresponding source base name

      CU_Idx  : CU_Index := 0;
      Current : CU_Index := 0;

      procedure Fill_Dep;
      --  Add dependency from D line

      procedure Fill_Unit;
      --  Add all units defined in ALI (spec, body or both)

      procedure Fill_With;
      --  Add all withed units into Withs below

      procedure Set_Source_Info_Data (Cache : Cache_Holder);
      --  Set returned source infor data

      function Key
        (LI       : Path_Name.Object'Class;
         Basename : Simple_Name;
         Kind     : GPR2.Unit.Library_Unit_Type) return String
      is (Path_Name.To_OS_Case
            (LI.Value & '@' & String (Basename) & '|'
             & (case Kind is
                   when GPR2.Unit.Body_Kind => 'b',
                   when GPR2.Unit.Spec_Kind => 's',
                   when GPR2.Unit.S_Separate => raise Program_Error)));

      --------------
      -- Fill_Dep --
      --------------

      procedure Fill_Dep is

         function Checksum (S : String) return Word;

         function Get_Token (May_Be_Quoted : Boolean := False) return String;

         function Time_Stamp (S : String) return Ada.Calendar.Time;

         function To_Unit_Name return String;
         --  This routine is needed only on GNAT version 7.2.2 and older,
         --  because unit name and kind is not defined in D lines.
         --  Get unit name from project tree if available.
         --  Put unresolved dependency into queue to resolve it later.

         --------------
         -- Checksum --
         --------------

         function Checksum (S : String) return Word is
            Chk : Word := 0;
            Hex : Word;
         begin
            if S'Length /= 8 then
               raise Scan_ALI_Error with
                 "Wrong checksum length" & S'Length'Img;
            end if;

            for C of S loop
               case C is
                  when '0' .. '9' =>
                     Hex := Character'Pos (C) - Character'Pos ('0');

                  when 'a' .. 'f' =>
                     Hex := Character'Pos (C) - Character'Pos ('a') + 10;

                  when others =>
                     raise Scan_ALI_Error with
                       "Wrong character '" & C & "' in checksum";
               end case;

               Chk := Chk * 16 + Hex;
            end loop;

            return Chk;
         end Checksum;

         ---------------
         -- Get_Token --
         ---------------

         function Get_Token (May_Be_Quoted : Boolean := False) return String is
            Tok : constant String :=
                    IO.Get_Token
                      (A_Handle, Stop_At_LF => True,
                       May_Be_Quoted => May_Be_Quoted);
         begin
            if Tok = "" then
               raise Scan_ALI_Error with "Missed dependency field";
            else
               return Tok;
            end if;
         end Get_Token;

         ----------------
         -- Time_Stamp --
         ----------------

         function Time_Stamp (S : String) return Ada.Calendar.Time is
            T : String (1 .. 14);
         begin
            if S'Length /= 14 then
               raise Scan_ALI_Error with
                 "Wrong timestamp """ & S & """ length" & S'Length'Img;
            end if;

            T := S;

            return Ada.Calendar.Formatting.Value
              (T (1 .. 4) & "-" & T (5 .. 6) & "-" & T (7 .. 8) & " "
               & T (9 .. 10) & ":" & T (11 .. 12) & ":" & T (13 .. 14));
         end Time_Stamp;

         Sfile  : constant String            := Get_Token (True);
         Stamp  : constant Ada.Calendar.Time := Time_Stamp (Get_Token);
         Chksum : constant Word              := Checksum (Get_Token);
         Forth  : constant String            :=
                    IO.Get_Token (A_Handle, Stop_At_LF => True);
         --  Could be empty on *.adc file dependency, preprocessor files or on
         --  GNAT version 7.2.2 and older.

         use GPR2.Unit;

         Kind : Library_Unit_Type;
         Taken_From_Tree : Boolean := False;

         ------------------
         -- To_Unit_Name --
         ------------------

         function To_Unit_Name return String is
            Path : constant Path_Name.Object :=
                     Path_Name.Create_File
                       (Simple_Name (Sfile), Path_Name.No_Resolution);
            Tree : constant access Project.Tree.Object := View.Tree;
            View : Project.View.Object := Tree.Get_View (Path);
            Source : Project.Source.Object;
         begin
            if not View.Is_Defined then
               Tree.Update_Sources
                 (Stop_On_Error => False,
                  With_Runtime  => True,
                  Backends      => No_Backends);

               View := Tree.Get_View (Path);

               if not View.Is_Defined then
                  return "";
               end if;
            end if;

            Source := View.Source (Path);

            pragma Assert (Source.Is_Defined);

            Taken_From_Tree := True;
            Kind := Source.Source.Kind;

            return To_Lower (Source.Source.Unit_Name);
         end To_Unit_Name;

         Name : constant String :=
                  (if Forth = "" and then Chksum /= 0 -- GNAT 7.2.2 and older
                   then To_Unit_Name else Forth);
         --  Unit_Name

         function Kind_Len return Natural is
           (if Kind in S_Spec | S_Body and then not Taken_From_Tree
            then 2 else 0);
         --  Length of suffix denoting dependency kind

         function Image (Dep : Dependency) return String is
           ('"' & Dep.Sfile & ' ' & Formatting.Image (Dep.Stamp)
            & ' ' & To_Hex_String (Dep.Checksum) & '"');

         Suffix : constant String :=
                     (if Forth'Length > 2
                      then Forth (Forth'Last - 1 .. Forth'Last)
                      else "");
         Position : Dependency_Maps.Cursor;
         C_Cache  : Cache_Map.Cursor;
         Inserted : Boolean;
         H_Cache  : Cache_Holder;
         C_Index  : Unit_Dependencies.Cursor;

      begin
         if Suffix = "%s" then
            Kind := S_Spec;

         elsif Suffix = "%b" then
            Kind := S_Body;

         elsif Name = "" then
            --  *.adc and preprocessor file dependencies

            return;

         elsif not Taken_From_Tree then
            Kind := S_Separate;

            if GNATCOLL.Utils.Starts_With
                 (Name, Prefix => To_Lower (CUs (1).Name) & '.')
            then
               H_Cache :=
                 (Create
                    (Name          => Name_Type (Name),
                     Index         => 1, -- Unknown for now
                     Lib_Unit_Kind => S_Separate,
                     Lib_Item_Kind => Is_Package, -- No way to know from ALI
                     Main          => None,       -- No way to know from ALI
                     Dependencies  =>
                       Source_Reference.Identifier.Set.Empty_Set,
                     Sep_From      => Parent_Name (Name_Type (Name)),
                     Flags         => Default_Flags),
                  Dependency_Maps.Empty_Map, Chksum, Stamp);

               Self.Cache.Insert (Name, H_Cache, C_Cache, Inserted);

               if not Inserted and then Self.Cache (C_Cache) /= H_Cache then
                  raise Scan_ALI_Error with "subunit inconsistency " & Name
                    & ' '
                    & (if Self.Cache (C_Cache).Unit.Separate_From
                       /= CUs (1).Name
                       then String (Self.Cache (C_Cache).Unit.Separate_From)
                       & " # " & String (CUs (1).Name) else "");
               end if;
            end if;
         end if;

         for Idx in CU_BN'Range loop
            if Sfile = CU_BN (Idx) then
               CU_TS (Idx) := Stamp;
               CU_CS (Idx) := Chksum;
            end if;
         end loop;

         Data.Dependencies.Insert
           (LI_Idx, Dependency_Maps.Empty_Map, C_Index, Inserted);

         Data.Dependencies (C_Index).Insert
           ((Length    => Name'Length - Kind_Len,
             Unit_Kind => Kind,
             Unit_Name => Name (Name'First .. Name'Last - Kind_Len)),
            (Length    => Sfile'Length,
             Stamp     => Stamp,
             Checksum  => Chksum,
             Sfile     => Sfile), Position, Inserted);

         if not Inserted
           and then not Equal (Dependency_Maps.Element (Position),
                               Sfile, Stamp, Chksum)
         then
            Ada.Text_IO.Put_Line
              ("# " & Image ((Length   => Sfile'Length,
                              SFile    => Sfile,
                              Stamp    => Stamp,
                              Checksum => Chksum)));

            raise Scan_ALI_Error with
              '"' & Name & """ already in dependencies of " & LI.Value
              & " with different data "
              & Image (Dependency_Maps.Element (Position));
         end if;
      end Fill_Dep;

      ---------------
      -- Fill_Unit --
      ---------------

      procedure Fill_Unit is
      begin
         --  Uname, Sfile, Utype

         declare
            Tok1 : constant String :=
                     IO.Get_Token (A_Handle, Stop_At_LF => True);
            Tok2 : constant String :=
                     IO.Get_Token (A_Handle, Stop_At_LF => True);
         begin
            --  At least "?%(b|s)"

            if Tok1'Length < 3 and then Tok1 (Tok1'Last - 1) /= '%' then
               raise Scan_ALI_Error with "Wrong unit name format " & Tok1;
            end if;

            if Tok2 = "" then
               raise Scan_ALI_Error with "File name absent in U line";
            end if;

            --  Set Utype. This will be adjusted after we finish reading the
            --  U lines, in case we have both spec and body.

            case Tok1 (Tok1'Last) is
               when 's'    => U_Kind := GPR2.Unit.S_Spec_Only;
               when 'b'    => U_Kind := GPR2.Unit.S_Body_Only;
               when others =>
                  raise Scan_ALI_Error with "Wrong unit name " & Tok1;
            end case;

            U_Name := +Tok1 (1 .. Tok1'Last - 2);
            S_Name := +Tok2;
         end;

         --  Flags (we skip the unit version)

         loop
            declare
               use GPR2.Unit;

               Tok    : constant String :=
                          IO.Get_Token (A_Handle, Stop_At_LF => True);
               C1, C2 : Character;

            begin
               exit when Tok = "";

               if Tok'Length = 2 then  --  This eliminates the version field

                  C1 := Tok (1);
                  C2 := Tok (2);

                  if C1 = 'B' then
                     --  Elaborate_Body_Desirable, Body_Needed_For_SAL

                     if C2 = 'D' then
                        U_Flags (Elaborate_Body_Desirable) := True;
                     elsif C2 = 'N' then
                        U_Flags (Body_Needed_For_SAL) := True;
                     end if;

                  elsif C1 = 'D' and then C2 = 'E' then
                     --  Dynamic_Elab

                     U_Flags (Dynamic_Elab) := True;

                  elsif C1 = 'E' and then C2 = 'B' then
                     --  Elaborate_Body

                     U_Flags (Elaborate_Body) := True;

                  elsif C1 = 'G' and then C2 = 'E' then
                     --  Is_Generic

                     U_Flags (Is_Generic) := True;

                  elsif C1 = 'I' and then C2 = 'S' then
                     --  Init_Scalars

                     U_Flags (Init_Scalars) := True;

                  elsif C1 = 'N' and then C2 = 'E' then
                     --  No_Elab_Code

                     U_Flags (No_Elab_Code) := True;

                  elsif C1 = 'P' then
                     --  Preelab, Pure, Unit_Kind

                     if C2 = 'R' then
                        U_Flags (Preelab) := True;
                     elsif C2 = 'U' then
                        U_Flags (Pure) := True;
                     elsif C2 = 'K' then
                        L_Type := GPR2.Unit.Is_Package;
                     end if;

                  elsif C1 = 'R' then
                     --  RCI, Remote_Types, Has_RACW

                     if C2 = 'C' then
                        U_Flags (RCI) := True;
                     elsif C2 = 'T' then
                        U_Flags (Remote_Types) := True;
                     elsif C2 = 'A' then
                        U_Flags (Has_RACW) := True;
                     end if;

                  elsif C1 = 'S' then
                     --  Shared_Passive, Unit_Kind

                     if C2 = 'P' then
                        U_Flags (Shared_Passive) := True;
                     elsif C2 = 'U' then
                        L_Type := GPR2.Unit.Is_Subprogram;
                     end if;
                  end if;
               end if;
            end;
         end loop;
      end Fill_Unit;

      ---------------
      -- Fill_With --
      ---------------

      procedure Fill_With is
         N : constant String := IO.Get_Token (A_Handle, Stop_At_LF => True);
         S : constant String := IO.Get_Token (A_Handle, Stop_At_LF => True)
               with Unreferenced;
         A : constant String := IO.Get_Token (A_Handle, Stop_At_LF => True)
               with Unreferenced;

         U_Last : constant Integer := N'Last - 2; -- Unit last character in N
         U_Kind : GPR2.Unit.Library_Unit_Type with Unreferenced;
      begin
         if U_Last <= 0
           or else N (N'Last - 1) /= '%'
           or else N (N'Last) not in 's' | 'b'
         then
            raise Scan_ALI_Error with "Wrong unit name format """ & N & '"';
         end if;

         --  Insert the withed unit without the sloc information. This
         --  information is found at the end of the ALI file and will be
         --  setup later.

         declare
            --  ??? line & column are wrong, we should parse the xref
            Sloc : constant GPR2.Source_Reference.Object :=
                     GPR2.Source_Reference.Object
                       (Source_Reference.Create (Source.Value, 1, 1));
            Position : Source_Reference.Identifier.Set.Cursor;
            Inserted : Boolean;
         begin
            --  With lines could be duplicated, ignore the next duplicated one

            Withs.Insert
              (Source_Reference.Identifier.Create
                 (Sloc => Sloc, Text => Name_Type (N (1 .. U_Last))),
              Position, Inserted);
         end;
      end Fill_With;

      --------------------------
      -- Set_Source_Info_Data --
      --------------------------

      procedure Set_Source_Info_Data (Cache : Cache_Holder) is
         Inserted : Boolean;
         Position : Unit_Dependencies.Cursor;
      begin
         pragma Assert (U_Ref.Index = Cache.Unit.Index);
         pragma Assert
           ((U_Ref.Kind in GPR2.Unit.Spec_Kind)
            = (Cache.Unit.Kind in GPR2.Unit.Spec_Kind),
            "cache inconsistent: " & String (U_Ref.Name)
            & Cache.Unit.Index'Img & ' ' & U_Ref.Kind'Img
            & ' ' & Cache.Unit.Kind'Img);

         U_Ref := Cache.Unit;

         if U_Ref.Index = 1 then
            Data.Kind := U_Ref.Kind;
         end if;

         Data.Parsed       := Source_Info.LI;
         Data.Is_Ada       := True;
         Data.LI_Timestamp := Cache.Timestamp;
         Data.Checksum     := Cache.Checksum;

         Data.Dependencies.Insert
           (LI_Idx, Dependency_Maps.Empty_Map, Position, Inserted);
         Union (Data.Dependencies (Position), Cache.Depends);
      end Set_Source_Info_Data;

      use GPR2.Unit;

      In_Cache : Cache_Map.Cursor :=
                   Self.Cache.Find (Key (LI, B_Name, U_Ref.Kind));
      Inserted : Boolean;

   begin
      --  If this unit is in the cache, return now we don't want to parse
      --  again the whole file.

      if Cache_Map.Has_Element (In_Cache) then
         Set_Source_Info_Data (Cache_Map.Element (In_Cache));
         return;
      end if;

      --  Fill the ALI object up till the XREFs

      IO.Open (A_Handle, LI);

      declare
         Header : Character;  --  Line header, set when calling Next_Line

         procedure Next_Line
           (Expected  : Character := ASCII.NUL;
            Allow_EOF : Boolean   := False)
           with Pre => not (Expected /= ASCII.NUL and then Allow_EOF);
         --  Wrapper to call IO.Next_Line

         ---------------
         -- Next_Line --
         ---------------

         procedure Next_Line
           (Expected  : Character := ASCII.NUL;
            Allow_EOF : Boolean   := False) is
         begin
            IO.Next_Line (A_Handle, Header);

            if Expected /= ASCII.NUL and then Header /= Expected then
               raise Scan_ALI_Error with
                 "Expected '" & Expected & "' but got '" & Header & ''';
            end if;

            if not Allow_EOF and then Header = ASCII.NUL then
               raise Scan_ALI_Error with
                 "Unexpected end of file in " & LI.Value;
            end if;
         end Next_Line;

      begin
         --  Version (V line, mandatory)

         Next_Line (Expected => 'V');

         --  Skip version string

         loop
            Next_Line;

            case Header is
               when 'M' =>
                  --  Scan main program type if exists

                  declare
                     Tok : constant String :=
                             IO.Get_Token (A_Handle, Stop_At_LF => True);
                  begin
                     if Tok = "F" then
                        Main := GPR2.Unit.Is_Function;
                     elsif Tok = "P" then
                        Main := GPR2.Unit.Is_Procedure;
                     else
                        raise Scan_ALI_Error;
                     end if;
                  end;

               when 'A' | 'U' =>
                  --  Skip to Args (A lines), or Units (U lines) if there is
                  --  none. There must be at least one U line.

                  exit;

               when others =>
                  null;
            end case;
         end loop;

         --  Read Args

         while Header = 'A' loop
            --  Skipp compilation arguments
            Next_Line;
            exit when Header /= 'A';
         end loop;

         --  Skip to Units (U lines)

         while Header /= 'U' loop
            Next_Line;
         end loop;

         --  Read Units + {Withs}

         loop
            --  Cannot have more than 2 units:  the spec and the body

            if CU_Idx = 2 then
               raise Scan_ALI_Error;
            end if;

            Fill_Unit;
            Next_Line;

            --  For each unit, read the With list (W/Y/Z lines) if any

            while Header in 'W' | 'Y' | 'Z' loop
               --  Only record explicite with clauses
               if Header in 'W' | 'Y' then
                  Fill_With;
               end if;

               Next_Line;
            end loop;

            --  Record this unit

            CU_Idx := CU_Idx + 1;

            if U_Ref.Name = Name_Type (-U_Name) then
               --  Keep original casing

               U_Name := +String (U_Ref.Name);

            else
               View.Reindex_Unit
                 (From => U_Ref.Name, To => Name_Type (-U_Name));
            end if;

            CUs (CU_Idx) :=
              GPR2.Unit.Create
                (Name          => Name_Type (-U_Name),
                 Index         => U_Ref.Index,
                 Lib_Unit_Kind => U_Kind,
                 Lib_Item_Kind => L_Type,
                 Main          => Main,
                 Dependencies  => Withs,
                 Sep_From      => No_Name,
                 Flags         => U_Flags);

            CU_BN (CU_Idx) := S_Name;

            Withs.Clear;

            if Simple_Name (-S_Name) = B_Name
              and then (U_Kind in GPR2.Unit.Spec_Kind)
                       = (U_Ref.Kind in GPR2.Unit.Spec_Kind)
            then
               Current := CU_Idx;
            end if;

            --  Skip to either the next U section, or the first D line.
            --  There must be at least one D line: the dependency to the
            --  unit itself.

            while Header not in 'U' | 'D' loop
               Next_Line;
            end loop;

            exit when Header /= 'U';
         end loop;

         if Current = 0 then
            if (CU_Idx = 1
                and then U_Ref.Kind = GPR2.Unit.S_Body
                and then CUs (1).Kind = GPR2.Unit.S_Spec_Only)
              or else
                (CU_Idx = 2
                 and then CU_BN (1) = CU_BN (2))
            then
               --  Body file with pragma No_Body

               View.Hide_Unit_Body (U_Ref.Name);
               View.Hide_Unit_Body (CUs (1).Name);
            end if;

            Data.Parsed := Source_Info.None;
            IO.Close (A_Handle);
            return;
         end if;

         --  Read Deps

         while Header = 'D' loop
            Fill_Dep;
            Next_Line (Allow_EOF => True);  --  Only here we allow EOF
         end loop;

         IO.Close (A_Handle);

         --  If we have 2 units, the first one should be the body and the
         --  second one the spec. Update the u_kind accordingly.

         if CU_Idx = 2 then
            pragma Assert (CUs (1).Name = CUs (2).Name);

            if CUs (1).Kind /= GPR2.Unit.S_Body_Only then
               raise Scan_ALI_Error
                 with "Unit body is on the wrong position";
            end if;

            GPR2.Unit.Update_Kind (CUs (1), GPR2.Unit.S_Body);

            if CUs (2).Kind /= GPR2.Unit.S_Spec_Only then
               raise Scan_ALI_Error
                 with "Unit spec is on the wrong position";
            end if;

            GPR2.Unit.Update_Kind (CUs (2), GPR2.Unit.S_Spec);
         end if;

         --  Record into the cache

         for K in 1 .. CU_Idx loop
            Self.Cache.Insert
              (Key (LI, Simple_Name (-CU_BN (K)), CUs (K).Kind),
               (CUs (K), Data.Dependencies (LI_Idx), CU_CS (K), CU_TS (K)),
               In_Cache, Inserted);

            pragma Assert
              (Inserted,
               "couldn't record into cache: " & LI.Value
               & ' ' & String (Cache_Map.Key (In_Cache))
               & Current'Img);

            if Current = K then
               Set_Source_Info_Data (Cache_Map.Element (In_Cache));
            end if;
         end loop;

      exception
         when E : others =>
            Ada.Text_IO.Put_Line
              ("ALI parser error: " & LI.Value
               & ' ' & Ada.Exceptions.Exception_Information (E));

            IO.Close (A_Handle);
            Data.Parsed := Source_Info.None;
      end;
   end Compute;

   -------------
   -- Compute --
   -------------

   overriding procedure Compute
     (Self   : not null access Object;
      Data   : in out Source_Info.Object'Class;
      Source : Project.Source.Object)
   is
      View : constant Project.View.Object := Source.View;
      LI   : Path_Name.Object;
      File : constant Path_Name.Object := Source.Path_Name;

      procedure Check_Separated (SU : in out GPR2.Unit.Object);

      ---------------------
      -- Check_Separated --
      ---------------------

      procedure Check_Separated (SU : in out GPR2.Unit.Object) is

         Name : constant Name_Type := SU.Name;
         Lown : constant String := To_Lower (Name);
         FU   : Project.Unit_Info.Object;
         Src  : Project.Source.Object;
         CS   : Cache_Map.Cursor := Self.Cache.Find (Lown);

         procedure Set_Data;
         --  Set some fields from cache to Source_Info.Object for subunit

         --------------
         -- Set_Data --
         --------------

         procedure Set_Data is
            Ref : constant Cache_Map.Constant_Reference_Type :=
                    Self.Cache.Constant_Reference (CS);
            Inserted : Boolean;
            Position : Unit_Dependencies.Cursor;
         begin
            pragma Assert (SU.Name = Ref.Unit.Name);

            Data.Parsed := Source_Info.LI;
            SU.Set_Separate_From (Ref.Unit.Separate_From);

            if SU.Index = 1 then
               Data.Kind := GPR2.Unit.S_Separate;
            end if;

            Data.Checksum     := Ref.Checksum;
            Data.LI_Timestamp := Ref.Timestamp;

            Data.Dependencies.Insert
              (Unit_Index (SU.Index), Dependency_Maps.Empty_Map, Position,
               Inserted);
            Union (Data.Dependencies (Position), Ref.Depends);
         end Set_Data;

      begin
         if Cache_Map.Has_Element (CS) then
            Set_Data;
            return;
         end if;

         for J in reverse Name'Range loop
            if Name (J) = '.' then
               FU := View.Unit (Name (Name'First .. J - 1));
               exit when FU.Is_Defined;
            end if;
         end loop;

         if not FU.Is_Defined or else not FU.Has_Body then
            return;
         end if;

         Src := View.Source (FU.Main_Body);

         declare
            Info : Source_Info.Object'Class := Src.Source;
            Dep  : Path_Name.Object;
         begin
            Info.Dependencies.Clear;

            for CU of Info.CU_List loop
               if CU.Kind in GPR2.Unit.Body_Kind
                 and then CU.Name = FU.Name
               then
                  Dep := GPR2.Project.Source.Artifact.Dependency
                    (Src, CU.Index);

                  if Dep.Is_Defined and then Dep.Exists then
                     Compute
                       (Self.all, Info, FU.Main_Body, Dep, CU, View);
                  end if;

                  exit;
               end if;
            end loop;

            if Info.Is_Parsed then
               CS := Self.Cache.Find (Lown);

               if Cache_Map.Has_Element (CS) then
                  Set_Data;
               end if;
            end if;
         end;
      end Check_Separated;

   begin
      Data.Dependencies.Clear;

      for CU of Data.CU_List loop
         LI := GPR2.Project.Source.Artifact.Dependency (Source, CU.Index);

         if LI.Is_Defined and then LI.Exists then
            Compute (Self.all, Data, File, LI, CU, View);
         elsif CU.Kind in GPR2.Unit.Body_Kind then
            Check_Separated (CU);
         end if;
      end loop;
   end Compute;

   -----------
   -- Union --
   -----------

   procedure Union
     (Target : in out Dependency_Maps.Map; Source : Dependency_Maps.Map)
   is
      Position : Dependency_Maps.Cursor;
      Inserted : Boolean;
   begin
      for CD in Source.Iterate loop
         Target.Insert
           (Dependency_Maps.Key (CD), Dependency_Maps.Element (CD),
            Position, Inserted);

         if not Inserted
           and then Dependency_Maps.Element (Position)
                 /= Dependency_Maps.Element (CD)
         then
            raise Scan_ALI_Error with "Inconsistent dependencies";
         end if;
      end loop;
   end Union;

begin
   GPR2.Source_Info.Parser.Registry.Register (Handle);
end GPR2.Source_Info.Parser.ALI;
