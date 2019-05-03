xcode:
	swift package generate-xcodeproj
build:
	swift build -Xswiftc -target -Xswiftc x86_64-apple-macosx10.11
test:
	swift test -Xswiftc -target -Xswiftc x86_64-apple-macosx10.11
release:
	swift build -c release -Xswiftc -target -Xswiftc x86_64-apple-macosx10.11

INSTALL_DIR = /usr/local/bin
install: release
	mkdir -p "$(INSTALL_DIR)"
	cp -f ".build/release/gift" "$(INSTALL_DIR)/gift"
