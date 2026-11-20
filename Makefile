# Thin wrapper around the rocq-generated CoqMakefile.

all: CoqMakefile
	+$(MAKE) -f CoqMakefile all

CoqMakefile: _CoqProject
	rocq makefile -f _CoqProject -o CoqMakefile

clean: CoqMakefile
	+$(MAKE) -f CoqMakefile cleanall
	rm -f CoqMakefile CoqMakefile.conf

# Forward any other target (install, uninstall, validate, ...) to CoqMakefile.
%: CoqMakefile
	+$(MAKE) -f CoqMakefile $@

# Keep make from trying to rebuild these via the catch-all rule.
_CoqProject Makefile: ;

.PHONY: all clean
