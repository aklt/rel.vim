#!/usr/bin/env bash

dir=$(pwd)

(cd ./test && for cmd in "vim --not-a-term" "nvim -n --headless"; do
  echo "running ${cmd}"
  export ENV_VALUE1=100
  export ENV_VALUE2=202
  ${cmd} --noplugin -u NONE \
    -c ':set nocp' \
    -c ':filetype plugin indent on' \
    -c ':syntax on' \
    -c ":set rtp=${dir}/,${dir}/test" \
    -c ':set shortmess=aT' \
    -c ":source ${dir}/plugin/rel.vim" \
    -c ":redir >> /tmp/rel.vim.test.$$.txt" \
    -c ':source ./test.vim' \
    -c ':redir END'
  ec=$?
  if [ ${ec} -ne 0 ]; then
    exit ${ec}
  else
    case "${cmd}" in
      vim*)
        cat /tmp/rel.vim.test.$$.txt
        ;;
    esac
    echo
  fi
  rm -f /tmp/rel.vim.test.$$.txt
done)
