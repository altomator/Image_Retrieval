(:
 mettre à jour l'annotation des visages : genre
 supprimer un visage
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external    ; (: document ID :)
declare variable $idIll as xs:string external    ; (: illustration ID :)
declare variable $idVsg as xs:string external ; (: visage ID :)
declare variable $cmd as xs:string external  ;  (: M, F, C, D, FT, N :)
declare variable $source as xs:string external;

declare %updating function local:replaceContent($ci as element()) { 

    if (($cmd = "F") or ($cmd = "M" ) or ($cmd = "C" ))  then (
      try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Visage de genre : <b>",$cmd,"</b></p></message>")),
      delete node $ci/@sexe, 
      insert node  (attribute sexe { $cmd })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }    
    ) 
   else if ($cmd = "D") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Visage supprime</p></message>"),  
      delete node $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )  
    else if ($cmd = "N") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Visage nomme</p></message>"),  
      insert node (if ($ci/@nom) then () else (attribute nom { "1" })) into $ci     
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )    
    else if ($cmd = "FT") then (
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Visage filtre</p></message>"),  
      delete node $ci/@filtre,
      insert node  (attribute filtre { "true" })  into  $ci,
      delete node $ci/@sexe,
      insert node  (attribute sexe { "FT" })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )   
   else (update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message><p>Aucune mise à jour</p></message>"))      
};

try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>"))
) else (
 for $visage in collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$idIll]//contenuImg[@n=$idVsg and text()="face"] 
 return local:replaceContent($visage)
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
