"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@/base64': '0.0',
            \                   '@%oop': '1.0',
            \              '@^ooputils': '0.0',
            \          '@%yaml/regexes': '0.0',})
let s:yaml=s:_r.yaml
let s:F.class={'BaseConstructor': {}, 'SafeConstructor': {}, 'Constructor': {}}
let s:class={'BaseConstructor': {
            \    'yaml_constructors':       {},
            \    'yaml_multi_constructors': {},
            \},
        \}
if has('float')
    let s:class.SafeConstructor={
                \'inf_value': 1.0e300,
            \}
    " pow(...) is shorter
    while s:class.SafeConstructor.inf_value!=
                \pow(s:class.SafeConstructor.inf_value, 2)
        let s:class.SafeConstructor.inf_value=
                    \pow(s:class.SafeConstructor.inf_value, 2)
    endwhile
    let s:class.SafeConstructor.nan_value=
                \-(s:class.SafeConstructor.inf_value)/
                \ (s:class.SafeConstructor.inf_value)
endif
"{{{1 load.BaseConstructor
"{{{2 load.BaseConstructor.__init__
function s:F.class.BaseConstructor.__init__(super)
    let self.constructed_objects={}
    let self.recursive_objects={}
endfunction
"{{{2 load.BaseConstructor.check_data
function s:F.class.BaseConstructor.check_data()
    return self.check_node()
endfunction
"{{{2 load.BaseConstructor.get_data
function s:F.class.BaseConstructor.get_data()
    if self.check_node()
        return self.construct_document(self.get_node())
    endif
endfunction
"{{{2 load.BaseConstructor.get_single_data
function s:F.class.BaseConstructor.get_single_data()
    let node=self.get_single_node()
    if node!={}
        return self.construct_document(node)
    endif
    return {}
endfunction
"{{{2 load.BaseConstructor.construct_document
function s:F.class.BaseConstructor.construct_document(node)
    return self.construct_object(a:node)
endfunction
"{{{2 load.BaseConstructor.construct_object
function s:F.class.BaseConstructor.construct_object(node)
    let selfname='BaseConstructor.construct_object'
    if has_key(self.constructed_objects, a:node.id)
        return self.constructed_objects[a:node.id]
    elseif has_key(self.recursive_objects, a:node.id)
        call self._raise(selfname, 'Constructor', 'invrec', 0,
                    \    a:node.start_mark)
    endif
    " self.recursive_objects[a:node]=None
    let self.recursive_objects[a:node.id]=0
    let constructor={}
    let tag_suffix=0
    if has_key(self.yaml_constructors, a:node.tag)
        let constructor.f=self.yaml_constructors[a:node.tag]
    else
        for tag_prefix in keys(self.yaml_multi_constructors)
            if a:node.tag[:len(tag_prefix)-1] is# tag_prefix
                let tag_suffix=a:node.tag[len(tag_prefix):]
                let constructor.f=self.yaml_multi_constructors[tag_prefix]
            endif
        endfor
        if !has_key(constructor, 'f')
            if has_key(self.yaml_multi_constructors, '_none')
                let tag_suffix=a:node.tag
                let constructor.f=self.yaml_multi_constructors._none
            elseif has_key(self.yaml_constructors, '_none')
                let constructor.f=self.yaml_constructors._none
            elseif a:node.__class__.name is# 'ScalarNode'
                let constructor.f=self.construct_scalar
            elseif a:node.__class__.name is# 'SequenceNode'
                let constructor.f=self.construct_sequence
            elseif a:node.__class__.name is# 'MappingNode'
                let constructor.f=self.construct_mapping
            endif
        endif
    endif
    let d={}
    if tag_suffix is 0
        let d.Data=call(constructor.f, [a:node], self)
    else
        let d.Data=call(constructor.f, [a:node, tag_suffix], self)
    endif
    let self.constructed_objects[a:node.id]=d.Data
    silent! unlet self.recursive_objects[a:node.id]
    return d.Data
endfunction
"{{{2 load.BaseConstructor.construct_scalar :: NodeConstructor
function s:F.class.BaseConstructor.construct_scalar(node, ...)
    let selfname='BaseConstructor.construct_scalar'
    if a:node.__class__.name isnot# 'ScalarNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notsc', a:node.__class__.name], a:node.start_mark)
    endif
    return a:node.value
endfunction
"{{{2 load.BaseConstructor.construct_sequence :: NodeConstructor
function s:F.class.BaseConstructor.construct_sequence(node)
    let selfname='BaseConstructor.construct_sequence'
    if a:node.__class__.name isnot# 'SequenceNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notseq', a:node.__class__.name], 0,
                    \    a:node.start_mark)
    endif
    let sequence=[]
    let self.constructed_objects[a:node.id]=sequence
    for value_node in a:node.value
        call add(sequence, self.construct_object(value_node))
    endfor
    return sequence
endfunction
"{{{2 load.BaseConstructor.construct_mapping :: NodeConstructor
function s:F.class.BaseConstructor.construct_mapping(node)
    let selfname='BaseConstructor.construct_mapping'
    if a:node.__class__.name isnot# 'MappingNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notmap', a:node.__class__.name], 0,
                    \    a:node.start_mark)
    endif
    let mapping={}
    let self.constructed_objects[a:node.id]=mapping
    let d={}
    for [key_node, value_node] in a:node.value
        let d.Key=self.construct_object(key_node)
        let tkey=type(d.Key)
        if tkey!=type('')
            if tkey==type(0)
                let d.Key=string(d.Key)
                call self._warn(selfname, 'Constructor', 'numstr',
                            \   a:node.start_mark, key_node.start_mark)
            elseif tkey==type(0.0)
                let d.Key=string(d.Key)
                call self._warn(selfname, 'Constructor', 'fltstr',
                            \   a:node.start_mark, key_node.start_mark)
            elseif tkey==type([])
                call self._raise(selfname, 'Constructor', 'lsthash',
                            \    a:node.start_mark, key_node.start_mark)
            elseif tkey==type({})
                call self._raise(selfname, 'Constructor', 'dcthash',
                            \    a:node.start_mark, key_node.start_mark)
            elseif tkey==2
                call self._raise(selfname, 'Constructor', 'dctfunc',
                            \    a:node.start_mark, key_node.start_mark)
            endif
        elseif empty(d.Key)
            call self._raise(selfname, 'Constructor', 'nullhash',
                        \    a:node.start_mark, key_node.start_mark)
        endif
        let d.Value=self.construct_object(value_node)
        let mapping[d.Key]=d.Value
        unlet d.Key d.Value
    endfor
    return mapping
endfunction
"{{{2 load.BaseConstructor.add_constructor
function s:F.class.BaseConstructor.add_constructor(tag, Constructor)
    unlockvar 1 self.__variables__.yaml_constructors
    let self.__variables__.yaml_constructors[a:tag]=a:Constructor
    lockvar! self.__variables__.yaml_constructors
endfunction
"{{{2 load.BaseConstructor.add_multi_constructor
function s:F.class.BaseConstructor.add_multi_constructor(tag, Constructor)
    unlockvar 1 self.__variables__.yaml_multi_constructors
    let self.__variables__.yaml_multi_constructors[a:tag]=a:Constructor
    unlockvar! self.__variables__.yaml_multi_constructors
endfunction
"{{{1 load.SafeConstructor
let s:class.safeconstructor={}
"{{{2 load.SafeConstructor.construct_scalar
function s:F.class.SafeConstructor.construct_scalar(node)
    if a:node.__class__.name is# 'MappingNode'
        for [key_node, value_node] in a:node.value
            if key_node.tag is# 'tag:yaml.org,2002:value'
                return self.construct_scalar(value_node)
            endif
        endfor
    endif
    return call(s:F.class.BaseConstructor.construct_scalar, [a:node], self)
endfunction
"{{{2 load.SafeConstructor.flatten_mapping :: (self + (node)) -> _
function s:F.class.SafeConstructor.flatten_mapping(node)
    let selfname='SafeConstructor.flatten_mapping'
    let merge=[]
    let index=0
    while index<len(a:node.value)
        let [key_node, value_node]=a:node.value[index]
        if key_node.tag is# 'tag:yaml.org,2002:merge'
            call remove(a:node.value, index)
            if value_node.__class__.name is# 'MappingNode'
                call self.flatten_mapping(value_node)
                call extend(merge, value_node.value)
            elseif value_node.__class__.name is# 'SequenceNode'
                let submerge=[]
                for subnode in value_node.value
                    if subnode.__class__.name isnot# 'MappingNode'
                        call self._raise(selfname, 'Constructor',
                                    \    ['nmapseq', subnode.__class__.name],
                                    \    a:node.start_mark, subnode.start_mark)
                    endif
                    call self.flatten_mapping(subnode)
                    call add(submerge, subnode.value)
                endfor
                call reverse(submerge)
                for value in submerge
                    call extend(merge, value)
                endfor
            else
                call self._raise(selfname, 'Constructor',
                            \    ['nmapseq', value_node.__class__.name],
                            \    a:node.start_mark, value_node.start_mark)
            endif
        elseif key_node.tag is# 'tag:yaml.org,2002:value'
            let key_node.tag='tag:yaml.org,2002:str'
            let index+=1
        else
            let index+=1
        endif
    endwhile
    if !empty(merge)
        let a:node.value=merge+a:node.value
    endif
endfunction
"{{{2 load.SafeConstructor.construct_mapping
function s:F.class.SafeConstructor.construct_mapping(node)
    if a:node.__class__.name is# 'MappingNode'
        call self.flatten_mapping(a:node)
    endif
    return call(s:F.class.BaseConstructor.construct_mapping, [a:node], self)
endfunction
"{{{2 load.SafeConstructor.construct_yaml_null
function s:F.class.SafeConstructor.construct_yaml_null(node)
    call self.construct_scalar(a:node)
    return s:yaml._undef
endfunction
"{{{2 load.SafeConstructor.construct_yaml_bool
function s:F.class.SafeConstructor.construct_yaml_bool(node)
    let value=self.construct_scalar(a:node)
    return ((value=~?'true')?(s:yaml._true):(s:yaml._false))
endfunction
"{{{2 load.SafeConstructor.construct_yaml_int
function s:F.class.SafeConstructor.construct_yaml_int(node)
    let value=self.construct_scalar(a:node)
    let value=tolower(substitute(value, '_', '', 'g'))
    let sign=1
    if value[0]==#'-'
        let sign=-1
    endif
    if value[0]==#'+' || value[0]==#'-'
        let value=value[1:]
    endif
    if value=='0'
        return 0
    elseif value[0:1]==#'0b'
        let r=0
        let value=value[2:]
        for digit in split(value, '\zs')
            let r=r*2+digit
        endfor
        return sign*r
    elseif value[0:1]==#'0x'
        return sign*str2nr(value, 16)
    elseif value[0]==#'0'
        return sign*str2nr(value, 8)
    elseif value=~#':'
        let digits=reverse(map(split(value, ':'), 'str2nr(v:val)'))
        let base=1
        let value=0
        for digit in digits
            let value+=digit*base
            let base=60*base
        endfor
        return sign*value
    else
        return sign*str2nr(value)
    endif
endfunction
"{{{2 load.SafeConstructor.construct_yaml_float
if has('float')
    function s:F.class.SafeConstructor.construct_yaml_float(node)
        let value=self.construct_scalar(a:node)
        let value=tolower(substitute(value, '_', '', 'g'))
        let sign=1
        if value[0] is# '-'
            let sign=-1
        endif
        if value[0] is# '-' || value[0] is# '+'
            let value=value[1:]
        endif
        if value is# '.inf'
            return sign*self.inf_value
        elseif value is# '.nan'
            return self.nan_value
        elseif value=~#':'
            let digits=reverse(map(split(value, ':'), 'str2float(v:val)'))
            let base=1
            unlet value
            let value=0.0
            for digit in digits
                let value+=digit*base
                let base=60*base
            endfor
            return sign*value
        else
            return sign*str2float(value)
        endif
    endfunction
endif
"{{{2 load.SafeConstructor.construct_yaml_binary
function s:F.class.SafeConstructor.construct_yaml_binary(node)
    let value=self.construct_scalar(a:node)
    let value=iconv(value, 'utf-8', 'latin1') " This should succeed even if 
                                              " !has('iconv')
    return s:_r.base64.decode(value)
endfunction
"{{{2 load.SafeConstructor.construct_yaml_timestamp
let s:class.safeconstructor.timestampregex=
            \'^\d\d\d\d'.
            \'-\d\d\='.
            \'-\d\d\='.
            \'\%(\%([Tt]\|['.s:yaml.whitespace.']\+\)'.
            \   '\(\d\d\=\)'.
            \   ':\(\d\d\)'.
            \   ':\(\d\d\)'.
            \   '\%(\.\(\d*\)\)\='.
            \   '\%(['.s:yaml.whitespace.']*\(Z\|\([+-]\)\(\d\d\=\)'.
            \                                  '\%(:\(\d\d\)\)\=\)\)\=\)\=$'
let s:class.safeconstructor.tsstartregex=
            \'^\(\d\d\d\d\)'.
            \'-\(\d\d\=\)'.
            \'-\(\d\d\=\)'
function s:F.class.SafeConstructor.construct_yaml_timestamp(node)
    let value=self.construct_scalar(a:node)
    let matches=matchlist(value, s:class.safeconstructor.timestampregex)
    let matches0=matchlist(value, s:class.safeconstructor.tsstartregex)
    call insert(matches, matches0[1], 1)
    call insert(matches, matches0[2], 2)
    call insert(matches, matches0[3], 3)
    let year   = str2nr(matches[1])
    let month  = str2nr(matches[2])
    let day    = str2nr(matches[3])
    if empty(matches[4])
        return value
        " return datetime.date(year, month, day)
    endif
    let hour   = str2nr(matches[4])
    let minute = str2nr(matches[5])
    let second = str2nr(matches[6])
    let fraction=''
    if !empty(matches[7])
        let fraction=matches[7][:6]
        let fraction.=repeat('0', 6-len(fraction))
        let fraction=str2nr(fraction)
    endif
    let delta=0 " = None
    if !empty(matches[9])
        let tz_hour   = str2nr(matches[10])
        let tz_minute = str2nr(matches[11])
        " delta=datetime.timedelta(hours=tz_hours, minutes=tz_minutes)
        if matches[9] is# '-'
            let delta=-delta
        endif
    endif
    " data=datetime.datetime(year, month, day, hour, minute, second, fraction)
    if delta
        " data-=delta
    endif
    return value
endfunction
"{{{2 load.SafeConstructor.construct_yaml_omap
function s:F.class.SafeConstructor.construct_yaml_omap(node)
    let selfname='SafeConstructor.construct_yaml_omap'
    let omap=[]
    let self.constructed_objects[a:node.id]=omap
    if a:node.__class__.name isnot# 'SequenceNode'
        call self._raise(selfname, 'Constructor',
                    \    ['nseqomap', a:node.__class__.name],
                    \    a:node.start_mark, a:node.start_mark)
    endif
    let d={}
    for subnode in a:node.value
        if subnode.__class__.name isnot# 'MappingNode'
            call self._raise(selfname, 'Constructor',
                        \    ['nmapomap', a:node.__class__.name],
                        \    a:node.start_mark, subnode.start_mark)
        endif
        if len(subnode.value)!=1
            call self._raise(selfname, 'Constructor',
                        \    ['nmlenomap', len(a:node.value)],
                        \    a:node.start_mark, subnode.start_mark)
        endif
        let [key_node, value_node]=subnode.value[0]
        let d.Key=self.construct_object(key_node)
        let value=self.construct_object(value_node)
        call add(omap, [d.Key, value])
        unlet d.Key value
    endfor
    return omap
endfunction
"{{{2 load.SafeConstructor.construct_yaml_pairs
function s:F.class.SafeConstructor.construct_yaml_pairs(node)
    let selfname='SafeConstructor.construct_yaml_pairs'
    let pairs=[]
    let self.constructed_objects[a:node.id]=pairs
    if a:node.__class__.name isnot# 'SequenceNode'
        call self._raise(selfname, 'Constructor',
                    \    ['nseqpr', a:node.__class__.name],
                    \    a:node.start_mark, a:node.start_mark)
    endif
    let d={}
    for subnode in a:node.value
        if subnode.__class__.name isnot# 'MappingNode'
            call self._raise(selfname, 'Constructor',
                        \    ['nmappr', a:node.__class__.name],
                        \    a:node.start_mark, subnode.start_mark)
        endif
        if len(subnode.value)!=1
            call self._raise(selfname, 'Constructor',
                        \    ['nmlenpr', len(a:node.value)],
                        \    a:node.start_mark, subnode.start_mark)
        endif
        let [key_node, value_node]=subnode.value[0]
        let d.Key=self.construct_object(key_node)
        let d.Value=self.construct_object(value_node)
        call add(pairs, [d.Key, d.Value])
        unlet d.Key d.Value
    endfor
    return pairs
endfunction
"{{{2 load.SafeConstructor.construct_yaml_set
function s:F.class.SafeConstructor.construct_yaml_set(node)
    let value=self.construct_mapping(a:node)
    let data=sort(keys(value))
    let self.constructed_objects[a:node.id]=data
    return data
endfunction
"{{{2 load.SafeConstructor.construct_yaml_str
function s:F.class.SafeConstructor.construct_yaml_str(node)
    return self.construct_scalar(a:node)
endfunction
"{{{2 load.SafeConstructor.construct_yaml_seq
function s:F.class.SafeConstructor.construct_yaml_seq(node)
    return self.construct_sequence(a:node)
endfunction
"{{{2 load.SafeConstructor.construct_yaml_map
function s:F.class.SafeConstructor.construct_yaml_map(node)
    return self.construct_mapping(a:node)
endfunction
"{{{2 load.SafeConstructor.construct_undefined
function s:F.class.SafeConstructor.construct_undefined(node)
    let selfname='SafeConstructor.construct_undefined'
    call self._raise(selfname, 'Constructor', ['unundef', a:node.tag],
                \    0, a:node.start_mark)
endfunction
"{{{1 load.Constructor
"{{{2 load.Constructor.construct_vim_function
function s:F.class.Constructor.construct_vim_function(node)
    let selfname='Constructor.construct_vim_function'
    let value=self.construct_scalar(a:node)
    if value!~#'^\d*$'
        if value[0:1] is# 's:'
            call self._raise(selfname, 'Constructor', ['fscript', value],
                        \    0, a:node.start_mark)
        endif
        try
            let fex=exists('*'.value)
        catch /^Vim\%((\a\+)\)\=:E129/
            call self._raise(selfname, 'Constructor', ['finvname', value],
                        \    0, a:node.start_mark)
        endtry
        if exists('fex') && fex
            return function(value)
        else
            call self._raise(selfname, 'Constructor', ['fundef', value],
                        \    0, a:node.start_mark)
        endif
    else
        call self._raise(selfname, 'Constructor', ['fnum', str2nr(value)],
                    \    0, a:node.start_mark)
    endif
endfunction
"{{{2 load.Constructor.construct_vim_locked
function s:F.class.Constructor.construct_vim_locked(node, tag_suffix)
    let tag='tag:yaml.org,2002:vim/'.a:tag_suffix
    let d={}
    if has_key(self.yaml_constructors, tag)
        let d.Data=call(self.yaml_constructors[tag], [a:node], self)
    else
        let a:node.tag=tag
        unlet self.recursive_objects[a:node.id]
        let d.Data=self.construct_object(a:node)
    endif
    lockvar 1 d.Data
    return d.Data
endfunction
"{{{2 load.Constructor.construct_vim_dictionary
function s:F.class.Constructor.construct_vim_dictionary(node)
    let selfname='Constructor.construct_vim_dictionary'
    if a:node.__class__.name isnot# 'MappingNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notmap', a:node.__class__.name], 0,
                    \    a:node.start_mark)
    endif
    let mapping={}
    let maplocked=0
    let self.constructed_objects[a:node.id]=mapping
    let d={}
    for [key_node, value_node] in a:node.value
        let locked=0
        let binary=0
        if key_node.tag==#'tag:yaml.org,2002:vim/Locked'
            let locked=1
            let key_node.tag='tag:yaml.org,2002:vim/String'
        elseif key_node.tag==#'tag:yaml.org,2002:Binary/vim/Locked'
            let locked=1
            let binary=1
            let key_node.tag='tag:yaml.org,2002:vim/String'
        endif
        let d.Key=self.construct_object(key_node)
        let tkey=type(d.Key)
        if tkey!=type('')
            if tkey==type(0)
                let d.Key=string(d.Key)
                call self._warn(selfname, 'Constructor', 'numstr',
                            \   a:node.start_mark, key_node.start_mark)
            elseif tkey==type(0.0)
                let d.Key=string(d.Key)
                call self._warn(selfname, 'Constructor', 'fltstr',
                            \   a:node.start_mark, key_node.start_mark)
            elseif tkey==type([])
                call self._raise(selfname, 'Constructor', 'lsthash',
                            \    a:node.start_mark, key_node.start_mark)
            elseif tkey==type({})
                call self._raise(selfname, 'Constructor', 'dcthash',
                            \    a:node.start_mark, key_node.start_mark)
            elseif tkey==2
                call self._raise(selfname, 'Constructor', 'dctfunc',
                            \    a:node.start_mark, key_node.start_mark)
            endif
        elseif empty(d.Key)
            call self._raise(selfname, 'Constructor', 'nullhash',
                        \    a:node.start_mark, key_node.start_mark)
        endif
        if binary
            let d.Key=s:_r.base64.decode(d.Key)
        endif
        let d.Value=self.construct_object(value_node)
        if islocked('mapping')
            let maplocked=1
            unlockvar 1 mapping
        endif
        if has_key(mapping, d.Key) && islocked('mapping[d.Key]')
            unlockvar 1 mapping[d.Key]
        endif
        let mapping[d.Key]=d.Value
        if locked
            lockvar 1 mapping[d.Key]
        endif
        unlet d.Key d.Value
    endfor
    if maplocked
        lockvar 1 mapping
    endif
    return mapping
endfunction
"{{{2 load.Constructor.construct_vim_list :: NodeConstructor
function s:F.class.Constructor.construct_vim_list(node)
    let selfname='Constructor.construct_vim_list'
    if a:node.__class__.name isnot# 'SequenceNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notseq', a:node.__class__.name], 0,
                    \    a:node.start_mark)
    endif
    let sequence=[]
    let seqlocked=0
    let self.constructed_objects[a:node.id]=sequence
    for value_node in a:node.value
        if value_node.tag[:32] is# 'tag:yaml.org,2002:vim/LockedItem/'
            let locked=1
            let value_node.tag=substitute(value_node.tag, 'LockedItem/', '', '')
        elseif value_node.tag[:32] is# 'tag:yaml.org,2002:vim/LockedAlias'
            let anchor=self.construct_scalar(value_node)
            if has_key(self.anchors, anchor)
                if islocked('sequence')
                    let seqlocked=1
                    unlockvar 1 sequence
                endif
                call add(sequence, self.construct_object(self.anchors[anchor]))
            else
                call self._raise(selfname, 'Constructor', ['ualias', anchor],
                            \    a:node.start_mark, value_node.start_mark)
            endif
            lockvar 1 sequence[-1]
            continue
        else
            let locked=0
        endif
        if islocked('sequence')
            let seqlocked=1
            unlockvar 1 sequence
        endif
        call add(sequence, self.construct_object(value_node))
        if locked
            lockvar 1 sequence[-1]
        endif
    endfor
    if seqlocked
        lockvar 1 seqlocked
    endif
    return sequence
endfunction
"{{{2 load.Constructor.construct_custom_binary
function s:F.class.Constructor.construct_custom_binary(node, tag_suffix)
    let selfname='Constructor.construct_custom_binary'
    if a:node.__class__.name isnot# 'ScalarNode'
        call self._raise(selfname, 'Constructor',
                    \    ['notsc', a:node.__class__.name], 0, a:node.start_mark)
    endif
    let tag='tag:yaml.org,2002:'.a:tag_suffix
    let a:node.value=s:_r.base64.decode(iconv(self.construct_scalar(a:node),
                \                             'utf-8', 'latin1'))
    let d={}
    if has_key(self.yaml_constructors, tag)
        let d.Data=call(self.yaml_constructors[tag], [a:node], self)
    else
        let a:node.tag=tag
        unlet self.recursive_objects[a:node.id]
        let d.Data=self.construct_object(a:node)
    endif
    return d.Data
endfunction
"{{{2 load.Constructor.construct_vim_buffer  XXX |
"{{{2 load.Constructor.construct_vim_window  XXX |
"{{{2 load.Constructor.construct_vim_tag     XXX |
"{{{2 load.Constructor.construct_vim_session XXX +-> to load.vim
"{{{2 load.Constructor.construct_vim_object (oop.vim support) XXX -> to oop.vim
"{{{1 
call s:_f.setclass('BaseConstructor')
call s:_f.setclass('SafeConstructor', 'BaseConstructor')
call s:_f.setclass('Constructor',     'SafeConstructor')
"{{{1 Constructor.add_constructor
let s:constructor=s:_classes.BaseConstructor.new()
call s:constructor.add_constructor('tag:yaml.org,2002:vim/String',
            \s:F.class.SafeConstructor.construct_yaml_str)
call s:constructor.add_constructor('tag:yaml.org,2002:vim/List',
            \s:F.class.Constructor.construct_vim_list)
call s:constructor.add_constructor('tag:yaml.org,2002:vim/Float',
            \s:F.class.SafeConstructor.construct_yaml_float)
call s:constructor.add_constructor('tag:yaml.org,2002:vim/Number',
            \s:F.class.SafeConstructor.construct_yaml_int)
call s:constructor.add_constructor('tag:yaml.org,2002:vim/Dictionary',
            \s:F.class.Constructor.construct_vim_dictionary)
call s:constructor.add_constructor('tag:yaml.org,2002:vim/Funcref',
            \s:F.class.Constructor.construct_vim_function)
call s:constructor.add_multi_constructor('tag:yaml.org,2002:vim/Locked',
            \s:F.class.Constructor.construct_vim_locked)
call s:constructor.add_multi_constructor('tag:yaml.org,2002:Binary/',
            \s:F.class.Constructor.construct_custom_binary)
unlet s:constructor
"{{{1 SafeConstructor.add_constructor
let s:constructor=s:_classes.BaseConstructor.new()
call s:constructor.add_constructor('tag:yaml.org,2002:null',
            \s:F.class.SafeConstructor.construct_yaml_null)
call s:constructor.add_constructor('tag:yaml.org,2002:bool',
            \s:F.class.SafeConstructor.construct_yaml_bool)
call s:constructor.add_constructor('tag:yaml.org,2002:int',
            \s:F.class.SafeConstructor.construct_yaml_int)
if has('float')
    call s:constructor.add_constructor('tag:yaml.org,2002:float',
                \s:F.class.SafeConstructor.construct_yaml_float)
endif
call s:constructor.add_constructor('tag:yaml.org,2002:binary',
            \s:F.class.SafeConstructor.construct_yaml_binary)
call s:constructor.add_constructor('tag:yaml.org,2002:timestamp',
            \s:F.class.SafeConstructor.construct_yaml_timestamp)
call s:constructor.add_constructor('tag:yaml.org,2002:omap',
            \s:F.class.SafeConstructor.construct_yaml_omap)
call s:constructor.add_constructor('tag:yaml.org,2002:pairs',
            \s:F.class.SafeConstructor.construct_yaml_pairs)
call s:constructor.add_constructor('tag:yaml.org,2002:set',
            \s:F.class.SafeConstructor.construct_yaml_set)
call s:constructor.add_constructor('tag:yaml.org,2002:str',
            \s:F.class.SafeConstructor.construct_yaml_str)
call s:constructor.add_constructor('tag:yaml.org,2002:seq',
            \s:F.class.SafeConstructor.construct_yaml_seq)
call s:constructor.add_constructor('tag:yaml.org,2002:map',
            \s:F.class.SafeConstructor.construct_yaml_map)
call s:constructor.add_constructor('_none',
            \s:F.class.SafeConstructor.construct_undefined)
unlet s:constructor
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
