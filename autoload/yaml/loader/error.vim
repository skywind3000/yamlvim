scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',})
let s:F.class={'MarkedYAMLError': {}, 'ReaderError': {}}
let s:class={}
let s:_messages={
            \'remessage': 'Unacceptable character #x%04x: “%s” in “%s”, '.
            \             'position %u',
        \}
function s:F.class.MarkedYAMLError.__init__(super, context, context_mark,
            \                              problem, problem_mark, note)
    let self.context=a:context
    let self.context_mark=a:context_mark
    let self.problem=a:problem
    let self.problem_mark=a:problem_mark
    let self.note=a:note
endfunction
function s:F.class.MarkedYAMLError.__str__()
    let lines=[]
    if type(self.context)==type('')
        call add(lines, self.context)
    endif
    if type(self.context_mark)==type({}) &&
                \(type(self.problem)!=type('') ||
                \ type(self.problem_mark)!=type({}) ||
                \ self.context_mark.line!=self.problem_mark.line ||
                \ self.context_mark.column!=self.problem_mark.column)
        call add(lines, self.context_mark.__str__())
    endif
    if type(self.problem)==type('')
        call add(lines, self.problem)
    endif
    if type(self.problem_mark)==type({})
        call add(lines, self.problem_mark.__str__())
    endif
    if type(self.note)==type('')
        call add(lines, self.note)
    endif
    return join(lines, "\n")
endfunction
function s:F.class.ReaderError.__init__(super, name, position, character,
            \                          encoding, reason)
    let self.name=a:name
    let self.position=a:position
    let self.character=a:character
    let self.encoding=a:encoding
    let self.reason=a:reason
endfunction
function s:F.class.ReaderError.__str__()
    return printf(s:_messages.remessage, self.character, self.reason, self.name,
                \                  self.position)
endfunction

call s:_f.setclass('YAMLError', 'Exception')
call s:_f.setclass('ReaderError', 'YAMLError')
call s:_f.setclass('MarkedYAMLError', 'YAMLError')
call s:_f.setclass('ScannerError', 'MarkedYAMLError')
call s:_f.setclass('ParserError', 'MarkedYAMLError')
call s:_f.setclass('ComposerError', 'MarkedYAMLError')
call s:_f.setclass('ConstructorError', 'MarkedYAMLError')
call s:_f.setclass('InternalError', 'MarkedYAMLError')

call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
