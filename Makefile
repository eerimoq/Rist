FORMAT_ARGS=--maxwidth 110 --swiftversion 5
LINT_ARGS=--strict --quiet

all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat $(FORMAT_ARGS) Sources/Rist

style-check:
	swiftformat $(FORMAT_ARGS) --lint Sources/Rist

lint:
	swiftlint lint $(LINT_ARGS) Sources/Rist
