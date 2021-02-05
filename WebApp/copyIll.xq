(:
 duplicate the illustration and update the crop (vertical cut) 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
(:declare option output:method 'html';
 
 Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;    (: document ID :)
declare variable $idIll as xs:string external   ;  (: illustration number :)
declare variable $idNew as xs:string external  ;
declare variable $source as xs:string external   ;
declare variable $mode as xs:string external   ; (: H / V :)



declare %updating function local:copyIll($ill as element()) {    
      try {    
       update:output("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message>      
       <p>Copy de l'illustration </p>
        </message>"
       ) ,
     (: duplicate  :)
     if ($mode = "V") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@h with xs:integer($ill/@h div 2),
          replace value of node $tmp/@y with $tmp/@y + xs:integer($ill/@h div 2)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@h,
      insert node (attribute h {xs:integer($ill/@h div 2)  }) into $ill )
     else if  ($mode = "V13") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@h with xs:integer($ill/@h * 0.666),
        replace value of node $tmp/@y with $tmp/@y + xs:integer($ill/@h div 3)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@h,
      insert node (attribute h {xs:integer($ill/@h div 3)  }) into $ill  
      ) 
      else if  ($mode = "V23") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@h with xs:integer($ill/@h * 0.333),
        replace value of node $tmp/@y with $tmp/@y + xs:integer($ill/@h * 0.666)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@h,
      insert node (attribute h {xs:integer($ill/@h * 0.666)  }) into $ill  
      ) 
      else if  ($mode = "V34") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@h with xs:integer($ill/@h * 0.25),
        replace value of node $tmp/@y with $tmp/@y + xs:integer($ill/@h * 0.75)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@h,
      insert node (attribute h {xs:integer($ill/@h * 0.75)  }) into $ill  
      ) 
      else if  ($mode = "V45") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@h with xs:integer($ill/@h * 0.2),
        replace value of node $tmp/@y with $tmp/@y + xs:integer($ill/@h * 0.80)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@h,
      insert node (attribute h {xs:integer($ill/@h * 0.80)  }) into $ill  
      ) 

       else if ($mode = "H13") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@w with xs:integer($ill/@w * 0.666),
        replace value of node $tmp/@x with $tmp/@x + xs:integer($ill/@w * 0.333)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@w,
      insert node (attribute w {xs:integer($ill/@w * 0.333)  }) into $ill  
      )
       else if ($mode = "H23") then (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@w with xs:integer($ill/@w * 0.333),
        replace value of node $tmp/@x with $tmp/@x + xs:integer($ill/@w * 0.666)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@w,
      insert node (attribute w {xs:integer($ill/@w * 0.666)  }) into $ill  
      )      
     else (
      insert node (copy $tmp := $ill
      modify (
        replace value of node $tmp/@n with $idNew, 
        replace value of node $tmp/@w with xs:integer($ill/@w div 2),
        replace value of node $tmp/@x with $tmp/@x + xs:integer($ill/@w div 2)
        )   
      return $tmp) into $ill/.., 
      delete node $ill/@w,
      insert node (attribute w {xs:integer($ill/@w div 2)  }) into $ill  
      )   
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
