NAME    = virtualmin-authfwd
VERSION = $(shell sed -n 's/^version=//p' module.info)
FILES   = module.info authfwd authfwd-lib.pl virtual_feature.pl postinstall.pl \
          uninstall.pl migrate-forwards.pl lang help LICENSE README.md

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
