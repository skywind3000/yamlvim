"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',})
let s:F.class={'Parser':               {},
            \  'StreamStartEvent':     {},
            \  'DocumentStartEvent':   {},
            \  'DocumentEndEvent':     {},
            \  'ScalarEvent':          {},
            \  'CollectionStartEvent': {},
            \  'NodeEvent':            {},
            \  'Event':                {},
            \}
" event: { "type": (...), "implicit": ?, "start_mark": mark, "end_mark": mark }
" event.AliasEvent: +{ "anchor": String }
" event.MappingStart: +{ "flow_style": Bool }
" event.SequenceStart: +{ "flow_style": Bool }
" event.Scalar: +{ "value": ?, "style": ? }
" state: event
let s:class={'Parser': {
            \    'DEFAULT_TAGS': {
            \       '!':  '!',
            \       '!!': 'tag:yaml.org,2002:',
            \    },
            \},
        \}
"{{{1 События
"{{{2 load.Event.__init__
function s:F.class.Event.__init__(super, start_mark, end_mark)
    let self.start_mark=a:start_mark
    let self.end_mark=a:end_mark
endfunction
"{{{2 load.NodeEvent.__init__
function s:F.class.NodeEvent.__init__(super, anchor, start_mark, end_mark)
    let self.start_mark=a:start_mark
    let self.end_mark=a:end_mark
    let self.anchor=a:anchor
endfunction
"{{{2 load.DocumentStartEvent.__init__
function s:F.class.DocumentStartEvent.__init__(super, start_mark, end_mark,
            \                                 explicit, version, tags)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.explicit=a:explicit
    let self.version=a:version
    let self.tags=a:tags
endfunction
"{{{2 load.ScalarEvent.__init__
function s:F.class.ScalarEvent.__init__(super, anchor, tag, implicit, value,
            \                          start_mark, end_mark, style)
    call call(a:super.__init__, [0, a:anchor, a:start_mark, a:end_mark], self)
    let self.tag=a:tag
    let self.implicit=a:implicit
    let self.value=a:value
    let self.style=a:style
endfunction
"{{{2 load.DocumentEndEvent.__init__
function s:F.class.DocumentEndEvent.__init__(super, start_mark, end_mark,
            \                               explicit)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.explicit=a:explicit
endfunction
"{{{2 load.StreamStartEvent.__init__
function s:F.class.StreamStartEvent.__init__(super, start_mark, end_mark,
            \                               encoding)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.encoding=a:encoding
endfunction
"{{{2 load.CollectionStartEvent.__init__
function s:F.class.CollectionStartEvent.__init__(super, anchor, tag, implicit,
            \                                   start_mark, end_mark,
            \                                   flow_style)
    let self.anchor=a:anchor
    let self.tag=a:tag
    let self.implicit=a:implicit
    let self.start_mark=a:start_mark
    let self.end_mark=a:end_mark
    let self.flow_style=a:flow_style
endfunction
"{{{1 load.Parser
"{{{2 load.Parser.__init__ :: () -> _
function s:F.class.Parser.__init__(super)
    " let self.current_event={} " = None
    let self.yaml_version=[] " = None
    let self.tag_handles={}
    let self.states=[]
    let self.marks=[]
    let self.state=self.parse_stream_start
endfunction
"{{{2 load.Parser.set_current_event
function s:F.class.Parser.set_current_event()
    if !has_key(self, 'current_event')
        if type(self.state)==2
            let self.current_event=self.state()
        else
            let self.current_event=s:_classes.None.new()
        endif
    endif
endfunction
"{{{2 load.Parser.check_event :: (self + (Class*)) -> Bool
function s:F.class.Parser.check_event(...)
    call self.set_current_event()
    if has_key(self, 'current_event') &&
                \self.current_event.__class__.name isnot# 'None'
        if empty(a:000)
            return 1
        endif
        for choice in a:000
            if self.current_event.__class__.name is# choice
                return 1
            endif
        endfor
    endif
    return 0
endfunction
"{{{2 load.Parser.peek_event :: (self + ()) -> event
function s:F.class.Parser.peek_event()
    call self.set_current_event()
    return self.current_event
endfunction
"{{{2 load.Parser.get_event :: (self + ()) -> event
function s:F.class.Parser.get_event()
    call self.set_current_event()
    let value=self.current_event
    unlet self.current_event
    return value
endfunction
"{{{2 load.Parser.parse_stream_start :: (self + ()) -> event
function s:F.class.Parser.parse_stream_start()
    let token=self.get_token()
    let event=s:_classes.StreamStartEvent.new(token.start_mark, token.end_mark,
                \                             token.encoding)
    let self.state=self.parse_implicit_document_start
    return event
endfunction
"{{{2 load.Parser.parse_implicit_document_start :: (self + ()) -> state
function s:F.class.Parser.parse_implicit_document_start()
    if !self.check_token('DirectiveToken', 'DocumentStartToken',
                \        'StreamEndToken')
        let self.tag_handles=copy(self.DEFAULT_TAGS)
        let token=self.peek_token()
        let start_mark=token.start_mark
        let end_mark=start_mark
        let event=s:_classes.DocumentStartEvent.new(start_mark, end_mark, 0, [],
                    \                               [])
        call add(self.states, self.parse_document_end)
        let self.state=self.parse_block_node
        return event
    else
        return self.parse_document_start()
    endif
endfunction
"{{{2 load.Parser.parse_document_start :: (self + ()) -> state
function s:F.class.Parser.parse_document_start()
    let selfname='Parser.parse_document_start'
    while self.check_token('DocumentEndToken')
        call self.get_token()
    endwhile
    if !self.check_token('StreamEndToken')
        let token=self.peek_token()
        let start_mark=token.start_mark
        let [version_, tags]=self.process_directives()
        if !self.check_token('DocumentStartToken')
            call self._raise(selfname, 'Parser',
                        \['ndocstart', self.peek_token().__class__.name], 0,
                        \self.peek_token().start_mark)
        endif
        let token=self.get_token()
        let end_mark=token.end_mark
        let event=s:_classes.DocumentStartEvent.new(start_mark, end_mark, 1,
                    \                               version_, tags)
        call add(self.states, self.parse_document_end)
        let self.state=self.parse_document_content
    else
        let token=self.get_token()
        let event=s:_classes.StreamEndEvent.new(token.start_mark,token.end_mark)
        " assert not self.states
        " assert not self.marks
        let self.state=0
    endif
    return event
endfunction
"{{{2 load.Parser.parse_document_end :: (self + ()) -> state
function s:F.class.Parser.parse_document_end()
    let token=self.peek_token()
    let start_mark=token.start_mark
    let end_mark=start_mark
    let explicit=0
    if self.check_token('DocumentEndToken')
        let token=self.get_token()
        let end_mark=token.end_mark
        let explicit=1
    endif
    let event=s:_classes.DocumentEndEvent.new(start_mark, end_mark, explicit)
    let self.state=self.parse_document_start
    return event
endfunction
"{{{2 load.Parser.parse_document_content :: (self + ()) -> state
function s:F.class.Parser.parse_document_content()
    let selfname='Parser.parse_document_content'
    if self.check_token('DirectiveToken', 'DocumentStartToken',
                \       'DocumentEndToken', 'StreamEndToken')
        let event=self.process_empty_scalar(self.peek_token().start_mark)
        let self.state=remove(self.states, -1)
        return event
    else
        return self.parse_block_node()
    endif
endfunction
"{{{2 load.Parser.process_directives :: (self + ()) -> (version, tags)
function s:F.class.Parser.process_directives()
    let selfname='Parser.process_directives'
    let self.yaml_version=[] " = None
    let self.tag_handles={}
    while self.check_token('DirectiveToken')
        let token=self.get_token()
        if token.name is# 'YAML'
            if !empty(self.yaml_version)
                call self._raise(selfname, 'Parser', 'multYAML', 0,
                            \    token.start_mark)
            endif
            let [major, minor]=token.value
            if major!=1
                call self._raise(selfname, 'Parser', ['majmis', major], 0,
                            \    token.start_mark)
            endif
            let self.yaml_version=token.value
        elseif token.name is# 'TAG'
            let [handle, prefix]=token.value
            if has_key(self.tag_handles, handle)
                call self._raise(selfname, 'Parser', ['duptag', handle], 0,
                            \    token.start_mark)
            endif
            let self.tag_handles[handle]=prefix
        endif
    endwhile
    let value=[self.yaml_version, copy(self.tag_handles)]
    call extend(self.tag_handles, self.DEFAULT_TAGS, 'keep')
    return value
endfunction
"{{{2 load.Parser.parse_block_node :: (self + ()) -> state
function s:F.class.Parser.parse_block_node()
    return self.parse_node(1, 0)
endfunction
"{{{2 load.Parser.parse_flow_node
function s:F.class.Parser.parse_flow_node()
    return self.parse_node(0, 0)
endfunction
"{{{2 load.Parser.parse_block_node_or_indentless_sequence
function s:F.class.Parser.parse_block_node_or_indentless_sequence()
    return self.parse_node(1, 1)
endfunction
"{{{2 load.Parser.parse_node :: (self + (Bool, Bool)) -> state
function s:F.class.Parser.parse_node(block, indentless_sequence)
    let selfname='Parser.parse_node'
    if self.check_token('AliasToken')
        let token=self.get_token()
        let event=s:_classes.AliasEvent.new(token.value, token.start_mark,
                    \                       token.end_mark)
        let self.state=remove(self.states, -1)
    else
        let anchor=''     " = None
        let tag=[]        " = None
        let start_mark={} " = None
        let end_mark={}   " = None
        let tag_mark={}   " = None
        if self.check_token('AnchorToken')
            let token=self.get_token()
            let start_mark=token.start_mark
            let end_mark=token.end_mark
            let anchor=token.value
            if self.check_token('TagToken')
                let token=self.get_token()
                let tag_mark=token.start_mark
                let end_mark=token.end_mark
                let tag=token.value
            endif
        elseif self.check_token('TagToken')
            let token=self.get_token()
            let start_mark=token.start_mark
            let end_mark=token.end_mark
            let tag=token.value
            if self.check_token('AnchorToken')
                let token=self.get_token()
                let end_mark=token.end_mark
                let anchor=token.value
            endif
        endif
        if !empty(tag)
            let [handle, suffix]=tag
            unlet tag
            if !empty(handle)
                if !has_key(self.tag_handles, handle)
                    call self._raise(selfname, 'Parser', ['ukntag', handle],
                                \    start_mark, tag_mark)
                endif
                let tag=(self.tag_handles[handle]).suffix
            else
                let tag=suffix
            endif
        else
            unlet tag
            let tag=''
        endif
        if start_mark=={}
            let start_mark=self.peek_token().start_mark
            let end_mark=start_mark
        endif
        let event={} " = None
        let implicit=(empty(tag)||(tag is# '!'))
        if a:indentless_sequence && self.check_token('BlockEntryToken')
            let end_mark=self.peek_token().end_mark
            let event=s:_classes.SequenceStartEvent.new(anchor, tag, implicit,
                        \                               start_mark, end_mark, 0)
            let self.state=self.parse_indentless_sequence_entry
        else
            if self.check_token('ScalarToken')
                let token=self.get_token()
                let end_mark=token.end_mark
                unlet implicit
                if (token.plain && empty(tag)) || tag is# '!'
                    let implicit=[1, 0]
                elseif empty(tag)
                    let implicit=[0, 1]
                else
                    let implicit=[0, 0]
                endif
                let event=s:_classes.ScalarEvent.new(anchor, tag, implicit,
                            \                        token.value, start_mark,
                            \                        end_mark, token.style)
                let self.state=remove(self.states, -1)
            elseif self.check_token('FlowSequenceStartToken')
                let end_mark=self.peek_token().end_mark
                let event=s:_classes.SequenceStartEvent.new(anchor, tag,
                            \                               implicit,
                            \                               start_mark,
                            \                               end_mark, 1)
                let self.state=self.parse_flow_sequence_first_entry
            elseif self.check_token('FlowMappingStartToken')
                let end_mark=self.peek_token().end_mark
                let event=s:_classes.MappingStartEvent.new(anchor, tag,
                            \                              implicit, start_mark,
                            \                              end_mark, 1)
                let self.state=self.parse_flow_mapping_first_key
            elseif a:block && self.check_token('BlockSequenceStartToken')
                let end_mark=self.peek_token().end_mark
                let event=s:_classes.SequenceStartEvent.new(anchor, tag,
                            \                               implicit,
                            \                               start_mark,
                            \                               end_mark, 0)
                let self.state=self.parse_block_sequence_first_entry
            elseif a:block && self.check_token('BlockMappingStartToken')
                let end_mark=self.peek_token().end_mark
                let event=s:_classes.MappingStartEvent.new(anchor, tag,
                            \                              implicit, start_mark,
                            \                              end_mark, 0)
                let self.state=self.parse_block_mapping_first_key
            elseif !empty(anchor) || !empty(tag)
                let event=s:_classes.ScalarEvent.new(anchor, tag, [implicit, 0],
                            \                        '', start_mark, end_mark,
                            \                        '')
                let self.state=remove(self.states, -1)
            else
                let token=self.peek_token()
                if a:block
                    call self._raise(selfname, 'Parser',
                                \    ['emptblock', token.__class__.name], 0,
                                \    token.start_mark)
                else
                    call self._raise(selfname, 'Parser',
                                \    ['emptyflow', token.__class__.name], 0,
                                \    token.start_mark)
                endif
            endif
        endif
    endif
    return event
endfunction
"{{{2 load.Parser.parse_indentless_sequence_entry
function s:F.class.Parser.parse_indentless_sequence_entry()
    if self.check_token('BlockEntryToken')
        let token=self.get_token()
        if !self.check_token('BlockEntryToken', 'KeyToken', 'ValueToken',
                    \        'BlockEndToken')
            call add(self.states, self.parse_indentless_sequence_entry)
            return self.parse_block_node()
        else
            let self.state=self.parse_indentless_sequence_entry
            return self.process_empty_scalar(token.end_mark)
        endif
    endif
    let token=self.peek_token()
    let event=s:_classes.SequenceEndEvent.new(token.start_mark, token.end_mark)
    let self.state=remove(self.states, -1)
    return event
endfunction
"{{{2 load.Parser.parse_block_sequence_entry
function s:F.class.Parser.parse_block_sequence_entry()
    let selfname='Parser.parse_block_sequence_entry'
    if self.check_token('BlockEntryToken')
        let token=self.get_token()
        if !self.check_token('BlockEntryToken', 'BlockEndToken')
            call add(self.states, self.parse_block_sequence_entry)
            return self.parse_block_node()
        else
            let self.state=self.parse_block_sequence_entry
            return self.process_empty_scalar(token.end_mark)
        endif
    endif
    if !self.check_token('BlockEndToken')
        let token=self.peek_token()
        call self._raise(selfname, 'Parser', ['nblkend', token.__class__.name],
                    \    self.marks[-1], token.start_mark)
    endif
    let token=self.get_token()
    let event=s:_classes.SequenceEndEvent.new(token.start_mark, token.end_mark)
    let self.state=remove(self.states, -1)
    call remove(self.marks, -1)
    return event
endfunction
"{{{2 load.Parser.parse_block_sequence_first_entry
function s:F.class.Parser.parse_block_sequence_first_entry()
    let token=self.get_token()
    call add(self.marks, token.start_mark)
    return self.parse_block_sequence_entry()
endfunction
"{{{2 load.Parser.parse_block_mapping_key
function s:F.class.Parser.parse_block_mapping_key()
    let selfname='Parser.parse_block_mapping_key'
    if self.check_token('KeyToken')
        let token=self.get_token()
        if !self.check_token('KeyToken', 'ValueToken', 'BlockEndToken')
            call add(self.states, self.parse_block_mapping_value)
            return self.parse_block_node_or_indentless_sequence()
        else
            let self.state=self.parse_block_mapping_value
            return self.process_empty_scalar(token.end_mark)
        endif
    endif
    if !self.check_token('BlockEndToken')
        let token=self.peek_token()
        call self._raise(selfname, 'Parser', ['nblkmend', token.__class__.name],
                    \    self.marks[-1], token.start_mark)
    endif
    let token=self.get_token()
    let event=s:_classes.MappingEndEvent.new(token.start_mark, token.end_mark)
    let self.state=remove(self.states, -1)
    call remove(self.marks, -1)
    return event
endfunction
"{{{2 load.Parser.parse_block_mapping_value
function s:F.class.Parser.parse_block_mapping_value()
    if self.check_token('ValueToken')
        let token=self.get_token()
        if !self.check_token('KeyToken', 'ValueToken', 'BlockEndToken')
            call add(self.states, self.parse_block_mapping_key)
            return self.parse_block_node_or_indentless_sequence()
        else
            let self.state=self.parse_block_mapping_key
            return self.process_empty_scalar(token.end_mark)
        endif
    else
        let self.state=self.parse_block_mapping_key
        let token=self.peek_token()
        return self.process_empty_scalar(token.start_mark)
    endif
endfunction
"{{{2 load.Parser.parse_block_mapping_first_key
function s:F.class.Parser.parse_block_mapping_first_key()
    let token=self.get_token()
    call add(self.marks, token.start_mark)
    return self.parse_block_mapping_key()
endfunction
"{{{2 load.Parser.parse_flow_sequence_first_entry
function s:F.class.Parser.parse_flow_sequence_first_entry()
    let token=self.get_token()
    call add(self.marks, token.start_mark)
    return self.parse_flow_sequence_entry(1)
endfunction
"{{{2 load.Parser.parse_flow_sequence_entry (self + ([Bool])) -> state
function s:F.class.Parser.parse_flow_sequence_entry(...)
    let selfname='Parser.parse_flow_sequence_entry'
    let first=get(a:000, 0, 0)
    if !self.check_token('FlowSequenceEndToken')
        if !first
            if self.check_token('FlowEntryToken')
                call self.get_token()
            else
                let token=self.peek_token()
                call self._raise(selfname, 'Parser',
                            \    ['nflwseq', token.__class__.name],
                            \    self.marks[-1], token.start_mark)
            endif
        endif
        if self.check_token('KeyToken')
            let token=self.peek_token()
            let event=s:_classes.MappingStartEvent.new(0, 0, 1,token.start_mark,
                        \                              token.end_mark, 1)
            let self.state=self.parse_flow_sequence_entry_mapping_key
            return event
        elseif !self.check_token('FlowSequenceEndToken')
            call add(self.states, self.parse_flow_sequence_entry)
            return self.parse_flow_node()
        endif
    endif
    let token=self.get_token()
    let event=s:_classes.SequenceEndEvent.new(token.start_mark, token.end_mark)
    let self.state=remove(self.states, -1)
    call remove(self.marks, -1)
    return event
endfunction
"{{{2 load.Parser.parse_flow_sequence_entry_mapping_key
function s:F.class.Parser.parse_flow_sequence_entry_mapping_key()
    let token=self.get_token()
    if !self.check_token('ValueToken', 'FlowEntryToken', 'FlowSequenceEndToken')
        call add(self.states, self.parse_flow_sequence_entry_mapping_value)
        return self.parse_flow_node()
    else
        let self.state=self.parse_flow_sequence_entry_mapping_value
        return self.process_empty_scalar(token.end_mark)
    endif
endfunction
"{{{2 load.Parser.parse_flow_sequence_entry_mapping_value
function s:F.class.Parser.parse_flow_sequence_entry_mapping_value()
    if self.check_token('ValueToken')
        let token=self.get_token()
        if !self.check_token('FlowEntryToken', 'FlowSequenceEndToken')
            call add(self.states, self.parse_flow_sequence_entry_mapping_end)
            return self.parse_flow_node()
        else
            let self.state=self.parse_flow_sequence_entry_mapping_end
            return self.process_empty_scalar(token.end_mark)
        endif
    else
        let self.state=self.parse_flow_sequence_entry_mapping_end
        let token=self.peek_token()
        return self.process_empty_scalar(token.start_mark)
    endif
endfunction
"{{{2 load.Parser.parse_flow_sequence_entry_mapping_end
function s:F.class.Parser.parse_flow_sequence_entry_mapping_end()
    let self.state=self.parse_flow_sequence_entry
    let token=self.peek_token()
    return s:_classes.MappingEndEvent.new(token.start_mark, token.end_mark)
endfunction
"{{{2 load.Parser.parse_flow_mapping_first_key
function s:F.class.Parser.parse_flow_mapping_first_key()
    let token=self.get_token()
    call add(self.marks, token.start_mark)
    return self.parse_flow_mapping_key(1)
endfunction
"{{{2 load.Parser.parse_flow_mapping_key (self + ([Bool])) -> state
function s:F.class.Parser.parse_flow_mapping_key(...)
    let selfname='Parser.parse_flow_mapping_key'
    let first=get(a:000, 0, 0)
    if !self.check_token('FlowMappingEndToken')
        if !first
            if self.check_token('FlowEntryToken')
                call self.get_token()
            else
                let token=self.peek_token()
                call self._raise(selfname, 'Parser',
                            \    ['nflwmap', token.__class__.name],
                            \    self.marks[-1], token.start_mark)
            endif
        endif
        if self.check_token('KeyToken')
            let token=self.get_token()
            if !self.check_token('ValueToken', 'FlowEntryToken',
                        \        'FlowMappingEndToken')
                call add(self.states, self.parse_flow_mapping_value)
                return self.parse_flow_node()
            else
                let self.state=self.parse_flow_mapping_value
                return self.process_empty_scalar(token.end_mark)
            endif
        elseif !self.check_token('FlowMappingEndToken')
            call add(self.states, self.parse_flow_mapping_empty_value)
            return self.parse_flow_node()
        endif
    endif
    let token=self.get_token()
    let event=s:_classes.MappingEndEvent.new(token.start_mark, token.end_mark)
    let self.state=remove(self.states, -1)
    call remove(self.marks, -1)
    return event
endfunction
"{{{2 load.Parser.parse_flow_mapping_value
function s:F.class.Parser.parse_flow_mapping_value()
    if self.check_token('ValueToken')
        let token=self.get_token()
        if !self.check_token('FlowEntryToken', 'FlowMappingEndToken')
            call add(self.states, self.parse_flow_mapping_key)
            return self.parse_flow_node()
        else
            let self.state=self.parse_flow_mapping_key
            return self.process_empty_scalar(token.end_mark)
        endif
    else
        let self.state=self.parse_flow_mapping_key
        let token=self.peek_token()
        return self.process_empty_scalar(token.start_mark)
    endif
endfunction
"{{{2 load.Parser.parse_flow_mapping_empty_value
function s:F.class.Parser.parse_flow_mapping_empty_value()
    let self.state=self.parse_flow_mapping_key
    return self.process_empty_scalar(self.peek_token().start_mark)
endfunction
"{{{2 load.Parser.process_empty_scalar :: (self + (mark)) -> event
function s:F.class.Parser.process_empty_scalar(mark)
    return s:_classes.ScalarEvent.new('', '', [0, 1], '', a:mark, a:mark, '')
endfunction
"{{{1 
call s:_f.setclass('Event')
call s:_f.setclass('DocumentStartEvent', 'Event')
call s:_f.setclass('DocumentEndEvent',   'Event')
call s:_f.setclass('StreamStartEvent',   'Event')
call s:_f.setclass('StreamEndEvent',     'Event')
call s:_f.setclass('CollectionEndEvent', 'Event')
call s:_f.setclass('NodeEvent',          'Event')
call s:_f.setclass('AliasEvent',           'NodeEvent')
call s:_f.setclass('ScalarEvent',          'NodeEvent')
call s:_f.setclass('CollectionStartEvent', 'NodeEvent')
call s:_f.setclass('SequenceStartEvent', 'CollectionStartEvent')
call s:_f.setclass('SequenceEndEvent',   'CollectionEndEvent')
call s:_f.setclass('MappingStartEvent',  'CollectionStartEvent')
call s:_f.setclass('MappingEndEvent',    'CollectionEndEvent')

call s:_f.setclass('None')

call s:_f.setclass('Parser')
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
