"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',
            \       '@%yaml/regexes': '0.0',})
let s:yaml=s:_r.yaml
let s:F.class={'Reader': {}, 'Mark': {}}
let s:class={}
let s:_messages={
            \       'inutf': 'not a utf-8 character',
            \        'spna': 'special characters are not allowed',
            \ 'markmessage': '  in “%s”, line %u, column %u',
            \       'nprnt': 'non-printable unicode characters are not allowed',
        \}
"{{{1 load.Reader
"{{{2 load.Reader.__init__ :: (stream) -> _
function s:F.class.Reader.__init__(super, stream)
    let self.name='' " = None
    let self.stream='' " = None
    let self.stream_pointer=0
    let self.eof=1 " :: Bool
    let self.buffer=[]
    let self.pointer=0
    let self.raw_buffer=0 " = None
    " self.raw_decode :: (String, Bool) -> ([ Char ], Maybe UInt)
    " Bool: self.eof (?)
    " String: List of raw characters
    " Maybe UInt: UInt or negative number. -(1+negative number) indicates an
    "                                      index of invalid character
    " Char: List of decoded characters
    let self.raw_decode=0 " = None
    let self.encoding='' " = None
    let self.index=0 " = None
    let self.raw_index=0
    let self.line=0
    let self.column=0

    let self.stream=a:stream
    let self.name='<unicode string>'
    let self.eof=0
    let self.raw_buffer=''
    " self.check_printable(a:stream)
    " let self.buffer=split(a:stream, '\zs')
endfunction
"{{{2 load.Reader.get_mark :: (self + ()) -> mark
function s:F.class.Reader.get_mark()
    return s:_classes.Mark.new(self.name, self.index, self.line, self.column,
                    \          self.buffer, self.pointer)
endfunction
"{{{2 load.Reader.update_raw (self + ([UInt])) -> _
function s:F.class.Reader.update_raw(...)
    let size=128
    if !empty(a:000)
        let size=a:000[0]
    endif
    " self.read(size)
    let data=matchstr(self.stream, '^.\{0,'.size.'}', self.stream_pointer)
    let self.raw_buffer.=data
    let self.stream_pointer+=len(data)
    if empty(data)
        let self.eof=1
    endif
endfunction
"{{{2 load.Reader.update (self + (UInt)) -> _
function s:F.class.Reader.update(length)
    let selfname='Reader.update'
    if type(self.raw_buffer)!=type('')
        return
    endif
    let self.buffer=self.buffer[(self.pointer):]
    let self.pointer=0
    while len(self.buffer)<a:length
        if !self.eof
            call self.update_raw()
        endif
        if type(self.raw_decode)==2
            let [data, converted]=call(self.raw_decode, [self.raw_buffer,
                        \                                self.eof], {})
            if converted<0
                let estart=(-(converted+1))
                let character=self.raw_buffer[(estart):]
                if !empty(self.stream)
                    " XXX this probably cannot determine true position
                    let position=self.stream_pointer-len(self.raw_buffer)+estart
                else
                    let position=estart
                endif
                call self.__raise('Reader', self.name, position,
                            \     char2nr(character), 'utf-8', '')
            endif
            call self.check_printable(data)
            let self.raw_buffer=self.raw_buffer[(converted):]
        else
            let data=[]
            let position=self.index+(len(self.buffer)-self.pointer)
            while !empty(self.raw_buffer)
                let nr=char2nr(self.raw_buffer)
                let ch=nr2char(nr)
                let lch=len(ch)
                if self.raw_buffer[:(lch-1)]!=#ch
                    let position=self.index+
                                \(len(self.buffer)-self.pointer)+
                                \index
                    call self.__raise('Reader', self.name, position,
                                \               char2nr(ch), 'utf-8',
                                \               s:_messages.inutf)
                elseif position==0 && nr==0xFEFF
                    " pass: BOM is allowed
                elseif !s:yaml.isprintnr(nr)
                    call self.__raise('Reader', self.name, position,
                                \               char2nr(ch), 'utf-8',
                                \               s:_messages.nprnt)
                endif
                call add(data, ch)
                let position+=1
                let self.raw_buffer=self.raw_buffer[(lch):]
            endwhile
        endif
        let self.buffer+=data
        if self.eof
            call add(self.buffer, '')
            let self.raw_buffer=''
            break
        endif
    endwhile
endfunction
"{{{2 load.Reader.peek :: (self + ([UInt])) -> Maybe Char
function s:F.class.Reader.peek(...)
    if empty(a:000)
        let index=0
    else
        let index=a:000[0]
    endif
    let idx=self.pointer+index
    if idx<len(self.buffer)
        return self.buffer[idx]
    else
        call self.update(index+1)
        return get(self.buffer, self.pointer+index, '')
    endif
endfunction
"{{{2 load.Reader.prefix :: (self + ([UInt])) -> String
function s:F.class.Reader.prefix(...)
    let length=1
    if !empty(a:000)
        let length=a:000[0]
    endif
    if (self.pointer+length)>=len(self.buffer)
        call self.update(length)
    endif
    return join(self.buffer[(self.pointer):(self.pointer+length-1)], '')
endfunction
"{{{2 load.Reader.forward :: (self + ([UInt])) -> _
function s:F.class.Reader.forward(...)
    let length=1
    if !empty(a:000)
        let length=a:000[0]
    endif
    if (self.pointer+length+1)>=len(self.buffer)
        call self.update(length+1)
    endif
    while length
        let ch=self.buffer[self.pointer]
        let self.pointer+=1
        let self.index+=1
        let self.raw_index+=len(ch)
        if ch is# "\n" || (ch is# "\r" && self.buffer[self.pointer] isnot# "\n")
            let self.line+=1
            let self.column=0
        elseif ch isnot# "\uFEFF" " XXX BOM
            let self.column+=1
        endif
        let length-=1
    endwhile
endfunction
"{{{2 load.Reader.check_printable :: (self + ([ Char ])) -> _
function s:F.class.Reader.check_printable(data)
    let selfname='Reader.check_printable'
    let position=self.index+(len(self.buffer)-self.pointer)
    for ch in a:data
        if !empty(ch) && !s:yaml.isprintchar(ch) && !(position==0 &&
                    \                                   ch is# "\uFEFF")
            call self.__raise('Reader', self.name, position, char2nr(ch),
                        \     'utf-8', s:_messages.spna)
        endif
        let position+=1
    endfor
endfunction
"{{{1 load.Mark
"{{{2 load.Mark.__init__
function s:F.class.Mark.__init__(super, name, index, line, column, buffer,
            \                   pointer)
    let self.name=a:name
    let self.index=a:index
    let self.line=a:line
    let self.column=a:column
    let self.buffer=copy(a:buffer)
    let self.pointer=a:pointer
endfunction
"{{{2 load.Mark.get_snippet
function s:F.class.Mark.get_snippet(...)
    let indent=get(a:000, 0, 4)
    let max_length=get(a:000, 1, &columns)
    if empty(self.buffer)
        return ''
    endif
    let head=''
    let start=self.pointer
    while start>0 &&
                \get(self.buffer, start-1, '')!~#'^['.s:yaml.linebreak.']\=$'
        let start-=1
        if self.pointer-start > max_length/2-1
            let head=' ... '
            let start+=5
            break
        endif
    endwhile
    let tail=''
    let end=self.pointer
    let lbuffer=len(self.buffer)
    while end<lbuffer &&
                \get(self.buffer, end, '')!~#'^['.s:yaml.linebreak.']\=$'
        let end+=1
        if end-self.pointer > max_length/2-1
            let tail=' ... '
            let end-=5
            break
        endif
    endwhile
    let snippet=join(self.buffer[(start):(end-1)], '')
    return repeat(' ', indent).head.snippet.tail."\n".
                \repeat(' ', indent+self.pointer-start+len(head)).'^'
endfunction
"{{{2 load.Mark.__str__
function s:F.class.Mark.__str__()
    let snippet=self.get_snippet()
    let where=printf(s:_messages.markmessage, self.name, self.line+1,
                \                             self.column+1)
    if !empty(snippet)
        let where.=":\n".snippet
    endif
    return where
endfunction
"{{{1 
call s:_f.setclass('Reader')
call s:_f.setclass('Mark')
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
