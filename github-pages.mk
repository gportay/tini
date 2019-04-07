#!/usr/bin/make -f
#
# Copyright (c) 2017, 2019 Gaël PORTAY
#
# SPDX-License-Identifier: MIT
#
# See: https://help.github.com/articles/setting-up-your-github-pages-site-locally-with-jekyll/

.PHONY: all
all: exec

.SILENT: Gemfile
Gemfile:
	echo "# GitHub Pages" >$@.tmp
	echo "source 'https://rubygems.org'" >>$@.tmp
	echo "gem 'github-pages', group: :jekyll_plugins" >>$@.tmp
	echo "group :jekyll_plugins do" >>$@.tmp
	echo "  gem 'jekyll-asciidoc'" >>$@.tmp
	echo "end" >>$@.tmp
	cat $@.tmp >>$@
	rm -f $@.tmp

_config.yml:
	echo "theme: jekyll-theme-cayman" >$@.tmp
	cat $@.tmp >>$@
	rm -f $@.tmp

.PHONY: exec
exec: bundle-exec

.PHONY: update
update: bundle-update

.SILENT: install
.PHONY: install
install:
	if ! which bundler >/dev/null 2>&1; then \
		gem install bundler; \
	fi

.PHONY: clean
clean:
	rm -Rf _site

bundle-install:
bundle-exec: _config.yml
bundle-exec: override BUNDLEFLAGS+=jekyll serve
bundle-update:
bundle-%: Gemfile
	bundle $* $(BUNDLEFLAGS)

