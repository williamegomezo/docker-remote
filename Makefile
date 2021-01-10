# Define all shells to test with. Can be overridden with `make SHELLS=... <target>`.
	# Since we rely on paths relative to the makefile location, abort if make isn't being run from there.
$(if $(findstring /,$(MAKEFILE_LIST)),$(error Please only invoke this makefile from the directory it resides in))
	# Note: With Travis CI:
	#  - the path to urchin is passed via the command line.
	#  - the other utilities are NOT needed, so we skip the test for their existence.
URCHIN := urchin

SHELLS := sh bash dash zsh # ksh (#574)
# Generate 'test-<shell>' target names from specified shells.
# The embedded shell names are extracted on demand inside the recipes.
SHELL_TARGETS := $(addprefix test-,$(SHELLS))
# Define the default test suite(s). This can be overridden with `make TEST_SUITE=<...>  <target>`.
# Test suites are the names of subfolders of './test'.
TEST_SUITE := $(shell find ./test/* -type d -prune -exec basename {} \;)

# Set of test-<shell> targets; each runs the specified test suites for a single shell.
# Note that preexisting NVM_* variables are unset to avoid interfering with tests, except when running the Travis tests (where NVM_DIR must be passed in and the env. is assumed to be pristine).
.PHONY: $(SHELL_TARGETS)
$(SHELL_TARGETS):
	@shell='$@'; shell=$${shell##*-}; which "$$shell" >/dev/null || { printf '\033[0;31m%s\033[0m\n' "WARNING: Cannot test with shell '$$shell': not found." >&2; exit 0; } && \
	printf '\n\033[0;34m%s\033[0m\n' "Running tests in $$shell"; \
	for suite in $(TEST_SUITE); do $(URCHIN) -f -s $$shell test/$$suite || exit; done

# All-tests target: invokes the specified test suites for ALL shells defined in $(SHELLS).
.PHONY: test
test: $(SHELL_TARGETS)