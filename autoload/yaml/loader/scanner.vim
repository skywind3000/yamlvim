"{{{1 
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%oop': '1.0',
            \           '@^ooputils': '0.0',
            \       '@%yaml/regexes': '0.0',})
let s:yaml=s:_r.yaml
let s:_messages={
            \'ambcolonnote': 'Assuming that it separates key from value',
        \}
let s:F.class={'Scanner':          {},
            \  'Token':            {},
            \  'DirectiveToken':   {},
            \  'StreamStartToken': {},
            \  'AliasToken':       {},
            \  'AnchorToken':      {},
            \  'TagToken':         {},
            \  'ScalarToken':      {},
            \  'SimpleKey':        {},
            \}
" token: { "encoding": ?, "start_mark": mark, "type": String, "end_mark": mark }
" token.DirectiveToken: +{ "name": String }
" token.DirectiveToken(name=YAML): +{ "value": (major, minor) }
"                                               (major, minor :: Uint)
" token.DirectiveToken(name=TAG): +{ "value": (handle, prefix) }
"                                               (handle :: String)
" token.TagToken: +{ "value": (handle, suffix) }
" token.ScalarToken: +{ "value": ?, "plain": Bool, "style": ? }
let s:class={'Scanner': {
            \    'SEPREGEX': '^['.(s:yaml.whitespace).(s:yaml.linebreak).']\=$',
            \    'FLOWREGEX': '^['.(s:yaml.whitespace).(s:yaml.linebreak).
            \                      (s:yaml.flowindicator).(s:yaml.comment).
            \                      (s:yaml.mappingkey).(s:yaml.mappingvalue).
            \                      (s:yaml.sequenceentry).
            \                      (s:yaml.directivestart).
            \                      (s:yaml.anchorstart).(s:yaml.aliasstart).
            \                      '''"`|!>@]\=$',
            \    'ANEND': '^['.(s:yaml.whitespace).(s:yaml.linebreak).
            \                  (s:yaml.directivestart).(s:yaml.mappingkey).
            \                  (s:yaml.mappingvalue).',\]}@]\=$',
            \    'ESCAPE_REPLACEMENTS': {
            \       'a':  "\x07",
            \       'b':  "\x08",
            \       't':  "\x09",
            \       "\t": "\x09",
            \       'n':  "\x0A",
            \       'v':  "\x0B",
            \       'f':  "\x0C",
            \       'r':  "\x0D",
            \       'e':  "\x1B",
            \       ' ':  "\x20",
            \       '"':  '"',
            \       '/':  '/',
            \       '\':  '\',
            \       'N':  "\u0085",
            \       '_':  "\u00A0",
            \       'L':  "\u2028",
            \       'P':  "\u2029",
            \    },
            \    'ESCAPE_CODES': {
            \       'x': 2,
            \       'u': 4,
            \       'U': 8,
            \    },
            \},
            \'DirectiveToken':     {'id': '<directive>',},
            \'DocumentStartToken': {'id': '<document start>',},
            \'DocumentEndToken':   {'id': '<document end>',},
            \'StreamStartToken':   {'id': '<stream start>',},
            \'StreamEndToken':     {'id': '<stream end>',},
        \}
"{{{1 load.Scanner
"{{{2 load.Scanner.__init__ :: () -> _
function s:F.class.Scanner.__init__(super)
    let self.done=0 " :: Bool
    " Number of unclosed [ and {, flow_level=0 means block context
    let self.flow_level=0 " :: UInt
    " List of processed tokens that are not yet emitted
    let self.tokens=[]
    " Fetch the STREAM-START token
    call self.fetch_stream_start()
    " Number of tokens that were emitted through the `get_token' method
    let self.tokens_taken=0
    " Current indentation level
    let self.indent=-1
    " Past indentation levels
    let self.indents=[]

    " Variables related to simple keys treatment.

    " A simple key is a key that is not denoted by the '?' indicator.
    " Example of simple keys:
    "   ---
    "   block simple key: value
    "   ? not a simple key:
    "   : { flow simple key: value }
    " We emit the KEY token before all keys, so when we find a potential
    " simple key, we try to locate the corresponding ':' indicator.
    " Simple keys should be limited to a single line and 1024 characters.

    " Can a simple key start at the current position? A simple key may
    " start:
    " - at the beginning of the line, not counting indentation spaces
    "       (in block context),
    " - after '{', '[', ',' (in the flow context),
    " - after '?', ':', '-' (in the block context).
    " In the block context, this flag also signifies if a block collection
    " may start at the current position.
    let self.allow_simple_key=1 " :: Bool

    " Keep track of possible simple keys. This is a dictionary. The key
    " is `flow_level`; there can be no more that one possible simple key
    " for each level. The value is a SimpleKey record:
    "   (token_number, required, index, line, column, mark)
    " A simple key may start with ALIAS, ANCHOR, TAG, SCALAR(flow),
    " '[', or '{' tokens.
    let self.possible_simple_keys={}
endfunction
"{{{2 token
"{{{3 load.Scanner.check_token :: (self + (Class*)) -> Bool
function s:F.class.Scanner.check_token(...)
    call self.more_tokens()
    if !empty(self.tokens)
        if empty(a:000)
            return 1
        endif
        for choice in a:000
            if self.tokens[0].__class__.name is# choice
                return 1
            endif
        endfor
    endif
    return 0
endfunction
"{{{3 load.Scanner.peek_token :: (self + ()) -> token
function s:F.class.Scanner.peek_token()
    call self.more_tokens()
    return get(self.tokens, 0, {})
endfunction
"{{{3 load.Scanner.get_token :: (self + ()) -> token
function s:F.class.Scanner.get_token()
    call self.more_tokens()
    if !empty(self.tokens)
        let self.tokens_taken+=1
        return remove(self.tokens, 0)
    endif
    return 0
endfunction
"{{{3 load.Scanner.need_more_tokens :: (self + ()) -> Bool
function s:F.class.Scanner.need_more_tokens()
    if self.done
        return 0
    endif
    if empty(self.tokens)
        return 1
    endif
    call self.stale_possible_simple_keys()
    if self.next_possible_simple_key()==self.tokens_taken
        return 1
    endif
    return 0
endfunction
"{{{3 load.Scanner.more_tokens :: (self + ()) -> _
function s:F.class.Scanner.more_tokens()
    while self.need_more_tokens()
        call self.fetch_more_tokens()
    endwhile
endfunction
"{{{3 load.Scanner.fetch_more_tokens :: (self + ()) -> _
let s:class.scanner={}
let s:class.scanner.chtofname={
            \'[': 'fetch_flow_sequence_start',
            \'{': 'fetch_flow_mapping_start',
            \'}': 'fetch_flow_mapping_end',
            \']': 'fetch_flow_sequence_end',
            \',': 'fetch_flow_entry',
            \'*': 'fetch_alias',
            \'&': 'fetch_anchor',
            \'!': 'fetch_tag',
            \"'": 'fetch_single',
            \'"': 'fetch_double',
        \}
function s:F.class.Scanner.fetch_more_tokens()
    let selfname='Scanner.fetch_more_tokens'
    call self.scan_to_next_token()         " Skip ws and comments
    call self.stale_possible_simple_keys() " Remove obsolete simple keys
    call self.unwind_indent(self.column)   " Compare the current indentation and 
                                           " column. It may add some tokens and 
                                           " decrease the current indentation 
                                           " level
    let ch=self.peek()
    if ch==#''
        return self.fetch_stream_end()
    elseif ch is# '%' && self.check_directive()
        return self.fetch_directive()
    elseif ch is# '-' && self.check_document_start()
        return self.fetch_document_start()
    elseif ch is# '.' && self.check_document_end()
        return self.fetch_document_end()
    elseif has_key(s:class.scanner.chtofname, ch)
        return self[s:class.scanner.chtofname[ch]]()
    elseif ch is# '-' && self.check_block_entry()
        return self.fetch_block_entry()
    elseif ch is# '?' && self.check_key()
        return self.fetch_key()
    elseif ch is# ':' && self.check_value()
        return self.fetch_value()
    elseif ch is# '|' && !self.flow_level
        return self.fetch_literal()
    elseif ch is# '>' && !self.flow_level
        return self.fetch_folded()
    elseif self.check_plain()
        return self.fetch_plain()
    endif
    call self._raise(selfname, 'Scanner', ['nottkstrt', ch], 0,
                \    self.get_mark())
endfunction
"{{{2 Simple key treatment
"{{{3 load.Scanner.next_possible_simple_key :: (self + ()) -> UInt
function s:F.class.Scanner.next_possible_simple_key()
    let min_token_number=0
    for level in keys(self.possible_simple_keys)
        let key=self.possible_simple_keys[level]
        if !min_token_number || key.token_number<min_token_number
            let min_token_number=key.token_number
        endif
    endfor
    return min_token_number
endfunction
"{{{3 load.Scanner.stale_possible_simple_keys :: (self + ()) -> _
function s:F.class.Scanner.stale_possible_simple_keys()
    let selfname='Scanner.stale_possible_simple_keys'
    " Remove entries that are no longer possible simple keys. According to
    " the YAML specification, simple keys
    " - should be limited to a single line,
    " - should be no longer than 1024 characters.
    " Disabling this procedure will allow simple keys of any length and
    " height (may cause problems if indentation is broken though).
    for [level, key] in items(self.possible_simple_keys)
        if key.line!=self.line || (self.index-key.index)>1024
            if key.required
                call self._raise(selfname, 'Scanner', 'sknc', key.mark,
                            \    self.get_mark())
            endif
            unlet self.possible_simple_keys[level]
        endif
    endfor
endfunction
"{{{3 load.Scanner.save_possible_simple_key :: (self + ()) -> _
function s:F.class.Scanner.save_possible_simple_key()
    let required=(!self.flow_level && self.indent==self.column)
    " assert self.allow_simple_key or not required
    if self.allow_simple_key
        call self.remove_possible_simple_key()
        let token_number=self.tokens_taken+len(self.tokens)
        let key=s:_classes.SimpleKey.new(token_number, required,
                    \                    self.index, self.line, self.column,
                    \                    self.get_mark())
        let self.possible_simple_keys[self.flow_level]=key
    endif
endfunction
"{{{3 load.Scanner.remove_possible_simple_key :: (self + ()) -> _
function s:F.class.Scanner.remove_possible_simple_key()
    let selfname='Scanner.remove_possible_simple_key'
    if has_key(self.possible_simple_keys, self.flow_level)
        let key=self.possible_simple_keys[self.flow_level]
        if key.required
            call self.__raise(selfname, 'scanner', 'sknc')
        endif
        unlet self.possible_simple_keys[self.flow_level]
    endif
endfunction
"{{{2 indent
"{{{3 load.Scanner.unwind_indent :: (self + (column)) -> _
function s:F.class.Scanner.unwind_indent(column)
    " In the flow context, indentation is ignored. We make the scanner less
    " restrictive then specification requires.
    if self.flow_level
        return 0
    endif

    " In block context, we may need to issue the BLOCK-END tokens.
    while self.indent>a:column
        let mark=self.get_mark()
        let self.indent=remove(self.indents, -1)
        call add(self.tokens, s:_classes.BlockEndToken.new(mark, mark))
    endwhile
endfunction
"{{{3 load.Scanner.add_indent :: (self + (column)) -> Bool
function s:F.class.Scanner.add_indent(column)
    if self.indent<a:column
        call add(self.indents, self.indent)
        let self.indent=a:column
        return 1
    endif
    return 0
endfunction
"{{{2 fetchers
"{{{3 load.Scanner.fetch_stream_start :: (self + ()) -> _
function s:F.class.Scanner.fetch_stream_start()
    let mark=self.get_mark()
    call add(self.tokens, s:_classes.StreamStartToken.new(mark, mark,
                \                                         self.encoding))
endfunction
"{{{3 load.Scanner.fetch_stream_end :: (self + ()) -> _
function s:F.class.Scanner.fetch_stream_end()
    call self.unwind_indent(-1)
    call self.remove_possible_simple_key()
    let self.allow_simple_key=0
    let self.possible_simple_keys={}
    let mark=self.get_mark()
    call add(self.tokens, s:_classes.StreamEndToken.new(mark, mark))
    let self.done=1
endfunction
"{{{3 load.Scanner.fetch_directive :: (self + ()) -> _
function s:F.class.Scanner.fetch_directive()
    call self.unwind_indent(-1)
    call self.remove_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_directive())
endfunction
"{{{3 load.Scanner.fetch_document_start :: (self + ()) -> _
function s:F.class.Scanner.fetch_document_start()
    call self.fetch_document_indicator('DocumentStartToken')
endfunction
"{{{3 load.Scanner.fetch_document_end :: (self + ()) -> _
function s:F.class.Scanner.fetch_document_end()
    call self.fetch_document_indicator('DocumentEndToken')
endfunction
"{{{3 load.Scanner.fetch_document_indicator :: (self + (Class)) -> _
function s:F.class.Scanner.fetch_document_indicator(tokenclass)
    call self.unwind_indent(-1)
    call self.remove_possible_simple_key()
    let self.allow_simple_key=0
    let start_mark=self.get_mark()
    call self.forward(3)
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes[a:tokenclass].new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_flow_sequence_start :: (self + ()) -> _
function s:F.class.Scanner.fetch_flow_sequence_start()
    call self.fetch_flow_collection_start('FlowSequenceStartToken')
endfunction
"{{{3 load.Scanner.fetch_flow_mapping_start :: (self + ()) -> _
function s:F.class.Scanner.fetch_flow_mapping_start()
    call self.fetch_flow_collection_start('FlowMappingStartToken')
endfunction
"{{{3 load.Scanner.fetch_flow_collection_start :: (self + (Class)) -> _
function s:F.class.Scanner.fetch_flow_collection_start(tokenclass)
    call self.save_possible_simple_key()
    let self.flow_level+=1
    let self.allow_simple_key=1
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes[a:tokenclass].new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_flow_sequence_end :: (self + ()) -> _
function s:F.class.Scanner.fetch_flow_sequence_end()
    call self.fetch_flow_collection_end('FlowSequenceEndToken')
endfunction
"{{{3 load.Scanner.fetch_flow_mapping_end :: (self + ()) -> _
function s:F.class.Scanner.fetch_flow_mapping_end()
    call self.fetch_flow_collection_end('FlowMappingEndToken')
endfunction
"{{{3 load.Scanner.fetch_flow_collection_end :: (self + (Class)) -> _
function s:F.class.Scanner.fetch_flow_collection_end(tokenclass)
    call self.remove_possible_simple_key()
    let self.flow_level-=1
    let self.allow_simple_key=0
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes[a:tokenclass].new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_flow_entry :: (self + ()) -> _
function s:F.class.Scanner.fetch_flow_entry()
    let self.allow_simple_key=1
    call self.remove_possible_simple_key()
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes.FlowEntryToken.new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_block_entry :: (self + ()) -> _
function s:F.class.Scanner.fetch_block_entry()
    let selfname='Scanner.fetch_block_entry'
    if !self.flow_level
        if !self.allow_simple_key
            call self._raise(selfname, 'Scanner', 'seqnall', 0, self.get_mark())
        endif
        if self.add_indent(self.column)
            let mark=self.get_mark()
            call add(self.tokens, s:_classes.BlockSequenceStartToken.new(mark,
                        \                                                mark))
        endif
    else
        " pass
        return 0
    endif
    let self.allow_simple_key=1
    call self.remove_possible_simple_key()
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes.BlockEntryToken.new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_key :: (self + ()) -> _
function s:F.class.Scanner.fetch_key()
    let selfname='Scanner.fetch_key'
    if !self.flow_level
        if !self.allow_simple_key
            call self._raise(selfname, 'Scanner', 'mnotall', 0, self.get_mark())
        elseif self.add_indent(self.column)
            let mark=self.get_mark()
            call add(self.tokens, s:_classes.BlockMappingStartToken.new(mark,
                        \                                               mark))
        endif
    endif
    " Simple keys are allowed after '?' in the block context
    let self.allow_simple_key=!self.flow_level
    call self.remove_possible_simple_key()
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes.KeyToken.new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_value :: (self + ()) -> _
function s:F.class.Scanner.fetch_value()
    let selfname='Scanner.fetch_value'
    if has_key(self.possible_simple_keys, self.flow_level)
        let key=remove(self.possible_simple_keys, self.flow_level)
        call insert(self.tokens, s:_classes.KeyToken.new(key.mark, key.mark),
                    \key.token_number-self.tokens_taken)
        if !self.flow_level && self.add_indent(key.column)
            call insert(self.tokens,
                        \s:_classes.BlockMappingStartToken.new(key.mark,
                        \                                      key.mark),
                        \key.token_number-self.tokens_taken)
        endif
        " There cannot be two simple keys one after another
        let self.allow_simple_key=0
    else
        if !self.flow_level && !self.allow_simple_key
            call self._raise(selfname, 'Scanner', 'mnotall', 0, self.get_mark())
        endif
        if !self.flow_level
            if self.add_indent(self.column)
                let mark=self.get_mark()
                call add(self.tokens,
                            \s:_classes.BlockMappingStartToken.new(mark, mark))
            endif
        endif
        " Simple keys are allowed after ':' in the block context
        let self.allow_simple_key=!self.flow_level
        call self.remove_possible_simple_key()
    endif
    let start_mark=self.get_mark()
    call self.forward()
    let end_mark=self.get_mark()
    call add(self.tokens, s:_classes.ValueToken.new(start_mark, end_mark))
endfunction
"{{{3 load.Scanner.fetch_alias :: (self + ()) -> _
function s:F.class.Scanner.fetch_alias()
    call self.save_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_anchor('AliasToken'))
endfunction
"{{{3 load.Scanner.fetch_anchor :: (self + ()) -> _
function s:F.class.Scanner.fetch_anchor()
    call self.save_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_anchor('AnchorToken'))
endfunction
"{{{3 load.Scanner.fetch_tag :: (self + ()) -> _
function s:F.class.Scanner.fetch_tag()
    call self.save_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_tag())
endfunction
"{{{3 load.Scanner.fetch_literal :: (self + ()) -> _
function s:F.class.Scanner.fetch_literal()
    call self.fetch_block_scalar('|')
endfunction
"{{{3 load.Scanner.fetch_folded :: (self + ()) -> _
function s:F.class.Scanner.fetch_folded()
    call self.fetch_block_scalar('>')
endfunction
"{{{3 load.Scanner.fetch_block_scalar :: (self + (style)) -> _
function s:F.class.Scanner.fetch_block_scalar(style)
    let self.allow_simple_key=1
    call self.remove_possible_simple_key()
    call add(self.tokens, self.scan_block_scalar(a:style))
endfunction
"{{{3 load.Scanner.fetch_single :: (self + ()) -> _
function s:F.class.Scanner.fetch_single()
    call self.fetch_flow_scalar("'")
endfunction
"{{{3 load.Scanner.fetch_double :: (self + ()) -> _
function s:F.class.Scanner.fetch_double()
    call self.fetch_flow_scalar('"')
endfunction
"{{{3 load.Scanner.fetch_flow_scalar :: (self + (style)) -> _
function s:F.class.Scanner.fetch_flow_scalar(style)
    call self.save_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_flow_scalar(a:style))
endfunction
"{{{3 load.Scanner.fetch_plain :: (self + ()) -> _
function s:F.class.Scanner.fetch_plain()
    call self.save_possible_simple_key()
    let self.allow_simple_key=0
    call add(self.tokens, self.scan_plain())
endfunction
"{{{2 checkers
"{{{3 load.Scanner.check_directive :: (self + ()) -> Bool
function s:F.class.Scanner.check_directive()
    if self.column==0
        return 1
    endif
    return 0
endfunction
"{{{3 load.Scanner.check_document_start :: (self + ()) -> Bool
function s:F.class.Scanner.check_document_start()
    if self.column==0 && self.prefix(3)==#'---' &&
                \self.peek(3)=~#self.SEPREGEX
        return 1
    endif
    return 0
endfunction
"{{{3 load.Scanner.check_document_end :: (self + ()) -> Bool
function s:F.class.Scanner.check_document_end()
    if self.column==0 && self.prefix(3)==#'...' &&
                \self.peek(3)=~#self.SEPREGEX
        return 1
    endif
    return 0
endfunction
"{{{3 load.Scanner.check_block_entry :: (self + ()) -> Bool
function s:F.class.Scanner.check_block_entry()
    return self.peek(1)=~#self.SEPREGEX
endfunction
"{{{3 load.Scanner.check_key :: (self + ()) -> Bool
function s:F.class.Scanner.check_key()
    if self.flow_level
        return 1
    else
        return self.peek(1)=~#self.SEPREGEX
    endif
endfunction
"{{{3 load.Scanner.check_value :: (self + ()) -> Bool
function s:F.class.Scanner.check_value()
    if self.flow_level
        return 1
    else
        return self.peek(1)=~#self.SEPREGEX
    endif
endfunction
"{{{3 load.Scanner.check_plain :: (self + ()) -> Bool
function s:F.class.Scanner.check_plain()
    let ch=self.peek()
    return (ch!~#self.FLOWREGEX || (self.peek(1)!~#self.SEPREGEX &&
                \                   ch==#'-' || (!self.flow_level &&
                \                                (ch==#'?' || ch==#':'))))
endfunction
"{{{2 scanners
"{{{3 load.Scanner.scan_to_next_token :: (self + ()) -> _
function s:F.class.Scanner.scan_to_next_token()
    " We ignore spaces, line breaks and comments.
    " If we find a line break in the block context, we set the flag
    " `allow_simple_key` on.
    " The byte order mark is stripped if it's the first character in the
    " stream. We do not yet support BOM inside the stream as the
    " specification requires. Any such mark will be considered as a part
    " of the document.
    if self.index==0 && self.peek() is# "\uFEFF"
        call self.forward()
    endif
    let found=0
    while !found
        while self.peek()=~#'^['.s:yaml.whitespace.']$'
            call self.forward()
        endwhile
        if self.peek() is# s:yaml.comment
            while self.peek()!~#'^['.s:yaml.linebreak.']\=$'
                call self.forward()
            endwhile
        endif
        if !empty(self.scan_line_break())
            if !self.flow_level
                let self.allow_simple_key=1
            endif
        else
            let found=1
        endif
    endwhile
endfunction
"{{{3 load.Scanner.scan_directive :: (self + ()) -> token
function s:F.class.Scanner.scan_directive()
    let start_mark=self.get_mark()
    call self.forward()
    let name=self.scan_directive_name(start_mark)
    let value='' " = None
    if name is# 'YAML'
        unlet value
        let value=self.scan_yaml_directive_value(start_mark)
        let end_mark=self.get_mark()
    elseif name is# 'TAG'
        unlet value
        let value=self.scan_tag_directive_value(start_mark)
        let end_mark=self.get_mark()
    else
        let end_mark=self.get_mark()
        while self.peek()!~#self.SEPREGEX
            call self.forward()
        endwhile
    endif
    call self.scan_directive_ignored_line(start_mark)
    return s:_classes.DirectiveToken.new(name, value, start_mark, end_mark)
endfunction
"{{{3 load.Scanner.scan_directive_name :: (self + (mark)) -> String
function s:F.class.Scanner.scan_directive_name(start_mark)
    let selfname='Scanner.scan_directive_name'
    let length=0
    let ch=self.peek(length)
    while s:yaml.isnschar(ch)
        let length+=1
        let ch=self.peek(length)
    endwhile
    if !length
        call self._raise(selfname, 'Scanner', ['ndirname', ch], a:start_mark,
                    \    self.get_mark())
    endif
    let value=self.prefix(length)
    call self.forward(length)
    let ch=self.peek()
    if ch!~#self.SEPREGEX
        call self._raise(selfname, 'Scanner', ['ndirend', ch], a:start_mark,
                    \    self.get_mark())
    endif
    return value
endfunction
"{{{3 load.Scanner.scan_yaml_directive_value :: (self + (mark)) -> (UInt,UInt)
function s:F.class.Scanner.scan_yaml_directive_value(start_mark)
    let selfname='Scanner.scan_yaml_directive_value'
    while self.peek()=~#'^['.s:yaml.whitespace.']'
        call self.forward()
    endwhile
    let major=self.scan_yaml_directive_number(a:start_mark)
    if self.peek()!=#'.'
        call self._raise(selfname, 'Scanner', ['nYAMLdsep', self.peek()],
                    \    a:start_mark, self.get_mark())
    endif
    call self.forward()
    let minor=self.scan_yaml_directive_number(a:start_mark)
    if self.peek()!~#self.SEPREGEX
        call self._raise(selfname, 'Scanner', ['nYAMLws', self.peek()],
                    \    a:start_mark, self.get_mark())
    endif
    return [major, minor]
endfunction
"{{{3 load.Scanner.scan_yaml_directive_number :: (self + (mark)) -> UInt
function s:F.class.Scanner.scan_yaml_directive_number(start_mark)
    let selfname='Scanner.scan_yaml_directive_number'
    let ch=self.peek()
    if ch!~#'^\d$'
        call self._raise(selfname, 'Scanner', ['nYAMLd', ch], a:start_mark,
                    \    self.get_mark())
    endif
    let length=0
    while self.peek(length)=~#'^\d$'
        let length+=1
    endwhile
    let value=(self.prefix(length))+0
    call self.forward(length)
    return value
endfunction
"{{{3 load.Scanner.scan_tag_directive_value :: (self + (mark)) -> (Str,Str)
function s:F.class.Scanner.scan_tag_directive_value(start_mark)
    while self.peek()=~#'^['.s:yaml.whitespace.']$'
        call self.forward()
    endwhile
    let handle=self.scan_tag_directive_handle(a:start_mark)
    while self.peek()=~#'^['.s:yaml.whitespace.']$'
        call self.forward()
    endwhile
    let prefix=self.scan_tag_directive_prefix(a:start_mark)
    return [handle, prefix]
endfunction
"{{{3 load.Scanner.scan_tag_directive_handle :: (self + (mark)) -> String
function s:F.class.Scanner.scan_tag_directive_handle(start_mark)
    let selfname='Scanner.scan_tag_directive_handle'
    let value=self.scan_tag_handle('directive', a:start_mark)
    let ch=self.peek()
    if ch!~#'^['.s:yaml.whitespace.']$'
        call self._raise(selfname, 'Scanner', ['nTAGsep', ch], a:start_mark,
                    \    self.get_mark())
    endif
    return value
endfunction
"{{{3 load.Scanner.scan_tag_directive_prefix :: (self + (mark)) -> String
function s:F.class.Scanner.scan_tag_directive_prefix(start_mark)
    let value=self.scan_tag_uri('directive', a:start_mark)
    let ch=self.peek()
    if ch!~#self.SEPREGEX
        call self._raise(selfname, 'Scanner', ['nTAGesep', ch], a:start_mark,
                    \    self.get_mark())
    endif
    return value
endfunction
"{{{3 load.Scanner.scan_directive_ignored_line :: (self + (mark)) -> _
function s:F.class.Scanner.scan_directive_ignored_line(start_mark)
    let selfname='Scanner.scan_directive_ignored_line'
    while self.peek()=~#'^['.s:yaml.whitespace.']'
        call self.forward()
    endwhile
    if self.peek() is# s:yaml.comment
        while self.peek()!~#'^['.s:yaml.linebreak.']\=$'
            call self.forward()
        endwhile
    endif
    let ch=self.peek()
    if ch!~#'^['.s:yaml.linebreak.']\=$'
        call self._raise(selfname, 'Scanner', ['ndirlend', ch], a:start_mark,
                    \    self.get_mark())
    endif
    call self.scan_line_break()
endfunction
"{{{3 load.Scanner.scan_anchor :: (self + (Class)) -> token
function s:F.class.Scanner.scan_anchor(tokenclass)
    let selfname='Scanner.scan_anchor'
    let start_mark=self.get_mark()
    let indicator=self.peek()
    let isalias=0
    if indicator is# s:yaml.anchorstart
        let isalias=1
    endif
    call self.forward()
    let length=0
    let ch=self.peek(length)
    while s:yaml.isanchorchar(ch)
        let length+=1
        let ch=self.peek(length)
    endwhile
    if !length
        call self._raise(selfname, 'Scanner',
                    \    [((isalias)?('nalname'):('nanname')), ch],
                    \    start_mark, self.get_mark())
    endif
    let value=self.prefix(length)
    call self.forward(length)
    let ch=self.peek()
    if ch!~#self.ANEND
        call self._raise(selfname, 'Scanner',
                    \    [((isalias)?('nalend'):('nanend')), ch],
                    \    start_mark, self.get_mark())
    endif
    let end_mark=self.get_mark()
    return s:_classes[a:tokenclass].new(value, start_mark, end_mark)
endfunction
"{{{3 load.Scanner.scan_tag :: (self + ()) -> token
function s:F.class.Scanner.scan_tag()
    let selfname='Scanner.scan_tag'
    let start_mark=self.get_mark()
    let ch=self.peek(1)
    if ch is# '<'
        let handle=''
        call self.forward(2)
        let suffix=self.scan_tag_uri('tag', start_mark)
        if self.peek()!=#'>'
            call self._raise(selfname, 'Scanner', ['ntagendgt', self.peek()],
                        \    start_mark, self.get_mark())
        endif
        call self.forward()
    else
        let length=1
        let use_handle=0 " :: Bool
        while ch!~#self.SEPREGEX
            if ch is# '!'
                let use_handle=1
                break
            endif
            let length+=1
            let ch=self.peek(length)
        endwhile
        let handle='!'
        if use_handle
            let handle=self.scan_tag_handle('tag', start_mark)
        else
            call self.forward()
        endif
        let suffix=self.scan_tag_uri('tag', start_mark)
    endif
    let ch=self.peek()
    if ch!~#self.SEPREGEX
        call self._raise(selfname, 'Scanner', ['ntagend', ch],
                    \    start_mark, self.get_mark())
    endif
    let value=[handle, suffix]
    let end_mark=self.get_mark()
    return s:_classes.TagToken.new(value, start_mark, end_mark)
endfunction
"{{{3 load.Scanner.scan_block_scalar :: (self + (style)) -> token
function s:F.class.Scanner.scan_block_scalar(style)
    let folded=(a:style is# '>')
    let chunks=[]
    let start_mark=self.get_mark()
    call self.forward()
    let [chomping, increment]=self.scan_block_scalar_indicators(start_mark)
    call self.scan_block_scalar_ignored_line(start_mark)
    let min_indent=self.indent+1
    if min_indent<1
        let min_indent=1
    endif
    if !increment
        let [breaks, max_indent, end_mark]=self.scan_block_scalar_indentation()
        let indent=max([min_indent, max_indent])
    else
        let indent=min_indent+increment-1
        let [breaks, end_mark]=self.scan_block_scalar_breaks(indent)
    endif
    let line_break=''
    while self.column==indent && !empty(self.peek())
        call extend(chunks, breaks)
        let leading_non_space=(self.peek()!~#'^['.s:yaml.whitespace.']$')
        let length=0
        while self.peek(length)!~#'^['.s:yaml.linebreak.']\=$'
            let length+=1
        endwhile
        call add(chunks, self.prefix(length))
        call self.forward(length)
        let line_break=self.scan_line_break()
        let [breaks, end_mark]=self.scan_block_scalar_breaks(indent)
        if self.column==indent && !empty(self.peek())
            if folded && line_break is# "\n" && leading_non_space &&
                        \self.peek()!~#'^['.s:yaml.whitespace.']$'
                if empty(breaks)
                    call add(chunks, ' ')
                endif
            else
                call add(chunks, line_break)
            endif
        else
            break
        endif
    endwhile
    if chomping!=0
        call add(chunks, line_break)
    endif
    if chomping==1
        call extend(chunks, breaks)
    endif
    return s:_classes.ScalarToken.new(join(chunks, ''), 0, start_mark, end_mark,
                \                     a:style)
endfunction
"{{{3 load.Scanner.scan_block_scalar_indicators :: (self + (mark)) -> (?, ?)
function s:F.class.Scanner.scan_block_scalar_indicators(start_mark)
    let selfname='Scanner.scan_block_scalar_indicators'
    let chomping=-1 " = None
    let increment=0 " = None
    let ch=self.peek()
    if ch==#'+' || ch==#'-'
        let chomping=(ch==#'+')
        call self.forward()
        let ch=self.peek()
    endif
    if ch=~#'^\d$'
        let increment=ch+0
        if increment==0
            call self._raise(selfname, 'Scanner', 'nullindnt', a:start_mark,
                        \    self.get_mark())
        endif
        call self.forward()
        let ch=self.peek()
        if chomping==-1 && (ch is# '+' || ch is# '-')
            let chomping=(ch is# '+')
            call self.forward()
        endif
    endif
    if ch!~#self.SEPREGEX
        call self._raise(selfname, 'Scanner', ['nblkind', ch], a:start_mark,
                    \    self.get_mark())
    endif
    return [chomping, increment]
endfunction
"{{{3 load.Scanner.scan_block_scalar_ignored_line :: (self + (mark)) -> _
function s:F.class.Scanner.scan_block_scalar_ignored_line(start_mark)
    let selfname='Scanner.scan_block_scalar_ignored_line'
    while self.peek()=~#'^['.s:yaml.whitespace.']$'
        call self.forward()
    endwhile
    if self.peek() is# s:yaml.comment
        while self.peek()!~#'^['.s:yaml.linebreak.']\=$'
            call self.forward()
        endwhile
    endif
    let ch=self.peek()
    if ch!~#'^['.s:yaml.linebreak.']\=$'
        call self._raise(selfname, 'Scanner', ['nignln', ch], a:start_mark,
                    \    self.get_mark())
    endif
    call self.scan_line_break()
endfunction
"{{{3 load.Scanner.scan_block_scalar_indentation :: (self + ()) -> (?,?,mark)
function s:F.class.Scanner.scan_block_scalar_indentation()
    let chunks=[]
    let max_indent=0
    let end_mark=self.get_mark()
    while self.peek()=~#'^['.(s:yaml.whitespace).(s:yaml.linebreak).']$'
        if self.peek()!~#'^['.s:yaml.whitespace.']$'
            call add(chunks, self.scan_line_break())
            let end_mark=self.get_mark()
        else
            call self.forward()
            if self.column>max_indent
                let max_indent=self.column
            endif
        endif
    endwhile
    return [chunks, max_indent, end_mark]
endfunction
"{{{3 load.Scanner.scan_block_scalar_breaks :: (self + (UInt)) -> (?,mark)
function s:F.class.Scanner.scan_block_scalar_breaks(indent)
    let chunks=[]
    let end_mark=self.get_mark()
    while self.column<a:indent && self.peek()=~#'^['.(s:yaml.whitespace).']$'
        call self.forward()
    endwhile
    while self.peek()=~#'^['.(s:yaml.linebreak).']$'
        call add(chunks, self.scan_line_break())
        let end_mark=self.get_mark()
        while self.column<a:indent &&
                    \self.peek()=~#'^['.(s:yaml.whitespace).']$'
            call self.forward()
        endwhile
    endwhile
    return [chunks, end_mark]
endfunction
"{{{3 load.Scanner.scan_flow_scalar :: (self + (style)) -> token
function s:F.class.Scanner.scan_flow_scalar(style)
    let double=(a:style==#'"')
    let chunks=[]
    let start_mark=self.get_mark()
    let quote=self.peek()
    call self.forward()
    call extend(chunks, self.scan_flow_scalar_non_spaces(double, start_mark))
    while self.peek()!=#quote
        call extend(chunks, self.scan_flow_scalar_spaces(double, start_mark))
        call extend(chunks,
                    \self.scan_flow_scalar_non_spaces(double, start_mark))
    endwhile
    call self.forward()
    let end_mark=self.get_mark()
    return s:_classes.ScalarToken.new(join(chunks, ''), 0, start_mark, end_mark,
                \                     a:style)
endfunction
"{{{3 load.Scanner.scan_flow_scalar_non_spaces :: (self + (Bool, mark))
"                                                                -> [ String ]
function s:F.class.Scanner.scan_flow_scalar_non_spaces(double, start_mark)
    let selfname='Scanner.scan_flow_scalar_non_spaces'
    let chunks=[]
    while 1
        let length=0
        while self.peek(length)!~#'^['.((a:double)?('"\\'):("'")).
                    \                  (s:yaml.whitespace).
                    \                  (s:yaml.linebreak).']\=$'
            let length+=1
        endwhile
        if length
            call add(chunks, self.prefix(length))
            call self.forward(length)
        endif
        let ch=self.peek()
        if ch is# "'" && self.peek(1) is# "'"
            call add(chunks, "'")
            call self.forward(2)
        elseif ch is# '\'
            call self.forward()
            let ch=self.peek()
            if has_key(self.ESCAPE_REPLACEMENTS, ch)
                call add(chunks, self.ESCAPE_REPLACEMENTS[ch])
                call self.forward()
            elseif has_key(self.ESCAPE_CODES, ch)
                let length=self.ESCAPE_CODES[ch]
                call self.forward()
                let k=0
                while k<length
                    if self.peek(k)!~#'^\x$'
                        call self._raise(selfname, 'Scanner',
                                    \    ['ndqs', length, self.peek()],
                                    \     a:start_mark, self.get_mark())
                    endif
                    let k+=1
                endwhile
                let code=str2nr(self.prefix(length), 16)
                if code==0
                    call self._warn(selfname, 'Scanner', 'strnull',
                                \   a:start_mark, self.get_mark())
                else
                    call add(chunks, nr2char(code))
                    call self.forward(length)
                endif
            elseif ch=~#'^['.(s:yaml.linebreak).']$'
                call self.scan_line_break()
                call extend(chunks, self.scan_flow_scalar_breaks(a:double,
                            \                                    a:start_mark))
            elseif ch is# '0'
                call self._warn(selfname, 'Scanner', 'strnull', a:start_mark,
                            \   self.get_mark())
            else
                call self._raise(selfname, 'Scanner', ['uknesc', ch],
                            \    a:start_mark, self.get_mark())
            endif
        else
            return chunks
        endif
    endwhile
endfunction
"{{{3 load.Scanner.scan_flow_scalar_spaces :: (self+(Bool,mark)) -> [ String ]
function s:F.class.Scanner.scan_flow_scalar_spaces(double, start_mark)
    let selfname='Scanner.scan_flow_scalar_spaces'
    let chunks=[]
    let length=0
    while self.peek(length)=~#'^['.(s:yaml.whitespace).']$'
        let length+=1
    endwhile
    let whitespaces=self.prefix(length)
    call self.forward(length)
    let ch=self.peek()
    if ch==#''
        call self._raise(selfname, 'Scanner', 'qseos', a:start_mark,
                    \    self.get_mark())
    elseif ch=~#'^['.(s:yaml.linebreak).']$'
        let line_break=self.scan_line_break()
        let breaks=self.scan_flow_scalar_breaks(a:double, a:start_mark)
        if line_break isnot# "\n"
            call add(chunks, line_break)
        elseif empty(breaks)
            call add(chunks, ' ')
        endif
        call extend(chunks, breaks)
    else
        call add(chunks, whitespaces)
    endif
    return chunks
endfunction
"{{{3 load.Scanner.scan_flow_scalar_breaks :: (self+(Bool,mark)) -> [ String ]
function s:F.class.Scanner.scan_flow_scalar_breaks(double, start_mark)
    let selfname='Scanner.scan_flow_scalar_breaks'
    let chunks=[]
    while 1
        let prefix=self.prefix(3)
        if (prefix is# '---' || prefix is# '...') &&
                    \self.peek(3)=~#self.SEPREGEX
            call self._raise(selfname, 'Scanner', 'docsepqs', a:start_mark,
                        \    self.get_mark())
        endif
        while self.peek()=~#'^['.s:yaml.whitespace.']$'
            call self.forward()
        endwhile
        if self.peek()=~#'^['.s:yaml.linebreak.']$'
            call add(chunks, self.scan_line_break())
        else
            return chunks
        endif
    endwhile
endfunction
"{{{3 load.Scanner.scan_plain :: (self + ()) -> token
function s:F.class.Scanner.scan_plain()
    let selfname='Scanner.scan_plain'
    let chunks=[]
    let start_mark=self.get_mark()
    let end_mark=start_mark
    let indent=self.indent+1
    let spaces=[]
    while 1
        let length=0
        if self.peek() is# s:yaml.comment
            break
        endif
        while 1
            let ch=self.peek(length)
            if ch=~#self.SEPREGEX ||
                        \(!self.flow_level &&
                        \ ch is# s:yaml.mappingvalue &&
                        \ self.peek(length+1)=~#self.SEPREGEX) ||
                        \(self.flow_level &&
                        \ ch=~#'^['.(s:yaml.flowindicator).
                        \           (s:yaml.mappingvalue).
                        \           (s:yaml.mappingkey).']$')
                break
            endif
            let length+=1
        endwhile
        if (self.flow_level && ch is# s:yaml.mappingvalue &&
                    \self.peek(length+1)!~#'^['.(s:yaml.flowindicator).
                    \                           (s:yaml.whitespace).
                    \                           (s:yaml.linebreak).']\=$')
            " XXX
            call self._warn(selfname, 'Scanner', 'ambcolon', start_mark,
                        \   self.get_mark(), s:_messages.ambcolonnote)
        endif
        if length==0
            break
        endif
        let self.allow_simple_key=0
        call extend(chunks, spaces)
        call add(chunks, self.prefix(length))
        call self.forward(length)
        let end_mark=self.get_mark()
        unlet spaces
        let spaces=self.scan_plain_spaces(indent, start_mark)
        if type(spaces)!=type([]) || empty(spaces) || self.peek()==#'#' ||
                    \(!self.flow_level && self.column<indent)
            break
        endif
    endwhile
    return s:_classes.ScalarToken.new(join(chunks, ''), 1, start_mark, end_mark,
                \                     '')
endfunction
"{{{3 load.Scanner.scan_plain_spaces :: (self + (UInt, mark)) -> [ String ]
function s:F.class.Scanner.scan_plain_spaces(indent, start_mark)
    let chunks=[]
    let length=0
    while self.peek(length)=~#'^['.(s:yaml.whitespace).']$'
        let length+=1
    endwhile
    let whitespaces=self.prefix(length)
    call self.forward(length)
    let ch=self.peek()
    if ch=~#'^['.s:yaml.linebreak.']$'
        let line_break=self.scan_line_break()
        let self.allow_simple_key=1
        let prefix=self.prefix(3)
        if (prefix==#'---' || prefix==#'...') && self.peek(3)=~#self.SEPREGEX
            return 0
        endif
        let breaks=[]
        while self.peek()=~#'^['.(s:yaml.whitespace).(s:yaml.linebreak).']$'
            if self.peek()=~#'^['.s:yaml.whitespace.']$'
                call self.forward()
            else
                call add(breaks, self.scan_line_break())
                let prefix=self.prefix(3)
                if (prefix is# '---' || prefix is# '...') &&
                            \self.peek(3)=~#self.SEPREGEX
                    return 0
                endif
            endif
        endwhile
        if line_break isnot# "\n"
            call add(chunks, line_break)
        elseif empty(breaks)
            call add(chunks, ' ')
        endif
        call extend(chunks, breaks)
    elseif !empty(whitespaces)
        call add(chunks, whitespaces)
    endif
    return chunks
endfunction
"{{{3 load.Scanner.scan_tag_handle :: (self + (?, mark)) -> String
function s:F.class.Scanner.scan_tag_handle(name, start_mark)
    let selfname='Scanner.scan_tag_handle'
    let istag=(a:name==#'tag')
    let ch=self.peek()
    if ch isnot# '!'
        call self._raise(selfname, 'Scanner',
                    \[((istag)?('ntagbang'):('ndirbang')), ch],
                    \a:start_mark, self.get_mark())
    endif
    let length=1
    let ch=self.peek(length)
    if ch!~#'^['.s:yaml.whitespace.']$'
        while ch=~#'^['.s:yaml.nsword.']$'
            let length+=1
            let ch=self.peek(length)
        endwhile
        if ch!~#'!'
            call self.forward(length)
            " XXX different from previous error message
            call self._raise(selfname, 'Scanner',
                        \[((istag)?('ntagbang'):('ndirbang')), ch],
                        \a:start_mark, self.get_mark())
        endif
        let length+=1
    endif
    let value=self.prefix(length)
    call self.forward(length)
    return value
endfunction
"{{{3 load.Scanner.scan_tag_uri :: (self + (?, mark)) -> String
function s:F.class.Scanner.scan_tag_uri(name, start_mark)
    let selfname='Scanner.scan_tag_uri'
    let istag=(a:name==#'tag')
    let chunks=[]
    let length=0
    let ch=self.peek(length)
    while ch=~#'^['.s:yaml.nstag.']$'
        if ch is# '%'
            call add(chunks, self.prefix(length))
            call self.forward(length)
            let length=0
            call add(chunks, self.scan_uri_escapes(a:name, a:start_mark))
        else
            let length+=1
        endif
        let ch=self.peek(length)
    endwhile
    if length
        call add(chunks, self.prefix(length))
        call self.forward(length)
    endif
    if empty(chunks)
        call self._raise(selfname, 'Scanner',
                    \    [((istag)?('ntaguri'):('ndiruri')), ch],
                    \    a:start_mark, self.get_mark())
    endif
    return join(chunks, '')
endfunction
"{{{3 load.Scanner.scan_uri_escapes :: (self + (?, mark)) -> String
function s:F.class.Scanner.scan_uri_escapes(name, start_mark)
    let selfname='Scanner.scan_uri_escapes'
    let istag=(a:name is# 'tag')
    let codes=[]
    let mark=self.get_mark()
    while self.peek() is# '%'
        call self.forward()
        let k=0
        while k<2
            if self.peek(k)!~#'^\x$'
                call self._raise(selfname, 'Scanner',
                            \    [((istag)?('nturiesc'):('nduriesc')),
                            \     self.peek(k)],
                            \    a:start_mark, self.get_mark())
            endif
            let k+=1
        endwhile
        call add(codes, str2nr(self.prefix(2), 16))
        call self.forward(2)
    endwhile
    " FIXME check for valid unicode
    return join(map(codes, 'eval(printf(''"\x%02x"'', v:val))'))
endfunction
"{{{3 load.Scanner.scan_line_break :: (self + ()) -> Bool
function s:F.class.Scanner.scan_line_break()
    let ch=self.peek()
    let r=''
    if ch is# "\r"
        call self.forward()
        let ch=self.peek()
        let r="\n"
    endif
    if ch is# "\n"
        call self.forward()
        let r="\n"
    endif
    return r
endfunction
"{{{1 Tokens
"{{{2 load.Token.__init__
function s:F.class.Token.__init__(super, start_mark, end_mark)
    let self.start_mark=a:start_mark
    let self.end_mark=a:end_mark
endfunction
"{{{2 load.DirectiveToken.__init__
function s:F.class.DirectiveToken.__init__(super, name, value, start_mark,
            \                             end_mark)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.name=a:name
    let self.value=a:value
endfunction
"{{{2 load.StreamStartToken.__init__
function s:F.class.StreamStartToken.__init__(super, start_mark, end_mark,
            \                               encoding)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.encoding=a:encoding
endfunction
"{{{2 load.AliasToken.__init__
function s:F.class.AliasToken.__init__(super, value, start_mark, end_mark)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.value=a:value
endfunction
"{{{2 load.AnchorToken.__init__
function s:F.class.AnchorToken.__init__(super, value, start_mark, end_mark)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.value=a:value
endfunction
"{{{2 load.TagToken.__init__
function s:F.class.TagToken.__init__(super, value, start_mark, end_mark)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.value=a:value
endfunction
"{{{2 load.ScalarToken.__init__
function s:F.class.ScalarToken.__init__(super, value, plain, start_mark,
            \                          end_mark, style)
    call call(a:super.__init__, [0, a:start_mark, a:end_mark], self)
    let self.value=a:value
    let self.plain=a:plain
    let self.style=a:style
endfunction
"{{{1 load.SimpleKey.__init__
function s:F.class.SimpleKey.__init__(super, token_number, required, index,
            \                        line, column, mark)
    let self.token_number=a:token_number
    let self.required=a:required
    let self.index=a:index
    let self.line=a:line
    let self.column=a:column
    let self.mark=a:mark
endfunction
"{{{1 
call s:_f.setclass('Token')
call s:_f.setclass('DirectiveToken',          'Token')
call s:_f.setclass('DocumentStartToken',      'Token')
call s:_f.setclass('DocumentEndToken',        'Token')
call s:_f.setclass('StreamStartToken',        'Token')
call s:_f.setclass('StreamEndToken',          'Token')
call s:_f.setclass('BlockSequenceStartToken', 'Token')
call s:_f.setclass('BlockMappingStartToken',  'Token')
call s:_f.setclass('BlockEndToken',           'Token')
call s:_f.setclass('FlowSequenceStartToken',  'Token')
call s:_f.setclass('FlowMappingStartToken',   'Token')
call s:_f.setclass('FlowSequenceEndToken',    'Token')
call s:_f.setclass('FlowMappingEndToken',     'Token')
call s:_f.setclass('KeyToken',                'Token')
call s:_f.setclass('ValueToken',              'Token')
call s:_f.setclass('BlockEntryToken',         'Token')
call s:_f.setclass('FlowEntryToken',          'Token')
call s:_f.setclass('AliasToken',              'Token')
call s:_f.setclass('AnchorToken',             'Token')
call s:_f.setclass('TagToken',                'Token')
call s:_f.setclass('ScalarToken',             'Token')

call s:_f.setclass('SimpleKey')

call s:_f.setclass('Scanner')
"{{{1 
call frawor#Lockvar(s:, '')
" vim: ft=vim:ts=8:fdm=marker:fenc=utf-8:fmr={{{,}}}
