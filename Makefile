all: xcode
xcode:
	swift package generate-xcodeproj
build:
	swift build
test:
	swift test
