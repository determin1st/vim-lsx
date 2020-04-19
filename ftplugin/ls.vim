" default check
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1
" ...

setlocal formatoptions-=t formatoptions+=croql
setlocal comments=:#
setlocal commentstring=#\ %s
setlocal omnifunc=javascriptcomplete#CompleteJS

" enable LiveScriptMake if it won't overwrite any settings.
if !len(&l:makeprg)
  compiler ls
endif
" check here in case the compiler above isn't loaded.
if !exists('livescript_compiler')
  let livescript_compiler = 'lsc'
endif
if !exists('livescript_extra_compiler')
  let livescript_extra_compiler = ''
endif
if !exists('livescript_compile_vert')
  let livescript_compile_vert = 1
endif

" resets variables for the current buffer.
function! s:LiveScriptCompileResetVars()
  " {{{
  let b:livescript_compile_buf = -1
  let b:livescript_compile_pos = []
  let b:livescript_compile_watch = 0
  " }}}
endfunction

" cleans things up in the source buffer.
function! s:LiveScriptCompileClose()
  " {{{
  exec bufwinnr(b:livescript_compile_src_buf) 'wincmd w'
  silent! autocmd! LiveScriptCompileAuWatch * <buffer>
  call s:LiveScriptCompileResetVars()
  " }}}
endfunction

" updates the LiveScriptCompile buffer given some input lines.
function! s:LiveScriptCompileUpdate(startline, endline, ext)
  " {{{
  " get input string
  let input = join(getline(a:startline, a:endline), "\n")
  " Move to the compile buffer.
  exec bufwinnr(b:livescript_compile_buf) 'wincmd w'
  " LiveScript doesn't like empty input.
  if !len(input)
    return
  endif
  " compile the input
  let output = system(g:livescript_compiler . ' -scb 2>&1', input)
  " check for extra compiler
  if a:ext ==# 'lsx'
    " add extra message and
    " feed the compiler
    let output = "// lsx: " . g:livescript_extra_compiler . "\n" . output
    let output = system(g:livescript_extra_compiler . ' 2>&1', output)
  endif
  " Be sure we're in the compile buffer before overwriting.
  if exists('b:livescript_compile_buf')
    echoerr 'compile buffers are messed up'
    return
  endif
  " Replace buffer contents with new output and delete the last empty line.
  setlocal modifiable
    exec '% delete _'
    put! =output
    exec '$ delete _'
  setlocal nomodifiable
  " Highlight as JavaScript if there is no compile error.
  if v:shell_error
    setlocal filetype=
  else
    setlocal filetype=javascript
  endif
  call setpos('.', b:livescript_compile_pos)
  " }}}
endfunction

" updates the compile buffer with the whole source buffer.
function! s:LiveScriptCompileWatchUpdate(ext)
  " {{{
  call s:LiveScriptCompileUpdate(1, '$', a:ext)
  exec bufwinnr(b:livescript_compile_src_buf) 'wincmd w'
  " }}}
endfunction

" peek at compiled LiveScript in a scratch buffer.
" ranges are handled ranges like this to prevent
" the cursor from being moved (and its position saved)
" before the function is called.
function! s:LiveScriptCompile(startline, endline, args)
  " {{{
  if !executable(g:livescript_compiler)
    echoerr "Can't find LiveScript compiler `" . g:livescript_compiler . "`"
    return
  endif

  " if in the compile buffer,
  " switch back to the source buffer and continue.
  if !exists('b:livescript_compile_buf')
    exec bufwinnr(b:livescript_compile_src_buf) 'wincmd w'
  endif

  " parse arguments.
  let watch = a:args =~ '\<watch\>'
  let unwatch = a:args =~ '\<unwatch\>'
  let size = str2nr(matchstr(a:args, '\<\d\+\>'))
  " Determine default split direction.
  if g:livescript_compile_vert
    let vert = 1
  else
    let vert = a:args =~ '\<vert\%[ical]\>'
  endif
  " Remove any watch listeners.
  silent! autocmd! LiveScriptCompileAuWatch * <buffer>
  " check parameters
  if unwatch
    " when just unwatching, don't compile.
    let b:livescript_compile_watch = 0
    return
  endif
  if watch
    " enable watching
    let b:livescript_compile_watch = 1
  endif
  " using current file extention,
  " determine if extra compilation step is required
  let b:livescript_ext = ''
  if strlen(g:livescript_extra_compiler)
    let b:livescript_ext = expand('%:e')
  endif
  " build the compile buffer if it doesn't exist.
  if bufwinnr(b:livescript_compile_buf) == -1
    let src_buf = bufnr('%')
    let src_win = bufwinnr(src_buf)
    " Create the new window and resize it.
    if vert
      let width = size ? size : winwidth(src_win) / 2
      belowright vertical new
      exec 'vertical resize' width
    else
      " Try to guess the compiled output's height.
      let height = size ? size : min([winheight(src_win) / 2,
      \                               a:endline - a:startline + 5])

      belowright new
      exec 'resize' height
    endif
    " We're now in the scratch buffer, so set it up.
    setlocal bufhidden=wipe buftype=nofile
    setlocal nobuflisted nomodifiable noswapfile nowrap
    autocmd BufWipeout <buffer> call s:LiveScriptCompileClose()
    " Save the cursor when leaving the compile buffer.
    autocmd BufLeave <buffer> let b:livescript_compile_pos = getpos('.')
    nnoremap <buffer> <silent> q :hide<CR>
    let b:livescript_compile_src_buf = src_buf
    let buf = bufnr('%')
    " Go back to the source buffer and set it up.
    exec bufwinnr(b:livescript_compile_src_buf) 'wincmd w'
    let b:livescript_compile_buf = buf
  endif
  " check watch enabled
  if b:livescript_compile_watch
    call s:LiveScriptCompileWatchUpdate(b:livescript_ext)
    augroup LiveScriptCompileAuWatch
      autocmd InsertLeave <buffer> call s:LiveScriptCompileWatchUpdate(b:livescript_ext)
      autocmd BufWritePost <buffer> call s:LiveScriptCompileWatchUpdate(b:livescript_ext)
    augroup END
  else
    call s:LiveScriptCompileUpdate(a:startline, a:endline, b:livescript_ext)
  endif
  " }}}
endfunction

" completes arguments for the LiveScriptCompile command.
function! s:LiveScriptCompileComplete(arg, cmdline, cursor)
  " {{{
  let args = ['unwatch', 'vertical', 'watch']

  if !len(a:arg)
    return args
  endif

  let match = '^' . a:arg

  for arg in args
    if arg =~ match
      return [arg]
    endif
  endfor
  " }}}
endfunction

" don't overwrite the CoffeeCompile variables.
if !exists("s:livescript_compile_buf")
  call s:LiveScriptCompileResetVars()
endif
" create commands
" compiles some LiveScript
command! -range=% -bar -nargs=* -complete=customlist,s:LiveScriptCompileComplete
\        LiveScriptCompile call s:LiveScriptCompile(<line1>, <line2>, <q-args>)
" runs some LiveScript
command! -range=% -bar LiveScriptRun <line1>,<line2>:w !lsc -sp

" editor settings
" vim: fdm=marker ts=2 sw=2 sts=2 nu:
