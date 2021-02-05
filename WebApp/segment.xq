(:
 change the segmentation
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;    (: document ID :)
declare variable $idIll as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external    ;
declare variable $x as xs:integer external  ; (: new coordinates :)
declare variable $y as xs:integer external  ;
declare variable $l as xs:integer external  ;
declare variable $h as xs:integer external  ;


declare %updating function local:updateIll($ill as element()) {   
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Nouvelle segmentation de l'illustration </p>
        </message>"
       ) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill,
      insert node (if ($ill/@source) then () else (attribute source { $source }))  into  $ill,
      insert node (if ($ill/@seg) then () else (attribute seg { "1" })) into $ill, 
      delete node $ill/@x,
      insert node (attribute x { $x }) into $ill,   
      delete node $ill/@y,
      insert node (attribute y { $y }) into $ill, 
      delete node $ill/@w,
      insert node (attribute w { $l }) into $ill, 
      delete node $ill/@h,
      insert node (attribute h { $h }) into $ill     
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
 local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$idIll and not(@filtre)]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }