(:
 
:)


declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external  ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external   ;


declare %updating function local:updateIll($ill as element()) {   
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message><p>Illustration filtrée en <b>publicité</b></p></message>"
       ) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :)
      insert node (if ($ill/@pub) then () else (attribute pub { "1" })) into $ill,
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">publicite</genre> into $ill,
      insert node <genre source="final">publicite</genre> into $ill
                
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
      
};

let $res := "foo"  
return 
local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 

