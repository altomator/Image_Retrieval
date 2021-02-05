(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
 
declare variable $corpus as xs:string external  ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $type as xs:string external  ;
declare variable $source as xs:string external  ;
declare variable $action as xs:string external := "I"  ; (: I = one ill, "D", all illustrations :)

declare %updating function local:replaceIll($ill as element()) {    
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?>
      <?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
      
       <message>                
       <p>Fonction mise à jour en <b>",$type,"</b></p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :) 
      (: inserer la fonction  :)      
      insert node <fonction source='{data($source)}' time="{fn:current-dateTime()}">{data($type)}</fonction> into $ill,
      insert node (if (($type = "couverture") and (not($ill/@une))) then (attribute une { "true" }) else ()) into $ill,
      (: creer la fonction finale  :) 
      delete node $ill/fonction[@source="final"],
      delete node $ill/@pub, 
      delete node $ill/@filtre,
      delete node $ill/@filtrehm,
      insert node <fonction source="final">{data($type)}</fonction> into $ill
               
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
 if ($action="I") then (
   local:replaceIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) )
 else (
   for $ill in collection($corpus)//analyseAlto[(metad/ID=$id)]//ill 
   return local:replaceIll($ill)
 )
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
