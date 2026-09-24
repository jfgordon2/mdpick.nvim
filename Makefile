.PHONY: test lint

test:
	nvim --headless --clean -u tests/minimal_init.lua -l tests/run.lua

lint:
	luacheck lua plugin tests

