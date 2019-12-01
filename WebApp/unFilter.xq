(:
 
:)


declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external   ;


declare %updating function local:updateIll($ill as element()) {    
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Illustration défiltrée </p>
        </message>"
       ) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "1" })) into $ill, (: ajout d'un attribut edit :)
      delete node $ill/@filtre,
      delete node $ill/@filtrehm,
      delete node  $ill/genre[@source="hm"]       
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
      
};

(:declare %updating function local:replaceCouleur($ill as element()) {
  if (($color != "undef") and ($ill/@couleur != $color)) then (
  db:output("Update successful."), replace value of node $ill/@couleur with $color
  )
  else ()
}; 
:)

let $res := "foo"  
return 
local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 

