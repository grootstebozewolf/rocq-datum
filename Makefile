# Thin wrapper around the rocq-generated CoqMakefile.

AUDIT_ROCQ = rocq compile -R theories Datum -Q audit DatumAudit

all: CoqMakefile
	+$(MAKE) -f CoqMakefile all

CoqMakefile: _CoqProject
	rocq makefile -f _CoqProject -o CoqMakefile

# Regenerate audit/Ledger.v, audit/ledger.tsv and audit/counts.tsv.
# Fails on dangling names, non-Counterexample QEX entries, unregistered
# theorems and axioms outside the policy (see audit/ledger.py).
audit: all
	python3 audit/ledger.py emit
	rm -rf audit/_out && mkdir -p audit/_out
	$(AUDIT_ROCQ) audit/Ledger.v
	python3 audit/ledger.py report

# Self-test of the audit gates against fixtures in tests/ledger/.
test-ledger:
	bash tests/ledger/run.sh

clean: CoqMakefile
	+$(MAKE) -f CoqMakefile cleanall
	rm -f CoqMakefile CoqMakefile.conf
	rm -rf audit/_out audit/*.vo audit/*.vok audit/*.vos audit/*.glob audit/.*.aux

# Forward any other target (install, uninstall, validate, ...) to CoqMakefile.
%: CoqMakefile
	+$(MAKE) -f CoqMakefile $@

# Keep make from trying to rebuild these via the catch-all rule.
_CoqProject Makefile: ;

.PHONY: all audit test-ledger clean
