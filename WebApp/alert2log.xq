(:
 insérer un élément d'alerte dans une illustration
:)


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

let $res := "foo"  
return 

local:replaceIll(collection($corpus)//analyseAlto[(metad/ID =$id)]//ill[@n=$n]) 

