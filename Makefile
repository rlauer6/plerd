#-*- mode: makefile -*-

CPAN_DIST_MAKER=make-cpan-dist.pl

package_version := $(shell perl -I lib -MPlerd -e 'print $$Plerd::VERSION;')
package=Plerd

README.md: README.pod
	pod2markdown $< > $@

# builds the distribution tarball and renames based on package version
cpan: buildspec.yml README.md
	test -n "$$DEBUG" && set -x; \
	test -n "$$DEBUG" && DEBUG="--debug"; \
	test -e requires && REQUIRES="-r requires"; \
	test -n "$(NOCLEANUP)" && NOCLEANUP="--no-cleanup"; \
	test -n "$(DRYRUN)" && DRYRUN="--dryrun"; \
	test -n "$(SCANDEPS)" && SCANDEPS="-s"; \
	test -n "$(NOVERSION)" && NOVERSION="-n"; \
	PROJECT_ROOT="--project-root $$(readlink -f .)"; \
	$(CPAN_DIST_MAKER) $$PROJECT_ROOT $$REQUIRES $$DRYRUN $$SCANDEPS $$NOVERSION $$NOCLEANUP $$DEBUG -b $< || echo "$$?"

# handle n.m.r-b version format (but don't use this anymore!)
	if test -n "$$(echo $(package_version) | grep '\-')"; then \
		echo $$package_version; \
		package_version=$(package_version); package=$(package); \
		tarball=$${package##perl-}-$${package_version%%-*}.tar.gz; \
		test -e "$$tarball" && mv $$tarball $${package##perl-}-$$package_version.tar.gz; \
	fi

CLEANFILES = \
    extra-files \
    provides \
    resources 

clean-local:
	for a in $(CLEANFILES); do \
	  rm -f $$a || true; \
	done
	rm -f *.tar.gz
	rm -f *.tmp
