"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',})
let s:F.class={'BaseResolver': {}}
let s:class={'BaseResolver': {
            \    'DEFAULT_SCALAR_TAG':   'tag:yaml.org,2002:str',
            \    'DEFAULT_SEQUENCE_TAG': 'tag:yaml.org,2002:seq',
            \    'DEFAULT_MAPPING_TAG':  'tag:yaml.org,2002:map',
            \    'yaml_implicit_resolvers': {},
            \    'yaml_path_resolvers': [],
            \    'yaml_path_resolver_ids': [],
            \},
        \}
"{{{1 load.BaseResolver
"{{{2 load.BaseResolver.__init__ :: () -> _
function s:F.class.BaseResolver.__init__(super)
    let self.resolver_exact_paths=[]
    let self.resolver_prefix_paths=[]
endfunction
"{{{2 load.BaseResolver.set_yaml_path_resolver
function s:F.class.BaseResolver.set_yaml_path_resolver(path, kind, value)
    let idx=index(self.yaml_path_resolver_ids, [a:path, a:kind])
    if idx==-1
        call add(self.yaml_path_resolver_ids, [a:path, a:kind])
        call add(self.yaml_path_resolvers, 0)
        let idx=len(self.yaml_path_resolver_ids)
    endif
    let self.yaml_path_resolvers[idx]=a:value
endfunction
"{{{2 load.BaseResolver.get_yaml_path_resolver
function s:F.class.BaseResolver.get_yaml_path_resolver(path, kind)
    let idx=index(self.yaml_path_resolver_ids, [a:path, a:kind])
    if idx==-1
        return 0
    endif
    return self.yaml_path_resolvers[idx]
endfunction
"{{{2 load.BaseResolver.check_resolver_prefix ::
"       (self + (depth::Uint, path, kind, node, index)) -> Bool
function s:F.class.BaseResolver.check_resolver_prefix(depth, path, kind,
            \                                        current_node,
            \                                        current_index)
    let [node_check, index_check]=a:path[a:depth-1]
    if type(node_check)==type('')
        if a:current_node.tag isnot# node_check
            return 0
        endif
    elseif node_check!={}
        if a:current_node.__class__.name isnot# node_check.__class__.name
            return 0
        endif
    endif
    if type(index_check)==type(0) && index_check<0
        let index_check=(index_check==-1)
        let cinone=(type(a:current_index)==type(0) && a:current_index==-1)
        if index_check && !cinone
            return 0
        elseif !index_check && cinone
            return 0
        endif
    elseif type(index_check)==type('')
        if !((type(a:current_index)==type({}) &&
                    \   a:current_index.__class__.name is# 'ScalarNode') &&
                    \index_check is# a:current_index.value)
            return 0
        endif
    elseif type(index_check)==type(0) && index_check>=0
        if !(type(a:current_index)==type(0) && a:current_index==index_check)
            return 0
        endif
    endif
    return 1
endfunction
"{{{2 load.BaseResolver.descent_resolver :: (self + (node, index)) -> _
function s:F.class.BaseResolver.descent_resolver(current_node, current_index)
    if empty(self.yaml_path_resolvers)
        return 0
    endif
    let exact_paths={}
    let prefix_paths=[]
    if a:current_node!={}
        let depth=len(self.resolver_prefix_paths)
        for [path, kind] in self.resolver_prefix_paths[-1]
            if self.check_resolver_prefix(depth, path, kind, a:current_node,
                        \                 a:current_index)
                if len(path)>depth
                    call add(prefix_paths, [path, kind])
                else
                    let exact_paths[kind]=self.get_yaml_path_resolver(path,
                                \                                     kind)
                endif
            endif
        endfor
    else
        let idx=0
        for [path, kind] in self.yaml_path_resolver_ids
            if empty(path)
                let exact_paths[kind]=self.yaml_path_resolvers[idx]
            else
                call add(prefix_paths, [path, kind])
            endif
            let idx+=1
        endfor
    endif
    call add(self.resolver_exact_paths, exact_paths)
    call add(self.resolver_prefix_paths, prefix_paths)
endfunction
"{{{2 load.BaseResolver.ascent_resolver :: (self + ()) -> _
function s:F.class.BaseResolver.ascent_resolver()
    if empty(self.resolver_exact_paths)
        return 0
    endif
    call remove(self.resolver_exact_paths, -1)
    call remove(self.resolver_prefix_paths, -1)
endfunction
"{{{2 load.BaseResolver.resolve :: (self + (String, ?, implicit)) -> tag
function s:F.class.BaseResolver.resolve(kind, value, implicit)
    if a:kind is# 'ScalarNode' && a:implicit[0]
        if empty(a:value)
            let resolvers=get(self.yaml_implicit_resolvers, '_none', [])
        else
            let resolvers=copy(get(self.yaml_implicit_resolvers,
                        \a:value[0], []))
            call extend(resolvers, get(self.yaml_implicit_resolvers,
                        \'_none', []))
        endif
        for [tag, regex] in resolvers
            if a:value=~#regex
                return tag
            endif
        endfor
        let implicit=a:implicit[1]
    endif
    if self.yaml_path_resolvers!=#[]
        let exact_paths=self.resolver_exact_paths[-1]
        if has_key(exact_paths, a:kind)
            return exact_paths[a:kind]
        endif
        if has_key(exact_paths, '_none')
            return exact_paths._none
        endif
    endif
    if a:kind is# 'ScalarNode'
        return self.DEFAULT_SCALAR_TAG
    elseif a:kind is# 'SequenceNode'
        return self.DEFAULT_SEQUENCE_TAG
    elseif a:kind is# 'MappingNode'
        return self.DEFAULT_MAPPING_TAG
    endif
endfunction
"{{{2 load.BaseResolver.add_implicit_resolver
function s:F.class.BaseResolver.add_implicit_resolver(tag, regex, first)
    if type(a:first)!=type([])
        let first=[0]
    else
        let first=a:first
    endif
    for ch in first
        if empty(ch)
            let ch='_none'
        endif
        if !has_key(self.__variables__.yaml_implicit_resolvers, ch)
            unlockvar 1 self.__variables__.yaml_implicit_resolvers
            let self.__variables__.yaml_implicit_resolvers[ch]=
                        \[[a:tag, a:regex]]
            lockvar! self.__variables__.yaml_implicit_resolvers
        else
            unlockvar 1 self.__variables__.yaml_implicit_resolvers[ch]
            call add(self.__variables__.yaml_implicit_resolvers[ch],
                        \[a:tag, a:regex])
            lockvar! self.__variables__.yaml_implicit_resolvers[ch]
        endif
    endfor
endfunction
"{{{1 
call s:_f.setclass('BaseResolver')
call s:_f.setclass('Resolver', 'BaseResolver')
"{{{1 BaseResolver.add_implicit_resolver
let s:resolver=s:_classes.BaseResolver.new()
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:bool',
            \'^\%(true\|True\|TRUE'.
            \'\|false\|False\|FALSE\)$',
            \split('tTfF', '\zs'))
" call s:resolver.add_implicit_resolver('tag:yaml.org,2002:bool',
            " \'^\%(yes\|Yes\|YES\|no\|No\|NO\|true\|True\|TRUE\|false'.
            " \'\|False\|FALSE\|on\|On\|ON\|off\|Off\|OFF\)$',
            " \split('yYnNtTfFoO', '\zs'))
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:float',
            \'^\%([+-]\=\%([0-9][0-9_]*\)\.[0-9_]*\%([eE][-+][0-9]\+\)\='.
            \'\|\.[0-9_]\+\%([eE][-+][0-9]\+\)\='.
            \'\|[-+]\=[0-9][0-9_]*\%(:[0-5]\=[0-9]\)\+\.[0-9_]*'.
            \'\|[-+]\=\.\%(inf\|Inf\|INF\)'.
            \'\|\.\%(nan\|NaN\|NAN\)\)$',
            \split('-+0123456789.', '\zs'))
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:int',
            \'^\%([-+]\=0b[0-1_]\+'.
            \'\|[-+]\=0[0-7_]\+'.
            \'\|[-+]\=\%(0\|[1-9][0-9_]*\)'.
            \'\|[-+]\=0x[0-9a-fA-F_]\+'.
            \'\|[-+]\=[1-9][0-9_]*\%(:[0-5]\=[0-9]\)\+\)$',
            \split('-+0123456789', '\zs'))
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:merge', '^<<$', ['<'])
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:null',
            \'^\%(\~\|null\|Null\|NULL\|\)$', ['~', 'n', 'N', ''])
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:timestamp',
            \'^\%(\d\d\d\d-\d\d-\d\d'.
            \'\|\d\d\d\d-\d\d\=-\d\d\=\%([Tt]\|\s\+\)\d\d\=:\d\d:\d\d'.
            \                       '\%(\.\d*\)\='.
            \               '\%(\s*\%(Z\|[-+]\d\d\=\%(:\d\d\)\=\)\)\=\)$',
            \split('0123456789', '\zs'))
call s:resolver.add_implicit_resolver('tag:yaml.org,2002:value', '^=$', ['='])
unlet s:resolver
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
