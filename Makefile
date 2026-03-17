#-*- mode: makefile -*-

SHELL := /bin/bash

CPAN_DIST_MAKER=make-cpan-dist.pl

package_version := $(shell cat VERSION)

VERSION ?= $(shell cat VERSION);

PERL_MODULES = \
    lib/Plerd.pm \
    lib/Plerd/Init.pm \
    lib/Plerd/Post.pm \
    lib/Plerd/SmartyPants.pm \
    lib/Plerd/Tag.pm \
    lib/Plerd/Util.pm

%.pm: %.pm.in
	sed -e 's/[@]PACKAGE_VERSION[@]/$(package_version)/' $< > $@

package=Plerd

TARBALL = $(package)-$(package_version).tar.gz

all: $(TARBALL) README.md

README.md: README.pod
	pod2markdown $< > $@

.PHONY: cpan
# builds the distribution tarball and renames based on package version
cpan: $(TARBALL)

$(TARBALL): buildspec.yml $(PERL_MODULES) README.md
	test -n "$$DEBUG" && set -x; \
	test -n "$$DEBUG" && DEBUG="--debug"; \
	test -e requires && REQUIRES="-r requires"; \
	test -n "$(NOCLEANUP)" && NOCLEANUP="--no-cleanup"; \
	test -n "$(DRYRUN)" && DRYRUN="--dryrun"; \
	test -n "$(SCANDEPS)" && SCANDEPS="-s"; \
	test -n "$(NOVERSION)" && NOVERSION="-n"; \
	PROJECT_ROOT="--project-root $$(readlink -f .)"; \
	$(CPAN_DIST_MAKER) $$PROJECT_ROOT $$REQUIRES $$DRYRUN $$SCANDEPS $$NOVERSION $$NOCLEANUP $$DEBUG -b $< || echo "$$?"

CLEANFILES = \
    extra-files \
    provides \
    resources 

include version.mk

include release-notes.mk

clean-local:
	for a in $(CLEANFILES); do \
	  rm -f $$a || true; \
	done
	rm -f *.tar.gz
	rm -f *.tmp
