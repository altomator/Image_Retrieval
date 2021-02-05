let $root := "/Users/bnf/Documents/BnF/Dev/GallicaPix/_Production/datasets/JSON"
for $doc in collection('test')
let $name := concat($root,document-uri($doc))
let $json := json:serialize($doc, map { 'format': 'jsonml','indent': 'yes' })
return file:write($name, $json)