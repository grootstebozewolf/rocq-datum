# Thin wrapper around the rocq-generated CoqMakefile.

AUDIT_ROCQ = rocq compile -output-directory . -R theories Datum -Q audit DatumAudit
ST4_CP = tools/st4/lib/ST4-4.3.4.jar:tools/st4/lib/antlr-runtime-3.5.3.jar

all: CoqMakefile
	+$(MAKE) -f CoqMakefile all

CoqMakefile: _CoqProject
	rocq makefile -f _CoqProject -o CoqMakefile

# Regenerate audit/Ledger.v and audit/ledger.tsv, then the Markdown views.
# Fails on dangling names, non-Counterexample QEX entries, unregistered
# theorems and axioms outside the policy (see audit/ledger.py).
audit: all
	python3 audit/ledger.py emit
	rm -rf audit/_out && mkdir -p audit/_out
	$(AUDIT_ROCQ) audit/Ledger.v
	python3 audit/ledger.py report
	$(MAKE) docs

# Render audit/LEDGER.md and README.md from audit/ledger.tsv with
# StringTemplate 4.  Every count in them is derived from ledger rows.
docs:
	bash tools/st4/fetch.sh
	java -cp $(ST4_CP) tools/st4/Render.java audit/ledger.tsv \
	  templates/ledger.stg audit/LEDGER.md \
	  templates/readme.stg README.md

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

.PHONY: all audit docs test-ledger clean
