(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external  ;  (: illustration number :)
declare variable $subtitle as xs:string external   ; 
declare variable $caption as xs:string external  ; 
declare variable $txt as xs:string external  ; 
declare variable $source as xs:string external   ; 

declare %updating function local:replaceIll($ill as element()) {    
    if (($subtitle != "") or  ($caption != "") or ($txt != ""))  then (
       try {
      update:output(concat ("<?xml version=""1.0"" encoding=""UTF-8""?>
      <?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
      
       <message>
       <p><b>Titre mis à jour :</b> ",$subtitle,"</p>      
       <p><b>Légende mise à jour :</b> ",$caption,"</p>
       <p><b>Texte mis à jour :</b> ",$txt,"</p>
       </message>")),
      insert node (if ($ill/@editocr) then () else (attribute editocr { "true" })) into $ill, (: ajout d'un attribut edit :)
      (: sauvegarder valeur courante :)       
      (if (($subtitle != "") and ($ill/titraille)) then (rename node $ill/titraille as "titraille_sav") else ()),
      insert node (if ($subtitle != "") then (<titraille source='{data($source)}' time="{fn:current-dateTime()}">{data($subtitle)}</titraille>) else ()) into $ill,    
     (if (($caption != "") and ($ill/leg)) then (rename node $ill/leg as "leg_sav") else ()),
      insert node (if ($caption != "") then (<leg source='{data($source)}' time="{fn:current-dateTime()}">{data($caption)}</leg>) else ()) into $ill,
      (if (($txt != "")  and ($ill/txt)) then (rename node $ill/txt as "txt_sav") else ()),
      insert node (if ($txt != "") then (<txt source='{data($source)}' time="{fn:current-dateTime()}">{data($txt)}</txt>) else ()) into $ill
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
