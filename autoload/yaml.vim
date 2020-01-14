"{{{1 Первая загрузка
scriptencoding utf-8
execute frawor#Setup('1.0', {'@./dumper': '0.0',
            \                '@./loader': '0.0',
            \              '@/resources': '0.0',})
"{{{1 yaml resource
call s:_f.postresource('yaml', {'loads': s:_r.loader.loads,
            \                'load_all': s:_r.loader.load_all,
            \                   'dumps': s:_r.dumps,})
"{{{1
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8
