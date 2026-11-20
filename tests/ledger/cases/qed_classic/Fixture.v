From Stdlib Require Import Classical_Prop.

Lemma lem (p : Prop) : p \/ ~ p.
Proof. exact (classic p). Qed.
