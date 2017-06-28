"===============================================================================
" File:        rel.vim
" Description: Vim plugin to handle links to resources
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     This program is free software. It comes without any warranty.
"===============================================================================
if exists('g:rel_version')
  finish
endif
let g:rel_version = '0.2.2'
let s:keepcpo = &cpoptions
set cpoptions&vim

scriptencoding utf-8

let s:default_extmap = {
      \ 'html': 'firefox %s',
      \ 'jpg': 'chromium %s',
      \ 'png': 'geeqie %s',
      \ 'gif': 'imv %s',
      \ 'avi': 'vlc %s',
      \ 'mpg': 'vlc %s',
      \ 'mpeg': 'vlc %s',
      \ 'mp4': 'vlc %s',
      \ 'mp3': 'vlc %s',
      \ 'wav': 'vlc %s',
      \ 'gnumeric': 'gnumeric %s',
      \ }

if exists('g:rel_extmap')
  let g:rel_extmap = extend(s:default_extmap, g:rel_extmap)
else
  let g:rel_extmap = s:default_extmap
endif

if ! exists('g:rel_highlight')
  let g:rel_highlight = 3
endif

if ! exists('g:rel_schemes')
  let g:rel_schemes = {}
endif

let g:rel_chars_not_ok = ' \t()"<>' . "'"
let g:rel_http_chars = '!#$%&*+,-./01234567899:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~'

if g:rel_highlight > 0
  hi link xREL htmlLink
  let s:match = ['\c\%(\%(^\|[' . g:rel_chars_not_ok . ']\)\zs\%(' .
      \ join(add(add(keys(g:rel_schemes), 'man'), 'help'), '\|') .
      \ '\):[^' . g:rel_chars_not_ok . ']\+\)',
      \ '\%([^' . g:rel_chars_not_ok . ']\+\.\%(' . join(keys(g:rel_extmap), '\|') . '\)\)',
      \ '[^' . g:rel_chars_not_ok . ']\+#[\/:][^' . g:rel_chars_not_ok . ']\+',
      \ '\%(http\|ftp\)s\?:\/\/[' . g:rel_http_chars . ']\+',
      \ '\%(^\|[' . g:rel_chars_not_ok . ']\)\zs\%(\.\.\|\.\|\~\|\w\+\)\?\/\/\@!\f[^' .
      \ g:rel_chars_not_ok . ']*'
      \ ]

  let g:rel_syn_match = '\%(' . join(s:match[:g:rel_highlight - 1], '\|') . '\)'
  unlet s:match
  augroup REL
    au!
    au BufWinEnter * call matchadd('xREL', g:rel_syn_match)
  augroup END
endif

if ! hasmapto('<Plug>(Rel)')
  nmap <unique> <C-k> <Plug>(Rel)
  nmap <LeftMouse> <Plug>(Rel)
endif

nnoremap <Plug>(Rel) :call rel#Rel(expand('<cWORD>'))<CR>
command! -nargs=* Rel call rel#Rel(<f-args>)

let &cpoptions= s:keepcpo
unlet s:keepcpo
