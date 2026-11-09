NAME    = virtualmin-authfwd
VERSION = $(shell sed -n 's/^version=//p' module.info)
FILES   = module.info CHANGELOG LICENSE README.md config config.info config.info.el \
          defaultacl authfwd authfwd-lib.pl virtual_feature.pl postinstall.pl \
          uninstall.pl log_parser.pl acl_security.pl index.cgi migrate.cgi \
          list-authenticated-forwards.pl set-authenticated-forward.pl \
          migrate-authenticated-forwards.pl lang help images

# Builds a Webmin module package, installable from
# Webmin -> Webmin Configuration -> Webmin Modules.
dist:
	rm -rf build && mkdir -p build/$(NAME)
	cp -r $(FILES) build/$(NAME)/
	tar -C build -czf $(NAME)-$(VERSION).wbm.gz $(NAME)
	rm -rf build
	@echo built $(NAME)-$(VERSION).wbm.gz

test:
	sh t/test-authfwd.sh

.PHONY: dist test
