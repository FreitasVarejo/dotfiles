" Spell setup script
" Run this inside Neovim after cloning dotfiles to generate .spl files
"
" Usage:
"   :so ~/dotfiles/nvim/spell/setup.vim

" Create spell directory if it doesn't exist
let s:spell_dir = stdpath('config') . '/spell'
if !isdirectory(s:spell_dir)
  call mkdir(s:spell_dir, 'p')
endif

" Generate English spell file if .add exists
let s:en_add = s:spell_dir . '/en.utf-8.add'
if filereadable(s:en_add)
  execute 'mkspell! ' . s:spell_dir . '/en.utf-8.spl ' . s:en_add
  echo 'English spell file generated'
else
  echo 'Note: Create ' . s:en_add . ' with :zg or download dictionary first'
endif

" Generate Portuguese spell file if .add exists
let s:pt_add = s:spell_dir . '/pt_BR.utf-8.add'
if filereadable(s:pt_add)
  execute 'mkspell! ' . s:spell_dir . '/pt_BR.utf-8.spl ' . s:pt_add
  echo 'Portuguese spell file generated'
else
  echo 'Note: Create ' . s:pt_add . ' with :zg or download dictionary first'
endif

echo 'Spell setup complete!'
echo 'Add custom words with :zg and regenerate with :mkspell!'