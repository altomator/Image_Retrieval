(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external   ;
declare variable $mode as xs:string external   ;

(: avoiding Server-side request forgery :)
declare  function local:isUrl($string as xs:string) as xs:boolean { 
   matches($string,'ftp') or matches($string,'http')
};

declare %updating function local:updateIll($ill as element()) {    
      try {    
       update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Mode couleur : <b>",$mode,"</b></p></message>")) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "1" })) into $ill,
      
      delete node $ill/@couleur,
      insert node (attribute couleur { $mode }) into $ill
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
      
};

(:declare %updating function local:replaceCouleur($ill as element()) {
  if (($color != "undef") and ($ill/@couleur != $color)) then (
  db:output("Update successful."), replace value of node $ill/@couleur with $color
  )
  else ()
}; 
:)

try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>"))
) else (
 local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
