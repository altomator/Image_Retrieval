(:
 renumber the illustrations
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external  ;    (: document ID :)
declare variable $page as xs:string external  ;  (: page number :)

declare %updating function local:renumberIlls($ills as element()) { 
  for $ill at $position in $ills/ill 
    let $n := concat ($page,'-',$position)
    return  
      try {    
       update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Renumérotation de l'illustration ", $ill/@n, " -> ",$n," </p>
        </message>")
       ) , 
          
        delete node $ill/@n,
        insert node (attribute n {$n}) into $ill
     
     } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
    }
      
};


try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>"))
) else (
     
   local:renumberIlls(collection($corpus)//analyseAlto[(metad/ID =$id)]//page[@ordre=$page]/ills)
   
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
