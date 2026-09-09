#!/bin/sh
set -eu

input_dir=${1:?usage: build-apt-repository.sh INPUT_DIR OUTPUT_DIR}
output_dir=${2:?usage: build-apt-repository.sh INPUT_DIR OUTPUT_DIR}
suite=${APT_REPO_SUITE:-stable}
component=${APT_REPO_COMPONENT:-main}
key_id=${APT_REPO_GPG_KEY_ID:?APT_REPO_GPG_KEY_ID must name the signing key}
passphrase=${APT_REPO_GPG_PASSPHRASE:?APT_REPO_GPG_PASSPHRASE must contain the signing-key passphrase}

rm -rf "$output_dir"
mkdir -p "$output_dir/pool/$component"

found=0
architectures=
for package in "$input_dir"/*.deb; do
    [ -f "$package" ] || continue
    name=$(dpkg-deb -f "$package" Package)
    version=$(dpkg-deb -f "$package" Version)
    architecture=$(dpkg-deb -f "$package" Architecture)
    [ "$name" = cerberus-store-builder ] || continue
    case "$architecture" in
        amd64|arm64) ;;
        *)
        echo "unsupported architecture in $package: $architecture" >&2
        exit 1
        ;;
    esac
    cp "$package" "$output_dir/pool/$component/${name}_${version}_${architecture}.deb"
    architectures="$architectures $architecture"
    found=1
done

[ "$found" -eq 1 ] || {
    echo "no supported cerberus-store-builder .deb found in $input_dir" >&2
    exit 1
}

architectures=$(printf '%s\n' "$architectures" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')
for architecture in $architectures; do
    index_dir="$output_dir/dists/$suite/$component/binary-$architecture"
    mkdir -p "$index_dir"
    (
        cd "$output_dir"
        dpkg-scanpackages --multiversion --arch "$architecture" "pool/$component" /dev/null \
            > "dists/$suite/$component/binary-$architecture/Packages"
    )
    gzip -9n -c "$index_dir/Packages" > "$index_dir/Packages.gz"
    xz -9e -c "$index_dir/Packages" > "$index_dir/Packages.xz"
done

release_dir="$output_dir/dists/$suite"
apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=Cerberus" \
    -o "APT::FTPArchive::Release::Label=Cerberus" \
    -o "APT::FTPArchive::Release::Suite=$suite" \
    -o "APT::FTPArchive::Release::Codename=$suite" \
    -o "APT::FTPArchive::Release::Architectures=$architectures" \
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
