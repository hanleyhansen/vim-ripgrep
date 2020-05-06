if exists('g:loaded_rg') || &cp
  finish
endif

let g:loaded_rg = 1

if !exists('g:rg_binary')
  let g:rg_binary = 'rg'
endif

if !exists('g:rg_format')
  let g:rg_format = "%f:%l:%c:%m"
endif

if !exists('g:rg_command')
  let g:rg_command = g:rg_binary . ' --vimgrep'
endif

if !exists('g:rg_root_types')
  let g:rg_root_types = ['.git']
endif

if !exists('g:rg_window_location')
  let g:rg_window_location = 'botright'
endif

if !exists('g:rg_apply_mappings')
    let g:rg_apply_mappings = 1
endif

fun! s:RgApplyKeyboardShortcuts()
    " inspiration https://github.com/rking/ag.vim/blob/master/autoload/ag.vim

    " edit and exit quickfix
    nnoremap <silent> <buffer> <C-e> <CR><C-w><C-w>:cclose<CR>
    " preview silently
    nnoremap <silent> <buffer> <C-p> <CR>:copen<CR>
    nnoremap <silent> <buffer> <C-o> <CR>:copen<CR>
    " close search list
    nnoremap <silent> <buffer> <C-q> :cclose<CR>

    " new tab
    nnoremap <silent> <buffer> <C-t> <C-w><CR><C-w>T
    " new tab silently (stay focused in quickfix)
    nnoremap <silent> <buffer> <C-s> <C-w><CR><C-w>TgT<C-W><C-W>

    " horizontal split silently (stay focused in quickfix)
    nnoremap <silent> <buffer> <C-h> <C-W><CR><C-w>K<C-w>b

    nnoremap <silent> <buffer> <C-v> :let b:height=winheight(0)<CR><C-w><CR><C-w>H:copen<CR><C-w>J:exe printf(":normal %d\<lt>c-w>_", b:height)<CR>
    " Interpretation:
    " :let b:height=winheight(0)<CR>                      Get the height of the quickfix list window
    " <CR><C-w>                                           Open the current item in a new split
    " <C-w>H                                              Slam the newly opened window against the left edge
    " :copen<CR> -or- :lopen<CR>                          Open either the quickfix window or the location list (whichever we were using)
    " <C-w>J                                              Slam the quickfix list window against the bottom edge
    " :exe printf(":normal %d\<lt>c-w>_", b:height)<CR>   Restore the quickfix list window's height from before we opened the match
endfun

fun! g:RgVisual() range
  call s:RgGrepContext(function('s:RgSearch'), '"' . s:RgGetVisualSelection() . '"')
endfun

fun! s:Rg(txt)
  call s:RgGrepContext(function('s:RgSearch'), s:RgSearchTerm(a:txt))
endfun

fun! s:RgGetVisualSelection()
    " Why is this not a built-in Vim script function?!
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfun

fun! s:RgSearchTerm(txt)
  if empty(a:txt)
    return expand("<cword>")
  else
    return a:txt
  endif
endfun

fun! s:RgSearch(txt)
  let l:rgopts = '--max-columns=1000 '
  if &ignorecase == 1
    let l:rgopts = l:rgopts . '-i '
  endif
  if &smartcase == 1
    let l:rgopts = l:rgopts . '-S '
  endif
  silent! exe 'grep! ' . l:rgopts . a:txt
  if len(getqflist())
    exe g:rg_window_location 'copen'
    redraw!
    if exists('g:rg_highlight')
      call s:RgHighlight(a:txt)
    endif
    if g:rg_apply_mappings
        call s:RgApplyKeyboardShortcuts()
    endif
  else
    cclose
    redraw!
    echo "No match found for " . a:txt
  endif
endfun

fun! s:RgGrepContext(search, txt)
  let l:grepprgb = &grepprg
  let l:grepformatb = &grepformat
  let &grepprg = g:rg_command
  let &grepformat = g:rg_format
  let l:te = &t_te
  let l:ti = &t_ti
  let l:shellpipe_bak=&shellpipe
  set t_te=
  set t_ti=
  if !has("win32")
    let &shellpipe="2>&1 >"
  endif

  if exists('g:rg_derive_root')
    call s:RgPathContext(a:search, a:txt)
  else
    call a:search(a:txt)
  endif

  let &shellpipe=l:shellpipe_bak
  let &t_te=l:te
  let &t_ti=l:ti
  let &grepprg = l:grepprgb
  let &grepformat = l:grepformatb
endfun

fun! s:RgPathContext(search, txt)
  let l:cwdb = getcwd()
  exe 'lcd '.s:RgRootDir()
  call a:search(a:txt)
  exe 'lcd '.l:cwdb
endfun

fun! s:RgHighlight(txt)
  let @/=escape(substitute(a:txt, '"', '', 'g'), '|')
  call feedkeys(":let &hlsearch=1\<CR>", 'n')
endfun

fun! s:RgRootDir()
  let l:cwd = getcwd()
  let l:dirs = split(getcwd(), '/')

  for l:dir in reverse(copy(l:dirs))
    for l:type in g:rg_root_types
      let l:path = s:RgMakePath(l:dirs, l:dir)
      if s:RgHasFile(l:path.'/'.l:type)
        return l:path
      endif
    endfor
  endfor
  return l:cwd
endfun

fun! s:RgMakePath(dirs, dir)
  return '/'.join(a:dirs[0:index(a:dirs, a:dir)], '/')
endfun

fun! s:RgHasFile(path)
  return filereadable(a:path) || isdirectory(a:path)
endfun

fun! s:RgShowRoot()
  if exists('g:rg_derive_root')
    echo s:RgRootDir()
  else
    echo getcwd()
  endif
endfun

command! -nargs=* -complete=file Rg :call s:Rg(<q-args>)
command! -complete=file RgRoot :call s:RgShowRoot()
