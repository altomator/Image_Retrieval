(:
 filtrer des tags
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external := "test"   ;
declare variable $id as xs:string external := "bpt6k4600009z"  ; (: document ID :)
declare variable $idIll as xs:string external := "12-2" ; (: illustration ID :)
declare variable $tagOld as xs:string external := "person"; (: object ID :)
declare variable $source as xs:string external := "hm";


declare %updating function local:filterContent($ci as element()*) {    
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Objet supprime</p></message>"),  
      delete node $ci/@filtre,
      insert node  (attribute filtre { "1" })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci
      
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
 for $objet in collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$idIll]//contenuImg[text()=$tagOld]
 let $res :="foo"  
 return local:filterContent($objet)
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
