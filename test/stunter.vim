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
let s:save_cpo = &cpo
set cpo&vim

scriptencoding utf-8

fun! Stunter(sid)
  let s:count = 0
  let s:sid = a:sid
  fun! s:StunterTest(...) abort " func, args...
    if a:0 != 3
      echoerr 'Usage :call StunterTest(subject, args, expected)'
      finish
    endif
    let funcName = a:000[0]
    let callName = funcName
    if funcName[0] ==# 's' && funcName[1] ==# ':'
      let callName = '<SNR>' . s:sid . '_' . funcName[2:]
    endif
    let Fn = funcref(callName)
    let args = a:000[1]
    let result = call(Fn, args)
    let s:count += 1
    let sres = string(result)
    let sexp = string(a:000[2])
    if sres == sexp
      let fnargs = string(a:000[1])
      let fnargs = strcharpart(fnargs, 1)
      let fnargs = strcharpart(fnargs, 0, len(fnargs) - 1)
      echomsg 'ok..' . s:count . '  ' . funcName . '(' . fnargs . ')' .
            \ ' == ' . sexp
    else
      echoerr 'Error: expected ' . sres . ' to be ' . sexp
    endif
  endfun
  return funcref('s:StunterTest')
endfun

echomsg 'Loaded Stunter ' . g:stunter_version

let &cpo = s:save_cpo
unlet s:save_cpo
