"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',})
let s:F.class={'Composer':{}, 'CollectionNode':{}, 'ScalarNode':{}, 'Node':{}}
" document: node
" node: { "id": unique+String, "type": ( "Scalar" | "Sequence" | "Mapping") }
" node.Mapping: +{ "value": [ (key, value) ] } (key :: node, value :: node)
" node.Sequence: +{ "value": [ node ] }
" node.Scalar: +{ "value": data }
" NodeConstructor: (self + (node[, tag_suffix])) -> data (node?)
" path: [ (node_check, index_check) ]
" node_check: (String | { "__class__": "*Node" })
" index_check: (Bool | String | Int | None): Bool: -1:True, -2:False
"                                            None: -2
" yaml_*constructors must contain function references :: NodeConstructor
" yaml_*constructors _none key is a representation of python None key
" implicit: (Bool, Bool)
let s:class={}
"{{{1 Nodes
"{{{2 load.Node.__init__ :: (tag, a, mark, mark, id) -> node
function s:F.class.Node.__init__(super, tag, value, start_mark, end_mark, id)
    let self.tag=a:tag
    let self.value=a:value
    let self.start_mark=a:start_mark
    let self.end_mark=a:end_mark
    let self.id=a:id
endfunction
"{{{2 load.CollectionNode.__init__ :: (tag, a, mark, mark, Bool) -> node
function s:F.class.CollectionNode.__init__(super, tag, value, start_mark,
            \                             end_mark, flow_style, id)
    call call(s:F.class.Node.__init__, [0, a:tag, a:value, a:start_mark,
                \                      a:end_mark, a:id], self)
    let self.flow_style=a:flow_style
endfunction
"{{{2 load.ScalarNode.__init__
function s:F.class.ScalarNode.__init__(super, tag, value, start_mark, end_mark,
            \                         style, id)
    call call(a:super.__init__, [0, a:tag, a:value, a:start_mark, a:end_mark,
                \                a:id], self)
    let self.style=a:style
endfunction
"{{{1 load.Composer
"{{{2 load.Composer.__init__ :: () -> _
function s:F.class.Composer.__init__(super)
    let self.anchors={}
endfunction
"{{{2 load.Composer.check_node
function s:F.class.Composer.check_node()
    if self.check_event('StreamStartEvent')
        call self.get_event()
    endif
    return !self.check_event('StreamEndEvent')
endfunction
"{{{2 load.Composer.get_node
function s:F.class.Composer.get_node()
    if !self.check_event('StreamEndEvent')
        return self.compose_document()
    endif
endfunction
"{{{2 load.Composer.get_single_node -> document
function s:F.class.Composer.get_single_node()
    let selfname='Composer.get_single_node'
    call self.get_event()
    let document={} " = None
    if !self.check_event('StreamEndEvent')
        let document=self.compose_document()
    endif
    if !self.check_event('StreamEndEvent')
        let event=self.get_event()
        call self._warn(selfname, 'Composer', 'notsingle',
                    \   document.start_mark, event.start_mark)
    endif
    call self.get_event()
    return document
endfunction
"{{{2 load.Composer.compose_document :: (self + ()) -> document
function s:F.class.Composer.compose_document()
    call self.get_event()
    let self.anchors={}
    let node=self.compose_node({}, -1)
    call self.get_event()
    return node
endfunction
"{{{2 load.Composer.compose_node :: (self + (node, index)) -> node
function s:F.class.Composer.compose_node(parent, index)
    let selfname='Composer.compose_node'
    if self.check_event('AliasEvent')
        let event=self.get_event()
        let anchor=event.anchor
        if !has_key(self.anchors, anchor)
            call self._raise(selfname, 'Composer', ['alundef', anchor],
                        \    0, event.start_mark)
        endif
        return self.anchors[anchor]
    endif
    let event=self.peek_event()
    if has_key(event, 'anchor')
        let anchor=event.anchor
        if has_key(self.anchors, anchor)
            call self._warn(selfname, 'Composer', ['dupan', anchor],
                        \   self.anchors[anchor].start_mark,
                        \   event.start_mark)
        endif
    else
        let anchor=''
    endif
    call self.descent_resolver(a:parent, a:index)
    if self.check_event('ScalarEvent')
        let node=self.compose_scalar_node(anchor)
    elseif self.check_event('SequenceStartEvent')
        let node=self.compose_sequence_node(anchor)
    elseif self.check_event('MappingStartEvent')
        let node=self.compose_mapping_node(anchor)
    endif
    call self.ascent_resolver()
    if !exists('l:node')
        call self._raise(selfname, 'Internal', ['ndef', 'node'],
                    \    0, 0)
    endif
    return node
endfunction
"{{{2 load.Composer.compose_scalar_node :: (self + (anchor)) -> node
function s:F.class.Composer.compose_scalar_node(anchor)
    let selfname='Composer.compose_scalar_node'
    let event=self.get_event()
    let tag=''
    if has_key(event, 'tag')
        let tag=event.tag
    endif
    if empty(tag) || tag is# '!'
        let tag=self.resolve('ScalarNode', event.value, event.implicit)
    endif
    let node=s:_classes.ScalarNode.new(tag, event.value, event.start_mark,
                \                      event.end_mark, event.style, self.id())
    if !empty(a:anchor)
        let self.anchors[a:anchor]=node
    endif
    return node
endfunction
"{{{2 load.Composer.compose_sequence_node :: (self + (anchor)) -> node
function s:F.class.Composer.compose_sequence_node(anchor)
    let selfname='Composer.compose_sequence_node'
    let start_event=self.get_event()
    let tag=''
    if has_key(start_event, 'tag')
        let tag=start_event.tag
    endif
    if empty(tag) || tag is# '!'
        let tag=self.resolve('SequenceNode', 0, start_event.implicit)
    endif
    let node=s:_classes.SequenceNode.new(tag, [], start_event.start_mark, 0,
                \                        start_event.flow_style, self.id())
    if !empty(a:anchor)
        let self.anchors[a:anchor]=node
    endif
    let index=0
    while !self.check_event('SequenceEndEvent')
        call add(node.value, self.compose_node(node, index))
        let index+=1
    endwhile
    let end_event=self.get_event()
    let node.end_mark=end_event.end_mark
    return node
endfunction
"{{{2 load.Composer.compose_mapping_node :: (self + (anchor)) -> node
function s:F.class.Composer.compose_mapping_node(anchor)
    let selfname='Composer.compose_mapping_node'
    let start_event=self.get_event()
    let tag=''
    if has_key(start_event, 'tag')
        let tag=start_event.tag
    endif
    if empty(tag) || tag is# '!'
        let tag=self.resolve('MappingNode', 0, start_event.implicit)
    endif
    let node=s:_classes.MappingNode.new(tag, [], start_event.start_mark, 0,
                \                       start_event.flow_style, self.id())
    if !empty(a:anchor)
        let self.anchors[a:anchor]=node
    endif
    while !self.check_event('MappingEndEvent')
        " key_event=self.peek_event()
        let item_key=self.compose_node(node, -1)
        " if " has_key(node.value, item_key)
            " call self._warn(selfname, 'Composer', ['dupkey', item_key],
                        " \   node.start_mark, item_key.start_mark)
        " endif
        let item_value=self.compose_node(node, item_key)
        call add(node.value, [item_key, item_value])
    endwhile
    let end_event=self.get_event()
    let node.end_mark=end_event.end_mark
    return node
endfunction
"{{{1 
call s:_f.setclass('Node')
call s:_f.setclass('ScalarNode',     'Node')
call s:_f.setclass('CollectionNode', 'Node')
call s:_f.setclass('SequenceNode', 'CollectionNode')
call s:_f.setclass('MappingNode',  'CollectionNode')

call s:_f.setclass('Composer')
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
