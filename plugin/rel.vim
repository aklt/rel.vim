"===============================================================================
" File:        rel.vim
" Description: Vim plugin to handle links to resources
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     This program is free software. It comes without any warranty.
"===============================================================================
if exists('g:rel_version')
  finish
endif
let g:rel_version = '0.3.0'
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

" TODO simpler URL highlight
let g:rel_highlight = 2

if ! exists('g:rel_schemes')
  let g:rel_schemes = {}
endif

let g:rel_chars_not_ok = ' ,!\t()"<>' . "'"
let g:rel_link_chars = '#$%&*+-./01234567899:=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ\\^_abcdefghijklmnopqrstuvwxyz~'

if g:rel_highlight > 0
  hi! link xREL Underlined
  let s:match = ['\%([^' . g:rel_chars_not_ok . ']*\zs\%(' .
      \ join(extend(keys(g:rel_schemes), ['man', 'help', 'http', 'https', 'ftp', 'ftps']), '\|') .
      \ '\):[^' . g:rel_chars_not_ok . ']\+\)',
      \ '\%([^' . g:rel_chars_not_ok . ']*\.\%(' . join(keys(g:rel_extmap), '\|') . '\)\)',
      \ '[^' . g:rel_chars_not_ok . ']\+#\?[^' . g:rel_chars_not_ok . ']*',
      \ '\%(http\|ftp\)s\?:\/\/\S\+',
      \ '\%(^\|[' . g:rel_chars_not_ok . ']\)\zs\%(\.\.\|\.\|\~\|\w\+\)\?\/\/\@!\f[^' .
      \ g:rel_chars_not_ok . ']*'
      \ ]

  let g:rel_syn_match = '\%(' . join(s:match[:g:rel_highlight - 1], '\|') . '\)'
  unlet s:match
  augroup REL
    au!
    au BufWinEnter * call matchadd('xREL', g:rel_syn_match, 1000)
  augroup END
endif

if ! hasmapto('<Plug>(Rel)')
  nmap <unique> <C-k> <Plug>(Rel)
  nmap <C-LeftMouse> <Plug>(Rel)
endif

nnoremap <Plug>(Rel) :call rel#Rel()<CR>
command! -nargs=* -complete=tag Rel call rel#Rel(<f-args>)

let &cpoptions= s:keepcpo
unlet s:keepcpo
