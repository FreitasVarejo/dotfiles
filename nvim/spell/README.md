# Spell Check Configuration

This directory contains spell check dictionaries for Neovim.

## Generating Spell Files

The `.spl` files are binary and must be generated using Neovim's `:mkspell` command.

### English (en)

```vim
:mkspell! spell/en.utf-8.spl ~/.config/nvim/spell/en.utf-8.add
```

Or download a pre-built dictionary and convert:

```bash
# Download OpenOffice spell dictionary
wget https://github.com/LibreOffice/dictionaries/archive/refs/heads/main.zip
unzip main.zip dictionaries-main/en/en_US.zip
# Extract the .aff and .dic files
mv en_US.aff en_US.utf-8.aff
mv en_US.dic en_US.utf-8.dic
# Generate .spl in Neovim:
# :mkspell! spell/en.utf-8.spl spell/en.utf-8.aff spell/en.utf-8.dic
```

### Portuguese (pt)

```vim
:mkspell! spell/pt.utf-8.spl ~/.config/nvim/spell/pt.utf-8.add
```

Or using Hunspell dictionaries:

```bash
# Download Portuguese dictionary
wget https://github.com/LibreOffice/dictionaries/archive/refs/heads/main.zip
unzip main.zip dictionaries-main/pt_BR/pt_BR.zip
mv pt_BR.aff pt_BR.utf-8.aff
mv pt_BR.dic pt_BR.utf-8.dic
```

## Quick Setup Script

Run this inside Neovim after installing dictionaries:

```vim
:so ~/dotfiles/nvim/spell/setup.vim
```

Or run this shell command to trigger the generation:

```bash
nvim --headless \
  -c "set spelllang=en_us,pt_br" \
  -c "mkspell! ~/.config/nvim/spell/en.utf-8.spl ~/.config/nvim/spell/en.utf-8.add" \
  -c "mkspell! ~/.config/nvim/spell/pt_BR.utf-8.spl ~/.config/nvim/spell/pt_BR.utf-8.add" \
  -c "qa"
```

## Adding Words

Add personal words to the .add files:

```vim
:spelldump  " View current dictionary
zg         " Add word under cursor to good list
zw         " Add word under cursor to wrong list
zug        " Undo addition
```

## Required Files

Once generated, you should have:
- `en.utf-8.spl` - English spell dictionary
- `pt_BR.utf-8.spl` - Portuguese (Brazil) spell dictionary