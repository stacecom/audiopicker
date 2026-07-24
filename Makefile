APP_NAME := AudioPicker
APP := dist/$(APP_NAME).app
INSTALL_DIR := /Applications

.PHONY: all build app run install uninstall clean

all: app

## Compile the executable (debug).
build:
	swift build

## Build the release .app bundle (ad-hoc signed) in ./dist.
app:
	./scripts/build-app.sh

## Build and launch the app from ./dist.
run: app
	open "$(APP)"

## Install the bundle into /Applications (recommended for launch-at-login).
install: app
	@echo "==> Installing to $(INSTALL_DIR)…"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	@echo "Installed. Launch from Applications or run: open \"$(INSTALL_DIR)/$(APP_NAME).app\""

## Remove the installed app and turn off its login item.
uninstall:
	-osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"

## Remove build artifacts.
clean:
	rm -rf .build dist
