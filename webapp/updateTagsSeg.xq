(:
 mise à jour des coordonnées des tags internes
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ; (: document ID :)
declare variable $idIll as xs:string external  ; (: illustration ID :)
declare variable $x0 as xs:integer external ; (: old origin :)
declare variable $y0 as xs:integer external ;
declare variable $xn as xs:integer external ; (: new origin :)
declare variable $yn as xs:integer external ;


declare %updating function local:update($ci as element()*) { 
      let $x_ci := $ci/@x
      let $y_ci := $ci/@y
      return    
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Objet mis à jour (x,y,l,h)</p></message>"),  
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci,
      delete node $ci/@x,
      insert node (attribute x { $x_ci + $x0 - $xn }) into $ci,   
      delete node $ci/@y,
      insert node (attribute y { $y_ci + $y0 - $yn }) into $ci
      
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
 for $objet in collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$idIll]//contenuImg
   let $res :="foo"  
   return local:update($objet)
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
