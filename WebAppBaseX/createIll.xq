(:
 create a new illustration
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;    (: document ID :)
declare variable $page as xs:string external   ; 
declare variable $idIll as xs:string external  ;
declare variable $w as xs:integer external  ;
declare variable $h as xs:integer external  ;


declare %updating function local:createIll($page as element()) {  
  if ($page/ills) then (
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Nouvelle illustration </p>
        </message>"
       ) ,         
       insert node <ill n='{data($idIll)}' edit='1' x='50' y='50' w='{data($w)}' h='{data($h)}' time="{fn:current-dateTime()}"></ill> into $page/ills    
    } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    )
    else ( try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Nouvelle illustration </p>
        </message>"
       ) ,          
       insert node <ills><ill n='{data($idIll)}' edit='1' x='50' y='50' w='{data($w)}' h='{data($h)}' time="{fn:current-dateTime()}"></ill></ills> into $page
        } catch * {
        update:output('Erreur [' || $err:code || ']: ' || $err:description)
      }
    )   
};


try{
let $url := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>"))
) else ( 
 let $page := collection($corpus)//analyseAlto[(metad/ID =$id)]//page[@ordre=$page]
 
 return
 local:createIll($page)
)}
 catch * {  
        update:output(concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur exécution [ ", $err:code, " ]</message>"))
   }