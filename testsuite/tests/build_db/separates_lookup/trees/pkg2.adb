package body Pkg2 is

   procedure Child;

   procedure Child is separate;

   procedure Foo is
   begin
      Child;
   end Foo;
end Pkg2;