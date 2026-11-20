From Stdlib Require Import Classical_Prop.
From Datum Require Import Ledger.Core.

Definition all_zero_cex : Counterexample (fun n : nat => n = 0).
Proof.
  exists 1. intro H.
  destruct (classic (1 = 1)); discriminate H.
Defined.
