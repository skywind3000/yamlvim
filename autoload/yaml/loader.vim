scriptencoding utf-8
execute frawor#Setup('0.0', {'@/resources': '0.0',
            \                  '@./loader': '0.0'})
let s:load={}
function s:load.loads(stream)
    let loader=s:_classes.Loader.new(a:stream)
    return loader.get_single_data()
endfunction
function s:load.load_all(stream)
    let loader=s:_classes.Loader.new(a:stream)
    let r=[]
    while loader.check_data()
        call add(r, loader.get_data())
    endwhile
    return r
endfunction
call s:_f.postresource('loader', remove(s:, 'load'))
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
