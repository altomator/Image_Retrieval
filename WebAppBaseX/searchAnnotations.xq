(:
 Recherche de pages illustrees par les annotations
:)

declare namespace functx = "http://www.functx.com";

declare option output:method 'html';

(: Arguments avec valeurs par defaut :)

(: nom de la base BaseX :)
declare variable $corpus as xs:string external := "vogue";
(: requete :)
declare variable $annotation as xs:string external := "voiture";
(: requete :)
declare variable $CS as xs:decimal external := 0.2;

declare variable $mode as xs:string external := "ibm";

declare variable $title as xs:string external := 'Vogue';
declare variable $fromPage as xs:integer external := 1; (: par defaut toutes les pages :)
declare variable $toPage as xs:integer external := 2000;
declare variable $fromDate as xs:string external := "1920-01-01";
declare variable $toDate as xs:string external := "1940-12-31";  (: par defaut toute la collection :)

(: URL Gallica de base :)
declare variable $rootURL as xs:string external := 'http://gallica.bnf.fr/ark:/12148/';
declare variable $rootIIIFURL as xs:string external := 'http://gallica.bnf.fr/iiif/ark:/12148/';

(: ARK des notices de titre :)
declare variable $titlesARK as map(*) := map {
 (: "Nantes": "cb41193663x", :)
  "Ouest": "cb32830550k",
  (: "Caen": "cb41193642z", :)
  "Matin": "cb328123058",
  "Gaulois": "cb32779904b",
  "Le Journal": "cb39294634r",
  "Petit Journal": "cb32836564q",
  "Parisien": "cb34419111x",
  "Vogue": "cb343833568",
  ".*": ""   (: si le parametre $title a sa valeur par daut :)
};

declare function local:evalQuery($query) {
    let $hits := xquery:eval($query)
    return $hits
};

declare function functx:mmddyyyy-to-date
  ( $dateString as xs:string? )  as xs:date? {

   if (empty($dateString))
   then ()
   else if (not(matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$')))
   then error(xs:QName('functx:Invalid_Date_Format'))
   else xs:date(replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$',
                        '$3-$2-$1'))
 } ;

(: renvoie l'ARK partir du paramre $title :)
declare function local:computeARK($title) {
  for $v in map:keys($titlesARK)
  return if (fn:contains($title,$v))
   then map:get($titlesARK, $v)
   else ()

};

(: construction de la page HTML :)
declare function local:createOutput($data) {
<html>
   <head>
   <style>
result {{
    background-color: #ffffff;
    width: 100%;
}}
ol {{
  columns: 3;
  -webkit-columns: 3;
  -moz-columns: 3;
}}
li.match {{
    padding: 10pt;
    margin-bottom: 15pt;
    width:75%;
    border-color: #d9b38c;
    border-style: dotted;
    border-width: 5px
}}
li.warning {{
    display: block;
    color: red
}}
p {{
    margin: 0;
}}
img {{
    margin-top: 10pt;
}}
title {{

    display: block;
    color: #000066;
    font-size: 15pt;
}}
date:before {{
  color: black;
  content: "Date : ";
}}
page:before {{
color: black;
  content: "Page: ";
}}
illustrations:before {{
color: black;
  content: "Illustrations: ";
}}
h2 {{
    padding: 15pt;
    font-family: sans-serif;
    font-size: 16pt;
}}
h3 {{
    padding-left: 15pt;padding-top:0pt;padding-bottom:0pt;
    font-family:sans-serif;
    font-weight: normal;
    font-size: 12pt;
    color: #333333;
}}
page, illustrations, date{{

    font-family: sans-serif;
    font-size: 12pt;
    color: #000066;
}}
a {{


    font-family: serif;
    color: #660033
}}
   </style>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>Vogue (1920-1940) : illustrations</title></head>
<body>
<h1>Vogue (1920-1940) : illustrations <span style="color:#999999;font-size:28pt">Gallica</span></h1>
<h2>Annotations ({$mode}) : <span  style="color:#990000">{$annotation}</span><br></br>
 <span  style="font-weight:normal;">seuil de confiance >= {$CS}<br></br>
 de  {$fromDate} à {$toDate} </span></h2>
<h3><b>Base</b> : {$corpus} </h3>
<h3><b>Pages indexées</b> : {count($data//page)} </h3>
<h3><b>Illustrations</b> :  {count($data//ill)}</h3>

<ol>
  {

  if (not(map:contains($titlesARK, $title))) then (
   <li class="warning">Titre inconnu : {data($title)}
    -- Valeurs autorisees : {map:for-each(
  $titlesARK, function($a, $b) { fn:concat($a," /")}
)} </li>

  )
  else (
  for $issue in $data//analyseAlto[
  (metad/dateEdition/text() ge $fromDate)
  and (metad/dateEdition/text() le $toDate)]
let $date := $issue/metad/dateEdition
let $id := $issue/metad/ID
let $tokens := fn:tokenize($date, "\-")
let $url := fn:concat($rootURL,local:computeARK($title),"/date")
for $page in $issue/contenus/pages/page[(position()>=$fromPage) and (position()<=$toPage)]
let $npage := $page/@ordre
(: ### REQUETE ### :)
for $ill in $page/ills/ill[contenuImg[text()=$annotation
  and @CS>="$CS"
  and @source>="$mode"]]
let $urlIIIFill := concat($rootIIIFURL,$id,"/f",$npage,"/",$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h)
let $urlIIIFpage := concat($rootIIIFURL,$id,"/f",$npage,"/full/pct:15/0/native.jpg")
let $urlIIIFcible := concat($urlIIIFill,"/pct:20/0/native.jpg")
let $urlIIIFvignette := concat($urlIIIFill,"/pct:6/0/native.jpg")
return
<div>
<li class="match">
<p>date : {data($date)}&#8193;/&#8193;n° page : {data($npage)}</p>
<p><a href="{$url}{$tokens[1]}{$tokens[2]}{$tokens[3]}" target="_blank">fascicule</a>&#8193;/&#8193;<a href="{$urlIIIFpage}" target="_blank">page</a></p>
<a href ="{$urlIIIFcible}" target="_blank"> <img src="{$urlIIIFvignette}"></img></a>
</li>
</div>
)
}
</ol> </body>
</html>
  };


(: execution de la requete sur la base :)
let $data := collection($corpus)
  return
    local:createOutput($data)
