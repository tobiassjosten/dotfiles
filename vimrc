set nocompatible

call pathogen#infect()

syntax on
set number

" Use UTF-8 without BOM.
set encoding=utf-8 nobomb

" We support 256 colors.
set t_Co=256

" When in tmux our terminal will be reported as 'screen' or 'screen-256color',
" which will fool Vim into not accepting Ctrl+arrow keys. Let's rectify this
" by binding those codes to the proper keys.
if &term =~ '^screen'
    execute "set <xUp>=\e[1;*A"
    execute "set <xDown>=\e[1;*B"
    execute "set <xRight>=\e[1;*C"
    execute "set <xLeft>=\e[1;*D"
endif

set incsearch   " Find the next match as we type the search.
set hlsearch    " Hilight searches by default.
set ignorecase  " Ignore case when searching.
set smartcase   " ... unless query contains at least one capital letter.
set gdefault    " Add the g flag to search/replace by default.

" Use , as leader key.
let mapleader = ","

" Center search matches when jumping.
map N Nzz
map n nzz

" Jump to the beginning of lines.
map <c-f> <c-f>0
map <c-b> <c-b>0
map H H0
map M M0
map L L0

" Scroll viewport faster.
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

set nowrap      " Dont wrap lines.
set linebreak   " Wrap lines at convenient points.

" Enable command line tab completion.
set wildmenu
" Only complete up to the point of ambiguity.
set wildmode=list:longest

" Don't close buffers, just hide them to preserve history.
set hidden

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

  augroup module
    " Markdown.
    autocmd BufRead,BufNewFile *.md set filetype=markdown wrap linebreak
    autocmd BufRead,BufNewFile *.markdown set wrap linebreak
    " Drupal PHP files.
    autocmd BufRead,BufNewFile *.module set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.install set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.test set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.inc set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.profile set filetype=php shiftwidth=2 softtabstop=2
  augroup END
endif

" Powerline settings
let g:Powerline_symbols = 'fancy'

" Mark current line.
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline
autocmd BufWinEnter * setlocal cursorline
autocmd BufWinLeave * setlocal cursorline
hi CursorLine cterm=NONE ctermbg=234 guibg=234

" Highlight trailing whitespace
" http://stackoverflow.com/questions/356126/how-can-you-automatically-remove-trailing-whitespace-in-vim/7255709#7255709
highlight ExtraWhitespace ctermbg=yellow guibg=yellow
au ColorScheme * highlight ExtraWhitespace guibg=yellow
au BufEnter * match ExtraWhitespace /\s\+$/
au InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
au InsertLeave * match ExtraWhiteSpace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" A NERDTree toggle combined with the NERDTreeFind command.
function! NERDTreeFindToggle()
  if exists("t:NERDTreeBufName")
    let s:ntree = bufwinnr(t:NERDTreeBufName)
  else
    let s:ntree = -1
  endif
  if (s:ntree != -1)
    :NERDTreeClose
  else
    :NERDTreeFind
  endif
endfunction

" Automatically close NERDTree if it's the last open window.
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

" Toggle NERDTree with Ctrl+d.
map <silent> <c-d> :call NERDTreeFindToggle()<cr>

" NERDTree configuration.
let g:NERDTreeQuitOnOpen = 1

" Open taglist with Ctrl+j.
map <silent> <c-j> :TlistToggle<cr>

" Taglist configuration.
let g:Tlist_GainFocus_On_ToggleOpen = 1
let g:Tlist_Use_Right_Window = 1
let g:Tlist_WinWidth = 40
let g:Tlist_Exit_OnlyWindow = 1
let g:Tlist_File_Fold_Auto_Close = 1
let g:Tlist_Close_On_Select = 1

" Lists for highlighting invisible characters.
set lcs=tab:▸\ ,trail:·,nbsp:_,precedes:«,extends:»
set list

" Delete without yanking.
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" Replace currently selected text with default register without yanking it.
nnoremap <leader>p "_ddP
vnoremap <leader>p "_dP

" Split windows more easily.
nnoremap <silent> vv <C-w>v
nnoremap <silent> ss <C-w>s

" Jump to first entry in location list.
nnoremap <leader>ll :llist<cr>:silent ll<space><cr><cr>

" Remap Q to close a window.
nnoremap <silent> Q <C-w>c

" Make :W and :Q aliases of :w and :q.
command! W w
command! Q q
command! Wq wq
command! WQ wq

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<CR>

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<CR>

" Copy to clipboard with xclip.
vmap <c-c> y: call system("xclip -i -selection clipboard", getreg("\""))<cr>

" Toggle pasting.
map <leader>pp :setlocal paste!<cr>

let g:debuggerMaxDepth = 10

" Load local .vimrcl, if any.
if filereadable($HOME.'/.vimrcl')
  source $HOME/.vimrcl
endif

" Load project .vimrc, if any.
if filereadable('.vimrc') && getcwd() != $HOME
  source .vimrc
endif

map <leader>, :DbgToggleBreakpoint<CR>
map <f2> :DbgRun<CR>
map <f3> :DbgStepOver<CR>
map <f4> :DbgStepInto<CR>
map <c-f4> :DbgStepOut<CR>
map <c-f4> :DbgDetach<CR>
