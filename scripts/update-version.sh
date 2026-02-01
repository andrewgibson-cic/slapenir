#!/bin/bash
# Update version numbers in source files
# Usage: ./scripts/update-version.sh <version>

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version not provided"
  echo "Usage: $0 <version>"
  exit 1
fi

echo "Updating version to: $VERSION"

# Update Cargo.toml version
if [ -f "proxy/Cargo.toml" ]; then
  echo "Updating proxy/Cargo.toml..."
  sed -i.bak "s/^version = \".*\"/version = \"$VERSION\"/" proxy/Cargo.toml
  rm proxy/Cargo.toml.bak 2>/dev/null || true
  echo "✅ Updated proxy/Cargo.toml to version $VERSION"
fi

# Update any Python package versions if they exist
if [ -f "agent/setup.py" ]; then
  echo "Updating agent/setup.py..."
  sed -i.bak "s/version=\".*\"/version=\"$VERSION\"/" agent/setup.py
  rm agent/setup.py.bak 2>/dev/null || true
  echo "✅ Updated agent/setup.py to version $VERSION"
fi

# Update VERSION file
echo "$VERSION" > VERSION
echo "✅ Created VERSION file"

echo ""
echo "Version update complete!"
echo "Files updated:"
[ -f "proxy/Cargo.toml" ] && echo "  - proxy/Cargo.toml"
[ -f "agent/setup.py" ] && echo "  - agent/setup.py"
echo "  - VERSION"