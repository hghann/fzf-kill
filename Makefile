# Default install directory
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
USER_BIN = $(HOME)/.local/bin

# Files to install
PROD_SCRIPT = fzf-kill
LEGACY_SCRIPT = fzf-kill-legacy.sh

.PHONY: install user-install uninstall clean help

help:
	@echo "fzf-kill macOS Installer"
	@echo "Usage:"
	@echo "  make install        - Install to $(BINDIR) (requires sudo)"
	@echo "  make user-install   - Install to $(USER_BIN)"
	@echo "  make uninstall      - Remove scripts from $(BINDIR) and $(USER_BIN)"
	@echo "  make clean          - Remove installed binaries from $(BINDIR)"

install:
	@echo "Installing to $(BINDIR)..."
	mkdir -p $(BINDIR)
	install -m 755 $(PROD_SCRIPT) $(BINDIR)/$(PROD_SCRIPT)
	install -m 755 $(LEGACY_SCRIPT) $(BINDIR)/$(LEGACY_SCRIPT)

user-install:
	@echo "Installing to $(USER_BIN)..."
	mkdir -p $(USER_BIN)
	install -m 755 $(PROD_SCRIPT) $(USER_BIN)/$(PROD_SCRIPT)
	install -m 755 $(LEGACY_SCRIPT) $(USER_BIN)/$(LEGACY_SCRIPT)
	@echo "Installation complete. Ensure $(USER_BIN) is in your PATH."

uninstall:
	@echo "Removing scripts from system and user paths..."
	@# Attempt system removal (sudo)
	sudo rm -f $(BINDIR)/$(PROD_SCRIPT) $(BINDIR)/$(LEGACY_SCRIPT)
	@# Attempt user removal
	rm -f $(USER_BIN)/$(PROD_SCRIPT) $(USER_BIN)/$(LEGACY_SCRIPT)

clean:
	@echo "Cleaning local workspace..."
	@# Remove the test folder files used for development
	rm -rf test/fzf-kill test/fzf-kill-legacy.sh

