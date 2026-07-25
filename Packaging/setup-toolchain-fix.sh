#!/bin/zsh
# Repairs SwiftPM builds on a machine whose Command Line Tools install is
# broken by leftovers from an older CLT version:
#
#   1. PackageDescription.swiftmodule contains a STALE
#      *.private.swiftinterface (Swift 5.10 era) that shadows the correct
#      public interface, so package manifests reference symbols the dylib no
#      longer exports ("Undefined symbols ... Package.__allocating_init").
#   2. usr/include/swift contains BOTH module.modulemap and
#      bridging.modulemap defining module SwiftBridging, which breaks any
#      cold-cache clang module build ("redefinition of module
#      'SwiftBridging'", surfacing as "could not build module
#      'CoreServices'/'Foundation'").
#
# This script fixes both WITHOUT touching system files:
#   * copies the manifest libraries and deletes the stale private interfaces
#   * writes a VFS overlay that masks the duplicate modulemaps
#   * installs a swiftc wrapper that appends the overlay flag
#
# The permanent fix is: sudo rm /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
# (or reinstalling the CLT / installing full Xcode).
set -euo pipefail

FIX="$HOME/.hikari-swiftpm-libs"
CLT="/Library/Developer/CommandLineTools"

mkdir -p "$FIX"
rm -rf "$FIX/ManifestAPI" "$FIX/PluginAPI"
cp -R "$CLT/usr/lib/swift/pm/ManifestAPI" "$FIX/"
cp -R "$CLT/usr/lib/swift/pm/PluginAPI" "$FIX/"
find "$FIX" -name "*.private.swiftinterface" -delete

printf '// masked stale duplicate of SwiftBridging (broken CLT install)\n' > "$FIX/empty.modulemap"

cat > "$FIX/mask.yaml" <<EOF
{
  "version": 0,
  "roots": [
    { "type": "file",
      "name": "$CLT/usr/include/swift/bridging.modulemap",
      "external-contents": "$FIX/empty.modulemap" },
    { "type": "file",
      "name": "$CLT/usr/include/swift/module.modulemap",
      "external-contents": "$FIX/empty.modulemap" }
  ]
}
EOF

cat > "$FIX/swiftc" <<EOF
#!/bin/zsh
# Wrapper: injects a VFS overlay masking a duplicated SwiftBridging modulemap
# left behind by a broken Command Line Tools upgrade.
exec $CLT/usr/bin/swiftc "\$@" -vfsoverlay "$FIX/mask.yaml"
EOF
chmod +x "$FIX/swiftc"

echo "✓ Toolchain fix installed at $FIX"
