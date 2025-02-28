Require Import ExtLib.Data.Monads.OptionMonad.
Require Import ExtLib.Structures.Monads.

From CHKC Require Import Tactics ListUtil Map.
Require Import Coq.FSets.FMapFacts.
(** * Document Conventions *)

(*
This document contains the coq file for Checked-CT not including the unsafe code region.
Checked-CT is a subset of Checked-C focusing on ensuring the temporal safety of Checked region. 
*)

(** * Syntax *)

(** The taus [var], [field], and [struct] are the (distinguished) syntactic classes of program variables ([x]), fields ([f]), and structures [T])
    respectively. They are all implemented concretely as natural numbers. Each is a distinguished class of identifier in the syntax of
    the language. *)
Require Export Psatz.
Require Export Bool.
Require Export Arith.
Require Export Psatz.
Require Export Program.
Require Export List.
Require Import ZArith.
Require Import ZArith.BinIntDef.
Require Export Reals.
Export ListNotations.

Require Export BinNums.
Require Import BinPos BinNat.

Import Coq.Lists.List.ListNotations.

Scheme Equality for list.


Local Open Scope Z_scope.


Definition var    := nat.
Definition funid := nat.

(* Useful shorthand in case we ever change representation. *)
Definition var_eq_dec := Nat.eq_dec.


(** Types, <<w>>, are either a word tau, [TInt, TPtr], a struct tau, [TStruct],
    or an array tau, [TArray]. Struct taus must be annotated with a struct identifier.
    Array taus are annotated with their lower-bound, upper-bound, and the (word) tau of their elements.

    The metavariable, [w], was chosen to abbreviate "wide" or compound taus.

    Notice that struct taus can be self-referential. Furthermore, they are the only tau
    which may be self-referential.

    Example:

    In

      struct foo {
        self^struct foo
      }

      let my_foo = malloc@struct foo in
      let my_foo_self = &my_foo->self in
      *my_foo_self = my_foo

    the memory location which holds the `self` field of `my_foo` contains a pointer which
    refers back to `my_foo`. Thus, `my_foo` is self-referential. *)

(* a bound is either a value or a expression as the form of var + num. *)
Inductive bound : Set := | Num : Z -> bound | Var : var -> Z -> bound.

Definition cbound : Set := list (list var * bound * bound).

Inductive tau : Set := TInt | TPtr (t:omega)
with omega : Set := TOmega (t:tau) | TArray (cb:cbound) (t: tau).

Coercion TOmega : tau >-> omega.

(*
Inductive tau : Type :=
  | TInt : tau
  | TPtr : bool -> tau -> tau (* bool indicates if the ptr is free or not. *)
  | TArray : bound -> bound -> bound -> tau -> tau.  (* the third bound indicates the cutting edge position is free or not. *)
*)

Lemma tau_eq_dec (t1 t2 : tau): {t1 = t2} + {~ t1 = t2}
with omega_eq_dec (t1 t2 : omega): {t1 = t2} + {~ t1 = t2}.
Proof.
  repeat decide equality.
  repeat decide equality.
Qed.


(** Word taus, <<t>>, are either numbers, [WTInt], or pointers, [WTPtr].
    Pointers must be annotated with a [mode] and a (compound) [tau]. *)

(** Fields, [fs], are a vector of fields paired with their (word) tau.
    We represent this as a finite list map. The keys are the field identifier, and the
    values are its (word) tau.
 *)

Require Import OrderedTypeEx.

(*
Module Fields := FMapList.Make Nat_as_OT.

Definition fields := Fields.t tau.

(** Structdefs, [D], are a map of structures to fields.

    Structdefs also have a well-formedness predicate. This says that a structdef
    cannot reference structures that it does not define. *)

Module StructDef := Map.Make Nat_as_OT.

Definition structdef := StructDef.t fields.
*)
(*
Inductive none_bound_only : bound -> Prop :=
    | none_bound_only_1: forall n, none_bound_only (Num n)
    | none_bound_only_2: forall x y, none_bound_only (Var x y None).
*)


Module Env := Map.Make Nat_as_OT.
Module EnvFacts := FMapFacts.Facts (Env).
Definition env := Env.t tau.

Definition empty_env := @Env.empty tau.

Definition venv := Env.t var.

Definition empty_venv := @Env.empty var.

(* well_bound definition might not needed in the tau system, since the new expr_wf will guarantee that. *)
Inductive well_bound_in : env -> bound -> Prop :=
   | well_bound_in_num : forall env n, well_bound_in env (Num n)
   | well_bound_in_var : forall env x y, Env.MapsTo x (TInt) env -> well_bound_in env (Var x y).

Inductive well_cbound_in: env -> cbound -> Prop :=
  | well_cbound_empty : forall env, well_cbound_in env nil
  | well_cbound_many : forall env x xs, well_bound_in env (snd (fst x))
          -> well_bound_in env (snd x) -> well_cbound_in env xs -> well_cbound_in env (x::xs).

Inductive well_tau_bound_in : env -> tau -> Prop :=
   | well_tau_bound_in_nat : forall env, well_tau_bound_in env TInt
   | well_tau_bound_in_ptr : forall t env, well_tau_bound_in env t -> well_tau_bound_in env (TPtr t)
with well_omega_bound_in : env -> omega -> Prop :=
   | well_tau_bound_in_tau : forall env t, well_tau_bound_in env t -> well_omega_bound_in env (TOmega t)
   | well_tau_bound_in_array : forall env lh t, well_cbound_in env lh ->
                                      well_tau_bound_in env t -> well_omega_bound_in env (TArray lh t).

Inductive well_bound_vars {A:Type}: list (var * A) -> bound -> Prop :=
  | well_bound_vars_num : forall l n, well_bound_vars l (Num n)
  | well_bound_vars_var : forall l y n, (exists a, In (y,a) l) -> well_bound_vars l (Var y n).

Inductive well_cbound_vars {A:Type}: list (var * A) -> cbound -> Prop :=
  | well_cbound_vars_empty : forall env, well_cbound_vars env nil
  | well_cbound_vars_many : forall env x xs, well_bound_vars env (snd (fst x))
          -> well_bound_vars env (snd x) -> well_cbound_vars env xs -> well_cbound_vars env (x::xs).

Inductive well_bound_vars_type {A:Type}: list (var * A) -> tau -> Prop :=
  | well_bound_vars_nat : forall l, well_bound_vars_type l (TInt)
  | well_bound_vars_ptr : forall l t, well_bound_vars_type l t -> well_bound_vars_type l (TPtr t)
with well_bound_vars_omega {A:Type} : list (var * A) -> omega -> Prop :=
  | well_bound_vars_tau : forall env t, well_bound_vars_type env t -> well_bound_vars_omega env (TOmega t)
  | well_bound_vars_array : forall l b t, well_cbound_vars l b 
                        -> well_bound_vars_type l t -> well_bound_vars_omega l (TArray b t).

(* Definition of simple tau meaning that no bound variables. *)
Definition simple_bound (b:bound) :=
   match b with Num x => True | _ => False end.

Definition simple_cbound (l:cbound) :=
  forall x y z, List.In (x,y,z) l -> simple_bound y /\ simple_bound z.

Inductive simple_tau : tau -> Prop :=
   | SPTInt : simple_tau TInt
   | SPTPtr : forall t, simple_tau t -> simple_tau (TPtr t)
with simple_omega : omega -> Prop :=
   | SPTTau : forall t, simple_tau t -> simple_omega (TOmega t)
   | SPTArray : forall b t, simple_cbound b -> simple_tau t -> simple_omega (TArray b t).

Inductive esimple_tau : tau -> Prop :=
   | ESPTInt : esimple_tau TInt
   | ESPTPtr : forall t, esimple_tau t -> esimple_tau (TPtr t)
with esimple_omega : omega -> Prop :=
   | ESPTTau : forall t, esimple_tau t -> esimple_omega (TOmega t)
   | ESPTArray : forall l h t, esimple_tau t -> esimple_omega (TArray ([(nil, Num l, Num h)]) t).

(*
Inductive ext_bound_in : list var -> bound -> Prop :=
  | ext_bound_in_num : forall l n, ext_bound_in l (Num n)
  | ext_bound_in_var : forall l y n, ext_bound_in l (Var y n).

Inductive ext_tau_in : list var -> tau -> Prop :=
  | ext_tau_in_nat : forall l, ext_tau_in l (TInt)
  | ext_tau_in_ptr : forall l c t, ext_tau_in l t -> ext_tau_in l (TPtr c t)
  | ext_tau_in_struct : forall l t, ext_tau_in l (TStruct t)
  | ext_tau_in_array : forall l b1 b2 t, ext_bound_in l b1 -> ext_bound_in l b2
                        -> ext_tau_in l t -> ext_tau_in l (TArray b1 b2 t)
  | ext_tau_in_ntarray : forall l b1 b2 t, ext_bound_in l b1 -> ext_bound_in l b2
                        -> ext_tau_in l t -> ext_tau_in l (TNTArray b1 b2 t).
*)

(*
Definition no_ebound (b:bound): Prop :=
   match b with Num n => True
             | Var x y => True
   end. 


Inductive no_etau : tau -> Prop :=
  | no_etau_nat : no_etau (TInt)
  | no_etau_ptr : forall m w, no_etau w -> no_etau (TPtr m w)
  | no_etau_struct : forall T, no_etau (TStruct T)
  | no_etau_array : forall l h t, no_etau t -> no_ebound l -> no_ebound h -> no_etau (TArray l h t)
  | no_etau_ntarray : forall l h t,  no_etau t -> no_ebound l -> no_ebound h -> no_etau (TNTArray l h t).
*)

(*
Definition fields_wf (D : structdef) (fs : fields) : Prop :=
  forall f t,
    Fields.MapsTo f t fs ->
    word_tau t /\ tau_wf D t /\ simple_tau t.

Definition structdef_wf (D : structdef) : Prop :=
  forall (T : struct) (fs : fields),
    StructDef.MapsTo T fs D ->
    fields_wf D fs.
*)

Inductive theta_elem : Type := TopElem | GeZero.

(* Theta map in the paper; used for keep tracking Bounds relation in compilation time. *)
Module Theta := Map.Make Nat_as_OT.

Definition theta := Theta.t theta_elem.

Definition empty_theta := @Theta.empty theta_elem.

(* This defines the subtyping relation. *)
Inductive nat_leq (T:theta) : bound -> bound -> Prop :=
  | nat_leq_num : forall l h, l <= h -> nat_leq T (Num l) (Num h)
  | nat_leq_var : forall x l h, l <= h -> nat_leq T (Var x l) (Var x h)
  | nat_leq_num_var : forall x l h, Theta.MapsTo x GeZero T -> l <= h -> nat_leq T (Num l) (Var x h).

Lemma nat_leq_trans : forall T a b c,  nat_leq T a b -> nat_leq T b c -> nat_leq T a c.
Proof.
  intros.
  destruct a. destruct b. destruct c.
  inv H. inv H0.
  apply nat_leq_num. lia.
  inv H. inv H0. apply nat_leq_num_var; try easy. lia.
  destruct c. inv H0.
  inv H. inv H0.
  constructor. easy. lia.
  inv H. inv H0.
  constructor. lia.
Qed.

Definition list_beq_c xl yl := list_beq var (fun x y => Nat.eqb x y) xl yl.

Fixpoint subt_bound (T:theta) (cl:list var) (b1:bound) (b2:bound) (c2:cbound) : Prop :=
  match c2 with nil => False
              | (x,y,u)::xs => if list_beq_c cl x then (nat_leq T b1 y /\ nat_leq T u b2) else subt_bound T cl b1 b2 xs
  end.

Fixpoint subt_bounds (T:theta) (c1:cbound) (c2:cbound) : Prop :=
  match c1 with nil => True
              | (x,y,u)::xs => subt_bound T x y u c2 /\ subt_bounds T xs c2
  end.

Fixpoint subt_empty_bound  (T:theta) (b1:bound) (b2:bound) (c2:cbound) : Prop :=
  match c2 with nil => True
              | (x,y,u)::xs => nat_leq T b1 y /\ nat_leq T u b2 /\ subt_empty_bound T b1 b2 xs
  end.

Inductive subtype (Q:theta) : tau -> tau -> Prop :=
  | SubTyRefl : forall t, subtype Q t t
  | SubTyBot : forall lh t, subt_empty_bound Q (Num 0) (Num 1) lh ->
                         subtype Q (TPtr (TOmega t)) (TPtr (TArray lh t))
  | SubTySubsume : forall lh lh' t, subt_bounds Q lh lh' ->
    subtype Q (TPtr (TArray lh t)) (TPtr (TArray lh' t)).

(* Subtyping transitivity. *)
Lemma subtype_trans : forall Q t t' w, subtype Q t (TPtr w) -> subtype Q (TPtr w) t' -> subtype Q t t'.
Proof.
 intros. inv H; inv H0.
      * eapply SubTyRefl.
      * eapply SubTyBot;eauto.
      * eapply SubTySubsume; eauto.
      * eapply SubTyBot; eauto.
      * eapply SubTyBot;eauto.
Admitted.
(* eapply nat_leq_trans. apply H2. assumption.
         eapply nat_leq_trans. apply H7. assumption.
      * eapply SubTySubsume;eauto.
      * eapply SubTySubsume; eauto.
        eapply nat_leq_trans. apply H2. assumption.
        eapply nat_leq_trans. apply H7. assumption.
Qed.
*)

(* Defining stack. *)
(*
Module Stack := Map.Make Nat_as_OT.

Definition stack := Stack.t (Z * tau).

Definition empty_stack := @Stack.empty (Z * tau).

Definition arg_stack := Stack.t bound.

Definition empty_arg_stack := @Stack.empty bound.
*)
(*
Definition dyn_env := Stack.t tau.

Definition empty_dyn_env := @Stack.empty tau.


Definition cast_bound (s:stack) (b:bound) : option bound :=
   match b with Num n => Some (Num n)
             | Var x n => (match (Stack.find x s) with Some (v,t) => Some (Num (n+v)) | None => None end)
   end.

Inductive cast_tau_bound (s:stack) : tau -> tau -> Prop :=
   | cast_tau_bound_nat : cast_tau_bound s (TInt) (TInt)
   | cast_tau_bound_ptr : forall c t t', cast_tau_bound s t t'
                 -> cast_tau_bound s (TPtr c t) (TPtr c t')
   | cast_tau_bound_array : forall l l' h h' t t', cast_bound s l = Some l' -> cast_bound s h = Some h' ->
                  cast_tau_bound s t t' -> cast_tau_bound s (TArray l h t) (TArray l' h' t')
   | cast_tau_bound_ntarray : forall l l' h h' t t', cast_bound s l = Some l' -> cast_bound s h = Some h' ->
                  cast_tau_bound s t t' -> cast_tau_bound s (TNTArray l h t) (TNTArray l' h' t')
   | cast_tau_bound_struct : forall t, cast_tau_bound s (TStruct t) (TStruct t).
*)

(*Syntax Definition. *)
Inductive expression : Type :=
  | ELit : Z -> tau -> expression
  | EVar : var -> expression
  | ECall : funid -> list expression -> expression
     (* any function call is associated with a list of metavariable for defined 
         f (#define lv_1 ... lv_n) (e1,...,en) { e } *)
  | ELet : var -> expression -> expression -> expression
  | EMalloc : omega -> expression
  | EFree : expression -> expression
  | ECast : tau -> expression -> expression
  | EPlus : expression -> expression -> expression
  | EDeref : expression -> expression (*  * e *)
  | EAssign : expression -> expression -> expression (* *e = e *)
  | ECt : list var -> expression -> expression
  | EIfDef : list var -> expression -> context -> context -> expression -> expression
        (* ifdefelse : if defined(lv_1) && defined(lv_2) && ... && defined (lv_n) && e1 then C1(e2) else C2(e2) *)
  | EIf : expression -> expression -> expression -> expression (* if e1 then e2 else e3. *)
with context : Type :=
  | CHole : context
  | CLet : var -> context -> expression -> context
  | CPlusL : context -> expression -> context
  | CPlusR : Z -> tau -> context -> context
  | CFree : context -> context
  | CCast : tau -> context -> context
  | CDeref : context -> context
  | CAssignL : context -> expression -> context
  | CAssignR : Z -> tau -> context -> context
  | CCt : list var -> context -> context
  | CIfDef : list var -> context -> context -> context -> expression -> context
          (* context evaluation for ifdef, only evaluates the boolean expr part. *)
  | CIf : context -> expression -> expression -> context.

(*
Parameter fenv : funid -> option (var * list (var * tau) * tau * expression).
*)

Definition fenv : Type := funid -> option (var * list (var * tau) * tau * expression).

Inductive gen_arg_env : env -> list (var * tau) -> env -> Prop :=
    gen_arg_env_empty : forall env, gen_arg_env env [] env
  | gen_ar_env_many : forall env x t tvl env', gen_arg_env env tvl env' -> gen_arg_env env ((x,t)::tvl) (Env.add x t env').

(* Well-formedness definition. 
Definition is_check_array_ptr (t:tau) : Prop :=
  match t with TPtr C (TArray l h t') => True
             | TPtr C (TNTArray l h t') => True
             | _ => False
  end.

Definition simple_option (D : structdef) (a:option (Z*tau)) :=
  match a with None => True
         | Some (v,t) => word_tau t /\ tau_wf D t /\ simple_tau t
  end.
*)

Definition single_omega (w:omega) :=
   match w with TArray ([(nil, x,y)]) t => True | _ => False end.

Definition single_tau (w:tau) :=
   match w with TPtr (TArray ([(nil, x,y)]) t) => True | _ => False end.

Inductive expr_wf (F:fenv) : expression -> Prop :=
  | WFELit : forall n t,
    expr_wf F (ELit n t)
  | WFEVar : forall x,
      expr_wf F (EVar x)
  | WFECall : forall x el, 
      (forall v, F x = Some v) ->
      (forall e, In e el -> (exists n t, e = ELit n t
                 /\ simple_tau t) \/ (exists y, e = EVar y)) ->
      expr_wf F (ECall x el)
  | WFELet : forall x e1 e2,
      expr_wf F e1 ->
      expr_wf F e2 ->
      expr_wf F (ELet x e1 e2)

  | WFECt : forall vl e,
      expr_wf F e ->
      expr_wf F (ECt vl e)


  | WFEIFDef : forall xl e1 e2 C1 C2,
      expr_wf F e1 ->
      expr_wf F e2 ->
      expr_wf F (EIfDef xl e1 C1 C2 e2)

  | WFEIF : forall e1 e2 e3,
      expr_wf F e1 ->
      expr_wf F e2 ->
      expr_wf F e3 ->
      expr_wf F (EIf e1 e2 e3)
  | WFEMalloc : forall w, single_omega w -> expr_wf F (EMalloc w)
  | WFEFree : forall e,
      expr_wf F e -> expr_wf F (EFree e)
  | WFECast : forall t e,
      single_tau t ->
      expr_wf F e ->
      expr_wf F (ECast t e)
  | WFEPlus : forall e1 e2,
      expr_wf F e1 ->
      expr_wf F e2 ->
      expr_wf F (EPlus e1 e2)
  | WFEDeref : forall e,
      expr_wf F e ->
      expr_wf F (EDeref e)
  | WFEAssign : forall e1 e2,
      expr_wf F e1 ->
      expr_wf F e2 ->
      expr_wf F (EAssign e1 e2)
with context_wf (F:fenv) : context -> Prop :=
 | WFCHole : context_wf F CHole
 | WFCLet : forall v C e, context_wf F C -> expr_wf F e -> context_wf F (CLet v C e)
 | WFCPlusL : forall C e, context_wf F C -> expr_wf F e -> context_wf F (CPlusL C e)
 | WFCPlusR : forall v t C e, 
     expr_wf F e -> context_wf F C -> context_wf F (CPlusR v t C)
 | WFCFree : forall C, context_wf F C -> context_wf F (CFree C)
 | WFCCast : forall t C, context_wf F C -> context_wf F (CCast t C)
 | WFCDeref : forall C, context_wf F C -> context_wf F (CDeref C)
 | WFCAssignL : forall C e , context_wf F C -> expr_wf F e -> context_wf F (CAssignL C e)
 | WFCAssignR : forall v t C , context_wf F C -> context_wf F (CAssignR v t C)
 | WFCCt : forall vl C,
      context_wf F C ->
      context_wf F (CCt vl C)
 | WFCIfDef : forall vl C1 C2 C3 e, context_wf F C1 -> context_wf F C2 -> context_wf F C3 ->
      expr_wf F e -> context_wf F (CIfDef vl C1 C2 C3 e)
 | WFCIf : forall C1 e2 e3, context_wf F C1 -> expr_wf F e2 -> expr_wf F e3 ->
      context_wf F (CIf C1 e2 e3).


(* Standard substitution.
   In a let, if the bound variable is the same as the one we're substituting,
   then we don't substitute under the lambda. *)
 

(** Values, [v], are expressions [e] which are literals. *)

Inductive value : expression -> Prop :=
  VLit : forall (n : Z) (t : tau),
    simple_tau t ->
    value (ELit n t).

Hint Constructors value.

(** Note: Literal is a less strong version of value that doesn't
    enforce the syntactic constraints on the literal tau. *)

Inductive literal : expression -> Prop :=
  Lit : forall (n : Z) (t : tau),
    literal (ELit n t).

Hint Constructors literal.

(** * Dynamic Semantics *)

(** Heaps, [H], are a list of literals indexed by memory location.
    Memory locations are just natural numbers, and literals are
    numbers paired with their tau (same as [ELit] constructor).
    Addresses are offset by 1 -- looking up address 7 will translate
    to index 6 in the list.
lls
    Heaps also have a well-formedness predicate, which says that
    all memory locations must be annotated with a well-formed word
    tau.

    Finally, the only operation we can perform on a heap is allocation.
    This operation is defined by the partial function [allocate]. This
    function takes [D] a structdef, [H] a heap, and [w] a (compound) tau.
    The function is total assuming usual well-formedness conditions of [D] and
    [w]. It gives back a pair [(base, H')] where [base] is the base pointer for
    the allocated region and [H'] is [H] with the allocation. *)


Module Heap := Map.Make Z_as_OT.

Definition heap : Type := Heap.t (Z * tau).

Definition heap_wf (H : heap) : Prop :=
  forall (addr : Z), 0 < addr <= (Z.of_nat (Heap.cardinal H)) <-> Heap.In addr H.

Definition locks : Type := list (Z * Z).

Definition lock_in (x:Z) (s:locks) :=
   exists u v, List.In (u,v) s -> u <= x < v.


Section allocation.

Import ListNotations.
Import MonadNotation.
Local Open Scope monad_scope.

Print replicate.
Definition Zreplicate (z:Z) (T : tau) : (list tau) :=
match z with
  |Z.pos p => (replicate (Pos.to_nat p) T)
  |_ => []
end.

(* Changed this, to return the lower bound *)
Definition allocate_meta (w : omega)
  : option (Z * list tau) :=
  match w with
  | TArray ([(nil, (Num l),(Num h))]) T =>
    Some (l, Zreplicate (h - l + 1) T)
  | TArray _ _ => None
  | _ => Some (0, [TPtr w])
  end.


Definition allocate_meta_no_bounds (w : omega)
  : option (list tau) :=
  match (allocate_meta w) with
  | Some( _ , x) => Some x
  | None => None
end.


Lemma allocate_meta_implies_allocate_meta_no_bounds : forall w ts b,
allocate_meta w = Some (b, ts) -> allocate_meta_no_bounds w = Some ts.
Proof.
  intros. unfold allocate_meta_no_bounds. rewrite H. reflexivity.
Qed.

(* allocate_meta can succeed with bad bounds. allocate itself shouldn't *)
Definition allocate  (H : heap) (w : tau) : option (Z * (Z * Z) * heap) :=
  let H_size := Z.of_nat(Heap.cardinal H) in
  let base   := H_size + 1 in
  match allocate_meta w with
  | Some (0, am) => 
     let (asize, H') := List.fold_left
                  (fun (acc : Z * heap) (t : tau) =>
                     let (sizeAcc, heapAcc) := acc in
                     let sizeAcc' := sizeAcc + 1 in
                     let heapAcc' := Heap.add (H_size+sizeAcc') (0, t) heapAcc in
                     (sizeAcc', heapAcc'))
                  am
                  (0, H)
     in
     ret (base, (base,base + asize), H')
  | _ => None
  end.

End allocation.

(** Results, [r], are an expression ([RExpr]), null dereference error ([RNull]), or
    array out-of-bounds error ([RBounds]). RTSV: temporal safety violation *)

Inductive result : Type :=
  | RExpr : expression -> result
  | RNull : result
  | RTSV : result
  | RBounds : result.

(** Contexts, [E], are expressions with a hole in them. They are used in the standard way,
    for lifting a small-step reduction relation to compound expressions.

    We define two functions on contexts: [in_hole] and [mode_of]. The [in_hole] function takes a context,
    [E] and an expression [e] and produces an expression [e'] which is [E] with its hole filled by [e].
    The [mode_of] function takes a context, [E], and returns [m] (a mode) indicating whether the context has a
    subcontext which is unchecked. *)

Fixpoint in_hole (e : expression) (E : context) : expression :=
  match E with
  | CHole => e
  | CLet x E' e' => ELet x (in_hole e E') e'
  | CPlusL E' e' => EPlus (in_hole e E') e'
  | CPlusR n t E' => EPlus (ELit n t) (in_hole e E')
  | CFree E' => EFree (in_hole e E')
  | CCast t E' => ECast t (in_hole e E')
  | CDeref E' => EDeref (in_hole e E')
  | CAssignL E' e' => EAssign (in_hole e E') e'
  | CAssignR n t E' => EAssign (ELit n t) (in_hole e E')
  | CCt vl C => ECt vl (in_hole e C)
  | CIfDef vl C1 C2 C3 e1 => EIfDef vl (in_hole e C1) C2 C3 e1
  | CIf E' e1 e2 => EIf (in_hole e E') e1 e2
  end.

Fixpoint find_cxt (cl:list var) (E : context) : list var :=
  match E with
  | CHole => cl
  | CLet x E' e' => find_cxt cl E'
  | CPlusL E' e' => find_cxt cl E'
  | CPlusR n t E' => find_cxt cl E'
  | CFree E' => find_cxt cl E'
  | CCast t E' => find_cxt cl E'
  | CDeref E' => find_cxt cl E'
  | CAssignL E' e' => find_cxt cl E'
  | CAssignR n t E' => find_cxt cl E'
  | CCt vl C => find_cxt (cl++vl) C
  | CIfDef vl C1 C2 C3 e1 => find_cxt cl C1
  | CIf E' e1 e2 => find_cxt cl E'
  end.

Fixpoint compose (E_outer : context) (E_inner : context) : context :=
  match E_outer with
  | CHole => E_inner
  | CLet x E' e' => CLet x (compose E' E_inner) e'
  | CPlusL E' e' => CPlusL (compose E' E_inner) e'
  | CPlusR n t E' => CPlusR n t (compose E' E_inner)
  | CFree E' => CFree (compose E' E_inner)
  | CCast t E' => CCast t (compose E' E_inner)
  | CDeref E' => CDeref (compose E' E_inner)
  | CAssignL E' e' => CAssignL (compose E' E_inner) e'
  | CAssignR n t E' => CAssignR n t (compose E' E_inner)
  | CCt vl E' => CCt vl (compose E' E_inner)
  | CIfDef vl C1 C2 C3 e => CIfDef vl (compose C1 E_inner) C2 C3 e
  | CIf E' e1 e2 => CIf (compose E' E_inner) e1 e2
  end.

Lemma hole_is_id : forall e,
    in_hole e CHole = e.
Proof.
  intros.
  reflexivity.
Qed.

Lemma compose_correct : forall E_outer E_inner e0,
    in_hole (in_hole e0 E_inner) E_outer = in_hole e0 (compose E_outer E_inner).
Proof.
  intros. induction E_outer.
  easy. 1-9: (simpl; rewrite IHE_outer; reflexivity).
  simpl in *. rewrite IHE_outer1. easy.
  (simpl; rewrite IHE_outer; reflexivity).
Qed.

(* TODO: say more *)
(** The single-step reduction relation, [H; e ~> H'; r]. *)

(*
Definition eval_bound (s:stack) (b:bound) : option bound :=
   match b with Num n => Some (Num n)
             | Var x n => (match (Stack.find x s) with Some (v,t) => Some (Num (v + n)) | None => None end)
   end.

Definition eval_tau_bound (s : stack) (t : tau) : option tau := 
  match t with | TPtr c (TArray l h t) => 
                   match eval_bound s l with None => None
                                         | Some l' => 
                     match eval_bound s h with None => None
                                      | Some h' => 
                                Some (TPtr c (TArray l' h' t))
                     end
                   end
              | TPtr c (TNTArray l h t) => 
                   match eval_bound s l with None => None
                                         | Some l' => 
                     match eval_bound s h with None => None
                                      | Some h' => 
                                Some (TPtr c (TNTArray l' h' t))
                     end
                   end
              | _ => Some t
  end.


Lemma eval_tau_bound_array_ptr : forall s t,
    eval_tau_bound s t = None -> (exists  c l h t', t = TPtr c (TArray l h t') \/ t = TPtr c (TNTArray l h t')).
Proof.
 intros. unfold eval_tau_bound in H.
 destruct t; inversion H.
 destruct t; inversion H.
 exists m. exists b. exists b0. exists t.
 left. reflexivity.
 exists m. exists b. exists b0. exists t.
 right. reflexivity.
Qed.


Definition NTHit (s : stack) (x : var) : Prop :=
   match Stack.find x s with | Some (v,TPtr m (TNTArray l (Num 0) t)) => True
                          | _ => False
   end.

Definition add_nt_one (s : stack) (x:var) : stack :=
   match Stack.find x s with | Some (v,TPtr m (TNTArray l (Num h) t)) 
                         => Stack.add x (v,TPtr m (TNTArray l (Num (h+1)) t)) s
                              (* This following case will never happen since the tau in a stack is always evaluated. *)
                             | _ => s
   end.

Definition is_rexpr (r : result) : Prop :=
   match r with RExpr x => True
              | _ => False
   end.
*)

Definition is_array_ptr (t:tau) : Prop :=
  match t with TPtr (TArray lh t') => True
             | _ => False
  end.

Definition is_simp_array_ptr (t:tau) : Prop :=
  match t with TPtr (TArray ([(nil, Num l, Num h)]) t') => True
             | _ => False
  end.

Definition sub_bound (b:bound) (n:Z) : (bound) :=
  match b with Num m => Num (m - n)
           | Var x m => Var x (m - n)
  end.

Definition sub_cbound (c:cbound) (n:Z) := List.map (fun a => match a with (x,y,z) => (x,sub_bound y n, sub_bound z n) end) c.


Definition sub_tau_bound (t:tau) (n:Z) : tau :=
   match t with TPtr (TArray lh t1) => TPtr (TArray (sub_cbound lh n) t1)
              | _ => t
   end.

Definition malloc_bound (t:omega) : Prop :=
   match t with (TArray ([(nil,(Num l), (Num h))]) t) => (l = 0 /\ h > 0)
              | _ => True
   end.

(*
Definition change_strlen_stack (s:stack) (x : var) (m:mode) (t:tau) (l n n' h:Z) :=
     if n' <=? h then s else @Stack.add (Z * tau) x (n,TPtr m (TNTArray (Num l) (Num n') t)) s. 

Fixpoint gen_stack (vl:list var)  (es:list expression) (e:expression) : option expression := 
   match vl with [] => Some e
              | (v::vl') => match es with [] => None | e1::el =>
                                    match gen_stack vl' el e with None => None
                                                    | Some new_e => Some (ELet v e1 new_e)
                                    end
                              end
   end.
*)

Definition get_high_ptr (t : tau) := 
    match t with (TPtr (TArray ([(nil, l, h)]) t')) => Some h
              | _ => None
    end.

Definition get_high (t : omega) := 
    match t with ((TArray ([(nil, l, h)]) t')) => Some h
              | _ => None
    end.

Definition get_low_ptr (t : tau) := 
    match t with (TPtr (TArray ([(nil, l, h)]) t')) => Some l
              | _ => None
    end.

Definition get_low (t : omega) := 
    match t with ((TArray ([(nil, l, h)]) t')) => Some l
              | _ => None
    end.

(* TODO: say more *)
(** The compatible closure of [H; e ~> H'; r], [H; e ->m H'; r].

    We also define a convenience predicate, [reduces H e], which holds
    when there's some [m], [H'], and [r] such that [H; e ->m H'; r]. *)
Definition get_good_dept (e:expression) :=
  match e with ELit v t => Some (Num v)
             | EVar x => Some (Var x 0)
             | _ => None
  end.

(*
Fixpoint get_dept_map (l:list (var * tau)) (es:list expression) :=
   match l with [] => Some []
       | (x,TInt)::xl => (match es with e::es' => match get_good_dept e with None => None 
                                                        | Some b => match (get_dept_map xl es') with None => None
                                                                           | Some xl' => Some ((x,b)::xl')
                                                                    end
                                                  end
                                      | _ => None
                          end)
       | (x,y)::xl => match es with (e::es') => get_dept_map xl es' 
                                 | _ => None
                      end
    end.
*)
Definition subst_bound (b:bound) (x:var) (b1:bound) := 
   match b with Num n => (Num n)
           | Var y n => 
        if var_eq_dec y x then
           match b1 with (Num m) => (Num (n+m))
                         | (Var z m) => (Var z (n+m))
           end
        else Var y n
   end.

(*
Fixpoint subst_bounds (b:bound) (s: list (var*bound)) :=
  match s with [] => b
            | (x,b1)::xs => subst_bounds (subst_bound b x b1) xs
  end.
*)

Fixpoint remove_range (x:Z) (l:list (Z * Z)) :=
   match l with nil => nil
              | (u,v)::xs =>
              if (u <=? x) && (x <? v) then remove_range x xs else ((u,v)::remove_range x xs)
   end.

Definition subst_cbound (c:cbound) (x:var) (b1:bound) :=
   List.map (fun a => match a with (u,v,w) => (u, subst_bound v x b1, subst_bound w x b1) end) c.


Fixpoint subst_tau (t:tau) (x:var) (b1:bound) :=
   match t with TInt => TInt
            | TPtr t' => TPtr (subst_omega t' x b1)
   end
with subst_omega (t:omega) (x:var) (b1:bound) :=
   match t with TOmega a => TOmega (subst_tau a x b1)
              | TArray b t => TArray (subst_cbound b x b1) (subst_tau t x b1)
   end.


Definition inlist (a:var) (l:list var) := forallb (fun b => Nat.eqb a b) l.

Definition sublist_f (l1 l2 : list var) := forallb (fun b => inlist b l2) l1.

Definition sublist {A:Type} (l1:list A) (l2:list A) :=
   forall x, In x l1 -> In x l2.

Fixpoint simp_cbound (cl: list var) (b:cbound) : option cbound :=
   match b with nil => None
              | ((u,v,w)::xs) => if sublist_f u cl then Some ([(nil,v,w)]) else simp_cbound cl xs
   end.

Fixpoint simp_tau (cl:list var) (t:tau) :=
   match t with TInt => Some TInt
            | TPtr t' => match simp_omega cl t' with None => None | Some ta => Some (TPtr ta) end
   end
with simp_omega (cl:list var) (t:omega) :=
   match t with TOmega a => match simp_tau cl a with None => None | Some ta => Some (TOmega ta) end
              | TArray b t => match simp_cbound cl b with None => None
                                                        | Some cb => 
                      match (simp_tau cl t) with None => None
                                               | Some ta => Some (TArray cb ta)
                      end
                              end
   end.

Fixpoint simp_exp (cl:list var) (e:expression) := 
   match e with ELit n t => (match simp_tau cl t with None => ELit n t | Some t' => ELit n t' end)
              | EVar y => EVar y
              | ECall f el => ECall f (List.map (fun ea => simp_exp cl ea) el)
              | ELet y e1 e2 => ELet y (simp_exp cl e1) (simp_exp cl e2)
              | EMalloc t => EMalloc t
              | EFree ea => EFree (simp_exp cl ea)
              | ECast t ea => ECast t (simp_exp cl ea)
              | EPlus e1 e2 => EPlus (simp_exp cl e1) (simp_exp cl e2)
              | EDeref ea => EDeref (simp_exp cl ea)
              | EAssign e1 e2 => EAssign (simp_exp cl e1) (simp_exp cl e2)
              | ECt vl e1 => ECt vl (simp_exp (cl++vl) e1)
              | EIfDef vl e1 C1 C2 e2 => EIfDef vl (simp_exp cl e1) C1 C2 e2
              | EIf e1 e2 e3 => EIf (simp_exp cl e1) e2 e3
  end.

(* subst function and simplify. *)
Fixpoint subst_exp (e:expression) (x:var) (v:Z) (tv:tau) := 
   match e with ELit n t => ELit n (subst_tau t x (Num v))
              | EVar y => if Nat.eqb x y then ELit v tv else EVar y
              | ECall f el => ECall f (List.map (fun ea => subst_exp ea x v tv) el)
              | ELet y e1 e2 => if Nat.eq_dec x y then ELet y (subst_exp e1 x v tv) e2
                                                  else ELet y (subst_exp e1 x v tv) (subst_exp e2 x v tv)
              | EMalloc t => EMalloc (subst_omega t x (Num v))
              | EFree ea => EFree (subst_exp ea x v tv)
              | ECast t ea => ECast (subst_tau t x (Num v)) (subst_exp ea x v tv)
              | EPlus e1 e2 => EPlus (subst_exp e1 x v tv) (subst_exp e2 x v tv)
              | EDeref ea => EDeref (subst_exp ea x v tv)
              | EAssign e1 e2 => EAssign (subst_exp e1 x v tv) (subst_exp e2 x v tv)
              | ECt vl e1 => ECt vl (subst_exp e1 x v tv)
              | EIfDef vl e1 C1 C2 e2 => EIfDef vl (subst_exp e1 x v tv) 
                           (subst_context C1 x v tv) (subst_context C2 x v tv) (subst_exp e2 x v tv)
              | EIf e1 e2 e3 => EIf (subst_exp e1 x v tv) (subst_exp e2 x v tv) (subst_exp e3 x v tv)
  end
with subst_context (C:context) (x:var) (v:Z) (tv:tau) :=
  match C with CHole => CHole
             | CLet y E e1 => if Nat.eq_dec x y then CLet y (subst_context E x v tv) e1
                                                  else CLet y (subst_context E x v tv) (subst_exp e1 x v tv)
             | CPlusL E e1 => CPlusL (subst_context E x v tv) (subst_exp e1 x v tv)
             | CPlusR v tv E => CPlusR v tv (subst_context E x v tv)
             | CFree E => CFree (subst_context E x v tv)
             | CCast t E => CCast t (subst_context E x v tv)
             | CDeref E => CDeref (subst_context E x v tv)
             | CAssignL E e1 => CAssignL (subst_context E x v tv) (subst_exp e1 x v tv)
             | CAssignR v tv E => CAssignR v tv (subst_context E x v tv)
             | CCt vl E => CCt vl (subst_context E x v tv)
             | CIfDef vl E C1 C2 e1 => CIfDef vl (subst_context E x v tv) C1 C2 e1
             | CIf E e1 e2 => CIf (subst_context E x v tv) e1 e2
end.


(*
Inductive get_root {D:structdef} : tau -> tau -> Prop :=
    get_root_word : forall m t, word_tau t -> get_root (TPtr m t) t
  | get_root_array : forall m l h t, get_root (TPtr m (TArray l h t)) t
  | get_root_ntarray : forall m l h t, get_root (TPtr m (TNTArray l h t)) t
  | get_root_struct : forall m T f, StructDef.MapsTo T f D ->
    Some (TInt) = (Fields.find 0%nat f) -> @get_root D (TPtr m (TStruct T)) TInt.

Inductive gen_rets  (AS: list (var*bound)) (S: stack) : list (var * tau) -> list expression -> expression -> expression -> Prop :=
   gen_rets_empty : forall e, gen_rets AS S [] [] e e
  | gen_rets_many : forall x t t' xl e1 v es e2 e',  gen_rets AS S xl es e2 e' ->
          eval_arg S e1 (subst_tau AS t) (ELit v t') ->
          gen_rets AS S ((x,t)::xl) (e1::es) e2 (ERet x (v,t') (Stack.find x S) e').

Inductive tau : Set := AType (t:atype) | TPtr (b:bool) (t:omega)
with omega : Set := TOmega (t:tau) | TArray (b1:bound) (b2:bound) (i:bound) (t: delta)
with delta : Set := DPtr (t:tau) | DTau (t:atype).
*)

Inductive get_root : omega -> tau -> Prop :=
    get_root_word : forall t, get_root (TOmega t) t
  | get_root_array : forall lh t, get_root (TPtr (TArray lh t)) t.


Inductive gen_rets (vl : list var): list (var * tau) -> list expression -> expression -> tau -> expression -> Prop :=
   gen_rets_empty : forall e t, gen_rets vl [] [] e t (ECt vl e)
  | gen_rets_many_1 : forall x t v tv xl es e ta e', 
          gen_rets vl xl es e ta e' ->
          gen_rets vl ((x,t)::xl) ((ELit v tv)::es) e ta (ELet x (ELit v tv) e').


(* CoreChkC semantics. *)
Inductive step {F:funid -> option (var * list (var * tau) * tau * expression)} :
               list var -> locks -> heap -> expression -> locks -> heap -> result -> Prop :=

  | SFun : forall cl s H x el t v tvl e e', 
           F x = Some (v,tvl,t,e) ->
           (List.In v cl) ->
           gen_rets cl tvl el e t e' ->
          step cl s H (ECall x el) s H (RExpr e')
  | SLet : forall cl s H x n t e, 
      step cl s H (ELet x (ELit n t) e) s H (RExpr (simp_exp cl (subst_exp e x n t)))

  | SAddArr : forall cl s H n1 t1 n2,
      n1 > 0 -> is_simp_array_ptr t1 -> 
      step cl s H (EPlus (ELit n1 t1) (ELit n2 TInt))
           s H (RExpr (ELit (n1 + n2) (sub_tau_bound t1 n2)))
  | SAdd : forall cl s H n1 n2,
      step cl s H (EPlus (ELit n1 TInt) (ELit n2 TInt))
           s H (RExpr (ELit (n1 + n2) TInt))
  | SAddArrNull : forall cl s H n1 t n2,
      n1 <= 0 -> is_array_ptr t ->
      step cl s H (EPlus (ELit n1 t) (ELit n2 (TInt))) s H RNull
  | SCast : forall cl s H t n t',
      step cl s H (ECast t (ELit n t')) s H (RExpr (ELit n t))
  
  | SDeref: forall cl s H n n1 t t1 t',
      lock_in n s ->
      Heap.MapsTo n (n1, t1) H ->
      (forall l h ta, t = (TArray ([(nil,(Num l), (Num h))]) ta) -> h > 0 /\ l <= 0 ) ->
      esimple_tau (TPtr t) ->
      get_root t t' ->
      step cl s H (EDeref (ELit n (TPtr t))) s H (RExpr (ELit n1 t'))

  | SCt : forall cl s H vl n t, step cl s H (ECt vl (ELit n t)) s H (RExpr (ELit n t))

  | SDerefTSV : forall cl s H n t,
      ~ lock_in n s ->
      step cl s H (EDeref (ELit n (TPtr t))) s H RTSV

  | SDerefHighOOB : forall cl s H n t h,
      h <= 0 ->
      get_high_ptr t = Some (Num h) ->
      step cl s H (EDeref (ELit n t)) s H RBounds
  | SDerefLowOOB : forall cl s H n t l,
      l > 0 ->
      get_low_ptr t = Some (Num l) ->
      step cl s H (EDeref (ELit n t)) s H RBounds
  | SDerefNull : forall cl s H t n,
      n <= 0 -> 
      step cl s H (EDeref (ELit n (TPtr t))) s H RNull

  | SAssign : forall cl s H n t na ta tv n1 t1 H',
      lock_in n s ->
      Heap.MapsTo n (na,ta) H ->
      (forall l h t', t = TPtr (TArray ([(nil,(Num l), (Num h))]) t') -> h > 0 /\ l <= 0) -> 
      @get_root t tv ->
      H' = Heap.add n (n1, ta) H ->
      step cl
         s H  (EAssign (ELit n t) (ELit n1 t1))
         s H' (RExpr (ELit n1 tv))
  | SAssignTSV : forall cl s H n t n1 t1,
      ~ lock_in n s ->
      step cl
        s H (EAssign (ELit n t) (ELit n1 t1))
        s H RTSV
  | SAssignHighOOB : forall cl s H n t n1 t1 h,
      h <= 0 ->
      get_high_ptr t = Some (Num h) ->
      step cl
        s H (EAssign (ELit n t) (ELit n1 t1))
        s H RBounds
  | SAssignLowOOB : forall cl s H n t n1 t1 l,
      l > 0 ->
      get_low_ptr t = Some (Num l) ->
      step cl
         s H (EAssign (ELit n t) (ELit n1 t1))
         s H RBounds
  | SAssignNull : forall cl s H w n n1 t',
      n1 <= 0 ->
      step cl s H (EAssign (ELit n1 (TPtr w)) (ELit n t')) s H RNull

  | SMalloc : forall cl s H w H' n1 b,
      allocate H w = Some (n1, b, H') ->
      step cl
         s H (EMalloc w)
         (b::s) H' (RExpr (ELit n1 (TPtr w)))
  | SMallocHighOOB : forall cl s H w h,
      h <= 0 ->
      get_high w = Some (Num h) ->
      step cl s H (EMalloc w)  s H RBounds
  | SMallocLowOOB : forall cl s H w l,
      l <> 0 ->
      get_low w = Some (Num l) ->
      step cl s H (EMalloc w)  s H RBounds

  | SFree : forall cl s H n t,
      lock_in n s ->
      step cl
         s H (EFree (ELit n (TPtr t)))
         (remove_range n s) H (RExpr (ELit 0 TInt))

  | SFreeTSV : forall cl s H n t,
      ~ lock_in n s ->
      step cl
         s H (EFree (ELit n (TPtr t)))
         s H RTSV

  | SIfDefTrue : forall cl s H vl n t C1 C2 e, n <> 0 -> 
           sublist vl cl ->
           step cl s H (EIfDef vl (ELit n t) C1 C2 e) s H (RExpr (in_hole e C1))

  | SIfDefFalse1 : forall cl s H vl t C1 C2 e,
           step cl s H (EIfDef vl (ELit 0 t) C1 C2 e) s H (RExpr (in_hole e C2))

  | SIfDefFalse2 : forall cl s H vl n t C1 C2 e,
           ~ sublist vl cl ->
           step cl s H (EIfDef vl (ELit n t) C1 C2 e) s H (RExpr (in_hole e C2))

  | SIfTrue : forall cl s H n t e1 e2, n <> 0 -> 
           step cl s H (EIf (ELit n t) e1 e2) s H (RExpr e1)
  | SIfFalse : forall cl s H t e1 e2, 
              step cl s H (EIf (ELit 0 t) e1 e2) s H (RExpr e2).


Hint Constructors step.

(*

  | ELit : Z -> tau -> expression
  | EVar : var -> expression
  | ECall : funid -> list expression -> expression
     (* any function call is associated with a list of metavariable for defined 
         f (#define lv_1 ... lv_n) (e1,...,en) { e } *)
  | ELet : var -> expression -> expression -> expression
  | EMalloc : omega -> expression
  | EFree : expression -> expression
  | ECast : tau -> expression -> expression
  | EPlus : expression -> expression -> expression
  | EDeref : expression -> expression (*  * e *)
  | EAssign : expression -> expression -> expression (* *e = e *)
  | ECt : list var -> tau -> expression -> expression
  | EIfDef : list var -> expression -> context -> context -> expression -> expression
        (* ifdefelse : if defined(lv_1) && defined(lv_2) && ... && defined (lv_n) && e1 then C1(e2) else C2(e2) *)
  | EIf : expression -> expression -> expression -> expression (* if e1 then e2 else e3. *)

*)

Inductive reduce {F:funid -> option (var * list (var * tau) * tau * expression)} 
          : list var -> locks -> heap -> expression -> locks -> heap -> result -> Prop :=
  | RSExp : forall cl H s e H' s' e' E,
      @step F (find_cxt cl E) s H e s' H' (RExpr e') ->
      reduce cl s
        H (in_hole e E) s'  H' (RExpr (in_hole e' E))
  | RSHaltNull : forall cl H s e H' s' E,
      @step F (find_cxt cl E) s H e s' H' RNull ->
      reduce cl s
        H (in_hole e E) s' H' RNull
  | RSHaltBounds : forall cl H s e H' s'  E,
      @step F (find_cxt cl E) s H e s' H' RBounds ->
      reduce cl s H (in_hole e E) s' H' RBounds.

Hint Constructors reduce.

Definition reduces (F:funid -> option (var * list (var * tau) * tau * expression)) 
    (cl:list var) (s : locks) (H : heap) (e : expression) : Prop :=
  exists (s' : locks) (H' : heap) (r : result), @reduce F cl s H e s' H' r.

Hint Unfold reduces.


(* Defining function calls. *)

(** * Static Semantics *)

Require Import Lists.ListSet.

(*
Definition eq_dec_nt (x y : Z * tau) : {x = y} + { x <> y}.
repeat decide equality.
Defined. 


Definition scope := set (Z *tau)%tau. 
Definition empty_scope := empty_set (Z * tau).

Definition scope_set_add (v:Z) (t:tau) (s:scope) :=
     match t with TPtr m (TStruct x) => set_add eq_dec_nt (v,TPtr m (TStruct x)) s
               | _ => s
     end.
*)

(* Type check for a literal + simplifying the tau. *)
Inductive well_typed_lit (Q:theta) (H : heap) : Z -> tau -> Prop :=
  | TyLitInt : forall n,
      well_typed_lit Q H n TInt
  | TyLitZero : forall t,
      well_typed_lit Q H 0 t
  | TyLitC : forall n w t b ts,
      simple_tau w ->
      subtype Q (TPtr w) t ->
      Some (b, ts) = allocate_meta w ->
      (forall k, b <= k < b + Z.of_nat(List.length ts) ->
                 exists n' t',
                   Some t' = List.nth_error ts (Z.to_nat (k - b)) /\
                   Heap.MapsTo (n + k) (n', t') H /\
                   well_typed_lit Q H n' t') ->
      well_typed_lit Q H n t.

Lemma well_typed_lit_ind' :
  forall (Q:theta) (H : heap) (P : Z -> tau -> Prop),
    (forall (n : Z), P n TInt) ->
       (forall (t : tau), P 0 t) ->
       (forall (n : Z) (w : tau) (t: tau) (ts : list tau) (b : Z),
        simple_tau w ->
        subtype Q (TPtr w) t ->
        Some (b, ts) = allocate_meta w ->
        (forall k : Z,
         b <= k < b + Z.of_nat (length ts) ->
         exists (n' : Z) (t' : tau),
           Some t' = nth_error ts (Z.to_nat (k - b)) /\
           Heap.MapsTo (n + k) (n', t') H /\
           well_typed_lit Q H n' t' /\
           P n' t') -> P n t) -> forall (n : Z) (w : tau), well_typed_lit Q H n w -> P n w.
Proof.
  intros Q H P.
  intros HTyLitInt
         HTyLitZero
         HTyLitC.
  refine (fix F n t Hwtl :=
            match Hwtl with
            | TyLitInt _ _ n' => HTyLitInt n'
            | TyLitZero _ _ t' => HTyLitZero t'
            | TyLitC _ _ n' w' t' b ts HSim Hsub Hts IH =>
              HTyLitC n' w' t' ts b HSim Hsub Hts (fun k Hk =>
                                         match IH k Hk with
                                         | ex_intro _ n' Htmp =>
                                           match Htmp with
                                           | ex_intro _ t' Hn't' =>
                                             match Hn't' with
                                             | conj Ht' Hrest1 =>
                                               match Hrest1 with
                                               | conj Hheap Hwt =>
                                                 ex_intro _ n' (ex_intro _ t' 
                     (conj Ht' (conj Hheap (conj Hwt (F n' t' Hwt)))))
                                               end
                                             end
                                           end
                                         end)
            end).
Qed.

Hint Constructors well_typed_lit.

(*Type checking the arguments of a function. *)
Inductive well_typed_arg (Q:theta) (H : heap) (env:env): 
                 expression -> tau -> Prop :=
     | ArgLit : forall n t t',
      simple_tau t ->
      @well_typed_lit Q H n t' ->
      subtype Q t' t ->
      well_typed_arg Q H env (ELit n t') t
     | ArgVar : forall x t t',
      Env.MapsTo x t' env -> 
      well_tau_bound_in env t ->
      subtype Q t' t ->
      well_typed_arg Q H env (EVar x) t.

Inductive well_typed_args {Q:theta} {H : heap}: 
                   env -> list expression -> list (var * tau) -> tau -> tau -> Prop :=
     | args_empty : forall env t, well_typed_args env [] [] t t
     | args_many_1 : forall env e es v t vl tv tv', 
                 t <> TInt ->
                 well_typed_arg Q H env e t ->
                        well_typed_args env es vl tv tv'
                        -> well_typed_args env (e::es) ((v,t)::vl) tv tv'
     | args_many_2 : forall env e es v va vl tv tv', 
                 well_typed_arg Q H env e TInt ->
                        well_typed_args env es vl tv tv' -> get_good_dept e = Some va
                        -> well_typed_args env (e::es) ((v,TInt)::vl) tv (subst_tau tv' v va).

(* The CoreChkC Type System. *)
Inductive well_typed {F : fenv} {H:heap}
        : list var -> env -> theta -> expression -> tau -> Prop :=
  | TyConst : forall s env Q n t,
      well_tau_bound_in env t ->
      @well_typed_lit Q H n t -> 
      well_typed s env Q (ELit n t) t
  | TyVar : forall s env Q x t,
      Env.MapsTo x t env ->
      well_typed s env Q (EVar x) t

  | TyFun : forall s env Q es x sv tvl e t t', 
        F x = Some (sv,tvl,t,e) ->
        List.In sv s ->
        @well_typed_args Q H env es tvl t t' ->
           well_typed s env Q (ECall x es) t'

(*cases for the integer bounds substitution. (subst_tau [(x,b)] t) is the substitution function. *)
  | TyLetNat : forall s env Q x e1 e2 t b,
      well_typed s env Q e1 TInt ->
      well_typed s (Env.add x TInt env) Q e2 t ->
      get_good_dept e1 = Some b ->
      well_typed s env Q (ELet x e1 e2) (subst_tau t x b)

  | TyLet : forall s env Q x e1 t1 e2 t,
      well_typed s env Q e1 t1 ->
      well_typed s (Env.add x t1 env) Q e2 t ->
      well_typed s env Q (ELet x e1 e2) t

(* The counterpart of the TyLetNat rule. *)

  | TyCt : forall s env Q vl e t,
      well_typed vl env Q e t ->
      well_typed s env Q (ECt vl e) t

  | TyAdd : forall s env Q e1 e2,
      well_typed s env Q e1 (TInt) ->
      well_typed s env Q e2 (TInt) ->
      well_typed s env Q (EPlus e1 e2) TInt
  | TyMalloc : forall s env Q w,
      well_tau_bound_in env w ->
      well_typed s env Q (EMalloc w) (TPtr w)

  | TyFree : forall s env Q e t,
      well_typed s env Q e (TPtr t) ->
      well_typed s env Q (EFree e) TInt

  | TyCast : forall s env Q t e t',
      subtype Q t' t ->
      well_tau_bound_in env t ->
      well_typed s env Q e t' ->
      well_typed s env Q (ECast t e) t

  | TyDeref : forall s env Q e t t' t'',
      well_typed s env Q e t ->
      subtype Q t t' ->
      get_root t' t'' ->
      well_typed s env Q (EDeref e) t'
  | TyIndex : forall s env Q e1 lh e2 t,
      well_typed s env Q e1 (TPtr (TArray lh t)) -> 
      well_typed s env Q e2 (TInt) ->
      well_typed s env Q (EDeref (EPlus e1 e2)) t
  | TyAssign1 : forall s env Q e1 e2 t t1,
      subtype Q t1 t ->
      well_typed s env Q e1 (TPtr t) ->
      well_typed s env Q e2 t1 ->
      well_typed s env Q (EAssign e1 e2) t
  | TyAssign2 : forall s env Q e1 e2 lh t t',
      subtype Q t' t ->
      well_typed s env Q e1 (TPtr (TArray lh t)) ->
      well_typed s env Q e2 t' ->
      well_typed s env Q (EAssign e1 e2) t
  | TyIndexAssign : forall s env Q e1 e2 e3 lh t t',
      subtype Q t' t ->
      well_typed s env Q e1 (TPtr (TArray lh t)) ->
      well_typed s env Q e2 TInt ->
      well_typed s env Q e3 t' ->
      well_typed s env Q (EAssign (EPlus e1 e2) e3) t

  | TyIfDef : forall s env Q vl e1 C1 C2 e2 t,
      well_typed s env Q e1 TInt ->
      well_typed s env Q (in_hole e2 C1) t ->
      well_typed s env Q (in_hole e2 C2) t ->
      well_typed s env Q (EIfDef vl e1 C1 C2 e2) t
  | TyIf : forall s env Q e1 e2 e3 t,
      well_typed s env Q e1 TInt ->
      well_typed s env Q e2 t ->
      well_typed s env Q e3 t ->
      well_typed s env Q (EIf e1 e2 e3) t. 

Definition fun_wf (F:fenv) (H:heap) :=
     forall s env env' f v tvl t e, F f = Some (v,tvl,t,e) -> 
          gen_arg_env env tvl env' ->
          (forall x t', In (x,t') tvl -> well_bound_vars_type tvl t') /\
          (forall a, In a tvl -> ~ Env.In (fst a) env) /\
          (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b) /\
                        well_bound_vars_type tvl t /\ expr_wf F e
          /\ @well_typed F H s env' empty_theta e t.

Create HintDb Progress.

Ltac clean :=
  subst;
  repeat (match goal with
          | [ P : ?T, PQ : ?T -> _ |- _ ] => specialize (PQ P); clear P
          | [ H : ?T = ?T -> _ |- _ ] => specialize (H eq_refl)
          end).

Lemma step_implies_reduces : forall F ls s H e H' s' r,
    @step F ls s H e s' H' r ->
    reduces F ls s H e.
Proof.
  intros.
  assert (e = in_hole e CHole); try reflexivity.
  rewrite H1.
  destruct r; eauto 20.
Admitted.

Hint Resolve step_implies_reduces : Progress.

Lemma reduces_congruence : forall F cl H s e0 e,
    (exists E, in_hole e0 E = e) ->
    reduces F cl s H e0 ->
    reduces F cl s H e.
Proof.
  intros.
  destruct H0 as [ E Hhole ].
(*
  destruct H1 as [H' [ m' [ s' [r  HRed ]] ] ].
  inv HRed.
  rewrite compose_correct; eauto 20.
  rewrite compose_correct; eauto 20.
  rewrite compose_correct; eauto 20.
*)
Admitted.

Hint Resolve reduces_congruence : Progress.

(*
Lemma unchecked_congruence : forall e0 e,
    (exists e1 E, e0 = in_hole e1 E /\ mode_of(E) = U) ->
    (exists E, in_hole e0 E = e) ->
    exists e' E, e = in_hole e' E /\ mode_of(E) = U.
Proof.
  intros.
  destruct H as [ e1 [ E1 [ He0 HE1U ] ] ].
  destruct H0 as [ E He ].
  exists e1.
  exists (compose E E1).
  split.
  - subst. rewrite compose_correct. reflexivity.
  - apply compose_unchecked. assumption.
Qed.

Hint Resolve unchecked_congruence : Progress.
*)

Lemma well_typed_means_simple : forall (w : tau),
          well_tau_bound_in empty_env w -> simple_tau w.
Proof.
 intros. remember empty_env as env0.
 induction H.
 apply SPTInt.
 apply SPTPtr.
 apply IHwell_tau_bound_in.
 subst. easy.
Qed.

(* The Type Progress Theorem *)
Lemma progress : forall F sa ls H e t,
    heap_wf H ->
    expr_wf F e ->
    fun_wf F H ->
    @well_typed F H nil empty_env empty_theta e t ->
    value e \/
    reduces F ls sa H e.
Proof with eauto 20 with Progress.
  intros F sa ls H e t HHwf Hewf Hfun Hwt.
  remember empty_env as env.
  remember empty_theta as Q.
  induction Hwt as [
                     s env Q n t Wb HTyLit                                      | (* Literals *)
                     s env Q x t Wb                                             | (* Variables *)
                     s env Q es x sv tvl e ta t HMap HIn HArg                   | (* Call *)
                     s env Q x e1 e2 t b HTy1 IH1 HTy2 IH2 Hdept                | (* Let-Nat-Expr *)
                     s env Q x e1 t1 e2 t HTy1 IH1 HTy2 IH2                     | (* Let-Expr *)
                     s env Q vl e t HTy1 IH1                                    | (* ECt *)
                     s env Q e1 e2 HTy1 IH1 HTy2 IH2                            | (* Addition *)
                     s env Q w Wb                                               | (* Malloc *)
                     s env Q e t HTy1 IH1                                       | (* Free *)
                     s env Q t e t' HSub HChkPtr HTy IH                         | (* Cast - nat *)
                     s env Q e ta t t' HTy IH HSub Hx                           | (* Deref *)
                     s env Q e1 lh e2 t HTy1 IH1 HTy2 IH2                       | (* Index for array pointers *)

                     s env Q e1 e2 t t1 HSub HTy1 IH1 HTy2 IH2                  | (* Assign normal *)
                     s env Q e1 e2 lh t t' HSub HTy1 IH1 HTy2 IH2               | (* Assign array *)

                     s env Q e1 e2 e3 lh t t' HSub HTy1 IH1 HTy2 IH2 HTy3 IH3   | (* IndAssign for array pointers *)
                     s env Q vl e1 C1 C2 e2 t HTy1 IH1 HTy2 IH2 HTy3 IH3        | (* IfDef *)
                     s env Q e1 e2 e3 t HTy1 IH1 HTy2 IH2 HTy3 IH3                (* If *)
                 ]; clean.

  (* Case: TyConst *)
  - (* Holds trivially, since literals are values *)
    left...
    inv Hewf. apply VLit. apply well_typed_means_simple. easy. 
  (* Case: TyVar *)
  - (* Impossible, since environment is empty *)
    inversion Wb.
  

    (*I finished proof here. You will do the following. The following is old code. We modified a lot here.
      So, the following will serve as some hints for proofs. *)

  - (* Call Case *)
    right. left. inv Hewf.
    specialize (well_typed_args_same_length D Q H empty_env AS es tvl HArg) as X1.
    assert (sub_domain empty_env st).
    unfold sub_domain. intros.
    unfold Env.In, Env.Raw.PX.In in *.
    destruct H0.
    apply EnvFacts.empty_mapsto_iff in H0. inv H0.
    specialize (taud_args_values tvl es D Q st H empty_env AS H0) as X3.
    assert (bounds_in_stack st AS).
    apply get_dept_map_bounds_in_stack with (tvl := tvl) (es := es) (env := empty_env); try easy.
    apply (well_tau_args_trans D Q H empty_env AS es tvl); try easy.
    specialize (X3 H1 HArg). destruct X3.
    specialize (gen_rets_exist tvl st x0 AS es e X1 H4) as X2.
    destruct X2.
    eapply step_implies_reduces.
    Check SFun.
    apply (SFun D (fenv empty_env) AS st x0 H x es t tvl e x1 m'); try easy.
  -   (* Case: TyStrlen *)
    apply EnvFacts.empty_mapsto_iff in Wb. inv Wb.
  -   (* Case: TyLetStrlen *)
    apply EnvFacts.empty_mapsto_iff in Wb. inv Wb.
  (* Case: TyLetNat *)
  - (* `ELet x e1 e2` is not a value *)
    right.
    (* Invoke the IH on `e1` *)
    inv Hewf.
    apply (IH1) in H2.
    2: { easy. }
    destruct H2 as [ HVal1 | [ HRed1 | HUnchk1 ] ].
    (* Case: `e1` is a value *)
    + (* We can take a step according to SLet *)
      left.  
      inv HVal1...
      apply (step_implies_reduces D (fenv empty_env) H st 
              (ELet x (ELit n t0) e2) H (Stack.add x (n, t0) st) (RExpr(ERet x (n,t0) (Stack.find x st) e2))).
      apply SLet.
      apply simple_tau_means_cast_same. easy.
    (* Case: `e1` reduces *)
    + (* We can take a step by reducing `e1` *)
      left.
      ctx (ELet x e1 e2) (in_hole e1 (CLet x CHole e2))...
    (* Case: `e1` is unchecked *)
    + (* `ELet x e1 e2` must be unchecked, since `e1` is *)
      right.
      ctx (ELet x e1 e2) (in_hole e1 (CLet x CHole e2)).
      destruct HUnchk1...
  (* Case: TyLet *)
  - (* `ELet x e1 e2` is not a value *)
    right.
    (* Invoke the IH on `e1` *)
    inv Hewf.
    apply (IH1) in H2.
    2: { easy. }
    destruct H2 as [ HVal1 | [ HRed1 | HUnchk1 ] ].
    (* Case: `e1` is a value *)
    + (* We can take a step according to SLet *)
      left.  
      inv HVal1...
      apply (step_implies_reduces D (fenv empty_env) H st 
              (ELet x (ELit n t0) e2) H (Stack.add x (n, t0) st) (RExpr(ERet x (n,t0) (Stack.find x st) e2))).
      apply SLet.
      apply simple_tau_means_cast_same.
      easy.
    (* Case: `e1` reduces *)
    + (* We can take a step by reducing `e1` *)
      left.
      ctx (ELet x e1 e2) (in_hole e1 (CLet x CHole e2))...
    (* Case: `e1` is unchecked *)
    + (* `ELet x e1 e2` must be unchecked, since `e1` is *)
      right.
      ctx (ELet x e1 e2) (in_hole e1 (CLet x CHole e2)).
      destruct HUnchk1...
  (* Case: TyRet *)
  - (* `ELet x e1 e2` is not a value *)
    unfold Env.In,Env.Raw.PX.In in HIn.
    destruct HIn.
    apply EnvFacts.empty_mapsto_iff in H0. inv H0.
  - (* `ELet x e1 e2` is not a value *)
    unfold Env.In,Env.Raw.PX.In in HIn.
    destruct HIn.
    apply EnvFacts.empty_mapsto_iff in H0. inv H0.
  (* Case: TyAdd *)
  - (* `EPlus e1 e2` isn't a value *)
    right.
    inv Hewf.
    apply (IH1) in H2. 2:{ easy. }
    (* Invoke the IH on `e1` *)
    destruct H2 as [ HVal1 | [ HRed1 | HUnchk1 ] ].
    (* Case: `e1` is a value *)
    + (* We don't know if we can take a step yet, since `e2` might be unchecked. *)
      inv HVal1 as [ n1 t1 ].
      (* Invoke the IH on `e2` *)
      apply (IH2) in H3. 2:{ easy. }
      destruct H3 as [ HVal2 | [ HRed2 | HUnchk2 ] ].
      (* Case: `e2` is a value *)
      * (* We can step according to SAdd *)
        left.
        inv HVal2 as [ n2 t2 ]...
        eapply (step_implies_reduces D (fenv empty_env) H st (EPlus (ELit n1 t1) (ELit n2 t2)) H st (RExpr (ELit (n1 + n2) t1))).
        apply lit_nat_tau in HTy2. subst.
        apply (@SAdd D (fenv empty_env) st H t1 n1 n2).
        apply lit_nat_tau in HTy1. subst.
        unfold is_array_ptr. easy.
      (* Case: `e2` reduces *)
      * (* We can take a step by reducing `e2` *)
        left.
        ctx (EPlus (ELit n1 t1) e2) (in_hole e2 (CPlusR n1 t1 CHole))...
      (* Case: `e2` is unchecked *)
      * (* `EPlus (n1 t1) e2` must be unchecked, since `e2` is *)
        right.
        ctx (EPlus (ELit n1 t1) e2) (in_hole e2 (CPlusR n1 t1 CHole)).
        destruct HUnchk2...
    (* Case: `e1` reduces *)
    + (* We can take a step by reducing `e1` *)
      left.
      ctx (EPlus e1 e2) (in_hole e1 (CPlusL CHole e2))...
    (* Case: `e1` is unchecked *)
    + (* `EPlus e1 e2` must be unchecked, since `e1` is *)
      right.
      ctx (EPlus e1 e2) (in_hole e1 (CPlusL CHole e2)).
      destruct HUnchk1...
  (* Case: TyStruct *)
  - (* `EFieldAddr e fi` isn't a value *)
    right.
    inv Hewf.
    apply (IH) in H2. 2: { easy. }
    (* Invoke the IH on `e` *)
    destruct H2 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* So we can take a step... but how? *)
      left.
      inv HVal.
      inv HTy.
      {
        (* We proceed by case analysis on `m'` -- the mode of the pointer *)
        destruct m'.
        (* Case: m' = C *)
        * (* We now proceed by case analysis on 'n > 0' *)
          destruct (Z_gt_dec n 0).
          (* Case: n > 0 *)
          { (* We can step according to SStructChecked  *)
            assert (HWf3 := HDwf T fs HWf1). (* TODO(ins): turn these into lemmas, and stick into Progress db *)
            assert (HWf4 := HWf3 fi ti HWf2).
            destruct HWf4... }
          (* Case: n <= 0 *)
          { (* We can step according to SStructNull *)
             subst...   }
        (* Case: m' = U *)
        * (* We can step according to SStructUnChecked *)
          eapply step_implies_reduces; eapply SStructUnChecked; eauto.
          { (* LEO: This should probably be abstracted into a lemma *)
            apply HDwf in HWf1.
            apply HWf1 in HWf2.
            destruct HWf2...
          }
      }

        
    (* Case: `e` reduces *)
    + (* We can take a step by reducing `e` *)
      left.
      ctx (EFieldAddr e fi) (in_hole e (CFieldAddr CHole fi))...
    (* Case: `e` is unchecked *)
    + (* `EFieldAddr e fi` must be unchecked, since `e` is *)
      right.
      ctx (EFieldAddr e fi) (in_hole e (CFieldAddr CHole fi)).
      destruct HUnchk...
  (* Case: TyMalloc *)
  - (* `EMalloc w` isn't a value *)
    right.
    left.
    inv Hewf.
    specialize (well_typed_means_simple w Wb) as eq1.
    destruct w.
    * assert ((forall (l h : Z) (t : tau),
       TInt = TArray (Num l) (Num h) t -> l = 0 /\ h > 0)).
      intros. inv H0.
      assert (((forall (l h : Z) (t : tau),
       TInt = TNTArray (Num l) (Num h) t -> l = 0 /\ h > 0))).
       intros. inv H2.
       destruct ((wf_implies_allocate D TInt H H0 H2 eq1 H1)) as [ n [ H' HAlloc]].
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc TInt) H' st (RExpr (ELit n (TPtr C TInt)))).
       apply SMalloc. constructor.
       easy. easy.
   * assert ((forall (l h : Z) (t : tau),
       (TPtr m0 w) = TArray (Num l) (Num h) t -> l = 0 /\ h > 0)).
      intros. inv H0.
      assert (((forall (l h : Z) (t : tau),
       (TPtr m0 w) = TNTArray (Num l) (Num h) t -> l = 0 /\ h > 0))).
      intros. inv H2.
       destruct ((wf_implies_allocate D (TPtr m0 w) H H0 H2 eq1 H1)) as [ n [ H' HAlloc]].
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TPtr m0 w)) H' st (RExpr (ELit n (TPtr C (TPtr m0 w))))).
       apply SMalloc.
       apply simple_tau_means_cast_same. easy.
       unfold malloc_bound. easy.
       easy.
   * assert ((forall (l h : Z) (t : tau),
       (TStruct s) = TArray (Num l) (Num h) t -> l = 0 /\ h > 0)).
      intros. inv H0.
      assert (((forall (l h : Z) (t : tau),
       (TStruct s) = TNTArray (Num l) (Num h) t -> l = 0 /\ h > 0))).
      intros. inv H2.
       destruct ((wf_implies_allocate D (TStruct s) H H0 H2 eq1 H1)) as [ n [ H' HAlloc]].
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TStruct s)) H' st (RExpr (ELit n (TPtr C (TStruct s))))).
       apply SMalloc.
       apply (simple_tau_means_cast_same). easy. easy.
       assumption.
   * inv eq1.
     destruct (Z.eq_dec l 0).
     destruct (0 <? h) eqn:eq2.
     apply Z.ltb_lt in eq2.
     assert ((forall (l' h' : Z) (t : tau),
       (TArray (Num l) (Num h) w) = TArray (Num l') (Num h') t -> l' = 0 /\ h' > 0)).
      intros. split. injection H0.
      intros. subst. reflexivity.
      injection H0. intros. subst.  lia.
      assert ((forall (l' h' : Z) (t : tau),
       (TArray (Num l) (Num h) w) = TNTArray (Num l') (Num h') t -> l' = 0 /\ h' > 0)).
       intros. inv H3.
       assert (simple_tau (TArray (Num l) (Num h) w)).
       apply SPTArray. easy.
       destruct ((wf_implies_allocate D (TArray (Num l) (Num h) w) H H0 H3 H4 H1)) as [ n [ H' HAlloc]].
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TArray (Num l) (Num h) w))
                             H' st (RExpr (ELit n (TPtr C (TArray (Num l) (Num h) w))))).
       apply SMalloc.
       apply cast_tau_bound_array.
       unfold cast_bound. reflexivity.
       unfold cast_bound. reflexivity.
       apply simple_tau_means_cast_same. assumption.
       unfold malloc_bound. split. easy. lia. easy.
       assert (h <= 0).
       specialize (Z.ltb_lt 0 h) as eq3.
       apply not_iff_compat in eq3.
       assert((0 <? h) <> true).
       apply not_true_iff_false. assumption.
       apply eq3 in H0. lia.
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TArray (Num l) (Num h) w)) H st RBounds).
       apply (SMallocHighOOB D (fenv empty_env) st H (TArray (Num l) (Num h) w) (TArray (Num l) (Num h) w) h).
       assumption.
       apply simple_tau_means_eval_same. constructor. easy.
       easy.
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TArray (Num l) (Num h) w)) H st RBounds).
       apply (SMallocLowOOB D (fenv empty_env) st H (TArray (Num l) (Num h) w) (TArray (Num l) (Num h) w) l).
       assumption.
       apply simple_tau_means_eval_same. constructor. easy.
       easy.
   * inv eq1.
     destruct (Z.eq_dec l 0).
     destruct (0 <? h) eqn:eq2.
     apply Z.ltb_lt in eq2.
     assert ((forall (l' h' : Z) (t : tau),
       (TNTArray (Num l) (Num h) w) = TArray (Num l') (Num h') t -> l' = 0 /\ h' > 0)).
       intros. inv H0.
      assert ((forall (l' h' : Z) (t : tau),
       (TNTArray (Num l) (Num h) w) = TNTArray (Num l') (Num h') t -> l' = 0 /\ h' > 0)).
      intros. split. injection H3.
      intros. subst. reflexivity.
      injection H3. intros. subst.  lia.
       assert (simple_tau (TNTArray (Num l) (Num h) w)).
       apply SPTNTArray. easy.
       destruct ((wf_implies_allocate D (TNTArray (Num l) (Num h) w) H H0 H3 H4 H1)) as [ n [ H' HAlloc]].
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TNTArray (Num l) (Num h) w))
                             H' st (RExpr (ELit n (TPtr C (TNTArray (Num l) (Num h) w))))).
       apply SMalloc.
       apply cast_tau_bound_ntarray.
       unfold cast_bound. reflexivity.
       unfold cast_bound. reflexivity.
       apply simple_tau_means_cast_same. assumption.
       unfold malloc_bound.  split. easy. lia. easy.
       assert (h <= 0).
       specialize (Z.ltb_lt 0 h) as eq3.
       apply not_iff_compat in eq3.
       assert((0 <? h) <> true).
       apply not_true_iff_false. assumption.
       apply eq3 in H0. lia.
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TNTArray (Num l) (Num h) w)) H st RBounds).
       apply (SMallocHighOOB D (fenv empty_env) st H (TNTArray (Num l) (Num h) w) (TNTArray (Num l) (Num h) w) h).
       assumption.
       apply simple_tau_means_eval_same. constructor. easy.
       easy.
       apply (step_implies_reduces D (fenv empty_env) H st (EMalloc (TNTArray (Num l) (Num h) w)) H st RBounds).
       apply (SMallocLowOOB D (fenv empty_env) st H (TNTArray (Num l) (Num h) w) (TNTArray (Num l) (Num h) w) l).
       assumption.
       apply simple_tau_means_eval_same. constructor. easy.
       easy.
  (* Case: TyUnChecked *)
  - (* `EUnchecked e` isn't a value *)
    right.
    inv Hewf.
    apply (IH) in H1.
    2: { easy. }
    (* Invoke the IH on `e` *)
    destruct H1 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SUnChecked *)
      left.
      inv HVal...
    (* Case: `e` reduces *)
    + (* We can take a step by reducing `e` *)
      left.
      ctx (EUnchecked e) (in_hole e (CU CHole))...
    (* Case: `e` is unchecked *)
    + (* `EUnchecked e` is obviously unchecked *)
      right.
      ctx (EUnchecked e) (in_hole e (CU CHole))...
  (* Case: TyCast *)
  - (* `ECast t e` isn't a value when t is a nat tau or is unchecked mode. *)
    right.
    inv Hewf. apply (IH) in H4. 2: { easy. }
    (* Invoke the IH on `e` *)
    destruct H4 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SCast *)
      destruct m.
      left.
      inv HVal.
      specialize (well_typed_means_simple t Wb) as eq1.
      apply simple_tau_means_cast_same with ( s:= st) in eq1.
      apply (step_implies_reduces D (fenv empty_env) H st (ECast t (ELit n t0)) H st (RExpr (ELit n t))).
      apply SCast. easy.
      right. unfold unchecked. left.
      reflexivity.
    (* Case: `e` reduces *)
    + (* `ECast t e` can take a step by reducing `e` *)
      left.
      ctx (ECast t e) (in_hole e (CCast t CHole))...
    (* Case: `e` is unchecked *)
    + (* `ECast t e` must be unchecked, since `e` is *)
      right.
      ctx (ECast t e) (in_hole e (CCast t CHole)).
      destruct HUnchk...
  - (* `ECast (TPtr C t) e` isn't a value when t is a nat tau or is unchecked mode. *)
    right.
    inv Hewf. apply (IH) in H4. 2: { easy. }
    (* Invoke the IH on `e` *)
    destruct H4 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SCast *)
      destruct m.
      left.
      inv HVal.
      apply (step_implies_reduces D (fenv empty_env) H st (ECast (TPtr C t) (ELit n t0)) H st (RExpr (ELit n (TPtr C t)))).
      apply SCast.
      apply simple_tau_means_cast_same. constructor.
      apply well_typed_means_simple; try easy.
      right. unfold unchecked. left.
      reflexivity.
    (* Case: `e` reduces *)
    + (* `ECast t e` can take a step by reducing `e` *)
      left.
      ctx (ECast (TPtr C t) e) (in_hole e (CCast (TPtr C t) CHole))...
    (* Case: `e` is unchecked *)
    + (* `ECast t e` must be unchecked, since `e` is *)
      right.
      ctx (ECast (TPtr C t) e) (in_hole e (CCast (TPtr C t) CHole)).
      destruct HUnchk...
  - (* `EDynCast t e` isn't a value when t is an array pointer. *)
    right.
    inv Hewf.
    apply (IH) in H4. 2 : { easy. }
    (* Invoke the IH on `e` *)
    destruct H4 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SCast *)
      left.
      inv HVal.
      inv HTy.
      specialize (well_typed_means_simple (TPtr C (TArray x y t)) Wb) as eq2.
      inv eq2. inv H6.
      inv H4. inv H6.
      destruct (Z_le_dec l0 l).
      destruct (Z_lt_dec l h).
      destruct (Z_le_dec h h0).
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TArray (Num l) (Num h) t))
           (ELit n (TPtr C (TArray (Num l0) (Num h0) t')))) H st (RExpr (ELit n (TPtr C (TArray (Num l) (Num h) t))))).
      apply (SDynCastArray D (fenv empty_env) st H (TPtr C (TArray (Num l) (Num h) t)) n (TPtr C (TArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      constructor. constructor. easy. easy.
      apply simple_tau_means_cast_same with ( s:= st). easy.
      unfold eval_tau_bound,eval_bound. reflexivity. easy. easy.  easy.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TArray (Num l) (Num h) t))
            (ELit n (TPtr C (TArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastArrayHighOOB1 D (fenv empty_env) st H (TPtr C (TArray (Num l) (Num h) t)) n (TPtr C (TArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TArray (Num l) (Num h) t))
            (ELit n (TPtr C (TArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastArrayLowOOB2 D (fenv empty_env) st H (TPtr C (TArray (Num l) (Num h) t)) n (TPtr C (TArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TArray (Num l) (Num h) t))
            (ELit n (TPtr C (TArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastArrayLowOOB1 D (fenv empty_env) st H (TPtr C (TArray (Num l) (Num h) t)) n (TPtr C (TArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
    (* Case: `e` reduces *)
    + (* `ECast t e` can take a step by reducing `e` *)
      left.
      ctx (EDynCast (TPtr C (TArray x y t)) e) (in_hole e (CDynCast (TPtr C (TArray x y t)) CHole))...
    (* Case: `e` is unchecked *)
    + (* `ECast t e` must be unchecked, since `e` is *)
      right.
      ctx (EDynCast (TPtr C (TArray x y t)) e) (in_hole e (CDynCast (TPtr C (TArray x y t)) CHole)).
      destruct HUnchk...
  - (* `EDynCast t e` isn't a value when t is an pointer. *)
    right.
    inv Hewf.
    apply (IH) in H4. 2 : { easy. }
    (* Invoke the IH on `e` *)
    destruct H4 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SCast *)
      left.
      inv HVal.
      inv HTy.
      specialize (well_typed_means_simple (TPtr C (TArray x y t)) Wb) as eq2.
      inv eq2. inv H6.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TArray (Num l) (Num h) t))
           (ELit n (TPtr C t'))) H st (RExpr (ELit n (TPtr C (TArray (Num 0) (Num 1) t))))).
      apply (SDynCast D (fenv empty_env) st H (Num l) (Num h) t n C t'); try easy.
      apply simple_tau_means_cast_same with ( s:= st). easy.
    (* Case: `e` reduces *)
    + (* `ECast t e` can take a step by reducing `e` *)
      left.
      ctx (EDynCast (TPtr C (TArray x y t)) e) (in_hole e (CDynCast (TPtr C (TArray x y t)) CHole))...
    (* Case: `e` is unchecked *)
    + (* `ECast t e` must be unchecked, since `e` is *)
      right.
      ctx (EDynCast (TPtr C (TArray x y t)) e) (in_hole e (CDynCast (TPtr C (TArray x y t)) CHole)).
      destruct HUnchk...
  - (* `ECast t e` isn't a value when t is an nt-array pointer. *)
    right.
    inv Hewf. 
    apply (IH) in H4. 2 : { easy. }
    (* Invoke the IH on `e` *)
    destruct H4 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
    + (* We can step according to SCast *)
      left.
      inv HVal.
      inv HTy.
      specialize (well_typed_means_simple (TPtr C (TNTArray x y t)) Wb) as eq2.
      inv eq2. inv H6. inv H4. inv H6.
      destruct (Z_le_dec l0 l).
      destruct (Z_lt_dec l h).
      destruct (Z_le_dec h h0).
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TNTArray (Num l) (Num h) t))
           (ELit n (TPtr C (TNTArray (Num l0) (Num h0) t')))) H st (RExpr (ELit n (TPtr C (TNTArray (Num l) (Num h) t))))).
      apply (SDynCastNTArray D (fenv empty_env) st H (TPtr C (TNTArray (Num l) (Num h) t)) n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      constructor. constructor. easy. easy.
      apply simple_tau_means_cast_same with ( s:= st). easy.
      unfold eval_tau_bound,eval_bound. reflexivity. easy. easy.  easy.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TNTArray (Num l) (Num h) t))
            (ELit n (TPtr C (TNTArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastNTArrayHighOOB1 D (fenv empty_env) st H (TPtr C (TNTArray (Num l) (Num h) t)) n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TNTArray (Num l) (Num h) t))
            (ELit n (TPtr C (TNTArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastNTArrayLowOOB2 D (fenv empty_env) st H (TPtr C (TNTArray (Num l) (Num h) t)) n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
      apply (step_implies_reduces D (fenv empty_env) H st (EDynCast (TPtr C (TNTArray (Num l) (Num h) t))
            (ELit n (TPtr C (TNTArray (Num l0) (Num h0) t')))) H st RBounds).
      apply (SDynCastNTArrayLowOOB1 D (fenv empty_env) st H (TPtr C (TNTArray (Num l) (Num h) t)) n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                  l h t l0 h0 t').
      unfold eval_tau_bound,eval_bound. reflexivity.
      unfold eval_tau_bound,eval_bound. reflexivity. lia.
    (* Case: `e` reduces *)
    + (* `ECast t e` can take a step by reducing `e` *)
      left.
      ctx (EDynCast (TPtr C (TNTArray x y t)) e) (in_hole e (CDynCast (TPtr C (TNTArray x y t)) CHole))...
    (* Case: `e` is unchecked *)
    + (* `ECast t e` must be unchecked, since `e` is *)
      right.
      ctx (EDynCast (TPtr C (TNTArray x y t)) e) (in_hole e (CDynCast (TPtr C (TNTArray x y t)) CHole)).
      destruct HUnchk...
  (* Case: TyDeref *)
  - (* `EDeref e` isn't a value *)
    right.

    (* If m' is unchecked, then the typing mode `m` is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.

    (* TODO(ins): find a way to automate everything after case analysis... *)
    inv Hewf.
    apply (IH) in H1. 2 : { easy. }
    (* Invoke the IH on `e` *)
    destruct H1 as [ HVal | [ HRed | HUnchk ] ].
    (* Case: `e` is a value *)
     (* We can take a step... but how? *)

     + inv HVal.
      inv HTy.
      (* We proceed by case analysis on `w`, the tau of the pointer *)
      destruct HPtrType.
      (* Case: `w` is a word pointer *)
      * (* We now proceed by case analysis on 'n > 0' *)
        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (*Since w is subtype of a ptr it is also a ptr*)
          assert (H4 : exists t1, t = (TPtr C t1)).
          { eapply ptr_subtype_equiv. eauto.
          } destruct H4. rewrite H4 in *.
          clear H4.
          (* We now proceed by case analysis on '|- n0 : ptr_C w' *)
          inv H3.
          assert (HSim := H2).
          inv H9.
          (* Case: TyLitZero *)
          {
           (* Impossible, since n > 0 *)
           exfalso. lia.
            (*subst. inv H2. inv H3.*)
          }
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope. }
          (* Case: TyLitC *)
          { (* We can step according to SDeref *)
            destruct H11 with (k := 0) as [ n' [ t1' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
            unfold allocate_meta in *.
            specialize (subtype_trans D Q (TPtr C w) (TPtr C t') C x H6 HSub) as X1.
            inv H4.
            inv X1. inv H7. simpl. lia. 
            inv H10. inv H12.  inv H7. rewrite replicate_gt_eq. lia. lia.
            inv H7. simpl. lia.
            inv H10. inv H12.  inv H7. rewrite replicate_gt_eq. lia. lia.
            inv H7. simpl. lia.
            apply StructDef.find_1 in H8. rewrite H8 in H7. inv H7.
            split. lia.
            assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) fs))) > 0). 
            {
              eapply struct_subtype_non_empty; eauto.
              apply (SubTyStructArrayField_1 D Q T fs m).
              apply StructDef.find_2. assumption.
              assumption.
              apply StructDef.find_2.  easy.
            } lia.
            inv X1. inv H7. simpl. lia.
            inv H10. inv H12.  inv H7. rewrite replicate_gt_eq. lia. lia.
            inv H7. simpl. lia.
            inv H10. inv H12.  inv H7. rewrite replicate_gt_eq. lia. lia.
            inv H7. simpl. lia.
            rewrite Z.add_0_r in Hheap;
            inv Ht'tk.
            left.
            assert (exists tv, @get_root D (TPtr C x) tv).
            inv HSub.
            exists t'. constructor. easy.
            exists x. constructor. easy.
            exists t'. apply get_root_array.
            exists t'. apply get_root_ntarray.
            inv H4. inv H4. inv H4.
            exists TInt. apply get_root_struct with (f := fs); try easy.
            inv H4.
            destruct H7. destruct H3.
            eapply step_implies_reduces.
            eapply SDeref; eauto.
            - apply simple_tau_means_cast_same. easy.
            - intros. inv H7. inv H4. inv HSub.
              inv H14. inv H15. split. lia. easy.
              inv HSub. inv H14. inv H15. lia.
            - intros. inv H7. inv H4. inv HSub.
              inv H14. inv H15. split. lia. easy.
              inv HSub. inv H14. inv H15. lia.
          }
        }
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          left. eapply step_implies_reduces.
         
          assert (exists w0, t = TPtr C w0).
          {
            inv H0. inv HSub.
            exists w. destruct m0.
            reflexivity. inv HSub.
          }
          destruct H4. subst.
          eapply SDerefNull; eauto. 
        }

      (* Case: `w` is an array pointer *)
      * destruct H3.
        destruct H3 as [Ht H3].
        subst.

        assert (HArr : (exists l0 h0, t = (TPtr C (TArray l0 h0 t')))
                     \/ (exists l0 h0, t = (TPtr C (TNTArray l0 h0 t')))
                        \/ (t = TPtr C t')
                           \/ (exists T, (t = TPtr C (TStruct T)))).
        {
          inv HSub.
          left. exists l; exists h; reflexivity.
          right. right. left. easy. inv H6.
          inv H6.
          left. exists l0; exists h0; reflexivity.
          right. left. exists l0; exists h0; reflexivity.
          right. right. right. exists T. easy.
        }

        destruct HArr.
        destruct H4 as [l1 [h1 HArr]].
        subst.
        (* We now perform case analysis on 'n > 0' *)
        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (* We now proceed by case analysis on '|- n0 : ptr_C (array n t)' *)
          assert (simple_tau ((TPtr C (TArray l1 h1 t')))) as Y1.
          easy.
          match goal with
          | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
          end.
          (* Case: TyLitZero *)
          { (* Impossible, since n0 <> 0 *)
            exfalso. inv Hn0eq0.
          } 
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope.
          } 
          (* Case: TyLitC *)
          { (* We proceed by case analysis on 'h > 0' -- the size of the array *)
            destruct H3 as [Hyp2 Hyp3]; subst.
            inv Y1. inv H4.
            (* should this also be on ' h > 0' instead? DP*)
            destruct (Z_gt_dec h0 0) as [ Hneq0 | Hnneq0 ].
            (* Case: h > 0 *)
            { left. (* We can step according to SDeref *)
              (* LEO: This looks exactly like the previous one. Abstract ? *)
              inv H6. inv H7.
              specialize (simple_tau_means_cast_same t' st H8) as eq1.
              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) t'))
                           (TPtr C (TArray (Num l0) (Num h0) t')) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }
              
              (* if l <= 0 we can step according to SDeref. *)

              assert (Hhl : h0 - l0 > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }
              destruct (h0 - l0) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.
              assert (HL: l0 + Z.of_nat (Pos.to_nat p) = h0) by (zify; lia).
              rewrite HL in *; try lia.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TArray (Num l0) (Num h0) t'))
                          (TPtr C (TArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              intros l' h' t'' HT.
              inv HT.
              split; zify; lia.
              intros. inv H3.
              apply get_root_array.

              inv H14. inv H15.

              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) t'))
                           (TPtr C (TArray (Num l0) (Num h0) t')) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }

              assert (l0 = 0) by lia.
              assert (h0 = 1) by lia.
              subst.

              (* if l <= 0 we can step according to SDeref. *)
              inv H12. inv H7.
              specialize (H11 0). simpl in *.
              assert (0 <= 0 < 1) by lia.
              apply H11 in H3. destruct H3 as [n' [t' [X1 [X2 X3]]]].
              inv X1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' TInt (TPtr C (TArray (Num 0) (Num 1) TInt))
                          (TPtr C (TArray (Num 0) (Num 1) TInt))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              rewrite Z.add_0_r in X2. easy.
              intros. inv H3. lia.
              intros. inv H3.
              apply get_root_array.

              inv H7.
              specialize (H11 0). simpl in *.
              assert (0 <= 0 < 1) by lia.
              apply H11 in H3. destruct H3 as [n' [t' [X1 [X2 X3]]]].
              inv X1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' (TPtr m0 w) (TPtr C (TArray (Num 0) (Num 1) (TPtr m0 w)))
                          (TPtr C (TArray (Num 0) (Num 1) (TPtr m0 w)))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              rewrite Z.add_0_r in X2. easy.
              intros. inv H3. lia.
              intros. inv H3.
              apply get_root_array.
              inv H10. inv H10.
              inv H10. inv H14.

              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) t'))
                           (TPtr C (TArray (Num l0) (Num h0) t')) l0). lia.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }

              (* if l <= 0 we can step according to SDeref. *)
              inv H7.
              assert (l2 <= 0) by lia.
              rewrite replicate_gt_eq in *.

              assert (Hhl : h2 - l2 > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              lia.
              rewrite Z.add_0_r in Hheap.
              simpl in *.
              unfold Zreplicate in Ht'tk.

              destruct (h2 - l2) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.

              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TArray (Num l0) (Num h0) t'))
                          (TPtr C (TArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              intros l' h' t'' HT.
              inv HT.
              split; zify; lia.
              intros. inv H7.
              apply get_root_array.
              lia.
              inv H5.
              
              inv H10. inv H14. 
              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) t'))
                           (TPtr C (TArray (Num l0) (Num h0) t')) l0). lia.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }

              (* if l <= 0 we can step according to SDeref. *)
              inv H7.
              assert (l2 <= 0) by lia.
              rewrite replicate_gt_eq in *.

              assert (Hhl : h2 - l2 > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              lia.
              rewrite Z.add_0_r in Hheap.
              simpl in *.
              unfold Zreplicate in Ht'tk.

              destruct (h2 - l2 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.

              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TArray (Num l0) (Num h0) t'))
                          (TPtr C (TArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              intros l' h' t'' HT.
              inv HT.
              split; zify; lia.
              intros. inv H7.
              apply get_root_array.
              lia.
              inv H5.
              
              inv H15. inv H16.
              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) TInt))
                           (TPtr C (TArray (Num l0) (Num h0) TInt)) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }

              assert (l0 = 0) by lia.
              assert (h0 = 1) by lia.
              subst.

              destruct H11 with (k := 0) as [ n' [ t1' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              unfold allocate_meta in *. inv H7. 
              destruct (StructDef.find T D) eqn:HFind.
               assert (Hmap : StructDef.MapsTo T f D). 
               {
                 eapply find_implies_mapsto. assumption.
                }
               assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) f))) > 0). 
              {
                 eapply struct_subtype_non_empty; eauto.
                 apply (SubTyStructArrayField_1 D Q T fs m).
                 assumption.
                 assumption.
              }
              inv H4; zify; try lia.
              inv H4.

              rewrite Z.add_0_r in Hheap;
              inv Ht'tk.
              eapply step_implies_reduces.
              eapply SDeref; eauto.
              - apply simple_tau_means_cast_same. easy.
              - intros. inv H3. lia.
              - intros. inv H3.
              - apply get_root_array.

            }
            (* Case: h <= 0 *)
            { (* We can step according to SDerefOOB *)
              subst. left. eapply step_implies_reduces. 
              eapply (SDerefHighOOB D (fenv empty_env) st H n (TPtr C (TArray (Num l0) (Num h0) t'))
                           (TPtr C (TArray (Num l0) (Num h0) t')) h0). eauto.
              unfold eval_tau_bound; eauto. unfold get_high_ptr. reflexivity.
            }
          }
        } 
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          subst... }

        (* when subtype is nt-array ptr. *)
        destruct H4.
        destruct H4 as [l1 [h1 HArr]].
        subst.
        (* We now perform case analysis on 'n > 0' *)
        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (* We now proceed by case analysis on '|- n0 : ptr_C (array n t)' *)
          assert (simple_tau ((TPtr C (TNTArray l1 h1 t')))) as Y1.
          easy.
          match goal with
          | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
          end.
          (* Case: TyLitZero *)
          { (* Impossible, since n0 <> 0 *)
            exfalso. inv Hn0eq0.
          } 
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope.
          } 
          (* Case: TyLitC *)
          { (* We proceed by case analysis on 'h > 0' -- the size of the array *)
            destruct H3 as [Hyp2 Hyp3]; subst.
            inv Y1. inv H4. 
            (* should this also be on ' h > 0' instead? DP*)
            destruct (Z_gt_dec h0 0) as [ Hneq0 | Hnneq0 ].
            (* Case: h > 0 *)
            { left. (* We can step according to SDeref *)
              (* LEO: This looks exactly like the previous one. Abstract ? *)
              inv H6. inv H7.
              specialize (simple_tau_means_cast_same t' st H8) as eq1.
              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                           (TPtr C (TNTArray (Num l0) (Num h0) t')) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }
              
              (* if l <= 0 we can step according to SDeref. *)

              assert (Hhl : h0 - l0 +1 > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }
              destruct (h0 - l0 +1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TNTArray (Num l0) (Num h0) t'))
                          (TPtr C (TNTArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              intros l' h' t'' HT. inv HT.
              intros.
              inv H3.
              split; zify; lia.
              apply get_root_ntarray.
              inv H10. inv H10.

              inv H10. inv H14.

              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                           (TPtr C (TNTArray (Num l0) (Num h0) t')) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
              }

              (* if l <= 0 we can step according to SDeref. *)
              inv H7.
              assert (l2 <= 0) by lia.
              rewrite replicate_gt_eq in *.

              assert (Hhl : h2 - l2 + 1 > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              lia.
              rewrite Z.add_0_r in Hheap.
              simpl in *.
              unfold Zreplicate in Ht'tk.

              destruct (h2 - l2 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.

              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TNTArray (Num l0) (Num h0) t'))
                          (TPtr C (TNTArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              intros l' h' t'' HT. inv HT.
              intros. inv H7.
              split; zify; lia.
              apply get_root_ntarray.
              lia.
              inv H5.
            }
            (* Case: h <= 0 *)
            { (* We can step according to SDerefOOB *)
              subst. left. eapply step_implies_reduces. 
              eapply (SDerefHighOOB D (fenv empty_env) st H n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                           (TPtr C (TNTArray (Num l0) (Num h0) t')) h0). eauto.
              unfold eval_tau_bound; eauto. unfold get_high_ptr. reflexivity.
            }

          }
        } 
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          subst... }

        destruct H4.
        destruct H3 as [Ht H3].
        subst.

        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (*Since w is subtype of a ptr it is also a ptr*)
          (* We now proceed by case analysis on '|- n0 : ptr_C w' *)
          assert (simple_tau (TPtr C t')) as Hsim. easy.
          inv H9.
          (* Case: TyLitZero *)
          {
           (* Impossible, since n > 0 *)
           exfalso. lia.
            (*subst. inv H2. inv H3.*)
          }
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope. }
          (* Case: TyLitC *)
          { (* We can step according to SDeref *)
            inv H6. 

            destruct H11 with (k := 0) as [ n' [ t1' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
            unfold allocate_meta in *. destruct t'.
            inv H7. simpl. lia. inv H7. simpl. lia.
            inv Ht. inv Ht. inv Ht.

            rewrite Z.add_0_r in Hheap;
            inv Ht'tk.
            left.
            eapply step_implies_reduces.
            eapply SDeref; eauto.
            apply simple_tau_means_cast_same. constructor. inv Hsim. easy.
            intros. inv H4. inv Ht.
            intros. inv H4. inv Ht.
            constructor. easy.

            inv H12. inv H13.

            destruct (Z_gt_dec h1 0).

            (* if l > 0 we have a bounds error*)
            {
                left.
                eapply step_implies_reduces. 
                apply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TArray (Num h1) (Num l0) w))
                           (TPtr C (TArray (Num h1) (Num l0) w)) h1). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr. easy.
            }

            destruct (Z_ge_dec 0 l0).

            (* if h <= 0 we have a bounds error*)
            {
                left.
                eapply step_implies_reduces. 
                apply (SDerefHighOOB D (fenv empty_env) st H n (TPtr C (TArray (Num h1) (Num l0) w))
                           (TPtr C (TArray (Num h1) (Num l0) w)) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_high_ptr. easy.
            }

            assert (h1 = 0) by lia.
            assert (l0 = 1) by lia. subst.
              (* if l <= 0 we can step according to SDeref. *)
              inv H10. inv H7.
              left.
              specialize (H11 0). simpl in *.
              assert (0 <= 0 < 1) by lia.
              apply H11 in H4. destruct H4 as [n' [t' [X1 [X2 X3]]]].
              inv X1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' TInt (TPtr C (TArray (Num 0) (Num 1) TInt))
                          (TPtr C (TArray (Num 0) (Num 1) TInt))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              rewrite Z.add_0_r in X2. easy.
              intros. inv H4. lia.
              intros. inv H4.
              apply get_root_array.

              inv H7. left.
              specialize (H11 0). simpl in *.
              assert (0 <= 0 < 1) by lia.
              apply H11 in H4. destruct H4 as [n' [t' [X1 [X2 X3]]]].
              inv X1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' (TPtr m0 w0) (TPtr C (TArray (Num 0) (Num 1) (TPtr m0 w0)))
                          (TPtr C (TArray (Num 0) (Num 1) (TPtr m0 w0)))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor.  easy.
              rewrite Z.add_0_r in X2. easy.
              intros. inv H4. lia.
              intros. inv H4.
              apply get_root_array.
              inv Hsim. inv H9.
              inv H7. 
              inv H12. inv H13.

              inv H6. left.
              assert (Hhl : (h1 - l1) > 0) by lia.

              destruct (h1 - l1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.
              assert (HL: l1 + Z.of_nat (Pos.to_nat p) = h1) by (zify; lia).
              rewrite HL in *; try lia.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              apply (simple_tau_means_cast_same) with (s := st) in H5 as eq1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C t') (TPtr C t')); eauto.
              apply simple_tau_means_cast_same. constructor. inv H2. easy.
              intros. inv H4. inv H10.
              intros. inv H4. inv H10.
              apply get_root_word. easy.

              inv H5.
              inv H12. inv H13.
              inv H7. left.
              assert (Hhl : (h1 - l1 + 1) > 0) by lia.

              destruct (h1 - l1  + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.
              assert (HL: l1 + Z.of_nat (Pos.to_nat p) = h1+1) by (zify; lia).
              rewrite HL in *; try lia.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.

              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C t') (TPtr C t')); eauto.
              apply simple_tau_means_cast_same. constructor. inv H2. easy.
              intros. inv H4. inv H10.
              intros. inv H4. inv H10.
              apply get_root_word. easy.
              inv H5. inv H5. inv Ht. inv Ht. inv Ht.

              inv H7.
              destruct H11 with (k := 0) as [ n' [ t1' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              unfold allocate_meta in *. 
              destruct (StructDef.find T D) eqn:HFind.
               assert (Hmap : StructDef.MapsTo T f D). 
               {
                 eapply find_implies_mapsto. assumption.
                }
               assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) f))) > 0). 
              {
                 eapply struct_subtype_non_empty; eauto.
                 apply (SubTyStructArrayField_1 D Q T fs m).
                 assumption.
                 assumption.
              }
              inv H6; zify; try lia.
              inv H6.

              rewrite Z.add_0_r in Hheap;
              inv Ht'tk. left.
              eapply step_implies_reduces.
              eapply SDeref; eauto.
              apply simple_tau_means_cast_same. easy.
              intros. inv H4.
              intros. inv H4.
              apply get_root_word. easy.

              inv H13. inv H14. inv Ht. inv H2. inv H9.

          }
        }
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          left. eapply step_implies_reduces.
         
          eapply SDerefNull; eauto. 
        }

       (* when subtype is a TStruct pointer. *)
        destruct H4.
        destruct H3 as [Ht H3].
        subst.
        inv HSub. inv Ht.        

        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (*Since w is subtype of a ptr it is also a ptr*)
          (* We now proceed by case analysis on '|- n0 : ptr_C w' *)
          assert (simple_tau (TPtr C (TStruct x))) as Hsim.
          constructor. constructor. inv H9.
          (* Case: TyLitZero *)
          {
           (* Impossible, since n > 0 *)
           exfalso. lia.
            (*subst. inv H2. inv H3.*)
          }
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope. }
          (* Case: TyLitC *)
          { (* We can step according to SDeref *)
            inv H6. 
            destruct H15 with (k := 0) as [ n' [ t1' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
            unfold allocate_meta in *. inv H7. 
            destruct (StructDef.find x D) eqn:HFind.
            assert (Hmap : StructDef.MapsTo x f D). 
            {
             eapply find_implies_mapsto. assumption.
            }
            assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) f))) > 0). 
            {
              eapply struct_subtype_non_empty; eauto.
              apply (SubTyStructArrayField_1 D Q x fs m).
              assumption.
              assumption.
            }
            inv H6; zify; try lia.
            inv H6.

            unfold allocate_meta in *. inv H7.
            destruct (StructDef.find x D) eqn:HFind.
            assert (Hmap : StructDef.MapsTo x f D). 
            {
             eapply find_implies_mapsto. assumption.
            }
            assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) f))) > 0). 
            {
              eapply struct_subtype_non_empty; eauto.
              apply (SubTyStructArrayField_1 D Q x fs m).
              assumption.
              assumption.
            }

            rewrite Z.add_0_r in Hheap;
            inv Ht'tk. inv H6.
            left.
            eapply step_implies_reduces.
            eapply SDeref; eauto.
            apply simple_tau_means_cast_same. easy.
            intros. inv H6.
            intros. inv H6.
            apply get_root_struct with (f0 := f); try easy. 
            apply StructDef.find_1 in H10.
            rewrite H10 in *. inv HFind. easy. inv H6. inv H14. inv H14.
          }
        }
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          left. eapply step_implies_reduces.
         
          eapply SDerefNull; eauto. 
        }

        (* when t'' is a TNTArray. *)
        destruct H3 as [Ht H3]. subst.
        assert (HArr : (exists l0 h0, t = (TPtr C (TNTArray l0 h0 t')))).
        {
          inv HSub.
          exists l; exists h; easy.
          inv H6. inv H6.
          exists l0; exists h0; reflexivity.
        }

        destruct HArr as [l1 [h1 HArr]].
        rewrite HArr in *. clear HArr.
        (* We now perform case analysis on 'n > 0' *)
        destruct (Z_gt_dec n 0) as [ Hn0eq0 | Hn0neq0 ].
        (* Case: n > 0 *)
        { (* We now proceed by case analysis on '|- n0 : ptr_C (array n t)' *)
          assert (simple_tau ((TPtr C (TNTArray l1 h1 t')))) as Y1.
          easy.
          match goal with
          | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
          end.
          (* Case: TyLitZero *)
          { (* Impossible, since n0 <> 0 *)
            exfalso. inv Hn0eq0.
          } 
          (* Case: TyLitRec *)
          { (* Impossible, since scope is empty *)
            solve_empty_scope.
          } 
          (* Case: TyLitC *)
          { (* We proceed by case analysis on 'h > 0' -- the size of the array *)
            destruct H3 as [Hyp2 Hyp3]; subst.
            inv Y1. inv H4.
            (* should this also be on ' h > 0' instead? DP*)
            destruct (Z_gt_dec h0 0) as [ Hneq0 | Hnneq0 ].
            (* Case: h > 0 *)
            { left. (* We can step according to SDeref *)
              (* LEO: This looks exactly like the previous one. Abstract ? *)
              destruct (Z_gt_dec l0 0).

              (* if l > 0 we have a bounds error*)
              {
                eapply step_implies_reduces. 
                eapply (SDerefLowOOB D (fenv empty_env) st H n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                           (TPtr C (TNTArray (Num l0) (Num h0) t')) l0). easy.
                unfold eval_tau_bound. eauto.
                unfold get_low_ptr.
                reflexivity.
              }
              
              (* if l <= 0 we can step according to SDeref. *)
              inv H6. inv H7.
              assert (Hhl : (h0 - l0 + 1) > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }

              destruct (h0 - l0 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.
              assert (HL: l0 + Z.of_nat (Pos.to_nat p) = h0+1) by (zify; lia).
              rewrite HL in *; try lia.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              apply (simple_tau_means_cast_same) with (s := st) in H5 as eq1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TNTArray (Num l0) (Num h0) t'))
                          (TPtr C (TNTArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor. easy. 
              intros. inv H3.
              intros l' h' t'' HT.
              injection HT. intros. subst.
              split; zify; lia.
              apply get_root_ntarray.
              inv H10. inv H10.

              inv H10. inv H14. inv H7.
              assert (Hhl : (h2 - l2 + 1) > 0). {
                destruct h0. inv Hneq0. lia. inv Hneq0.
              }

              destruct (h2 - l2 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
              simpl in *.
              rewrite replicate_length in *.

              destruct H11 with (k := 0) as [ n' [ t'' [ Ht'tk [ Hheap Hwtn' ] ] ] ].
              { (split;  lia). }

              rewrite Z.add_0_r in Hheap.
              simpl in *.

              assert (Hp': Z.of_nat (Pos.to_nat p) = Z.pos p) by lia.
              rewrite Hp' in *; clear Hp'.
              assert (Hp': Pos.to_nat p = Z.to_nat (Z.pos p)) by (simpl; reflexivity).
              rewrite Hp' in *; clear Hp'. 

              assert (t' = t'').
              {
                eapply replicate_nth; eauto.
              }
              subst t''.
              apply (simple_tau_means_cast_same) with (s := st) in H5 as eq1.
              eapply step_implies_reduces.
              apply (SDeref D (fenv empty_env) st H n n' t' (TPtr C (TNTArray (Num l0) (Num h0) t'))
                          (TPtr C (TNTArray (Num l0) (Num h0) t'))); eauto.
              apply simple_tau_means_cast_same. constructor. constructor. easy. 
              intros. inv H3.
              intros l' h' t'' HT.
              injection HT. intros. subst.
              split; zify; lia.
              apply get_root_ntarray.
              inv H5.
            }
            (* Case: h <= 0 *)
            { (* We can step according to SDerefOOB *)
              subst. left. eapply step_implies_reduces. 
              eapply (SDerefHighOOB D (fenv empty_env) st H n (TPtr C (TNTArray (Num l0) (Num h0) t'))
                           (TPtr C (TNTArray (Num l0) (Num h0) t')) h0). eauto.
              unfold eval_tau_bound; eauto. unfold get_high_ptr. reflexivity.
            } 
          }
        } 
        (* Case: n <= 0 *)
        { (* We can step according to SDerefNull *)
          subst... }

     + left. ctx (EDeref e) (in_hole e (CDeref CHole))...
     + right.
       ctx (EDeref e) (in_hole e (CDeref CHole)).
       destruct HUnchk...
  - (* Index for array tau. *)
    right.
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.
    (* Leo: This is becoming hacky *)
    inv Hewf. inv H1.
    (*
    assert (exists l0 h0, t = (TPtr C (TArray l0 h0 t'))).
    {
      inv HSubType. exists l; exists h; eauto.
      exists l0; exists h0; eauto.
    }
    destruct H0 as [l0 [h0 H0]].
    rewrite H0 in *.
    clear HSubType H0 l h.
    remember l0 as l. remember h0 as h.
    clear Heql Heqh l0 h0 t.
    remember t' as t. clear Heqt t'.
    *)
    specialize (IH1 H3 eq_refl).
    specialize (IH2 H4 eq_refl).
    destruct IH1 as [ HVal1 | [ HRed1 | HUnchk1 ] ]; eauto.
    + inv HVal1 as [ n1 t1 ].
      destruct IH2 as [ HVal2 | [ HRed2 | HUnchk2 ] ]; eauto.
      * left.
        inv HVal2.
        ctx (EDeref (EPlus (ELit n1 t1) (ELit n t0))) (in_hole (EPlus (ELit n1 t1) (ELit n t0)) (CDeref CHole)).
        inv HTy1.
        inv H2. inv H9.
        exists C.
        exists st.
        exists H.
        { destruct (Z_gt_dec n1 0).
          - (* n1 > 0 *)
            exists (RExpr (EDeref (ELit (n1 + n) (TPtr C (TArray (Num (l0 - n)) (Num (h0 - n)) t))))).
            ctx (EDeref (ELit (n1 + n) (TPtr C (TArray (Num (l0 - n)) (Num (h0 - n)) t))))
                (in_hole (ELit (n1 + n) (TPtr C (TArray (Num (l0 - n)) (Num (h0 - n)) t))) (CDeref CHole)).
            rewrite HCtx.
            rewrite HCtx0.
            inv HTy2.
            eapply RSExp; eauto.
            assert ((TPtr C (TArray (Num (l0 - n)) (Num (h0 - n)) t)) 
             = sub_tau_bound (TPtr C (TArray (Num l0) (Num h0) t)) n).
            unfold sub_tau_bound,sub_bound. reflexivity.
            rewrite H2.
            apply SAddArr. assumption.
            unfold is_array_ptr. easy.
          - (* n1 <= 0 *)
            exists RNull.
            subst. 
            rewrite HCtx. 
            inv HTy2.
            eapply RSHaltNull; eauto.
            apply SAddArrNull. lia.
            unfold is_array_ptr. easy.
        }
      * left.
        ctx (EDeref (EPlus (ELit n1 t1) e2)) (in_hole e2 (CDeref (CPlusR n1 t1 CHole)))...
      * right.
        ctx (EDeref (EPlus (ELit n1 t1) e2)) (in_hole e2 (CDeref (CPlusR n1 t1 CHole))).
        destruct HUnchk2...
    + left.
      ctx (EDeref (EPlus e1 e2)) (in_hole e1 (CDeref (CPlusL CHole e2)))...
    + right.
      ctx (EDeref (EPlus e1 e2)) (in_hole e1 (CDeref (CPlusL CHole e2))).
      destruct HUnchk1...

  - (* Index for ntarray tau. *)
    right.
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.
    (* Leo: This is becoming hacky *)
    inv Hewf.
    inv H1.
    (*
    assert (exists l0 h0, t = (TPtr C (TArray l0 h0 t'))).
    {
      inv HSubType. exists l; exists h; eauto.
      exists l0; exists h0; eauto.
    }
    destruct H0 as [l0 [h0 H0]].
    rewrite H0 in *.
    clear HSubType H0 l h.
    remember l0 as l. remember h0 as h.
    clear Heql Heqh l0 h0 t.
    remember t' as t. clear Heqt t'.
    *)
    specialize (IH1 H3 eq_refl).
    specialize (IH2 H4 eq_refl).
    destruct IH1 as [ HVal1 | [ HRed1 | HUnchk1 ] ]; eauto.
    + inv HVal1 as [ n1 t1 ].
      destruct IH2 as [ HVal2 | [ HRed2 | HUnchk2 ] ]; eauto.
      * left.
        inv HVal2.
        ctx (EDeref (EPlus (ELit n1 t1) (ELit n t0))) (in_hole (EPlus (ELit n1 t1) (ELit n t0)) (CDeref CHole)).
        inv HTy1.
        inv H2. inv H9.
        exists C.
        exists st.
        exists H.
        { destruct (Z_gt_dec n1 0).
          - (* n1 > 0 *)
            exists (RExpr (EDeref (ELit (n1 + n) (TPtr C (TNTArray (Num (l0 - n)) (Num (h0 - n)) t))))).
            ctx (EDeref (ELit (n1 + n) (TPtr C (TNTArray (Num (l0 - n)) (Num (h0 - n)) t))))
                (in_hole (ELit (n1 + n) (TPtr C (TNTArray (Num (l0 - n)) (Num (h0 - n)) t))) (CDeref CHole)).
            rewrite HCtx.
            rewrite HCtx0.
            inv HTy2.
            eapply RSExp; eauto.
            assert ((TPtr C (TNTArray (Num (l0 - n)) (Num (h0 - n)) t)) 
             = sub_tau_bound (TPtr C (TNTArray (Num l0) (Num h0) t)) n).
            unfold sub_tau_bound,sub_bound. reflexivity.
            rewrite H2.
            apply SAddArr. assumption.
            unfold is_array_ptr. easy.
          - (* n1 <= 0 *)
            exists RNull.
            subst. 
            rewrite HCtx. 
            inv HTy2.
            eapply RSHaltNull; eauto.
            apply SAddArrNull. lia.
            unfold is_array_ptr. easy.
        }
      * left.
        ctx (EDeref (EPlus (ELit n1 t1) e2)) (in_hole e2 (CDeref (CPlusR n1 t1 CHole)))...
      * right.
        ctx (EDeref (EPlus (ELit n1 t1) e2)) (in_hole e2 (CDeref (CPlusR n1 t1 CHole))).
        destruct HUnchk2...
    + left.
      ctx (EDeref (EPlus e1 e2)) (in_hole e1 (CDeref (CPlusL CHole e2)))...
    + right.
      ctx (EDeref (EPlus e1 e2)) (in_hole e1 (CDeref (CPlusL CHole e2))).
      destruct HUnchk1...

  - (* Assign1 rule. This isn't a value, so it must reduce *)
    right.

    (* If m' is unchecked, then we are typing mode is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.

    (* Invoke IH on e1 *)
    inv Hewf.
    apply (IH1) in H2. 2 : { easy. }
    destruct H2 as [ HVal1 | [ HRed1 | [| HUnchk1 ] ] ]; idtac...
    + (* Case: e1 is a value *)
      inv HVal1 as [ n1' t1' WTt1' Ht1' ].
      (* Invoke IH on e2 *)
      apply (IH2) in H3. 2 : { easy. }
      inv H3 as [ HVal2 | [ HRed2 | [| HUnchk2 ] ] ]; idtac...
      * (* Case: e2 is a value, so we can take a step *)
        inv HVal2 as [n2' t2' Wtt2' Ht2' ].
        {
            inv HTy1; eauto.
            match goal with
            | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
            end... 
            + left.
              eapply step_implies_reduces.
              eapply SAssignNull; eauto. lia.
              apply simple_tau_means_eval_same. assumption.
            + solve_empty_scope.
            + left.
              inv HTy2. inv H4.
              unfold allocate_meta in H5.
              destruct t; inv H5; simpl in *. 
              ++   destruct (H9 0) as [x [xT [HNth [HMap HWT]]]]; simpl in*;
                try (zify; lia);
                try rewrite Z.add_0_r in *;
                eauto; 
              try (eapply step_implies_reduces;
                   eapply SAssign; eauto);
              try (eexists; eauto);
              intros; try congruence...
              apply simple_tau_means_cast_same. easy. inv H2. inv H2. inv H2. inv H2.
              apply get_root_word. constructor.
              ++ destruct (H9 0) as [x [xT [HNth [HMap HWT]]]]; simpl in*;
                try (zify; lia);
                try rewrite Z.add_0_r in *;
                eauto; 
              try (eapply step_implies_reduces;
                   eapply SAssign; eauto);
              try (eexists; eauto);
              intros; try congruence...
              apply simple_tau_means_cast_same. easy. inv H2. inv H2. inv H2. inv H2. 
              apply get_root_word. constructor.
              ++ inv WT.
              ++ inv WT.
              ++ inv WT.
              ++ inv WT.
              ++ inv H10. inv H11. inv H5.
                 destruct (H9 0) as [x [xT [HNth [HMap HWT]]]]; simpl in*;
                try (zify; lia);
                try rewrite Z.add_0_r in *;
                eauto; 
              try (eapply step_implies_reduces;
                   eapply SAssign; eauto);
              try (eexists; eauto);
              intros; try congruence...
              rewrite replicate_gt_eq. lia. lia.
              inv H3.
              apply simple_tau_means_cast_same. constructor. easy.
              1-4:inv H2; inv WT.
              apply get_root_word. easy. inv H3. 
              ++ inv H10. inv H11. inv H5.
                 destruct (H9 0) as [x [xT [HNth [HMap HWT]]]]; simpl in*;
                try (zify; lia);
                try rewrite Z.add_0_r in *;
                eauto; 
              try (eapply step_implies_reduces;
                   eapply SAssign; eauto);
              try (eexists; eauto);
              intros; try congruence...
              rewrite replicate_gt_eq. lia. lia.
              inv H3.
              apply simple_tau_means_cast_same. constructor. easy.
              1-4:inv H2; inv WT.
              apply get_root_word. easy. inv H3. 
              ++ inv WT.
              ++ inv WT.
              ++ inv WT.
              ++ inv H5. apply StructDef.find_1 in H8 as eq1.  rewrite eq1 in *.
                 inv H4.
              assert (forall t, subtype_stack D Q st t TInt -> t = TInt).
              {
                intros. inv H2. inv H4. easy. inv H5. inv H6. easy. inv H6. inv H5. easy.
              }
              apply H2 in HSub. clear H2. subst.
               assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) fs))) > 0). 
              {
                 eapply struct_subtype_non_empty; eauto.
                 apply (SubTyStructArrayField_1 D Q T fs m).
                 assumption.
                 assumption.
              }
                 destruct (H9 0) as [x [xT [HNth [HMap HWT]]]]; simpl in*;
                try (zify; lia);
                try rewrite Z.add_0_r in *;
                eauto; 
              try (eapply step_implies_reduces;
                   eapply SAssign; eauto);
              try (eexists; eauto);
              intros; try congruence...
              apply simple_tau_means_cast_same. constructor. constructor.
              1-4:inv H4. 
              apply get_root_word. easy.
              ++ inv WT.
         }
      * unfold reduces in HRed2. destruct HRed2 as [ H' [ ? [ ? [ r HRed2 ] ] ] ].
        inv HRed2; ctx (EAssign (ELit n1' t1') (in_hole e E)) (in_hole e (CAssignR n1' t1' E))...
      * destruct HUnchk2 as [ e' [ E [ ] ] ]; subst.
        ctx (EAssign (ELit n1' t1') (in_hole e' E)) (in_hole e' (CAssignR n1' t1' E))...
    + (* Case: e1 reduces *)
      destruct HRed1 as [ H' [ ? [? [ r HRed1 ] ] ] ].
      inv HRed1; ctx (EAssign (in_hole e E) e2) (in_hole e (CAssignL E e2))...
    + destruct HUnchk1 as [ e' [ E [ ] ] ]; subst.
      ctx (EAssign (in_hole e' E) e2) (in_hole e' (CAssignL E e2))...
  - (* Assign2 rule for array. *)
    right.

    (* If m' is unchecked, then we are typing mode is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.

    (* Invoke IH on e1 *)
    inv Hewf.
    apply (IH1) in H2. 2 : { easy. }
    destruct H2 as [ HVal1 | [ HRed1 | [| HUnchk1 ] ] ]; idtac...
    + (* Case: e1 is a value *)
      inv HVal1 as [ n1' t1' WTt1' Ht1' ].
      (* Invoke IH on e2 *)
      apply (IH2) in H3.
      inv H3 as [ HVal2 | [ HRed2 | [| HUnchk2 ] ] ]; idtac...
      * (* Case: e2 is a value, so we can take a step *)
        inv HVal2 as [n2' t2' Wtt2' Ht2' ].
        {
            inv HTy1; eauto.
            assert (Hsim := H0). inv H0. inv H3.
            match goal with
            | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
            end...
            + left.

              destruct (Z_gt_dec h0 0).
              * (* h > 0 - Assign  *)
                destruct (Z_gt_dec l0 0).
                { (* l > 0 *)
                eapply step_implies_reduces.
                eapply SAssignLowOOB; eauto... inv HTy2.
                unfold eval_tau_bound,eval_bound. reflexivity.
                unfold get_low_ptr. easy.
                }
                { (* l <= 0 *)
                  eapply step_implies_reduces.
                  eapply SAssignNull; eauto. lia.
                  unfold eval_tau_bound,eval_bound. eauto. 
                }
              * (* h <= 0 *)
                eapply step_implies_reduces.
                eapply SAssignHighOOB; eauto... 
                unfold eval_tau_bound, eval_bound. reflexivity.
                unfold get_high_ptr. easy.
            + solve_empty_scope.
            + left.

              destruct (Z_gt_dec n1' 0).
                ++ destruct (Z_gt_dec h0 0).
                    * (* h > 0 - Assign  *)
                      destruct (Z_gt_dec l0 0).
                      { (* l > 0 *)
                      eapply step_implies_reduces.
                      eapply SAssignLowOOB; eauto... 
                      unfold eval_tau_bound, eval_bound. reflexivity.
                      unfold get_low_ptr. easy. }
                      { (* l <= 0 *)
                        inv H4. inv H5.
                        destruct (H9 0).
                        rewrite replicate_gt_eq. lia. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TArray (Num l0) (Num h0) t) st) in H3.
                        constructor. apply H3.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                        inv H12. inv H13.
                        inv WT. inv H5.
                        destruct (H9 0). simpl in *. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TPtr C (TArray (Num l0) (Num h0) TInt)) st) in Hsim.
                        apply Hsim.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                        inv H5.
                        destruct (H9 0). simpl in *. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same
                                   (TPtr C (TArray (Num l0) (Num h0) (TPtr m0 w))) st) in Hsim.
                        apply Hsim.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                        inv H8. inv H8. inv H8. inv H12.
                        inv H5.
                        destruct (H9 0).
                        rewrite replicate_gt_eq. lia. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TPtr C (TArray (Num l0) (Num h0) t)) st) in Hsim.
                        apply Hsim.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                        inv H3. inv H8. inv H12. inv H5.
                        destruct (H9 0).
                        rewrite replicate_gt_eq. lia. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TPtr C (TArray (Num l0) (Num h0) t)) st) in Hsim.
                        apply Hsim.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                        inv H3. inv H13. inv H14.
                        inv H5.
                        apply StructDef.find_1 in H11. rewrite H11 in *.
                        inv H4.
                        destruct (H9 0).
                        assert ( Z.of_nat (length (map snd (Fields.elements (elt:=tau) fs))) > 0). 
                       {
                             eapply struct_subtype_non_empty; eauto.
                              apply (SubTyStructArrayField_1 D Q T fs m).
                             apply StructDef.find_2. easy. easy.
                             apply StructDef.find_2. easy. 
                       } lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same
                                   (TPtr C (TArray (Num l0) (Num h0) TInt)) st) in Hsim.
                        apply Hsim.
                        intros. inv H0. split. lia. lia.
                        intros. inv H0.
                        apply get_root_array.
                      }
                    * (* h <= 0 *)
                      eapply step_implies_reduces.
                      eapply SAssignHighOOB; eauto...
                      unfold eval_tau_bound,eval_bound. reflexivity. 
                      unfold get_high_ptr. easy.
              ++ destruct (Z_gt_dec h0 0).
                 * (* h > 0 - Assign  *)
                   destruct (Z_gt_dec l0 0).
                   { (* l > 0 *)
                   eapply step_implies_reduces.
                   eapply SAssignLowOOB; eauto...
                   unfold eval_tau_bound,eval_bound. reflexivity. 
                   unfold get_low_ptr. easy. }
                   { (* l <= 0 *)
                     eapply step_implies_reduces.   
                     eapply SAssignNull; eauto.
                     unfold eval_tau_bound,eval_bound. eauto.
                   }
                 * (* h <= 0 *)
                   eapply step_implies_reduces.
                   eapply SAssignHighOOB; eauto... inv HTy2.
                   unfold eval_tau_bound,eval_bound. reflexivity.
                   unfold get_high_ptr. easy.
         }
      * unfold reduces in HRed2. destruct HRed2 as [ H' [ ? [ ? [ r HRed2 ] ] ] ].
        inv HRed2; ctx (EAssign (ELit n1' t1') (in_hole e E)) (in_hole e (CAssignR n1' t1' E))...
      * destruct HUnchk2 as [ e' [ E [ ] ] ]; subst.
        ctx (EAssign (ELit n1' t1') (in_hole e' E)) (in_hole e' (CAssignR n1' t1' E))...
      * easy.
    + (* Case: e1 reduces *)
      destruct HRed1 as [ H' [ ? [? [ r HRed1 ] ] ] ].
      inv HRed1; ctx (EAssign (in_hole e E) e2) (in_hole e (CAssignL E e2))...
    + destruct HUnchk1 as [ e' [ E [ ] ] ]; subst.
      ctx (EAssign (in_hole e' E) e2) (in_hole e' (CAssignL E e2))...

  - (* Assign3 rule for nt-array. *)
    right.

    (* If m' is unchecked, then we are typing mode is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.

    (* Invoke IH on e1 *)
    inv Hewf.
    apply (IH1) in H2. 2 : { easy. }
    destruct H2 as [ HVal1 | [ HRed1 | [| HUnchk1 ] ] ]; idtac...
    + (* Case: e1 is a value *)
      inv HVal1 as [ n1' t1' WTt1' Ht1' ].
      (* Invoke IH on e2 *)
      apply (IH2) in H3. 2 : { easy. }
      inv H3 as [ HVal2 | [ HRed2 | [| HUnchk2 ] ] ]; idtac...
      * (* Case: e2 is a value, so we can take a step *)
        inv HVal2 as [n2' t2' Wtt2' Ht2' ].
        {
            inv HTy1; eauto.
            assert (Hsim := H0). inv H0. inv H3.
            match goal with
            | [ H : well_typed_lit _ _ _ _ _ _ |- _ ] => inv H
            end...
            + left.

              destruct (Z_gt_dec h0 0).
              * (* h > 0 - Assign  *)
                destruct (Z_gt_dec l0 0).
                { (* l > 0 *)
                eapply step_implies_reduces.
                eapply SAssignLowOOB; eauto...
                unfold eval_tau_bound,eval_bound. reflexivity. 
                unfold get_low_ptr. easy. }
                { (* l <= 0 *)
                  eapply step_implies_reduces.
                  eapply SAssignNull; eauto. lia.
                  unfold eval_tau_bound,eval_bound. eauto. 
                }
              * (* h <= 0 *)
                eapply step_implies_reduces.
                eapply SAssignHighOOB; eauto...                
                unfold eval_tau_bound,eval_bound. reflexivity. 
                unfold get_high_ptr. easy. 
            + solve_empty_scope.
            + left.

              destruct (Z_gt_dec n1' 0).
                ++ destruct (Z_gt_dec h0 0).
                    * (* h > 0 - Assign  *)
                      destruct (Z_gt_dec l0 0).
                      { (* l > 0 *)
                      eapply step_implies_reduces.
                      eapply SAssignLowOOB; eauto...                
                      unfold eval_tau_bound,eval_bound. reflexivity. 
                      unfold get_low_ptr. easy. }
                      { (* l <= 0 *)
                        inv H4. inv H5.
                        destruct (H9 0).
                        rewrite replicate_gt_eq. lia. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TNTArray (Num l0) (Num h0) t) st) in H3.
                        constructor. apply H3.
                        intros. inv H0.
                        intros. inv H0. split. lia. lia.
                        apply get_root_ntarray.
                        inv H8. inv H8. inv H8. inv H12.
                        inv H5.
                        destruct (H9 0).
                        rewrite replicate_gt_eq. lia. lia.
                        destruct H0 as [ta [X1 [X2 X3]]].
                        eapply step_implies_reduces.
                        eapply (SAssign); eauto.
                        rewrite Z.add_0_r in X2. apply X2.
                        apply (simple_tau_means_cast_same (TPtr C (TNTArray (Num l0) (Num h0) t)) st) in Hsim.
                        apply Hsim.
                        intros. inv H0.
                        intros. inv H0. split. lia. lia.
                        apply get_root_ntarray.
                        inv H3.
                      }
                    * (* h <= 0 *)
                      eapply step_implies_reduces.
                      eapply SAssignHighOOB; eauto...
                      unfold eval_tau_bound,eval_bound. reflexivity.
                      unfold get_high_ptr. easy.
              ++ destruct (Z_gt_dec h0 0).
                 * (* h > 0 - Assign  *)
                   destruct (Z_gt_dec l0 0).
                   { (* l > 0 *)
                   eapply step_implies_reduces.
                   eapply SAssignLowOOB; eauto...
                   unfold eval_tau_bound,eval_bound. reflexivity.
                   unfold get_low_ptr. easy.
                   }
                   { (* l <= 0 *)
                     eapply step_implies_reduces.   
                     eapply SAssignNull; eauto.
                     unfold eval_tau_bound,eval_bound. eauto.
                   }
                 * (* h <= 0 *)
                   eapply step_implies_reduces.
                   eapply SAssignHighOOB; eauto...
                   unfold eval_tau_bound,eval_bound. reflexivity.
                   unfold get_high_ptr. easy.
         }
      * unfold reduces in HRed2. destruct HRed2 as [ H' [ ? [ ? [ r HRed2 ] ] ] ].
        inv HRed2; ctx (EAssign (ELit n1' t1') (in_hole e E)) (in_hole e (CAssignR n1' t1' E))...
      * destruct HUnchk2 as [ e' [ E [ ] ] ]; subst.
        ctx (EAssign (ELit n1' t1') (in_hole e' E)) (in_hole e' (CAssignR n1' t1' E))...
    + (* Case: e1 reduces *)
      destruct HRed1 as [ H' [ ? [? [ r HRed1 ] ] ] ].
      inv HRed1; ctx (EAssign (in_hole e E) e2) (in_hole e (CAssignL E e2))...
    + destruct HUnchk1 as [ e' [ E [ ] ] ]; subst.
      ctx (EAssign (in_hole e' E) e2) (in_hole e' (CAssignL E e2))...

  (* T-IndAssign for array pointer. *)
  - (* This isn't a value, so it must reduce *)
    right.

    (* If m' is unchecked, then we are typing mode is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.
    inv Hewf.
    inv H2.
    (*
    assert (exists l0 h0, t = (TPtr C (TArray l0 h0 t'))).
    {
      inv HSubType. exists l; exists h; eauto.
      exists l0; exists h0; eauto.
    }
    destruct H0 as [l0 [h0 H0]].
    rewrite H0 in *.
    clear HSubType H0 l h.
    remember l0 as l. remember h0 as h.
    clear Heql Heqh l0 h0 t.
    remember t' as t. clear Heqt t'.
    *)
    (* Invoke IH on e1 *)
    apply (IH1) in H4. 2 : { easy. }
    destruct H4 as [ HVal1 | [ HRed1 | [| HUnchk1 ] ] ]; idtac...
    + (* Case: e1 is a value *)
      inv HVal1.
      (* Invoke IH on e2 *)
      apply (IH2) in H5. 2 : { easy. }
      destruct H5 as [ HVal2 | [ HRed2 | [| HUnchk2 ] ] ]; idtac...
      * inv HVal2.
        ctx (EAssign (EPlus (ELit n t0) (ELit n0 t1)) e3) 
                  (in_hole (EPlus (ELit n t0) (ELit n0 t1)) (CAssignL CHole e3)).
        inv HTy1.
        inv HTy2.
        assert (Hsim := H2).
        inv Hsim. inv H8.
        assert (simple_tau TInt). constructor.
        {
          apply (IH3) in H3. 2 : { easy. }
          inv H2; inv H7; (eauto 20 with Progress); 
            try solve_empty_scope.
          - destruct H3 as [ HVal3 | [ HRed3 | [| HUnchk3]]]; idtac...
            + inv HVal3.
              inv HTy3.
              left; eauto...
              destruct (Z_gt_dec n 0); subst; rewrite HCtx; do 4 eexists.
              * eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              * eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
            + destruct HRed3 as [H' [? [r HRed3]]].
              destruct (Z_gt_dec n 0).
              rewrite HCtx; left; do 4 eexists.
              eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              rewrite HCtx; left; do 4 eexists.
              eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
            + destruct HUnchk3 as [ e' [ E [ He2 HEUncheckednchk ]]]; subst.
              destruct (Z_gt_dec n 0).
              rewrite HCtx; left; do 4 eexists.
              eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              rewrite HCtx; left; do 4 eexists.
              eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
        }
      * destruct HRed2 as [ H' [ ? [? [ r HRed2 ] ] ] ].
        inv HRed2; ctx (EAssign (EPlus (ELit n t0) (in_hole e E)) e3) (in_hole e (CAssignL (CPlusR n t0 E) e3))...
      * destruct HUnchk2 as [ e' [ E [ He2 HEUncheckednchk ] ] ]; subst.
        ctx (EAssign (EPlus (ELit n t0) (in_hole e' E)) e3) (in_hole e' (CAssignL (CPlusR n t0 E) e3))...
    + destruct HRed1 as [ H' [? [ ? [ r HRed1 ] ] ] ].
      inv HRed1; ctx (EAssign (EPlus (in_hole e E) e2) e3) (in_hole e (CAssignL (CPlusL E e2) e3))...
    + destruct HUnchk1 as [ e' [ E [ He1 HEUncheckednchk ] ] ]; subst.
      ctx (EAssign (EPlus (in_hole e' E) e2) e3) (in_hole e' (CAssignL (CPlusL E e2) e3))...
  (* T-IndAssign for ntarray pointer. *)
  - (* This isn't a value, so it must reduce *)
    right.

    (* If m' is unchecked, then we are typing mode is unchecked *)
    destruct m'; [> | right; eauto 20 with Progress].
    clear HMode.
    inv Hewf. inv H2.
    (*
    assert (exists l0 h0, t = (TPtr C (TArray l0 h0 t'))).
    {
      inv HSubType. exists l; exists h; eauto.
      exists l0; exists h0; eauto.
    }
    destruct H0 as [l0 [h0 H0]].
    rewrite H0 in *.
    clear HSubType H0 l h.
    remember l0 as l. remember h0 as h.
    clear Heql Heqh l0 h0 t.
    remember t' as t. clear Heqt t'.
    *)
    (* Invoke IH on e1 *)
    apply (IH1) in H4. 2 : { easy. }
    destruct H4 as [ HVal1 | [ HRed1 | [| HUnchk1 ] ] ]; idtac...
    + (* Case: e1 is a value *)
      inv HVal1.
      (* Invoke IH on e2 *)
      apply (IH2) in H5. 2 : { easy. }
      destruct H5 as [ HVal2 | [ HRed2 | [| HUnchk2 ] ] ]; idtac...
      * inv HVal2.
        ctx (EAssign (EPlus (ELit n t0) (ELit n0 t1)) e3) 
                  (in_hole (EPlus (ELit n t0) (ELit n0 t1)) (CAssignL CHole e3)).
        inv HTy1.
        inv HTy2.
        assert (Hsim := H2).
        inv Hsim. inv H8.
        assert (simple_tau TInt). constructor.
        {
          apply (IH3) in H3. 2 : { easy. }
          inv H2; inv H7; (eauto 20 with Progress); 
            try solve_empty_scope.
          - destruct H3 as [ HVal3 | [ HRed3 | [| HUnchk3]]]; idtac...
            + inv HVal3.
              inv HTy3.
              left; eauto...
              destruct (Z_gt_dec n 0); subst; rewrite HCtx; do 4 eexists.
              * eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              * eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
            + destruct HRed3 as [H' [? [r HRed3]]].
              destruct (Z_gt_dec n 0).
              rewrite HCtx; left; do 4 eexists.
              eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              rewrite HCtx; left; do 4 eexists.
              eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
            + destruct HUnchk3 as [ e' [ E [ He2 HEUncheckednchk ]]]; subst.
              destruct (Z_gt_dec n 0).
              rewrite HCtx; left; do 4 eexists.
              eapply RSExp... eapply SAddArr. easy.
                unfold is_array_ptr. easy.
              rewrite HCtx; left; do 4 eexists.
              eapply RSHaltNull... eapply SAddArrNull. lia.
                unfold is_array_ptr. easy.
        }
      * destruct HRed2 as [ H' [ ? [? [ r HRed2 ] ] ] ].
        inv HRed2; ctx (EAssign (EPlus (ELit n t0) (in_hole e E)) e3) (in_hole e (CAssignL (CPlusR n t0 E) e3))...
      * destruct HUnchk2 as [ e' [ E [ He2 HEUncheckednchk ] ] ]; subst.
        ctx (EAssign (EPlus (ELit n t0) (in_hole e' E)) e3) (in_hole e' (CAssignL (CPlusR n t0 E) e3))...
    + destruct HRed1 as [ H' [? [ ? [ r HRed1 ] ] ] ].
      inv HRed1; ctx (EAssign (EPlus (in_hole e E) e2) e3) (in_hole e (CAssignL (CPlusL E e2) e3))...
    + destruct HUnchk1 as [ e' [ E [ He1 HEUncheckednchk ] ] ]; subst.
      ctx (EAssign (EPlus (in_hole e' E) e2) e3) (in_hole e' (CAssignL (CPlusL E e2) e3))...
  (* Istatement. It is impossible due to empty env. *)
   - inversion HEnv.
   - inversion HEnv.
   - right.
    inv Hewf.
    apply (IH1) in H3. 2:{ easy. }
    (* Invoke the IH on `e1` *)
    destruct H3 as [ HVal1 | [ HRed1 | HUnchk1 ] ].
    (* Case: `e1` is a value *)
    + (* We don't know if we can take a step yet, since `e2` might be unchecked. *)
      inv HVal1 as [ n1 t1 ].
      (* Invoke the IH on `e2` *)
       left.
       destruct n1 eqn:eq1.
       eapply (step_implies_reduces D).
       eapply SIfFalse;eauto.
       eapply (step_implies_reduces D).
       eapply SIfTrue;eauto. lia.
       eapply (step_implies_reduces D).
       eapply SIfTrue;eauto. lia.
    (* Case: `e1` reduces *)
    + (* We can take a step by reducing `e1` *)
      left.
      ctx (EIf e1 e2 e3) (in_hole e1 (CIf CHole e2 e3))...
    (* Case: `e1` is unchecked *)
    + (* `EPlus e1 e2` must be unchecked, since `e1` is *)
      right.
      ctx (EIf e1 e2 e3) (in_hole e1 (CIf CHole e2 e3)).
      destruct HUnchk1...
Qed.
(*
Definition heap_well_typed (D:structdef) (Q:theta) (H:heap) (n:Z) (t:tau) :=
      simple_tau t -> well_typed_lit D Q H empty_scope n t.

Inductive heap_wt_arg (D:structdef) (Q:theta) (H:heap) : expression -> Prop :=
     | HtArgLit : forall n t, heap_well_typed D Q H n t -> heap_wt_arg D Q H (ELit n t)
     | HtArgVar : forall x, heap_wt_arg D Q H (EVar x).

Inductive heap_wt_args (D:structdef) (Q:theta) (H:heap) : list expression -> Prop :=
    heap_wt_empty : heap_wt_args D Q H ([])
  | heap_wt_many : forall e el, heap_wt_arg D Q H e -> heap_wt_args D Q H el -> heap_wt_args D Q H (e::el).

Inductive heap_wt (D:structdef) (Q:theta) (H:heap) : expression -> Prop :=
   | HtLit : forall n t, heap_well_typed D Q H n t -> heap_wt D Q H (ELit n t)
   | HtVar : forall x, heap_wt D Q H (EVar x)
   | HtStrlen : forall x, heap_wt D Q H (EStrlen x)
   | HtCall : forall f el, heap_wt_args D Q H el -> heap_wt D Q H (ECall f el)
   | HtRet : forall x old a e, heap_wt D Q H e -> heap_wt D Q H (ERet x old a e)
   | HtDynCast : forall t e, heap_wt D Q H e -> heap_wt D Q H (EDynCast t e)
   | HtLet : forall x e1 e2, heap_wt D Q H e1 -> heap_wt D Q H e2 -> heap_wt D Q H (ELet x e1 e2)
   | HtMalloc : forall t, heap_wt D Q H (EMalloc t)
   | HtCast : forall t e, heap_wt D Q H e -> heap_wt D Q H (ECast t e)
   | HtPlus : forall e1 e2, heap_wt D Q H e1 -> heap_wt D Q H e2 -> heap_wt D Q H (EPlus e1 e2)
   | HtFieldAddr : forall e f, heap_wt D Q H e -> heap_wt D Q H (EFieldAddr e f)
   | HtDeref : forall e, heap_wt D Q H e -> heap_wt D Q H (EDeref e)
   | HtAssign : forall e1 e2, heap_wt D Q H e1 -> heap_wt D Q H e2 -> heap_wt D Q H (EAssign e1 e2)
   | HtIf : forall x e1 e2, heap_wt D Q H e1 -> heap_wt D Q H e2 -> heap_wt D Q H (EIf x e1 e2)
   | HtUnC : forall e, heap_wt D Q H e -> heap_wt D Q H (EUnchecked e).

*)
Definition is_ptr (t : tau) : Prop :=
    match t with TPtr m x => True 
              | _ => False
    end.

Definition is_nt_ptr (t : tau) : Prop :=
    match t with TPtr m (TNTArray l h t') => True 
              | _ => False
    end.

(* equivalence of tau based on semantic meaning. *)
Inductive tau_eq (S : stack) : tau -> tau -> Prop := 
     | tau_eq_refl: forall t , tau_eq S t t
     | tau_eq_left: forall t1 t2, simple_tau t1 -> cast_tau_bound S t2 t1 -> tau_eq S t2 t1
     | tau_eq_right: forall t1 t2, simple_tau t2 -> cast_tau_bound S t1 t2 -> tau_eq S t1 t2.

(* subtyping relation based on taus. *)
Inductive subtype_stack (D: structdef) (Q:theta) (S:stack) : tau -> tau -> Prop :=
     | subtype_same : forall t t', subtype D Q t t' -> subtype_stack D Q S t t'
     | subtype_left : forall t1 t2 t2', simple_tau t1 -> cast_tau_bound S t2 t2'
            -> subtype D Q t1 t2' -> subtype_stack D Q S t1 t2
     | subtype_right : forall t1 t1' t2, simple_tau t2 -> cast_tau_bound S t1 t1'
            -> subtype D Q t1' t2 -> subtype_stack D Q S t1 t2.

(* The join opeartions. *)
Inductive join_tau (D : structdef) (Q:theta) (S:stack) : tau -> tau -> tau -> Prop :=
   join_tau_front : forall a b, subtype_stack D Q S a b -> join_tau D Q S a b b
  | join_tau_end : forall a b, subtype_stack D Q S b a -> join_tau D Q S a b a.

Definition good_lit (H:heap) (n:Z) (t:tau):=
      match t with TInt => True
               | _ => n <= (Z.of_nat (Heap.cardinal H))
      end.





(*
Inductive gen_env : env -> list (var * tau) -> env -> Prop :=
     | gen_env_empty : forall env, gen_env env [] env
     | gen_env_many : forall x t l env env', gen_env env l env' -> gen_env env ((x,t)::l) (Env.add x t env').


Definition subst_bound_val (x:var) (n:Z) (b:bound) : bound :=
   match b with Num m => Num m
              | Var y m => if (Nat.eqb x y) then Num (n+m) else Var y m
   end.

Fixpoint subst_tau_val (x:var) (n:Z) (b:tau) : tau :=
   match b with TInt => TInt
              | TPtr c t => TPtr c (subst_tau_val x n t)
              | TStruct t => TStruct t
              | TArray l h t => TArray (subst_bound_val x n l) (subst_bound_val x n h) (subst_tau_val x n t)
              | TNTArray l h t => TNTArray (subst_bound_val x n l) (subst_bound_val x n h) (subst_tau_val x n t)
   end.


Definition subst_bound_var (x:var) (n:var) (b:bound) : bound :=
   match b with Num m => Num m
              | Var y m => if (Nat.eqb x y) then (Var n m) else Var y m
   end.

Fixpoint subst_tau_var (x:var) (n:var) (b:tau) : tau :=
   match b with TInt => TInt
              | TPtr c t => TPtr c (subst_tau_var x n t)
              | TStruct t => TStruct t
              | TArray l h t => TArray (subst_bound_var x n l) (subst_bound_var x n h) (subst_tau_var x n t)
              | TNTArray l h t => TNTArray (subst_bound_var x n l) (subst_bound_var x n h) (subst_tau_var x n t)
   end.

Inductive subst_all_arg : var -> expression -> tau -> tau -> Prop :=
   | subt_arg_lit : forall x n t t', subst_all_arg x (ELit n t) t' (subst_tau_val x n t')
   | subt_arg_var : forall x y t', subst_all_arg x (EVar y) t' (subst_tau_var x y t').

Inductive subst_all_args : list (var*tau) -> list expression -> tau -> tau -> Prop :=
   | subt_arg_empty : forall t, subst_all_args [] [] t t
   | subt_arg_many_1 : forall x tvl e el t t' t'', subst_all_arg x e t t' ->
                 subst_all_args tvl el t' t'' -> subst_all_args ((x,TInt)::tvl) (e::el) t t''
   | subt_arg_many_2 : forall x tvl e el t t' ta,
         ta <> TInt -> subst_all_args tvl el t t' -> subst_all_args ((x,ta)::tvl) (e::el) t t'.
*)
(*
Inductive to_ext_bound : var -> bound -> bound -> Prop :=
   | to_ext_num : forall x n, to_ext_bound x (Num n) (Num n)
   | to_ext_var_1 : forall x n, to_ext_bound x (Var x n) (ExVar x n)
   | to_ext_var_2 : forall x y n, x <> y -> to_ext_bound x (Var y n) (Var y n)
   | to_ext_exvar : forall x y n, to_ext_bound x (ExVar y n) (ExVar y n).

Inductive to_ext_tau : var -> tau -> tau -> Prop :=
   | to_ext_nat : forall x, to_ext_tau x TInt TInt
   | to_ext_ptr : forall x c t t',  to_ext_tau x t t' -> to_ext_tau x (TPtr c t) (TPtr c t')
   | to_ext_struct : forall x t, to_ext_tau x (TStruct t) (TStruct t)
   | to_ext_array : forall x l h t l' h' t', to_ext_bound x l l' -> to_ext_bound x h h' ->
                      to_ext_tau x t t' -> to_ext_tau x (TArray l h t) (TArray l' h' t')
    | to_ext_ntarray : forall x l h t l' h' t', to_ext_bound x l l' -> to_ext_bound x h h' ->
                      to_ext_tau x t t' -> to_ext_tau x (TNTArray l h t) (TNTArray l' h' t')
*)

Fixpoint eq_nat (s:stack) (e:expression) :=
  match e with (ELit n TInt) => Some n
             | EVar x => match Stack.find x s with None => None | Some (n,t) => Some n end
             | EPlus e1 e2 => 
               (match eq_nat s e1 with Some n1 => 
                   match eq_nat s e2 with Some n2 => Some (n1 + n2)
                       | _ => None
                   end
                  | _ => None
                end)
              | _ => None
    end.

Definition NTHitVal (t:tau) : Prop :=
   match t with | (TPtr m (TNTArray l (Num 0) t)) => True
                | _ => False
   end.

Definition add_nt_one_env (s : env) (x:var) : env :=
   match Env.find x s with | Some (TPtr m (TNTArray l (Num h) t)) 
                         => Env.add x (TPtr m (TNTArray l (Num (h+1)) t)) s
                              (* This following case will never happen since the tau in a stack is always evaluated. *)
                             | _ => s
   end.

(*

Inductive to_ext_bound : var -> bound -> bound -> Prop :=
   | to_ext_num : forall x n, to_ext_bound x (Num n) (Num n)
   | to_ext_var_1 : forall x n, to_ext_bound x (Var x n) (ExVar x n)
   | to_ext_var_2 : forall x y n, x <> y -> to_ext_bound x (Var y n) (Var y n)
   | to_ext_exvar : forall x y n, to_ext_bound x (ExVar y n) (ExVar y n).

Inductive to_ext_tau : var -> tau -> tau -> Prop :=
   | to_ext_nat : forall x, to_ext_tau x TInt TInt
   | to_ext_ptr : forall x c t t',  to_ext_tau x t t' -> to_ext_tau x (TPtr c t) (TPtr c t')
   | to_ext_struct : forall x t, to_ext_tau x (TStruct t) (TStruct t)
   | to_ext_array : forall x l h t l' h' t', to_ext_bound x l l' -> to_ext_bound x h h' ->
                      to_ext_tau x t t' -> to_ext_tau x (TArray l h t) (TArray l' h' t')
    | to_ext_ntarray : forall x l h t l' h' t', to_ext_bound x l l' -> to_ext_bound x h h' ->
                      to_ext_tau x t t' -> to_ext_tau x (TNTArray l h t) (TNTArray l' h' t')
   | to_ext_ext_1 : forall x t, to_ext_tau x (TExt x t) (TExt x t)
   | to_ext_ext_2 : forall x y t t', x <> y -> to_ext_tau x t t' -> to_ext_tau x (TExt x t) (TExt x t').
*)
Definition get_tvar_bound (b:bound) : list var :=
     match b with Num n => [] | Var x n => [x]  end.

Fixpoint get_tvars (t:tau) : (list var) :=
   match t with TInt => []
             | TPtr c t => get_tvars t
             | TStruct t => []
             | TArray l h t => get_tvar_bound l ++ get_tvar_bound h ++ get_tvars t
             | TNTArray l h t => get_tvar_bound l ++ get_tvar_bound h ++ get_tvars t
   end.

(*
Inductive vars_to_ext : list var -> tau -> tau -> Prop :=
    vars_to_ext_empty : forall t, vars_to_ext [] t t
  | vars_to_ext_many : forall x l t t' t'', to_ext_tau x t t' 
             -> vars_to_ext l (TExt x t') t'' -> vars_to_ext (x::l) t t''.
*)

(*
Inductive well_bound_args {A:Type}: list (var * tau) -> list (var * A) -> tau -> Prop := 
    well_bound_args_empty : forall l t, well_bound_vars_type l t -> well_bound_args [] l t
  | well_bound_args_many : forall x t1 tvl l t, well_bound_vars_type l t1
                           -> well_bound_args tvl l t -> well_bound_args ((x,t1)::tvl) l t.

Inductive well_arg_bound_in {A:Type}: list (var * A) -> expression -> Prop :=
   | well_arg_bound_in_lit : forall s v t, well_bound_vars_type s t -> well_arg_bound_in s (ELit v t)
   | well_arg_bound_in_var : forall s x, (exists a, In (x,a) s) -> well_arg_bound_in s (EVar x).

Inductive well_args_bound_in {A:Type}: list (var * A) -> list expression -> Prop :=
   | well_args_bound_empty : forall l, well_args_bound_in l []
   | well_args_bound_many : forall l x xl, well_arg_bound_in l x -> well_args_bound_in l xl -> well_args_bound_in l (x::xl).

Inductive well_expr_bound_in {A:Type}: list (var * A) -> expression -> Prop :=
   | well_expr_bound_in_lit : forall s v t, well_bound_vars_type s t -> well_expr_bound_in s (ELit v t)
   | well_expr_bound_in_var : forall s x, (exists a, In (x,a) s) -> well_expr_bound_in s (EVar x)
   | well_expr_bound_in_str : forall s x,(exists a, In (x,a) s) -> well_expr_bound_in s (EStrlen x)
   | well_expr_bound_in_call : forall s x el, well_args_bound_in s el ->  well_expr_bound_in s (ECall x el)
   | well_expr_bound_in_let : forall s x e1 e2, well_expr_bound_in s e1 
           -> well_expr_bound_in s e2 -> well_expr_bound_in s (ELet x e1 e2)
   | well_expr_bound_in_malloc : forall s t, list_tau_bound_in s t -> well_expr_bound_in s (EMalloc t)
   | well_expr_bound_in_cast : forall s t e, list_tau_bound_in s t ->
                    well_expr_bound_in s e -> well_expr_bound_in s (ECast t e)
   | well_expr_bound_in_dyncast : forall s t e, list_tau_bound_in s t ->
                    well_expr_bound_in s e -> well_expr_bound_in s (EDynCast t e)
   | well_expr_bound_in_plus : forall s e1 e2,  well_expr_bound_in s e1 ->
                 well_expr_bound_in s e2 -> well_expr_bound_in s (EPlus e1 e2)
   | well_expr_bound_in_field : forall s e1 f,  well_expr_bound_in s e1 ->
                well_expr_bound_in s (EFieldAddr e1 f)
   | well_expr_bound_in_deref : forall s e,  well_expr_bound_in s e ->
                well_expr_bound_in s (EDeref e)
   | well_expr_bound_in_assign : forall s e1 e2,  well_expr_bound_in s e1 ->
                 well_expr_bound_in s e2 -> well_expr_bound_in s (EAssign e1 e2)
   | well_expr_bound_in_if : forall s x e1 e2, In x s -> well_expr_bound_in s e1 ->
                 well_expr_bound_in s e2 -> well_expr_bound_in s (EIf x e1 e2)
   | well_expr_bound_in_unchecked : forall s e,  well_expr_bound_in s e ->
                well_expr_bound_in s (EUnchecked e).
*)

Fixpoint get_nat_vars (l : list (var * tau)) : list var :=
   match l with [] => []
            | (x,TInt)::xl => x::(get_nat_vars xl)
            | (x,t)::xl => (get_nat_vars xl)
   end.





Definition sub_domain (env: env) (S:stack) := forall x, Env.In x env -> Stack.In x S.


Local Close Scope Z_scope.

Local Open Scope nat_scope.

Hint Constructors well_typed.

(*Hint Constructors ty_ssa.*)


Lemma ptr_subtype_equiv : forall D Q m w t,
subtype D Q w (TPtr m t) ->
exists t', w = (TPtr m t').
Proof.
  intros. remember (TPtr m t) as p. generalize dependent t. induction H.
  - intros. exists t0. rewrite Heqp. reflexivity.
  - intros. inv Heqp. exists t. easy.
  - intros. inv Heqp. exists (TArray l h t0). easy.
  - intros. inv Heqp. exists (TNTArray l h t0). easy.
  - intros. inv Heqp. exists (TArray l h t). easy.
  - intros. inv Heqp. exists (TNTArray l h t). easy.
  - intros. inv Heqp. exists (TNTArray l h t). easy.
  - intros. exists (TStruct T).
    assert (m0 = m). {
      inv Heqp. reflexivity. 
    }
    rewrite H1. reflexivity.
  - intros. inv Heqp. exists (TStruct T).
    reflexivity.
Qed.

(* this might be an issue if we want to make checked pointers
a subtype of unchecked pointers. This will need to
be changed to generalize m*)
Lemma ptr_subtype_equiv' : forall D Q m w t,
subtype D Q (TPtr m t) w ->
exists t', w = (TPtr m t').
Proof.
 intros. remember (TPtr m t) as p. generalize dependent t. induction H.
  - intros. exists t0. rewrite Heqp. reflexivity.
  - intros. inv Heqp. exists (TArray l h t0). easy.
  - intros. inv Heqp. exists t. easy.
  - intros. inv Heqp. exists t. easy.
  - intros. exists (TArray l' h' t).
    assert (m0 = m). {
      inv Heqp. reflexivity. 
    }
    rewrite H1. reflexivity.
  - intros. inv Heqp. exists (TArray l' h' t). easy.
  - intros. exists (TNTArray l' h' t).
    assert (m0 = m). {
      inv Heqp. reflexivity. 
    }
    rewrite H1. reflexivity.
  - intros. exists TInt.
    assert (m0 = m). {
      inv Heqp. reflexivity. 
    }
    rewrite H1. reflexivity.
  - intros. exists (TArray l h TInt).
    assert (m0 = m). {
      inv Heqp. reflexivity. 
    }
    rewrite H3. reflexivity.
Qed.

Lemma nat_subtype : forall D Q t,
subtype D Q TInt t ->
t = TInt.
Proof.
  intros. remember TInt as t'. induction H; eauto.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
  - exfalso. inv Heqt'.
Qed.

(** ** Metatheory *)

(** *** Automation *)

(* TODO: write a function decompose : expr -> (context * expr) *)




Definition heap_consistent { D : structdef } {Q:theta} (H' : heap) (H : heap) : Prop :=
  forall n t,
    @well_typed_lit D Q H empty_scope n t->
    @well_typed_lit D Q H' empty_scope n t.

Hint Unfold heap_consistent.


(** *** Lemmas *)

(* ... for Progress *)

Create HintDb Progress.




Open Scope Z.
Lemma wf_implies_allocate_meta :
  forall (D : structdef) (w : tau),
    (forall l h t, w = TArray (Num l) (Num h) t -> l = 0 /\ h > 0) ->
    (forall l h t, w = TNTArray (Num l) (Num h) t -> l = 0 /\ h > 0) ->
    simple_tau w ->
    tau_wf D w -> exists b allocs, allocate_meta D w = Some (b, allocs).
Proof.
  intros D w HL1 HL2 HS HT.
  destruct w; simpl in *; eauto.
  - inv HT. destruct H0.
    apply StructDef.find_1 in H.
    rewrite -> H.
    eauto.
  - inv HS. eauto.
  - inv HS. eauto.
Qed.

Lemma wf_implies_allocate :
  forall (D : structdef) (w : tau) (H : heap),
    (forall l h t, w = TArray (Num l) (Num h) t -> l = 0 /\ h > 0) ->
    (forall l h t, w = TNTArray (Num l) (Num h) t -> l = 0 /\ h > 0) ->
    simple_tau w ->
    tau_wf D w -> exists n H', allocate D H w = Some (n, H').
Proof.
  intros D w H HL1 HL2 HS HT.
  eapply wf_implies_allocate_meta in HT; eauto.
  destruct HT as [l [ts HT]]. 
  unfold allocate. unfold allocate_meta in *.
  rewrite HT.
  edestruct (fold_left
               (fun (acc : Z * heap) (t : tau) =>
                  let (sizeAcc, heapAcc) := acc in
                  (sizeAcc + 1, Heap.add (sizeAcc + 1) (0, t) heapAcc)) ts
               ((Z.of_nat (Heap.cardinal H)), H)) as (z, h).

  destruct w eqn:Hw; inv HT; simpl in *; eauto.

  - destruct (StructDef.find s D) eqn:HFind; inv H1; eauto.
  - inv HS.
    edestruct HL1; eauto. 
    destruct l. subst; eauto.
    rewrite H0 in H1.
    assert (0 < Z.pos p).
    easy. inversion H1.
    assert (Z.neg p < 0).
    easy. rewrite H0 in H1. inversion H1.
  - inv HS.
    edestruct HL2; eauto. 
    destruct l. subst; eauto.
    rewrite H0 in H1.
    assert (0 < Z.pos p).
    easy. inversion H1.
    assert (Z.neg p < 0).
    easy. rewrite H0 in H1. inversion H1.
Qed.


Definition unchecked (m : mode) (e : expression) : Prop :=
  m = U \/ exists e' E, e = in_hole e' E /\ mode_of(E) = U.

Hint Unfold unchecked.

Ltac solve_empty_scope :=
  match goal with
  | [ H : set_In _ empty_scope |- _ ] => inversion H
  | _ => idtac "No empty scope found"
  end.


Require Import Coq.FSets.FMapList.
Require Import Coq.FSets.FMapFacts.

Module FieldFacts := WFacts_fun Fields.E Fields.
Module StructDefFacts := WFacts_fun StructDef.E StructDef.
Module HeapFacts := WFacts_fun Heap.E Heap.

(* This really should be part of the library, or at least easily provable... *)
Module HeapProp := WProperties_fun Heap.E Heap.
Lemma cardinal_plus_one :
  forall (H : heap) n v, ~ Heap.In n H ->
                         (Z.of_nat(Heap.cardinal (Heap.add n v H)) = Z.of_nat(Heap.cardinal H) + 1).
Proof.
  intros H n v NotIn.
  pose proof HeapProp.cardinal_2 as Fact.
  specialize (Fact _ H (Heap.add n v H) n v NotIn).
  assert (Hyp: HeapProp.Add n v H (Heap.add n v H)).
  {
    intros y.
    auto.
  } 
  specialize (Fact Hyp).
  lia.
Qed.

(* This should be part of the stupid map library. *)
(* Changed to Z to push final proof DP*)
Lemma heap_add_in_cardinal : forall n v H,
  Heap.In n H -> 
  Heap.cardinal (elt:=Z * tau) (Heap.add n v H) =
  Heap.cardinal (elt:=Z * tau) H.
Proof.
  intros.
  remember (Heap.cardinal (elt:=Z * tau) H) as m.
  destruct m.
  symmetry in Heqm.
  apply HeapProp.cardinal_Empty in Heqm.
Admitted.

Lemma replicate_length : forall (n : nat) (T : tau),
(length (replicate n T)) = n.
Proof.
  intros n T. induction n.
    -simpl. reflexivity.
    -simpl. rewrite IHn. reflexivity.
Qed.

Lemma replicate_length_nth {A} : forall (n k : nat) (w x : A),
    nth_error (replicate n w) k = Some x -> (k < n)%nat.
Proof.
  intros n; induction n; intros; simpl in *; auto.
  - inv H.
    destruct k; inv H1.
  - destruct k.
    + lia.
    + simpl in *.
      apply IHn in H.
      lia.
Qed.

(* Progress:
     If [e] is well-formed with respect to [D] and
        [e] has tau [t] under heap [H] in mode [m]
     Then
        [e] is a value, [e] reduces, or [e] is stuck in unchecked code *)
Lemma pos_succ : forall x, exists n, (Pos.to_nat x) = S n.
Proof.
   intros x. destruct (Pos.to_nat x) eqn:N.
    +zify. lia.
    +exists n. reflexivity.
Qed.

Ltac remove_options :=
  match goal with
  | [ H: Some ?X = Some ?Y |- _ ] => inversion H; subst X; clear H
  end.

(*No longer provable since we can allocate
bounds that are less than 0 now.
Lemma allocate_bounds : forall D l h t b ts,
Some(b, ts) = allocate_meta D (TArray l h t) ->
l = 0 /\ h > 0.
Proof.
intros.
destruct l.
  +destruct h.
    *simpl in H. inv H.
    *zify. omega.
    *simpl in H. inv H.
  +simpl in H. inv H.
  +simpl in H. inv H.
Qed.
*)

Lemma fields_aux : forall fs,
length (map snd (Fields.elements (elt:=tau) fs)) = length (Fields.elements (elt:=tau) fs).
Proof.
  intros. eapply map_length.
Qed.

Lemma obvious_list_aux : forall (A : Type) (l : list A),
(length l) = 0%nat -> 
l = nil.
Proof.
  intros. destruct l.
  - reflexivity.
  - inv H.
Qed.

(*These are obvious*)
Lemma fields_implies_length : forall fs t,
Some t = Fields.find (elt:=tau) 0%nat fs ->
((length (Fields.elements (elt:=tau) fs) > 0))%nat.
Proof.
 intros.
 assert (Fields.find (elt:=tau) 0%nat fs = Some t) by easy.
 apply Fields.find_2 in H0.
 apply Fields.elements_1 in H0.
 destruct ((Fields.elements (elt:=tau) fs)).
 inv H0. simpl. lia.
Qed.

Lemma find_implies_mapsto : forall s D f,
StructDef.find (elt:=fields) s D = Some f ->
StructDef.MapsTo s f D.
Proof.
  intros. 
  eapply StructDef.find_2. assumption.
Qed.


Lemma struct_subtype_non_empty : forall m T fs D Q,
subtype D Q (TPtr m (TStruct T)) (TPtr m TInt) ->
(StructDef.MapsTo T fs D) ->
Z.of_nat(length (map snd (Fields.elements (elt:=tau) fs))) > 0.
Proof.
  intros. remember (TPtr m (TStruct T)) as p1.
  remember (TPtr m TInt) as p2. induction H.
  - exfalso. rewrite Heqp1 in Heqp2. inv Heqp2.
  - exfalso. inv Heqp2.
  - exfalso. inv Heqp1.
  - exfalso. inv Heqp1.
  - exfalso. inv Heqp2.
  - inv Heqp1.
  - inv Heqp1.
  - inv Heqp1. assert (fs = fs0) by (eapply StructDefFacts.MapsTo_fun; eauto). 
    eapply fields_implies_length in H1. rewrite H2.
    zify. eauto. rewrite map_length. assumption.
  - inv Heqp2. 
Qed.

Lemma struct_subtype_non_empty_1 : forall m T fs D Q,
subtype D Q (TPtr m (TStruct T)) (TPtr m (TArray (Num 0) (Num 1) TInt)) ->
(StructDef.MapsTo T fs D) ->
Z.of_nat(length (map snd (Fields.elements (elt:=tau) fs))) > 0.
Proof.
  intros. remember (TPtr m (TStruct T)) as p1.
  remember (TPtr m (TArray (Num 0) (Num 1) TInt)) as p2. induction H.
  - exfalso. rewrite Heqp1 in Heqp2. inv Heqp2.
  - exfalso. inv Heqp2. inv Heqp1.
  - exfalso. inv Heqp1.
  - exfalso. inv Heqp1.
  - exfalso. inv Heqp1.
  - inv Heqp1.
  - inv Heqp2. 
  - inv Heqp1. inv Heqp2. 
  - inv Heqp1. inv Heqp2. 
    assert (fs = fs0) by (eapply StructDefFacts.MapsTo_fun; eauto). 
    eapply fields_implies_length in H1. rewrite H4.
    zify. eauto. rewrite map_length. assumption.
Qed.

Lemma struct_subtype_non_empty_2 : forall m T fs D Q,
subtype D Q (TPtr m (TStruct T)) (TPtr m (TNTArray (Num 0) (Num 1) TInt)) ->
(StructDef.MapsTo T fs D) ->
Z.of_nat(length (map snd (Fields.elements (elt:=tau) fs))) > 0.
Proof.
  intros. remember (TPtr m (TStruct T)) as p1.
  remember (TPtr m (TNTArray (Num 0) (Num 1) TInt)) as p2. induction H.
  - exfalso. rewrite Heqp1 in Heqp2. inv Heqp2.
  - exfalso. inv Heqp2.
  - exfalso. inv Heqp2. inv Heqp1.
  - exfalso. inv Heqp1.
  - exfalso. inv Heqp1.
  - inv Heqp1.
  - inv Heqp1. 
  - inv Heqp2. 
  - inv Heqp1. inv Heqp2. 
Qed.

(*
Definition env_denv_prop (env: env) (S:stack) (denv:dyn_env) :=
    forall x t t', Env.MapsTo x t env -> cast_tau_bound S t t' -> Stack.MapsTo x t' denv.
*)
Lemma gen_cast_bound_same :
   forall env s b, well_bound_in env b -> sub_domain env s -> (exists b', cast_bound s b = Some b').
Proof.
  intros. induction b.
  exists (Num z). unfold cast_bound. reflexivity.
  inv H. unfold sub_domain in *.
  assert (Env.In v env0).
  unfold Env.In,Env.Raw.PX.In.
  exists TInt. easy.
  apply H0 in H. 
  unfold cast_bound.
  unfold Stack.In,Stack.Raw.PX.In in *.
  destruct H. apply Stack.find_1 in H.
  destruct (Stack.find v s).
  injection H as eq1. destruct p.
  exists (Num (z + z0)). reflexivity.
  inv H.
Qed.

Lemma gen_cast_tau_bound_same :
   forall env s t, well_tau_bound_in env t -> sub_domain env s
           -> (exists t', cast_tau_bound s t t').
Proof.
  intros. induction t.
  exists TInt. apply cast_tau_bound_nat.
  inv H. apply IHt in H3. destruct H3.
  exists (TPtr m x). apply cast_tau_bound_ptr. assumption.
  exists (TStruct s0). apply cast_tau_bound_struct.
  inv H. apply IHt in H7. destruct H7.
  apply (gen_cast_bound_same env0 s) in H5.
  apply (gen_cast_bound_same env0 s) in H6.
  destruct H5. destruct H6.
  exists (TArray x0 x1 x).
  apply cast_tau_bound_array.
  1 - 5: assumption.
  inv H. apply IHt in H7. destruct H7.
  apply (gen_cast_bound_same env0 s) in H5.
  apply (gen_cast_bound_same env0 s) in H6.
  destruct H5. destruct H6.
  exists (TNTArray x0 x1 x).
  apply cast_tau_bound_ntarray.
  1 - 5: assumption.
Qed.


Lemma cast_word_tau : forall s t t', cast_tau_bound s t t' -> word_tau t -> word_tau t'.
Proof.
 intros. inv H0. inv H. constructor.
 inv H. constructor.
Qed.

Lemma cast_tau_wf : forall D s t t', cast_tau_bound s t t' -> tau_wf D t -> tau_wf D t'.
Proof.
 intros. generalize dependent t'. induction t.
 intros. inv H. constructor.
 intros. inv H. constructor. apply IHt. inv H0. assumption.
 assumption.
 intros. inv H. constructor.
 inv H0. destruct H1. exists x. assumption.
 intros. inv H.
 constructor. inv H0. eapply cast_word_tau. apply H7. assumption.
 apply IHt. inv H0. assumption. assumption.
 intros. inv H.
 constructor. inv H0. eapply cast_word_tau. apply H7. assumption.
 apply IHt. inv H0. assumption. assumption.
Qed.

Lemma cast_tau_bound_same : forall s t t' t'',
              cast_tau_bound s t t' -> cast_tau_bound s t t'' -> t' = t''.
Proof.
 intros s t.
 induction t.
 intros. inv H0. inv H. reflexivity.
 intros.
 inv H. inv H0.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 intros. inv H. inv H0. reflexivity.
 intros. inv H. inv H0.
 unfold cast_bound in *.
 destruct b. destruct b0. inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 destruct (Stack.find (elt:=Z * tau) v s).
 destruct p.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 inv H6.
 destruct (Stack.find (elt:=Z * tau) v s). destruct b0.
 destruct p.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 destruct (Stack.find (elt:=Z * tau) v0 s). destruct p. destruct p0.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 inv H6. inv H3. 
 intros. inv H. inv H0.
 unfold cast_bound in *.
 destruct b. destruct b0. inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 destruct (Stack.find (elt:=Z * tau) v s).
 destruct p.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 inv H6.
 destruct (Stack.find (elt:=Z * tau) v s). destruct b0.
 destruct p.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 destruct (Stack.find (elt:=Z * tau) v0 s). destruct p. destruct p0.
 inv H4. inv H6. inv H3. inv H8.
 assert (t' = t'0).
 apply IHt. assumption. assumption. rewrite H. reflexivity.
 inv H6. inv H3. 
Qed.

Lemma simple_tau_means_cast_same : forall t s, simple_tau t -> cast_tau_bound s t t.
Proof.
  induction t;intros; simpl; try constructor.
  inv H. apply IHt. easy.
  inv H. easy. inv H. easy. apply IHt. inv H. easy.
  inv H. easy. inv H. easy. apply IHt. inv H. easy.
Qed. 

Lemma simple_tau_means_eval_same : forall t s, simple_tau t -> eval_tau_bound s t = Some t.
Proof.
  induction t;intros; simpl; try constructor.
  destruct t; try easy.
  inv H. inv H1.
  unfold eval_bound. easy.
  inv H. inv H1.
  unfold eval_bound. easy.
Qed. 

Lemma cast_tau_eq : forall s t t1 t', 
        cast_tau_bound s t t' -> tau_eq s t t1 -> cast_tau_bound s t1 t'.
Proof.
 intros. inv H0. easy.
 assert (t' = t1).
 eapply cast_tau_bound_same. apply H. easy. subst.
 apply simple_tau_means_cast_same. easy.
 assert (t1 = t').
 specialize (simple_tau_means_cast_same t1 s H1) as eq1.
 eapply cast_tau_bound_same. apply H2. easy. subst.
 apply simple_tau_means_cast_same. easy.
Qed.

Lemma sub_domain_grow : forall env S x v t, sub_domain env S 
                 -> sub_domain (Env.add x t env) (Stack.add x v S).
Proof.
  intros.
  unfold sub_domain in *.
  intros.
  unfold Env.In,Env.Raw.PX.In in H0.
  destruct H0.
  unfold Stack.In,Stack.Raw.PX.In.
  destruct (Nat.eq_dec x x0).
  subst.
  exists v.
  apply Stack.add_1. easy.
  apply Env.add_3 in H0.
  assert (Env.In x0 env0).
  unfold Env.In,Env.Raw.PX.In.
  exists x1. easy.
  apply H in H1.
  unfold Stack.In,Stack.Raw.PX.In in H1.
  destruct H1.
  exists x2.
  apply Stack.add_2.
  lia. assumption. lia.
Qed.

(* Some lemmas related to cast/well_bound_in *)
Lemma not_in_empty : forall x, Env.In x empty_env -> False.
Proof.
 intros.
  unfold empty_env in H.
 specialize (@Env.empty_1 tau) as H1.
 unfold Env.In,Env.Raw.PX.In in H.
 destruct H.
 unfold Env.Empty,Env.Raw.Empty in H1.
 inv H.
Qed.

Lemma simple_tau_well_bound : forall (env: env) (w:tau),
                simple_tau w -> well_tau_bound_in env w.
Proof.
   intros. induction w.
   apply well_tau_bound_in_nat.
   apply well_tau_bound_in_ptr.
   apply IHw. inv H. assumption.
   apply well_tau_bound_in_struct.
   inv H.
   apply well_tau_bound_in_array.
   apply well_bound_in_num.
   apply well_bound_in_num.
   apply IHw. assumption.
   inv H.
   apply well_tau_bound_in_ntarray.
   apply well_bound_in_num.
   apply well_bound_in_num.
   apply IHw. assumption.
Qed.


Lemma well_bound_means_no_var :
     forall b, well_bound_in empty_env b -> (exists n, b = (Num n)).
Proof.
 intros. remember empty_env as env.
 induction H. eauto.
 subst. 
 unfold empty_env in H.
 specialize (@Env.empty_1 tau) as H1.
 unfold Env.In,Env.Raw.PX.In in H.
 apply EnvFacts.empty_mapsto_iff in H. inv H.
Qed.






Lemma empty_env_means_cast_bound_same :
   forall s b, well_bound_in empty_env b  -> cast_bound s b = Some b.
Proof.
  intros. unfold cast_bound. inv H.
  easy. apply EnvFacts.empty_mapsto_iff in H0. inv H0.
Qed.


Lemma empty_env_means_cast_tau_bound_same :
   forall s t, well_tau_bound_in empty_env t -> cast_tau_bound s t t.
Proof.
 intros. 
 remember empty_env as env.
 induction H. constructor.
 constructor. apply IHwell_tau_bound_in. easy.
 constructor.
 constructor. subst.
 apply empty_env_means_cast_bound_same. easy.
 subst.
 apply empty_env_means_cast_bound_same. easy.
 apply IHwell_tau_bound_in; easy.
 constructor. subst.
 apply empty_env_means_cast_bound_same. easy.
 subst.
 apply empty_env_means_cast_bound_same. easy.
 apply IHwell_tau_bound_in; easy.
Qed.

(*
Lemma lit_empty_means_cast_tau_bound_same :
  forall D F Q S H m n t t1, @well_typed D F S H empty_env Q m (ELit n t) t1 ->  cast_tau_bound S t t.
Proof.
 intros. remember empty_env as env.
 inv H0.
 apply simple_tau_means_cast_same.
 easy.
Qed.
*)

Lemma lit_nat_tau : forall D F H Q S env m n t, 
       @well_typed D F S H env Q m (ELit n t) TInt -> t = TInt.
Proof.
 intros. remember (ELit n t) as e. remember TInt as t1.
 induction H0; subst; inv Heqe.
 reflexivity.
Qed.


(* Progress proof for args. *)
Lemma well_typed_args_same_length : forall D Q H env s es tvl,
    @well_typed_args D Q H env s es tvl -> length es = length tvl.
Proof.
  intros. induction H0. easy.
  simpl. rewrite IHwell_typed_args. easy.
Qed.

Definition bound_in_stack (S: stack) (b:bound) :=
       match b with Num n => True
                | Var x n => Stack.In x S
       end.

Inductive stack_bound_in : stack -> tau -> Prop :=
   | stack_bound_in_nat : forall env, stack_bound_in env TInt
   | stack_bound_in_ptr : forall m t env, stack_bound_in env t -> stack_bound_in env (TPtr m t)
   | stack_bound_in_struct : forall env T, stack_bound_in env (TStruct T)
   | stack_bound_in_array : forall env l h t, bound_in_stack env l -> bound_in_stack env h -> 
                                      stack_bound_in env t -> stack_bound_in env (TArray l h t)
   | stack_bound_in_ntarray : forall env l h t, bound_in_stack env l -> bound_in_stack env h -> 
                                      stack_bound_in env t -> stack_bound_in env (TNTArray l h t).

Fixpoint bounds_in_stack (S:stack) (l : list (var * bound)) :=
   match l with [] => True
            | (x,v)::xl => (bound_in_stack S v /\ bounds_in_stack S xl)
   end.

Lemma stack_in_cast_bound : forall s t, bound_in_stack s t
              -> (exists t', cast_bound s t = Some t').
Proof.
  intros. unfold bound_in_stack in H.
  destruct t. exists (Num z). easy.
  unfold Stack.In,Stack.Raw.PX.In in H.
  destruct H. destruct x.
  exists (Num (z+z0)).
  unfold cast_bound.
  apply Stack.find_1 in H. rewrite H. easy.
Qed.

Lemma stack_in_cast_tau : forall s t, stack_bound_in s t
              -> (exists t', cast_tau_bound s t t').
Proof.
  intros. induction H.
  exists TInt. constructor.
  destruct IHstack_bound_in.
  exists (TPtr m x). constructor. easy.
  exists (TStruct T). constructor.
  destruct IHstack_bound_in.
  apply stack_in_cast_bound in H0.
  apply stack_in_cast_bound in H.
  destruct H. destruct H0.
  exists (TArray x0 x1 x).
  constructor. 1-3: easy.
  destruct IHstack_bound_in.
  apply stack_in_cast_bound in H0.
  apply stack_in_cast_bound in H.
  destruct H. destruct H0.
  exists (TNTArray x0 x1 x).
  constructor. 1-3: easy.
Qed.

Lemma well_bound_stack_bound_in : forall env S t,
  well_bound_in env t -> sub_domain env S -> bound_in_stack S t.
Proof.
  intros. induction H.
  constructor.
  unfold bound_in_stack.
  unfold sub_domain in H0.
  unfold Env.In,Env.Raw.PX.In in H0.
  specialize (H0 x).
  apply H0. exists TInt. easy.
Qed.

Lemma well_tau_stack_bound_in : forall env S t,
  well_tau_bound_in env t -> sub_domain env S -> stack_bound_in S t.
Proof.
  intros. induction H.
  constructor. constructor. apply IHwell_tau_bound_in. easy.
  constructor. constructor.
  apply (well_bound_stack_bound_in env0); try easy.
  apply (well_bound_stack_bound_in env0); try easy.
  apply IHwell_tau_bound_in. easy.
  constructor.
  apply (well_bound_stack_bound_in env0); try easy.
  apply (well_bound_stack_bound_in env0); try easy.
  apply IHwell_tau_bound_in. easy.
Qed.

Lemma stack_bound_in_bounds : forall AS S b, bounds_in_stack S AS ->
    bound_in_stack S b -> bound_in_stack S (subst_bounds b AS).
Proof.
  induction AS; intros; simpl. easy.
  destruct a.
  apply IHAS. simpl in H. destruct H. easy.
  simpl in H. destruct H.
  unfold subst_bound. destruct b. easy.
  destruct (var_eq_dec v0 v).
  destruct b0. constructor.
  unfold bound_in_stack.
  inv H. unfold Stack.In,Stack.Raw.PX.In.
  exists x. easy.
  easy.
Qed.

Lemma stack_bound_in_subst_tau : forall S AS t, bounds_in_stack S AS -> 
         stack_bound_in S t -> stack_bound_in S (subst_tau AS t).
Proof.
  intros. induction H0; simpl.
  constructor. constructor. apply IHstack_bound_in. easy. constructor.
  constructor.
  apply stack_bound_in_bounds; try easy.
  apply stack_bound_in_bounds; try easy.
  apply IHstack_bound_in. easy.
  constructor.
  apply stack_bound_in_bounds; try easy.
  apply stack_bound_in_bounds; try easy.
  apply IHstack_bound_in. easy.
Qed.

Lemma eval_arg_exists : forall S env e t,
         well_tau_bound_in env t -> sub_domain env S ->
         ((exists n t, e = ELit n t) \/ (exists y, e = EVar y /\ Env.In y env))
          -> (exists n' t', eval_arg S e t (ELit n' t')).
Proof.
 intros. destruct H1. destruct H1. destruct H1. subst.
 assert (exists t', cast_tau_bound S t t').
 apply stack_in_cast_tau.
 apply (well_tau_stack_bound_in env0); try easy.
 destruct H1.
 exists x. exists x1. constructor. easy.
 destruct H1. destruct H1. subst.
 assert (exists t', cast_tau_bound S t t').
 apply stack_in_cast_tau.
 apply (well_tau_stack_bound_in env0); try easy.
 destruct H1.
 unfold sub_domain in H0. apply H0 in H2.
 destruct H2. destruct x1.
 exists z. exists x0.
 apply eval_var with (t' := t0).
 easy. easy. 
Qed.

Lemma taud_args_values :
    forall tvl es D Q S H env AS, 
        sub_domain env S ->
        bounds_in_stack S AS ->
        @well_typed_args D Q H env AS es tvl ->
          (exists S', @eval_el AS S tvl es S').
Proof.
  intros. induction H2.
  exists S. constructor. 
  specialize (IHwell_typed_args H0 H1).
  destruct IHwell_typed_args.
  specialize (eval_arg_exists S env0 e (subst_tau s t)) as X1.
  inv H2.
  apply simple_tau_well_bound with (env := env0) in H5.
  specialize (X1 H5 H0).
  assert ((exists (n0 : Z) (t : tau), ELit n t' = ELit n0 t) \/
     (exists y : var,
        ELit n t' = EVar y /\ Env.In (elt:=tau) y env0)).
  left. exists n. exists t'. easy.
  apply X1 in H2. destruct H2. destruct H2.
  exists ((Stack.add v (x0,x1) x)).
  apply eval_el_many_2; try easy.
  assert ((exists (n : Z) (t : tau), EVar x0 = ELit n t) \/
     (exists y : var,
        EVar x0 = EVar y /\ Env.In (elt:=tau) y env0)).
  right.
  exists x0. split. easy. exists t'. easy.
  specialize (X1 H6 H0 H2).
  inv H2. destruct H8. destruct H2. inv H2.
  destruct H8. destruct H2. inv H2.
  destruct X1. destruct H2.
  exists ((Stack.add v (x0,x2) x)).
  apply eval_el_many_2; try easy.
Qed.

Inductive well_arg_env_in : env -> expression -> Prop :=
   | well_arg_env_lit : forall s v t, well_arg_env_in s (ELit v t)
   | well_arg_env_var : forall s x, Env.In x s -> well_arg_env_in s (EVar x).

Inductive well_args_env_in : env -> list expression -> Prop :=
   | well_args_empty : forall s, well_args_env_in s []
   | well_args_many : forall s e es, well_arg_env_in s e -> well_args_env_in s es -> well_args_env_in s (e::es).

Lemma well_tau_args_trans : forall D Q H env AS es tvl, @well_typed_args D Q H env AS es tvl -> well_args_env_in env es.
Proof.
  intros. induction H0. constructor.
  constructor.
  inv H0. constructor.
  constructor.
  exists t'. easy. easy.
Qed.

Definition bounds_in_stack_inv (l : list (var * bound)) (S:stack) := forall x y n, In (x,Var y n) l -> Stack.In y S.

Lemma get_dept_map_bounds_in_stack_inv : forall tvl es env S AS, well_args_env_in env es
             -> sub_domain env S -> get_dept_map tvl es = Some AS -> bounds_in_stack_inv AS S.
Proof.
  induction tvl. intros. simpl in *. inv H1. unfold bounds_in_stack. easy.
  intros.
  simpl in *. destruct a. destruct t.
  destruct es. inv H1.
  inv H. inv H5.
  unfold get_good_dept in *.
  destruct (get_dept_map tvl es) eqn:eq1. inv H1.
  specialize (IHtvl es env0 S l H6 H0 eq1).
  unfold bounds_in_stack_inv in *.
  intros. simpl in H. destruct H. inv H. apply IHtvl with (x := x) (y := y) (n:=n). easy.
  inv H1.
  unfold get_good_dept in *.
  destruct (get_dept_map tvl es) eqn:eq1. inv H1.
  specialize (IHtvl es env0 S l H6 H0 eq1).
  unfold bounds_in_stack_inv in *.
  intros. simpl in H1. destruct H1. inv H1.
  unfold sub_domain in H0.
  apply H0. easy.
  apply IHtvl with (x := x0) (y := y) (n:=n). easy.
  inv H1.
  destruct es. inv H1.
  inv H.
  apply IHtvl with (es := es) (env:=env0); try easy.
  destruct es. inv H1.
  inv H.
  apply IHtvl with (es := es) (env:=env0); try easy.
  destruct es. inv H1.
  inv H.
  apply IHtvl with (es := es) (env:=env0); try easy.
  destruct es. inv H1.
  inv H.
  apply IHtvl with (es := es) (env:=env0); try easy.
Qed.

Lemma bound_in_stack_correct : forall S AS, bounds_in_stack_inv AS S -> bounds_in_stack S AS.
Proof.
  intros. induction AS. simpl in *. easy.
  simpl in *. destruct a eqn:eq1.
  split.
  unfold bounds_in_stack_inv in H.
  destruct b. unfold bound_in_stack. easy.
  unfold bound_in_stack. apply H with (x := v) (n := z).
  simpl. left. easy.
  apply IHAS.
  unfold bounds_in_stack_inv in *.
  intros.
  apply H with (x := x) (n:=n). simpl. right. easy.
Qed.

Lemma get_dept_map_bounds_in_stack : forall tvl es env S AS, well_args_env_in env es
             -> sub_domain env S -> get_dept_map tvl es = Some AS -> bounds_in_stack S AS.
Proof.
  intros.
  apply bound_in_stack_correct.
  apply get_dept_map_bounds_in_stack_inv with (tvl := tvl) (env := env0) (es := es); try easy.
Qed.

(*
Definition sub_stack_nat (arg_env: arg_stack) (S:stack) (arg_s:stack) :=
       (forall x v, (Stack.MapsTo x (NumVal v) arg_env -> Stack.MapsTo x (v,TInt) arg_s)) /\
       (forall x v t v', (Stack.MapsTo x (VarVal v) arg_env -> Stack.MapsTo v (v',t) S -> Stack.MapsTo x (v',TInt) arg_s)).

Lemma subtype_stack_nat : forall D S t, subtype_stack D S TInt t -> t = TInt.
Proof.
  intros. inv H. inv H0. easy. inv H2. inv H1. easy. inv H1. inv H2. easy.
Qed.

Definition sub_list_arg_s (l : list var) (arg_s:stack) := forall x, In x l -> Stack.In x arg_s.

Lemma well_bound_vars_cast : forall b l s, sub_list_arg_s l s -> no_ebound b
          -> well_bound_vars l b -> (exists b', cast_bound s b = Some (Num b')).
Proof.
 intros. induction b; simpl.
 exists z. easy.
 destruct (Stack.find (elt:=Z * tau) v s) eqn:eq1.
 destruct p.
 exists ((z + z0)). easy.
 unfold sub_list_arg_s in *.
 inv H1. apply H in H4.
 unfold Stack.In,Stack.Raw.PX.In in *.
 destruct H4. apply Stack.find_1 in H1.
 rewrite H1 in eq1. inv eq1.
 inv H0.
Qed.

Lemma well_tau_bound_vars_cast : forall t l s, sub_list_arg_s l s -> well_bound_vars_type l t ->
               no_etau t -> (exists t', cast_tau_bound s t t' /\ simple_tau t').
Proof.
  induction t; intros; simpl.
  exists TInt. split. constructor. constructor.
  inv H0. apply IHt with (s := s) in H4. destruct H4.
  exists (TPtr m x). split.  constructor. easy. constructor. easy. easy. inv H1. easy.
  exists (TStruct s). constructor. constructor. constructor.
  inv H0. inv H1.
  apply IHt with (s := s) in H8; try easy. destruct H8.
  apply well_bound_vars_cast with (s := s) in H6; try easy.
  apply well_bound_vars_cast with (s := s) in H7; try easy.
  destruct H6. destruct H7.
  exists (TArray (Num x0) (Num x1) x). split. constructor. easy. easy. easy.
  constructor. easy.
  inv H0. inv H1.
  apply IHt with (s := s) in H8; try easy. destruct H8.
  apply well_bound_vars_cast with (s := s) in H6; try easy.
  apply well_bound_vars_cast with (s := s) in H7; try easy.
  destruct H6. destruct H7.
  exists (TNTArray (Num x0) (Num x1) x). split. constructor. easy. easy. easy.
  constructor. easy.
  inv H1.
Qed.





Lemma subtype_no_etau : forall t D t', subtype D t t' -> no_etau t -> no_etau t'.
Proof.
  intros. induction H; try easy.
  inv H0. constructor. constructor. easy.
  inv H1. constructor. inv H2. constructor.
  inv H0. inv H4. constructor. easy.
  inv H0. inv H4. constructor. easy.
  inv H0. constructor. inv H3. constructor. easy.
  inv H. constructor. constructor.
  inv H1. constructor. constructor.
  inv H0. constructor. inv H3. constructor. easy.
  inv H. constructor. constructor.
  inv H1. constructor. constructor.
  inv H0. constructor. inv H3. constructor. easy.
  inv H. constructor. constructor.
  inv H1. constructor. constructor.
  constructor. constructor.
  constructor. constructor. constructor.
  inv H2. constructor. inv H3. constructor.
Qed.

Lemma cast_bound_no_ebound : forall s b b', cast_bound s b = Some b' -> no_ebound b' -> no_ebound b.
Proof.
  intros. induction b; simpl. easy. easy.
  inv H. inv H0.
Qed.

Lemma cast_tau_no_etau : forall s t t', cast_tau_bound s t t' -> no_etau t' -> no_etau t.
Proof.
  intros. induction H;simpl. easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  apply cast_bound_no_ebound with (s := s) (b' := l'); try easy.
  apply cast_bound_no_ebound with (s := s) (b' := h'); try easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  apply cast_bound_no_ebound with (s := s) (b' := l'); try easy.
  apply cast_bound_no_ebound with (s := s) (b' := h'); try easy.
  easy. inv H0.
Qed.

Lemma subtype_no_etau_r : forall t D t', subtype D t t' -> no_etau t' -> no_etau t.
Proof.
  intros. induction H; try easy.
  inv H0. inv H4. constructor. easy.
  inv H1. constructor. inv H2. constructor. inv H0. easy.
  constructor. constructor.
  inv H0. constructor. constructor. easy.
  inv H1. constructor. inv H2. constructor.
  inv H0. inv H3. constructor. constructor. easy.
  inv H. constructor. constructor. inv H1. constructor. constructor.
  inv H0. inv H3. constructor. constructor. easy.
  inv H. constructor. constructor. inv H1. constructor. constructor.
  inv H0. inv H3. constructor. constructor. easy.
  inv H. constructor. constructor. inv H1. constructor. constructor.
  constructor. constructor.
  constructor. constructor.
Qed.

Lemma cast_bound_no_ebound_r : forall s b b', cast_bound s b = Some b' -> no_ebound b -> no_ebound b'.
Proof.
  intros. induction b; simpl. inv H. constructor. inv H. 
  destruct (Stack.find (elt:=Z * tau) v s) eqn:eq1. destruct p. inv H2. constructor. inv H2.
  inv H0.
Qed.

Lemma cast_tau_no_etau_r : forall s t t', cast_tau_bound s t t' -> no_etau t -> no_etau t'.
Proof.
  intros. induction H;simpl. easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  apply cast_bound_no_ebound_r with (s := s) (b := l); try easy.
  apply cast_bound_no_ebound_r with (s := s) (b := h); try easy.
  inv H0. constructor. apply IHcast_tau_bound. easy.
  apply cast_bound_no_ebound_r with (s := s) (b := l); try easy.
  apply cast_bound_no_ebound_r with (s := s) (b := h); try easy.
  easy. inv H0.
Qed.

Lemma subtype_stack_no_etau : forall t D s t', subtype_stack D s t t' -> no_etau t -> no_etau t'.
Proof.
  intros. inv H.
  apply subtype_no_etau with (t := t) (D:=D). easy. easy.
  specialize (subtype_no_etau t D t2' H3 H0) as eq1.
  apply cast_tau_no_etau with (s := s) (t' := t2'); try easy.
  specialize (cast_tau_no_etau_r s t t1' H2 H0) as eq1. 
  specialize (subtype_no_etau t1' D t' H3 eq1) as eq2.
  easy.
Qed.

Definition bound_env (e:env) := forall x t, Env.MapsTo x t e -> ext_tau_in [] t.

Lemma no_ebound_ext_bound : forall b, no_ebound b -> ext_bound_in [] b.
Proof.
  intros. induction b. constructor. constructor. inv H.
Qed.

Lemma no_ebound_ext_bound_anti : forall b, ext_bound_in [] b -> no_ebound b.
Proof.
  intros. induction b. constructor. constructor. inv H. simpl in H2. inv H2.
Qed.

Lemma no_etau_ext_tau : forall t, no_etau t -> ext_tau_in [] t.
Proof.
  intros. induction H; try constructor. easy.
  apply no_ebound_ext_bound. easy.
  apply no_ebound_ext_bound. easy.
  easy.
  apply no_ebound_ext_bound. easy.
  apply no_ebound_ext_bound. easy.
  easy.
Qed.

Lemma gen_env_ext_tau : forall tvl D env env', gen_env env tvl env' ->
        (forall x t', In (x,t') tvl -> word_tau t' /\ tau_wf D t' /\ no_etau t') -> bound_env env -> bound_env env'.
Proof.
  induction tvl; intros; simpl.
  inv H. easy.
  unfold bound_env in *. intros.
  inv H.
  assert ((forall (x : var) (t' : tau),
         In (x, t') tvl ->
         word_tau t' /\ tau_wf D t' /\ no_etau t')).
  intros.
  specialize (H0 x1 t').
  assert (In (x1, t') ((x0, t0) :: tvl)).
  simpl. right. easy. apply H0 in H3. easy.
  specialize (IHtvl D env0 env'0 H7 H H1).
  destruct (Nat.eq_dec x x0). subst.
  apply Env.mapsto_add1 in H2. subst.
  apply no_etau_ext_tau.
  specialize (H0 x0 t0).
  assert (In (x0, t0) ((x0, t0) :: tvl)). simpl. left. easy.
  apply H0 in H2. easy.
  apply Env.add_3 in H2. apply IHtvl with (x := x). easy. lia.
Qed.

Lemma vars_to_ext_bound : forall t t' l, (forall x, In x (get_tvars t) -> In x l)
              -> vars_to_ext l t t' -> ext_tau_in [] t'.
Proof.
  induction t; intros; simpl.
  inv H0. constructor.
  inv H2. inv H1. constructor. constructor.
  inv H3.
Admitted.

Lemma to_ext_ext_tau : forall t x t', to_ext_tau x t t' -> ext_tau_in [] t -> ext_tau_in [x] t'.
Proof.
  induction t; intros;simpl. inv H. constructor.
  inv H. inv H0. constructor. apply IHt. easy. easy.
  inv H. constructor.
  inv H.
Admitted.

Lemma simple_tau_ext_tau : forall t, simple_tau t -> ext_tau_in [] t.
Proof.
  intros. induction H. constructor. constructor. apply IHsimple_tau.
  constructor. constructor. constructor. constructor. easy.
  constructor.  constructor.  constructor. easy.
Qed.

Lemma ext_tau_well_bound : forall e D F st env m t, expr_wf D F e -> fun_wf D F -> structdef_wf D ->
          bound_env env -> @well_typed D F st env m e t -> ext_tau_in [] t.
Proof.
  intros. induction H3; simpl.
  inv H. apply no_etau_ext_tau. easy.
  inv H. unfold bound_env in H2. apply H2 with (x := x). easy.
  apply vars_to_ext_bound with (t := t) (l := get_tvars t).
  intros. easy. easy. constructor.
  constructor.
  apply to_ext_ext_tau with (t := t). easy.
  apply IHwell_typed2. inv H. easy.
  unfold bound_env in *. intros.
  destruct (Nat.eq_dec x0 x). subst.
  apply Env.mapsto_add1 in H5. subst. constructor.
  apply Env.add_3 in H5. apply H2 with (x := x0). easy. lia.
  inv H.
  apply IHwell_typed2. easy.
  unfold bound_env in *. intros.
  destruct (Nat.eq_dec x0 x). subst.
  apply Env.mapsto_add1 in H. subst. apply IHwell_typed1. easy. easy.
  apply Env.add_3 in H. apply H2 with (x := x0). easy. lia.
  inv H.
  apply IHwell_typed; try easy.
  constructor.
  unfold structdef_wf in H1.
  specialize (H1 T fs). apply H1 in H4. unfold fields_wf in H4.
  apply H4 in H5. destruct H5 as [X1 [X2 X3]].
  constructor.
  apply simple_tau_ext_tau. easy. inv H.
  constructor. apply no_etau_ext_tau. easy.
  apply IHwell_typed.  inv H. easy. easy.
  inv H. apply no_etau_ext_tau. easy.
  inv H. apply no_etau_ext_tau. easy.
  inv H. apply no_etau_ext_tau. easy.
  inv H. apply no_etau_ext_tau. inv H11. inv H7. constructor. constructor. easy.
  constructor. constructor.
  inv H. apply no_etau_ext_tau. inv H10. inv H6. constructor. constructor. easy.
  easy. easy.
  inv H.
  apply IHwell_typed in H8.
Admitted.


Lemma subtype_word_tau : forall D m t1 t2, word_tau t1 -> 
        subtype D (TPtr m t1) (TPtr m t2) -> t2 = t1 \/ (exists l h, nat_leq (Num 0) l
                                   /\ nat_leq h (Num 1) /\ t2 = TArray l h t1).
Proof.
  intros. 
  inv H0. left. easy.
  right. exists l. exists h. easy.
  inv H. inv H. inv H. inv H. inv H.
  inv H. inv H.
Qed.


*)

Lemma replicate_gt_eq : forall x t, 0 < x -> Z.of_nat (length (Zreplicate (x) t)) = x.
Proof.
  intros.
  unfold Zreplicate.
  destruct x eqn:eq1. lia.
  simpl. 
  rewrite replicate_length. lia.
  lia.
Qed.

Lemma gen_rets_exist: forall tvl (S S':stack) AS es e, length es = length tvl ->
         eval_el AS S tvl es S' -> (exists e', gen_rets AS S tvl es e e').
Proof.
  induction tvl. intros.
  simpl in *.
  destruct es. exists e.
  constructor. simpl in *. inv H.
  intros.
  destruct es. inv H. inv H0.
  assert (length es = length tvl). inv H. easy.
  apply IHtvl with (AS:= AS) (S := S) (S' := s') (e := e) in H0; try easy.
  destruct H0. 
  exists (ERet x (n,t') (Stack.find x S) x0).
  constructor. easy. easy.
Qed.

Lemma subtype_well_tau : forall D Q H env t t' n,
simple_tau t' -> tau_wf D t' ->
@well_typed_lit D Q H env n t ->
subtype D Q t t' ->
@well_typed_lit D Q H env n t'.
Proof.
  intros. induction H2. 
  - inv H3. eauto.
  - assert (exists t, t' = (TPtr U t)) by (inv H3; eauto).
    destruct H2. rewrite H2. eauto.
  - eauto.
  - specialize (subtype_trans D Q t t' C w) as eq1.

    assert (exists t0, t' = (TPtr C t0)) by (inv H3; eauto).
    destruct H5. rewrite H5 in *.
    eapply TyLitRec; eauto.
  - assert (exists t0, t' = (TPtr C t0)) by (inv H3; eauto).
    destruct H7. subst.
    assert (subtype D Q (TPtr C w) (TPtr C x)).
    apply subtype_trans with (m := C) (w := t); try easy.
    eapply TyLitC;eauto.
Qed.

(*
Lemma well_typed_lit_reduce : forall t D Q H s n1 tv n, 
    @get_root D (TPtr C t) tv ->
    well_typed_lit D Q H (set_add eq_dec_nt (n1, TPtr C t) s) n tv ->
    well_typed_lit D Q H s n tv.
Proof.
  induction t;intros;simpl. inv H0.
  constructor.
  inv H1. constructor. constructor.
  apply set_add_elim in H6. destruct H6.
  inv H1. inv H0. inv H7. admit. admit. inv H7. admit. admit. admit.
  admit. inv H7. admit. admit. admit. admit. admit.
  apply TyLitRec with (t := t0); try easy.
  inv H0. destruct m.
Qed.
*)




(* Define the property of a stack. *)
Definition stack_wt D (S:stack) := 
    forall x v t, Stack.MapsTo x (v,t) S -> word_tau t /\ tau_wf D t /\ simple_tau t.

Definition env_wt D (env : env) :=
    forall x t, Env.MapsTo x t env -> word_tau t /\ tau_wf D t /\ well_tau_bound_in env t.

(*
Lemma stack_simple_aux : forall D S x, stack_wf D (add_nt_one S x) -> stack_wf D S.
Proof.
  unfold stack_simple in *.
  unfold add_nt_one.
  intros. 
  destruct (Stack.find (elt:=Z * tau) x S) eqn:eq1.
  destruct p. destruct t0.
  apply (H x0 v t). assumption.
  destruct t0.
  apply (H x0 v t). assumption.
  apply (H x0 v t). assumption.
  apply (H x0 v t). assumption.
  apply (H x0 v t). assumption.
  destruct b0.
  destruct (Nat.eq_dec x0 x).
  specialize (H x z (TPtr m (TNTArray b (Num (z0 + 1)) t0))).
  assert (Stack.MapsTo x
      (z, TPtr m (TNTArray b (Num (z0 + 1)) t0))
      (Stack.add x
         (z, TPtr m (TNTArray b (Num (z0 + 1)) t0)) S)).
  apply Stack.add_1. reflexivity.
  apply H in H1.
  apply Stack.find_2 in eq1.
  subst.
  apply (Stack.mapsto_always_same (Z * tau) x (z, TPtr m (TNTArray b (Num z0) t0)) (v, t)) in eq1.
  inv eq1.
  inv H1. inv H3.
  apply SPTPtr.
  apply SPTNTArray. assumption. assumption.
  specialize (H x0 v t).
  assert (Stack.MapsTo x0 (v, t)
      (Stack.add x
         (z, TPtr m (TNTArray b (Num (z0 + 1)) t0)) S)).
  apply Stack.add_2. lia. assumption.
  apply H in H1.
  assumption.
  apply H with (x:= x0) (v:=v).  easy.
  apply H with (x:= x0) (v:=v).  easy.
  apply H with (x:= x0) (v:=v).  easy.
  apply H with (x:= x0) (v:=v).  easy.
  apply H with (x:= x0) (v:=v).  easy.
Qed.
*)

Lemma cast_means_simple_tau : forall s t t', cast_tau_bound s t t' -> simple_tau t'.
Proof.
  intros. induction H. 
  apply SPTInt. apply SPTPtr. assumption.
  unfold cast_bound in *.
  destruct l. destruct h.
  injection H as eq1. injection H0 as eq2.
  subst. 
  apply SPTArray. assumption.
  destruct (Stack.find (elt:=Z * tau) v s).
  destruct p.
  injection H0 as eq1. injection H as eq2. subst.
  apply SPTArray. assumption.
  inv H0.
  destruct (Stack.find (elt:=Z * tau) v s). destruct p.
  destruct h.
  inv H. inv H0.
  apply SPTArray. assumption.
  destruct (Stack.find (elt:=Z * tau) v0 s). destruct p.
  inv H. inv H0.
  apply SPTArray. assumption.
  inv H0. inv H.
  unfold cast_bound in *.
  destruct l. destruct h.
  injection H as eq1. injection H0 as eq2.
  subst. 
  apply SPTNTArray. assumption.
  destruct (Stack.find (elt:=Z * tau) v s).
  destruct p.
  inv H. inv H0.
  apply SPTNTArray. assumption.
  inv H0.
  destruct (Stack.find (elt:=Z * tau) v s). destruct p.
  destruct h.
  inv H. inv H0.
  apply SPTNTArray. assumption.
  destruct (Stack.find (elt:=Z * tau) v0 s). destruct p.
  inv H. inv H0.
  apply SPTNTArray. assumption.
  inv H0. inv H.
  apply SPTStruct.
Qed.

Lemma stack_simple_eval_arg : forall s e n t t',
              eval_arg s e t (ELit n t') -> simple_tau t'.
Proof.
  intros. inv H.
  apply cast_means_simple_tau with (s := s) (t := t). easy.
  apply cast_means_simple_tau with (s := s) (t := t). easy.
Qed.

Lemma subst_tau_word_tau : forall AS t, word_tau t -> word_tau (subst_tau AS t).
Proof.
 intros. induction t. simpl. easy.
 simpl. constructor. simpl. easy.
 inv H.
 inv H.
Qed.

Lemma subst_tau_tau_wf : forall D AS t, tau_wf D t -> tau_wf D (subst_tau AS t).
Proof.
 intros. induction t. simpl. easy.
 simpl. constructor. apply IHt. inv H. easy.
 simpl.  easy.
 simpl. constructor. inv H. apply subst_tau_word_tau. easy.
 apply IHt. inv H. easy.
 simpl. constructor. inv H. apply subst_tau_word_tau. easy.
 apply IHt. inv H. easy.
Qed.

Lemma stack_simple_eval_el : forall D AS s tvl el s',
              stack_wt D s -> (forall x t, In (x,t) tvl -> word_tau t /\ tau_wf D t) ->
               eval_el AS s tvl el s' -> stack_wt D s'.
Proof.
  intros. induction H1. easy.
  apply stack_simple_eval_arg in H1 as eq1.
  assert (stack_wt D s').
  apply IHeval_el; try easy.
  intros.
  specialize (H0 x0 t0).
  apply H0. simpl. right. easy.
  unfold stack_wt.
  intros.
  destruct (Nat.eq_dec x0 x).
  subst.
  apply Stack.mapsto_add1 in H4. inv H4.
  inv H1.
  specialize (H0 x t).
  assert (In (x, t) ((x, t) :: tvl)). simpl.  left. easy.
  apply H0 in H1.
  split.
  apply cast_word_tau with (s := s) (t := subst_tau AS t). easy.
  apply subst_tau_word_tau. easy.
  split.
  apply cast_tau_wf with (s := s) (t := subst_tau AS t). easy.
  apply subst_tau_tau_wf. easy. easy.
  specialize (H0 x t).
  assert (In (x, t) ((x, t) :: tvl)). simpl.  left. easy.
  apply H0 in H1.
  split.
  apply cast_word_tau with (s := s) (t := subst_tau AS t). easy.
  apply subst_tau_word_tau. easy.
  split.
  apply cast_tau_wf with (s := s) (t := subst_tau AS t). easy.
  apply subst_tau_tau_wf. easy. easy.
  apply Stack.add_3 in H4.
  apply H3 in H4. easy. lia.
Qed.

Lemma gen_arg_env_good : forall tvl enva, exists env, gen_arg_env enva tvl env.
Proof.
 intros.
 induction tvl. exists enva. subst. constructor.
 destruct IHtvl.
 destruct a.
 exists (Env.add v t x).
 constructor. easy.
Qed.

Lemma sub_domain_grows : forall tvl es env env' s s' AS,
      gen_arg_env env tvl env' -> eval_el AS s tvl es s'
    -> sub_domain env s -> sub_domain env' s'.
Proof.
  induction tvl. intros.
  inv H. inv H0. easy.
  intros. inv H. inv H0.
  apply sub_domain_grow.
  apply IHtvl with (es := es0) (s := s) (env0 := env0) (AS := AS); try easy.
Qed.


Lemma stack_simple_prop : forall D env S H S' H' e e',
         sub_domain env S ->
         fun_wf D fenv S' H' -> expr_wf D fenv e -> stack_wt D S ->
            step D (fenv env) S H e S' H' (RExpr e') -> stack_wt D S'.
Proof.
  intros.
  induction H4; try easy.
  unfold stack_wt in *.
  intros.
  unfold change_strlen_stack in *.
  destruct (n' <=? h).
  apply (H3 x0 v t0). assumption.
  destruct (Nat.eq_dec x x0). subst.
  apply Stack.mapsto_add1 in H10. inv H10.
  apply H3 in H7. inv H7. constructor.
  inv H10. constructor.
  inv H10. inv H11. split.
  constructor. inv H7. constructor. inv H12. easy. inv H12. easy.
  inv H10. constructor. inv H12. constructor. easy.
  apply Stack.add_3 in H10.
  apply H3 in H10. easy. easy.
  apply stack_simple_eval_el with (D := D) in H6. easy. easy.
  intros.
  unfold fun_wf in *.
  specialize (gen_arg_env_good tvl env0) as X1.
  destruct X1.
  specialize (H1 env0 x1 x tvl t e m H4 H9).
  specialize (sub_domain_grows tvl el env0 x1 s s' AS H9 H6 H0) as eq1.
  destruct H1.
  destruct (H1 x0 t0 H8). easy.
  unfold stack_wt. intros.
  destruct (Nat.eq_dec x x0). subst.
  apply Stack.mapsto_add1 in H5. inv H5.
  inv H2. inv H7.
  split.
  apply cast_word_tau with (s := s) (t := t); try easy.
  split.
  apply cast_tau_wf with (s := s) (t := t); try easy.
  apply cast_means_simple_tau with (s := s) (t := t). easy.
  apply Stack.add_3 in H5.
  apply H3 in H5. easy. easy.
  inv H2. unfold simple_option in *.
  unfold stack_wt in *. intros.
  destruct (Nat.eq_dec x x0). subst.
  apply Stack.mapsto_add1 in H2. inv H2. easy.
  apply Stack.add_3 in H2.
  apply H3 in H2. easy. easy.
  unfold stack_wt in *.
  intros.
  apply Stack.remove_3 in H4.
  apply H3 in H4. easy.
  unfold stack_wt.
  intros. unfold add_nt_one in *.
  destruct (Stack.find (elt:=Z * tau) x s) eqn:eq1. destruct p.
  destruct t2. inv H2.
  apply H3 in H8. easy.
  destruct t2.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  destruct b0.
  apply Stack.find_2 in eq1.
  destruct (Nat.eq_dec x x0). subst.
  apply Stack.mapsto_add1 in H8. inv H8.
  apply H3 in eq1.
  destruct eq1 as [X1 [X2 X3]].
  split. constructor.
  split. constructor. inv X2. inv H9. constructor. easy. easy.
  constructor. inv X3. inv H9. constructor. easy.
  apply Stack.add_3 in H8.
  apply H3 in H8. easy. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
  apply H3 in H8. easy.
Qed.

Lemma subtype_tau_wf : forall D Q t t', subtype D Q t t' -> tau_wf D t -> tau_wf D t'.
Proof.
  intros.
  inv H. assumption.
  inv H0. constructor.
  constructor. assumption. assumption.
  inv H0.
  constructor.
  inv H4.
  assumption.
  constructor.
  inv H0.
  inv H4. assumption.
  inv H0. inv H3. constructor. constructor. assumption. assumption.
  inv H0. inv H3. constructor. constructor. assumption. assumption.
  inv H0. inv H3. constructor. constructor. assumption. assumption.
  constructor. constructor.
  constructor. constructor.
  constructor. constructor.
Qed.

(*
Lemma simple_tau_var_fresh : forall x t, simple_tau t -> var_fresh_tau x t.
Proof.
  intros. 
  induction t.
  constructor.
  constructor.
  apply IHt. inv H. assumption.
  constructor.
  inv H. constructor. constructor. constructor.
  apply IHt. assumption.
  inv H. constructor. constructor. constructor.
  apply IHt. assumption.
Qed.

Lemma step_exp_fresh : forall D F cx S H e cx' S' H' e',
        stack_simple S ->
        step D F cx S H e cx' S' H' (RExpr e') -> var_fresh cx e -> var_fresh cx' e'.
Proof.
intros.
remember (RExpr e') as ea.
induction H1; eauto.
inv Heqea.
constructor.
apply Stack.find_2 in H1.
apply H0 in H1.
apply simple_tau_var_fresh. assumption.
inv Heqea. constructor. constructor.
inv Heqea.
Qed.
*)

Lemma nth_error_map_snd : forall (l : list (Z*tau)) t i,
                nth_error (map snd l) i = Some t -> (exists x, nth_error l i = Some (x,t)).
Proof.
  intros. generalize dependent i.
  induction l.
  intros.
  destruct i eqn:eq1.
  simpl in *. inv H.
  inv H.
  intros.
  destruct i.
  simpl.
  simpl in H.
  destruct a.
  exists z. inv H. easy.
  simpl in H.
  apply IHl in H.
  simpl.
  easy.
Qed.

Check InA.

Check Fields.elements_1.

Lemma weakening_bound : forall env x b t' t, Env.MapsTo x t env -> t <> TInt ->
     well_bound_in env b -> well_bound_in (Env.add x t' env) b.
Proof.
  intros. induction H1.
  apply well_bound_in_num.
  apply well_bound_in_var.
  unfold Env.In in *.
  unfold Env.Raw.PX.In in *.
  assert (x = x0 \/ x <> x0).
  lia.
  destruct H2. subst.
  apply Env.mapsto_always_same with (v1 := t) in H1; try easy.
  apply Env.add_2. assumption.
  assumption.
Qed.

Lemma weakening_tau_bound : forall env x t t' ta,  Env.MapsTo x ta env -> ta <> TInt ->
         well_tau_bound_in env t -> well_tau_bound_in (Env.add x t' env) t.
Proof.
  intros.
  induction H1.
  apply well_tau_bound_in_nat.
  apply well_tau_bound_in_ptr.
  apply IHwell_tau_bound_in. easy.
  apply well_tau_bound_in_struct.
  apply well_tau_bound_in_array.
  apply weakening_bound with (t := ta); try easy. 
  apply weakening_bound with (t := ta); try easy. 
  apply IHwell_tau_bound_in. easy.
  apply well_tau_bound_in_ntarray.
  apply weakening_bound with (t := ta); try easy. 
  apply weakening_bound with (t := ta); try easy. 
  apply IHwell_tau_bound_in. easy.
Qed.

(* ... for Preservation *)
(*
Lemma weakening_bound : forall env x b t',
     well_bound_in env b -> well_bound_in (Env.add x t' env) b.
Proof.
  intros. induction H.
  apply well_bound_in_num.
  apply well_bound_in_var.
  unfold Env.In in *.
  unfold Env.Raw.PX.In in *.
  assert (x = x0 \/ x <> x0).
  lia.
  destruct H0.
  apply Env.add_1. assumption.
  destruct H.
  exists x1.
  apply Env.add_2. assumption.
  assumption.
Qed.

Lemma weakening_tau_bound : forall env x t t', 
         well_tau_bound_in env t -> well_tau_bound_in (Env.add x t' env) t.
Proof.
  intros.
  induction H.
  apply well_tau_bound_in_nat.
  apply well_tau_bound_in_ptr.
  assumption.
  apply well_tau_bound_in_struct.
  apply well_tau_bound_in_array.
  apply weakening_bound. assumption.
  apply weakening_bound. assumption.
  assumption.
  apply well_tau_bound_in_ntarray.
  apply weakening_bound. assumption.
  apply weakening_bound. assumption.
  assumption.
Qed.


Lemma weakening : forall D F S H env m n t,
    @well_typed D F S H env m (ELit n t) t ->
    forall x t', @well_typed D F S H (Env.add x t' env) m (ELit n t) t.
Proof.
  intros D F S H env m e t HWT.
  inv HWT.
  inv H6; eauto.
  intros. apply TyLit.
  apply weakening_tau_bound. assumption.
  apply (@WTStack D S H empty_scope e t t').
  assumption.
  apply H1.
Qed.
*)

Lemma env_maps_add :
  forall env x (t1 t2 : tau),
    Env.MapsTo x t1 (Env.add x t2 env) ->
    t1 = t2.
Proof.
  intros env x t1 t2 H.
  assert (Env.E.eq x x); try reflexivity.
  apply Env.add_1 with (elt := tau) (m := env) (e := t2) in H0.
  remember (Env.add x t2 env) as env'.
  apply Env.find_1 in H.
  apply Env.find_1 in H0.
  rewrite H in H0.
  inv H0.
  reflexivity.
Qed.


(* This theorem will be useful for substitution.

   In particular, we can automate a lot of reasoning about environments by:
   (1) proving that equivalent environments preserve typing (this lemma)
   (2) registering environment equivalence in the Setoid framework (this makes proofs in (3) easier)
   (3) proving a number of lemmas about which environments are equivalent (such as shadowing above)
   (4) registering these lemmas in the proof automation (e.g. Hint Resolve env_shadow)

   Then when we have a typing context that looks like:

   H : (Env.add x0 t0 (Env.add x0 t1 env)) |- e : t
   ================================================
   (Env.add x0 t0 env) |- e : t

   we can solve it simply by eauto.

   during proof search, eauto should invoke equiv_env_wt which will leave a goal of
   (Env.add x0 t0 (Env.add x0 t1 env)) == (Env.add x0 t0) and then subsequently apply the
   shadowing lemma.
 *)

Lemma env_find_add1 : forall x (t : tau) env,
    Env.find x (Env.add x t env) = Some t.
Proof.
  intros.
  apply Env.find_1.
  apply Env.add_1.
  reflexivity.
Qed.

Lemma env_find1 : forall x env,
    Env.find x env = None -> (forall (t : tau), ~ Env.MapsTo x t env).
Proof.
  intros.
  unfold not.
  intros.
  apply Env.find_1 in H0.
  rewrite -> H0 in H.
  inv H.
Qed.

Lemma env_find2 : forall x env,
    (forall (t : tau), ~ Env.MapsTo x t env) -> Env.find x env = None.
Proof.
  intros.
  destruct (Env.find (elt := tau) x env0) eqn:Hd.
  - exfalso. eapply H.
    apply Env.find_2 in Hd.
    apply Hd.
  - reflexivity.
Qed.

Lemma env_find_add2 : forall x y (t : tau) env,
    x <> y ->
    Env.find x (Env.add y t env) = Env.find x env.
Proof.
  intros.
  destruct (Env.find (elt:=tau) x env0) eqn:H1.
  apply Env.find_1.
  apply Env.add_2.
  auto.
  apply Env.find_2.
  assumption.
  apply env_find2.
  unfold not.
  intros.
  eapply Env.add_3 in H0.
  apply Env.find_1 in H0.
  rewrite -> H1 in H0.
  inversion H0.
  auto.
Qed.

Lemma equiv_env_add : forall x t env1 env2,
    Env.Equal (elt:=tau) env1 env2 ->
    Env.Equal (elt:=tau) (Env.add x t env1) (Env.add x t env2).
Proof.
  intros.
  unfold Env.Equal.
  intros.
  destruct (Env.E.eq_dec x y).
  rewrite e.
  rewrite env_find_add1.
  rewrite env_find_add1.
  auto.
  auto.
  auto.
  rewrite env_find_add2.
  rewrite env_find_add2.
  unfold Env.Equal in H.
  apply H.
  auto.
  auto.
Qed.
(* LEO: All of these proofs are horribly brittle :) *)

Lemma equiv_env_well_bound : forall b env1 env2,
    Env.Equal env1 env2 -> well_bound_in env1 b -> well_bound_in env2 b.
Proof.
  intros. induction H0;eauto.
  apply well_bound_in_num.
  apply well_bound_in_var.
  unfold Env.In in *. unfold Env.Raw.PX.In in *.
  specialize (@Env.mapsto_equal tau x TInt env0 env2 H0 H) as eq1.
  eauto.
Qed.

Lemma equiv_env_well_bound_tau : forall t env1 env2,
    Env.Equal env1 env2 -> well_tau_bound_in env1 t -> well_tau_bound_in env2 t.
Proof.
  intros. induction H0;eauto.
  apply well_tau_bound_in_nat.
  apply well_tau_bound_in_ptr.
  apply IHwell_tau_bound_in.
  assumption.
  apply well_tau_bound_in_struct.
  apply well_tau_bound_in_array.
  apply (equiv_env_well_bound l env0 env2). 1 - 2: assumption.
  apply (equiv_env_well_bound h env0 env2). 1 - 2: assumption.
  apply IHwell_tau_bound_in. assumption.
  apply well_tau_bound_in_ntarray.
  apply (equiv_env_well_bound l env0 env2). 1 - 2: assumption.
  apply (equiv_env_well_bound h env0 env2). 1 - 2: assumption.
  apply IHwell_tau_bound_in. assumption.
Qed.

Lemma equiv_env_warg: forall D Q H env1 env2 e t,
    Env.Equal env1 env2 -> 
     well_typed_arg D Q H env1 e t -> 
     well_typed_arg D Q H env2 e t.
Proof.
  intros. generalize dependent env2.
  induction H1; eauto 20.
  intros. eapply ArgLit. easy. easy. easy.
  intros. apply ArgVar with (t' := t').
  apply Env.mapsto_equal with (s1 := env1); try easy.
  eapply equiv_env_well_bound_tau. apply H3. apply H1. easy.
Qed.


Lemma equiv_env_wargs: forall D Q H AS env1 env2 es tvl,
    Env.Equal env1 env2 -> 
     @well_typed_args D Q H env1 AS es tvl -> 
     @well_typed_args D Q H env2 AS es tvl.
Proof.
  intros. generalize dependent env2.
  induction H1; eauto 20.
  intros. apply args_empty.
  intros. eapply args_many.
  eapply equiv_env_warg. apply H2. assumption.
  apply IHwell_typed_args. easy.
Qed.

(*
Lemma equiv_env_wt : forall D F S H Q env1 env2 m e t,
    Env.Equal env1 env2 ->
    @well_typed D F S H env1 Q m e t ->
    @well_typed D F S H env2 Q m e t.
Proof.
  intros.
  generalize dependent env2.
  induction H1; eauto 20.
  - intros.
    apply TyVar.
    apply Env.mapsto_equal with (s1 := env0); try easy.
  - intros. 
    eapply TyFun.
    apply H0. easy.
    eapply equiv_env_wargs. apply H3.
    assumption.
  - intros. 
    apply (TyStrlen env2 Q m x h l t).
    apply Env.mapsto_equal with (s1 := env0); try easy.
  - intros.
    apply (TyLetStrlen env2 Q m x y e l h t).
    apply Env.mapsto_equal with (s1 := env0); try easy.
  - intros.
    eapply TyLet.
    apply IHwell_typed1.
    assumption.
    apply IHwell_typed2.
    apply equiv_env_add.
    auto.
  - intros.
    eapply TyMalloc.
    apply (equiv_env_well_bound_tau w env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyCast; eauto.
    apply (equiv_env_well_bound_tau t env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyCastCheckedPtr; eauto.
    apply (equiv_env_well_bound_tau t env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyDynCast1; eauto.
    apply (equiv_env_well_bound_tau (TPtr C (TArray x y t)) env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyDynCast2; eauto.
    apply (equiv_env_well_bound_tau (TPtr C (TArray x y t)) env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyDynCast3; eauto.
    apply (equiv_env_well_bound_tau (TPtr C (TNTArray x y t)) env0 env2). 1 - 2 : assumption.
  - intros.
    eapply TyIf; eauto.
    apply Env.find_2.
    apply Env.find_1 in H0.
    unfold Env.Equal in H5.
    rewrite <- H5. assumption.
Qed.
*)
Lemma env_shadow : forall env x (t1 t2 : tau),
    Env.Equal (Env.add x t2 (Env.add x t1 env)) (Env.add x t2 env).
Proof.
  intros env x t1 t2 y.
  destruct (Nat.eq_dec x y) eqn:Eq; subst; eauto.
  - do 2 rewrite env_find_add1; auto.
  - repeat (rewrite env_find_add2; eauto).
Qed.

Lemma env_shadow_eq : forall env0 env1 x (t1 t2 : tau),
    Env.Equal env0 (Env.add x t2 env1) ->
    Env.Equal (Env.add x t1 env0) (Env.add x t1 env1).
Proof.
  intros env0 env1 x t1 t2 H y.
  destruct (Nat.eq_dec x y) eqn:Eq; subst; eauto.
  - repeat (rewrite env_find_add1; eauto).
  - rewrite env_find_add2; eauto.
    specialize (H y).
    rewrite env_find_add2 in H; eauto.
    rewrite env_find_add2; eauto.
Qed.

Lemma env_neq_commute : forall x1 x2 (t1 t2 : tau) env,
    ~ Env.E.eq x1 x2 ->
    Env.Equal (Env.add x1 t1 (Env.add x2 t2 env)) (Env.add x2 t2 (Env.add x1 t1 env)).
Proof.
  intros x1 x2 t1 t2 env Eq x.
  destruct (Nat.eq_dec x x1) eqn:Eq1; destruct (Nat.eq_dec x x2) eqn:Eq2; subst; eauto;
  repeat (try rewrite env_find_add1; auto; try rewrite env_find_add2; auto).    
Qed.

Lemma env_neq_commute_eq : forall x1 x2 (t1 t2 : tau) env env',
    ~ Env.E.eq x1 x2 -> Env.Equal env' (Env.add x2 t2 env) ->
    Env.Equal (Env.add x1 t1 env') (Env.add x2 t2 (Env.add x1 t1 env)).
Proof.
  intros x1 x2 t1 t2 env env' NEq Eq x.
  destruct (Nat.eq_dec x x1) eqn:Eq1; destruct (Nat.eq_dec x x2) eqn:Eq2; subst; eauto.
  - unfold Env.E.eq in *; exfalso; eapply NEq; eauto.
  - repeat (try rewrite env_find_add1 in *; auto; try rewrite env_find_add2 in *; auto).
  - specialize (Eq x2); repeat (try rewrite env_find_add1 in *; auto; try rewrite env_find_add2 in *; auto).
  - specialize (Eq x); repeat (try rewrite env_find_add1 in *; auto; try rewrite env_find_add2 in *; auto).
Qed.

Create HintDb Preservation.

Definition heap_wt_all (D : structdef) (Q:theta) (H:heap) := forall x n t, Heap.MapsTo x (n,t) H
            -> word_tau t /\ tau_wf D t /\ simple_tau t /\ well_typed_lit D Q H empty_scope n t.

Definition stack_consistent_grow (S S' : stack) (env : env) := 
       forall x v t, Env.In x env -> sub_domain env S -> Stack.MapsTo x (v,t) S -> Stack.MapsTo x (v,t) S'.

Definition stack_wf D Q env s :=
    (forall x t,
         Env.MapsTo x t env ->
         exists v t' t'',
           cast_tau_bound s t t' /\
           subtype D Q t'' t' /\
            Stack.MapsTo x (v, t'') s).

Definition stack_heap_consistent D Q H S :=
    forall x n t, Stack.MapsTo x (n,t) S -> well_typed_lit D Q H empty_scope n t.

(*
Inductive stack_wf D Q H : env -> stack -> Prop :=
  | WFS_Stack : forall env s,
     (forall x t,
         Env.MapsTo x t env ->
         exists v t' t'',
           cast_tau_bound s t t' /\
           subtype D Q t'' t' /\
            Stack.MapsTo x (v, t'') s /\
            @well_typed_lit D H empty_scope v t'')
   /\ (forall x v t,
             Stack.MapsTo x (v, t) s -> 
                   @well_typed_lit D H empty_scope v t    
          -> exists t' t'',
                @Env.MapsTo tau x t' env /\ cast_tau_bound s t' t''
                   /\ subtype D Q t t'')
 ->
     stack_wf D Q H env s.
*)
Lemma values_are_nf : forall D F H s e,
    value D e ->
    ~ exists  m s' H' r, @reduce D F s H e m s' H' r.
Proof.
  intros D F H s e Hv contra.
  inv Hv.
  destruct contra as [m [ s' [ H' [ r contra ] ] ] ].
  inv contra; destruct E; inversion H4; simpl in *; subst; try congruence.
  inv H5. inv H5. inv H5.
Qed.

Lemma lit_are_nf : forall D F H s n t,
    ~ exists H'  s' m r, @reduce D F s H (ELit n t) m s' H' r.
Proof.
  intros D F s H n t contra.
  destruct contra as [H' [ s' [ m [ r contra ] ] ] ].
  inv contra; destruct E; inversion H2; simpl in *; subst; try congruence.
Qed.


Lemma subtype_ptr : forall D Q m t t', subtype D Q (TPtr m t) t' -> exists ta, t' = TPtr m ta.
Proof.
  intros. inv H. exists t. easy.
  exists (TArray l h t). easy.
  exists t0. easy.
  exists t0. easy.
  exists (TArray l' h' t0). easy.
  exists (TArray l' h' t0). easy.
  exists (TNTArray l' h' t0). easy.
  exists TInt. easy.
  exists (TArray l h TInt). easy.
Qed.

Lemma cast_ptr_left : forall s t1 m t2, cast_tau_bound s t1 (TPtr m t2) -> exists ta, t1 = (TPtr m ta).
Proof.
  intros. inv H. exists t. easy.
Qed.

Lemma gen_arg_env_has_old : forall tvl env env0, gen_arg_env env tvl env0
          -> (forall x, Env.In x env -> Env.In x env0).
Proof.
  induction tvl.
  intros;simpl.
  inv H. easy.
  intros;simpl. inv H.
  apply IHtvl with (x := x) in H5.
  destruct H5.
  destruct (Nat.eq_dec x x0).
  subst.
  exists t.
  apply Env.add_1. easy.
  exists x1.
  apply Env.add_2. lia.
  easy.
  easy.
Qed.

Lemma gen_arg_env_has_all : forall tvl env env0, gen_arg_env env tvl env0
          -> (forall x t, Env.MapsTo x t env0 -> Env.MapsTo x t env \/ In (x,t) tvl).
Proof.
  intros. induction H. left. easy.
  destruct (Nat.eq_dec x x0). subst.
  apply Env.mapsto_add1 in H0. subst.
  right. simpl. left. easy.
  apply Env.add_3 in H0.
  apply IHgen_arg_env in H0. destruct H0. left. easy.
  right. simpl. right. easy. lia.
Qed.

Lemma stack_consist_trans : forall S S' env tvl es AS,
    sub_domain env S ->
    (forall a, In a tvl -> ~ Env.In (fst a) env) ->
    length tvl = length es ->
    eval_el AS S tvl es S' -> stack_consistent_grow S S' env.
Proof.
  intros. induction H2.
  unfold stack_consistent_grow.
  intros. easy.
  unfold stack_consistent_grow.
  intros.
  assert ((forall a : Env.key * tau,
             In a tvl -> ~ Env.In (elt:=tau) (fst a) env0)).
  intros.
  apply H0. simpl. right. easy.
  assert (length tvl = length es). simpl in *.
  inv H1. easy.
  specialize (IHeval_el H5 H7 H8).
  unfold stack_consistent_grow in *.
  specialize (IHeval_el x0 v t0 H4 H5 H6).
  destruct (Nat.eq_dec x0 x). subst.
  assert (In (x,t) ((x, t) :: tvl)). simpl. left. easy.
  apply H0 in H9.
  simpl in *. contradiction.
  apply Stack.add_2. lia. easy.
Qed.

Lemma well_typed_arg_same_length : forall D Q H env AS es tvl,
         @well_typed_args D Q H env AS es tvl -> length es = length tvl.
Proof.
  intros. induction H0. easy.
  simpl. rewrite IHwell_typed_args. easy.
Qed.

Lemma gen_arg_env_grow_1 : forall tvl env env', gen_arg_env env tvl env' -> 
      (forall a, In a tvl -> ~ Env.In (fst a) env) ->
      (forall x t, Env.MapsTo x t env -> Env.MapsTo x t env').
Proof.
  induction tvl; intros;simpl.
  inv H. easy.
  inv H.
  specialize (IHtvl env0 env'0 H6).
  assert ((forall a : var * tau,
         In a tvl -> ~ Env.In (elt:=tau) (fst a) env0)).
  intros.
  apply H0. simpl. right. easy.
  specialize (IHtvl H).
  apply IHtvl in H1 as eq1.
  destruct (Nat.eq_dec x x0).
  subst.
  specialize (H0 (x0,t0)).
  assert (In (x0, t0) ((x0, t0) :: tvl)).
  simpl. left. easy.
  apply H0 in H2.
  simpl in *.
  assert (Env.In (elt:=tau) x0 env0).
  exists t. easy. contradiction.
  apply Env.add_2. lia.
  easy.
Qed.

Lemma gen_arg_env_grow_2 : forall tvl env env', gen_arg_env env tvl env' -> 
      (forall a, In a tvl -> ~ Env.In (fst a) env) ->
      (forall x t, Env.MapsTo x t env' -> Env.MapsTo x t env \/ In (x,t) tvl).
Proof.
  induction tvl; intros;simpl.
  inv H. left. easy.
  inv H.
  destruct (Nat.eq_dec x x0). subst.
  apply Env.mapsto_add1 in H1. subst.
  right. left. easy.
  apply Env.add_3 in H1; try lia.
  assert ((forall a : var * tau,
         In a tvl -> ~ Env.In (elt:=tau) (fst a) env0)).
  intros.
  apply H0. simpl. right. easy.
  specialize (IHtvl env0 env'0 H6 H x t H1).
  destruct IHtvl. left. easy.
  right. right. easy.
Qed.

Lemma stack_grow_cast_same : forall env S S' b b', well_bound_in env b ->
        sub_domain env S -> stack_consistent_grow S S' env ->
              cast_bound S b = Some b' -> cast_bound S' b = Some b'.
Proof.
  intros. unfold cast_bound in *.
  destruct b. assumption.
  destruct (Stack.find (elt:=Z * tau) v S) eqn:eq1. destruct p.
  unfold stack_consistent_grow in *.
  apply Stack.find_2 in eq1. inv H.
  apply H1 in eq1; try easy.
  destruct (Stack.find (elt:=Z * tau) v S') eqn:eq2.
  destruct p.
  apply Stack.find_2 in eq2.
  apply (@Stack.mapsto_always_same (Z * tau) v (z0,t)) in eq2; try easy.
  inv eq2. easy.
  apply Stack.find_1 in eq1.
  rewrite eq1 in eq2. easy.
  exists TInt. easy. inv H2.
Qed.

Lemma stack_grow_cast_tau_same : forall env S S' t t', well_tau_bound_in env t ->
        sub_domain env S -> stack_consistent_grow S S' env ->
              cast_tau_bound S t t' -> cast_tau_bound S' t t'.
Proof.
  intros.
  induction H2. constructor.
  constructor.
  apply IHcast_tau_bound. inv H. easy.
  inv H.
  constructor.
  apply (stack_grow_cast_same env0 S); try easy.
  apply (stack_grow_cast_same env0 S); try easy.
  apply IHcast_tau_bound. easy.
  inv H.
  constructor.
  apply (stack_grow_cast_same env0 S); try easy.
  apply (stack_grow_cast_same env0 S); try easy.
  apply IHcast_tau_bound. easy.
  apply cast_tau_bound_struct.
Qed.

Lemma nth_error_empty_none {A:Type}: forall n, @nth_error A [] n = None.
Proof.
  induction n; intros;simpl.
  easy. easy.
Qed.

Lemma cast_subtype_same : forall t1 D Q S t1' t2 t2', subtype D Q t1 t2 -> 
    cast_tau_bound S t1 t1' -> cast_tau_bound S t2 t2' ->
    (forall x n ta, Theta.MapsTo x GeZero Q -> Stack.MapsTo x (n,ta) S -> 0 <= n) ->
    subtype D Q t1' t2'.
Proof.
  induction t1; intros;simpl.
  inv H0. inv H. inv H1. constructor.
  inv H0.
  inv H. inv H1.
  specialize (cast_tau_bound_same S t1 t' t'0 H6 H4) as eq3. subst.
  constructor. inv H5. inv H8.
  inv H1. inv H8. unfold cast_bound in *. inv H7. inv H10.
  specialize (cast_tau_bound_same S t1 t' t'1 H6 H11) as eq3. subst.
  apply SubTyBot.
  apply cast_word_tau in H6; try easy. constructor. easy. constructor. easy.
  inv H8. inv H1. inv H9. unfold cast_bound in *.
  destruct (Stack.find (elt:=Z * tau) x S) eqn:eq1. destruct p. inv H8. inv H11.
  specialize (cast_tau_bound_same S t1 t' t'1 H6 H12) as eq3. subst.
  apply SubTyBot.
  apply cast_word_tau in H6; try easy. constructor.
  apply Stack.find_2 in eq1.
  apply H2 in eq1; try easy. lia. constructor. easy.
  inv H8.
Admitted.

Definition bound_eval (S:stack) (b:bound) :=
  match b with Num n => Some n
           | Var x n => match Stack.find x S with Some (m,t) => Some (m + n)
                                               | None => None
                        end
  end.


Lemma well_bound_var_in_as : forall AS x z env, 
     ~ Env.In x env ->
      well_bound_in env (subst_bounds (Var x z) AS) ->
     (exists b, In (x,b) AS).
Proof.
  induction AS; intros; simpl in *.
  inv H0. assert (Env.In x env0).
  exists TInt. easy. contradiction.
  destruct a.
  destruct (var_eq_dec x v). subst.
  exists b. left. easy.
  specialize (IHAS x z env0 H H0). destruct IHAS. 
  exists x0. right. easy.
Qed.


Lemma cast_bound_in_env_same : forall AS S env0 v z, 
    sub_domain env0 S ->
            (forall a, In a AS -> ~ Env.In (fst a) env0) -> Env.In v env0 ->
              cast_bound S (subst_bounds (Var v z) AS) = cast_bound S (Var v z).
Proof.
  induction AS; intros;simpl.
  unfold sub_domain in *.
  specialize (H v H1). destruct H.
  apply Stack.find_1 in H. rewrite H. easy.
  destruct a.
  destruct (var_eq_dec v k). subst.
  assert (In (k,b) ((k, b) :: AS)).
  simpl. left. easy.
  apply H0 in H2. simpl in *. contradiction.
  assert ((forall a : Env.key * bound,
        In a AS -> ~ Env.In (elt:=tau) (fst a) env0)).
  intros. apply H0. simpl. right. easy.
  rewrite IHAS with (env0 := env0); try easy.
Qed.

Lemma nth_no_appear {A B:Type} : forall x v AS,
     (forall n n' (a b: A * B), n <> n' -> nth_error ((x,v)::AS) n = Some a -> nth_error ((x,v)::AS) n' = Some b -> fst a <> fst b) ->
     (forall y w, In (y,w) AS -> x <> y).
Proof.
  intros.
  apply In_nth_error in H0. destruct H0.
  specialize (H Nat.zero (S x0) (x,v) (y,w)).
  assert (Nat.zero <> S x0).
  intros R. easy.
  apply H in H1; try easy.
Qed.

Lemma subst_tau_no_effect: forall AS v z,
     (forall a, In a AS -> fst a <> v) -> subst_bounds (Var v z) AS = Var v z.
Proof.
  induction AS;intros;simpl.
  easy.
  destruct a.
  specialize (H (v0,b)) as eq1.
  assert (In (v0, b) ((v0, b) :: AS)). simpl. left. easy.
  apply eq1 in H0.
  destruct (var_eq_dec v v0). subst. easy.
  assert (forall a : var * bound, In a (AS) -> fst a <> v).
  intros. apply H. simpl. right. easy.
  apply IHAS with (z := z) in H1. easy.
Qed.

Lemma subst_bounds_only_one: forall AS env v b z, In (v,b) AS -> 
    (forall a, In a AS -> ~ Env.In (fst a) env) ->
     (forall x b, In (x,b) AS -> (match b with Num v => True | Var y v => @Env.In (tau) y env end)) ->
    (forall n n' a b, n <> n' -> nth_error AS n = Some a -> nth_error AS n' = Some b -> fst a <> fst b) ->
       subst_bounds (Var v z) AS = subst_bound (Var v z) v b.
Proof.
  induction AS;intros.
  easy. simpl.
  destruct a. simpl in H. destruct H. inv H.
  destruct (var_eq_dec v v).
  destruct b.
   assert (forall AS z, subst_bounds (Num z) AS = Num z).
   {
    intros. induction AS0. simpl. easy.
    simpl. destruct a. easy.
   }
  rewrite H. easy.
  assert (forall a, In a ((v, Var v0 z0) :: AS) -> fst a <> v0).
  {
    intros. simpl in *. intros R. destruct H. destruct a. inv H.
    simpl in *.
    specialize (H0 (k,Var k z0)).
    specialize (H1 k (Var k z0)).
    assert ((k, Var k z0) = (k, Var k z0) \/ In (k, Var k z0) AS).
    left. easy. apply H0 in H as eq1. apply H1 in H. simpl in *. contradiction.
    specialize (H0 a).
    assert ((v, Var v0 z0) = a \/ In a AS). right. easy.
    apply H0 in H3.
    specialize (H1 v (Var v0 z0)).
    assert ((v, Var v0 z0) = (v, Var v0 z0) \/ In (v, Var v0 z0) AS). left. easy.
    apply H1 in H4. destruct a. simpl in *. subst. contradiction.
  }
  rewrite subst_tau_no_effect; try easy.
  intros. apply H. simpl. right. easy. easy.
  destruct (var_eq_dec v k). subst.
  specialize (nth_no_appear k b0 AS H2) as eq1.
  apply eq1 in H. easy.
  specialize (IHAS env0 v b z H).
  assert ((forall a : Env.key * bound,
        In a AS -> ~ Env.In (elt:=tau) (fst a) env0)).
  intros. apply H0. simpl. right. easy.
  assert ((forall (x : Env.key) (b : bound),
        In (x, b) AS ->
        match b with
        | Num _ => True
        | Var y _ => Env.In (elt:=tau) y env0
        end)).
  intros. apply (H1 x). simpl. right. easy. 
  assert ((forall (n n' : nat) (a b : Env.key * bound),
        n <> n' ->
        nth_error AS n = Some a ->
        nth_error AS n' = Some b -> fst a <> fst b)).
  intros.
  specialize (H2 (S n0) (S n')).
  simpl in *.
  apply H2. lia. easy. easy.
  specialize (IHAS H3 H4 H5).
  rewrite IHAS.
  unfold subst_bound.
  easy.
Qed.


Lemma cast_as_same_bound : forall b S S' env AS b',
    sub_domain env S -> stack_consistent_grow S S' env ->
    well_bound_in env (subst_bounds b AS) ->
    (forall a, In a AS -> ~ Env.In (fst a) env) ->
     (forall x b, In (x,b) AS -> (match b with Num v => True | Var y v => Env.In y env end)) ->
     (forall a, In a AS -> Stack.In (fst a) S') ->
     (forall x b na ta, In (x,b) AS -> Stack.MapsTo x (na,ta) S' -> bound_eval S b = Some na) ->
    (forall n n' a b, n <> n' -> nth_error AS n = Some a -> nth_error AS n' = Some b -> fst a <> fst b) ->
      cast_bound S (subst_bounds b AS) = Some b' -> cast_bound S' b = Some b'.
Proof.
  intros. simpl in *. destruct b.
   assert (forall AS, subst_bounds (Num z) AS = Num z).
   {
    intros. induction AS0. simpl. easy.
    simpl. destruct a. easy.
   }
   rewrite H8 in H7. easy.
   specialize (Classical_Prop.classic (Env.In v env0)) as eq1.
   destruct eq1.
   rewrite cast_bound_in_env_same with (env0 := env0) in H7.
   unfold stack_consistent_grow in *.
   rewrite <- H7.
   unfold cast_bound.
   destruct (Stack.find (elt:=Z * tau) v S) eqn:eq1. destruct p.
   apply Stack.find_2 in eq1.
   apply H0 in eq1; try easy.
   apply Stack.find_1 in eq1. rewrite eq1. easy.
   unfold sub_domain in *.
   apply H in H8.
   destruct H8. apply Stack.find_1 in H8. rewrite eq1 in H8. easy.
   easy. easy. easy.
   specialize (well_bound_var_in_as AS v z env0 H8 H1) as eq1.
   destruct eq1.
   rewrite <- H7.
   apply H4 in H9 as eq2.
   destruct eq2. simpl in *. destruct x0.
   apply H5 with (b := x) in H10 as eq3; try easy.
   unfold bound_eval in eq3.
   apply Stack.find_1 in H10.
   rewrite H10.
   rewrite subst_bounds_only_one with (env := env0) (b := x); try easy.
   unfold subst_bound.
   destruct (var_eq_dec v v).
   destruct x. inv eq3. easy.
   unfold cast_bound.
   destruct (Stack.find (elt:=Z * tau) v0 S) eqn:eq1. destruct p. inv eq3.
   assert ((z + (z2 + z1)) = (z + z1 + z2)) by lia.
   rewrite H11. easy. inv eq3. easy.
Qed.

Lemma cast_as_same : forall t S S' env AS t',
    sub_domain env S -> stack_consistent_grow S S' env ->
     well_tau_bound_in env (subst_tau AS t) -> 
    (forall a, In a AS -> ~ Env.In (fst a) env) ->
     (forall x b, In (x,b) AS -> (match b with Num v => True | Var y v => Env.In y env end)) ->
     (forall a, In a AS -> Stack.In (fst a) S') ->
     (forall x b na ta, In (x,b) AS -> Stack.MapsTo x (na,ta) S' -> bound_eval S b = Some na) ->
    (forall n n' a b, n <> n' -> nth_error AS n = Some a -> nth_error AS n' = Some b -> fst a <> fst b) ->
     cast_tau_bound S (subst_tau AS t) t' ->
     cast_tau_bound S' t t'.
Proof.
   induction t; intros; simpl.
   assert (forall AS, subst_tau AS TInt = TInt).
   {
    intros. induction AS0. simpl. easy.
    simpl. easy.
   }
   rewrite H8 in H7. inv H7. constructor.
   simpl in *. 
   inv H7. constructor. apply IHt with (S := S) (env := env0) (AS := AS); try easy.
   inv H1. easy.
   assert (forall AS, subst_tau AS (TStruct s)  = (TStruct s) ).
   {
    intros. induction AS0. simpl. easy.
    simpl. easy.
   }
   rewrite H8 in H7. inv H7. constructor.
   simpl in *. inv H1. inv H7.
   constructor.
   rewrite cast_as_same_bound with (S := S) (env := env0) (AS := AS) (b' := l'); try easy.
   rewrite cast_as_same_bound with (S := S) (env := env0) (AS := AS) (b' := h'); try easy.
   apply IHt with (S := S) (AS := AS) (env := env0); try easy.
   simpl in *. inv H1. inv H7.
   constructor.
   rewrite cast_as_same_bound with (S := S) (env := env0) (AS := AS) (b' := l'); try easy.
   rewrite cast_as_same_bound with (S := S) (env := env0) (AS := AS) (b' := h'); try easy.
   apply IHt with (S := S) (AS := AS) (env := env0); try easy.
Qed.


Lemma stack_wf_out : forall tvl es D Q H env AS S S',
     sub_domain env S -> stack_wt D S -> stack_wf D Q env S ->
     env_wt D env -> stack_heap_consistent D Q H S ->
     (forall a, In a tvl -> ~ Env.In (fst a) env) ->
     (forall x n t ta, Env.MapsTo x t env -> Stack.MapsTo x (n,ta) S ->
           (exists t', cast_tau_bound S t t' /\ subtype D Q ta t')) ->
     (forall x n ta, Theta.MapsTo x GeZero Q -> Stack.MapsTo x (n,ta) S -> 0 <= n) ->
     (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b) ->
     (forall e, In e es -> (exists n t, e = ELit n t
                 /\ word_tau t /\ tau_wf D t /\ simple_tau t) \/ (exists y, e = EVar y)) ->
     @well_typed_args D Q H env AS es tvl ->
     eval_el AS S tvl es S' ->
       (forall x t, In (x,t) tvl ->
         exists v t',
           cast_tau_bound S (subst_tau AS t) t' /\
            Stack.MapsTo x (v,t') S' /\
            @well_typed_lit D Q H empty_scope v t').
Proof.
  intros.
  induction H11. inv H10. intros.
  inv H12.
  intros. inv H10.
  assert ((forall a : Env.key * tau,
             In a tvl ->
             ~ Env.In (elt:=tau) (fst a) env0)).
  intros. apply H5. simpl. right. easy.
  assert ((forall (n n' : nat) (a b : Env.key * tau),
             n <> n' ->
             nth_error tvl n = Some a ->
             nth_error tvl n' = Some b -> fst a <> fst b)).
  intros.
  specialize (H8 (S n0) (S n') a b).
  simpl in H8. apply H8; try easy. lia.
  assert ((forall e : expression,
             In e es ->
             (exists (n : Z) (t : tau),
                e = ELit n t /\ word_tau t /\ tau_wf D t /\ simple_tau t) \/
             (exists y : var, e = EVar y))).
  intros. apply H9. simpl. right. easy.
  specialize (IHeval_el H0 H1 H2 H4 H10 H6 H7 H14 H15 H22). clear H14. clear H15.
  simpl in H12. destruct H12. inv H12.
  inv H19. inv H11.
  exists n.
  apply simple_tau_means_cast_same with (s := s) in H12 as eq1.
  exists (subst_tau AS t).
  split. easy. 
  split.
  apply (cast_tau_bound_same s (subst_tau AS t) (subst_tau AS t) t' eq1) in H20.
  rewrite H20. apply Stack.add_1. easy.
  apply subtype_well_tau with (t := t'0); try easy.
  assert (In (ELit n t'0) (ELit n t'0 :: es)). simpl. left. easy.
  apply H9 in H11. destruct H11. destruct H11 as [na [ta [X1 [X2 [X3 X4]]]]].
  inv X1. apply subtype_tau_wf in H15. easy. easy. destruct H11. inv H11.
  inv H11.
  assert (well_tau_bound_in env0 t'0).
  apply H3 with (x := x0); easy.
  specialize (gen_cast_tau_bound_same env0 s t'0 H11 H0) as eq1.
  destruct eq1.
  apply cast_means_simple_tau in H16 as eq1.
  apply cast_means_simple_tau in H23 as eq2.
  specialize (H6 x0 n t'0 t'1 H12 H21) as eq3.
  destruct eq3. destruct H17.
  specialize (cast_tau_bound_same s t'0 x1 x2 H16 H17) as eq3. subst.
  unfold stack_wt in H1.
  specialize (cast_subtype_same t'0 D Q s x2 (subst_tau AS t) t' H15 H16 H23 H7) as eq3.
  assert (word_tau x2).
  apply cast_word_tau in H16; try easy.
  specialize (H3 x0 t'0 H12). easy.
  inv H19. inv eq3. inv H18. inv H23. inv H16.
  exists n. exists TInt.
  split. easy.
  split. apply Stack.add_1. easy.  apply TyLitInt.
  specialize (subtype_trans D Q t'1 t' m w H18 eq3) as eq4.
  exists n. exists t'. split. easy.
  split. apply Stack.add_1. easy.
  unfold stack_wf in *.
  specialize (H2 x0 t'0 H12).
  destruct H2 as [v [ta [tb [X1 [X2 X3]]]]].
  apply Stack.mapsto_always_same with (v1 := (n, t'1)) in X3 as eq6; try easy. inv eq6.
  apply H1 in X3 as X4. destruct X4 as [X3a [X3b X3c]].
  apply subtype_well_tau with (t := tb); try easy.
  apply subtype_tau_wf with (Q := Q) (t' := t')  in X3b. easy. easy.
  unfold stack_heap_consistent in *.
  apply H4 with (x := x0); try easy.
  simpl in *.
  specialize (IHeval_el H12).
  destruct IHeval_el as [v [ta [X1 [X2 X3]]]].
  exists v. exists ta.
  split. easy. split.
  apply nth_no_appear with (y := x) (w := t) in H8.
  apply Stack.add_2. easy. easy.
  easy. easy.
Qed.


Lemma well_tau_args_well_bound : forall D Q H env AS es tvl,
   @well_typed_args D Q H env AS es tvl -> 
   (forall x t, In (x,t) tvl -> well_tau_bound_in env (subst_tau AS t)).
Proof.
  intros. induction H0.
  simpl in *. easy. simpl in *.
  destruct H1.
  inv H1. inv H0.
  apply simple_tau_well_bound with (env := env0) in H1. easy.
  easy.
  apply IHwell_typed_args. easy.
Qed.

Lemma as_well_bound : forall AS D Q H env tvl es,
   @well_typed_args D Q H env AS es tvl -> 
     get_dept_map tvl es = Some AS -> 
    (forall x b, In (x,b) AS -> (match b with Num v => True | Var y v => Env.In y env end)).
Proof.
Admitted.

Lemma as_not_in_env : forall AS tvl es env,
     get_dept_map tvl es = Some AS -> length tvl = length es -> 
    (forall a, In a tvl -> ~ @Env.In tau (fst a) env) -> (forall a, In a AS -> ~ @Env.In tau (fst a) env).
Proof.
Admitted.

Lemma as_stack_in : forall AS tvl es S S',
     get_dept_map tvl es = Some AS -> eval_el AS S tvl es S' ->
    (forall a, In a AS -> Stack.In (fst a) S').
Proof.
Admitted.

Lemma as_stack_in_2 : forall AS tvl es S S',
     get_dept_map tvl es = Some AS -> eval_el AS S tvl es S' ->
    (forall a, In a AS -> Stack.In (fst a) S') -> 
(forall x b na ta, In (x,b) AS -> Stack.MapsTo x (na,ta) S' -> bound_eval S b = Some na).
Proof.
Admitted.

Lemma as_diff : forall AS tvl es,
     get_dept_map tvl es = Some AS -> length tvl = length es ->
   (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b) ->
   (forall n n' a b, n <> n' -> nth_error AS n = Some a -> nth_error AS n' = Some b -> fst a <> fst b).
Proof.
Admitted.


Definition theta_wt (Q:theta) (env:env) (S:stack) :=
     (forall x, Theta.In x Q -> Env.In x env)
  /\ (forall x n ta, Theta.MapsTo x GeZero Q -> Stack.MapsTo x (n,ta) S -> 0 <= n).

Lemma stack_wf_core : forall D Q env S, stack_wf D Q env S ->
    (forall x n t ta, Env.MapsTo x t env -> Stack.MapsTo x (n,ta) S ->
           (exists t', cast_tau_bound S t t' /\ subtype D Q ta t')).
Proof.
  intros.
  unfold stack_wf in *.
  specialize (H x t H0).
  destruct H as [v [t' [t'' [X1 [X2 X3]]]]].
  exists t'. split. easy.
  apply Stack.mapsto_always_same with (v1 := (v,t'')) in H1; try easy. inv H1.
  easy.
Qed.

Lemma stack_tvl_has : forall tvl AS S es S', eval_el AS S tvl es S'
        -> (forall x t, In (x,t) tvl -> exists n ta, Stack.MapsTo x (n,ta) S').
Proof.
  intros. induction H.
  simpl in *. easy.
  simpl in H0. destruct H0.
  inv H0. exists n. exists t'. apply Stack.add_1. easy.
  destruct (Nat.eq_dec x x0). subst.
  exists n. exists t'. apply Stack.add_1. easy.
  apply IHeval_el in H0.
  destruct H0. destruct H0.
  exists x1. exists x2.
  apply Stack.add_2. lia. easy.
Qed.


Lemma stack_wf_trans :
   forall D Q H env env' S S' AS tvl es,
   stack_wt D S -> sub_domain env S -> stack_wf D Q env S -> stack_heap_consistent D Q H S -> env_wt D env ->
     (forall a, In a tvl -> ~ Env.In (fst a) env) ->
     (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b) ->
     (forall x t, Env.MapsTo x t env' -> Env.MapsTo x t env \/ In (x,t) tvl) ->
     (forall x n ta, Theta.MapsTo x GeZero Q -> Stack.MapsTo x (n,ta) S -> 0 <= n) ->
     (forall e, In e es -> (exists n t, e = ELit n t
                 /\ word_tau t /\ tau_wf D t /\ simple_tau t) \/ (exists y, e = EVar y)) ->
     @well_typed_args D Q H env AS es tvl ->
     get_dept_map tvl es = Some AS ->
     eval_el AS S tvl es S' ->
      stack_wf D Q env' S'.
Proof.
  intros.
  assert (length tvl = length es) as eq1.
  rewrite (well_typed_args_same_length D Q H env0 AS es tvl); try easy.
  specialize (stack_consist_trans S S' env0 tvl es AS H1 H5 eq1 H12) as eq2.
  specialize (stack_wf_core D Q env0 S H2) as eq3.
  specialize (stack_wf_out tvl es D Q H env0 AS S S' H1 H0 H2 H4 H3 H5 eq3 H8 H6 H9 H10 H12) as eq4.
  unfold stack_wf in *.
  intros.
  apply H7 in H13.
  destruct H13. apply H2 in H13 as eq5. destruct eq5 as [v [ta [tb [X1 [X2 X3]]]]].
  exists v. exists ta. exists tb.
  split. apply stack_grow_cast_tau_same with (env := env0) (S := S); try easy.
  unfold env_wt in *.
  apply H4 in H13. easy. split. easy.
  unfold stack_consistent_grow in *.
  apply eq2; try easy. exists t. easy.
  apply eq4 in H13 as eq5.
  destruct eq5 as [v [ta [X1 [X2 X3]]]].
  exists v. exists ta. exists ta.
  split.
  apply cast_as_same with (S := S) (AS := AS) (env := env0); try easy.
  apply (well_tau_args_well_bound D Q H env0 AS es tvl) with (x := x); try easy.
  intros.
  apply (as_not_in_env AS tvl es env0); try easy.
  intros.
  apply (as_well_bound AS D Q H env0 tvl es) with (x := x0); try easy.
  intros. 
  apply (as_stack_in AS tvl es S S'); try easy.
  intros.
  apply (as_stack_in_2 AS tvl es S S') with (x := x0) (ta := ta0); try easy.
  apply (as_stack_in AS tvl es S S'); try easy.
  intros. 
  apply (as_diff AS tvl es) with (n := n) (n' := n'); try easy.
  split. constructor. easy.
Qed.

Lemma subtype_word_tau : forall D Q t t', subtype D Q t t' -> word_tau t -> word_tau t'.
Proof.
  intros.
  inv H. assumption.
  1-8:constructor.
Qed.

Lemma stack_heap_consistent_trans : forall tvl es D Q H env AS S S',
     sub_domain env S -> stack_wt D S -> stack_wf D Q env S ->
     env_wt D env -> stack_heap_consistent D Q H S ->
     (forall a, In a tvl -> ~ Env.In (fst a) env) ->
     (forall x n t ta, Env.MapsTo x t env -> Stack.MapsTo x (n,ta) S ->
           (exists t', cast_tau_bound S t t' /\ subtype D Q ta t')) ->
     (forall x n ta, Theta.MapsTo x GeZero Q -> Stack.MapsTo x (n,ta) S -> 0 <= n) ->
     (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b) ->
     (forall e, In e es -> (exists n t, e = ELit n t
                 /\ word_tau t /\ tau_wf D t /\ simple_tau t) \/ (exists y, e = EVar y)) ->
     @well_typed_args D Q H env AS es tvl ->
     eval_el AS S tvl es S' ->  stack_heap_consistent D Q H S'.
Proof.
  intros.
  induction H11. inv H10. easy.
  unfold stack_heap_consistent in *.
  intros. inv H10.
  assert ((forall a : Env.key * tau,
             In a tvl ->
             ~ Env.In (elt:=tau) (fst a) env0)).
  intros. apply H5. simpl. right. easy.
  assert ((forall (n n' : nat) (a b : Env.key * tau),
             n <> n' ->
             nth_error tvl n = Some a ->
             nth_error tvl n' = Some b -> fst a <> fst b)).
  intros.
  specialize (H8 (S n1) (S n') a b).
  simpl in H8. apply H8; try easy. lia.
  assert ((forall e : expression,
             In e es ->
             (exists (n : Z) (t : tau),
                e = ELit n t /\ word_tau t /\ tau_wf D t /\ simple_tau t) \/
             (exists y : var, e = EVar y))).
  intros. apply H9. simpl. right. easy.
  specialize (IHeval_el H0 H1 H2 H4 H10 H6 H7 H14 H15 H22). clear H14. clear H15.
  inv H11.
  inv H19.
  destruct (Nat.eq_dec x0 x). subst.
  apply Stack.mapsto_add1 in H13. inv H13.
  apply simple_tau_means_cast_same with (s := s) in H15 as eq1.
  apply cast_tau_bound_same with (t' := (subst_tau AS t)) in H18; try easy.
  rewrite <- H18.
  apply subtype_well_tau with (t := t'0); try easy.
  assert (In (ELit n t'0) (ELit n t'0 :: es)).
  simpl. left. easy. apply H9 in H11.
  destruct H11. destruct H11. destruct H11. destruct H11. inv H11.
  apply subtype_tau_wf with (Q := Q) (t := x1); try easy.
  destruct H11. inv H11.
  apply Stack.add_3 in H13.
  apply IHeval_el in H13. easy. lia.
  inv H19.
  apply H4 in H20 as eq1.
  destruct (Nat.eq_dec x0 x). subst.
  apply Stack.mapsto_add1 in H13. inv H13.
  unfold stack_wf in H2.
  apply H2 in H14 as eq2.
  destruct eq2 as [va [ta [tb [X1 [X2 X3]]]]].
  apply Stack.mapsto_always_same with (v1 := (n,t'0)) in X3; try easy. inv X3.
  assert (subtype D Q ta t').
  apply cast_subtype_same with (S := s) (t1 := t'1) (t2 := (subst_tau AS t)); try easy.
  assert (subtype D Q tb t').
  apply H1 in H20.
  assert (word_tau ta).
  apply (subtype_word_tau D Q tb); try easy.
  inv H13. inv H11. inv X2. constructor.
  apply subtype_trans with (m := m) (w := w); try easy.
  apply subtype_well_tau with (t := tb); try easy.
  apply H1 in H20.
  apply cast_means_simple_tau in H21. easy.
  apply subtype_tau_wf with (Q := Q) (t := tb); try easy.
  apply H1 in H20. easy.
  apply Stack.add_3 in H13.
  apply IHeval_el in H13. easy. lia.
Qed.

Lemma theta_grow_tau : forall D F S H env Q m e t,
  @well_typed D F S H env empty_theta m e t
   -> @well_typed D F S H env Q m e t.
Proof.
  intros. remember empty_theta as Q'. induction H0;subst;eauto.
  constructor.
Admitted.

Check List.find.

Definition tmem (l : list var) (x:var) := 
   match find (fun y => Nat.eqb x y) l with Some x => true | _ => false end.

Definition gen_rets_tau (S:stack) (x:var) (ta:tau) (e:expression) (t:tau) :=
   match ta with TInt => 
     match e with ELit v t' => if tmem (get_tvars t) x then Some (subst_tau [(x,Num v)] t) else Some t
                | EVar y => match Stack.find y S with None => None
                                  | Some (v,t') => 
                                 if tmem (get_tvars t) x then Some (subst_tau [(x,Num v)] t) else Some t
                            end
                | _ => None
     end
             | _ => Some t
   end.

Inductive gen_rets_taus (S:stack) : list (var * tau) -> (list expression) -> tau -> tau -> Prop :=
   | rets_tau_empty : forall t, gen_rets_taus S [] [] t t
   | rets_tau_many : forall x ta tvl e es t t' t'', gen_rets_taus S tvl es t t' -> 
                gen_rets_tau S x ta e t' = Some t'' ->
                gen_rets_taus S ((x,ta)::tvl) (e::es) t t''.

Lemma tmem_in : forall l x, tmem l x = true <-> In x l.
Proof.
  intros. split. unfold tmem. intros.
  destruct (find (fun y : nat => (x =? y)%nat) l) eqn:eq1.
  apply find_some in eq1. destruct eq1.
  apply Nat.eqb_eq in H1. subst. easy.
  apply find_none with (x := x) in eq1.
  apply Nat.eqb_neq in eq1. easy. easy.
  intros. unfold tmem.
  destruct (find (fun y : nat => (x =? y)%nat) l) eqn:eq1.
  apply find_some in eq1. destruct eq1.
  apply Nat.eqb_eq in H1. subst. easy.
  apply find_none with (x := x) in eq1.
  apply Nat.eqb_neq in eq1. easy. easy.
Qed.

Lemma well_typed_tau_nat : forall D F S H env Q m e t, 
         @well_typed D F S H env Q m e t -> expr_wf D F e -> (forall x, In x (get_tvars t) -> Env.MapsTo x TInt env).
Proof.
Admitted.

Lemma expr_wf_gen_rets : forall tvl es D F S AS e e',
     stack_wt D S -> 
     expr_wf D F e -> gen_rets AS S tvl es e e' ->
    (forall x t', In (x,t') tvl -> word_tau t' /\ tau_wf D t') ->
     expr_wf D F e'.
Proof.
  intros. induction H1. easy.
  specialize (H2 x t) as eq1.
  assert (In (x, t) ((x, t) :: xl)). simpl in *. left. easy.
  apply eq1 in H4. destruct H4.
  constructor.
  inv H3.
  unfold simple_option. split.
  apply cast_word_tau in H10; try easy.
  apply subst_tau_word_tau. easy.
  split.
  apply cast_tau_wf with (D:= D) in H10; try easy.
  apply subst_tau_tau_wf. easy.
  apply cast_means_simple_tau in H10. easy.
  unfold simple_option.
  assert (In (x, t) ((x, t) :: xl)). simpl in *. left. easy.
  apply eq1 in H3. destruct H3.
  split.
  apply cast_word_tau in H12; try easy.
  apply subst_tau_word_tau. easy.
  split.
  apply cast_tau_wf with (D:= D) in H12; try easy.
  apply subst_tau_tau_wf. easy.
  apply cast_means_simple_tau in H12. easy.
  unfold simple_option.
  destruct (Stack.find (elt:=Z * tau) x S) eqn:eq2.
  destruct p. unfold stack_wt in *.
  apply Stack.find_2 in eq2.
  apply H in eq2. easy. easy.
  apply IHgen_rets; try easy. intros.
  specialize (H2 x0 t'0).
  assert (In (x0, t'0) ((x, t) :: xl)). simpl. right. easy.
  apply H2 in H7. easy.
Qed.

Lemma well_typed_gen_rets : forall tvl es D F S S' H AS env Q m e t e' t',
       expr_wf D F e' ->
       @well_typed D F S' H env Q m e t -> 
       gen_rets AS S tvl es e e' ->
       gen_rets_taus S tvl es t t' ->
       (forall x t, In (x,t) tvl -> Env.MapsTo x t env) ->
       @well_typed D F S' H env Q m e' t'.
Proof.
  intros. generalize dependent t'.
  induction H2; intros. inv H3. easy.
  inv H5.
  apply IHgen_rets in H13 ; try easy.
  unfold gen_rets_tau in *.
  assert (t0 = TInt \/ t0 <> TInt).
  destruct t0. left. easy. 1-4:right; easy.
  destruct H5. subst.
   assert (forall AS, subst_tau AS TInt = TInt).
   {
    intros. induction AS0. simpl. easy.
    simpl. easy.
   }
  rewrite H5 in H3. inv H3. inv H10.
  destruct (tmem (get_tvars t'1) x) eqn:eq1.
  apply tmem_in in eq1. inv H14.
  apply TyRetTInt.
  specialize (H4 x TInt). simpl in *. exists TInt. apply H4. left. easy. easy. easy.
  assert (~ In x (get_tvars t'1)).
  intros R. apply tmem_in in R.
  rewrite eq1 in R. easy.
  inv H14. apply TyRet.
  specialize (H4 x TInt). simpl in *. exists TInt. apply H4. left. easy. easy. easy.
  inv H12.
  apply Stack.find_1 in H11. rewrite H11 in *.
  destruct (tmem (get_tvars t'1) x) eqn:eq1.
  apply tmem_in in eq1. inv H14.
  apply TyRetTInt.
  specialize (H4 x TInt). simpl in *. exists TInt. apply H4. left. easy. easy. easy.
  assert (~ In x (get_tvars t'1)).
  intros R. apply tmem_in in R.
  rewrite eq1 in R. easy.
  inv H14. apply TyRet.
  specialize (H4 x TInt). simpl in *. exists TInt. apply H4. left. easy. easy. easy.
  assert (match t0 with
      | TInt =>
          match e1 with
          | ELit v _ =>
              if tmem (get_tvars t'1) x
              then Some (subst_tau [(x, Num v)] t'1)
              else Some t'1
          | EVar y =>
              match Stack.find (elt:=Z * tau) y S with
              | Some (v, _) =>
                  if tmem (get_tvars t'1) x
                  then Some (subst_tau [(x, Num v)] t'1)
                  else Some t'1
              | None => None
              end
          | _ => None
          end
      | _ => Some t'1
      end = Some t'1).
  destruct t0; try easy. rewrite H6 in *. clear H6.
  inv H14.
  inv H0.
  specialize (well_typed_tau_nat D F S' H env0 Q m e' t'0 H13 H12) as eq1.
  apply TyRet.
  specialize (H4 x t0) as eq2.
  simpl in *. exists t0. apply eq2; try easy. left. easy.
  easy.
  intros R.
  apply eq1 in R.
  specialize (H4 x t0) as eq2.
  simpl in *. 
  assert ((x, t0) = (x, t0) \/ In (x, t0) xl). left. easy.
  apply eq2 in H0.
  apply Env.mapsto_always_same with (v1 := TInt) in H0; try easy.
  rewrite <- H0 in *. contradiction.
  inv H0. easy.
  intros. apply H4. simpl. right. easy.
Qed.

Lemma gen_arg_env_same : forall env tvl enva, gen_arg_env env tvl enva
      -> (forall n n' a b, n <> n' -> nth_error tvl n = Some a -> nth_error tvl n' = Some b -> fst a <> fst b)
       -> (forall x t, In (x,t) tvl -> Env.MapsTo x t enva).
Proof.
 intros. induction H.
 simpl in *. easy.
 specialize (nth_no_appear x0 t0 tvl H0) as eq1.
 simpl in *. destruct H1. inv H1.
 apply Env.add_1. easy.
 apply Env.add_2.
 apply eq1 in H1. easy.
 apply IHgen_arg_env; try easy.
 intros.
 specialize (H0 (S n) (S n') a b).
 apply H0. lia. simpl. easy. easy.
Qed.

Lemma get_dept_in_as : forall tvl es AS, 
   get_dept_map tvl es = Some AS -> (forall x, In (x,TInt) tvl -> (exists v, In (x,v) AS)).
Proof.
  induction tvl; intros;simpl in *. easy.
  destruct H0. subst.
  destruct es. inv H.
  destruct (get_good_dept e) eqn:eq1.
  destruct (get_dept_map tvl es) eqn:eq2. inv H.
  exists b. simpl. left. easy.
  inv H. inv H.
  destruct a. destruct t. destruct es. inv H.
  destruct (get_good_dept e) eqn:eq1.
  destruct (get_dept_map tvl es) eqn:eq2. inv H.
  specialize (IHtvl es l eq2 x H0).
  destruct IHtvl. exists x0. simpl. right. easy.
  inv H. inv H. destruct es. inv H.
  specialize (IHtvl es AS H x H0). destruct IHtvl. exists x0. easy.
  destruct es. inv H.
  specialize (IHtvl es AS H x H0). destruct IHtvl. exists x0. easy.
  destruct es. inv H.
  specialize (IHtvl es AS H x H0). destruct IHtvl. exists x0. easy.
  destruct es. inv H.
  specialize (IHtvl es AS H x H0). destruct IHtvl. exists x0. easy.
Qed.


Lemma gen_rets_as_cast_same:
   forall tvl D Q H env es AS S t t', get_dept_map tvl es = Some AS ->
   stack_wf D Q env S ->
   gen_rets_taus S tvl es t t' -> 
   well_bound_vars_type tvl t ->
   @well_typed_args D Q H env AS es tvl ->
   cast_tau_bound S (subst_tau AS t) t'.
Proof.
Admitted.

Lemma gen_rets_tau_exists:
   forall tvl D Q H env es AS S t, 
   sub_domain env S -> 
   get_dept_map tvl es = Some AS ->
   @well_typed_args D Q H env AS es tvl ->
   (exists t', gen_rets_taus S tvl es t t').
Proof.
Admitted.


Lemma call_t_in_env : forall tvl D Q H env es AS t,
   well_bound_vars_type tvl t ->
   get_dept_map tvl es = Some AS ->
   @well_typed_args D Q H env AS es tvl ->
   well_tau_bound_in env (subst_tau AS t).
Proof.
Admitted.

Lemma stack_grow_well_typed:
   forall D F S S' H env Q m e t,
     stack_consistent_grow S S' env -> @well_typed D F S H env Q m e t
     -> @well_typed D F S' H env Q m e t.
Proof.
Admitted.

Lemma well_typed_exchange_strlen :
    forall D env Q S H l x y n n' e m t t0 ta l0 h0, stack_wt D S -> stack_wf D Q env S
      -> stack_heap_consistent D Q H S -> theta_wt Q env S 
      -> heap_wf D H -> heap_wt_all D Q H ->
      env_wt D env -> ~ Env.In (elt:=tau) x env ->
     ~ In x (get_tvars t) -> 0 <= n' -> 
      @well_typed D (fenv) S H
        (Env.add x TInt
           (Env.add y (TPtr C (TNTArray l (Var x 0) ta)) env))
        (Theta.add x GeZero Q) C e t
    ->
   @well_typed D (fenv) (change_strlen_stack S y m t0 l0 n n' h0) H
     (Env.add x TInt (Env.add y (TPtr C (TNTArray l (Num n') ta)) env)) Q
      C e t.
Proof.
  intros.
Admitted.

Lemma well_bound_grow_env :
    forall env enva b, (forall x t, Env.MapsTo x t env -> Env.MapsTo x t enva) -> 
     well_bound_in env b -> well_bound_in enva b.
Proof.
   intros. induction b.
   apply well_bound_in_num.
   apply well_bound_in_var. inv H0.
   apply H. easy.
Qed.

Lemma well_tau_bound_grow_env :
        forall env enva t, (forall x t, Env.MapsTo x t env -> Env.MapsTo x t enva) -> 
         well_tau_bound_in env t -> well_tau_bound_in enva t.
Proof.
   intros. induction t.
   apply well_tau_bound_in_nat.
   apply well_tau_bound_in_ptr.
   apply IHt. inv H0. assumption.
   apply well_tau_bound_in_struct.
   apply well_tau_bound_in_array.
   apply well_bound_grow_env with (env := env0); try easy. inv H0. assumption.
   apply well_bound_grow_env with (env := env0); try easy. inv H0. assumption.
   inv H0. apply IHt. assumption.
   apply well_tau_bound_in_ntarray.
   apply well_bound_grow_env with (env := env0); try easy. inv H0. assumption.
   apply well_bound_grow_env with (env := env0); try easy. inv H0. assumption.
   inv H0. apply IHt. assumption.
Qed.

Module StackFacts := FMapFacts.Facts (Stack).

Lemma cast_bound_not_nat :
   forall env S b b' x n ta m tb, sub_domain env S -> well_bound_in env b ->
     Env.MapsTo x (TPtr m tb) env ->
     cast_bound S b = Some b' -> 
     cast_bound (Stack.add x (n,ta) S) b = Some b'.
Proof.
  intros. unfold cast_bound in *. destruct b. easy.
  inv H0.
  destruct (Stack.find (elt:=Z * tau) v (Stack.add x (n, ta) S) ) eqn:eq1. destruct p.
  apply Stack.find_2 in eq1.
  destruct (Stack.find (elt:=Z * tau) v S) eqn:eq2.
  apply Stack.find_2 in eq2. destruct p.
  destruct (Nat.eq_dec x v). subst.
  apply Env.mapsto_always_same with (v1 := TInt) in H1; try easy.
  apply Stack.add_3 in eq1; try easy.
  apply Stack.mapsto_always_same with (v1 := (z1, t0)) in eq1; try easy. inv eq1. easy.
  destruct (Nat.eq_dec x v). subst.
  apply Env.mapsto_always_same with (v1 := TInt) in H1; try easy.
  apply Stack.add_3 in eq1.
  apply Stack.find_1 in eq1. rewrite eq1 in eq2. inv eq2.
  easy.
  destruct (Stack.find (elt:=Z * tau) v S) eqn:eq2.
  apply Stack.find_2 in eq2.
  destruct (Nat.eq_dec x v). subst.
  apply Env.mapsto_always_same with (v1 := TInt) in H1; try easy.
  apply StackFacts.not_find_in_iff in eq1.
  assert (Stack.In (elt:=Z * tau) v (Stack.add x (n, ta) S)).
  exists p.
  apply Stack.add_2. easy. easy. contradiction. easy.
Qed.

Lemma cast_tau_bound_not_nat :
   forall env S t t' x n ta m tb, sub_domain env S -> well_tau_bound_in env t ->
     Env.MapsTo x (TPtr m tb) env ->
     cast_tau_bound S t t' -> 
     cast_tau_bound (Stack.add x (n,ta) S) t t'.
Proof.
  intros. induction H2. constructor.
  constructor. apply IHcast_tau_bound. inv H0. easy.
  constructor. apply cast_bound_not_nat with (env := env0) (m := m) (tb := tb); try easy.
  inv H0. easy.
  apply cast_bound_not_nat with (env := env0) (m := m) (tb := tb); try easy.
  inv H0. easy.
  apply IHcast_tau_bound. inv H0. easy.
  constructor. apply cast_bound_not_nat with (env := env0) (m := m) (tb := tb); try easy.
  inv H0. easy.
  apply cast_bound_not_nat with (env := env0) (m := m) (tb := tb); try easy.
  inv H0. easy.
  apply IHcast_tau_bound. inv H0. easy.
  constructor.
Qed.

Lemma replicate_nth_anti {A:Type} : forall (n k : nat) (x : A),
    (k < n)%nat -> nth_error (replicate n x) k = Some x.
  Proof.
    induction n; intros k w H.
    - lia.
    - simpl. destruct k. simpl. easy.
      assert (k < n)%nat by lia.
      apply IHn with (x := w) in H0. simpl. easy. 
Qed.

Lemma alloc_correct : forall w D Q H ptr H',
    simple_tau w ->
    allocate D H w = Some (ptr, H') ->
    structdef_wf D ->
    heap_wf D H ->
    @heap_consistent D Q H' H /\
    well_typed_lit D Q H empty_scope ptr (TPtr C w) /\
    heap_wf D H'.
Proof.
  intros. 
Admitted.

(* Type Preservation Theorem. *)
Lemma preservation : forall D S H env Q e t S' H' e',
    @structdef_wf D ->
    heap_wf D H ->
    heap_wt_all D Q H ->
    fun_wf D fenv S' H' ->
    expr_wf D fenv e ->
    stack_wt D S ->
    env_wt D env ->
    theta_wt Q env S ->
    sub_domain env S ->
    stack_wf D Q env S ->
    stack_heap_consistent D Q H S ->
    @well_typed D fenv S H env Q C e t ->
    @reduce D (fenv env) S H e C S' H' (RExpr e') ->
    exists env' Q',
      sub_domain env' S' /\ stack_wf D Q' env' S' 
        /\ stack_heap_consistent D Q' H' S' /\
      @heap_consistent D Q H' H 
   /\ (@well_typed D fenv S' H' env' Q' C e' t
       \/ (exists t' t'', cast_tau_bound S' t t' 
        /\ subtype D Q' t'' t' /\ @well_typed D fenv S' H' env' Q' C e' t'')).
Proof with eauto 20 with Preservation.
  intros D s H env Q e t s' H' e' HDwf HHwf HHWt HFun HEwf Hswt Henvt HQt HSubDom HSwf HSHwf Hwt.
  generalize dependent H'. generalize dependent s'.  generalize dependent e'.
  remember C as m.
  induction Hwt as [
                     env Q m n t HTyLit                                         | (* Literals *)
                     env Q m x t Wb                                             | (* Variables *)
                     env Q AS m m' es x tvl e t HMap HGen HMode HArg            | (* Call *)
                     env Q m x h l t Wb                                         | (* Strlen *)
                     env Q m x y e l h t ta Alpha Wb HTy IH Hx                  | (* LetStrlen *)
                     env Q m x e1 e2 t b Alpha HTy1 IH1 HTy2 IH2 Hx Hdept       | (* Let-Nat-Expr *)
                     env Q m x e1 t1 e2 t Alpha HTy1 IH1 HTy2 IH2 Hx            | (* Let-Expr *)
                     env Q m x na a e t HIn Hx HTy1 IH1                         | (* RetNat *)
                     env Q m x na ta a e t HIn HTy1 IH1 Hx                      | (* Ret *)
                     env Q m e1 e2 HTy1 IH1 HTy2 IH2                            | (* Addition *)
                     env Q m e m' T fs i fi ti HTy IH HWf1 HWf2                 | (* Field Addr *)
                     env Q m w Wb                                               | (* Malloc *)
                     env Q m e t HTy IH                                         | (* U *)
                     env Q m t e t' Wb HChkPtr HTy IH                           | (* Cast - nat *)
                     env Q m t e t' Wb HTy IH HSub                              | (* Cast - subtype *)
                     env Q m e x y u v t t' Wb HTy IH Teq                       | (* DynCast - ptr array *)
                     env Q m e x y t t' HNot Teq Wb HTy IH                      | (* DynCast - ptr array from ptr *)
                     env Q m e x y u v t t' Wb Teq HTy IH                       | (* DynCast - ptr nt-array *)
                     env Q m e m' t l h t' t'' HTy IH HSub HPtrType HMode       | (* Deref *)
                     env Q m e1 m' l h e2 t WT Twf HTy1 IH1 HTy2 IH2 HMode                      | (* Index for array pointers *)
                     env Q m e1 m' l h e2 t WT Twf HTy1 IH1 HTy2 IH2 HMode                      | (* Index for ntarray pointers *)
                     env Q m e1 e2 m' t t1 HSub WT HTy1 IH1 HTy2 IH2 HMode                      | (* Assign normal *)
                     env Q m e1 e2 m' l h t t' WT Twf HSub HTy1 IH1 HTy2 IH2 HMode              | (* Assign array *)
                     env Q m e1 e2 m' l h t t' WT Twf HSub HTy1 IH1 HTy2 IH2 HMode              | (* Assign nt-array *)

                     env Q m e1 e2 e3 m' l h t t' WT Twf TSub HTy1 IH1 HTy2 IH2 HTy3 IH3 HMode      |  (* IndAssign for array pointers *)
                     env Q m e1 e2 e3 m' l h t t' WT Twf TSub HTy1 IH1 HTy2 IH2 HTy3 IH3 HMode      |  (* IndAssign for ntarray pointers *)
                     env Q m m' x t t1 e1 e2 t2 t3 t4 HEnv TSub HPtr HTy1 IH1 HTy2 IH2 HJoin HMode  | (* IfDef *)
                     env Q m m' x l t e1 e2 t2 t3 t4 HEnv HTy1 IH1 HTy2 IH2 HJoin HMode             | (* IfDefNT *)
                     env Q m e1 e2 e3 t2 t3 t4 HTy1 IH1 HTy2 IH2 HTy3 IH3 HJoin (* If *)
                 ]; intros e' s' H' HFun Hreduces; subst.
  (* T-Lit, impossible because values do not step *)
  - exfalso. eapply lit_are_nf...
  (* T-Var *)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst. inv H5. exists env. exists Q.
    split. easy.
    split. assumption.
    split. easy.
    split. unfold heap_consistent. eauto.
    right. unfold stack_wf in HSwf.
    unfold stack_heap_consistent in *.
    specialize (HSwf x t Wb) as eq2.
    destruct eq2 as [ vx [ t' [t'' [X1 [X2 X3]]]]].
    specialize (Stack.mapsto_always_same (Z*tau) x (vx, t'') (v, t0) s' X3 H10) as eq1.
    inv eq1.
    exists t'. exists t0.
    split. easy. split. easy.
    apply TyLit.
    apply HSHwf with (x := x). easy.
  (*T-Call*)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst. inv H5.
    rewrite H6 in HMap. inv HMap.
    specialize (gen_arg_env_good tvl env) as X1.
    destruct X1 as [enva X1]. rewrite H10 in HGen. inv HGen.
    specialize (sub_domain_grows tvl es env enva s s' AS X1 H13 HSubDom) as X2.
    exists enva. exists Q.
    split. easy.
    split. 
    apply (stack_wf_trans D Q H' env enva s s' AS tvl es); try easy.
    unfold fun_wf in *.
    destruct (HFun env enva x tvl t e m' H6 X1) as [Y1 [Y2 Y3]]. easy.
    destruct (HFun env enva x tvl t e m' H6 X1) as [Y1 [Y2 Y3]]. easy.
    intros.
    specialize (gen_arg_env_has_all tvl env enva X1 x0 t0 H) as eq1. easy.
    unfold theta_wt in *. destruct HQt. easy.
    inv HEwf. easy.
    split.
    apply (stack_heap_consistent_trans tvl es D Q H' env AS s s'); try easy.
    unfold fun_wf in *.
    destruct (HFun env enva x tvl t e m' H6 X1) as [Y1 [Y2 Y3]]. easy.
    unfold stack_wf in *. intros. specialize (HSwf x0 t0 H).
    destruct HSwf as [va [tc [td [Y1 [Y2 Y3]]]]].
    apply Stack.mapsto_always_same with (v1 := (n,ta)) in Y3; try easy. inv Y3.
    exists tc. easy.
    unfold theta_wt in *. destruct HQt. easy.
    destruct (HFun env enva x tvl t e m' H6 X1) as [Y1 [Y2 Y3]]. easy.
    inv HEwf. easy.
    split.
    easy.
    destruct (HFun env enva x tvl t e m' H6 X1) as [Y1 [Y2 [Y3 [Y4 [Y5 [Y6 [Y7 Y8]]]]]]].
    left. destruct m'. 2: { assert (U = U) by easy. apply HMode in H. easy. } 
    specialize (gen_rets_tau_exists tvl D Q H' env es AS s t HSubDom H10 HArg) as eq1.
    destruct eq1.
    specialize (gen_rets_as_cast_same tvl D Q H' env es AS s t x0 H10 HSwf H Y6 HArg) as eq1.
    apply theta_grow_tau with (Q := Q) in Y8.
    assert (forall x t', In (x,t') tvl -> word_tau t' /\ tau_wf D t').
    intros. apply Y1 in H1. easy.
    specialize (expr_wf_gen_rets tvl es D fenv s AS e e' Hswt Y7 H14 H1) as eq2.
    specialize (gen_arg_env_same env tvl enva X1 Y3) as eq3.
    specialize (well_typed_gen_rets tvl es D (fenv) s s' H' AS enva
               Q C e t e' x0 eq2 Y8 H14 H eq3) as eq4.
    specialize (call_t_in_env tvl D Q H' env es AS t Y6 H10 HArg) as eq5.
    assert (length tvl = length es) as eq6.
    rewrite (well_typed_args_same_length D Q H' env AS es tvl); try easy.
    specialize (stack_consist_trans s s' env tvl es AS HSubDom Y2 eq6 H13) as eq7.
    inv Y4.
    apply TyCast with (t' := x0); try easy.
   assert (forall AS, subst_tau AS TInt = TInt).
   {
    intros. induction AS0. simpl. easy.
    simpl. easy.
   }
   rewrite H2. constructor.
   destruct m. simpl. 
   apply TyCastCheckedPtr with (t' := x0); try easy.
   apply well_tau_bound_grow_env with (env := env).
   apply gen_arg_env_grow_1 with (tvl := tvl); try easy.
   inv eq5. easy.
   simpl in eq1.
   apply subtype_left with (t2' := x0).
   apply cast_means_simple_tau in eq1. easy.
   apply stack_grow_cast_tau_same with (env := env) (S := s); try easy.
   constructor.
    apply TyCast with (t' := x0); try easy.
   simpl in *.
   apply well_tau_bound_grow_env with (env := env).
   apply gen_arg_env_grow_1 with (tvl := tvl); try easy.
   easy.
  (*T-Strlen*)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst. inv H5. exists env. exists Q.
    split.
    unfold change_strlen_stack.
    unfold sub_domain in *.
    intros. destruct (n' <=? h0).
    apply HSubDom. easy.
    destruct (Nat.eq_dec x0 x). subst.
    exists (n, TPtr m (TNTArray (Num l0) (Num n') t0)).
    apply Stack.add_1. easy.
    apply HSubDom in H.
    destruct H.
    exists x1.
    apply Stack.add_2. lia. easy.
    split.
    unfold stack_wf in *. intros.
    unfold change_strlen_stack. 
    destruct (Nat.eq_dec x0 x). subst.
    unfold stack_wt in *.
    apply Hswt in H8 as eq1. destruct eq1 as [X1 [X2 X3]].
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1.
    specialize (HSwf x t2 H). easy.
    apply Z.leb_nle in eq1.
    specialize (HSwf x (TPtr C (TNTArray h l t)) Wb).
    destruct HSwf as [va [ta [tb [Y1 [Y2 Y3]]]]].
    apply Stack.mapsto_always_same with (v1 := (va,tb)) in H8; try easy.
    inv H8.
    apply Env.mapsto_always_same with (v1 := t2) in Wb; try easy. subst.
    exists n. exists ta. exists (TPtr m (TNTArray (Num l0) (Num n') t0)).
    assert (subtype D Q (TPtr m (TNTArray (Num l0) (Num n') t0)) (TPtr m (TNTArray (Num l0) (Num h0) t0))).
    apply SubTyNtSubsume.
    constructor. easy. constructor. lia.
    split. apply Henvt in H as eq2. destruct eq2 as [Y5 [Y6 Y7]].
    apply cast_tau_bound_not_nat with (env := env) (m := C) (tb := ((TNTArray h l t))); try easy.
    split.
    apply subtype_trans with (m := m) (w := (TNTArray (Num l0) (Num h0) t0)); try easy.
    apply Stack.add_1. easy.
    specialize (HSwf x0 t2 H).
    destruct HSwf as [va [ta [tb [X1 [X2 X3]]]]].
    exists va.  exists ta. exists tb.
    split.
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1. easy.
    apply Z.leb_nle in eq1.
    apply cast_tau_bound_not_nat with (env := env) (m := C) (tb := ((TNTArray h l t))); try easy.
    apply Henvt in H as eq2. destruct eq2 as [Y5 [Y6 Y7]]. easy.
    split. easy.
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1. easy.
    apply Z.leb_nle in eq1.
    apply Stack.add_2. lia. easy.
    split.
    unfold stack_heap_consistent in *.
    intros.
    unfold change_strlen_stack in H.
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1.
    apply HSHwf with (x := x0); try easy.
    apply Z.leb_nle in eq1.
    destruct (Nat.eq_dec x0 x). subst.
    apply Stack.mapsto_add1 in H. inv H.
    apply HSHwf in H8 as eq3. inv eq3. constructor. constructor.
    solve_empty_scope.
    unfold allocate_meta in *. 
    unfold scope_set_add in *. inv H3. inv H2. inv H11.
    apply TyLitC with (w := ((TNTArray (Num l0) (Num n') t0)))
     (b := l0) (ts := (Zreplicate (n' - l0 + 1) t0)); eauto.
    constructor. easy. apply SubTyRefl.
    intros.
    unfold scope_set_add.
    destruct (n' - l0 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
    rewrite replicate_gt_eq in H; try easy.
    rewrite <- Hp in *. assert (l0 + (n' - l0 + 1) = n' + 1) by lia.
    rewrite H2 in *. clear H2.
    specialize (H12 n) as eq2.
    assert (n <= n < n + n' + 1) by lia.
    apply eq2 in H2. clear eq2.
    specialize (H13 0) as eq2.
    assert (l0 <= 0 < l0 + Z.of_nat (length (Zreplicate (h0 - l0 + 1) t0))).
    rewrite replicate_gt_eq; try lia.
    apply eq2 in H3. clear eq2.
    destruct H3 as [na [ta [X1 [X2 X3]]]].
    destruct H2 as [nb [X4 X5]].
    rewrite Z.add_0_r in X2.
    apply Heap.mapsto_always_same with (v1 := (nb,t1)) in X2; try easy. inv X2.
    symmetry in X1.
    destruct (h0 - l0 + 1) as [| p1 | ?] eqn:Hp1; zify; [lia | |lia].
    unfold Zreplicate in X1.
    apply replicate_nth in X1. subst.
    destruct (Z_ge_dec h0 k).
    specialize (H13 k).
    assert (l0 <= k < l0 + Z.of_nat (length (Zreplicate (Z.pos p1) ta))).
    rewrite replicate_gt_eq; try lia.
    apply H13 in H2. destruct H2 as [nc [tc [Y1 [Y2 Y3]]]].
    exists nc. exists tc.
    split. unfold Zreplicate in *.
    symmetry in Y1.
    apply replicate_nth in Y1. subst.
    rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    specialize (H12 (n+k)).
    assert (n <= n + k < n + n' + 1) by lia.
    apply H12 in H2.
    destruct H2 as [nb [Y1 Y2]].
    apply HHWt in Y1 as eq2.
    exists nb. exists ta.
    split. unfold Zreplicate. rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    inv H10. inv H10. inv H2. inv H17. inv H10.
    destruct (Z_ge_dec h2 n').
    apply subtype_well_tau with (t := (TPtr C (TNTArray (Num l2) (Num h2) t0))); try easy.
    constructor. constructor. easy.
    constructor. apply Hswt in H8. constructor.
    destruct H8. destruct H2. inv H2. inv H14. easy.
    destruct H8 as [Y1 [Y2 Y3]]. inv Y2. inv H2. easy.
    apply TyLitC with (w := (TNTArray (Num l2) 
           (Num h2) t0)) (b := l2) (ts := Zreplicate (h2 - l2 + 1) t0); try easy.
    constructor. easy.
    constructor. intros.
    unfold scope_set_add.
    inv H11.
    specialize (H13 k H). easy.
    apply SubTyNtSubsume. constructor. lia. constructor. lia.
    inv H11.
    apply TyLitC with (w := ((TNTArray (Num l0) (Num n') t0)))
     (b := l0) (ts := (Zreplicate (n' - l0 + 1) t0)); eauto.
    constructor. easy. apply SubTyRefl.
    intros.
    unfold scope_set_add.
    destruct (n' - l0 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
    rewrite replicate_gt_eq in H; try easy.
    rewrite <- Hp in *. assert (l0 + (n' - l0 + 1) = n' + 1) by lia.
    rewrite H2 in *. clear H2.
    specialize (H12 n) as eq2.
    assert (n <= n < n + n' + 1) by lia.
    apply eq2 in H2. clear eq2.
    specialize (H13 0) as eq2.
    assert (l2 <= 0 < l2 + Z.of_nat (length (Zreplicate (h2 - l2 + 1) t0))).
    rewrite replicate_gt_eq; try lia.
    apply eq2 in H10. clear eq2.
    destruct H10 as [na [ta [X1 [X2 X3]]]].
    destruct H2 as [nb [X4 X5]].
    rewrite Z.add_0_r in X2.
    apply Heap.mapsto_always_same with (v1 := (nb,t1)) in X2; try easy. inv X2.
    symmetry in X1.
    destruct (h2 - l2 + 1) as [| p1 | ?] eqn:Hp1; zify; [lia | |lia].
    unfold Zreplicate in X1.
    apply replicate_nth in X1. subst.
    destruct (Z_ge_dec h2 k).
    specialize (H13 k).
    assert (l2 <= k < l2 + Z.of_nat (length (Zreplicate (Z.pos p1) ta))).
    rewrite replicate_gt_eq; try lia.
    apply H13 in H2. destruct H2 as [nc [tc [Y1 [Y2 Y3]]]].
    exists nc. exists tc.
    rewrite Hp.
    split. unfold Zreplicate in *.
    symmetry in Y1.
    apply replicate_nth in Y1. subst.
    rewrite replicate_nth_anti. easy. lia. easy.
    specialize (H12 (n+k)).
    assert (n <= n + k < n + n' + 1) by lia.
    apply H12 in H2.
    destruct H2 as [nb [Y1 Y2]].
    apply HHWt in Y1 as eq2.
    exists nb. exists ta.
    split. unfold Zreplicate. rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    apply Stack.add_3 in H. apply HSHwf in H. easy. lia.
    split. easy.
    left. constructor. constructor.
  (*T-LetStrlen*)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst. inv H5. 
    assert (forall E' e', in_hole e' E' = EStrlen y -> E' = CHole).
    { induction E';intros;simpl in *;eauto.
      1-12:inv H0.
    }
    apply H0 in H3 as eq1. subst. rewrite hole_is_id in *. subst.
    inv H5.
    simpl in *. 
    exists (Env.add y (TPtr C (TNTArray l (Num n') ta)) env). exists Q.
    split.
    unfold change_strlen_stack.
    unfold sub_domain in *.
    intros. destruct (n' <=? h0).
    apply HSubDom.
    destruct (Nat.eq_dec x0 y). subst.
    exists (TPtr C (TNTArray l h ta)). easy.
    destruct H. apply Env.add_3 in H. exists x1. easy. lia.
    destruct (Nat.eq_dec x0 y). subst.
    exists (n, TPtr m (TNTArray (Num l0) (Num n') t0)).
    apply Stack.add_1. easy.
    destruct H. apply Env.add_3 in H.
    assert (Env.In x0 env). exists x1. easy.
    apply (HSubDom) in H2.
    destruct H2.
    exists x2.
    apply Stack.add_2. lia. easy. lia.
    split.
    unfold stack_wf in *. intros.
    unfold change_strlen_stack. 
    destruct (Nat.eq_dec x0 y). subst.
    unfold stack_wt in *.
    apply Hswt in H10 as eq1. destruct eq1 as [X1 [X2 X3]].
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1.
    apply Env.mapsto_add1 in H as eq2. subst.
    specialize (HSwf y (TPtr C (TNTArray l h ta)) Wb).
    destruct HSwf as [va [ta' [tb [Y1 [Y2 Y3]]]]].
    inv Y1. inv H5.
    apply Stack.mapsto_always_same with (v1 := (va,tb)) in H10; try easy.
    inv H10. inv Y2.
    exists n. exists (TPtr C (TNTArray (Num l0) (Num n') t'0)).
    exists (TPtr C (TNTArray (Num l0) (Num h0) t'0)).
    split. constructor. constructor.
    easy. easy. easy. split. apply SubTyNtSubsume. constructor. easy. constructor. easy. easy.
    inv X2. inv H3. inv H10. inv H4.
    exists n. exists (TPtr C (TNTArray (Num h1) (Num n') t'0)).
    exists (TPtr C (TNTArray (Num l0) (Num h0) t'0)).
    split. constructor. constructor.
    easy. easy. easy. split. apply SubTyNtSubsume. constructor. easy. constructor. easy. easy.
    unfold cast_bound in H11. destruct l. inv H11. destruct (Stack.find (elt:=Z * tau) v s).
    destruct p. inv H11. inv H11.
    apply Z.leb_nle in eq1.
    specialize (HSwf y (TPtr C (TNTArray l h ta)) Wb).
    destruct HSwf as [va [ta' [tb [Y1 [Y2 Y3]]]]].
    apply Stack.mapsto_always_same with (v1 := (va,tb)) in H10; try easy.
    inv H10.
    apply Env.mapsto_add1 in H as eq2. subst. inv Y2.
    exists n. exists  (TPtr m (TNTArray (Num l0) (Num n') t0)). exists (TPtr m (TNTArray (Num l0) (Num n') t0)).
    assert (subtype D Q (TPtr m (TNTArray (Num l0) (Num n') t0)) (TPtr m (TNTArray (Num l0) (Num n') t0))).
    constructor. split.
    apply cast_tau_bound_not_nat with (env := (Env.add y (TPtr C (TNTArray l (Num n') ta)) env)) 
     (m := C) (tb := (TNTArray l (Num n') ta)); try easy.
    unfold sub_domain. intros. destruct H3.
    destruct (Nat.eq_dec x0 y). subst. 
    exists ((n, TPtr m (TNTArray (Num l0) (Num h0) t0)) ). easy.
    apply Env.add_3 in H3. apply HSubDom. exists x1. easy. lia.
    apply weakening_tau_bound with (ta := (TPtr C (TNTArray l h ta))); try easy.
    apply Henvt in Wb as eq2. destruct eq2 as [Y5 [Y6 Y7]].
    inv Y7. inv H5. constructor. constructor. easy. constructor. easy.
    inv Y1. inv H4. constructor. constructor; try easy.
    split. constructor. apply Stack.add_1. easy. inv H4.
    inv Y1. inv H3. inv H11. inv Y1. inv H3. inv H11. inv H12.
    inv Y1. inv H4.
    exists n. exists  (TPtr C (TNTArray (Num h1) (Num n') t0)).
    exists (TPtr C (TNTArray (Num l0) (Num n') t0)).
    split.
    apply cast_tau_bound_not_nat with (env := (Env.add y (TPtr C (TNTArray (Num l0) (Num n') ta)) env)) 
     (m := C) (tb := (TNTArray (Num l0) (Num n') ta)); try easy.
    unfold sub_domain. intros. destruct H2.
    destruct (Nat.eq_dec x0 y). subst. 
    exists ((n, TPtr C (TNTArray (Num l0) (Num h0) t0)) ). easy.
    apply Env.add_3 in H2. apply HSubDom. exists x1. easy. lia.
    apply weakening_tau_bound with (ta := (TPtr C (TNTArray l h ta))); try easy.
    apply Henvt in Wb as eq2. destruct eq2 as [Y5 [Y6 Y7]].
    inv Y7. inv H10. constructor. constructor. easy. constructor. easy.
    apply Env.add_1. easy.
    constructor. constructor; try easy.
    split. constructor. constructor. easy. constructor. easy.
    apply Stack.add_1. easy.
    inv Y1. inv H5.
    destruct l. inv H15. unfold cast_bound in H15.
    destruct (Stack.find (elt:=Z * tau) v s). destruct p. inv H15. inv H15.
    apply Env.add_3 in H; try lia. apply HSwf in H as eq1.
    destruct eq1 as [va [ta' [tb [Y5 [Y6 Y7]]]]].
    exists va. exists ta'. exists tb.
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1.
    easy.
    apply Z.leb_nle in eq1.
    split. 
    apply cast_tau_bound_not_nat with (env := env) 
     (m := C) (tb := (TNTArray l h ta)); try easy.
    apply Henvt in H. easy.
    split. easy.
    apply Stack.add_2. lia. easy.
    split.
    unfold stack_heap_consistent in *.
    intros.
    unfold change_strlen_stack in H.
    destruct (n' <=? h0) eqn:eq1. apply Z.leb_le in eq1.
    apply HSHwf with (x := x0); try easy.
    apply Z.leb_nle in eq1.
    destruct (Nat.eq_dec x0 y). subst.
    apply Stack.mapsto_add1 in H. inv H.
    apply HSHwf in H10 as eq3. inv eq3. constructor. constructor.
    solve_empty_scope.
    unfold allocate_meta in *. 
    unfold scope_set_add in *. inv H4. inv H3. inv H12.
    apply TyLitC with (w := ((TNTArray (Num l0) (Num n') t0)))
     (b := l0) (ts := (Zreplicate (n' - l0 + 1) t0)); eauto.
    constructor. easy. apply SubTyRefl.
    intros.
    unfold scope_set_add.
    destruct (n' - l0 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
    rewrite replicate_gt_eq in H; try easy.
    rewrite <- Hp in *. assert (l0 + (n' - l0 + 1) = n' + 1) by lia.
    rewrite H3 in *. clear H3.
    specialize (H13 n) as eq2.
    assert (n <= n < n + n' + 1) by lia.
    apply eq2 in H3. clear eq2.
    specialize (H14 0) as eq2.
    assert (l0 <= 0 < l0 + Z.of_nat (length (Zreplicate (h0 - l0 + 1) t0))).
    rewrite replicate_gt_eq; try lia.
    apply eq2 in H4. clear eq2.
    destruct H4 as [na [ta' [X1 [X2 X3]]]].
    destruct H3 as [nb [X4 X5]].
    rewrite Z.add_0_r in X2.
    apply Heap.mapsto_always_same with (v1 := (nb,t1)) in X2; try easy. inv X2.
    symmetry in X1.
    destruct (h0 - l0 + 1) as [| p1 | ?] eqn:Hp1; zify; [lia | |lia].
    unfold Zreplicate in X1.
    apply replicate_nth in X1. subst.
    destruct (Z_ge_dec h0 k).
    specialize (H14 k).
    assert (l0 <= k < l0 + Z.of_nat (length (Zreplicate (Z.pos p1) ta'))).
    rewrite replicate_gt_eq; try lia.
    apply H14 in H3. destruct H3 as [nc [tc [Y1 [Y2 Y3]]]].
    exists nc. exists tc.
    split. unfold Zreplicate in *.
    symmetry in Y1.
    apply replicate_nth in Y1. subst.
    rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    specialize (H13 (n+k)).
    assert (n <= n + k < n + n' + 1) by lia.
    apply H13 in H3.
    destruct H3 as [nb [Y1 Y2]].
    apply HHWt in Y1 as eq2.
    exists nb. exists ta'.
    split. unfold Zreplicate. rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    inv H11. inv H11. inv H3. inv H18. inv H11.
    destruct (Z_ge_dec h2 n').
    apply subtype_well_tau with (t := (TPtr C (TNTArray (Num l2) (Num h2) t0))); try easy.
    constructor. constructor. easy.
    constructor. apply Hswt in H10. constructor.
    destruct H10. destruct H3. inv H3. inv H15. easy.
    destruct H10 as [Y1 [Y2 Y3]]. inv Y2. inv H3. easy.
    apply TyLitC with (w := (TNTArray (Num l2) 
           (Num h2) t0)) (b := l2) (ts := Zreplicate (h2 - l2 + 1) t0); try easy.
    constructor. easy.
    constructor. intros.
    unfold scope_set_add.
    inv H12.
    specialize (H14 k H). easy.
    apply SubTyNtSubsume. constructor. lia. constructor. lia.
    inv H12.
    apply TyLitC with (w := ((TNTArray (Num l0) (Num n') t0)))
     (b := l0) (ts := (Zreplicate (n' - l0 + 1) t0)); eauto.
    constructor. easy. apply SubTyRefl.
    intros.
    unfold scope_set_add.
    destruct (n' - l0 + 1) as [| p | ?] eqn:Hp; zify; [lia | |lia].
    rewrite replicate_gt_eq in H; try easy.
    rewrite <- Hp in *. assert (l0 + (n' - l0 + 1) = n' + 1) by lia.
    rewrite H3 in *. clear H3.
    specialize (H13 n) as eq2.
    assert (n <= n < n + n' + 1) by lia.
    apply eq2 in H3. clear eq2.
    specialize (H14 0) as eq2.
    assert (l2 <= 0 < l2 + Z.of_nat (length (Zreplicate (h2 - l2 + 1) t0))).
    rewrite replicate_gt_eq; try lia.
    apply eq2 in H11. clear eq2.
    destruct H11 as [na [ta' [X1 [X2 X3]]]].
    destruct H3 as [nb [X4 X5]].
    rewrite Z.add_0_r in X2.
    apply Heap.mapsto_always_same with (v1 := (nb,t1)) in X2; try easy. inv X2.
    symmetry in X1.
    destruct (h2 - l2 + 1) as [| p1 | ?] eqn:Hp1; zify; [lia | |lia].
    unfold Zreplicate in X1.
    apply replicate_nth in X1. subst.
    destruct (Z_ge_dec h2 k).
    specialize (H14 k).
    assert (l2 <= k < l2 + Z.of_nat (length (Zreplicate (Z.pos p1) ta'))).
    rewrite replicate_gt_eq; try lia.
    apply H14 in H3. destruct H3 as [nc [tc [Y1 [Y2 Y3]]]].
    exists nc. exists tc.
    rewrite Hp.
    split. unfold Zreplicate in *.
    symmetry in Y1.
    apply replicate_nth in Y1. subst.
    rewrite replicate_nth_anti. easy. lia. easy.
    specialize (H13 (n+k)).
    assert (n <= n + k < n + n' + 1) by lia.
    apply H13 in H3.
    destruct H3 as [nb [Y1 Y2]].
    apply HHWt in Y1 as eq2.
    exists nb. exists ta'.
    split. unfold Zreplicate. rewrite Hp.
    rewrite replicate_nth_anti. easy. lia. easy.
    apply Stack.add_3 in H. apply HSHwf in H. easy. lia.
    split. easy.
    left. apply TyLet with (t2 := TInt); try easy.
    intros R. destruct R. apply Env.add_3 in H.
    assert (Env.In (elt:=tau) x env). exists x0. easy. contradiction.
    intros R. subst.
    assert (Env.In (elt:=tau) x env). exists (TPtr C (TNTArray l h ta)).
    easy. contradiction.
    apply TyLit. constructor.
    apply well_typed_exchange_strlen; try easy.
  (* T-Let *)

  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst.
    + clear H0. clear H9. rename e'0 into e'.
      specialize (stack_grow_prop D F s H s' H' (ELet x e1 e2) e' HSSA H5) as eq1.
      specialize (stack_simple_prop D F s H s' H' (ELet x e1 e2) e' SSimple H5) as eq2.
      inv H5. exists (Env.add x t0 env). inv HEwf.
      assert (Ht : t0 = t1). {
        inv HTy1. reflexivity.
      } rewrite Ht in *. clear Ht.
      split. econstructor.
      inv HSSA.
      destruct H. destruct H0.
      inv H0.
      unfold sub_domain in HSubDom.
      intros R. apply HSubDom in R.
      apply H in R. contradiction.
      split. unfold sub_domain in *.
      intros. 
      destruct (Nat.eq_dec x0 x). subst.
      unfold Stack.In,Stack.Raw.PX.In.
      exists (n, t').
      apply Stack.add_1. reflexivity.
      assert (Stack.In (elt:=Z * tau) x0 s -> Stack.In (elt:=Z * tau) x0 (Stack.add x (n, t') s)).
      intros. 
      unfold Stack.In,Stack.Raw.PX.In in *.
      destruct H0. exists x1.
      apply Stack.add_2. lia. assumption.
      apply H0. apply HSubDom.
      unfold Env.In,Env.Raw.PX.In in *.
      destruct H.
      apply Env.add_3 in H.
      exists x1. assumption. lia.
      split. apply (new_sub D F).
      assumption. assumption.
      assumption. assumption.
      assumption.
      split. unfold heap_consistent. eauto.
      left. apply (stack_grow_well_typed D F s).
      assumption.
      assumption.
    + clear H1.
      assert (~ Stack.In x s) as eqa.
      inv HSSA. destruct H0. destruct H1.
      inv H1.
      intros R. apply H0 in R. contradiction.
      apply ty_ssa_stack_small_let in HSSA.
      specialize (ty_ssa_stack_in_hole s e E HSSA) as eq3.
      specialize (stack_grow_prop D F s H s' H' e e'0 eq3 H5) as eq1.
      edestruct IH1...
      inv HEwf;eauto.
      exists x0. destruct H0 as [He [Hdom [Hs' [Hh Hwt]]]]. split. eauto. split.
      eauto. split. eauto. split. eauto.
      destruct Hwt.
      left. econstructor. apply H0.
      inv He. apply (stack_grow_well_typed D F s).
      assumption. 
      apply (heapWF D F s H).
      assumption. assumption.
      destruct (Nat.eq_dec x  x1).
      subst.
      eapply equiv_env_wt.
      assert (Env.Equal (Env.add x1 t1 (Env.add x1 t0 env)) (Env.add x1 t1 env)).
      apply env_shadow. apply env_sym in H2.
      apply H2.
      apply (stack_grow_well_typed D F s s') in HTy2.
      apply (heapWF D F s' H). assumption.
      assumption. assumption.
      apply (equiv_env_wt D F s' H' 
               (Env.add x1 t0 (Env.add x t1 env)) (Env.add x t1 (Env.add x1 t0 env))).
      apply env_neq_commute_eq.
      unfold Env.E.eq. lia. easy.
      apply well_typed_grow.
      intros R. 
      unfold Env.In,Env.Raw.PX.In in *.
      destruct R.
      apply Env.add_3 in H2.
      destruct H1.
      exists x0. assumption. assumption.
      apply (stack_grow_well_typed D F s s') in HTy2.
      apply (heapWF D F s' H). assumption.
      assumption. assumption.
      destruct H0.
      destruct H0.
      destruct H0. destruct H1.
      assert (@well_typed D F s' H' (Env.add x t1 env) C e2 t).
      apply (stack_grow_well_typed D F s s') in HTy2.
      apply (heapWF D F s' H). assumption. assumption. assumption.
      specialize (@well_typed_subtype D F s' H' env
                    C e2 t x t1 x1 x2 H3 H0 H1) as eqb.
      destruct eqb. left. econstructor.
      apply H2. inv He. 
      apply well_typed_grow.
      destruct (Nat.eq_dec x  x3).
      subst.
      eapply equiv_env_wt.
      assert (Env.Equal (Env.add x3 x2 (Env.add x3 t0 env)) (Env.add x3 x2 env)).
      apply env_shadow. apply env_sym in H7.
      apply H7. assumption.
      apply (equiv_env_wt D s' H' 
               (Env.add x3 t0 (Env.add x x2 env)) (Env.add x x2 (Env.add x3 t0 env))).
      apply env_neq_commute_eq.
      unfold Env.E.eq. lia. easy.
      apply well_typed_grow.
      intros R. 
      unfold Env.In,Env.Raw.PX.In in *.
      destruct R.
      apply Env.add_3 in H7.
      destruct H6.
      exists x0. assumption. assumption. assumption.
      destruct H4.
      destruct H4.
      destruct H4.
      destruct H6.
      right. exists x3. exists x4.
      split. eauto. split. eauto.
      econstructor. apply H2.
      inv He. assumption.
      destruct (Nat.eq_dec x  x5).
      subst.
      eapply equiv_env_wt.
      assert (Env.Equal (Env.add x5 x2 (Env.add x5 t0 env)) (Env.add x5 x2 env)).
      apply env_shadow. apply env_sym in H10.
      apply H10. assumption.
      apply (equiv_env_wt D s' H' 
               (Env.add x5 t0 (Env.add x x2 env)) (Env.add x x2 (Env.add x5 t0 env))).
      apply env_neq_commute_eq.
      unfold Env.E.eq. lia. easy.
      apply well_typed_grow.
      intros R. 
      unfold Env.In,Env.Raw.PX.In in *.
      destruct R.
      apply Env.add_3 in H10.
      destruct H8.
      exists x0. assumption. assumption. assumption.
  (* T-FieldAddr *)
  - inv Hreduces.
    destruct E; inversion H2; simpl in *; subst. exists env. 
    + clear H0. clear H10. inv H6.
      * inv HTy.
        (* Gotta prove some equalities *)
        assert (fs = fs0).
        { apply StructDef.find_1 in HWf1.
          match goal with
          | [ H : StructDef.MapsTo _ _ _ |- _ ] =>
            apply StructDef.find_1 in H; rewrite HWf1 in H; inv H
          end; auto.
        } 
        subst.
        assert (fields_wf D fs0) by eauto.

        (* assert (i = i0).
        { edestruct H; eauto. destruct H0. eapply H0. apply HWf2. apply H9. } *)
        subst.
        assert (ti = ti0).
        { apply Fields.find_1 in HWf2.
          apply Fields.find_1 in H9.
          rewrite HWf2 in H9.
          inv H9.
          reflexivity. }
        subst.
        rename fs0 into fs.
        clear i.
        rename i0 into i. 
        rename ti0 into ti. 

        (* The fact that n^(ptr C struct T) is well-taud is all we need *)
        split; eauto.
        inv HHwf.
        constructor. eapply preservation_fieldaddr; eauto. omega.
      * inv HTy.
        (* Gotta prove some equalities *)
        assert (fs = fs0).
        { apply StructDef.find_1 in HWf1.
          apply StructDef.find_1 in H7.
          rewrite HWf1 in H7.
          inv H7.
          reflexivity. }
        subst. 
        assert (fields_wf D fs0) by eauto.
        assert (ti = ti0).
        { eauto using FieldFacts.MapsTo_fun. }
        clear i.
        rename fs0 into fs.
        rename i0 into i.
        subst; rename ti0 into ti.
        (* Since it is an unchecked pointer, well-taudness is easy *)
        idtac...
    + clear H2. rename e0 into e1_redex. rename e'0 into e1_redex'.
      edestruct IH; eauto.
      inv HHwf; eauto.
  (* T-Plus *)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst.
    + clear H0. clear H7. rename e'0 into e'. inv H4.
      * inversion HTy1.
      * inv HTy1...
    + clear H1. rename e into e1_redex. rename e'0 into e1_redex'. edestruct IH1; idtac...
      inv HHwf; eauto.
    + clear H1. rename e into e2_redex. rename e'0 into e2_redex'. edestruct IH2; idtac...
      inv HHwf; eauto.
  (* T-Malloc *)
  - inv Hreduces.
    destruct E; inversion H2; simpl in *; subst.
    clear H0. clear H8.
    inv H5.
    split; eapply alloc_correct; eauto.
  (* T-U *)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst.
    + clear H0. clear H7. inv H4. inv HTy...
    + inversion H7; inversion H0.
  (* T-Cast *)
  - inv Hreduces.
    destruct E; inversion H1; simpl in *; subst.
    + clear H0. clear H7. inv H4. inv HTy.
      inv HHwf.
      inv H1.
      * idtac...
      * destruct m.
        { specialize (HChkPtr eq_refl w). exfalso. apply HChkPtr. reflexivity. }
        { idtac... }
    + clear H1. rename e0 into e1_redex. rename e'0 into e1_redex'. edestruct IH; idtac...
      inv HHwf; eauto.
  (* T-Deref *) 
  - destruct m'; try (specialize (HMode eq_refl); inversion HMode).
    clear HMode.
    inv HHwf.
    specialize (IH H1 eq_refl).
    inv Hreduces.
    destruct E eqn:He; inversion H2; simpl in *; try congruence.
    + 
      subst.
      clear IH.
      inv H5.
      split; eauto.
      destruct HPtrType as [[Hw Eq] | Hw]; subst.
      *   inv HSubType.  
         ** { inv HTy.
            remember H7 as Backup; clear HeqBackup.
            inv H7.
           - exfalso.
            eapply heap_wf_maps_nonzero; eauto.
           - inv H2.
            
           - inv Hw; simpl in*; subst; simpl in *.
            + inv H0; simpl in *.
              destruct (H5 0) as [N [T' [HT' [HM' HWT']]]]; [inv H2; simpl; omega | ].
             
              inv HT'.
              rewrite Z.add_0_r in HM'.
              assert (Hyp: (N, TInt) = (n1, t1)). {
              eapply HeapFacts.MapsTo_fun. inv H2. inv H0.
              exact HM'. exact H9. }
              inv Hyp; subst; eauto.
            + inv H0; simpl in *.
              destruct (H5 0) as [N [T' [HT' [HM' HWT']]]]; [inv H2; simpl; omega | ].
              inv HT'.
              rewrite Z.add_0_r in HM'.
              assert (Hyp: (N, TPtr m w) = (n1, t1)). {
                eapply HeapFacts.MapsTo_fun. inv H2.
                inv H0. exact HM'. exact H9. }
              inv Hyp; subst; eauto.
              apply TyLit.

              assert (Hyp: set_remove_all (n, TPtr C (TPtr m w))
                                     ((n,TPtr C (TPtr m w))::nil) = empty_scope).
              { 
                destruct (eq_dec_nt (n, TPtr C (TPtr m w)) (n, TPtr C (TPtr m w))) eqn:EQ; try congruence.
                unfold set_remove_all.
                rewrite EQ.
                auto.
              }

              rewrite <- Hyp.
              apply scope_strengthening. inv H2. inv H0.
              exact HWT'. exact HEwf. exact Backup.
            }
           ** { inv HTy.
              remember H10 as Backup; clear HeqBackup.
              inv H10.
              - exfalso.
                eapply heap_wf_maps_nonzero; eauto.
              - inv H2.
            
              - inv Hw; simpl in*; subst; simpl in *.
            
              }
          ** { inv HTy.
               remember H12 as Backup; clear HeqBackup.
               inv H12.
               - exfalso.
                 eapply heap_wf_maps_nonzero; eauto.
               - inv H2.
            
               - inv Hw; simpl in*; subst; simpl in *.
                 + inv H0; simpl in *.
                   destruct (H10 0) as [N [T' [HT' [HM' HWT']]]]; [inv H2; simpl; eauto | ].
                   destruct (StructDef.find (elt:=fields) T D) eqn:H.
                   inv H0. rewrite map_length. 
                   assert (StructDef.MapsTo T f D) by (eapply find_implies_mapsto; eauto).
                   assert (f = fs) by (eapply StructDefFacts.MapsTo_fun; eauto). rewrite <- H2 in *.
                   assert (((length (Fields.elements (elt:=tau) f)) > 0)%nat) by (eapply fields_implies_length; eauto).
                   omega. inv H. inv H0.
                   inv HT'.
                   rewrite Z.add_0_r in HM'.
                   assert (Hb : b = 0). 
                   {
                     destruct (StructDef.find (elt:=fields) T D);
                      inv H2. reflexivity.
                   } rewrite Hb in *.
                   simpl in H0. 
                   assert (Hts : StructDef.find (elt:=fields) T D = Some fs) by (eapply StructDef.find_1; eauto).
                   rewrite Hts in H2. inv H2.
                   assert (Some TInt = match map snd (Fields.elements (elt := tau) fs)
                    with 
                    | nil => None
                    | x:: _ => Some x
                          end) by (eapply element_implies_element; eauto).
                    rewrite <- H in H0. inv H0. 
                    assert (Hyp: (N, TInt) = (n1, t1)). {
                    eapply HeapFacts.MapsTo_fun.
                    exact HM'. exact H9. }
                    inv Hyp; subst; eauto.
                }
      *   assert (exists t1, w = (TPtr C t1)) by (inv HSubType; eauto).
          destruct H. rewrite H in *. clear H.
        { inv HTy.
          clear H8.
          clear H0.
          clear H1.
          remember H7 as Backup; clear HeqBackup.
          inv H7.
          - exfalso. 
            eapply heap_wf_maps_nonzero; eauto.
          - inversion H0.
          - destruct Hw as [? [? ?]]; subst.
            inv H0; simpl in *.
            inv HSubType.
            -- unfold allocate_meta in H4.
               destruct (H11 l h t). reflexivity.
               assert (Hpos : exists p, (h - l) = Z.pos p).
                {
                   destruct h; destruct l; inv H.
                   + exists p. simpl; reflexivity.
                   + exfalso. eapply H0. simpl. reflexivity.
                   + assert (Z.pos p - Z.neg p0 > 0) by (zify; omega).
                     assert (exists p2, Z.pos p - Z.neg p0 = Z.pos p2).
                     {
                      destruct (Z.pos p - Z.neg p0); inv H. exists p1. reflexivity.
                     } destruct H5. exists x. assumption.
                }
                destruct Hpos. rewrite H5 in *. simpl in H4. 
                inv H4; simpl in *. 
                assert (exists p, h = Z.pos p).
                {
                  destruct h; inv H. exists p; reflexivity.
                }
                destruct H4. destruct l.
                * assert (Hpos : exists n, Pos.to_nat x = S n) by apply pos_succ.
                  destruct Hpos.
                  destruct (H3 0) as [N [T' [HT' [HM' HWT']]]]; [ simpl; rewrite H7; simpl; zify; omega  | ].
                  rewrite H7 in HT'.  simpl in HT'. inv HT'.  rewrite Z.add_0_r in HM'.
                  maps_to_fun.
                  constructor.
                  assert (Hyp: set_remove_all (n, TPtr C (TArray 0 (Z.pos x0) t))
                                        ((n,TPtr C (TArray 0 (Z.pos x0) t))::nil) = empty_scope).
                    { 
                      destruct (eq_dec_nt (n, TPtr C (TArray 0 (Z.pos x0) t))
                                    (n, TPtr C (TArray 0 (Z.pos x0) t))) eqn:EQ; try congruence.
                      unfold set_remove_all.
                      rewrite EQ.
                      auto.
                    }
                  rewrite <- Hyp.
                  apply scope_strengthening; eauto.
                * exfalso; eapply H0; eauto.
                * assert (Hpos : exists n, Pos.to_nat x = S n) by apply pos_succ.
                  destruct Hpos. rewrite H4 in *.  clear H4 H0 H.
                  destruct (H3 0) as [N [T' [HT' [HM' HWT']]]]; [ rewrite H7; rewrite replicate_length; zify; omega | ].
                  rewrite H7 in HT'.
                  rewrite Z.add_0_r in HM'.
                  symmetry in HT'.
                   assert (t = T').
                   { 
                     eapply replicate_nth; eauto.
                   } 
                   subst T'.
                  maps_to_fun.
                   econstructor.
                   assert (Hyp: set_remove_all (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))
                                        ((n,TPtr C (TArray (Z.neg p) (Z.pos x0) t))::nil) = empty_scope).
                        { 
                          destruct (eq_dec_nt (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))
                                        (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))) eqn:EQ; try congruence.
                          unfold set_remove_all.
                          rewrite EQ.
                          auto.
                        }

                      rewrite <- Hyp.
                      apply scope_strengthening; eauto.
            -- unfold allocate_meta in H4.
               destruct (H11 l0 h0 t). reflexivity.
               clear H0.
               assert (Hpos : exists p, (h0 - l0) = Z.pos p).
                {
                   destruct h0; destruct l0; inv H.
                   + exists p. simpl; reflexivity.
                   + exfalso. eapply H5. simpl. reflexivity.
                   + assert (Z.pos p - Z.neg p0 > 0) by (zify; omega).
                     assert (exists p2, Z.pos p - Z.neg p0 = Z.pos p2).
                     {
                      destruct (Z.pos p - Z.neg p0); inv H. exists p1. reflexivity.
                     } destruct H0. exists x. assumption.
                }
                destruct Hpos. rewrite H0 in *. simpl in H4. 
                inv H4; simpl in *. 
                assert (exists p, h0 = Z.pos p).
                {
                  destruct h0; inv H. exists p; reflexivity.
                }
                destruct H4. destruct l0.
                * assert (Hpos : exists n, Pos.to_nat x = S n) by apply pos_succ.
                  destruct Hpos.
                  destruct (H3 0) as [N [T' [HT' [HM' HWT']]]]; [ simpl; rewrite H7; simpl; zify; omega  | ].
                  rewrite H7 in HT'.  simpl in HT'. inv HT'.  rewrite Z.add_0_r in HM'.
                  maps_to_fun.
                  constructor.
                  assert (Hyp: set_remove_all (n, TPtr C (TArray 0 (Z.pos x0) t))
                                        ((n,TPtr C (TArray 0 (Z.pos x0) t))::nil) = empty_scope).
                    { 
                      destruct (eq_dec_nt (n, TPtr C (TArray 0 (Z.pos x0) t))
                                    (n, TPtr C (TArray 0 (Z.pos x0) t))) eqn:EQ; try congruence.
                      unfold set_remove_all.
                      rewrite EQ.
                      auto.
                    }
                  rewrite <- Hyp.
                  apply scope_strengthening; eauto.
                * exfalso; eapply H5; eauto.
                * assert (Hpos : exists n, Pos.to_nat x = S n) by apply pos_succ.
                  destruct Hpos. rewrite H4 in *.
                  destruct (H3 0) as [N [T' [HT' [HM' HWT']]]]; [ rewrite H7; rewrite replicate_length; zify; omega | ].
                  rewrite H7 in HT'.
                  rewrite Z.add_0_r in HM'.
                  symmetry in HT'.
                   assert (t = T').
                   { 
                     eapply replicate_nth; eauto.
                   } 
                   subst T'.
                  maps_to_fun.
                   econstructor.
                   assert (Hyp: set_remove_all (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))
                                        ((n,TPtr C (TArray (Z.neg p) (Z.pos x0) t))::nil) = empty_scope).
                        { 
                          destruct (eq_dec_nt (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))
                                        (n, TPtr C (TArray (Z.neg p) (Z.pos x0) t))) eqn:EQ; try congruence.
                          unfold set_remove_all.
                          rewrite EQ.
                          auto.
                        }

                      rewrite <- Hyp.
                      apply scope_strengthening; eauto.
          }

    + subst.
      destruct (IH (in_hole e'0 c) H') as [HC HWT]; eauto. 
  - inv HHwf.

    assert (exists l0 h0, t = (TPtr m' (TArray l0 h0 t'))).
    {
      inv HSubType. exists l. exists h. reflexivity.
      exists l0. exists h0. reflexivity. 
    }

    destruct H0 as [l0 [h0 Hb]].
    rewrite Hb in *. clear Hb HSubType.
    (* TODO: Move outside, cleanup *)
    Ltac invert_expr_wf e :=
      match goal with
      | [ H : expr_wf _ e |- _ ] => inv H
      end.

    invert_expr_wf (EPlus e1 e2).
    inv Hreduces.

    Ltac invert_ctx_and_hole :=
      match goal with
      | [H : in_hole _ ?C = _ |- _] => destruct C; inversion H; simpl in *; subst; clear H
      end.

    invert_ctx_and_hole.

    + inv H6. (*TODO: auto *)
    + invert_ctx_and_hole.
      * { (* Plus step *)
          match goal with
          | [ H : step _ _ _ _ _ |- _ ] => inv H
          end; split; eauto...
          - inv HTy1.
            eapply TyDeref; eauto.
            constructor.

            Ltac cleanup :=
              repeat (match goal with
                      | [H : ?X =  ?X |- _ ] => clear H
                      | [H : ?X -> ?X |- _ ] => clear H
                      end).
            cleanup.
            
            match goal with
            | [ H : well_typed_lit _ _ _ _ _ |- _ ] =>
              remember H as Backup; clear HeqBackup; inv H; eauto; try omega
            end.

            unfold allocate_meta in *.

            inversion H0; subst b; subst ts; clear H0.
            
            eapply TyLitC; unfold allocate_meta in *; eauto.

            intros k Hk.
            
            assert (Hyp: h0 - n2 - (l0 - n2) = h0 - l0) by omega.
            rewrite Hyp in * ; clear Hyp.
            
            destruct (H6 (n2 + k)) as [n' [t'' [HNth [HMap HWT]]]]; [inv H0; omega | ].

            exists n'. exists t''.

            rewrite Z.add_assoc in HMap.
            inv H0.
            split; [ | split]; auto.
            + destruct (h0 - l0) eqn:HHL; simpl in *.
              * rewrite Z.add_0_r in Hk.
                destruct (Z.to_nat (n2 + k - l0)); inv HNth.
              * assert (HR: k - (l0 - n2) = n2 + k - l0) by (zify; omega).
                rewrite HR.
                auto.
              * destruct (Z.to_nat (n2 + k - l0)); inv HNth.
            + apply scope_weakening_cons.

              eapply scope_strengthening in HWT; eauto.
              assert (HAdd : set_add eq_dec_nt (n1, TPtr C (TArray l0 h0 t'))
                                     empty_scope =
                             (n1, TPtr C (TArray l0 h0 t')) :: nil) by auto.
              rewrite HAdd in HWT.
              clear HAdd.

              assert (HEmpty : empty_scope =
                               set_remove_all (n1, TPtr C (TArray l0 h0 t')) 
                                             ((n1, TPtr C (TArray l0 h0 t')) :: nil)).
              {
                unfold set_remove_all.
                destruct (eq_dec_nt (n1, TPtr C (TArray l0 h0 t'))
                                    (n1, TPtr C (TArray l0 h0 t'))); auto.
                congruence.
              }
              rewrite <- HEmpty in HWT.
              auto.
            + eapply SubTyRefl.
          - inv HTy1.
            destruct m'.
            + exfalso; eapply H10; eauto.
            + specialize (HMode eq_refl). inv HMode.
        }
      * clear l h t. 
        specialize (IH1 H3 eq_refl).
        specialize (IH1 (in_hole e'0 E) H').
        destruct IH1 as [HC HWT]; eauto.
        split; eauto. eapply TyIndex; eauto.
        eapply SubTyRefl. eauto...
      * specialize (IH2 H4 eq_refl (in_hole e'0 E) H').
        destruct IH2 as [HC HWT]; eauto.
        split; eauto. eapply TyIndex; eauto...
        eapply SubTyRefl.
  (* T-Assign *)
  - inv Hreduces.
    inv HHwf.
    destruct E; inversion H4; simpl in *; subst.
    + clear H10 H3.
      inv H7.
      inv Hwt2.
      inv Hwt1.
      destruct H1 as [[HW Eq] | Eq]; subst.
      * {
          destruct m'; [| specialize (H2 eq_refl); inv H2].
          inv H0.
          **
            eapply well_typed_heap_in in H11; eauto.
            destruct H11 as [N HMap].
            split.
            - apply HeapUpd with (n := N); eauto...
              eapply PtrUpd; eauto.
            - constructor.
              eapply PtrUpd; eauto. 
          **
            eapply well_typed_heap_in in H11; eauto.
            destruct H11 as [N HMap].
            split.
            - apply HeapUpd with (n := N); eauto...
              eapply PtrUpd; eauto.
            - constructor.
              eapply PtrUpd; eauto. 
            - eapply subtype_well_tau;
              eauto. eapply SubTySubsume; eauto.
          **
            eapply well_typed_heap_in in H11. eauto.
            destruct H11 as [N HMap].
            split; eauto.
            - apply HeapUpd with (n := N); eauto...
            - eauto.
            - eauto.
            - eapply subtype_well_tau;
              eauto. eapply SubTyStructArrayField; eauto.
        } 
      * destruct Eq as [? [? ?]]; subst.
        inv H0. 
        ** 
          { destruct m'; [| specialize (H2 eq_refl); inv H2].
            eapply (well_typed_heap_in_array n D H l h) in H11; eauto.
            destruct H11 as [N HMap].
            split.
            - apply HeapUpd with (n := N); eauto...
              eapply PtrUpd; eauto.
            - constructor.
              eapply PtrUpd; eauto.
            - eapply (H13 l h). eauto.
            - eapply H13. eauto.
          }
        ** 
          { clear H7. clear l h.
            destruct m'; [| specialize (H2 eq_refl); inv H2].
            eapply (well_typed_heap_in_array n D H l0 h0) in H11; eauto.
            destruct H11 as [N HMap].
            split.
            - apply HeapUpd with (n := N); eauto...
              eapply PtrUpd; eauto.
            - constructor.
              eapply PtrUpd; eauto.
            - eapply (H13 l0 h0). eauto.
            - eapply H13. eauto.
          }
    + destruct (IHHwt1 H6 eq_refl (in_hole e'0 E) H') as [HC HWT]; eauto.
      split; eauto...
    + destruct (IHHwt2 H8 eq_refl (in_hole e'0 E) H') as [HC HWT]; eauto.
      split; eauto... 
  - inv Hreduces.
    inv HHwf.
    inv H7.
    destruct E; inv H5; subst; simpl in*; subst; eauto.
    + inv H8.
    + assert (exists l0 h0, t = (TPtr m' (TArray l0 h0 t'))).
      {
        inv H2. exists l. exists h. reflexivity.
        exists l0. exists h0. reflexivity. 
      }
      destruct H4 as [l0 [h0 H4]].
      rewrite H4 in *. clear H4 H2.
      destruct E; inversion H6; simpl in *; subst.
      * { (* Plus step *)
          inv H8; split; eauto...
          - inv Hwt1.
            eapply TyAssign; eauto.
            constructor.
            cleanup.
            
            match goal with
            | [ H : well_typed_lit _ _ _ _ _ |- _ ] =>
              remember H as Backup; clear HeqBackup; inv H; eauto; try omega
            end.

            unfold allocate_meta in *.

            inversion H2; subst b; subst ts; clear H0.
            
            eapply TyLitC; unfold allocate_meta in *; eauto.

            intros k Hk.
            
            assert (Hyp: h0 - n2 - (l0 - n2) = h0 - l0) by omega.
            rewrite Hyp in * ; clear Hyp.
            inv H2.
            destruct (H5 (n2 + k)) as [n' [t0 [HNth [HMap HWT]]]]; [omega | ].

            exists n'. exists t0.

            rewrite Z.add_assoc in HMap.

            split; [ | split]; eauto.
            + destruct (h0 - l0) eqn:HHL; simpl in *.
              * rewrite Z.add_0_r in Hk.
                destruct (Z.to_nat (n2 + k - l0)); inv HNth.
              * assert (HR: k - (l0 - n2) = n2 + k - l0) by (zify; omega).
                rewrite HR.
                auto.
              * destruct (Z.to_nat (n2 + k - l0)); inv HNth.
            + apply scope_weakening_cons.

              eapply scope_strengthening in HWT; eauto.
              assert (HAdd : set_add eq_dec_nt (n1, TPtr C (TArray l0 h0 t'))
                                     empty_scope =
                             (n1, TPtr C (TArray l0 h0 t')) :: nil) by auto.
              rewrite HAdd in HWT.
              clear HAdd.

              assert (HEmpty : empty_scope =
                               set_remove_all (n1, TPtr C (TArray l0 h0 t')) 
                                             ((n1, TPtr C (TArray l0 h0 t')) :: nil)).
              {
                unfold set_remove_all.
                destruct (eq_dec_nt (n1, TPtr C (TArray l0 h0 t'))
                                    (n1, TPtr C (TArray l0 h0 t'))); auto.
                congruence.
              }
              rewrite <- HEmpty in HWT.
              auto.
            + eapply SubTyRefl; eauto.
          - inv Hwt1.
            destruct m'.
            + exfalso; eapply H14; eauto.
            + specialize (H3 eq_refl). exfalso; inv H3.
              
         }
      * destruct (IHHwt1 H10 eq_refl (in_hole e'0 E) H') as [HC HWT]; eauto.
        split. eauto. eapply TyIndexAssign; eauto.
        eapply SubTyRefl. eauto... eauto... 
      * destruct (IHHwt2 H12 eq_refl (in_hole e'0 E) H') as [HC HWT]; eauto.
        split; eauto. eapply TyIndexAssign; eauto... eapply SubTyRefl.
Qed.

(* ... for Blame *)

Create HintDb Blame.

Print heap_add_in_cardinal.

Lemma heap_wf_step : forall D F S H e S' H' e',
    @structdef_wf D ->
    heap_wf D H ->
    @step D F S H e S' H' (RExpr e') ->
    heap_wf D H'.
Proof.
  intros D F S H e S' H' e' HD HHwf HS.
  induction HS; eauto.
  - assert (Heap.cardinal H' = Heap.cardinal H).
      { rewrite H5. apply heap_add_in_cardinal. exists (na,ta). eauto. }
    intro addr; split; intro Hyp.
    + rewrite H5.
      rewrite H6 in Hyp.
      destruct (HHwf addr) as [HAddr HIn].
      destruct (HAddr Hyp) as [v Hx].
      destruct (Z.eq_dec addr n).
      * subst.
        exists (n1, ta). apply Heap.add_1. easy.
      * exists v.
        eapply Heap.add_2; eauto.
    + rewrite H5 in Hyp.
      destruct Hyp as [v Hv].
      destruct (Z.eq_dec addr n).
      * subst.
        rewrite H6.
        apply HHwf; auto.
        exists (na,ta);easy.
      * rewrite H6.
        apply HHwf.
        exists v.
        apply Heap.add_3 in Hv; auto.
  - apply alloc_correct with (Q := empty_theta) in H2; try easy.
    apply cast_means_simple_tau in H0. easy.
Qed.

Lemma fun_wf_step : forall D env S H e S' H' e',
    @structdef_wf D ->
    fun_wf D fenv S H ->
    @step D (fenv env) S H e S' H' (RExpr e') ->
    fun_wf D fenv S' H'.
Proof.
Admitted.

Lemma heap_wt_step : forall D F Q S H e S' H' e',
    heap_wt_all D Q H ->
    @step D F S H e S' H' (RExpr e') ->
    heap_wt_all D Q H'.
Proof.
Admitted.

Lemma stack_wt_step : forall D F S H e S' H' e',
    stack_wt D S ->
    @step D F S H e S' H' (RExpr e') ->
    stack_wt D S'.
Proof.
Admitted.

(*
Lemma expr_wf_subst :
  forall D n t x e,
    expr_wf D (ELit n t) ->
    expr_wf D e ->
    expr_wf D (subst x (ELit n t) e).
Proof.
  intros D n t x e Hwf H.
  inv Hwf.
  induction H; simpl; eauto;
    repeat (constructor; eauto).
  - destruct (var_eq_dec x x0); repeat (constructor; eauto).
  - destruct (var_eq_dec x x0); repeat (constructor; eauto).
Qed.
*)

Lemma expr_wf_step : forall env D S H e S' H' e',
    @expr_wf D fenv e -> stack_wt D S ->
    @step D (fenv env) S H e S' H' (RExpr e') ->
    @expr_wf D fenv e'.
Proof.
  intros env D S H e S' H' e' Hwf Hswt HS.
  inv HS; inv Hwf; eauto; try solve [repeat (constructor; eauto)].
  apply Hswt in H7. constructor; try easy.
Admitted.

Lemma expr_wf_reduce : forall env D S H m e S' H' e',
    @expr_wf D fenv e -> stack_wt D S ->
    @reduce D (fenv env) S H e m S' H' (RExpr e') ->
    @expr_wf D fenv e'.
Proof.
  intros env D S H m e S' H' e' Hwf Hswt HR.
  inv HR; auto.
  induction E; subst; simpl in *; eauto;
  try solve [inv Hwf; constructor; eauto].
  - eapply expr_wf_step in H2; eauto.
Qed.  

Definition normal { D : structdef } {F:funid -> option (list (var * tau) * tau * expression * mode)}
          (S:stack) (H : heap) (e : expression) : Prop :=
  ~ exists m' S' H' r, @reduce D F S H e m' S' H' r.

Definition stuck { D : structdef } {F:funid -> option (list (var * tau) * tau * expression * mode)}
        (S:stack) (H : heap) (r : result) : Prop :=
  match r with
  | RBounds => True
  | RNull => True
  | RExpr e => @normal D F S H e /\ ~ value D e
  end.

Inductive eval { D : structdef } {F:funid -> option (list (var * tau) * tau * expression * mode)} :
    stack -> heap -> expression -> mode -> stack -> heap -> result -> Prop :=
  | eval_refl   : forall S H e m, eval S H e m S H (RExpr e)
  | eval_transC : forall S H S' H' S'' H'' e e' r,
      @reduce D F S H e C S' H' (RExpr e') ->
      eval S' H' e' C S'' H'' r ->
      eval S H e C S'' H'' r
  | eval_transU : forall S H S' H' S'' H'' m' e e' r,
      @reduce D F S H e U S' H' (RExpr e') ->
      eval S' H' e' m' S'' H'' r ->
      eval S H e U S'' H'' r.

Lemma wt_dec : forall D S H Q env m e t, { @well_typed D fenv S H Q env m e t }
           + { ~ @well_typed D fenv S H Q env m e t }.
  (* This is a biggy *)
Admitted.

(* The Blame Theorem. *)
Theorem blame : forall D S H e t m S' H' r,
    @structdef_wf D ->
    heap_wf D H ->
    heap_wt_all D empty_theta H ->
    fun_wf D fenv S H ->
    stack_wt D S ->
    @expr_wf D fenv e ->
    @well_typed D fenv S H empty_env empty_theta C e t ->
    @eval D (fenv empty_env) S H e m S' H' r ->
    @stuck D (fenv empty_env) S' H' r ->
    m = U \/ (exists E e0, r = RExpr (in_hole e0 E) /\ mode_of E = U).
Proof.
  intros D S H e t m S' H' r HDwf HHwf HHwt Hfun HSwt Hewf Hwt Heval Hstuck.
  destruct r.
  - pose proof (wt_dec D S' H' empty_env empty_theta C e0 t).
    destruct H0.
    (* e0 is well taud *)
    + remember (RExpr e0) as r.
      induction Heval; subst.
      * inv Heqr.
        assert (value D e0 \/ reduces D (fenv empty_env) S H e0 \/ unchecked C e0).
        { apply progress with (t := t); eauto. }
        destruct H0.
        unfold stuck in Hstuck.
        destruct Hstuck.
        exfalso. apply H2. assumption.
        destruct H0.
        unfold stuck in Hstuck.
        destruct Hstuck.
        unfold normal in H1.
        unfold reduces in H0.
        exfalso. apply H1.
        assumption.
        unfold unchecked in H0.
        destruct H0.
        inversion H0.
        right. destruct H0. destruct H0. destruct H0.
        exists x0.
        exists x.
        split.
        rewrite H0. reflexivity.
        assumption.
      * apply IHHeval.
        inv H0. eapply heap_wf_step; eauto.
        inv H0. eapply heap_wt_step;eauto.
        inv H0. eapply fun_wf_step;eauto.
        inv H0. eapply stack_wt_step;eauto.
        eapply expr_wf_reduce; eauto.
        assert (@heap_consistent D empty_theta H' H
              /\ @well_typed D (fenv) S' H' empty_env empty_theta C e' t).
        { apply preservation with (e := e); assumption. }
        destruct H1.
        assumption.
        reflexivity.
        assumption.
        assumption.
      * left. reflexivity.
    (* e0 is not well taud *)
    + remember (RExpr e0) as r.
      induction Heval; subst.
      * inv Heqr.
        exfalso.
        apply n.
        assumption.
      * apply IHHeval.
        inv H0. eapply heap_wf_step; eauto.
        eapply expr_wf_reduce; eauto.
        assert (@heap_consistent D H' H /\ @well_typed D H' empty_env C e' t).
        { apply preservation with (e := e); assumption. }
        destruct H1.
        assumption.
        reflexivity.
        assumption.
        assumption.
      * left. reflexivity.
  - left.
    clear Hstuck.
    remember RNull as r.
    induction Heval; subst.
    + inversion Heqr.
    + apply IHHeval; try reflexivity.
      inv H0.
      eapply heap_wf_step; eauto.
      eapply expr_wf_reduce; eauto.
      assert (@heap_consistent D H' H /\ @well_typed D H' empty_env C e' t).
      { apply preservation with (e := e); eauto. }
      destruct H1.
      apply H2.
    + reflexivity.
  - left.
    clear Hstuck.
    remember RBounds as r.
    induction Heval; subst.
    + inversion Heqr.
    + apply IHHeval; try reflexivity.
      inv H0.
      eapply heap_wf_step; eauto.
      eapply expr_wf_reduce; eauto.
      assert (@heap_consistent D H' H /\ @well_typed D H' empty_env C e' t).
      { apply preservation with (e := e); eauto. }
      destruct H1.
      apply H2.
    + reflexivity.
Qed. 



