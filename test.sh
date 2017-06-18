#!/usr/bin/env bash

vim --noplugin -u NONE \
  -c ':set nocp' \
  -c ':filetype plugin indent on' \
  -c ':syntax on' \
  -c ':let g:rel_test_mode = 1' \
  -c ':source ./plugin/rel.vim' \
  -c ":redir >> /tmp/rel.vim.test.$$.txt" \
  -c ':source ./test.vim' \
  -c ':redir END'

cat /tmp/rel.vim.test.$$.txt
echo
rm -f /tmp/rel.vim.test.$$.txt
