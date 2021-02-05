(:
 insérer un élément d'alerte dans une illustration
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";


declare namespace functx = "http://www.functx.com";
declare namespace file = "http://expath.org/ns/file";

(: declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;
declare variable $n as xs:string external   ;  (: illustration number :)
declare variable $pb as xs:string external   ; (: alert :)
declare variable $source as xs:string external   ;


declare variable $logFile := "../webapp/static/log.txt" ;

declare %updating function local:replaceIll($ill as element()) { 
   
    if (($pb != ""))  then (
     file:append-text-lines($logFile, concat($corpus,",",$id,",",$n,",",$pb,",",fn:current-dateTime()),"UTF-8")    
    )           
};

try{
let $url := $corpus  
return 
if  (not(gp:isAlphaNum($corpus))) then (
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
