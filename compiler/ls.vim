" Language:    LiveScript
" Maintainer:  Michael Quad
" URL:         http://github.com/gkz/vim-ls
" URL:         http://github.com/determin1st/vim-lsx
" License:     WTFPL

" default check
if exists('current_compiler')
  finish
endif
let current_compiler = 'ls'
" set global defaults
if !exists('livescript_compiler')
  let livescript_compiler = 'lsc'
endif
if !exists('livescript_extra_compiler')
  let livescript_extra_compiler = ''
endif
if !exists('livescript_compile_auto')
  let livescript_compile_auto = 1
endif
" create helpers
function! s:LiveScriptMake()
  " after some fiddling with "make",
  " i've decided to put everything straight into vimscript,
  " make sux and this is a much cleaner way:
  " compile livescript code and get the output
  let o = system(g:livescript_compiler . ' -cb ' . shellescape(expand('%')))
  " check for error
  if strlen(o)
    " simply dump everything
    echo "\n"
    echohl ErrorMsg
    echo o . "\n"
    echohl None
    " finish
    return
  endif
  " check for extra compiler
  if strlen(g:livescript_extra_compiler) && expand('%:e') ==# 'lsx'
    " compile generated javascript with extra compiler
    let f = expand('%:r') . '.js'
    let o = system(g:livescript_extra_compiler . ' ' . shellescape(f))
    " save the output
    let o = ["// lsx: " . g:livescript_extra_compiler] + split(o, "\n", 1)
    call writefile(o, f, 's')
  endif
endfunction
function! s:LiveScriptAutoMake()
  if g:livescript_compile_auto
    call s:LiveScriptMake()
  endif
endfunction
" define the autocommands group
augroup LiveScriptMakeAuto
  " to prevent this defined twice,
  " cleanup
  autocmd!
  " compile livescript file on save
  autocmd BufWritePost <buffer> call s:LiveScriptAutoMake()
augroup END

" editor settings
" vim: fdm=marker ts=2 sw=2 sts=2 nu:
