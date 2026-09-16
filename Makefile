.DEFAULT_GOAL := build
.PHONY: setup build run test bundle wasm apple-build apple-test ios-build overlay

setup:
	rustup target add wasm32-unknown-unknown
	npm ci

build:
	npm run build

run:
	npm run dev

test:
	npm test

bundle:
	npm run bundle

wasm:
	npm run build:wasm

apple-build:
	cmake --preset debug
	cmake --build --preset debug

apple-test: apple-build
	ctest --test-dir build/debug --output-on-failure

ios-build:
	./scripts/run_ios_iphone.sh --build-only

overlay:
	bash tools/matte-overlay/build.sh
