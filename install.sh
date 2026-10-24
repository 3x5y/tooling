#!/bin/sh

SRC=~/z/admin/tooling

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

symlink "$SRC"/etc/bashrc  ~/.bashrc
symlink "$SRC"/etc/zshrc   ~/.zshrc
symlink "$SRC"/etc/inputrc ~/.inputrc
symlink "$SRC"/etc/vimrc   ~/.vimrc
symlink "$SRC"/etc/gitconfig ~/.gitconfig

mkdir -p ~/.ssh
chmod 700 ~/.ssh
symlink "$SRC"/etc/ssh/config ~/.ssh/config
symlink "$SRC"/etc/ssh/config.d ~/.ssh/config.d

mkdir -p ~/.vim
symlink "$SRC"/etc/vim/plugin ~/.vim/plugin
symlink "$SRC"/etc/vim/pack   ~/.vim/pack
