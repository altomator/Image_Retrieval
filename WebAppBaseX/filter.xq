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


(: we may have multiple illustrations with same id :)
declare %updating function local:updateIll($elements as element()*) { 
     for $ill in head($elements) (: delete only the first :)
     return  
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Illustration filtrée </p>
        </message>"
       ) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "1" })) into $ill, (: ajout d'un attribut edit :)
      insert node (if ($ill/@filtrehm) then () else (attribute filtrehm { "1" })) into $ill,
      insert node (if ($ill/@filtre) then () else (attribute filtre { "1" })) into $ill,
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">filtre</genre> into $ill,
      delete node $ill/genre[@source="final"],
      insert node <genre source="final">filtre</genre> into $ill       
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
 local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
