set nocompatible

call pathogen#infect()

syntax on
set number

" Use UTF-8 without BOM.
set encoding=utf-8 nobomb

set incsearch   " Find the next match as we type the search.
set hlsearch    " Hilight searches by default.
set ignorecase  " Ignore case when searching.
set smartcase   " ... unless query contains at least one capital letter.
set gdefault    " Add the g flag to search/replace by default.

set nowrap      " Dont wrap lines.
set linebreak   " Wrap lines at convenient points.

" Enable command line tab completion.
set wildmenu

set scrolloff=4 " Start scrolling three lines before the horizontal border.

" Swapfiles are more annoying than helpful.
set noswapfile
set nobackup
set nowb

" Allow backspacing over everything in insert mode.
set backspace=indent,eol,start

" %% expands to the path of the current file.
cabbr <expr> %% expand('%:p:h')

" From https://github.com/spf13/spf13-vim/blob/master/.vimrc.
if has('statusline')
  set laststatus=2

  set statusline=%<%f\ 
  set statusline+=%w%h%m%r
  set statusline+=\ [%{&ff}/%Y]\ 
  set statusline+=%#warningmsg#
  set statusline+=%{SyntasticStatuslineFlag()}
  set statusline+=%*

  let g:syntastic_enable_signs=1

  set statusline+=%=%-14.(%l,%c%V%)\ %p%%
endif

if has("autocmd")
  " Enable per filetype indentation.
  filetype plugin indent on

  " Cases in a switch should be indented.
  let PHP_vintage_case_default_indent=1

  " Drupal PHP files.
  augroup module
    autocmd BufRead,BufNewFile *.module set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.install set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.test set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.inc set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.profile set filetype=php shiftwidth=2 softtabstop=2
  augroup END
endif

" Mark current line.
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline
autocmd BufWinEnter * setlocal cursorline
autocmd BufWinLeave * setlocal cursorline
hi CursorLine cterm=NONE ctermbg=darkgrey guibg=darkgrey

" Highlight trailing whitespace
" http://stackoverflow.com/questions/356126/how-can-you-automatically-remove-trailing-whitespace-in-vim/7255709#7255709
highlight ExtraWhitespace ctermbg=yellow guibg=yellow
au ColorScheme * highlight ExtraWhitespace guibg=yellow
au BufEnter * match ExtraWhitespace /\s\+$/
au InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
au InsertLeave * match ExtraWhiteSpace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" Lists for highlighting invisible characters.
set lcs=tab:▸\ ,trail:·,nbsp:_,precedes:«,extends:»
set list

" Split windows more easily.
nnoremap <silent> vv <C-w>v
nnoremap <silent> ss <C-w>s

" Remap Q to close a window.
nnoremap <silent> Q <C-w>c

" Make :W act as :w.
nnoremap W :w<CR>

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<CR>

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<CR>

" Load local .vimrcl, if any.
if filereadable($HOME.'/.vimrcl')
  source $HOME/.vimrcl
endif
