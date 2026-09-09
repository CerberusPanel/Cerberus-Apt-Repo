#!/bin/sh
set -eu

input_dir=${1:?usage: build-apt-repository.sh INPUT_DIR OUTPUT_DIR}
output_dir=${2:?usage: build-apt-repository.sh INPUT_DIR OUTPUT_DIR}
suite=${APT_REPO_SUITE:-stable}
component=${APT_REPO_COMPONENT:-main}
key_id=${APT_REPO_GPG_KEY_ID:?APT_REPO_GPG_KEY_ID must name the signing key}
passphrase=${APT_REPO_GPG_PASSPHRASE:?APT_REPO_GPG_PASSPHRASE must contain the signing-key passphrase}

rm -rf "$output_dir"
mkdir -p "$output_dir/pool/$component/c"

found=0
for package in "$input_dir"/*.deb; do
    [ -f "$package" ] || continue
    name=$(dpkg-deb -f "$package" Package)
    architecture=$(dpkg-deb -f "$package" Architecture)
    [ "$name" = cerberus-store-builder ] || continue
    [ "$architecture" = amd64 ] || {
        echo "unsupported architecture in $package: $architecture" >&2
        exit 1
    }
    mkdir -p "$output_dir/pool/$component/c/$name"
    cp "$package" "$output_dir/pool/$component/c/$name/"
    found=1
done

[ "$found" -eq 1 ] || {
    echo "no cerberus-store-builder amd64 .deb found in $input_dir" >&2
    exit 1
}

index_dir="$output_dir/dists/$suite/$component/binary-amd64"
mkdir -p "$index_dir"
(
    cd "$output_dir"
    dpkg-scanpackages --arch amd64 "pool/$component" /dev/null > "$index_dir/Packages"
)
gzip -9n -c "$index_dir/Packages" > "$index_dir/Packages.gz"
xz -9e -c "$index_dir/Packages" > "$index_dir/Packages.xz"

release_dir="$output_dir/dists/$suite"
apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=Cerberus" \
    -o "APT::FTPArchive::Release::Label=Cerberus" \
    -o "APT::FTPArchive::Release::Suite=$suite" \
    -o "APT::FTPArchive::Release::Codename=$suite" \
    -o "APT::FTPArchive::Release::Architectures=amd64" \
    -o "APT::FTPArchive::Release::Components=$component" \
    -o "APT::FTPArchive::Release::Description=Cerberus application repository" \
    release "$release_dir" > "$release_dir/Release"

gpg --batch --yes --pinentry-mode loopback --passphrase "$passphrase" \
    --local-user "$key_id" --armor --detach-sign \
    --output "$release_dir/Release.gpg" "$release_dir/Release"
gpg --batch --yes --pinentry-mode loopback --passphrase "$passphrase" \
    --local-user "$key_id" --clearsign \
    --output "$release_dir/InRelease" "$release_dir/Release"
gpg --batch --yes --export-options export-minimal --export "$key_id" \
    > "$output_dir/cerberus-store-builder-archive-keyring.pgp"
