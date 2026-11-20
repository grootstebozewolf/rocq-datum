(** * Datum.Ledger.Core

    Types for the two audit ledgers.

    - QED: positive results; ordinary theorems.
    - QEX: Qed-closed counterexamples.  A QEX entry is not a label on a
      comment but a term of type [Counterexample P]: a concrete witness [x]
      together with a proof of [~ P x].  The generated [audit/Ledger.v]
      checks every QEX name against this type, so the kernel rejects an
      entry that is not a witnessed refutation.

    This file must stay closed under the global context: no imports beyond
    the prelude, no axioms. *)

Definition Counterexample {A : Type} (P : A -> Prop) : Type :=
  { x : A | ~ P x }.

(** A counterexample refutes the universal claim.  Constructive. *)
Lemma refutes {A : Type} {P : A -> Prop} :
  @Counterexample A P -> ~ (forall x, P x).
Proof.
  intros [x Hx] H.
  exact (Hx (H x)).
Qed.

(** Building a counterexample by computation.

    Give a boolean checker [p] that is sound for [P] ([P x -> p x = true])
    and a witness [x] with [p x = false].  The last argument is meant to be
    closed by [eq_refl] (the kernel evaluates [p x]), or by [vm_compute;
    reflexivity] inside a proof, so the refutation of [P x] does not rest
    on a hand-written argument. *)
Definition by_check {A : Type} {P : A -> Prop} (p : A -> bool)
    (sound : forall y, P y -> p y = true)
    (x : A) (Hx : p x = false) : Counterexample P.
Proof.
  exists x.
  intros HP.
  rewrite (sound x HP) in Hx.
  discriminate Hx.
Defined.
