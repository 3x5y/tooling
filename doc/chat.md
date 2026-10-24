# Tooling bootstrap and configuration strategy

## 1. Recommended approach

Use **two Git repositories, a small POSIX shell bootstrap, and explicit setup commands**. Avoid introducing a dotfile manager, configuration-management framework, or package-manager abstraction.

Separate four responsibilities:

| Responsibility    | Mechanism                          | Purpose                                           |
| ----------------- | ---------------------------------- | ------------------------------------------------- |
| Bootstrap         | POSIX shell script                 | Obtain the repositories with minimal dependencies |
| Configuration     | Repository files and symlinks      | Install and update dotfiles                       |
| Provisioning      | Platform-specific scripts          | Install software dependencies                     |
| Environment setup | Explicit platform-specific scripts | Configure OS and user preferences                 |

Keep `tooling` public and independently usable. Treat `private` as an optional additional configuration layer, not a prerequisite for using `tooling`.

The central principle is:

**Bootstrap establishes access to the configuration. Configuration does not bootstrap itself, and provisioning does not implicitly modify configuration.**

This avoids circular dependencies and allows a new machine to start from a minimal OS installation.

I would use this layout:

```text
~/src/
    tooling/
    private/

~/.config/
    ...
```

The repositories remain ordinary Git working trees. Installed configuration files are symlinks into them.

For example:

```text
~/.vimrc        -> ~/src/tooling/vim/vimrc
~/.gitconfig    -> ~/src/tooling/git/gitconfig
~/.bashrc       -> ~/src/tooling/bash/bashrc
~/.zshrc        -> ~/src/tooling/zsh/zshrc
```

There is no generated configuration directory, deployment database, or persistent installation manifest.

The symlinks make updates immediate: changing a tracked file in the repository changes the active configuration.

The tradeoff is that configuration depends on the repository remaining at its installed location. For a personal system with a fixed directory convention, that is reasonable.

## 2. Repository structure

Keep the repositories small and organized by responsibility rather than by machine.

### Public repository: `tooling`

```text
tooling/
├── bootstrap.sh
├── install.sh
├── README.md
│
├── bash/
│   └── bashrc
├── zsh/
│   └── zshrc
├── vim/
│   ├── vimrc
│   └── pack/
├── git/
│   └── gitconfig
├── ssh/
│   ├── config
│   └── known_hosts
│
├── bin/
│   └── ...
│
├── provision/
│   ├── macos.sh
│   └── debian.sh
│
└── preferences/
    └── macos.sh
```

### Private repository: `private`

```text
private/
├── install.sh
│
├── ssh/
│   ├── config
│   └── keys/
│
├── git/
│   └── config
│
└── bin/
    └── ...
```

This is an illustrative structure. Only create directories when they have actual contents.

The public repository should contain no secrets, but it can contain public SSH host keys, public user keys, Git identity, and other non-secret configuration.

The private repository contains sensitive configuration and credentials. It must never be required for the public repository to function.

A useful invariant is that **every machine can install `tooling` without having access to `private`**.

## 3. Bootstrap

### Prerequisites

The bootstrap should require only:

* A POSIX-compatible shell.
* Git.
* HTTPS access to the public repository.

Do not require Bash, Zsh, Python, Homebrew, GNU utilities, or a particular shell configuration.

For macOS, installing Xcode Command Line Tools is an acceptable prerequisite:

```sh
xcode-select --install
```

For Debian/Ubuntu:

```sh
sudo apt-get update
sudo apt-get install git openssh-client
```

For WSL, use the same Debian/Ubuntu procedure inside the Linux distribution.

The scripts should run within WSL, not attempt to configure native Windows.

### Bootstrap sequence

I would use a two-stage bootstrap.

**Stage 1: obtain `tooling`.**

On a new machine:

```sh
mkdir -p "$HOME/src"
git clone https://github.com/USER/tooling.git "$HOME/src/tooling"
```

Then:

```sh
cd "$HOME/src/tooling"
./install.sh
```

This is preferable to:

```sh
curl https://example.com/bootstrap.sh | sh
```

Cloning first allows inspection of the repository and script before execution. It also avoids needing both `curl` and Git.

If you want a one-command bootstrap later, a downloadable script can perform the same clone and installation. It should remain a convenience wrapper rather than a separate implementation.

**Stage 2: establish canonical repository access.**

Once the public SSH configuration is installed and the machine has the necessary private key, configure the canonical remote:

```sh
git remote add canonical \
    git@pilo:tooling.git
```

The exact URL depends on your server's Git repository layout.

I would retain the HTTPS public mirror as a separate remote:

```text
origin      https://github.com/USER/tooling.git
canonical   git@pilo:tooling.git
```

This is clearer than replacing the original remote.

It also makes the roles explicit:

* `origin`: public bootstrap source and mirror.
* `canonical`: authoritative repository on the PILO server.

You can configure the local branch to push to `canonical` without making the public mirror the default push destination.

For example:

```sh
git config remote.pushDefault canonical
```

This avoids accidentally pushing private or unfinished changes to the public mirror.

The same remote arrangement is not necessary for `private`, which should normally have only its canonical SSH remote.

## 4. SSH configuration and key management

SSH is the most important part of the design because it creates a genuine bootstrap dependency:

1. Accessing the canonical repositories requires SSH.
2. SSH requires host trust and user authentication.
3. Some of that configuration lives in the repositories.

The cleanest solution is to divide SSH configuration into **public connection metadata, private authentication material, and an initial trust anchor**.

### Public SSH configuration

I would put stable host definitions in `tooling`:

```sshconfig
Host pilo
    HostName pilo.example.net
    User myuser
    IdentityFile ~/.ssh/keys/pilo
    IdentitiesOnly yes
```

The `HostName` and `User` values are generally not secrets. Nor are public host keys.

Your public repository can also contain a curated `known_hosts` file for stable infrastructure.

However, a host fingerprint obtained from the same untrusted source as the SSH connection does not independently establish trust.

**The public GitHub mirror is a useful distribution mechanism, but it is not automatically an independent trust anchor.**

For the PILO server, establish its SSH host key fingerprint through a trusted channel, ideally during server provisioning or by inspecting its console. Record the expected fingerprint in your bootstrap documentation.

Then verify the installed host key against that fingerprint before accepting the connection.

Avoid `StrictHostKeyChecking=no` and automated acceptance of arbitrary keys.

### User authentication keys

I would retain your preference for separate keys, but reconsider the granularity.

There are three reasonable approaches:

| Strategy                               | Advantages                                            | Disadvantages                                                |
| -------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------ |
| One key per host pair                  | Fine-grained revocation and isolation                 | Many keys and SSH stanzas                                    |
| One key per client machine             | Simple management; individual machines can be revoked | Compromise exposes access to every service trusting that key |
| One key per client and security domain | Balances isolation and administration                 | Slightly more configuration                                  |

**I recommend one key per client machine and security domain.**

For example:

```text
~/.ssh/keys/
    personal
    infrastructure
    work
    temporary
```

A laptop might use its `infrastructure` key for PILO and other trusted personal infrastructure, but a separate key for unrelated services.

This is simpler than maintaining a distinct key for every host pair without using a single universal identity.

For temporary deployments, a dedicated key is still sensible when isolation or independent revocation matters.

Remember that an SSH public key can be installed on multiple servers. The same private key can authenticate to those servers without being transmitted to them. Reusing a key does not inherently allow one server to impersonate the client, although compromise of the client's private key affects every server that trusts it.

### Private keys and the `private` repository

I would **not store unencrypted SSH private keys in Git**, even in the private repository.

Git retains historical versions, and a repository compromise may expose credentials that were removed from the current tree.

For now, use one of these approaches:

* Generate keys locally on each machine and distribute the corresponding public keys to authorized servers.
* Restore encrypted private keys from a separate, trusted backup.
* Use a hardware-backed key where practical.

The first option is particularly attractive for your setup.

It requires a small amount of manual provisioning, but avoids introducing encryption tooling into the bootstrap dependency chain.

Your `private` repository can contain SSH host definitions and other sensitive configuration without containing private authentication keys.

### SSH bootstrap sequence

For a new client:

1. Clone `tooling` over HTTPS.
2. Install public SSH configuration and trusted host keys.
3. Generate or restore the client's SSH authentication key.
4. Authorize its public key on the PILO server through an existing trusted administrative path.
5. Verify the server's SSH host identity.
6. Clone `private` from PILO.
7. Install private configuration.
8. Configure the canonical remote for `tooling`.

This is a deliberate bootstrap procedure rather than a fully automatic one.

I would not attempt to eliminate the initial trust-establishment step. Doing so generally means relocating the trust problem rather than solving it.

### SSH configuration layering

OpenSSH supports `Include`, so use that instead of constructing a combined configuration file.

For example, install this as `~/.ssh/config`:

```sshconfig
Include ~/.ssh/config.d/private.conf
Include ~/.ssh/config.d/tooling.conf

Host *
    IdentitiesOnly yes
```

Install the public and private files independently.

Because OpenSSH generally uses the first value obtained for a parameter, order matters. More specific definitions should precede general defaults.

Keep private and public host aliases distinct where practical to avoid accidental overrides.

For known host keys, I would initially use OpenSSH's normal `~/.ssh/known_hosts`, with a small curated file for trusted PILO infrastructure if needed. The `UserKnownHostsFile` directive can add a curated file, but be careful not to accidentally disable ordinary host-key recording.

There is no need for a sophisticated SSH configuration generator.

---

## 5. Configuration installation

Use a small, idempotent installer based on symlinks.

The installer should:

* Create required directories.
* Create missing symlinks.
* Leave correct symlinks unchanged.
* Replace symlinks previously installed by the same repository when their targets need updating.
* Refuse to overwrite unrelated files or directories.
* Report conflicts and stop.

For example, a minimal helper:

```sh
link_file() {
    src=$1
    dst=$2

    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then
            return 0
        fi

        printf 'Conflict: %s\n' "$dst" >&2
        return 1
    fi

    if [ -e "$dst" ]; then
        printf 'Conflict: %s\n' "$dst" >&2
        return 1
    fi

    ln -s "$src" "$dst"
}
```

Usage:

```sh
link_file \
    "$HOME/src/tooling/vim/vimrc" \
    "$HOME/.vimrc"
```

This deliberately does not attempt to repair every possible filesystem state.

An existing unrelated file is a conflict requiring explicit intervention.

For simplicity, the example refuses to replace even a stale symlink. That is conservative and appropriate initially. Automatic replacement of recognized, previously managed symlinks can be added if it becomes useful.

### Avoid automatic backups

Many dotfile installers automatically rename existing configuration files to `.bak` or timestamped backups.

I would avoid that.

It creates hidden state and makes repeated installation behaviour less predictable.

Instead, report the conflict and let the operator decide whether to remove, rename, or incorporate the existing configuration.

### Public and private configuration

Prefer independent files and native include mechanisms.

For example, Git supports:

```gitconfig
[include]
    path = ~/src/tooling/git/common.gitconfig

[include]
    path = ~/src/private/git/config
```

An absent include file is tolerated, allowing `tooling` to work without `private`.

You could make the public Git configuration the main `~/.gitconfig` and have it include the private file.

Similar layering is possible for Vim, Bash, Zsh, and SSH.

**Use native configuration includes rather than generating merged configuration files.**

That keeps the installation process independent of application-specific configuration semantics.

---

## 6. Git configuration

I would keep your dedicated Git email address in the public repository.

If it is already associated with public commits, hiding it from the configuration repository provides little practical benefit.

A minimal Git configuration might be:

```gitconfig
[user]
    name = Your Name
    email = git@example.net

[core]
    editor = vim

[include]
    path = ~/src/private/git/config
```

Private overrides can supply machine-specific or sensitive settings.

For different identities, consider Git's conditional includes:

```gitconfig
[includeIf "gitdir:~/src/work/"]
    path = ~/src/private/git/work.gitconfig
```

This is preferable to a custom script that rewrites Git identity based on the machine.

### Canonical remotes

I would not hardcode the canonical remote into the public repository's bootstrap process.

The initial clone can retain its HTTPS remote. A separate command can establish the canonical remote once SSH is available.

For example:

```sh
git remote add canonical git@pilo:tooling.git
git config remote.pushDefault canonical
```

One caveat: `remote.pushDefault` determines the preferred remote for pushing, but branch-specific settings and Git's push configuration can affect the final destination.

Check `git remote -v` and the configured upstream before the first push.

For maximum simplicity, explicitly using:

```sh
git push canonical
```

is also perfectly reasonable.

I would initially prefer explicit pushes rather than introduce automatic mirroring between PILO and GitHub.

---

## 7. Vim configuration and plugins

For your current scale, **vendoring plugins is a reasonable choice**.

Vim 8 introduced native package support, which eliminates the need for a plugin manager for many conventional plugins.

A possible layout:

```text
vim/
├── vimrc
└── pack/
    └── tooling/
        └── start/
            ├── plugin-a/
            └── plugin-b/
```

Install:

```text
~/.vim/
    pack -> ~/src/tooling/vim/pack
```

Or link the entire `.vim` directory if you do not need machine-local content inside it.

### Vendoring versus submodules

| Approach       | Advantages                                        | Disadvantages                                          |
| -------------- | ------------------------------------------------- | ------------------------------------------------------ |
| Vendoring      | Self-contained; works offline; ordinary Git clone | Manual plugin updates; repository grows                |
| Git submodules | Tracks upstream repositories and exact commits    | Extra clone/update commands; more bootstrap complexity |
| Plugin manager | Convenient installation and updating              | Adds another dependency and installation mechanism     |

For two or three small plugins, vendoring is the simplest option.

It also provides reproducibility: the checked-out `tooling` commit determines the plugin versions.

When you update a plugin, update the vendored files and commit the result.

If you eventually accumulate many large plugins, reconsider submodules. There is no need to solve that problem now.

### Compatibility

Keep the main `vimrc` conservative:

```vim
set nocompatible
set number
set hidden

if has('syntax')
    syntax enable
endif
```

Guard optional features:

```vim
if has('packages')
    " Package-dependent configuration.
endif
```

Note that native packages require a sufficiently recent Vim. Older Vim versions will not load packages through this mechanism.

If supporting older Vim installations is important, you can maintain a minimal base configuration that works without plugins.

Avoid making the entire editor configuration depend on a plugin manager or modern scripting features.

---

## 8. Bash and Zsh

Keep both configurations minimal and largely independent.

For example:

```text
bash/
    bashrc
    profile

zsh/
    zshrc
    zprofile

shell/
    aliases
    environment
```

Share only genuinely portable shell configuration.

Do not force Bash and Zsh to source a large common configuration file containing shell-specific syntax.

A small POSIX-compatible shared file is reasonable:

```sh
# shell/environment
export EDITOR=vim
export PAGER=less
```

Both shells can source it.

For interactive aliases and functions, use separate files if portability becomes awkward.

### PATH management

For your scripts, prefer a stable location:

```text
~/src/tooling/bin
```

Add it to `PATH` through shell configuration.

For scripts needed by non-interactive programs, do not assume interactive shell startup files will be loaded.

Use explicit paths or configure the invoking service's environment.

This is particularly important for PILO's systemd services.

---

## 9. Provisioning tools

Keep provisioning separate from configuration installation.

I would use small platform-specific scripts rather than one script that tries to identify and support every possible operating system.

For example:

```text
provision/
    macos.sh
    debian.sh
```

WSL running Debian or Ubuntu can use `debian.sh`.

The scripts should be explicit about their assumptions.

### macOS

Assume:

* Xcode Command Line Tools are installed.
* Git is available.
* The user has chosen whether to install Homebrew.

A provisioning script can install packages using Homebrew, but **do not make Homebrew a prerequisite for installing dotfiles**.

You could eventually use a `Brewfile`, but for a small number of packages, a shell script is adequate.

### Debian and Ubuntu

Use `apt` directly.

For example:

```sh
#!/bin/sh
set -eu

sudo apt-get update
sudo apt-get install -y \
    git \
    openssh-client \
    vim \
    zsh
```

Package installation is generally repeatable, although it is not strictly free of side effects: subsequent runs may install newer package versions.

Keep package selection explicit rather than trying to derive it from the configuration repository.

### WSL

Treat WSL primarily as a Linux environment.

Do not mix Windows and Linux configuration provisioning unless there is a specific requirement.

Native Windows configuration can be addressed separately if it becomes necessary.

### PILO server

The PILO server should use the same public configuration repository where appropriate, but I would distinguish **interactive user tooling** from **server operational dependencies**.

The PILO installation process should provision everything required for PILO's own operation.

It should not depend on the interactive user's dotfiles, shell aliases, or `~/src/tooling/bin`.

Conversely, installing personal tooling should not modify PILO's ZFS configuration, systemd units, or storage topology.

This separation is important for recovery and reproducibility.

---

## 10. Environment preferences

Keep operating-system preferences separate from package provisioning.

For example:

```text
preferences/
    macos.sh
```

This script might use `defaults write` to configure selected macOS settings.

Run it explicitly:

```sh
./preferences/macos.sh
```

Do not invoke it automatically during bootstrap or dotfile installation.

Some settings are immediately effective; others require restarting an application, logging out, or restarting the relevant service.

Document these requirements in the script.

I would avoid trying to read the existing state of every preference and construct a complex reconciliation mechanism.

For simple settings, repeated assignment of the desired value is sufficient.

---

## 11. Update workflow

Once bootstrapped, normal maintenance should be straightforward.

For public configuration:

```sh
cd ~/src/tooling
git pull --ff-only
./install.sh
```

For private configuration:

```sh
cd ~/src/private
git pull --ff-only
./install.sh
```

Because the configuration files are symlinked, most changes become effective immediately.

The installer is only needed when adding or changing links.

Shell configuration changes require starting a new shell or explicitly reloading the relevant file.

Provisioning and preference scripts remain independent operations:

```sh
./provision/debian.sh
./preferences/macos.sh
```

I would not initially introduce a single `update-everything` command.

Updating Git repositories, installing software, and changing OS preferences have different consequences. Keeping those operations separate makes failures and side effects easier to understand.

---

## 12. Suggested implementation sequence

I would implement this incrementally.

| Stage | Deliverable                 | Scope                                                                   |
| ----- | --------------------------- | ----------------------------------------------------------------------- |
| 1     | Public `tooling` repository | Bash, Zsh, Vim, Git configuration                                       |
| 2     | Minimal `install.sh`        | Symlinks, directory creation, conflict detection                        |
| 3     | Public HTTPS bootstrap      | Documented clone and install procedure                                  |
| 4     | SSH configuration           | Public host definitions, verified PILO host key, per-client credentials |
| 5     | Private repository          | Optional configuration and sensitive scripts                            |
| 6     | Canonical Git remote setup  | Explicit transition from public bootstrap to PILO authority             |
| 7     | Provisioning scripts        | macOS and Debian/Ubuntu                                                 |
| 8     | Environment preferences     | Explicit macOS defaults                                                 |
| 9     | Vim plugins                 | Vendored native Vim packages                                            |

Each stage should work without requiring subsequent stages.

In particular, stages 1–3 should produce a usable development environment without access to PILO or the private repository.

### Testing

For this scale, I would test only a few important installation properties:

* Running the installer twice produces the same symlinks.
* Existing unrelated configuration files are not overwritten.
* The public configuration works without the private repository.
* The bootstrap works without Bash-specific features or optional tools.
* SSH configuration resolves the intended host, identity, and host-key policy.
* The configuration works on at least one macOS and one Debian/Ubuntu installation.

A small shell test script is sufficient. There is no need for a testing framework.

---

## 13. Future expansion

Several extensions remain available without changing the basic design.

**More applications:** Add configuration directories and installer entries. Continue using native include mechanisms where available.

**Machine-specific configuration:** Use small, explicit host-local files that are not tracked by Git. Avoid introducing hostname-based conditionals until they are genuinely needed.

**Secrets management:** If the private repository eventually needs to contain encrypted credentials, consider `age` or another simple encryption tool. This would introduce an additional dependency, so defer it until there is a concrete requirement.

**SSH certificates:** If you eventually manage many hosts and identities, SSH user and host certificates could simplify trust and authorization. For the current number of machines, pinned host keys and ordinary public-key authentication are sufficient.

**Package manifests:** Homebrew's `Brewfile` and Debian package lists may become useful if provisioning scripts grow. Neither needs to be introduced initially.

**Declarative configuration managers:** Tools such as GNU Stow, chezmoi, or Ansible remain options if the requirements become substantially more complex. The proposed repository layout does not prevent adopting one later.

---

## Final design decisions

I would settle on the following:

| Concern                    | Decision                                                                      |
| -------------------------- | ----------------------------------------------------------------------------- |
| Repositories               | `tooling` public, `private` restricted                                        |
| Canonical authority        | PILO Git repositories                                                         |
| Bootstrap source           | Public HTTPS mirror                                                           |
| Bootstrap dependencies     | POSIX shell and Git                                                           |
| Repository location        | `~/src/tooling`, `~/src/private`                                              |
| Configuration installation | Simple symlinks                                                               |
| Installation behaviour     | Idempotent; conflicts are fatal                                               |
| Public/private layering    | Native application includes                                                   |
| SSH authentication         | Separate keys per client and security domain                                  |
| SSH host trust             | Pinned keys verified through a trusted bootstrap channel                      |
| SSH private keys           | Generated locally or restored securely, not committed unencrypted             |
| Git remotes                | Public HTTPS `origin`, PILO SSH `canonical`                                   |
| Vim plugins                | Vendored, using native Vim packages                                           |
| Software provisioning      | Explicit platform-specific scripts                                            |
| OS preferences             | Separate scripts                                                              |
| Updates                    | Explicit Git pulls; rerun installer when necessary                            |
| PILO server                | Same user tooling where appropriate; operational dependencies remain separate |

**The only unavoidable complication is SSH trust establishment.** Everything else can be reduced to ordinary Git operations, shell scripts, symlinks, and native application configuration.

I would resist adding further machinery until a concrete requirement makes this arrangement insufficient.
