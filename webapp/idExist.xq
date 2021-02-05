(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
declare option output:method 'text';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $id as xs:string external ;
declare variable $maxIlls as xs:integer external := 5;


declare  function local:info($doc as element()) {        
 let $pre := concat(
     "{ ""https://gallica.bnf.fr/ark:/12148/",$id,""": 
     {
       ")        
 let $end := "
}"
 (: pages avec des illustrations :)        
 let $pages := count($doc//pages/page[count(ills/ill)>0])
 (: illustrations :)  
 let $ills := $doc//ills/ill
 let $nIlls := count($ills)
 (: les $maxIlls premières illustrations :)
 let $infos := concat(
  """pages_with_ills"": ",$pages,",
       ""ills"": ", $nIlls,",
       ""first_ills"": [",
          fn:string-join (for $ill at $positionIll in $ills[position() <= $maxIlls]
         return 
         concat ("
         {
          ""page"": ""f", fn:head(fn:tokenize($ill/@n, '\-')),""",
          ""id"": """,$ill/@n,""",  
          ""x"": ",$ill/@x,",
          ""y"": ",$ill/@y,",
          ""w"": ",$ill/@w,",
          ""h"": ",$ill/@h,"
         }",
         (if ($positionIll < fn:min(($maxIlls,$nIlls))) then ',' else '')       
          ))
         ,
       "]
     }")         
 return $pre || fn:string-join ($infos,' ') || $end  
              
};

let $foo := $id  
return 
if (not(gp:isAlphaNum($id))) then (
  (: do nothing :)
  let $msg := concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur [ ", $id," ]</message>")
  return $msg
) else (   
   let $docs := (for $db in ("vogue","1418")    
       let $docsDB := collection($db)/analyseAlto[(metad/ID=$id)]
       return $docsDB)
       return if ($docs) then ( (: hack : il existe des documents doublons :)
        if (count($docs)>1) then local:info($docs[1])
        else local:info($docs))
       else ("{}")           
)

