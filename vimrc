set nocompatible

set number

set incsearch   " Find the next match as we type the search.
set hlsearch    " Hilight searches by default.
set ignorecase  " Ignore case when searching.

set nowrap      " Dont wrap lines.
set linebreak   " Wrap lines at convenient points.

" Swapfiles are more annoying than helpful.
set noswapfile
set nobackup
set nowb

" Enable per filetype indentation.
if has("autocmd")
  filetype plugin indent on
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
