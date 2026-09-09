# Cerberus APT Repository

This repository publishes the signed APT archive for Cerberus Store Builder.
GitHub Actions downloads the `.deb` attached to an AppStoreFileBuilder GitHub
Release, generates APT metadata, signs it, and deploys it to GitHub Pages.

## User installation

After the first repository release is published, users install the archive key
and repository definition once:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/cerberus-store-builder-archive-keyring.pgp \
  https://ryvor.github.io/Cerberus-Apt-Repo/apt/cerberus-store-builder-archive-keyring.pgp
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/cerberus-store-builder-archive-keyring.pgp] https://ryvor.github.io/Cerberus-Apt-Repo/apt stable main' \
  | sudo tee /etc/apt/sources.list.d/cerberus-store-builder.list
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
     access to `ryvor/AppStoreFileBuilder`; required only if that repository is
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

1. In `AppStoreFileBuilder`, run `npm run build:linux` and create a GitHub
   Release with the generated `amd64.deb` attached.
2. In this repository, open **Actions → Publish APT repository → Run workflow**
   and enter the matching GitHub Release tag.
3. When the workflow completes, users receive the update with `sudo apt update`
   and `sudo apt upgrade`.

The workflow publishes only the newest package version. This is intentional for
a small single-package archive; clients already holding an older version can
still upgrade normally.
