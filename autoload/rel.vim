let s:save_cpo = &cpoptions
set cpoptions&vim

scriptencoding utf-8

if has('nvim')
  if !has('nvim-0.2.0')
    echoerr 'rel.vim: Need at least neovim 0.2.0'
    finish
  endif
  fun! s:ReplaceEscapes(str) abort
    let l:escapes = ['%20', '%23', '%2f', '%26', '%7e', '%28', '%29', '%27', '%22']
    let l:replace = [' ',   '#',   '/',   '&',   '~',   '(',   ')',   "'",   '"']
    let l:res = a:str
    let l:idx = 0
    for l:et in l:escapes
      let l:res = substitute(l:res, l:et, l:replace[l:idx], 'gi')
      let l:idx = l:idx + 1
    endfor
    return l:res
  endfun
else
  if v:version < 800 || (v:version == 800 && !has('patch0020'))
    echoerr 'rel.vim: Need at least vim 8.0.0020'
    finish
  endif
endif

if ! exists('g:rel_open')
  let g:rel_open = 'edit'
endif

if ! exists('g:rel_modifiers')
  let g:rel_modifiers = ''
endif

if ! exists('g:rel_http')
  let g:rel_http = 'firefox %s'
endif

fun! s:NormalizePath(path) abort
  let l:res = substitute(a:path, '^\~', $HOME, 'e')
  let l:res = expand(a:path)
  let l:res = substitute(l:res, '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g')
  return escape(l:res, ' ')
endfun

fun! s:RunJob(cmd, arg) abort
  let l:job = substitute(a:cmd, '%s', a:arg, 'g')
  if ! has('job')
    return system(l:job)
  endif
  call job_start(l:job, {
        \ 'err_io': 'null',
        \ 'in_io': 'null',
        \ 'out_io': 'null'
        \ })
endfun

fun! s:OpenManHelpOrFileAndGoto(a) abort " (_, filename, goto)
  let l:filename = s:NormalizePath(a:a[1])
  let l:goto = a:a[2]
  if len(l:filename) > 0
    let l:helpOrMan = ''
    if l:filename =~? '^man:'
      if ! exists(':Man')
        echoerr 'please enable :Man command with "runtime ftplugin/man.vim"'
        return
      endif
      let l:page = strcharpart(l:filename, 4)
      let l:helpOrMan = ':Man ' . l:page
    elseif l:filename =~? '^help:'
      let l:page = strcharpart(l:filename, 5)
      if g:rel_open =~# 'tab'
        let l:helpOrMan = ':tab help ' . l:page
      else
        let l:helpOrMan = g:rel_modifiers . ' help ' . l:page
      endif
    endif
    let l:frag = ''
    if len(l:goto) > 0
      let l:line = 1
      let l:column = 1
      let l:needle = ''
      if l:goto[0] ==# ':' " Jump to position
        let l:frag = ':'
        let l:line = substitute(l:goto, '^:\?\(\d\+\).*$', '\1', 'e')
        let l:column = substitute(l:goto, '^:\?\d\+:\(\d\+\).*$', '\1', 'e')
        if len(l:line) == 0
          let l:line = 1
        endif
        if len(l:column) == 0
          let l:column = 1
        endif
      else " Jump to regex
        let l:frag = '/'
        let l:needle = strcharpart(l:goto, 1)
        if l:goto[0] !=# '/'
          let l:needle = l:goto
        endif
        " work around nvim bug: cannot handle funcref in substitution
        if has('nvim')
          let l:needle = escape(s:ReplaceEscapes(l:needle), ' \\')
        else
          let l:needle = escape(substitute(l:needle,
                \ '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g'), ' \\')
        endif
      endif
    endif
    let l:peditopen = ''
    if ! empty(l:helpOrMan)
      exe l:helpOrMan
    else
      " Give files an absolute path
      if l:filename[0] !=# '/'
        let l:filename = expand('%:p:h') . '/' . l:filename
      endif
      " jump to fragment in preview window
      if g:rel_open =~# '^:\?ped'
        if l:frag ==# ':'
          let l:peditopen = '+:' . l:line
        elseif l:frag ==# '/'
          let l:peditopen = '+:1/' . l:needle
        endif
      endif
      let l:exeCmd = ''
      if g:rel_open =~# 'tab'
        let l:exeCmd = g:rel_open . ' ' . l:filename
      else
        let l:exeCmd = g:rel_modifiers . ' ' . g:rel_open . ' ' . l:peditopen . ' ' . l:filename
      endif
      exe l:exeCmd
    endif
    " no jump in preview window so place cursor in this window
    if empty(l:peditopen)
      if l:frag ==# ':'
        call cursor(str2nr(l:line), str2nr(l:column))
      elseif l:frag ==# '/'
        call cursor(1, 1)
        call search(l:needle)
      endif
    endif
    " Open folds if any
    if foldlevel('.') > 0
      if ! empty(l:peditopen)
        wincmd P
        if &previewwindow
          silent! .foldopen
        endif
        wincmd p
      else
        silent! .foldopen
      endif
    endif
    return 1
  endif
  return a:a[0]
endfun

fun! s:OpenHttp(a)abort
  " echomsg 's:OpenHttp ' . string(a:a)
  call s:RunJob(g:rel_http, a:a[1])
  return 1
endfun

fun! s:OpenFileExt(a) abort
  let l:rel = a:a[1]
  let l:ext = tolower(a:a[2])
  if len(l:ext) == 0 || ! has_key(g:rel_extmap, l:ext)
    return a:a[0]
  endif
  let l:job = g:rel_extmap[l:ext]
  return s:RunJob(l:job, s:NormalizePath(a:a[1]))
endfun

fun! s:OpenResolvedScheme(a) abort
  " echomsg 's:OpenResolvedScheme ' . string(a:a)
  if exists('g:rel_schemes') && has_key(g:rel_schemes, a:a[1])
    let l:Resolved = g:rel_schemes[a:a[1]]
    if empty(a:a[2]) && empty(a:a[3])
      echomsg 'rel.vim: scheme ' . a:a[1] . ' is ' . string(l:Resolved)
      return
    endif
    if type(l:Resolved) == type('')
      if len(a:a[2]) > 0
        if stridx(l:Resolved, '%p') > -1
          let l:Resolved = substitute(l:Resolved, '%p', a:a[2], 'g')
        else
          echoerr 'missing %p path in g:rel_schemes[' . a:a[1] . ']'
          return
        endif
      endif
      if len(a:a[3]) > 0
        if stridx(l:Resolved, '%f') > -1
          let l:Resolved = substitute(l:Resolved, '%f', a:a[3], 'g')
        else
          let l:Resolved .= '#' . a:a[3]
        endif
      endif
      return s:RelResolve(l:Resolved)
    elseif type(l:Resolved) == type(funcref('s:OpenHttp'))
      let l:res = call(l:Resolved, [a:a[0], a:a[2], a:a[3]])
      if type(l:res) == type(0) && l:res == 0
        return a:a[0]
      elseif l:res == 1
        call s:RelResolve(a:a[0])
      elseif len(l:res) > 0
        call s:RelResolve(l:res)
      endif
      return 1
    endif
  endif
  return a:a[0]
endfun

let s:rel_handlers = [
      \ [ '^\(\w\+\):\([^#]*\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \  funcref('s:OpenResolvedScheme')],
      \ [ '\(\%(http\|ftp\)s\?:\/\/[' . g:rel_link_chars . ']\+\)',
      \  funcref('s:OpenHttp') ],
      \ [ '^\(\S\+\.\(\w\+\)\)$', funcref('s:OpenFileExt') ],
      \ [ '^\%(file:\/\/\)\?\([^#]\+\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \  funcref('s:OpenManHelpOrFileAndGoto')]
      \ ]

let s:RelResolveMaxIter = 5

fun! s:RelResolve(token) abort
  let s:RelResolveMaxIter = s:RelResolveMaxIter - 1
  if s:RelResolveMaxIter < 0
    echomsg 'rel.vim: recursed too deeply while resolving'
    return
  endif
  for l:hdl in s:rel_handlers
    let l:token2 = substitute(a:token, l:hdl[0], l:hdl[1], 'ie')
    if l:token2 != a:token
      return
    endif
  endfor
endfun

fun! s:MakeCharLookup(chars)
  let l:res = []
  let l:len = strchars(a:chars)
  let l:i = 0
  while l:i < 256
    call add(l:res, 0)
    let l:i = l:i + 1
  endwhile

  let l:i = 0
  while l:i < l:len
    let l:val = char2nr(strcharpart(a:chars, l:i, 1))
    if l:val < 256
      let l:res[l:val] = 1
    endif
    let l:i = l:i + 1
  endwhile
  return join(l:res, '')
endfun

let s:lookup = s:MakeCharLookup(g:rel_link_chars)

fun! s:TokenAtCursor(line, cpos)
  let l:line = map(split(a:line, '\zs'), {i, c -> char2nr(c)})
  let l:last = len(a:line)

  let l:b = a:cpos
  let l:e = a:cpos
  let l:bok = 1
  let l:eok = 1

  while l:bok || l:eok
    if l:bok && l:b >= 0 && l:line[l:b] < 256 && s:lookup[l:line[l:b]] == '1'
      let l:b = l:b - 1
    else
      if l:bok && l:b >= 0
        let l:b += 1
      endif
      let l:bok = 0
    endif

    if l:eok && l:e < l:last && l:line[l:e] < 256 && s:lookup[l:line[l:e]] == '1'
      let l:e = l:e + 1
    else
      let l:eok = 0
    endif
  endwhile
  return strcharpart(a:line, l:b, l:e - l:b)
endfun

fun! rel#Rel(...) abort
  let l:token = ''
  let l:column = 1
  if empty(a:000)
    let l:line = getline('.')
    let l:column = getcurpos()[2]
  else
    let l:line = a:000[0]
    if a:0 > 1
      let l:column = a:000[1]
    endif
  endif
  let l:token = s:TokenAtCursor(l:line, l:column)
  " echomsg 'Token ' . l:token
  if len(l:token) > 0
    let s:RelResolveMaxIter = 5
    call s:RelResolve(l:token)
  endif
endfun

fun! rel#StunterTest() abort
  fun! s:SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
  endfun
  runtime stunter.vim
  return Stunter(s:SID())
endfun

let &cpoptions = s:save_cpo
unlet s:save_cpo
