.PHONY: xcode-project test-server

xcode-project:
	@command -v xcodegen >/dev/null || (echo "Instala XcodeGen: brew install xcodegen" && exit 1)
	cd ios && xcodegen generate

test-server:
	npm run typecheck
	npm test
