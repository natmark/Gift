xcode:
	swift package generate-xcodeproj
build:
	swift build
test:
	swift test
release:
	swift build -c release

INSTALL_DIR = /usr/local/bin
install: release
	mkdir -p "$(INSTALL_DIR)"
	cp -f ".build/release/gift" "$(INSTALL_DIR)/gift"
