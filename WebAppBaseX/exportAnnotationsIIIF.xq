(:
 
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
declare option output:method 'text';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
   
declare variable $corpus as xs:string external    ;
declare variable $id as xs:string external   ;


declare  function local:exportIllJSON($doc as element()) {       
 let $pre := concat(
     "{ ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/manifest.json"": {
       ")        
 let $end := "}
         }"
 let $pages := $doc//pages/page[count(ills/ill)>0]
 let $lastPage := count($pages)
 let $listeAnnotations := for $page at $positionPage in $pages 
   let $ills := $page/ills/ill
   let $lastIll := count($ills)
   let $annotationPage := if ($lastIll > 0) then (
     concat(
   """https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/canvas/f",$page/@ordre,""": [
    ",
     fn:string-join (
      (for $ill at $positionIll in $ills
       let $tags := $ill/contenuImg[@x and @y and @w and @h and @lang='fr']
       let $lastTag := count($tags)
       let $tagNames := fn:string-join($tags, ', ')
       let $legs := $ill/contenuText
       let $legsIDs := fn:string-join($legs/@n, ', ')
       let $lastLeg := count($legs)
       let $annotation :=  
        concat("{
          ""@context"": ""http://iiif.io/api/presentation/2/context.json"",
          ""@id"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/",$ill/@n,""",
          ",
          """@type"": ""oa:Annotation"",
          ""motivation"": ""oa:describing"",
          ""resource"": [{
            ""@type"": ""dctypes:Text"",
            ""format"": ""text/html"",
            ""chars"": ""<p><strong>illustration ",$ill/@n, " (",$positionIll,"/",$lastIll,")",
             "</strong></p><p><small>technique : ",
            $ill/tech[@source="final"],
            " - fonction : ",
            $ill/fonction[@source="final"],
            " - genre : ",
            $ill/genre[@source="final"],
            " - annotations (", $lastTag,") : ",$tagNames,
            " - legendes (",$lastLeg,") : ",$legsIDs,
            "</small></p><p><a href=\""http://gallica.bnf.fr/ark:/12148/",$id,
            "/f",$page/@ordre,"\"" target=\""_blank\"" rel=\""noopener\"">Afficher dans Gallica</a></p><p><a href=\""https://gallicapix.bnf.fr/rest?run=findIllustrations-app.xq&amp;keyword=&amp;sourceTarget=&amp;corpus=vogue&amp;start=1&amp;mode=html&amp;CS=0&amp;id=",$id,
            "\"" target=\""_blank\"" rel=\""noopener\"">Afficher dans GallicaPix</a></p>""
          }],
        ""on"": [{
          ""@type"": ""oa:SpecificResource"",
          ""full"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/canvas/f",$page/@ordre,""",
          ",
          """selector"": {
            ""@type"": ""oa:Choice"",
            ""default"": {
              ""@type"": ""oa:FragmentSelector"",
              ""value"": ""xywh=",$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h,"""
          } ,
          ""item"": {
           ""@type"": ""oa:SvgSelector"",
            ""value"": ""<svg xmlns='http://www.w3.org/2000/svg'><path xmlns=\""http://www.w3.org/2000/svg\"" d=\""M",$ill/@x,",",$ill/@y,"h",$ill/@w,"v",$ill/@h,"h-",$ill/@w,"z\"" ", "id=\""rectangle_illustration-gallicapix_",$ill/@n,"\"" fill-opacity=\"".1\"" fill=\""#ff0000\"" stroke=\""#ff0000\"" /></svg>""
            }
         },                  
           ""within"": {
              ""@id"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/manifest.json"",
              ""@type"": ""sc:Manifest""
             }
           }]
         }
         ",
         (: :)
         (if (($lastTag = 0) and ($lastLeg = 0)  and ($positionIll != $lastIll)) then ',' else ''),          
         fn:string-join (
          (for $tag at $positionTag in $tags
          let $x :=  $ill/@x + (if (gp:is-a-number($tag/@x)) then ($tag/@x) else (1))
          let $y :=  $ill/@y + (if (gp:is-a-number($tag/@y)) then ($tag/@y) else (1))
          let $annotationTag := concat(",
          {
          ""@context"": ""http://iiif.io/api/presentation/2/context.json"",
          ""@id"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/",$ill/@n,"-",$positionTag,""", 
          ""@type"": ""oa:Annotation"",
          ""motivation"": ""oa:tagging"",
          ""resource"": [{
             ""@type"": ""dctypes:Text"",
             ""format"": ""text/html"",
             ""chars"": """"
              }, {
              ""@type"": ""oa:Tag"",
              ""chars"": """,$tag," (",$tag/@source,": ",$tag/@CS,")""
              }],
              ""on"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/canvas/f",$page/@ordre,"#xywh=",
               $x,",",$y,",",$tag/@w,",",$tag/@h,""" 
        }"
        ,
         (if (($positionTag = $lastTag) and ($lastLeg = 0) and ($positionIll != $lastIll)) then ',' else '')
         
        )  
          return  $annotationTag
            ), ' ')
         ,
         
        fn:string-join (
          (for $leg at $positionLeg in $legs
          let $x :=    (if (gp:is-a-number($leg/@x)) then ($leg/@x) else (1))
          let $y :=    (if (gp:is-a-number($leg/@y)) then ($leg/@y) else (1))
          let $annotationLeg := concat(",
          {
          ""@context"": ""http://iiif.io/api/presentation/2/context.json"",
          ""@id"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/",$ill/@n,"-",$positionLeg,""", 
          ""@type"": ""oa:Annotation"",
          ""motivation"": ""oa:supplementing"",
          ""resource"": [{
             ""@type"": ""dctypes:Text"",
             ""format"": ""text/html"",
             ""chars"": """"
              }, {
              ""@type"": ""oa:TextualBody"",
              ""language"": ""fr"",
              ""chars"": ""bloc texte (type : ", $leg/@type,", ",$leg/@n,") : ", if ($leg/text()) then ($leg) ," ","""
              }],
              
              ""on"": [{
          ""@type"": ""oa:SpecificResource"",
          ""full"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/canvas/f",$page/@ordre,""",
          ",
          """selector"": {
            ""@type"": ""oa:Choice"",
            ""default"": {
              ""@type"": ""oa:FragmentSelector"",
              ""value"": ""xywh=",$x,",",$y,",",$leg/@w,",",$leg/@h,"""
          } ,
          ""item"": {
           ""@type"": ""oa:SvgSelector"",
            ""value"": ""<svg xmlns='http://www.w3.org/2000/svg'><path xmlns=\""http://www.w3.org/2000/svg\"" d=\""M",$x,",",$y,"h",$leg/@w,"v",$leg/@h,"h-",$leg/@w,"z\"" ", "id=\""rectangle_texte-gallicapix_",$ill/@n,"\"" fill-opacity=\"".3\"" fill=\""#DCDCDC\"" stroke-linejoin=\""round\"" stroke-width=\""1\"" stroke=\""##808080\"" /></svg>""
            }
         },                  
           ""within"": {
              ""@id"": ""https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/manifest.json"",
              ""@type"": ""sc:Manifest""
             }
           }]
         }"
        ,
         (if (($positionLeg = $lastLeg) and ($positionIll != $lastIll)) then ',' else '')
         
        )  
          return  $annotationLeg
            ), ' ')
            
      )       
      return  $annotation,' ')
     )
    ,
      "]"
      ,
        (if ($positionPage != $lastPage) then ',
        ' else '')
      ))
    return $annotationPage
      
   return $pre || fn:string-join ($listeAnnotations,' ') || $end  
              
};

let $foo := $corpus  
return 
if (not(gp:isAlphaNum($corpus))) then (
  (: do nothing :)
  let $msg := concat("<?xml version=""1.0"" encoding=""UTF-8""?><?xml-stylesheet href=""/static/common.css"" type=""text/css""?>
       <message> Erreur corpus [ ", $corpus," ]</message>")
  return $msg
) else (
   let $docs := collection($corpus)//analyseAlto[(metad/ID=$id)]
   (: hack : il y a des documents doublons :)
   return if (count($docs)>1) then (local:exportIllJSON($docs[1])) else (local:exportIllJSON($docs))
     
 (:local:exportIllJSON(collection($corpus)//analyseAlto[(metad/ID=$id)]) :)
)

