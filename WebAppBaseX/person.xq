(:
 Mise à jour des informations de présence de personnes pour une illustration
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $person as xs:string external   ; (: man, woman, child, crowd, mixte :)
declare variable $source as xs:string external   ;


declare %updating function local:replaceIll($ill as element()) {    
    if (($person != ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Personne signalée dans l'illustration : <b>",$person,"</b></p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "1" })) into $ill, (: ajout d'un attribut edit :) 
      insert node <contenuImg source='{data($source)}' CS='1' lang='en' time="{fn:current-dateTime()}">{data($person)}</contenuImg> into $ill,
      if ($person = "couple") then (
          insert node <contenuImg source='{data($source)}' CS='1' lang='en' time="{fn:current-dateTime()}">man</contenuImg> into $ill,
          insert node <contenuImg source='{data($source)}' CS='1' lang='en' time="{fn:current-dateTime()}">woman</contenuImg> into $ill
        ) else(),
      insert node <contenuImg source='{data($source)}' CS='1' lang='en' time="{fn:current-dateTime()}">person</contenuImg> into $ill 
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
 local:replaceIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
