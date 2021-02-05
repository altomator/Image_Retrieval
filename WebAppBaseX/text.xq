(:
 mettre à jour l'annotation des blocs de texte 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html'; :)
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external    ; (: document ID :)
declare variable $idIll as xs:string external    ; (: illustration ID :)
declare variable $idTxt as xs:string external ; (: texte ID :)
declare variable $cmd as xs:string external  ;  (: D, FT, I, page, leg, id, txt :)
declare variable $source as xs:string external;
declare variable $texte as xs:string external := "";


declare %updating function local:replaceContent($ci as element()) { 
    if ($cmd = "D") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Texte supprime</p></message>"),  
      delete node $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )  
    else if (($cmd = "page") or ($cmd = "leg") or ($cmd = "txt") or ($cmd = "id")) then (
      try {
       update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Texte de niveau ",$cmd,"</p></message>")), 
       delete node $ci/@type,     
       insert node  (attribute type { $cmd })  into  $ci ,
       insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci, 
       delete node $ci/@time,
       insert node  (attribute time {fn:current-dateTime()}) into  $ci 
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )  
   else if ($cmd = "I") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Texte inséré</p></message>"),  
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci,
      replace value of node $ci with $texte
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )   
    else if ($cmd = "FT") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Texte filtre</p></message>"),  
      insert node  (attribute filtre { "true" })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )   
   else (update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message><p>Commande inconnue</p></message>"))      
};

try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
    (: do nothing :)
    update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $url," ]</message>"))
) else (
 for $texte in collection($corpus)//analyseAlto[(metad/ID=$id)]//contenuText[@n=$idTxt]
 let $res := $texte  
 return local:replaceContent($texte)
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }

