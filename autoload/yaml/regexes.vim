"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@/resources': '0.0',})
"}}}1
let s:yaml={}
let s:yaml._undef=''
let s:yaml._true=1
let s:yaml._false=0
let s:yaml._null=s:yaml._undef
" http://www.yaml.org/spec/1.2/spec.html#c-printable
let s:yaml.printable='\x09\x0A\x0D\x20-\x7E'.
            \'\u0085\u00A0-\uD7FF\uE000-\uFFFD'.
            \'\U10000-\U10FFFF'
let s:yaml.printchar='['.s:yaml.printable.']'
" Vim does not support too wide unicode character ranges, waiting for a patch
if 1
    let s:yaml.printable='\x09\x0A\x0D\x20-\x7E'
    let s:yaml.printchar='\%(\p\|[\x09\x0A\x0D]\|\%u0085\)'
endif
" http://www.yaml.org/spec/1.2/spec.html#c-flow-indicator
let s:yaml.flowindicator='[\]{},'
" http://www.yaml.org/spec/1.2/spec.html#s-white
let s:yaml.whitespace='\t '
" http://www.yaml.org/spec/1.2/spec.html#b-char
let s:yaml.linebreak='\x0A\x0D'
            " \"SEPREGEX": '^[ \t\r\n\x85\u2028\u2029]\=$',
let s:yaml.wslbr=(s:yaml.whitespace).(s:yaml.linebreak)
" http://www.yaml.org/spec/1.2/spec.html#c-comment
let s:yaml.comment='#'
" http://www.yaml.org/spec/1.2/spec.html#ns-word-char
let s:yaml.nsword='0-9a-zA-Z\-'

let s:yaml.mappingkey='?'
let s:yaml.mappingvalue=':'
let s:yaml.sequenceentry='\-'
let s:yaml.directivestart='%'
let s:yaml.aliasstart='*'
let s:yaml.anchorstart='&'
" http://www.yaml.org/spec/1.2/spec.html#c-indicator
let s:yaml.indicator='\-?:,[\]{}#&*!|>''"%@`'
" http://www.yaml.org/spec/1.2/spec.html#ns-char
let s:yaml.nschar='\%(['.(s:yaml.wslbr).']\@!'.
            \(s:yaml.printchar).'\)'
" http://www.yaml.org/spec/1.2/spec.html#ns-directive-name
let s:yaml.nsdirectivenamereg=s:yaml.nschar.'\+'
" http://www.yaml.org/spec/1.2/spec.html#ns-uri-char
let s:yaml.nsurichar='\%(%\x\x\|['.s:yaml.nsword.
            \                     '#;/?:@&=+$,_.!~*''()[\]]\)'
" http://www.yaml.org/spec/1.2/spec.html#ns-tag-char
let s:yaml.nstagreg='\%(%\x\x\|['.s:yaml.nsword.'#;/?:@&=+$,_.~*''()]\)'
let s:yaml.nstag=s:yaml.nsword.'%#;/?:@&=+$,_.~*''()'
" http://www.yaml.org/spec/1.2/spec.html#ns-anchor-char
let s:yaml.anchorchar='\%(['.(s:yaml.flowindicator).
            \                  (s:yaml.wslbr).']\@!'.
            \           s:yaml.printchar.'\)'
" http://www.yaml.org/spec/1.2/spec.html#ns-plain-safe(c)
let s:yaml.nsplainsafechar='\%(['.s:yaml.flowindicator.']\@!'.
            \                    s:yaml.nschar.'\)'
"{{{1 yaml.isprintnr
function s:yaml.isprintnr(chnr)
    return (a:chnr==0x09 || a:chnr==0x0A || a:chnr==0x0D || a:chnr==0x85 ||
                \(   0x20<=a:chnr && a:chnr<=0x00007E) ||
                \(   0xA0<=a:chnr && a:chnr<=0x00D7FF) ||
                \( 0xE000<=a:chnr && a:chnr<=0x00FFFD) ||
                \(0x10000<=a:chnr && a:chnr<=0x10FFFF))
endfunction
"{{{1 comm.isprintchar
function s:yaml.isprintchar(ch)
    let chnr=char2nr(a:ch)
    if nr2char(chnr)!=#a:ch
        return 0
    endif
    return s:yaml.isprintnr(chnr)
endfunction
"{{{1 comm.is*char
let s:excludeprint=[
            \   ['ns',           s:yaml.wslbr],
            \   ['anchor',      (s:yaml.flowindicator).(s:yaml.wslbr)],
            \   ['nsplainsafe', (s:yaml.flowindicator).(s:yaml.wslbr)],
            \]
for [s:funcname, s:excluderegex] in s:excludeprint
    execute      'function s:yaml.is'.s:funcname."char(ch)\n".
                \"    if a:ch=~#'^[".s:excluderegex."]$'\n".
                \"        return 0\n".
                \"    endif\n".
                \"    return s:yaml.isprintchar(a:ch)\n".
                \'endfunction'
    unlet s:funcname s:excluderegex
endfor
unlet s:excludeprint
"{{{1 
call s:_f.postresource('yaml', s:yaml)
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
