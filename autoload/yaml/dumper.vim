"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@/resources': '0.0',
            \                   '@/base64': '0.0',
            \                  '@^regexes': '0.0',})
let s:yaml=s:_r.yaml
let s:typenames=['Number', 'String', 'Funcref', 'List', 'Dictionary', 'Float']
let s:_messages={
            \      'btdump': 'Failed to construct binary with custom tag',
        \}
"{{{1 findobj
function s:F.findobj(obj, r, dumped, opts)
    if type(a:obj)!=type({}) && type(a:obj)!=type([])
        return ''
    endif
    for [line, info] in items(a:dumped)
        if a:obj is info[0]
            if empty(info[1])
                let info[1]='l'.line
                let a:r[line-1].=' &'.info[1]
            endif
            return info[1]
        endif
    endfor
    let a:dumped[len(a:r)]=[a:obj, '']
    return ''
endfunction
"{{{1 dumpnum
function s:F.dumpnum(obj, r, dumped, opts)
    let a:r[-1].=' '.a:obj
    return a:r
endfunction
"{{{1 choose_scalar_style
"{{{2 Стили скаляров:
"   Неблочные:
"       Простой:
"           - "ns-char - c-indicator | [?:-] ns-plain-safe(c)"
"           - "ns-char = nb-char - s-white"
"           - "nb-char = c-printable - b-char - c-byte-order-mark"
"           - "c-printable=x09|x0A|x0D|x20-x7E|x85|xA0-xD7FF|xE000-xFFFD|
"                          x10000-x10FFFF"
"           - "b-char = \r|\n"
"           - "c-byte-order-mark = xFEFF"
"           - "s-white = \t|<SPACE>"
"           - "ns-plain-safe(c) =
"                   c=(flow-out|block-key) => ns-plain-safe-out
"                   c=(flow-in|flow-key)   => ns-plain-safe-in"
"           - "ns-plain-safe-in  = ns-char - c-flow-indicator"
"           - "ns-plain-safe-out = ns-char"
"           - "c-flow-indicator = ,|[|]|{|}"
"           - "ns-plain-char(c) = (ns-plain-safe(c) - : - #) |
"                                 (ns-char #) |
"                                 (: ns-plain-safe(c))"
"       С одинарными кавычками:
"           - "nb-single-char = ''|(nb-json - ')"
"           - "ns-single-char = nb-single-char - s-white"
"           - "nb-json = x09|x20-x10FFFF"
"           - "c-single-quoted(n,c) = ' nb-single-text(n,c) '"
"           - "nb-single-text(n,c) =
"                   c=(flow-out|flow-in)   => nb-single-multi-line(n)
"                   c=(block-key|flow-key) => nb-single-one-line"
"           - "nb-single-one-line = nb-single-char*"
"           - "nb-single-multi-line(n) = nb-ns-single-in-line
"                                        (s-single-next-line(n) | s-white*)"
"           - "nb-ns-single-in-line = (s-white* ns-single-char)*"
"           - "s-single-next-line(n) = s-flow-folded(n)
"                                      (ns-single-char nb-ns-single-in-line
"                                       (s-single-next-line(n) | s-white*))?"
"       С двойными кавычками:
"           - "nb-double-char = c-ns-esc-char | (nb-json - \ - ")"
"           - "ns-double-char = nb-double-char - s-white"
"           - "c-double-quoted(n,c) = " nb-double-text(n,c) ""
"           - "nb-double-text(n,c) =
"                   c=(flow-out|flow-in)   => nb-double-multi-line(n)
"                   c=(block-key|flow-key) => nb-double-one-line"
"           - "nb-double-one-line = nb-double-char*"
"       ...
"}}}2
function s:F.choose_scalar_style(scalar, opts, iskey)
    "{{{2 Пустой скаляр
    if empty(a:scalar)
        " Данный выбор не влияет на читабельность и совместим с 'all_flow'
        return 'double'
    endif
    "{{{2 Объявление переменных
    "{{{3 Возможные стили
    let plain=1
    let double=1
    let single=1
    let literal=1
    let folded=1
    let binary=1
    "{{{3 Запреты на стили
    if get(a:opts, 'all_flow', 0)
        let plain=0
        let single=0
        let literal=0
        let folded=0
    elseif a:iskey
        let literal=0
        let folded=0
    elseif a:scalar=~#'^['.s:yaml.wslbr.']'
        " В соотвестствии со спецификацией, строки, которые начинаются с лишних 
        " пробельных символов, не подвергаются line folding. Запрещаем иметь 
        " folded скаляры, в начале которых находятся пробельные символы, чтобы 
        " не разбираться с возможными проблемами.
        let folded=0
        " Также запрещено в цикле
        let plain=0
    endif
    if a:scalar=~?'\V\^\%(=\|<<\|true\|false\|null\|yes\|no\|on\|off\|~\)\$' ||
                \a:scalar=~#'['.s:yaml.wslbr.']$'
        let plain=0
    endif
    "{{{3 Переменные для цикла
    let i=0                " Смещение текущего символа
    let slen=len(a:scalar) " Длина скаляра
    let prevchar=''        " Предыдущий символ
    let linelen=0          " Длина текущей строки внутри скаляра
    let maxlinelen=0       " Максимальная длина строки внутри скаляра
    let wordlen=0          " Длина текущего слова внутри скаляра
    let maxwordlen=0       " Максимальная длина слова внутри скаляра
    " Следующие переменные нужны для принятие решения о выборе между "scalar" 
    " и 'scalar'
    let numsquote=0        " Количество символов одинарного штриха
    let numbsdq=0          " Количество обратных косых черт и двойных штрихов
    "{{{2 Основной цикл
    while i<slen
        "{{{3 Объявление переменных
        let char=matchstr(a:scalar, '.', i) " Текущий символ
        let lchar=len(char)                 " Его длина в байтах
        "{{{3 Символ является непечатным
        if !s:yaml.isprintchar(char) || (char is# "\u2029" ||
                    \                    char is# "\u2028")
            let plain=0
            let single=0
            let literal=0
            let folded=0
            " Байт не является представлением UTF-8 символа
            if nr2char(char2nr(char))!=#char
                return 'binary'
            endif
        endif
        "{{{3 Допустим «простой» скаляр
        if plain
            " В качестве первого символа простого скаляра недопустимы 
            " символы-индикаторы (за исключением знака вопроса, двоеточия 
            " и дефиса, за которыми не следует пробел). Также запрещаем простому 
            " скаляру начинаться с цифры или точки чтобы не проверять, может ли 
            " он быть прочитан как число
            if i==0
                if ((char=~#'^['.s:yaml.indicator.']$' &&
                            \!(char=~#'^[?:\-]$' &&
                            \  slen>=2 &&
                            \  s:yaml.isnsplainsafechar(
                            \       matchstr(a:scalar, '.', 1)))) ||
                            \!s:yaml.isnsplainsafechar(char)) ||
                            \a:scalar=~#'^[+-]\=[0-9.]'
                    let plain=0
                endif
            " После двоеточия не должен идти пробельный символ
            elseif char is# ':'
                if !s:yaml.isnsplainsafechar(matchstr(a:scalar, '.', i+lchar))
                    let plain=0
                endif
            " Также запретим пробельные символы, за которыми не следуют 
            " непробельные
            elseif !s:yaml.isnsplainsafechar(char) &&
                        \!(char=~#'^['.s:yaml.whitespace.']$' &&
                        \  s:yaml.isnsplainsafechar(
                        \       matchstr(a:scalar,
                        \           '^['.s:yaml.whitespace.']*\zs.',
                        \           i+lchar)))
                let plain=0
            endif
        endif
        "{{{3 Незакавыченные скаляры: простой скаляр и два блочных
        if plain || literal || folded
            " Если есть последовательность, похожая на комментарий, уберём 
            " незакавыченные скаляры
            if char is# '#'
                if prevchar=~#'^['.s:yaml.wslbr.']$'
                    let plain=0
                    let literal=0
                    let folded=0
                endif
            " На всякий случай запретим CR: его могут посчитать новой строкой
            elseif char is# "\r"
                let plain=0
                let literal=0
                let folded=0
            endif
        endif
        "{{{3 'scalar'
        if single
            " Запрещаем символы новой строки: мне неохота возиться с line 
            " folding для этого стиля
            if char=~#'^['.s:yaml.linebreak.']$'
                let single=0
            " Подсчитываем символы «"», «\» и «'»: на основе их количества будет 
            " делаться выбор между 'scalar' и "scalar"
            elseif char==#'"' || char==#'\'
                let numbsdq+=1
            elseif char==#''''
                let numsquote+=1
            endif
        endif
        "{{{3 Обрабатываем конец строки
        if char isnot# "\n"
            let linelen+=1
        else
            if linelen>maxlinelen
                let maxlinelen=linelen
            endif
            let linelen=0
        endif
        "{{{3 Обрабатываем конец слова
        if !(char==#' ' || char==#"\n")
            let wordlen+=1
        else
            if wordlen>maxwordlen
                let maxwordlen=wordlen
            endif
            let wordlen=0
        endif
        "{{{3 Завершение цикла
        let prevchar=char
        let i+=len(char)
    endwhile
    "{{{2 Проверяем длину последей строки и последнего слова
    if linelen>maxlinelen
        let maxlinelen=linelen
    endif
    if wordlen>maxwordlen
        let maxwordlen=wordlen
    endif
    "{{{2 Выбираем стиль на основе собранных данных
    if slen>=80 && literal && maxlinelen<=80 && maxlinelen>=20
        return 'literal'
    elseif slen>=80 && folded && maxwordlen<=80 && maxlinelen>=20
        return 'folded'
    elseif plain && match(a:scalar, '['.s:yaml.whitespace.']$')==-1
        return 'plain'
    elseif single && numbsdq>=numsquote
        return 'single'
    elseif double
        return 'double'
    endif
    return 'binary'
endfunction
"{{{1 str
let s:F.str={}
"{{{2 str.literal
function s:F.str.literal(obj, r, dumped, opts, iskey)
    let indent=matchstr(a:r[-1], '^ *')."  "
    let chomp='+'
    if a:obj!~#'\n$'
        let chomp='-'
    endif
    let iindent=''
    if a:obj=~#'^['.s:yaml.whitespace.']'
        let iindent='2'
    endif
    let a:r[-1].=' |'.chomp.iindent
    let lines=split(a:obj, "\n", 1)
    let last=0
    while empty(lines[-1])
        call remove(lines, -1)
        let last+=1
    endwhile
    call extend(a:r, map(lines, '((empty(v:val))?(""):("'.indent.'")).v:val'))
    call extend(a:r, repeat([''], last-1))
    return a:r
endfunction
"{{{2 str.folded
function s:F.str.folded(obj, r, dumped, opts, iskey)
    let indent=matchstr(a:r[-1], '^ *')."  "
    let chomp='+'
    if a:obj!~#'\n$'
        let chomp='-'
    endif
    let iindent=''
    if a:obj=~#'^['.s:yaml.whitespace.']'
        let iindent='2'
    endif
    let a:r[-1].=' >'.chomp.iindent
    let lines=split(a:obj, "\n", 1)
    let last=0
    while empty(lines[-1])
        call remove(lines, -1)
        let last+=1
    endwhile
    for line in lines
        let llen=len(line)
        if llen>80
            let words=split(line, ' ', 1)
            let line=''
            let llen=0
            let prevempty=0
            for word in words
                let wlen=len(word)
                let llen+=wlen
                if llen>80 && wlen && word[0] isnot# "\t"
                    call add(a:r, indent.line)
                    let line=word
                    let llen=wlen
                else
                    let line.=((empty(line))?(''):(' ')).word
                    let llen+=!empty(line)
                endif
            endfor
            call add(a:r, indent.line)
        else
            call add(a:r, indent.line)
        endif
        call add(a:r, '')
    endfor
    call remove(a:r, -1)
    call extend(a:r, repeat([''], last-1))
    return a:r
endfunction
"{{{2 str.plain
function s:F.str.plain(obj, r, dumped, opts, iskey)
    let a:r[-1].=((a:iskey)?(''):(' ')).a:obj
    return a:r
endfunction
"{{{2 str.single
function s:F.str.single(obj, r, dumped, opts, iskey)
    let a:r[-1].=((a:iskey)?(''):(' ')).string(a:obj)
    return a:r
endfunction
"{{{2 str.double
function s:F.str.double(obj, r, dumped, opts, iskey)
    "{{{3 Объявление переменных
    let a:r[-1].=((a:iskey)?(''):(' ')).'"'
    let indent=substitute(a:r[-1], '.', ' ', 'g')
    let idx=0
    let slen=len(a:obj)
    let curword=''
    let wordlen=0
    let linelen=0
    let prevspace=0
    "{{{3 Представление
    while idx<slen
        " Так мы получим следующий символ без диакритики (а на следующей 
        " итерации получим диакритику без символа).
        let chnr=char2nr(a:obj[(idx):])
        let char=nr2char(chnr)
        let clen=len(char)
        let chkchar=a:obj[(idx):(idx+clen-1)]
        let idx+=clen
        if has_key(s:escrev, char)
            " Экранирование
            let curword.=s:escrev[char]
            let wordlen+=2
        elseif s:yaml.isprintnr(chnr) && !(chnr==0x2029 || chnr==0x2028)
            let curword.=char
            let wordlen+=1
        else
            if chnr<0x100
                let curword.=printf('\x%0.2x', chnr)
                let wordlen+=4
            elseif chnr<0x10000
                let curword.=printf('\u%0.4x', chnr)
                let wordlen+=6
            elseif chnr<0x100000000
                let curword.=printf('\U%0.8x', chnr)
                let wordlen+=10
            else
                let curword.=char
                let wordlen+=1
            endif
        endif
    endwhile
    let a:r[-1].=curword
    let a:r[-1].='"'
    "}}}3
    return a:r
endfunction
"{{{2 str.binary
function s:F.str.binary(obj, r, dumped, opts, iskey)
    if a:r[-1]=~#'!\S*$'
        if a:r[-1]=~#'!!LockedString$'
            let a:r[-1]=substitute(a:r[-1], '!!Locked\zsString$', 'binary', '')
        elseif a:r[-1]=~#'!!\S*$'
            let a:r[-1]=substitute(a:r[-1], '!!\zs\ze\S*$', 'Binary/', '')
        else
            call s:_f.warn('btdump')
        endif
    else
        let a:r[-1].=((a:iskey)?(''):(' ')).'!!binary'
    endif
    let a:r[-1].=' '.s:_r.base64.encode(a:obj)
    return a:r
endfunction
"{{{1 dumpstr
"{{{2 s:escrev
let s:escrev={
            \"\n": '\n',
            \"\\": '\\',
            \"\b": '\b',
            \"\f": '\f',
            \"\r": '\r',
            \"\"": '\"',
        \}
" According to http://www.yaml.org/spec/1.2/spec.html#id2770814, tab is allowed 
" inside quoted strings
            " \"\t": '\t',
"}}}2
function s:F.dumpstr(obj, r, dumped, opts, ...)
    let iskey=!empty(a:000)
    let style=s:F.choose_scalar_style(a:obj, a:opts, iskey)
    return s:F.str[style](a:obj, a:r, a:dumped, a:opts, iskey)
endfunction
"{{{1 dumpfun
function s:F.dumpfun(obj, r, dumped, opts)
    let a:r[-1].=' !!vim/Funcref '.substitute(string(a:obj), 'function(\(.*\))',
                \                             '\1', '')
    return a:r
endfunction
"{{{1 dumplst
function s:F.dumplst(obj, r, dumped, opts)
    if empty(a:obj)
        let a:r[-1].=' []'
        return a:r
    endif
    let indent=matchstr(a:r[-1], '^ *')
    let i=0
    if get(a:opts, 'all_flow', 0)
        call add(a:r, indent.'  [')
    endif
    let d={}
    for d.Item in a:obj
        if get(a:opts, 'all_flow', 0)
            call add(a:r, indent.'    ')
        else
            call add(a:r, indent.'  -')
        endif
        let tobji=type(a:obj[i])
        let islocked=0
        if islocked('a:obj[i]') && get(a:opts, "preserve_locks", 0)
            let a:r[-1].=' !!vim/LockedItem/'
            let islocked=1
        endif
        call s:F.dump(d.Item, a:r, a:dumped, a:opts, islocked)
        unlet d.Item
        if get(a:opts, 'all_flow', 0)
            let a:r[-1].=','
        endif
        let i+=1
    endfor
    if get(a:opts, 'all_flow', 0)
        call add(a:r, indent.'  ]')
    endif
    return a:r
endfunction
"{{{1 dumpdct
function s:F.dumpdct(obj, r, dumped, opts)
    if a:obj=={}
        let a:r[-1].=' {}'
        return a:r
    endif
    let indent=matchstr(a:r[-1], '^ *')
    let keylist=keys(a:obj)
    let d={}
    let d.Sortarg=get(a:opts, 'key_sort', 0)
    if !(type(d.Sortarg)==type(0) && d.Sortarg==0)
        if type(d.Sortarg)==2
            call sort(keylist, d.Sortarg)
        else
            call sort(keylist)
        endif
    endif
    if get(a:opts, 'all_flow', 0)
        call add(a:r, indent.'  {')
    endif
    for key in keylist
        let d.Value=get(a:obj, key)
        if get(a:opts, 'all_flow', 0)
            call add(a:r, indent.'    ')
        else
            call add(a:r, indent.'  ')
        endif
        if islocked('a:obj[key]') && get(a:opts, "preserve_locks", 0)
            let a:r[-1].='!!vim/Locked '
        endif
        call s:F.dump(key, a:r, a:dumped, a:opts, -1, 0)
        let a:r[-1].=':'
        call s:F.dump(d.Value, a:r, a:dumped, a:opts, 0)
        unlet d.Value
        if get(a:opts, 'all_flow', 0)
            let a:r[-1].=','
        endif
    endfor
    if get(a:opts, 'all_flow', 0)
        call add(a:r, indent.'  }')
    endif
    return a:r
endfunction
"{{{1 dumpflt
function s:F.dumpflt(obj, r, dumped, opts)
    let a:r[-1].=' '.substitute(substitute(string(a:obj), 'e\zs\ze\d', '+', ''),
                \               '\ze\(inf\|nan\)', '.', '')
    return a:r
endfunction
"{{{1 dump
"{{{2 s:dumptypes
let s:dumptypes=[s:F.dumpnum, s:F.dumpstr, s:F.dumpfun,
            \    s:F.dumplst, s:F.dumpdct, s:F.dumpflt]
"}}}2
function s:F.dump(obj, r, dumped, opts, islocked, ...)
    let anchor=s:F.findobj(a:obj, a:r, a:dumped, a:opts)
    let iskey=!empty(a:000)
    if !empty(anchor)
        if get(a:opts, 'preserve_locks', 0) && a:r[-1]=~#' !!vim/LockedItem/$'
            let a:r[-1]=substitute(a:r[-1], ' !!vim/LockedItem/$',
                        \' !!vim/LockedAlias '.anchor, '')
            return a:r
        endif
        let a:r[-1].=' *'.anchor
        return a:r
    endif
    let d={}
    let d.Obj=a:obj
    if a:islocked==1
        if islocked('d.Obj')
            let a:r[-1].='Locked'
        endif
        let a:r[-1].=s:typenames[type(d.Obj)]
    elseif a:islocked==0
        let tag=''
        for d.Function in a:opts.custom_tags
            let result=call(d.Function, [d.Obj], {})
            if type(result)==type([]) && len(result)==2 &&
                        \type(result[0])==type('')
                let [tag, d.Obj]=result
                break
            endif
            unlet d.Function result
        endfor
        if empty(tag)
            if get(a:opts, 'preserve_locks', 0)
                let tobj=type(d.Obj)
                if tobj==type([]) || tobj==type({})
                    let a:r[-1].=' !!vim/'.((islocked('d.Obj'))?
                                \               ('Locked'):
                                \               ('')).
                                \s:typenames[tobj]
                endif
            endif
        else
            let a:r[-1].=((iskey)?(' '):('')).tag.
                        \((iskey)?(''):(' '))
        endif
    endif
    call call(s:dumptypes[type(d.Obj)],
                \[d.Obj, a:r, a:dumped, a:opts]+a:000,
                \{})
    return a:r
endfunction
"{{{1 dumps
function s:F.dumps(obj, ...)
    let r=['%YAML 1.2', '---']
    let opts=((a:0>1)?(deepcopy(a:2)):({}))
    if !has_key(opts, 'custom_tags')
        let opts.custom_tags=[]
    endif
    call s:F.dump(a:obj, r, {}, opts, 0)
    if get(opts, 'all_flow', 0)
        call filter(r, 'v:val[-1:] isnot# " "')
    else
        call add(r, '...')
    endif
    return ((a:0)?(a:1):(1)) ? join(r, "\n") : r
endfunction
call s:_f.postresource('dumps', s:F.dumps)
"{{{1
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
