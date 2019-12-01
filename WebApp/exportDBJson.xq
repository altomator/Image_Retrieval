(:
 
:)


declare namespace functx = "http://www.functx.com";
declare option output:method 'text';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;


declare  function local:exportIllJSON($ill as element()) {    
   
   let $tmp := json:serialize($ill,map { 'format': 'jsonml','indent': 'yes' } )
   return  concat("[""metadata"", {""id"":""",$id,"""},", $tmp,"]" )      
      
};

let $res := "foo"  
return 
local:exportIllJSON(collection($corpus)//analyseAlto[(metad/ID=$id)]) 

