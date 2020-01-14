scriptencoding utf-8
execute frawor#Setup('0.0', {})
function s:F.setclass(plugdict, fdict, name, ...)
    let g=a:plugdict.g
    call g._f.pyoop.class(a:name, get(g.F.class, a:name, {}),
                \                 get(g.class, a:name, {}),
                \                 a:000)
endfunction
call s:_f.newfeature('setclass', {'cons': remove(s:F, 'setclass')})
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
