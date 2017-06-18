"===============================================================================
" File:        rel.vim
" Description: Vim plugin to handle links to resources
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     This program is free software. It comes without any warranty.
"===============================================================================
if exists('g:rel_version')
  finish
endif
if has('nvim')
  if !has('nvim-0.2.0')
    echoerr 'rel.vim: Need at least neovim 0.2.0'
    finish
  endif
else
  if v:version < 800 || (v:version == 800 && !has('patch0020'))
    echoerr 'rel.vim: Need at least vim 8.0.0020'
    finish
  endif
endif
let g:rel_version = '0.1.1'
let s:keepcpo = &cpo
set cpo&vim

scriptencoding utf-8

if ! exists('g:rel_open')
  let g:rel_open = 'edit'
endif

if ! exists('g:rel_modifiers')
  let g:rel_modifiers = ''
endif

if ! exists('g:rel_http')
  let g:rel_http = 'firefox %s'
endif

if ! exists('g:rel_extmap')
  let g:rel_extmap = {'html': 'firefox %s'}
endif

if ! exists('g:rel_highlight')
  let g:rel_highlight = 3
endif

if ! exists('g:rel_schemes')
  let g:rel_schemes = {}
endif

fun! s:NormalizePath(path)
  let res = substitute(a:path, '^\~', $HOME, 'e')
  let res = substitute(res, '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g')
  return res
endfun

fun! s:RunJob(cmd, arg)
  let job = substitute(a:cmd, '%s', a:arg, 'g')
  if ! has('job')
    return system(job)
  endif
  call job_start(job, {
        \ 'err_io': 'null',
        \ 'in_io': 'null',
        \ 'out_io': 'null'
        \ })
endfun

fun! s:OpenManHelpOrFileAndGoto(a)
  let filename = s:NormalizePath(a:a[1])
  let goto = a:a[2]
  if len(filename) > 0
    let helpOrMan = ''
    if filename =~? '^man:'
      if ! exists(':Man')
        echoerr 'please enable :Man command with "runtime ftplugin/man.vim"'
        return
      endif
      let page = strcharpart(filename, 4)
      let helpOrMan = ':Man ' . page
    elseif filename =~? '^help:'
      let page = strcharpart(filename, 5)
      if g:rel_open =~# 'tab'
        let helpOrMan = ':tab help ' . page
      else
        let helpOrMan = g:rel_modifiers . ' help ' . page
      endif
    endif
    let frag = ''
    if len(goto) > 0
      let line = 1
      let column = 1
      let needle = ''
      if goto[0] ==# ':' " Jump to position
        let frag = ':'
        let line = substitute(goto, '^:\?\(\d\+\).*$', '\1', 'e')
        let column = substitute(goto, '^:\?\d\+:\(\d\+\).*$', '\1', 'e')
        if len(line) == 0
          let line = 1
        endif
        if len(column) == 0
          let column = 1
        endif
      else " Jump to regex
        let frag = '/'
        let needle = strcharpart(goto, 1)
        if goto[0] !=# '/'
          let needle = goto
        endif
        let needle = escape(substitute(needle,
              \ '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g'), ' ')
      endif
    endif
    let peditopen = ''
    if ! empty(helpOrMan)
      exe helpOrMan
    else
      " jump to fragment in preview window
      if g:rel_open =~# '^:\?ped'
        if frag ==# ':'
          let peditopen = '+:' . line
        elseif frag ==# '/'
          let peditopen = '+:1/' . needle
        endif
      endif
      if g:rel_open =~# 'tab'
        exe g:rel_open . ' ' . filename
      else
        exe g:rel_modifiers . ' ' . g:rel_open . ' ' . peditopen . ' ' . filename
      endif
    endif
    " no jump in preview window so place cursor in this window
    if empty(peditopen)
      if frag ==# ':'
        call cursor(str2nr(line), str2nr(column))
      elseif frag ==# '/'
        call cursor(1, 1)
        call search(needle)
      endif
    endif
    return 1
  endif
  return a:a[0]
endfun

fun! s:OpenHttp(a)
  " echomsg 's:OpenHttp ' . string(a:a)
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
  " echomsg 's:OpenResolvedScheme ' . string(a:a)
  if exists('g:rel_schemes') && has_key(g:rel_schemes, a:a[1])
    let Resolved = g:rel_schemes[a:a[1]]
    if empty(a:a[2]) && empty(a:a[3])
      echomsg 'rel.vim: scheme ' . a:a[1] . ' is ' . string(Resolved)
      return
    endif
    if type(Resolved) == type('')
      if len(a:a[2]) > 0
        if stridx(Resolved, '%p') > -1
          let Resolved = substitute(Resolved, '%p', a:a[2], 'g')
        else
          echoerr 'missing %p path in g:rel_schemes[' . a:a[1] . ']'
          return
        endif
      endif
      if len(a:a[3]) > 0
        if stridx(Resolved, '%f') > -1
          let Resolved = substitute(Resolved, '%f', a:a[3], 'g')
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

let s:not_ok = ' \t"<>'
let s:http_chars = "!#$%&'()*+,-./0-9:;=?@A-Z_a-z~"

let s:rel_handlers = [
      \ [ '^\(\w\+\):\([^#]*\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \  funcref('s:OpenResolvedScheme')],
      \ [ '\(\%(http\|ftp\)s\?:\/\/[' . s:http_chars . ']\+\)',
      \  funcref('s:OpenHttp') ],
      \ [ '^\(\S\+\.\(\w\+\)\)$', funcref('s:OpenFileExt') ],
      \ [ '^\%(file:\/\/\)\?\([^#]\+\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \  funcref('s:OpenManHelpOrFileAndGoto')]
      \ ]

if g:rel_highlight > 0
  hi link xREL htmlLink
  let match = ['\c\%(\%(^\|[' . s:not_ok . ']\)\zs\%(' .
      \ join(add(add(keys(g:rel_schemes), 'man'), 'help'), '\|') .
      \ '\):[^' . s:not_ok . ']\+\)',
      \ '\%([^' . s:not_ok . ']\+\.\%(' . join(keys(g:rel_extmap), '\|') . '\)\)',
      \ '[^' . s:not_ok . ']\+#[\/:][^' . s:not_ok . ']\+',
      \ '\%(http\|ftp\)s\?:\/\/[' . s:http_chars . ']\+',
      \ '\%(^\|[' . s:not_ok . ']\)\zs\%(\.\.\|\.\|\~\|\w\+\)\?\/\/\@!\f[^' .
      \ s:not_ok . ']*'
      \ ]

  let g:rel_syn_match = '\%(' . join(match[:g:rel_highlight - 1], '\|') . '\)'
  unlet match
  augroup REL
    au!
    au BufWinEnter * call matchadd('xREL', g:rel_syn_match)
  augroup END
endif

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

fun! s:Rel(...)
  if ! empty(a:000)
    let token = a:000[0]
    if len(token) > 0
      " Recognize markdown links
      if token =~# '\[[^\]]\+\]([^\)]\+)'
        let token = substitute(token, '!\?\[[^\]]\+\](\([^\)]\+\))', '\1', '')
      endif
      let s:RelResolveMaxIter = 5
      call s:RelResolve(token)
    endif
  endif
endfun

if ! hasmapto('<Plug>(Rel)')
  nmap <unique> <C-k> <Plug>(Rel)
  nmap <LeftMouse> <Plug>(Rel)
endif

nnoremap <Plug>(Rel) :call <SID>Rel(expand('<cWORD>'))<CR>
command! -nargs=* Rel call <SID>Rel(<f-args>)

let &cpo= s:keepcpo
unlet s:keepcpo
