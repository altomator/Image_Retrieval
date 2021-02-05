(:
 ajout d'un visage
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;  (: document ID :)
declare variable $idIll as xs:string external   ;  (: illustration ID :)
declare variable $idVisage as xs:string external   ;  (: #visage  :)
declare variable $sexe as xs:string external;  (: M, F, P :) 
declare variable $source as xs:string external   ;
declare variable $x as xs:integer external ;
declare variable $y as xs:integer external ;
declare variable $l as xs:integer external ;
declare variable $h as xs:integer external ;

declare %updating function local:addFace($ill as element()) {    
       try {
      update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Visage signalé dans l'illustration </p></message>"),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :) 
      insert node <contenuImg source='{data($source)}' n='{data($idIll)}-{data($idVisage)}' sexe='{data($sexe)}' CS='1' x='{data($x)}' y='{data($y)}' w='{data($l)}' h='{data($h)}' time="{fn:current-dateTime()}">face</contenuImg>  into $ill
      
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
 local:addFace(collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$idIll]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
