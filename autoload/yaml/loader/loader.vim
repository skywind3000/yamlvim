"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',
            \             '@^reader': '0.0',
            \            '@^scanner': '0.0',
            \             '@^parser': '0.0',
            \           '@^composer': '0.0',
            \        '@^constructor': '0.0',
            \           '@^resolver': '0.0',
            \              '@^error': '0.0',})
let s:F.class={'Loader': {}}
let s:class={}
"{{{1 Выводимые сообщения
let s:_messages={
            \'ee': {
            \   'ndocstart': '@|Expected `<document start>'', but found %s',
            \    'multYAML': '@|Found multiply YAML directives',
            \      'majmis': '@|Found incompatible YAML document: expected '.
            \                '1.x, but found %u.x',
            \      'duptag': '@|Found duplicate tag handle: %s',
            \      'ukntag': 'While parsing a node@|found undefined '.
            \                'tag handle: %s',
            \   'emptblock': 'While parsing a block node@|expected the node '.
            \                'content, but found %s',
            \   'emptyflow': 'While parsing a flow node@|expected the node '.
            \                'content, but found %s',
            \     'nblkend': 'While parsing a block collection@|expected '.
            \                '<block end>, but found %s',
            \    'nblkmend': 'While parsing a block mapping@|expected '.
            \                '<block end>, but found %s',
            \     'nflwseq': 'While parsing a flow sequence@|expected '.
            \                '`,'' or `]'', but got %s',
            \     'nflwmap': 'While parsing a flow sequence@|expected '.
            \                '`,'' or `}'', but got %s',
            \   'nottkstrt': 'While scanning for the next token@|found '.
            \                'character “%s” that cannot start any token',
            \        'sknc': 'While scanning a simple key@|could not find '.
            \                'expected `:''',
            \     'seqnall': '@|Sequence entries are not allowed here',
            \     'mnotall': '@|Mapping keys are not allowed here',
            \    'ndirname': 'While scanning a directive@|expected '.
            \                'non-whitespace non-linebreak printable '.
            \                'character, but found “%s”',
            \     'ndirend': 'While scanning a directive@|expected '.
            \                'whitespace or linebreak character, '.
            \                'but found “%s”',
            \   'nYAMLdsep': 'While scanning a YAML directive@|expected '.
            \                'a digit or decimal separator (dot), '.
            \                'but found “%s”',
            \     'nYAMLws': 'While scanning a YAML directive@|expected '.
            \                'a whitespace or linebreak character, '.
            \                'but found “%s”',
            \      'nYAMLd': 'While scanning a YAML directive@|expected '.
            \                'a digit or separator, but found “%s”',
            \     'nTAGsep': 'While scanning a TAG directive@|expected a '.
            \                'separator (whitespace), but found “%s”',
            \    'nTAGesep': 'While scanning a TAG directive@|expected a '.
            \                'separator (linebreak or whitespace), '.
            \                'but found “%s”',
            \    'ndirlend': 'While scanning a directive@|expected a comment '.
            \                'or a line break, but found “%s”',
            \     'nanname': 'While scanning an anchor@|expected '.
            \                'printable non-whitespace non-linebreak '.
            \                'character, but found “%s”',
            \     'nalname': 'While scanning an alias@|expected '.
            \                'printable non-whitespace non-linebreak '.
            \                'character, but found “%s”',
            \      'nanend': 'While scanning an anchor@|expected '.
            \                'its end, but found “%s”',
            \      'nalend': 'While scanning an alias@|expected '.
            \                'its end, but found “%s”',
            \   'ntagendgt': 'While parsing a tag@|expected `>'', '.
            \                'but found “%s”',
            \     'ntagend': 'While scanning a tag@|expected linebreak or '.
            \                'whitespace character, but found “%s”',
            \   'nullindnt': 'While scanning a block scalar@|expected '.
            \                'indentation indicator in the range 1-9, but '.
            \                'found 0',
            \     'nblkind': 'While scanning a block scalar@|expected '.
            \                'indentation or chomping indicators or '.
            \                'a separator (linebreak or whitespace), '.
            \                'but found “%s”',
            \      'nignln': 'While scanning a block scalar@|expected '.
            \                'a comment or a line break, but found “%s”',
            \        'ndqs': 'While scanning a double-quoted scalar@|'.
            \                'expected escape sequence of %u hexadecimal '.
            \                'numbers, but found “%s”',
            \      'uknesc': 'While scanning a double-quoted scalar@|'.
            \                'found unknown escape sequence “\\%s”',
            \     'strnull': '@|Unable to embed null (\\x00) character '.
            \                'in string, ignored escape sequence',
            \       'qseos': 'While scanning a quoted scalar@|'.
            \                'found unexpected end of stream',
            \    'docsepqs': 'While scanning a quoted scalar@|'.
            \                'found unexpected document separator',
            \    'abmcolon': 'While scanning a plain scalar@|'.
            \                'found unexpected `:''',
            \    'ntagbang': 'While scanning a tag@|'.
            \                'expected `!'', but found “%s”',
            \    'ndirbang': 'While scanning a directive@|'.
            \                'expected `!'', but found “%s”',
            \     'ntaguri': 'While scanning a tag@|'.
            \                'expected URI, but found “%s”',
            \     'ndiruri': 'While scanning a directive@|'.
            \                'expected URI, but found “%s”',
            \    'nturiesc': 'While scanning a tag@|expected URI '.
            \                'escaped sequence of 2 hex digits, but found “%s”',
            \    'nduriesc': 'While scanning a directive@|expected URI '.
            \                'escaped sequence of 2 hex digits, but found “%s”',
            \   'notsingle': 'Expected single document in the stream,@|'.
            \                'but found another document',
            \      'dupkey': 'While composing a mapping found@|'.
            \                'duplicate key: %s',
            \     'alundef': '@|Found undefined alias “%s”',
            \       'dupan': 'Overwritten duplicating anchor “%s”; '.
            \                'previous occurence@|next occurence',
            \      'invrec': '@|Found unconstructable recursive node',
            \       'notsc': '@|Expected a scalar node, but found %s',
            \      'notseq': '@|Expected a sequence node, but found %s',
            \      'notmap': '@|Expected a mapping node, but found %s',
            \      'fltstr': 'While constructing a mapping node@|'.
            \                'converted float to string',
            \      'numstr': 'While constructing a mapping node@|'.
            \                'converted number to string',
            \     'lsthash': 'While constructing a mapping node@|'.
            \                'found a list that cannot be used as '.
            \                'a dictionary key',
            \     'dcthash': 'While constructing a mapping node@|'.
            \                'found a dictionary that cannot be used as '.
            \                'a dictionary key',
            \     'dctfunc': 'While constructing a mapping node@|'.
            \                'found a function reference that cannot be used '.
            \                'as a dictionary key',
            \    'nullhash': 'While constructing a mapping node@|'.
            \                'found an empty value that cannot be used as '.
            \                'a dictionary key',
            \     'nmapseq': 'While constructing a mapping@|expected '.
            \                'a mapping or list of mappings for merging, '.
            \                'but found %s',
            \    'nseqomap': 'While constructing an ordered map@|expected '.
            \                'a sequence, but found %s',
            \    'nmapomap': 'While constructing an ordered map@|expected '.
            \                'a mapping, but found %s',
            \   'nmlenomap': 'While constructing an ordered map@|expected '.
            \                'a single mapping item, but found %u items',
            \      'nseqpr': 'While constructing pairs@|expected '.
            \                'a sequence, but found %s',
            \      'nmappr': 'While constructing pairs@|expected '.
            \                'a mapping, but found %s',
            \     'nmlenpr': 'While constructing pairs@|expected '.
            \                'a single mapping item, but found %u items',
            \     'unundef': '@|Could not determine a constructor '.
            \                'for the tag %s',
            \     'fscript': '@|Unable to get script function “%s”',
            \      'fundef': '@|Function “%s” does not exist',
            \    'finvname': '@|String “%s” is not a valid function name',
            \        'fnum': '@|Cannot find function with number “%u”',
            \      'ualias': 'While constructing a vim list@|'.
            \                'found unknown locked alias “%s”',
            \        'ndef': '@|Variable %s used before defining',
            \    'ambcolon': 'While scanning a plain scalar@|'.
            \                'found ambigious `:''',
            \},
            \       'infun': 'In function %s:',
            \       'unexc': 'Got %sError:',
        \}
"{{{1 load.Loader.__init__ :: (stream) -> _
function s:F.class.Loader.__init__(super, stream)
    call call(a:super.Reader.__init__,      [0, a:stream], self)
    call call(a:super.Scanner.__init__,     [0],           self)
    call call(a:super.Parser.__init__,      [0],           self)
    call call(a:super.Composer.__init__,    [0],           self)
    call call(a:super.Resolver.__init__,    [0],           self)
    call call(a:super.Constructor.__init__, [0],           self)
    let self.lastid=-1
endfunction
"{{{1 load.Loader.id :: (self + ()) -> id
function s:F.class.Loader.id()
    let self.lastid+=1
    return self.lastid
endfunction
"{{{1 load.Loader.__geterr
function s:F.class.Loader.__geterr(class, ...)
    let class=a:class.'Error'
    return call(s:_classes[class].new, a:000, s:_classes[class])
endfunction
"{{{1 load.Loader.__raise
function s:F.class.Loader.__raise(...)
    return call(self.__geterr, a:000, self).raise()
endfunction
"{{{1 load.Loader.__warn
function s:F.class.Loader.__warn(...)
    return call(self.__geterr, a:000, self).warn()
endfunction
"{{{1 load.Loader.__doerr
function s:F.class.Loader.__doerr(e, selfname, class, msgid, context_mark,
            \                    problem_mark, ...)
    if type(a:msgid)==type([])
        let msg=call(function('printf'),
                    \[get(s:_messages.ee, a:msgid[0], a:msgid[0])]+a:msgid[1:])
    else
        let msg=get(s:_messages.ee, a:msgid, a:msgid[0])
    endif
    let [context, problem]=split(msg, '@|', 1)
    let context=printf(s:_messages.unexc, a:class)."\n".context
    if type(a:selfname)==type('')
        let context=printf(s:_messages.infun, a:selfname)."\n".context
    endif
    let context=substitute(context, '\_s\+$', '', '')
    let note=get(a:000, 0, '')
    return call(self[a:e], [a:class, context, a:context_mark, problem,
                \           a:problem_mark, note], self)
endfunction
"{{{1 load.Loader._raise
function s:F.class.Loader._raise(...)
    return call(self.__doerr, ['__raise']+a:000, self)
endfunction
"{{{1 load.Loader._warn
function s:F.class.Loader._warn(...)
    return call(self.__doerr, ['__warn']+a:000, self)
endfunction
"{{{1
call s:_f.setclass('Loader', 'Reader', 'Scanner', 'Parser', 'Composer',
            \                'Constructor', 'Resolver')
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
