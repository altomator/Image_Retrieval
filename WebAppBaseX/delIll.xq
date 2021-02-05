(:
 supprimer une ill.
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
       <p>Illustration supprimée </p>
        </message>"
       ) ,
      
      delete node $ill      
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
