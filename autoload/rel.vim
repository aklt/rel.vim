let s:save_cpo = &cpo
set cpo&vim

scriptencoding utf-8

if has('nvim')
  if !has('nvim-0.2.0')
    echoerr 'rel.vim: Need at least neovim 0.2.0'
    finish
  endif
  fun! s:ReplaceEscapes(str) abort
    let escapes = ['%20', '%23', '%2f', '%26', '%7e', '%28', '%29', '%27', '%22']
    let replace = [' ',   '#',   '/',   '&',   '~',   '(',   ')',   "'",   '"']
    let res = a:str
    let idx = 0
    for et in escapes
      let res = substitute(res, et, replace[idx], 'gi')
      let idx = idx + 1
    endfor
    return res
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

let default_mime_programs = {
      \   'application': {
      \     'vnd.ms-excel': {
      \       'unix': ['gnumeric %f'],
      \       'win32': ['excel %f']
      \     },
      \     'x-gnumeric': {
      \       'unix': ['gnumeric %f'],
      \       'win32': ['gnumeric %f']
      \     }
      \   },
      \   'audio': {
      \     '*': {
      \       'unix': ['vlc %f'],
      \       'win32': ['TODO %f']
      \     },
      \     'mpeg': {
      \       'unix': ['clementine %']
      \     }
      \   },
      \   'image': {
      \     '*': {
      \       'unix':  ['geeqie %f', 'eog %f', 'gimp %f'],
      \       'win32': ['adcdc']
      \     },
      \     'gif': {
      \       'unix': ['imv %f', 'geeqie %f']
      \     }
      \   },
      \   'inode': {
      \     'directory': {
      \       'unix': ['rox %f']
      \     }
      \   },
      \   'video': {
      \     '*': {
      \       'unix': ['vlc %f'],
      \       'win32': ['vlc %f']
      \     }
      \   }
      \ }

if exists('g:rel_mime_programs')
  let s:mimePrograms = extend(default_mime_programs, g:rel_mime_programs)
else
  let s:mimePrograms = default_mime_programs
endif

fun! s:NormalizePath(path) abort
  let res = substitute(a:path, '^\~', $HOME, 'e')
  let res = substitute(res, '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g')
  return escape(res, ' ')
endfun

fun! s:RunJob(cmd, arg) abort
  let job = substitute(a:cmd, '%s', a:arg, 'g')
  if ! has('job')
    return system(job)
  endif
  call job_start(job, {
        \ 'err_io': 'null',
        \ 'in_io': 'null',
        \ 'out_io': 'null'
        \ })
  if exists('g:rel_test_mode')
    let g:rel_test_mode_result = 's:RunJob(' . job . ')'
  endif
endfun

" Run one of the shell commands replacing %f with the file name and  continuing
" until one of the succeeds.
"
" Returns [0, [cmd output]] on success and
"         [errCode, [error], errCode, [error], ...] on failure
fun! s:RunOneOf (commands, filename) abort
  let out = ''
  let res = []
  for p in a:commands
    let cmd = substitute(p, '%f', a:filename, 'g')
    let out = systemlist(cmd)
    if v:shell_error == 0
      return [0, out]
    else
      call add(res, v:shell_error)
      call add(res, out)
    endif
  endfor
  return res
endfun

fun! s:GetMimeType (filename) abort
  let res = system('file --mime-type ' . a:filename)
  if v:shell_error == 0
    let mime = substitute(res, '^[^:]\+:\s*\|\n$', '', 'gm')
    return mime
  endif
endfun

let s:os = 'unix'

if has('macunix')
  let s:os = 'macunix'
elseif has('win32')
  let s:os = 'win32'
elseif has('win32unix')
  let s:os = 'win32unix'
endif

fun! s:LookupMimeProgram (mimeType) abort
  let key = split(a:mimeType, '/')
  if ! has_key(s:mimePrograms, key[0])
    return [1, 'no mime head: ' . key[0]]
  endif
  let it = s:mimePrograms[key[0]]
  if ! has_key(it, key[1])
    if ! has_key(it, '*')
      return [2, 'no mime tail: ' . key[1] . ' or *']
    endif
    let it = it['*']
  else
    let it = it[key[1]]
  endif
  if ! has_key(it, s:os)
    return [3, 'no OS key for ' . a:mimeType]
  endif
  return [0, it[s:os]]
endfun

fun! s:GetMimePrograms(filename) abort
  let mime = s:GetMimeType(a:filename)
  return s:LookupMimeProgram(mime)
endfun

fun! s:OpenManHelpOrFileAndGoto(a) abort
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
        " work around nvim bug: cannot handle funcref in substitution
        if has('nvim')
          let needle = escape(s:ReplaceEscapes(needle), ' ')
        else
          let needle = escape(substitute(needle,
                \ '%\(\x\x\)', '\=nr2char("0x" . submatch(1))', 'g'), ' ')
        endif
      endif
    endif
    let peditopen = ''
    if ! empty(helpOrMan)
      exe helpOrMan
      if exists('g:rel_test_mode')
        let g:rel_test_mode_result = 's:OpenManHelpOrFileAndGoto('
              \ . string(a:a) . ') --> ' . helpOrMan
      endif
    else
      " jump to fragment in preview window
      if g:rel_open =~# '^:\?ped'
        if frag ==# ':'
          let peditopen = '+:' . line
        elseif frag ==# '/'
          let peditopen = '+:1/' . needle
        endif
      endif
      let exeCmd = ''
      if g:rel_open =~# 'tab'
        let exeCmd = g:rel_open . ' ' . filename
      else
        let exeCmd = g:rel_modifiers . ' ' . g:rel_open . ' ' . peditopen . ' ' . filename
      endif
      exe exeCmd
      if exists('g:rel_test_mode')
        let g:rel_test_mode_result = 's:OpenManHelpOrFileAndGoto('
              \ . string(a:a) . ') --> ' . exeCmd
      endif
    endif
    " no jump in preview window so place cursor in this window
    if empty(peditopen)
      if frag ==# ':'
        call cursor(str2nr(line), str2nr(column))
        if exists('g:rel_test_mode')
          let g:rel_test_mode_result .= ' ' . line . ':' . column
        endif
      elseif frag ==# '/'
        call cursor(1, 1)
        call search(needle)
        if exists('g:rel_test_mode')
          let g:rel_test_mode_result .= ' ' . '/' . needle
        endif
      endif
    endif
    " Open folds if any
    if ! empty(peditopen)
      wincmd P
      if &previewwindow
        silent! .foldopen
      endif
      wincmd p
    else
      silent! .foldopen
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
  let rel = a:a[1]
  let ext = tolower(a:a[2])
  if len(ext) == 0 || ! has_key(g:rel_extmap, ext)
    return a:a[0]
  endif
  let job = g:rel_extmap[ext]
  return s:RunJob(job, s:NormalizePath(a:a[1]))
endfun

fun! s:OpenResolvedScheme(a) abort
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

let s:rel_handlers = [
      \ [ '^\(\w\+\):\([^#]*\)\%(#\(\%(\/\|:\)\S\+\)\)\?',
      \  funcref('s:OpenResolvedScheme')],
      \ [ '\(\%(http\|ftp\)s\?:\/\/[' . g:rel_http_chars . ']\+\)',
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
  for hdl in s:rel_handlers
    let token2 = substitute(a:token, hdl[0], hdl[1], 'ie')
    if token2 != a:token
      return
    endif
  endfor
endfun

fun! rel#Rel(...) abort
  if ! empty(a:000)
    let token = a:000[0]
    if len(token) > 0
      let s:RelResolveMaxIter = 5
      call s:RelResolve(token)
    endif
  endif
endfun

fun! rel#StunterTest() abort
  fun! s:SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
  endfun
  let sid = s:SID()
  runtime stunter.vim
  return Stunter(s:SID())
endfun

let &cpo = s:save_cpo
unlet s:save_cpo
