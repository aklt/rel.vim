" Rel
"
" Author: Anders Thøgersen
"
" Route your text linking.  This is sort of a revamp of UTL.vim
"
" Better mnemonics:
"
"   : line number
"   / token match  space is %20 in this
"
" TODO define paths/protocols in a dictionary, ie. wiki:Notes
" TODO make it possible to pass data to external progs, ie. gnuplot
" TODO define a function to mark locations to a different buffer, so we can
"      explore and mark on our way around some files
"
" if exists('g:rel_version')
"     finish
" endif
let g:rel_version = '0.0.1'
if v:version < 800
  echomsg 'rel.vim: need vim version 8'
  finish
endif
let s:keepcpo = &cpo
set cpo&vim

fun! ReplaceTilde(path)
  let res = substitute(a:path, '^\~', $HOME, "e")
  return res
endfun

fun! RunJob(cmd, arg)
  call job_start(a:cmd . ' ' . a:arg, {
        \ "err_io": "null",
        \ "in_io": "null",
        \ "out_io": "null"
        \ })
endfun

" Jump to a file with vim at a line number or matching text
"
" file://foo#/bar
" foo#/bar
" foo#:12

" https://i.imgur.com/TLTwmJo.gifv
" ~/freshen.vym
" /usr/share/icons/hicolor/22x22/mimetypes/application-x-vnd.kde.kplato.work.png
" man:at#//var/spool/atd
" http://dr.dk
fun! OpenFileOrManAndGotoX(a)
  if len(a:a[1]) > 0
    let idx = stridx(a:a[1], '#')
    let path = strcharpart(a:a[1], 0, idx)
    let hash = strcharpart(a:a[1], idx + 1)
    return OpenFileOrManAndGoto(ReplaceTilde(path), hash)
  endif
endfun

let s:esc = '\\/*{}[].-'

fun! OpenFileOrManAndGoto(filename, goto)
  if a:filename =~ '^man:'
    if ! exists(":Man")
      echoerr 'please enable :Man command with "runtime ftplugin/man.vim"'
      return
    endif
    let page = strcharpart(a:filename, 4)
    let page = substitute(page, '%20', ' ', 'g')
    exe ':Man ' . page
  else
    exe 'tabnew ' . a:filename
  endif
  if a:goto[0] == ':'
    return cursor(str2nr(strcharpart(a:goto, 1)), 0)
  endif
  let needle = strcharpart(a:goto, 1)
  if a:goto[0] != '/'
    let needle = a:goto
  endif
  let needle = substitute(needle, '%20', ' ', 'g')
  exe ':call search("' . escape(needle, s:esc) . '")'
  return 'foo'
endfun

fun! OpenHttp(a)
  call RunJob('chromium --force-device-scale-factor=1', a:a[1])
  return 1
endfun

fun! OpenFileExt(a)
  call RunJob('vym', ReplaceTilde(a:a[1]))
  return 1
endfun

let g:rel_handlers = [
      \ [ '^\(https\?:\/\/\S\+\)', funcref('OpenHttp') ],
      \ [ '^\(\S\+\.\w\{1,4}\)$', funcref('OpenFileExt') ],
      \ [ '^\%(file:\/\/\)\?\(\S\+\)\%(#\(\/\w\+\|:\d\+\)\)\?',  funcref('OpenFileOrManAndGotoX')]
      \ ]

fun! TokenAtCursor(line, pos)
  if strcharpart(a:line, a:pos, 1) =~ '\s'
    echomsg 'no token under cursor'
    return ''
  endif
  let len = strchars(a:line)
  let i = a:pos
  let j = a:pos
  let lasti = i
  let lastj = j

  while i > -1
    if strcharpart(a:line, i, 1) =~ '\s'
      let lasti = i + 1
      let i = -1
    endif
    let i = i - 1
  endwhile

  if i == -1 " lasti was not assigned
    let lasti = 0
  endif

  while j < len
    if strcharpart(a:line, j, 1) =~ '\s'
      let lastj = j - 1
      let j = len
    endif
    let j = j + 1
  endwhile

  if j == len  " lastj was not assigned
    let lastj = len -1
  endif

  let res = strcharpart(a:line, lasti, lastj - lasti + 1)
  return res
endfun

fun! s:Rel()
  let pos = getcurpos()
  let line = getline('.')
  let token = TokenAtCursor(line, pos[2])
  for hdl in g:rel_handlers
    let token2 = substitute(token, hdl[0], hdl[1], 'ie')
    if token2 != token
      return
    endif
  endfor
endfun

nmap <C-u> :call <SID>Rel()<CR>

let &cpo= s:keepcpo
unlet s:keepcpo
