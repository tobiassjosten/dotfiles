" Layout based on:
" http://dougireton.com/blog/2013/02/23/layout-your-vimrc-like-a-boss/

" ----------------------------------------------------------------------------
"  bundling
" ----------------------------------------------------------------------------

set nocompatible

let mapleader = ','

set rtp+=~/.vim/bundle/vundle/

filetype off

call vundle#rc()

Bundle 'gmarik/vundle'

" Closetag — Functions and mappings to close open HTML/XML tags.
Bundle 'closetag.vim'

" Commentary — Comment stuff out.
xmap " gcgv
Bundle 'tpope/vim-commentary'

" CtrlP — Fuzzy file, buffer, mru, tag, etc finder.
let g:ctrlp_clear_cache_on_exit = 0
nmap <c-l> :CtrlPBuffer<cr>
nmap <c-ö> :CtrlPTag<cr>
Bundle 'kien/ctrlp.vim'

" DBGPavim — Enable PHP debug in Vim with Xdebug, with a new debug engine.
let g:dbgPavimPort = 9000
let g:dbgPavimBreakAtEntry = 1
map <leader>, :Bp<cr>
Bundle 'brookhong/DBGPavim'

" Gitgutter — Shows a git diff in the gutter (sign column).
Bundle 'airblade/vim-gitgutter'

" HAML — Runtime files for Haml, Sass, and SCSS.
Bundle 'tpope/vim-haml'

" HTML5 — HTML5 omnicomplete and syntax.
Bundle 'othree/html5.vim'

" Matchindent — Set the indent style to what is in the file being edited.
Bundle 'conormcd/matchindent.vim'

" Multiple cursors — Live update in Insert mode.
Bundle 'terryma/vim-multiple-cursors'

" NERDTree — A tree explorer plugin for Vim.
let g:NERDTreeQuitOnOpen = 1
map <silent> <c-d> :call NERDTreeFindToggle()<cr>
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
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
autocmd vimenter * if !argc() | NERDTree | endif
Bundle 'scrooloose/nerdtree'

" PHP — Syntax file with 5.3 & basic 5.4 support.
Bundle 'StanAngeloff/php.vim'

" Puppet — Puppet niceties for your Vim setup.
Bundle 'rodjek/vim-puppet'

" Repeat — Enable repeating supported plugin maps with dot.
Bundle 'tpope/vim-repeat'

" Supertab — Perform all your vim insert mode completions with Tab.
Bundle 'ervandew/supertab'

" Surround — Quoting/parenthesizing made simple.
Bundle 'tpope/vim-surround'

" Syntastic — Syntax checking hacks for Vim.
Bundle 'scrooloose/syntastic'

" Tabular — Text filtering and alignment.
Bundle 'godlygeek/tabular'

" Tagbar — The Vim class outline viewer.
let g:tagbar_autoclose = 1
let g:tagbar_autofocus = 1
let g:tagbar_iconchars = ['+', '-']
let g:tagbar_autoshowtag = 1
map <c-j> :TagbarToggle<cr>
Bundle 'majutsushi/tagbar'

" Twig — Twig syntax highlighting, snipMate, etc.
Bundle 'evidens/vim-twig'

" UtilSnips — The Ultimate Snippet Solution for Vim.
Bundle 'SirVer/ultisnips'
let g:UltiSnipsSnippetDirectories = ['ultisnips']
let g:UltiSnipsSnippetsDir = '~/.vim/ultisnips'
let g:UltiSnipsExpandTrigger='<tab>'
let g:UltiSnipsJumpForwardTrigger='<c-l>'
let g:UltiSnipsJumpBackwardTrigger='<c-k>'


" ----------------------------------------------------------------------------
"  moving around, searching and patterns
" ----------------------------------------------------------------------------

" Find the next match as we type the search.
set incsearch

" Ignore case when searching.
set ignorecase

" ... unless query contains at least one capital letter.
set smartcase


" ----------------------------------------------------------------------------
"  tags
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  displaying text
" ----------------------------------------------------------------------------

" Start scrolling four lines before the horizontal border.
set scrolloff=4

" Wrap long lines.
set wrap

" Wrap long lines at a character in 'breakat'.
set linebreak

" String to put before wrapped screen lines.
set showbreak=↪\ 

" Minimal number of columns to keep left and right of the cursor.
set sidescrolloff=2

" Display otherwise invisible characters like tabs, trailing spaces, etc.
set list

" Lists for highlighting invisible characters.
set listchars=tab:▸\ ,trail:·,nbsp:_,precedes:«,extends:»

" Show the line number for each line.
set number


" ----------------------------------------------------------------------------
"  syntax, highlighting and spelling
" ----------------------------------------------------------------------------

" Turn on Filetype detection, plugins, and indent.
if has('autocmd')
  filetype plugin indent on
endif

" Turn on syntax highlighting.
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Keep transperancy background for gutter in gnome-terminal.
highlight SignColumn ctermfg=4 ctermbg=none guifg=darkblue guibg=none

" Hilight searches by default.
set hlsearch

" Mark current line.
set cursorline
hi cursorline cterm=none ctermbg=234 guibg=234


" ----------------------------------------------------------------------------
"  multiple windows
" ----------------------------------------------------------------------------

" Show a status line, even if there's only one window.
set laststatus=2

" Don't unload a buffer when no longer shown in a window.
set hidden


" ----------------------------------------------------------------------------
"  multiple tab pages
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  terminal
" ----------------------------------------------------------------------------

" We support 256 colors.
set t_Co=256

" Send more characters to rendering, for a smoother experience.
set ttyfast


" ----------------------------------------------------------------------------
"  using the mouse
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  printing
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  messages and info
" ----------------------------------------------------------------------------

" Show (partial) command keys in the status line.
set showcmd

" Display the current mode in the status line.
set showmode

" Show curser position below each window.
set ruler

" Don't ring the bell for error messages.
set noerrorbells


" ----------------------------------------------------------------------------
"  selecting text
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  editing text
" ----------------------------------------------------------------------------

" Allow backspacing over everything in insert mode.
set backspace=indent,eol,start

" Delete comment char on second line when joining two commented lines.
if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j
endif

" Better omni-complete menu.
set completeopt=menu,preview

" Use one space after '.' when joining a line.
set nojoinspaces


" ----------------------------------------------------------------------------
"  tabs and indenting
" ----------------------------------------------------------------------------

" <tab> in front of line inserts 'shiftwidth' blanks.
set smarttab

" Round to 'shiftwidth' for "<<" and ">>".
set shiftround

" Automatically set the indent of a new line.
set autoindent


" ----------------------------------------------------------------------------
"  folding
" ----------------------------------------------------------------------------

" When opening files, all folds open by default.
if has('folding')
  set nofoldenable
endif


" ----------------------------------------------------------------------------
"  diff mode
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  mapping
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  reading and writing files
" ----------------------------------------------------------------------------

" Automatically read a file when it was modified outside of Vim.
set autoread


" ----------------------------------------------------------------------------
"  the swap file
" ----------------------------------------------------------------------------

" Do not use swapfiles.
set noswapfile


" ----------------------------------------------------------------------------
"  command line editing
" ----------------------------------------------------------------------------

" Save more commands in history.
set history=200

" List all matches and complete till the longest common string.
set wildmode=list:longest,full

" File tab completion ignores these file patterns
set wildignore+=*.exe,*.swp,.DS_Store

" Add guard around 'wildignorecase' to prevent terminal vim error.
if exists('&wildignorecase')
  " Ignore case when completing file names.
  set wildignorecase
endif

" Enable command line tab completion.
set wildmenu


" ----------------------------------------------------------------------------
"  executing external commands
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  running make and jumping to errors
" ----------------------------------------------------------------------------


" ----------------------------------------------------------------------------
"  language specific
" ----------------------------------------------------------------------------

if has("autocmd")
  augroup module
    " Markdown.
    autocmd BufRead,BufNewFile *.md,*.markdown set filetype=markdown wrap linebreak
    autocmd BufRead,BufNewFile *.md,*.markdown set wrap linebreak

    " Drupal PHP files.
    autocmd BufRead,BufNewFile *.module set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.install set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.test set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.inc set filetype=php shiftwidth=2 softtabstop=2
    autocmd BufRead,BufNewFile *.profile set filetype=php shiftwidth=2 softtabstop=2

    " Jekyll YAML Front Matter.
    autocmd BufRead,BufNewFile * syntax match Comment /\%^---\_.\{-}---$/

    " JavaScript files.
    autocmd BufRead,BufNewFile Gruntfile set filetype=javascript

    " Ruby files.
    autocmd BufRead,BufNewFile Gemfile,Guardfile set filetype=ruby
  augroup END
endif


" ----------------------------------------------------------------------------
"  multi-byte characters
" ----------------------------------------------------------------------------

set encoding=utf-8 nobomb


" ----------------------------------------------------------------------------
"  various
" ----------------------------------------------------------------------------

" Load local .vimrc/.exrc/.gvimrc files.
set exrc

" Safer working with script files in the current directory.
set secure

" Use the /g flag by default for :substitute.
set gdefault


" ----------------------------------------------------------------------------
"  mappings and aliases
" ----------------------------------------------------------------------------

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
nnoremap <c-e> 3<C-e>
nnoremap <c-y> 3<C-y>

" Delete without yanking.
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" Replace currently selected text with default register without yanking it.
nnoremap <leader>p "_ddP
vnoremap <leader>p "_dP

" Split windows more easily.
nnoremap <silent> vv <c-w>v
nnoremap <silent> ss <c-w>s

" Window navigation.
map <c-j> <c-w>j
map <c-k> <c-w>k
map <c-h> <c-w>h
map <c-l> <c-w>l

" Jump to first entry in location list.
nnoremap <leader>ll :llist<cr>:silent ll<space><cr><cr>

" Remap Q to close a window.
nnoremap <silent> Q <c-w>c

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<cr>

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<cr>

" Copy to clipboard with xclip.
vmap <c-c> y: call system("xclip -i -selection clipboard", getreg("\""))<cr>

" Toggle pasting.
map <leader>pp :setlocal paste!<cr>

" Make :W and :Q aliases of :w and :q.
command! W w
command! Q q
command! Wq wq
command! WQ wq

" Reselect visual block after indent/outdent.
vnoremap < <gv
vnoremap > >gv
vnoremap = =gv


" ----------------------------------------------------------------------------
"  miscellaneous
" ----------------------------------------------------------------------------

" When in tmux our terminal will be reported as 'screen' or 'screen-256color',
" which will fool Vim into not accepting Ctrl+arrow keys. Let's rectify this
" by binding those codes to the proper keys.
if &term =~ '^screen'
    execute "set <xUp>=\e[1;*A"
    execute "set <xDown>=\e[1;*B"
    execute "set <xRight>=\e[1;*C"
    execute "set <xLeft>=\e[1;*D"
endif

" %% expands to the path of the current file.
cabbr <expr> %% expand('%:p:h')

" Load local .vimrcl, if any.
if filereadable($HOME.'/.vimrcl')
  source $HOME/.vimrcl
endif
