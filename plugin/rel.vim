"============================================================================
" File:        rel.vim
" Description: Vim plugin to handle links to ressources
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     This program is free software. It comes without any warranty,
"============================================================================
" TODO define paths/protocols in a dictionary, ie. wiki:Notes
" TODO make it possible to pass data to external progs
if exists('g:rel_version')
    finish
endif
let g:rel_version = '0.1.1'
let s:keepcpo = &cpo
set cpo&vim

if ! exists('g:rel_open')
  let g:rel_open = 'tabnew'
endif

if ! exists('g:rel_http')
  let g:rel_http = 'lynx'
endif

if ! exists('g:rel_extmap')
  let g:rel_extmap = {'jpg': 'gimp %s'}
endif

fun! s:NormalizePath(path)
  let res = substitute(a:path, '^\~', $HOME, "e")
  let res = substitute(res, '%20', ' ', 'g')
  return res
endfun

fun! s:RunJob(cmd, arg)
  let job = substitute(a:cmd, '%s', a:arg, 'g')
  if ! has('job')
    return system(job)
  endif
  call job_start(job, {
        \ "err_io": "null",
        \ "in_io": "null",
        \ "out_io": "null"
        \ })
endfun

fun! s:GetRelPartsAndOpenFileOrMan(a)
  let len = len(a:a[1])
  if len > 0
    let idx = stridx(a:a[1], '#')
    let hash = ''
    if idx >= 0
      let hash = strcharpart(a:a[1], idx + 1)
    else
      let idx = len
    endif
    let path = strcharpart(a:a[1], 0, idx)
    return s:OpenFileOrManAndGoto(s:NormalizePath(path), hash)
  endif
  return a:a[1]
endfun

let s:esc = '\\/*{}[].-'

fun! s:OpenFileOrManAndGoto(filename, goto)
  if a:filename =~ '^man:'
    if ! exists(":Man")
      echoerr 'please enable :Man command with "runtime ftplugin/man.vim"'
      return
    endif
    let page = strcharpart(a:filename, 4)
    exe ':Man ' . page
  elseif a:filename =~ '^vim:'
    let page = strcharpart(a:filename, 4)
    exe ':help ' . page
  else
    exe g:rel_open . ' ' . a:filename
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

fun! s:OpenHttp(a)
  call s:RunJob('chromium --force-device-scale-factor=1 %s', a:a[1])
  return 1
endfun

fun! s:OpenFileExt(a)
  let rel = a:a[1]
  let ext = tolower(a:a[2])
  if len(ext) == 0 || ! has_key(g:rel_extmap, ext)
    return a:a[1]
  endif
  let job = g:rel_extmap[ext]
  return s:RunJob(job, s:NormalizePath(a:a[1]))
endfun

let s:rel_handlers = [
      \ [ '^\(https\?:\/\/\S\+\)', funcref('s:OpenHttp') ],
      \ [ '^\(\S\+\.\(\w\+\)\)$', funcref('s:OpenFileExt') ],
      \ [ '^\%(file:\/\/\)\?\(\S\+\)\%(#\(\/\w\+\|:\d\+\)\)\?',
      \   funcref('s:GetRelPartsAndOpenFileOrMan')]
      \ ]

fun! s:TokenAtCursor(line, pos)
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
  let token = s:TokenAtCursor(line, pos[2])
  for hdl in s:rel_handlers
    let token2 = substitute(token, hdl[0], hdl[1], 'ie')
    if token2 != token
      return
    endif
  endfor
endfun

if ! hasmapto('<Plug>(Rel)')
  nmap <unique> <C-k> <Plug>(Rel)
endif

nnoremap <Plug>(Rel) :call <SID>Rel()<CR>

let &cpo= s:keepcpo
unlet s:keepcpo
