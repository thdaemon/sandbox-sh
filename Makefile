.PHONY: install

DEST := /usr/local

default:
	@echo "Run \`make install' to install"

install:
	install -d -m755 "$(DEST)/bin" "$(DEST)/share/sandbox-sh" "$(DEST)/share/man/man1"
	install -m755 src/bin/* "$(DEST)/bin/"
	cp -r src/share/sandbox-sh/* "$(DEST)/share/sandbox-sh/"
	asciidoctor -b manpage -o $(DEST)/share/man/man1/sandbox.sh.1 docs/sandbox.sh.1.adoc