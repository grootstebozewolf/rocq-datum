From Stdlib Require Import PeanoNat.
From Datum Require Import Ledger.Core.

(* Claim: every natural number is even.  Refuted by 1, by computation. *)
Definition is_even (n : nat) : Prop := Nat.even n = true.

Definition all_even_cex : Counterexample is_even :=
  by_check Nat.even (fun y H => H) 1 eq_refl.

(* Repair: every double is even. *)
Lemma double_even (n : nat) : is_even (2 * n).
Proof. unfold is_even. rewrite Nat.even_mul. reflexivity. Qed.

(* Claim: every natural number is zero.  Refuted, no repair yet. *)
Definition all_zero_cex : Counterexample (fun n : nat => n = 0) :=
  by_check (Nat.eqb 0) (fun y H => eq_ind_r (fun z => Nat.eqb 0 z = true) eq_refl H) 1 eq_refl.
