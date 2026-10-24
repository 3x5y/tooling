# Tooling

Personal configuration and scripts for macOS, Debian/Ubuntu, and WSL.

* `tooling`: public configuration and scripts.
* `private`: private configuration and scripts.
* Canonical Git repositories reside on the PILO server.
* `tooling` is mirrored publicly for bootstrap access.

## 1. Prerequisites

* POSIX shell and Git.
* macOS: install Xcode Command Line Tools (`xcode-select --install`).
* Debian/Ubuntu/WSL: `sudo apt-get install git openssh-client`.

## 2. Bootstrap

Clone the public repository:

```sh
mkdir -p ~/z/admin
git clone https://github.com/USER/tooling.git ~/z/admin/tooling
cd ~/z/admin/tooling
./install.sh
```

* Installs configuration using symlinks.
* Safe to rerun.
* Existing unrelated files are not overwritten.
* Does not provision software or modify OS preferences.

## 3. SSH

* Install public SSH configuration and trusted host keys.
* Verify the PILO server host key against a fingerprint obtained independently.
* Generate or restore the client SSH key.
* Authorize the public key on PILO.
* Verify access: `ssh pilo`.

## 4. Canonical repositories

Configure the PILO remote:

```sh
cd ~/z/admin/tooling
git remote add canonical pi10:/z/admin/tooling.git
git config remote.pushDefault canonical
```

Clone and install private configuration:

```sh
git clone pi10:/z/admin/private.git ~/z/admin/private
cd ~/z/admin/private
./install.sh
```

* Retain the public HTTPS remote for bootstrap and mirroring.
* Never commit unencrypted private keys or secrets.

## 5. Provisioning

Run explicitly as required:

```sh
# macOS
./provision/macos.sh

# Debian/Ubuntu/WSL
./provision/debian.sh

# macOS preferences
./preferences/macos.sh
```

* Provisioning and preferences are independent of configuration installation.
* WSL setup applies to the Linux environment only.

## 6. Updates

```sh
cd ~/z/admin/tooling
git pull --ff-only
./install.sh
```

Repeat for `~/z/admin/private` where installed.

* Symlinked configuration changes take effect without reinstalling.
* Rerun installers when links are added or changed.
* Run provisioning and preference scripts separately when required.
* Resolve installation conflicts manually.

