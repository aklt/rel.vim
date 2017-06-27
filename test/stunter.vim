"===============================================================================
" File:        stunter.vim
" Description: Run simple vim tests
" Author:      Anders Thøgersen <anders [at] bladre.dk>
" License:     MIT This program is free software. It comes without any warranty.
"===============================================================================
if exists('g:stunter_version')
  finish
endif
let g:stunter_version = 'v0.1.0'
let s:save_cpo = &cpoptions
set cpoptions&vim

scriptencoding utf-8

fun! Stunter(sid) " 'MethodName, args, expected[, expression]'
  let s:count = 0
  let s:sid = a:sid
  fun! s:StunterTest(...) abort " func, args...
    if !(a:0 == 3 || a:0 == 4)
      echoerr 'Usage :call StunterTest(subject, args, expected[, expression])'
      return
    endif
    let l:funcName = a:000[0]
    let l:callName = l:funcName
    if l:funcName[0] ==# 's' && l:funcName[1] ==# ':'
      let l:callName = '<SNR>' . s:sid . '_' . l:funcName[2:]
    endif
    let l:Fn = funcref(l:callName)
    let l:args = a:000[1]
    let l:result = call(l:Fn, l:args)
    let s:count += 1
    let l:sres = string(l:result)
    let l:sexp = string(a:000[2])
    if l:sres == l:sexp
      let l:fnargs = string(a:000[1])
      let l:fnargs = strcharpart(l:fnargs, 1)
      let l:fnargs = strcharpart(l:fnargs, 0, len(l:fnargs) - 1)
      echomsg 'ok..' . s:count . '  ' . l:funcName . '(' . l:fnargs . ')' .
            \ ' == ' . l:sexp
    else
      echoerr 'Error: expected ' . l:sres . ' to be ' . l:sexp
    endif
    if len(a:000) == 4
      let l:eres = eval(a:000[3])
      if !l:eres
        echomsg 'Expected evaluation of ' . a:000[3] . ' to be truthy'
      endif
    endif
  endfun
  return funcref('s:StunterTest')
endfun

echomsg 'Loaded Stunter ' . g:stunter_version

let &cpoptions = s:save_cpo
unlet s:save_cpo
