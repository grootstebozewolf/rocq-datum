(** * Datum.Geometry.RiemannSphere

    The Riemann sphere: the unit sphere S² ⊂ ℝ³ is in bijection with the
    extended complex plane Ĉ = ℂ ∪ {∞} via stereographic projection from
    the north pole N = (0,0,1).

    ℂ is modelled as ℝ × ℝ (a point [Fin a b] is a + bi), so everything
    here is pure-ℝ algebra.

    Main results:

    - [riemann_sphere]: [unstereo] maps Ĉ into S², and [stereo] / [unstereo]
      are mutually inverse between S² and Ĉ (Macro).
    - [chordal_fin], [chordal_inf]: the chordal metric induced on Ĉ by the
      Euclidean distance on S².
    - [unstereo_recip]: w ↦ 1/w is the rotation (x,y,z) ↦ (x,-y,-z) of S²,
      hence [recip_involutive].
    - [unstereo_antipode]: w ↦ -1/w̄ is the antipodal map p ↦ -p.
    - [stereo_not_always_finite] (QEX): "every point of S² projects to a
      finite point" is refuted by N; repaired by [stereo_finite_iff]. *)

From Stdlib Require Import Reals Lra.
Require Import Datum.Ledger.Core.
Open Scope R_scope.

(** ** Points of ℝ³ and the unit sphere *)

Record P3 := mkP3 { px : R; py : R; pz : R }.

Definition on_sphere (p : P3) : Prop :=
  px p ^ 2 + py p ^ 2 + pz p ^ 2 = 1.

Definition north : P3 := mkP3 0 0 1.
Definition south : P3 := mkP3 0 0 (-1).

(** Squared Euclidean distance in ℝ³. *)
Definition dist2 (p q : P3) : R :=
  (px p - px q) ^ 2 + (py p - py q) ^ 2 + (pz p - pz q) ^ 2.

Definition neg (p : P3) : P3 := mkP3 (- px p) (- py p) (- pz p).

(** Rotation by π about the x-axis. *)
Definition rot_x (p : P3) : P3 := mkP3 (px p) (- py p) (- pz p).

(** ** The extended complex plane Ĉ = ℂ ∪ {∞} *)

Inductive ExtC : Type :=
| Fin (a b : R)   (** a + bi *)
| Inf.            (** ∞ *)

(** |w|² for a finite point. *)
Definition norm2 (a b : R) : R := a ^ 2 + b ^ 2.

(** ** Stereographic projection and its inverse *)

Definition stereo (p : P3) : ExtC :=
  if Req_EM_T (pz p) 1 then Inf
  else Fin (px p / (1 - pz p)) (py p / (1 - pz p)).

Definition unstereo (w : ExtC) : P3 :=
  match w with
  | Inf => north
  | Fin a b =>
      let d := 1 + norm2 a b in
      mkP3 (2 * a / d) (2 * b / d) ((norm2 a b - 1) / d)
  end.

Lemma norm2_nonneg (a b : R) : 0 <= norm2 a b.
Proof. unfold norm2. nra. Qed.

Lemma norm2_zero (a b : R) : norm2 a b = 0 -> a = 0 /\ b = 0.
Proof. unfold norm2. intros H. split; nra. Qed.

Lemma unstereo_denom_pos (a b : R) : 0 < 1 + norm2 a b.
Proof. pose proof (norm2_nonneg a b). lra. Qed.

Lemma north_on_sphere : on_sphere north.
Proof. unfold on_sphere, north; simpl. ring. Qed.

(** A point of the sphere at height 1 is the north pole. *)
Lemma sphere_top_is_north (p : P3) :
  on_sphere p -> pz p = 1 -> p = north.
Proof.
  destruct p as [x y z]; unfold on_sphere, north; simpl.
  intros Hs Hz; subst z.
  assert (Hx : x = 0) by nra.
  assert (Hy : y = 0) by nra.
  subst; reflexivity.
Qed.

(** [unstereo] lands on the sphere. *)
Theorem unstereo_on_sphere (w : ExtC) : on_sphere (unstereo w).
Proof.
  destruct w as [a b |]; [| exact north_on_sphere].
  unfold on_sphere, unstereo; simpl.
  pose proof (unstereo_denom_pos a b) as Hd.
  unfold norm2 in *.
  field. lra.
Qed.

(** [stereo] is a left inverse of [unstereo] on all of Ĉ. *)
Theorem stereo_unstereo (w : ExtC) : stereo (unstereo w) = w.
Proof.
  destruct w as [a b |].
  - unfold stereo, unstereo; simpl.
    pose proof (unstereo_denom_pos a b) as Hd.
    pose proof (norm2_nonneg a b) as Hn.
    destruct Req_EM_T as [E | _].
    + exfalso.
      apply (Rmult_eq_compat_r (1 + norm2 a b)) in E.
      unfold Rdiv in E. rewrite Rmult_assoc, Rinv_l in E by lra. lra.
    + f_equal; field; lra.
  - unfold stereo, unstereo, north; simpl.
    destruct (Req_EM_T 1 1) as [_ | n]; [reflexivity | contradiction].
Qed.

(** [unstereo] is a left inverse of [stereo] on the sphere. *)
Theorem unstereo_stereo (p : P3) : on_sphere p -> unstereo (stereo p) = p.
Proof.
  intros Hs.
  unfold stereo.
  destruct (Req_EM_T (pz p) 1) as [Ez | Nz].
  - symmetry. exact (sphere_top_is_north p Hs Ez).
  - destruct p as [x y z]; unfold on_sphere in Hs; simpl in *.
    assert (Hk : 1 - z <> 0) by lra.
    (* 1 + |w|² = 2 / (1 - z) on the sphere. *)
    assert (Hd : 1 + norm2 (x / (1 - z)) (y / (1 - z)) = 2 / (1 - z)).
    { unfold norm2.
      apply (Rmult_eq_reg_r ((1 - z) ^ 2)); [| apply pow_nonzero; exact Hk].
      field_simplify; [| exact Hk | exact Hk].
      nra. }
    unfold unstereo; rewrite Hd.
    assert (Hn : norm2 (x / (1 - z)) (y / (1 - z)) = 2 / (1 - z) - 1) by lra.
    rewrite Hn.
    f_equal; field; exact Hk.
Qed.

(** Stereographic projection is a bijection S² ≅ Ĉ. *)
Theorem riemann_sphere :
  (forall w, on_sphere (unstereo w)) /\
  (forall w, stereo (unstereo w) = w) /\
  (forall p, on_sphere p -> unstereo (stereo p) = p).
Proof.
  split; [exact unstereo_on_sphere |].
  split; [exact stereo_unstereo | exact unstereo_stereo].
Qed.

Corollary unstereo_injective (w w' : ExtC) :
  unstereo w = unstereo w' -> w = w'.
Proof.
  intros E.
  rewrite <- (stereo_unstereo w), <- (stereo_unstereo w'), E.
  reflexivity.
Qed.

Corollary stereo_injective_on_sphere (p q : P3) :
  on_sphere p -> on_sphere q -> stereo p = stereo q -> p = q.
Proof.
  intros Hp Hq E.
  rewrite <- (unstereo_stereo p Hp), <- (unstereo_stereo q Hq), E.
  reflexivity.
Qed.

(** ** Poles *)

Lemma stereo_north : stereo north = Inf.
Proof.
  unfold stereo, north; simpl.
  destruct (Req_EM_T 1 1); [reflexivity | contradiction].
Qed.

Lemma unstereo_zero : unstereo (Fin 0 0) = south.
Proof. unfold unstereo, south, norm2; simpl. f_equal; field. Qed.

(** ** Which points have a finite image *)

(** Refutation of "every point of the sphere projects into ℂ": the north
    pole is sent to ∞. *)
Definition stereo_not_always_finite :
  Counterexample (fun p : { p : P3 | on_sphere p } =>
                    exists a b, stereo (proj1_sig p) = Fin a b).
Proof.
  exists (exist _ north north_on_sphere).
  simpl. rewrite stereo_north.
  intros (a & b & E). discriminate E.
Defined.

(** Repair: exactly the points other than N project into ℂ. *)
Theorem stereo_finite_iff (p : P3) :
  on_sphere p -> ((exists a b, stereo p = Fin a b) <-> p <> north).
Proof.
  intros Hs. split.
  - intros (a & b & E) En. subst p.
    rewrite stereo_north in E. discriminate E.
  - intros Hn. unfold stereo.
    destruct (Req_EM_T (pz p) 1) as [Ez | _].
    + exfalso. exact (Hn (sphere_top_is_north p Hs Ez)).
    + eexists; eexists; reflexivity.
Qed.

(** ** The chordal metric *)

(** Distance between the images of two finite points. *)
Theorem chordal_fin (a b c d : R) :
  dist2 (unstereo (Fin a b)) (unstereo (Fin c d)) =
  4 * norm2 (a - c) (b - d) / ((1 + norm2 a b) * (1 + norm2 c d)).
Proof.
  unfold dist2, unstereo; simpl.
  pose proof (unstereo_denom_pos a b) as H1.
  pose proof (unstereo_denom_pos c d) as H2.
  unfold norm2 in *.
  field. lra.
Qed.

(** Distance from the image of a finite point to the image of ∞. *)
Theorem chordal_inf (a b : R) :
  dist2 (unstereo (Fin a b)) (unstereo Inf) = 4 / (1 + norm2 a b).
Proof.
  unfold dist2, unstereo, north; simpl.
  pose proof (unstereo_denom_pos a b) as H1.
  unfold norm2 in *.
  field. lra.
Qed.

(** ** Möbius symmetries as rigid motions of the sphere *)

(** w ↦ 1/w on Ĉ, with 1/0 = ∞ and 1/∞ = 0. *)
Definition recip (w : ExtC) : ExtC :=
  match w with
  | Inf => Fin 0 0
  | Fin a b =>
      if Req_EM_T (norm2 a b) 0 then Inf
      else Fin (a / norm2 a b) (- b / norm2 a b)
  end.

(** w ↦ -1/w̄ on Ĉ, with 0 ↦ ∞ and ∞ ↦ 0. *)
Definition antipode (w : ExtC) : ExtC :=
  match w with
  | Inf => Fin 0 0
  | Fin a b =>
      if Req_EM_T (norm2 a b) 0 then Inf
      else Fin (- a / norm2 a b) (- b / norm2 a b)
  end.

(** Shared shape of the two proofs below. *)
Local Ltac moebius_case w :=
  destruct w as [a b |];
  [ destruct (Req_EM_T (norm2 a b) 0) as [Z | Z];
    [ destruct (norm2_zero a b Z); subst a b;
      unfold unstereo, rot_x, neg, north, norm2; simpl;
      f_equal; field
    | pose proof (norm2_nonneg a b);
      assert (0 < norm2 a b) by lra;
      unfold unstereo, rot_x, neg, norm2 in *; simpl;
      f_equal; field; repeat split; nra ]
  | unfold unstereo, rot_x, neg, north, norm2; simpl;
    f_equal; field ].

(** Inversion w ↦ 1/w is the half-turn about the real axis. *)
Theorem unstereo_recip (w : ExtC) :
  unstereo (recip w) = rot_x (unstereo w).
Proof.
  unfold recip. moebius_case w.
Qed.

(** w ↦ -1/w̄ is the antipodal map. *)
Theorem unstereo_antipode (w : ExtC) :
  unstereo (antipode w) = neg (unstereo w).
Proof.
  unfold antipode. moebius_case w.
Qed.

Lemma rot_x_involutive (p : P3) : rot_x (rot_x p) = p.
Proof. destruct p; unfold rot_x; simpl; f_equal; ring. Qed.

Lemma neg_involutive (p : P3) : neg (neg p) = p.
Proof. destruct p; unfold neg; simpl; f_equal; ring. Qed.

(** 1/(1/w) = w on all of Ĉ, read off from the rotation. *)
Corollary recip_involutive (w : ExtC) : recip (recip w) = w.
Proof.
  apply unstereo_injective.
  rewrite !unstereo_recip. apply rot_x_involutive.
Qed.

Corollary antipode_involutive (w : ExtC) : antipode (antipode w) = w.
Proof.
  apply unstereo_injective.
  rewrite !unstereo_antipode. apply neg_involutive.
Qed.

(** Antipodal points never coincide on the sphere, so -1/w̄ ≠ w. *)
Corollary antipode_no_fixed_point (w : ExtC) : antipode w <> w.
Proof.
  intros E.
  pose proof (unstereo_on_sphere w) as Hs.
  apply (f_equal unstereo) in E. rewrite unstereo_antipode in E.
  destruct (unstereo w) as [x y z]; unfold neg, on_sphere in *; simpl in *.
  injection E as Ex Ey Ez.
  assert (x = 0) by lra. assert (y = 0) by lra. assert (z = 0) by lra.
  subst. lra.
Qed.
