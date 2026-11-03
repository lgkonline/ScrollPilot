#!/bin/bash
set -euo pipefail

# Build an isolated Swift Testing package from the actual production sources.
# This keeps the test runner independent of app signing and TCC permissions.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ScrollPilotTests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Sources/NavigationGestures" "$test_dir/Tests/NavigationGesturesTests"
cp "$repo_root/NavigationGestureDecoder.swift" "$repo_root/NavigationGestureRemapper.swift" "$test_dir/Sources/NavigationGestures/"
cp "$repo_root/Tests/NavigationGestureTests.swift" "$test_dir/Tests/NavigationGesturesTests/"
cat > "$test_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "NavigationGestures",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "NavigationGestures"),
        .testTarget(name: "NavigationGesturesTests", dependencies: ["NavigationGestures"])
    ],
    swiftLanguageModes: [.v5]
)
SWIFT
export CLANG_MODULE_CACHE_PATH="$test_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$test_dir/ModuleCache"
xcrun swift test --package-path "$test_dir" \
    --cache-path "$test_dir/Cache" \
    --config-path "$test_dir/Configuration" \
    --security-path "$test_dir/Security" \
    "$@"
