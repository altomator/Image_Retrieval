(:
 change the segmentation
:)


declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;    (: document ID :)
declare variable $idIll as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external    ;
declare variable $x as xs:integer external  ;
declare variable $y as xs:integer external  ;
declare variable $l as xs:integer external  ;
declare variable $h as xs:integer external  ;

declare %updating function local:updateIll($ill as element()) { 
   
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Demande de segmentation sur l'illustration </p>
        </message>"
       ) ,
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill,
      insert node (if ($ill/@source) then () else (attribute source { $source }))  into  $ill,
      insert node (if ($ill/@seg) then () else (attribute seg { "1" })) into $ill, 
      delete node $ill/@x,
      insert node (attribute x { $x }) into $ill,   
      delete node $ill/@y,
      insert node (attribute y { $y }) into $ill, 
      delete node $ill/@w,
      insert node (attribute w { $l }) into $ill, 
      delete node $ill/@h,
      insert node (attribute h { $h }) into $ill     
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
local:updateIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$idIll and not(@filtre)]) 

