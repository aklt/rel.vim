"============================================================================
" File:        rel.vim
" Description: Vim plugin to handle links to resources
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     This program is free software. It comes without any warranty,
"============================================================================
if exists('g:rel_version')
  finish
endif
let g:rel_version = '0.1.1'
let s:keepcpo = &cpo
set cpo&vim

if ! exists('g:rel_open')
  let g:rel_open = 'tabnew'
endif

if ! exists('g:rel_modifiers')
  let g:rel_modifiers = 'vert'
endif

if ! exists('g:rel_http')
  let g:rel_http = 'firefox %s'
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

let s:esc = '\\/*{}[]."-'

fun! s:OpenFileOrManAndGoto(a)
  let filename = s:NormalizePath(a:a[1])
  let goto = a:a[2]
  if len(filename) > 0
    if filename =~ '^man:'
      if ! exists(":Man")
        echoerr 'please enable :Man command with "runtime ftplugin/man.vim"'
        return
      endif
      let page = strcharpart(filename, 4)
      exe ':Man ' . page
    elseif filename =~ '^vim:'
      let page = strcharpart(filename, 4)
      if g:rel_open =~ 'tab'
        exe ':tab help ' . page
      else
        exe g:rel_modifiers . ' help ' . page
      endif
    elseif g:rel_open =~ 'tab'
      exe g:rel_open . ' ' . filename
    else
      exe g:rel_modifiers . ' ' . g:rel_open . ' ' . filename
    endif
    if len(goto) > 0
      if goto[0] == ':'
        let line = substitute(goto, '^:\?\(\d\+\).*$', '\1', 'e')
        let column = substitute(goto, '^:\?\d\+:\(\d\+\).*$', '\1', 'e')
        if len(line) == 0
          let line = 1
        endif
        if len(column) == 0
          let column = 1
        endif
        return cursor(str2nr(line), str2nr(column))
      endif
      let needle = strcharpart(goto, 1)
      if goto[0] != '/'
        let needle = goto
      endif
      let needle = substitute(needle, '%20', ' ', 'g')
      let s = escape(needle, s:esc)
      call cursor(1, 1)
      call search(s)
    endif
    return 1
  endif
  return a:a[0]
endfun

fun! s:OpenHttp(a)
  call s:RunJob(g:rel_http, a:a[1])
  return 1
endfun

fun! s:OpenFileExt(a)
  let rel = a:a[1]
  let ext = tolower(a:a[2])
  if len(ext) == 0 || ! has_key(g:rel_extmap, ext)
    return a:a[0]
  endif
  let job = g:rel_extmap[ext]
  return s:RunJob(job, s:NormalizePath(a:a[1]))
endfun

fun! s:OpenResolvedScheme(a)
  if exists('g:rel_schemes') && has_key(g:rel_schemes, a:a[1])
    let Resolved = g:rel_schemes[a:a[1]]
    if type(Resolved) == type('')
      if len(a:a[2]) > 0
        if stridx(Resolved, '%p') > -1
          let Resolved = substitute(Resolved, '%p', a:a[2], 'eg')
        else
          echoerr 'missing %p path in g:rel_schemes[' . a:a[1] . ']'
          return
        endif
      endif
      if len(a:a[3]) > 0
        if stridx(Resolved, '%f') > -1
          let Resolved = substitute(Resolved, '%f', a:a[3], 'eg')
        else
          let Resolved .= '#' . a:a[3]
        endif
      endif
      return s:RelResolve(Resolved)
    elseif type(Resolved) == type(funcref('s:OpenHttp'))
      let res = call(Resolved, [a:a[0], a:a[2], a:a[3]])
      if type(res) == type(0) && res == 0
        return a:a[0]
      elseif res == 1
        call s:RelResolve(a:a[0])
      elseif len(res) > 0
        call s:RelResolve(res)
      endif
      return 1
    endif
  endif
  return a:a[0]
endfun

let s:rel_handlers = [
      \ [ '^\(\w\+\):\([^#]\+\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \   funcref('s:OpenResolvedScheme')],
      \ [ '^\(https\?:\/\/\S\+\)$', funcref('s:OpenHttp') ],
      \ [ '^\(\S\+\.\(\w\+\)\)$', funcref('s:OpenFileExt') ],
      \ [ '^\%(file:\/\/\)\?\([^#]\+\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \   funcref('s:OpenFileOrManAndGoto')]
      \ ]

fun! s:TokenAtCursor(line, pos)
  if strcharpart(a:line, a:pos, 1) =~ '\s'
    return echomsg 'no token under cursor'
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

  return strcharpart(a:line, lasti, lastj - lasti + 1)
endfun

let s:RelResolveMaxIter = 5

fun! s:RelResolve(token)
  let s:RelResolveMaxIter = s:RelResolveMaxIter - 1
  if s:RelResolveMaxIter < 0
    echomsg 'rel.vim: recursed too deeply while resolving'
    return
  endif
  for hdl in s:rel_handlers
    let token2 = substitute(a:token, hdl[0], hdl[1], 'ie')
    if token2 != a:token
      return
    endif
  endfor
endfun

fun! s:Rel()
  let pos = getcurpos()
  let line = getline('.')
  let token = s:TokenAtCursor(line, pos[2])
  if len(token) > 0
    let s:RelResolveMaxIter = 5
    call s:RelResolve(token)
  endif
endfun

if ! hasmapto('<Plug>(Rel)')
  nmap <unique> <C-k> <Plug>(Rel)
endif

nnoremap <Plug>(Rel) :call <SID>Rel()<CR>

let &cpo= s:keepcpo
unlet s:keepcpo
