#!/bin/bash
# Print the Homebrew formula for a release. The release workflow writes it to the
# job summary; copy it to Formula/index-store-mcp.rb in hrdkp/homebrew-tap.
#
# Usage: scripts/render-formula.sh VERSION SHA256
set -euo pipefail

version="${1:?usage: render-formula.sh VERSION SHA256}"
sha256="${2:?usage: render-formula.sh VERSION SHA256}"
root="$(cd "$(dirname "$0")/.." && pwd)"
minimum_xcode="$(sed -nE 's/.*static let minimumXcode = "([^"]+)".*/\1/p' "$root/Sources/IndexStoreMCP/BuildInfo.swift")"
[[ -n "$minimum_xcode" ]] || { echo "FAIL: could not read BuildInfo.minimumXcode" >&2; exit 1; }

cat <<RUBY
class IndexStoreMcp < Formula
  desc "MCP server giving coding agents semantic code navigation for Xcode projects"
  homepage "https://github.com/hrdkp/swift-index-store-mcp"
  url "https://github.com/hrdkp/swift-index-store-mcp/releases/download/v${version}/index-store-mcp-${version}-arm64-macos.tar.gz"
  sha256 "${sha256}"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sonoma
  depends_on xcode: "${minimum_xcode}"

  def install
    bin.install "index-store-mcp"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/index-store-mcp --version").strip
  end
end
RUBY
