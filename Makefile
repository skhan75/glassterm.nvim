NVIM ?= nvim
STYLUA_VERSION ?= 2.1.0
STYLUA := deps/bin/stylua

.PHONY: test test-file deps format lint bench clean

# Run every tests/test_*.lua file.
test: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

# Run one file: make test-file FILE=tests/test_styles.lua
test-file: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

deps: deps/mini.nvim

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

$(STYLUA):
	@mkdir -p deps/bin
	@os=$$(uname -s); arch=$$(uname -m); \
	case "$$os-$$arch" in \
		Darwin-arm64) asset=stylua-macos-aarch64.zip ;; \
		Darwin-x86_64) asset=stylua-macos.zip ;; \
		Linux-aarch64) asset=stylua-linux-aarch64.zip ;; \
		*) asset=stylua-linux-x86_64.zip ;; \
	esac; \
	curl -fsSL -o deps/stylua.zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v$(STYLUA_VERSION)/$$asset" \
		&& unzip -o -q deps/stylua.zip -d deps/bin && rm deps/stylua.zip && chmod +x $@

format: $(STYLUA)
	$(STYLUA) lua plugin tests

lint: $(STYLUA)
	$(STYLUA) --check lua plugin tests

# Keypress-to-redraw latency through a real pseudo-terminal.
bench:
	python3 scripts/bench.py

clean:
	rm -rf deps
