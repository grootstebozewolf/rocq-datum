# rocq-datum

Foundational Rocq lemmas for verified computational geometry: pure-ℝ facts, ℝ↔floating-point bridges, and rounding-error bounds.

```coq
From Datum Require Import Real.Base.
```

## Assumptions

Importing `Stdlib.Reals` brings four axioms into the closure:

- `Stdlib.Logic.Classical_Prop.classic`
- `Stdlib.Reals.ClassicalDedekindReals.sig_forall_dec`
- `Stdlib.Reals.ClassicalDedekindReals.sig_not_dec`
- `Stdlib.Logic.FunctionalExtensionality.functional_extensionality_dep`

This is a fact about the import closure, not a choice made by Datum. Datum states no theorems yet; per-theorem assumptions are reported per lemma (`Print Assumptions`).
