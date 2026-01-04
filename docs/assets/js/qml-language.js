// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// QML language definition for Monaco Editor
//

// Register QML language with Monaco
function registerQmlLanguage(monaco) {
    // Register the language
    monaco.languages.register({ id: 'qml' });

    // Set language configuration (brackets, comments, etc.)
    monaco.languages.setLanguageConfiguration('qml', {
        comments: {
            lineComment: '//',
            blockComment: ['/*', '*/']
        },
        brackets: [
            ['{', '}'],
            ['[', ']'],
            ['(', ')']
        ],
        autoClosingPairs: [
            { open: '{', close: '}' },
            { open: '[', close: ']' },
            { open: '(', close: ')' },
            { open: '"', close: '"' },
            { open: "'", close: "'" }
        ],
        surroundingPairs: [
            { open: '{', close: '}' },
            { open: '[', close: ']' },
            { open: '(', close: ')' },
            { open: '"', close: '"' },
            { open: "'", close: "'" }
        ]
    });

    // Monarch tokenizer for syntax highlighting
    monaco.languages.setMonarchTokensProvider('qml', {
        keywords: [
            'import', 'property', 'signal', 'readonly', 'alias', 'required',
            'function', 'if', 'else', 'for', 'while', 'do',
            'switch', 'case', 'default', 'break', 'continue',
            'return', 'try', 'catch', 'finally', 'throw',
            'true', 'false', 'null', 'undefined',
            'var', 'let', 'const', 'this', 'typeof', 'instanceof',
            'new', 'delete', 'in', 'of', 'as'
        ],

        typeKeywords: [
            'int', 'real', 'double', 'bool', 'string', 'var',
            'list', 'color', 'url', 'date', 'rect', 'point',
            'size', 'font', 'vector2d', 'vector3d', 'vector4d',
            'quaternion', 'matrix4x4'
        ],

        operators: [
            '=', '>', '<', '!', '~', '?', ':',
            '==', '<=', '>=', '!=', '&&', '||', '++', '--',
            '+', '-', '*', '/', '&', '|', '^', '%', '<<',
            '>>', '>>>', '+=', '-=', '*=', '/=', '&=', '|=',
            '^=', '%=', '<<=', '>>=', '>>>='
        ],

        symbols: /[=><!~?:&|+\-*\/\^%]+/,

        escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

        tokenizer: {
            root: [
                // Import statements
                [/import\s+/, 'keyword', '@import'],

                // Component names (start with uppercase)
                [/[A-Z][a-zA-Z0-9]*/, 'type.identifier'],

                // Property bindings (identifier followed by :)
                [/[a-z_][a-zA-Z0-9]*(?=\s*:)/, 'variable'],

                // id: special property
                [/\bid\b/, 'keyword'],

                // Identifiers and keywords
                [/[a-z_$][a-zA-Z0-9_$]*/, {
                    cases: {
                        '@keywords': 'keyword',
                        '@typeKeywords': 'type',
                        '@default': 'identifier'
                    }
                }],

                // Whitespace
                { include: '@whitespace' },

                // Delimiters and operators
                [/[{}()\[\]]/, '@brackets'],
                [/[<>](?!@symbols)/, '@brackets'],
                [/@symbols/, {
                    cases: {
                        '@operators': 'operator',
                        '@default': ''
                    }
                }],

                // Numbers
                [/\d*\.\d+([eE][\-+]?\d+)?/, 'number.float'],
                [/0[xX][0-9a-fA-F]+/, 'number.hex'],
                [/\d+/, 'number'],

                // Delimiter: after number because of .\d floats
                [/[;,.]/, 'delimiter'],

                // Strings
                [/"([^"\\]|\\.)*$/, 'string.invalid'],
                [/"/, 'string', '@string_double'],
                [/'([^'\\]|\\.)*$/, 'string.invalid'],
                [/'/, 'string', '@string_single']
            ],

            import: [
                [/[A-Za-z_][A-Za-z0-9_.]*/, 'namespace'],
                [/\d+\.\d+/, 'number'],
                [/as\s+/, 'keyword'],
                [/$/, '', '@pop'],
                [/\s+/, 'white']
            ],

            whitespace: [
                [/[ \t\r\n]+/, 'white'],
                [/\/\*/, 'comment', '@comment'],
                [/\/\/.*$/, 'comment']
            ],

            comment: [
                [/[^\/*]+/, 'comment'],
                [/\*\//, 'comment', '@pop'],
                [/[\/*]/, 'comment']
            ],

            string_double: [
                [/[^\\"]+/, 'string'],
                [/@escapes/, 'string.escape'],
                [/\\./, 'string.escape.invalid'],
                [/"/, 'string', '@pop']
            ],

            string_single: [
                [/[^\\']+/, 'string'],
                [/@escapes/, 'string.escape'],
                [/\\./, 'string.escape.invalid'],
                [/'/, 'string', '@pop']
            ]
        }
    });
}

// Theme matching Clayground website
function createQmlTheme(monaco) {
    monaco.editor.defineTheme('clayground-dark', {
        base: 'vs-dark',
        inherit: true,
        rules: [
            { token: 'keyword', foreground: 'FF7B72', fontStyle: 'bold' },
            { token: 'type', foreground: '79C0FF' },
            { token: 'type.identifier', foreground: '7EE787', fontStyle: 'bold' },
            { token: 'variable', foreground: 'FFA657' },
            { token: 'string', foreground: 'A5D6FF' },
            { token: 'number', foreground: '79C0FF' },
            { token: 'comment', foreground: '6E7681', fontStyle: 'italic' },
            { token: 'operator', foreground: '00D9FF' },
            { token: 'namespace', foreground: 'D2A8FF' }
        ],
        colors: {
            'editor.background': '#0D1117',
            'editor.foreground': '#E6EDF3',
            'editor.lineHighlightBackground': '#161B22',
            'editor.selectionBackground': '#264F78',
            'editorCursor.foreground': '#00D9FF',
            'editorLineNumber.foreground': '#6E7681',
            'editorLineNumber.activeForeground': '#E6EDF3'
        }
    });
}

// Export for use in playground.js
window.registerQmlLanguage = registerQmlLanguage;
window.createQmlTheme = createQmlTheme;
