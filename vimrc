" Layout based on:
" http://dougireton.com/blog/2013/02/23/layout-your-vimrc-like-a-boss/

" ----------------------------------------------------------------------------
"  bundling
" ----------------------------------------------------------------------------

set nocompatible

let mapleader = ' '

filetype off

silent! packadd minpac
if exists('*minpac#init')
  call minpac#init()
  call minpac#add('k-takata/minpac', {'type': 'opt'})

  " Airline — Lean & mean status/tabline.
  call minpac#add('bling/vim-airline')

  " Ballerina – Ballerina plugin for Vim.
  call minpac#add('ballerina-attic/plugin-vim')

  " Commentary — Comment stuff out.
  vmap \ gcgv
  nmap \ gcc
  call minpac#add('tpope/vim-commentary')

  " CtrlP — Fuzzy file, buffer, mru, tag, etc finder.
  let g:ctrlp_clear_cache_on_exit = 0
  let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|^.git$\|_site'
  nmap <c-l> :CtrlPBuffer<cr>
  nmap <c-ö> :CtrlPTag<cr>
  call minpac#add('kien/ctrlp.vim')

  " CSS – Preview colours in source code while editing.
  call minpac#add('ap/vim-css-color')

  " CtrlP Matcher — C matching extension.
  call minpac#add('JazzCore/ctrlp-cmatcher')

  " EditorConfig — Consistent coding styles.
  call minpac#add('editorconfig/editorconfig-vim')

  " Fugitive — A Git wrapper so awesome, it should be illegal.
  call minpac#add('tpope/vim-fugitive')

  " Gitgutter — Shows a git diff in the gutter (sign column).
  call minpac#add('airblade/vim-gitgutter')

  " Go — Go (golang) support.
  call minpac#add('fatih/vim-go')
  let g:go_fmt_command = 'goimports'
  command! -bar GoSetup GoInstallBinaries

  " Groovy — Syntax for the Groovy programming language.
  call minpac#add('vim-scripts/groovy.vim')

  " Gruvbox – Retro groove color scheme.
  call minpac#add('morhetz/gruvbox')
  let g:gruvbox_contrast_dark = 'hard'

  " Gutentags
  call minpac#add('ludovicchabant/vim-gutentags')

  " Incsearch — Improved incremental searching.
  call minpac#add('haya14busa/incsearch.vim')
  let g:incsearch#auto_nohlsearch = 1
  let g:incsearch#consistent_n_direction = 1

  " Liquid
  call minpac#add('tpope/vim-liquid')

  " Matchindent — Set the indent style to what is in the file being edited.
  call minpac#add('conormcd/matchindent.vim')

  " NERDTree — A tree explorer plugin for Vim.
  let g:NERDTreeQuitOnOpen = 1
  let g:NERDTreeShowHidden = 1
  let g:NERDTreeWinSize = 50
  map <silent> <c-d> :call NERDTreeFindToggle()<cr>
  function! NERDTreeFindToggle()
    if exists("t:NERDTreeBufName") | let s:ntree = bufwinnr(t:NERDTreeBufName) | else | let s:ntree = -1 | endif
    if (s:ntree != -1) | :NERDTreeClose | else | :NERDTreeFind | endif
  endfunction
  autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
  autocmd vimenter * if !argc() && exists("NERDTree") | NERDTree | endif
  call minpac#add('scrooloose/nerdtree')

  " NERDTree Git – A plugin of NERDTree showing git status flags.
  call minpac#add('Xuyuanp/nerdtree-git-plugin')

  " Repeat — Enable repeating supported plugin maps with dot.
  call minpac#add('tpope/vim-repeat')

  " Supertab — Perform all your vim insert mode completions with Tab.
  call minpac#add('ervandew/supertab')

  " Syntastic — Syntax checking hacks for Vim.
  call minpac#add('scrooloose/syntastic')

  " Tagbar — The Vim class outline viewer.
  let g:tagbar_autoclose = 1
  let g:tagbar_autofocus = 1
  let g:tagbar_iconchars = ['+', '-']
  let g:tagbar_autoshowtag = 1
  map <c-m> :TagbarToggle<cr>
  call minpac#add('majutsushi/tagbar')

  " Terraform – Basic vim/terraform integration.
  let g:terraform_align=1
  let g:terraform_fmt_on_save=1
  call minpac#add('hashivim/vim-terraform')

  " Twig — Twig syntax highlighting, snipMate, etc.
  call minpac#add('evidens/vim-twig')

  " UtilSnips — The Ultimate Snippet Solution for Vim.
  call minpac#add('SirVer/ultisnips')
  let g:UltiSnipsSnippetDirectories = ['ultisnips']
  let g:UltiSnipsSnippetsDir = '~/.vim/ultisnips'
  let g:UltiSnipsExpandTrigger='<tab>'
  let g:UltiSnipsJumpForwardTrigger='<tab>'
  let g:UltiSnipsJumpBackwardTrigger='<c-tabk>'
endif


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
highlight SignColumn ctermfg=4 ctermbg=NONE guifg=darkblue guibg=NONE

" Hilight searches by default.
set hlsearch

" Mark current line.
set cursorline
highlight cursorline cterm=NONE ctermbg=234


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
  "augroup General
  "  autocmd!
  "  autocmd BufNewFile,BufRead,BufEnter * colorscheme murphy
  "augroup END

  augroup Git
    autocmd!
    autocmd Filetype gitcommit setlocal spell textwidth=72
  augroup END

  augroup Go
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter *.go set filetype=go
    autocmd FileType go colorscheme gruvbox
  augroup END

  augroup Groovy
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter *.groovy,Jenkinsfile set filetype=groovy
  augroup END

  augroup JavaScript
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter Gruntfile set filetype=javascript
    autocmd FileType javascript color murphy
  augroup END

  augroup Markdown
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter *.md,*.markdown set filetype=markdown
    autocmd FileType markdown set wrap linebreak
  augroup END

  augroup PHP
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter *.module,*.inc set filetype=php
    autocmd FileType php setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab
    autocmd FileType php color desert
    autocmd FileType php highlight cursorline cterm=NONE ctermbg=234
  augroup END

  augroup Ruby
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter Gemfile,Guardfile,Vagrantfile set filetype=ruby
  augroup END

  augroup YAMLFrontMatter
    autocmd!
    autocmd BufNewFile,BufRead,BufEnter * syntax match Comment /\%^---\_.\{-}---$/
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

" Quick save.
nnoremap <leader>w :w<cr>

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

" Incsearch remappings.
map / <Plug>(incsearch-forward)
map ? <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)
map n <Plug>(incsearch-nohl-n)
map N <Plug>(incsearch-nohl-N)
map * <Plug>(incsearch-nohl-*)
map # <Plug>(incsearch-nohl-#)
map g* <Plug>(incsearch-nohl-g*)
map g# <Plug>(incsearch-nohl-g#)


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
