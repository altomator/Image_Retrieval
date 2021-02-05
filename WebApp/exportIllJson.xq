(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
declare option output:method 'text';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)

declare  function local:exportIllJSON($ill as element()) {    
   let $tmp := json:serialize($ill,map { 'format': 'jsonml','indent': 'yes' } )
   return  concat("[""metadata"", {""id"":""",$id,"""},", $tmp,"]" )      
      
};

try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  let $msg := concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>")
  return $msg
) else ( 
 local:exportIllJSON(collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$n]) 
)}
 catch * {  
       let $msg := concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?><message> Erreur exécution [ ", $err:code, " ]</message>")
       return $msg
   }
