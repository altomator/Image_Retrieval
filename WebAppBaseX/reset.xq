(:
 reset the illustration segmentation
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;    (: document ID :)
declare variable $idIll as xs:string external   ;  (: illustration number :)
declare variable $source as xs:string external   ;
declare variable $l as xs:integer external   ; 
declare variable $h as xs:integer external   ;


declare %updating function local:copyIll($ill as element()) {    
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Reset segmentation</p>
        </message>"
       ) ,
     
         
        replace value of node $ill/@x with 1,
        replace value of node $ill/@y with 1,
        replace value of node $ill/@w with $l, 
        replace value of node $ill/@h with $h          
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
 local:copyIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$idIll]) 
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }
