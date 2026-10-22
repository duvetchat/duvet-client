#!/usr/bin/env bash
# Regenerates test/fixtures/ from the server's own response types: copies the
# generators (*.go.tmpl) into a throwaway package of the API and the gateway
# checkouts, runs them with `go test`, and removes them.
#
#   tool/fixtures/generate.sh [API_DIR] [GATEWAY_DIR]
#
# The checkouts default to ../api and ../gateway, next to duvet-client.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
client="$(cd "$here/../.." && pwd)"
api="$(cd "${1:-$client/../api}" && pwd)"
gateway="$(cd "${2:-$client/../gateway}" && pwd)"
out="$client/test/fixtures"

run() { # module dir, generator template
	local pkg="$1/zz_fixtures"
	if [[ -e "$pkg" ]]; then
		echo "$pkg already exists; remove it first" >&2
		exit 1
	fi
	mkdir "$pkg"
	trap 'rm -rf "$pkg"' RETURN
	cp "$here/fill_test.go.tmpl" "$pkg/fill_test.go"
	cp "$here/$2" "$pkg/fixtures_test.go"
	(cd "$1" && FIXTURES_DIR="$out" go test -count=1 ./zz_fixtures/)
}

rm -f "$out"/*.json
mkdir -p "$out"
run "$api" api_fixtures_test.go.tmpl
run "$gateway" gateway_fixtures_test.go.tmpl
echo "$(ls "$out" | wc -l) fixtures in $out"
