#!/bin/sh

# This script installs the Nix package manager on your system by
# downloading a binary distribution and running its installer script
# (which in turn creates and populates /nix).

{ # Prevent execution if this script was only partially downloaded
oops() {
    echo "$0:" "$@" >&2
    exit 1
}

tmpDir="$(mktemp -d -t nix-binary-tarball-unpack.XXXXXXXXXX || \
          oops "Can't create temporary directory for downloading the Nix binary tarball")"
cleanup() {
    rm -rf "$tmpDir"
}
trap cleanup EXIT INT QUIT TERM

require_util() {
    command -v "$1" > /dev/null 2>&1 ||
        oops "you do not have '$1' installed, which I need to $2"
}

case "$(uname -s).$(uname -m)" in
    Linux.x86_64) system=x86_64-linux; hash=afa6bf82bacb18ec0d6a1fd992b718192f895023d6cea8b94b2fb35fce352ff5;;
     Linux.aarch64) system=aarch64-linux; hash=dfbbaa86404c3efe74d87c8d4c39081affc673c8b5f64cfefc4ab0eaf84ed39b;;
    *) oops "sorry, there is no binary distribution of Nix for your platform";;
esac

url="https://releases.nixos.org/nix/nix-2.13.3/nix-2.13.3-$system.tar.xz"

tarball="$tmpDir/$(basename "$tmpDir/nix-2.13.3-$system.tar.xz")"

require_util curl "download the binary tarball"
require_util tar "unpack the binary tarball"
if [ "$(uname -s)" != "Darwin" ]; then
    require_util xz "unpack the binary tarball"
fi

echo "downloading Nix 2.13.3 binary tarball for $system from '$url' to '$tmpDir'..."
curl -L "$url" -o "$tarball" || oops "failed to download '$url'"

if command -v sha256sum > /dev/null 2>&1; then
    hash2="$(sha256sum -b "$tarball" | cut -c1-64)"
elif command -v shasum > /dev/null 2>&1; then
    hash2="$(shasum -a 256 -b "$tarball" | cut -c1-64)"
elif command -v openssl > /dev/null 2>&1; then
    hash2="$(openssl dgst -r -sha256 "$tarball" | cut -c1-64)"
else
    oops "cannot verify the SHA-256 hash of '$url'; you need one of 'shasum', 'sha256sum', or 'openssl'"
fi

if [ "$hash" != "$hash2" ]; then
    oops "SHA-256 hash mismatch in '$url'; expected $hash, got $hash2"
fi

unpack=$tmpDir/unpack
mkdir -p "$unpack"
tar -xJf "$tarball" -C "$unpack" || oops "failed to unpack '$url'"

script=$(echo "$unpack"/*/install)

[ -e "$script" ] || oops "installation script is missing from the binary tarball!"
"$script" "$@"

} # End of wrapping