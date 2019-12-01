(:
 mettre à jour l'annotation des objets :
 filtrer un tag
 supprimer un tag
:)


declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external   ;
declare variable $id as xs:string external    ; (: document ID :)
declare variable $idIll as xs:string external ; (: illustration ID :)
declare variable $cbir as xs:string external; (: cbir mode :)
declare variable $source as xs:string external;
declare variable $tagOld as xs:string external; (: tag :)
declare variable $tag as xs:string external  ;  (: new tag or D or FT :)

declare %updating function local:replaceContent($ci as element()) { 

     if ($tag = "D") then ( (: delete the tag :)
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Tag supprime</p></message>"),  
      delete node $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )        
    else if ($tag = "FT") then ( (: filter the uncorrect tag :)
      try {
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Tag filtre</p></message>"), 
      delete node $ci/@filtre,
      insert node  (attribute filtre { "1" })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }         
   )   
   else ( (: create a new tag and filter the old one :)
      try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Etiquette mise a jour : <b>",$tagOld,"</b></p></message>")),
      delete node $ci/@filtre,
      insert node  (attribute filtre { "1" })  into  $ci,
      insert node (if ($ci/@edit) then () else (attribute edit { "1" })) into $ci,
      delete node $ci/@time,
      insert node  (attribute time {fn:current-dateTime()}) into  $ci,
      insert node (copy $tmp := $ci
      modify (
        replace value of node $tmp/@source with $source, 
        replace value of node $tmp/@CS with "1.0", 
        replace value of node $tmp with $tag
        )   
      return $tmp) into $ci/.. 
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }    
    )     
};


for $objet in collection($corpus)//analyseAlto[(metad/ID=$id)]//ill[@n=$idIll]//contenuImg[@source=$cbir and text()=$tagOld]
let $res :="foo"  
return local:replaceContent($objet)

