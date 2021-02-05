(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html'; 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $iptc as xs:string external  ; (: IPTC theme :)
declare variable $illType as xs:string external  ; (: dessin, gravure, etc. :)
declare variable $color as xs:string external   ; (: couleur :)
declare variable $source as xs:string external   ;


declare %updating function local:replaceIll($ill as element()) { 
    (: pas trouve moins tordu pour updater tout les criteres ... :)
    if (($iptc = "") and  ($illType = "") and ($color != ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?>
      <?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
      
       <message>      
       <p><b>Couleur mise à jour :</b> ",$color,"</p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :) 
      delete node $ill/@couleur,
      insert node (attribute couleur { $color }) into $ill  
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    ) 
    else if (($iptc != "") and  ($illType = "") and ($color = ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Thème mis à jour :</b> ",$iptc,"</p></message>")), 
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :)
      insert node <theme source='{data($source)}' time="{fn:current-dateTime()}">{data($iptc)}</theme> into $ill, 
      delete node $ill/theme[@source="final"], (: supprimer et remplacer :)  
      insert node <theme source="final">{data($iptc)}</theme> into $ill 
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    ) 
    else if (($iptc != "") and  ($illType = "") and ($color != ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Thème mis à jour :</b> ",$iptc," - <b>couleur mise à jour :</b> ",$color,"</p></message>")), 
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :)
      insert node <theme source='{data($source)}' time="{fn:current-dateTime()}">{data($iptc)}</theme> into $ill, 
      delete node $ill/theme[@source="final"], (: supprimer et remplacer :)  
      insert node <theme source="final">{data($iptc)}</theme> into $ill ,
      delete node $ill/@couleur,
      insert node (attribute couleur { $color }) into $ill 
      } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    )           
    else if (($illType != "") and ($iptc = "") and ($color = "")) then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Genre mis à jour :</b> ",$illType,"</p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :) 
      (: inserer le  genre :)      
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">{data($illType)}</genre> into $ill,
      (: creer le  genre final  :) 
      delete node $ill/genre[@source="final"],
      insert node <genre source="final" >{data($illType)}</genre> into $ill,
      (: ajout d'un attribut pub s'il n'existe pas deja
      insert node (if (($illType = "publicite") and (not ($ill/@pub))) then (attribute pub { "true" }) else ()) into $ill,
      delete node (if (not (contains($illType,'publicite')) and ($ill/@pub)) then ( $ill/@pub ) else ()) ,  :)
      (: gestion des  attributs filtre :) 
      insert node (if (contains($illType,'filtre') and (not ($ill/@filtre))) then (attribute filtre { "true" },attribute filtrehm { "true" }) else ()) into $ill,
      delete node (if (not (contains($illType,'filtre')) and ($ill/@filtre)) then ( $ill/@filtre ) else ())        
       } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    ) 
    else if (($illType != "") and ($iptc = "") and ($color != "")) then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Genre mis à jour :</b> ",$illType," - <b>couleur creee :</b> ",$color,"</p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :)
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">{data($illType)}</genre> into $ill,
      delete node $ill/genre[@source="final"],
      insert node <genre source="final">{data($illType)}</genre> into $ill, 
       (: gestion des  attributs filtre :) 
      insert node (if (contains($illType,'filtre') and (not ($ill/@filtre))) then (attribute filtre { "true" },attribute filtrehm { "true" }) else ()) into $ill,
      delete node (if (not (contains($illType,'filtre')) and ($ill/@filtre)) then ( $ill/@filtre ) else ()) ,     
      delete node $ill/@couleur,
      insert node (attribute couleur { $color }) into $ill     
       } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    )           
   else if (($illType != "") and ($iptc != "") and ($color = "")) then (
      try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Thème mis à jour :</b> ",$iptc, " - <b>genre cree :</b> ",$illType,"</p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :) 
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">{data($illType)}</genre> into $ill,
      delete node $ill/genre[@source="final"],
      insert node <genre source="final" >{data($illType)}</genre> into $ill,
       (: gestion des  attributs filtre :) 
      insert node (if (contains($illType,'filtre') and (not ($ill/@filtre))) then (attribute filtre { "true" },attribute filtrehm { "true" }) else ()) into $ill,
      delete node (if (not (contains($illType,'filtre')) and ($ill/@filtre)) then ( $ill/@filtre ) else ()) ,  
      insert node <theme source='{data($source)}' time="{fn:current-dateTime()}">{data($iptc)}</theme> into $ill,
       delete node $ill/theme[@source="final"], (: supprimer et remplacer :)  
      insert node <theme source="final">{data($iptc)}</theme> into $ill      
       } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    )  
    else if (($illType != "") and ($iptc != "") and ($color != "")) then (
      try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p><b>Thème mis à jour :</b> ",$iptc, " - <b>genre cree :</b> ",$illType," - couleur creee : ",$color,"</p></message>")),
      insert node (if ($ill/@edit) then () else (attribute edit { "true" })) into $ill, (: ajout d'un attribut edit :)
      insert node <genre source='{data($source)}' time="{fn:current-dateTime()}">{data($illType)}</genre> into $ill,
      delete node $ill/genre[@source="final"],
      insert node <genre source="final">{data($illType)}</genre> into $ill, 
       (: gestion des  attributs filtre :) 
      insert node (if (contains($illType,'filtre') and (not ($ill/@filtre))) then (attribute filtre { "true" },attribute filtrehm { "true" }) else ()) into $ill,
      delete node (if (not (contains($illType,'filtre')) and ($ill/@filtre)) then ( $ill/@filtre ) else ()) ,     
      insert node <theme source='{data($source)}' time="{fn:current-dateTime()}">{data($iptc)}</theme> into $ill,
       delete node $ill/theme[@source="final"], (: supprimer et remplacer :)  
      insert node <theme source="final">{data($iptc)}</theme> into $ill ,
      delete node $ill/@couleur,
      insert node (attribute couleur { $color }) into $ill       
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
