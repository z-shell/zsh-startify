# `ZSH-STARIFY`

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-blue?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Screenshots](#screenshots)
- [Installation](#installation)
  - [Any plugin manager](#any-plugin-manager)
  - [Zplugin](#zplugin)
- [Quick Start](#quick-start)
  - [Zstyles](#zstyles)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

A plugin that aims at providing what
[vim-startify](https://github.com/mhinz/vim-startify) plugin does, but in Zsh. The
analogy isn't fully easy to make. `vim-startify` states:

> It provides dynamically created headers or footers and uses configurable lists to
> show recently used or bookmarked files and persistent sessions.

zsh-startify:

- shows recently used files if used by a shell-utill command, with name of the
  command(s) on othe right,
- shows recently used vim files,
- will show active tmux sessions,
- will show statistics of most popular aliases in use,
- will show recently visited projects (i.e. `git` repositories, but also directories
  with a `Makefile`, a `CMakeLists.txt`, a `configure` script, etc. – a very advanced
  feature, inherited from `zsh-startify`'s predecessor: `psprint/zaccumulator` plugin),
- will show recently ran `git` commands, with analysis of e.g. recently checked-out
  branches,
- will cooperate with any bookmarking plugins to show their bookmarks.

# Screenshots

![zsh-startify](https://raw.githubusercontent.com/z-shell/zsh-startify/img/zsh-startify.png)

# Installation

## Any plugin manager

Issue the regular loading command of your plugin manager, pointing it to
`z-shell/zsh-startify`. Then, add invocation of `zsh-startify` to the end of
`~/.zshrc`:

```zsh
% tail -n 5 ~/.zshrc                (git)-[master●]
#zmodload -i zsh/sched
#schedprompt

# ADD TO ~/.zshrc
zsh-startify
```

## [Zplugin](https://github.com/z-shell/zplugin)

```zsh
# Option A – normal load without Turbo-Mode
zplugin ice atload'zsh-startify'
zplugin load z-shell/zsh-startify

# Option B – a load with Turbo-Mode being in use
zplugin ice wait'0' lucid atload'zsh-startify'
zplugin load z-shell/zsh-startify
```

The first option (A) loads the plugin synchronously, at the time of execution of the
`zplugin load ...` command. The second option (B) loads in an asynchronous manner, 0
seconds after the prompt being first displayed.

# Quick Start

`zsh-startify` accumulates data in its own history file. To pre-fill it quickly with a
few of entries (basing on the regular history) you can run the
`__from-zhistory-accumulate` command.

## Zstyles

The zstyles used to configure the plugin (add such commands anywhere in the `zshrc`):

```zsh
zstyle ":plugin:zsh-startify:shellutils" size 5  # The size of the recently used file list (default: 5)
zstyle ":plugin:zsh-startify:vim" size 5         # The size of the recently opened in Vim list (default: 5)
```

<!-- vim:tw=87-->
