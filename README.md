# Cerberus APT Repository

This repository publishes the signed APT archive for Cerberus Store Builder.
GitHub Actions downloads the `.deb` attached to an AppStoreFileBuilder GitHub
Release, generates APT metadata, signs it, and deploys it to GitHub Pages.

## User installation

After the first repository release is published, users install the archive key
and repository definition once:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/cerberus-store-builder-archive-keyring.pgp https://CerberusPanel.github.io/Cerberus-Apt-Repo/apt/cerberus-store-builder-archive-keyring.pgp
echo 'deb [signed-by=/etc/apt/keyrings/cerberus-store-builder-archive-keyring.pgp] https://CerberusPanel.github.io/Cerberus-Apt-Repo/apt stable main' | sudo tee /etc/apt/sources.list.d/cerberus-store-builder.list
sudo apt update
sudo apt install cerberus-store-builder
```

## One-time GitHub configuration

1. In **Settings → Pages**, set **Build and deployment** to **GitHub Actions**.
2. Create a dedicated OpenPGP signing key. Do not reuse a personal identity key.
3. Add these repository secrets in **Settings → Secrets and variables → Actions**:
   - `APT_REPO_GPG_PRIVATE_KEY`: ASCII-armoured private key export.
   - `APT_REPO_GPG_PASSPHRASE`: passphrase for that key.
   - `UPSTREAM_REPOSITORY_TOKEN`: a fine-grained token with read-only Contents
     access to `CerberusPanel/cerberus-store-builder`; required only if that repository is
     private.

Create and export a dedicated key locally:

```sh
gpg --quick-generate-key 'Cerberus APT Repository <ryvorsoftware@outlook.com>' rsa4096 sign 3y
gpg --list-secret-keys --keyid-format=long
gpg --armor --export-secret-keys KEY_FINGERPRINT
```

Paste the final command's output into `APT_REPO_GPG_PRIVATE_KEY`. Store a safe
offline backup of the private key and passphrase. Losing the key prevents you
from publishing trusted updates; publishing it compromises every user who
trusts the repository.

## Publishing a release

1. In `AppStoreFileBuilder`, build one or more Linux architectures and attach
   every generated `.deb` to the GitHub Release. The archive accepts `amd64`
   and `arm64` packages; Windows `.exe` and AppImage assets are ignored.
2. In this repository, open **Actions → Publish APT repository → Run workflow**
   and enter the matching GitHub Release tag.
3. When the workflow completes, users receive the update with `sudo apt update`
   and `sudo apt upgrade`.

The workflow publishes only the newest package version. This is intentional for
a small single-package archive; clients already holding an older version can
still upgrade normally.

## Adding more Cerberus applications

APT repositories can publish many applications from the same URL. Users add
this repository once, then install each application by its package name:

```sh
sudo apt install cerberus-store-builder
sudo apt install cerberus-panel
```

Each application must have a unique lowercase package name and publish its own
GitHub Release containing one `.deb` for each supported Linux architecture.
For example, a release may attach both an `amd64` and an `arm64` package. Do
not attach Windows installers or AppImages to the APT publication process;
they can remain GitHub Release assets but are not APT packages.

### Current repository limitation

This initial publisher intentionally supports only `cerberus-store-builder`.
It rebuilds a single-package archive, so it must be upgraded before a second
application is published. Do not attempt to publish another package with the
current workflow: it will reject a different package name.

### Before publishing the second app

1. Update the repository publisher to maintain a catalogue of applications and
   preserve every current package when a new release is added.
2. Register the new application's GitHub repository, release tag, and package
   name in that catalogue.
3. Build and attach the new application's Linux `.deb` assets to its GitHub
   Release.
4. Run the APT publisher. It will download all registered application releases,
   regenerate the shared package indexes, and sign the updated archive with the
   existing Cerberus APT signing key.

No new user repository setup or signing key is needed when adding applications;
existing users only run `sudo apt update` and install the new package by name.
