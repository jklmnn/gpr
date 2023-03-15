with Gpr_Parser_AdaSAT.Theory;
with Gpr_Parser_AdaSAT.DPLL;

package body Gpr_Parser_AdaSAT.Helpers is
   type Empty_Context is null record;

   C : Empty_Context;

   function Empty_Theory_Check
     (Ctx : in out Empty_Context;
      M   : Model;
      F   : in out Formula) return Boolean;
   function Empty_Theory_Check
     (Ctx : in out Empty_Context;
      M   : Model;
      F   : in out Formula) return Boolean
   is
      pragma Unreferenced (Ctx, M, F);
   begin
      return True;
   end Empty_Theory_Check;

   package Empty_Theory is new Theory (Empty_Context, Empty_Theory_Check);

   package SAT is new DPLL (Empty_Theory);

   function DPLL_Solve
     (F        : Formula;
      M        : in out Model;
      Min_Vars : Variable_Or_Null := 0) return Boolean
   is (SAT.Solve (F, C, M, Min_Vars));
end Gpr_Parser_AdaSAT.Helpers;
