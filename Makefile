# Makefile for orthoviewer R package
#
# This automates building the neuroimjs dependency and installing the R package.
#
# Usage:
#   make all        - Build neuroimjs and install orthoviewer (default)
#   make build-js   - Build neuroimjs UMD bundle only
#   make copy-js    - Copy neuroimjs bundle to inst/htmlwidgets/lib/
#   make install    - Install the R package
#   make check      - Run R CMD check
#   make test       - Run package tests
#   make clean      - Remove copied JS artifacts
#   make clean-all  - Remove JS artifacts and uninstall R package

# Paths
NEUROIMJS_DIR := $(HOME)/code/jscode/neuroimjs
JS_LIB_DIR := inst/htmlwidgets/lib/neuroimjs
NEUROIMJS_BUNDLE := $(NEUROIMJS_DIR)/dist/neuroimjs.umd.js
NEUROIMJS_CSS := $(NEUROIMJS_DIR)/dist/style.css

# Default target
.PHONY: all
all: build-js copy-js install

# Build neuroimjs UMD bundle
.PHONY: build-js
build-js:
	@echo "Building neuroimjs UMD bundle..."
	cd $(NEUROIMJS_DIR) && npm run build:vite
	@echo "Done building neuroimjs."

# Create lib directory and copy JS artifacts
.PHONY: copy-js
copy-js: $(JS_LIB_DIR)
	@echo "Copying neuroimjs bundle to $(JS_LIB_DIR)..."
	cp $(NEUROIMJS_BUNDLE) $(JS_LIB_DIR)/
	cp $(NEUROIMJS_CSS) $(JS_LIB_DIR)/
	@echo "Done copying JS artifacts."
	@ls -lh $(JS_LIB_DIR)/

$(JS_LIB_DIR):
	mkdir -p $(JS_LIB_DIR)

# Install the R package
.PHONY: install
install:
	@echo "Installing orthoviewer R package..."
	Rscript -e "devtools::install(quick = TRUE, upgrade = 'never')"
	@echo "Done installing orthoviewer."

# Full rebuild: clean, build JS, copy, install
.PHONY: rebuild
rebuild: clean build-js copy-js install

# Run R CMD check
.PHONY: check
check:
	@echo "Running R CMD check..."
	Rscript -e "devtools::check()"

# Run package tests
.PHONY: test
test:
	@echo "Running tests..."
	Rscript -e "devtools::test()"

# Generate documentation
.PHONY: document
document:
	@echo "Generating documentation..."
	Rscript -e "devtools::document()"

# Run the example Shiny app
.PHONY: run-example
run-example:
	@echo "Starting example Shiny app..."
	Rscript -e "orthoviewer::orthoviewer_example_app()"

# Verify JS bundle contains required exports
.PHONY: verify-js
verify-js:
	@echo "Verifying neuroimjs bundle exports..."
	@printf "  neuroimjs global: " && \
		grep -q "globalThis.*neuroimjs" $(JS_LIB_DIR)/neuroimjs.umd.js && echo "OK" || echo "MISSING"
	@printf "  LayerControlPanel: " && \
		COUNT=$$(grep -c "LayerControlPanel" $(JS_LIB_DIR)/neuroimjs.umd.js) && \
		[ $$COUNT -gt 0 ] && echo "OK ($$COUNT refs)" || echo "MISSING"
	@printf "  layer-control-panel element: " && \
		grep -q "layer-control-panel" $(JS_LIB_DIR)/neuroimjs.umd.js && echo "OK" || echo "MISSING"
	@printf "  OrthogonalImageViewer: " && \
		grep -q "OrthogonalImageViewer" $(JS_LIB_DIR)/neuroimjs.umd.js && echo "OK" || echo "MISSING"

# Clean copied JS artifacts
.PHONY: clean
clean:
	@echo "Removing JS artifacts from $(JS_LIB_DIR)..."
	rm -rf $(JS_LIB_DIR)
	@echo "Done."

# Clean everything including R package
.PHONY: clean-all
clean-all: clean
	@echo "Uninstalling orthoviewer R package..."
	Rscript -e "try(remove.packages('orthoviewer'), silent = TRUE)"
	@echo "Done."

# Help target
.PHONY: help
help:
	@echo "orthoviewer Makefile targets:"
	@echo ""
	@echo "  all         - Build neuroimjs and install orthoviewer (default)"
	@echo "  build-js    - Build neuroimjs UMD bundle"
	@echo "  copy-js     - Copy neuroimjs bundle to inst/htmlwidgets/lib/"
	@echo "  install     - Install the R package"
	@echo "  rebuild     - Clean, build JS, copy, and install"
	@echo "  check       - Run R CMD check"
	@echo "  test        - Run package tests"
	@echo "  document    - Generate roxygen2 documentation"
	@echo "  run-example - Start the example Shiny app"
	@echo "  verify-js   - Verify JS bundle contains required exports"
	@echo "  clean       - Remove copied JS artifacts"
	@echo "  clean-all   - Remove JS artifacts and uninstall R package"
	@echo "  help        - Show this help message"
