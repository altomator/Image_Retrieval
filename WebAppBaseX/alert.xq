(:
 insérer un élément d'alerte dans une illustration
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
 declare option output:method 'html';
(: 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $pb as xs:string external   ; (: alert :)
declare variable $source as xs:string external   ;


declare %updating function local:replaceIll($ill as element()) { 
   
    if (($pb != ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Problème signalé dans l'illustration : <b>",$pb,"</b></p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "1" })) into $ill, (: ajout d'un attribut edit :) 
      insert node <alert source='{data($source)}'  time="{fn:current-dateTime()}">{data($pb)}</alert> into $ill
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
 local:replaceIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n])) 
} catch * {
         update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
