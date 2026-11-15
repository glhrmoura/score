APP = Score
BUILD = build
BUNDLE = $(BUILD)/$(APP).app
SOURCES = $(wildcard Sources/*.swift)
ARCH = $(shell uname -m)
INSTALL_DIR = /Applications

.PHONY: all run install clean

all: $(BUNDLE)

$(BUNDLE): $(SOURCES) Resources/Info.plist Resources/AppIcon.icns $(wildcard Resources/Fonts/*) $(wildcard Resources/pt-BR.lproj/*)
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	swiftc -parse-as-library -O -swift-version 5 -target $(ARCH)-apple-macos14.0 $(SOURCES) -o $(BUNDLE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp -R Resources/Fonts $(BUNDLE)/Contents/Resources/Fonts
	cp -R Resources/pt-BR.lproj $(BUNDLE)/Contents/Resources/pt-BR.lproj
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(BUNDLE)

run: all
	open $(BUNDLE)

install: all
	-pkill -x $(APP) && sleep 1
	rm -rf $(INSTALL_DIR)/$(APP).app
	cp -R $(BUNDLE) $(INSTALL_DIR)/$(APP).app
	open $(INSTALL_DIR)/$(APP).app

clean:
	rm -rf $(BUILD)
