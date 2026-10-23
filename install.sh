#!/bin/sh

SRC=z/admin/tooling

symlink() {
    src=$1
    dst=$2

    if [ -L "$dst" ]
    then
        if [ "$(readlink "$dst")" = "$src" ]
        then
            return 0
        fi

        echo Conflict: "$dst" >&2
        return 1
    fi

    if [ -e "$dst" ]
    then
        echo Conflict: "$dst" >&2
        return 1
    fi

    mkdir -p $(dirname "$dst")
    ln -sv "$src" "$dst"
}

symlink "$SRC"/etc/bashrc  "$HOME"/.bashrc
symlink "$SRC"/etc/zshrc   "$HOME"/.zshrc
symlink "$SRC"/etc/inputrc "$HOME"/.inputrc
symlink "$SRC"/etc/vimrc   "$HOME"/.vimrc
symlink "$SRC"/etc/gitconfig "$HOME"/.gitconfig

mkdir -p ~/.ssh
chmod 700 ~/.ssh
symlink ~/"$SRC"/etc/ssh/config "$HOME"/.ssh/config
symlink ~/"$SRC"/etc/ssh/config.d "$HOME"/.ssh/config.d
