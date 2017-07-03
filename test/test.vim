
fun! ExpectCursor(pos)
  let l:realPos = join(getpos('.')[1:2], ':')
  if a:pos !=# l:realPos
    throw 'Expected cursor at ' . a:pos . ' got ' . l:realPos
  else
    echomsg 'cursor..ok'
  endif
endfun

let Test = rel#StunterTest()

echomsg 's:NormalizePath'
call Test('s:NormalizePath', ['/tmp/foo'], '/tmp/foo')
call Test('s:NormalizePath', ['/tmp/foo'], '/tmp/foo')
call Test('s:NormalizePath', ['/tmp/%20foo'], '/tmp/\ foo')
call Test('s:NormalizePath', ['~/%26foo'], $HOME . '/&foo')
call Test('s:NormalizePath', ['$HOME/%26foo'], $HOME . '/&foo')
call Test('s:NormalizePath', ['/%26-$ENV_VALUE1/foo'], '/&-100/foo')
" FIXME Problem
" call Test('s:NormalizePath', ['%24XX$ENV_VALUE1/foo'], '')

echomsg 's:TokenAtCursor'
call Test('s:TokenAtCursor', ['stunter.vim#:2', 0], 'stunter.vim#:2')
call Test('s:TokenAtCursor', ['stunter.vim#:2', 1], 'stunter.vim#:2')
call Test('s:TokenAtCursor', [' stunter.vim#:2', 0], '')
call Test('s:TokenAtCursor', ['<<stunter.vim#:2>>', 3], 'stunter.vim#:2')
call Test('s:TokenAtCursor', ['<<<<stunter.vim#:2>>>>', 3], '')
call Test('s:TokenAtCursor', ['<stunter.vim#:2>', 14], 'stunter.vim#:2')
call Test('s:TokenAtCursor', ['<stunter.vim#:2>', 15], '')

echomsg 'rel#Rel - various'
let g:rel_open = 'edit'
call Test('rel#Rel', ['stunter.vim#:4'], 0, 'getcurpos()[1:2] == [4,1]')
call Test('rel#Rel', [ 'stunter.vim#:7:10' ], 0, 'getcurpos()[1:2] == [7, 10]')
call Test('rel#Rel', [ '<<stunter.vim#:26:20>>', 3], 0, 'getcurpos()[1:2] == [26, 20]')
call Test('rel#Rel', ['stunter.vim#/g:stunter', 3], 0, 'getcurpos()[1:2] == [7, 12]')
call Test('rel#Rel', ['"stunter.vim#/g:stunter"', 3], 0, 'getcurpos()[1:2] == [7, 12]')
call Test('rel#Rel', ['(<"stunter.vim#/g:stunter">)', 3], 0, 'getcurpos()[1:2] == [7, 12]')

echomsg 'rel#Rel - help:'
call Test('rel#Rel', ['help:variables#/when%20compiled'], 0)

if !has('nvim')
  call ExpectCursor('44:37')
endif

" Later
if 0
  echomsg 's:GetMimeType'
  call Test('s:GetMimeType', ['/tmp'], 'inode/directory')

  echomsg 's:LookupMimeProgram'
  call Test('s:LookupMimeProgram', ['inode/directory'], [0, ['rox %f']])
  call Test('s:LookupMimeProgram', ['audio/x-wav'], [0, ['vlc %f']])
endif

:qa
finish

let s:test_count = 0

fun! Expect(res)
  if g:rel_test_mode_result !=# a:res
    throw 'Expected ' . a:res . ' got ' . g:rel_test_mode_result
  else
    echomsg 'ok..' . s:test_count
    let s:test_count = s:test_count + 1
  endif
endfun

fun! ExpectCursor(pos)
  let l:realPos = join(getpos('.')[1:2], ':')
  if a:pos !=# l:realPos
    throw 'Expected cursor at ' . a:pos . ' got ' . l:realPos
  else
    echomsg 'ok..' . s:test_count
    let s:test_count = s:test_count + 1
  endif
endfun


"
" Edit file
"
let g:rel_open = 'edit'

:Rel test.sh#:4
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#:4', 'test.sh', ':4', '', '', '', '', '', '', '']) -->  edit  test.sh 4::4")
call ExpectCursor('4:1')

:Rel test.sh#:8:10
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#:8:10', 'test.sh', ':8:10', '', '', '', '', '', '', '']) -->  edit  test.sh 8:10")
call ExpectCursor('8:10')

:Rel test.sh#/rel_test
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#/rel_test', 'test.sh', '/rel_test', '', '', '', '', '', '', '']) -->  edit  test.sh /rel_test")
call ExpectCursor('9:16')

"
" Edit in Preview window
" 
let g:rel_open = 'pedit'

:Rel test.sh#:4
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#:4', 'test.sh', ':4', '', '', '', '', '', '', '']) -->  pedit +:4 test.sh")
:wincmd k
call ExpectCursor('4:3')
:wincmd j

:Rel test.sh#:8
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#:8', 'test.sh', ':8', '', '', '', '', '', '', '']) -->  pedit +:8 test.sh")
:wincmd k
call ExpectCursor('8:5')
:wincmd j

:Rel test.sh#/rel_test
call Expect("s:OpenManHelpOrFileAndGoto(['test.sh#/rel_test', 'test.sh', '/rel_test', '', '', '', '', '', '', '']) -->  pedit +:1/rel_test test.sh")
:wincmd k
call ExpectCursor('9:5')
:wincmd j

:Rel help:variables#/when%20compiled
call Expect("s:OpenManHelpOrFileAndGoto(['help:variables#/when%20compiled', 'help:variables', '/when%20compiled', '', '', '', '', '', '', '']) -->  help variables /when\\ compiled")

let manVim = '/tmp/vim80/runtime/ftplugin/man.vim'
if filereadable(manVim)
  exe ':source ' . manVim
  :Rel man:ls#/The%20SIZE
  call Expect("s:OpenManHelpOrFileAndGoto(['man:ls#/The%20SIZE', 'man:ls', '/The%20SIZE', '', '', '', '', '', '', '']) --> :Man ls /The\\ SIZE")
  " call ExpectCursor('176:8')
else
  echomsg 'skip..' . s:test_count
  let s:test_count = s:test_count + 1
endif

if !has('nvim')
  :Rel http://www.vim.org
  call Expect('s:RunJob(firefox http://www.vim.org)')
endif

:qa!

" vi:tw=190
