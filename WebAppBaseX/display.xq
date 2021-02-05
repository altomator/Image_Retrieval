(:
 Display a page, it's illustrations and face crops inside illustrations
 Affiche une page, ses illustrations et les visages dans les illustrations
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";
declare option output:method 'html';

declare variable $debug as xs:integer external := 1 ;  (: developpement-production / switch dev-prod :)
declare variable $display as xs:integer external := 0 ;  (: display the tags crops :)

(: Arguments du formulaire avec valeurs par defaut
   Args and default values from the form              :)
declare variable $corpus as xs:string external ;  (: base - database :)
declare variable $id as xs:string external := "" ;  (: ID document / document ID :)
declare variable $pageOrder as xs:integer external  := 1 ; (: numéro de page / page number :)
declare variable $nPages as xs:integer external := 0  ; (: pagination  :)
declare variable $illType as xs:string external := "" ;   (: types du document : carte, photo... / document type: map, picture... Multiple types: gravure_photog  :)
declare variable $sourceData as  xs:string := "final"; (: source de données à interroger / target of the request :)

declare variable $CBIR as xs:string external := "*"; (: source des données de classification / source of the classification data: * / ibm / dnn / google :)
declare variable $CS as xs:decimal external := 0.05; (: seuil pour la classification / threshold on classification Confidence Score, from 0 to 10 - 0%-100% :)
declare variable $faceClass as xs:string external := "face"; (: nom du concept "visage" / name of the Face class "face" :)
declare variable $sourceEdit as  xs:string := "hm"; (: source des données annotées / source of the human annotations: hm / cwd :)
declare variable $locale as xs:string external := "" ; (: localisation / localization : "fr"/"en" :)
(: module d'affichage des images : 0.5 / 1.0 / 2.0 / Size of the thumbnails :)
declare variable $module as xs:decimal external := 1;
(: largeur des images affichées :)
declare variable $largeurAff as xs:integer external := xs:integer($module * 600);
(: largeur des images affichées dans l'éditeur :)
declare variable $largeur as xs:integer external := xs:integer($module * 1000);
(: Gallica .medres= 512 px en largeur
   Paris-match : 595 :)
(: conversion mm pixels :   IMG = 22 MONO = 23.65   :)
declare variable $dpi as xs:decimal external := 20;

(: mise en page HTML :)
declare variable $padding as xs:integer  := 0;
(: marge autour des illustrations iiif / padding aroung illustration :)
declare variable $delta as xs:decimal  := 0.4;
(: facteur d'affichage  des illustrations iiif (%) 
declare variable $pct as xs:decimal  := 50;  100 pour Paris Match :)

(: couleurs d'affichage du masque sur les visages
Colors of the faces mask for Women, Man and no Gender:)
declare variable $coulF   := ";background-color: rgba(255,192,203,";
declare variable $coulM   := ";background-color: rgba(30,144,255,";
declare variable $coulP   := ";background-color: rgba(132,65,157,";

declare variable $dossierLocal  := "/static/img/" ;
(: -------- END parameters ---------- :)




(: Detection du sexe d'apres les données de classification
Gender detection based on classsification data :)
declare function functx:gender
  ($classes as xs:string?,
   $mode as xs:string?)  as xs:string? {

   switch($mode)
     case "classes" return (: using the classification classes :)
    if (fn:contains($classes,"couple")) then
        ("FM")
     else (
        if ((fn:contains($classes,"group of men"))) then
          ("MM")
     else (
        if ((fn:contains($classes,"group of women"))) then
          ("FF")
      else (
        if ((fn:contains($classes,"group of people")) or (fn:contains($classes," man,")) and (fn:contains($classes,"woman")) or (fn:contains($classes," men,")) and (fn:contains($classes,"women"))) then
          ("FMFM")
      else (
        if ((fn:contains($classes,"woman")) or (fn:contains($classes,"women"))) then
          ("F")
        else (if ((fn:contains($classes," man,")) or (fn:contains($classes,"men,"))) then
              ("M")
              else (
                   if (fn:contains($classes,"child")) then
                     ("C")
                   else (
                        if (fn:contains($classes,"crowd")) then
                        ("W")
                   else (
                     if (fn:contains($classes,"person") or fn:contains($classes,"portrait picture") or fn:contains($classes,"people")) then
                     ("P")
                   else ()
                   )
                   )
                 ))))
              )
         )
      case "faces"  return   (: using the face detection :)
       if ((fn:contains($classes,"M")) and (fn:contains($classes,"F"))) then
        ("Mixte")
     else (
        if (fn:contains($classes,"F")) then
          ("F")
        else (if (fn:contains($classes,"M")) then
              ("M")
              else ("P")
              )
         )
      default return ""
  };

(: Construction de la page HTML
   HTML page creation :)
declare function local:createHTMLOutput($data) {
<html>
<head>
<link rel="stylesheet" type="text/css" href="/static/common.css"></link>
<link rel="stylesheet" type="text/css" href="/static/results.css"></link>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.css"></link>
<link rel="stylesheet" type="text/css" href="/static/cropper.css" />
<style>
p {{
 color: black ;
 font-family: sans-serif;
 font-size: 9pt;
}}

body {{
    padding: {$padding}pt;
   }}

/* affichage des crops de classe */ 
.item-tag {{
  position:absolute;
  padding: 0px;
  width:10px;
  height:10px;
  top: 0px;
  right: 0px;
  z-index:4;
  border-width:1px;
  border-style: inset;
  border-color: rgba(0,0,180, 0.8);
  background-color: rgba(0,0,180,0.05);  /* bleu */
  border-radius: 3px;
}}
   
/* affichage des crops illustration - display the illustration crops */
/* illustration  */
.item-obj {{
  position:absolute;
  padding: 0px;
  width:10px;
  height:10px;
  top: 0px;
  right: 0px;
  z-index:4;
  border-width:1px;
  border-style: inset;
  border-color: rgba(255,127,80, 1);
  background-color: rgba(255,127,80,0.20);  /* orange */
  border-radius: 3px;
}}

/* illustration filtrée - filtered illustrations */
.FT:before{{
	content:'&#xf00d;';
  font-weight: normal;
  padding-left:2px;
  font-size: 12pt;
  color: rgba(220, 20, 60, 0.7);   /* red */
}}
.FT {{
  background-color: rgba(100,100,100,0.80);
  border-color: rgba(100,100,100, 0.7);
  border-style: dotted;
  border-width: 3px;
  z-index:4;
}}

/* illustration publicité - advertisement illustrations */
.pub {{
  background-color: rgba(100,100,200,0.20);
  border-color: rgba(100,100,200, 0.7);
  border-style: dashed;
  border-width: 2px;
}}

/* affichage des crops visage - display the face crops */
/* visage HOMME - man  */
.item-faceM {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 2px;
  border-style: solid;
  border-color: rgba(30,144,255, 0.6);
  background-color: rgba(30,144,255, 0.2);  /* bleu */
  border-radius: 3px;
}}
/* visage FEMME - women  */
.item-faceF {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 2px;
  border-style: solid;
  border-color: rgba(255,192,203, 0.6);
  background-color: rgba(255,192,203, 0.2);  /* rose */
  border-radius: 3px;
}}
/* visage générique - neutral  */
.item-faceP {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 2px;
  border-style: solid;
  border-color:rgba(160,110,110, 0.6);
  background-color: rgba(150,110,110, 0.2);  /* gris rouge */
  border-radius: 3px;
}}
/* visage ENFANT - child  */
.item-faceC {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index: 5;
  border-width: 2px;
  border-style: solid;
  border-color: rgba(255,165,0, 0.6);
  background-color: rgba(255,165,0, 0.2);  /* orange */
  border-radius: 3px;
}}
/* visage filtre - filtered */
.item-faceFT {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index: 5;
  border-width:2px;
  border-style: dotted;
  border-color: rgba(220,220,220, 0.7);
  background-color: rgba(220,220,220, 0.2);  /* gris */
  border-radius: 3px;
}}


/* bloc document illustré - document block */
.item-doc {{
  position: absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 1px;
  right: 1px;
  z-index:4;
  border-width: 3px;
  border-style: solid;
  border-color: rgba(50, 0, 190,0.8); /* bleu */ 
  border-radius: 3px;    
}}

/* bloc texte - txt block */
.item-txt {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 1px;
  border-style: solid;
  border-color: rgba(20,20,20,0.4);
  border-radius: 6px;
  background-color: rgba(20,20,20, 0.2);  /* gris */ 
}}
/* bloc texte filtré - filtered */
.item-txtFT {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index: 5;
  border-width: 2px;
  border-style: dotted;
  border-color: rgba(20,20,20, 0.4);
  background-color: rgba(20,20,20, 0.2);  /* gris */
  border-radius: 6px;
}}

/* affichage des icones Personne - display the Person icons */
/* NEUTRE - neutral */
.item-P:before{{
	content:'&#xf007;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size: {xs:float($module)*2+10}pt;
  /*color: rgba(132,65,157, 0.5);   violet */
   color: rgba(140,110,110, 0.95);
}}
.item-P, .item-M,  .item-MM, .item-F,  .item-FF, .item-FMFM, .item-C, .item-FM, .item-W, .item-name  {{
  position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:5;
}}
/* HOMME - man */
.item-M:before{{
	content:'&#xf183;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(30,144,255, 0.9);  /* bleu */
}}
/* FEMME - woman */
.item-F:before{{
	content:'&#xf182;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(255,192,203, 0.9);
}}
/* couple man+woman */
.item-FM:before{{
	content:'&#xf183;&#xf182;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(128,0,128, 0.8);
}}
/* group of men */
.item-MM:before{{
	content:'&#xf183;&#xf183;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(30,144,255,0.9);
}}
/* group of women */
.item-FF:before{{
	content:'&#xf182;&#xf182;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(255,192,203,0.9);
}}
/* group of people */
.item-FMFM:before{{
	content:'&#xf182;&#xf183;&#xf182;&#xf183;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(150,80,140,0.9);
}}
/* enfant - child */
.item-C:before{{
	content:'&#xf1ae;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(255,165,0, 0.9);
}}
/* foule - crowd */
.item-W:before{{
	content:'&#xf0c0;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(110,110,110, 0.9);
}}
/* visage nommé - face with name */
.item-name:before{{
	content:'&#xf2c3;';
  padding-left:2px;
  padding-right:12px;

  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(255,255,255, 0.8);
}}

/* segmenter */
.item-seg:before{{
	content: '&#xf046;';
  font-weight: normal;
  font-size:10pt;
  color: rgba(154,205,50, 0.7);
}}
.item-seg {{
   position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:8;
}}


/* menu flottant en bas des images - floating menu bellow the illustrations */
ul li a {{
  font-size: {xs:float($module)*2+6}pt;
}}
/* pour les icones fa */
#small {{
  font-size: {xs:float($module)*2+8}pt;
}}
#norm {{
  font-size: {xs:float($module)*2+9}pt;
}}
#big {{
  font-size: {xs:float($module)*2+10}pt;
}}
#sbig {{
  font-size: {xs:float($module)*2+12}pt;
}}
.menu {{
  font-size: {xs:float($module)*2+6}pt;
  color:gray;
}}

/* menu pour les illustrations */
.menu-tip{{
  z-index: 15;
  width: { (100+xs:float($module)*50)}px;
  margin-top: {if ($debug) then ("-100px") else ("20px")};
  margin-left: -40px;
}}

/* menu pour la segmentation niveau page */
.menu-tipSeg{{
  z-index: 15;
  width: 50px;
  right: -{$largeurAff - 50}px; 
  height: 20px;
  margin: 0px;
  border-width:1px;
  border-style: inset;
  border-color: "grey";
  display: block 
}}

/* menu pour les visages, crops, textes... - faces menu */
.menu-tipv{{
  z-index: 16;
  width: { (70+xs:float($module)*50)}px;
  margin-top: -10px;
  margin-left: -20px;
  background-color: rgba(185,165,165,0.4);
}}

.txt {{
   font-size: 7pt;
   font-family: sans-serif;
   line-height: 1.3;
   padding-top: 6px;
   color: white
}}

.txtlight {{
   font-size:  {xs:float($module)*2.5+3}pt;;
   font-family: sans-serif;
   line-height: 1.2;
   color: white;
}}

.cropper {{
  padding: {$padding};
  margin-top:10pt;
  width: {$largeur};
   }}

.cropper img {{
    width: 100%;
 }}

.div_img {{
  width: {$largeurAff};
  padding: {$padding};
  position: absolute;
  top: 0px;
  left: 0px;
}}

#ligneLog {{
  display: none;
}}

.form-horizontal {{
  padding: 10pt;
  display: none;
}}

.button {{
  display: none;
  margin: 10pt;
}}

.resizer-buttons {{
  display: none;
  margin-left: {xs:float($largeur) * 0.5 - 50}px;
}}

.menu-nav {{
  color:#cf6e33;
  float:right;
  line-height: 1.3;
  padding-top: 10px;
  padding-right: 10%
}}


/* pour Firefox */
select.techFoncGen {{
  width: 170px;
}}
</style>

 <!-- Construction de la page HTML - building the HTML page -->
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>Gallica : Recherche d&#x27;illustrations</title>

</head>
<body id="body" >
{
(: critère sur les ID :)
let $id-predicate := if  (not ($id = "")) then concat (
   " (metad/ID[text()='", $id, "']) ") else ()


(: critère sur les pages : page de début, de fin
Criteria on page position :)
let $npage-predicate :=  concat(
   "  (@ordre = ",
  $pageOrder, ") and ")

(: critère sur les types de documents: carte, dessin, photo...
Criteria on documents types: map, drawing, picture... :)
let $genre-predicate := if  (not ($illType = "")) then (
 concat(" and (genre[matches('",$illType,"',text()) and @source='",$sourceData,"']) "))
 else ()

(: catégories de critères de recherche  : metadonnees sur le document :)
let $meta := if ( not($id-predicate="") ) then (1) else (0)

(: construction de la requête :)
let $meta-predicate := if ($meta = 1) then (   (: recherche  avec critere sur les metadonnees  :)
   concat
  ( "//analyseAlto[",
   $id-predicate,
    " ]" (:   hack pour neutraliser le and du  dernier predicat :)
    )
 )
else ( )

let $page-predicate :=
 concat (
    "//page[",
  $npage-predicate,
   " ""true"" ]"
   )

let $ill-predicate := concat (
"//ill[ ""true"" ", (: pour neutraliser le AND qui suit :)

  $genre-predicate,
    "]")

(: critère sur la source de la classification: ibm (Watson), google, dnn
Criteria on the classification source: ibm (Watson), google, dnn :)
let $CBIRsource := if ($CBIR="*") then ("true ") else ($CBIR)

(: executer la requete :)
let $eval-string := concat (
   "collection('",
   $data,
   "')",
   $meta-predicate,
    $page-predicate,
   $ill-predicate
 )

(: pour ne pas executer la requete
let $hits := ()
:)
let $subhits := xquery:eval($eval-string)
let $nbIlls := count($subhits)
let $illUn := fn:head($subhits) (: first ill. of the result list  :)
(: let $nPages := $illUn/../../../../../metad/nbPage :)
let $illSuiv := concat($pageOrder,'-',$nbIlls+1)
let $xUn := $illUn/@x
let $meta := $illUn/../../../../../metad
let $source := $meta/source
let $largeurPx := $illUn/../../@largeurPx (: page size :)
let $hauteurPx := $illUn/../../@hauteurPx
let $segDoc := $illUn/../../document
let $rot := if ($illUn/@rotation) then ($illUn/@rotation) else (0)
let $type := $meta/type
(: get the page dimensions :)
let $lPage := if ($largeurPx) then ($largeurPx)
  else (
   if (($nbIlls = 1) and ($illUn/@x <= 1)) then ($illUn/@w) (: one illustration and full page size : photo... :)
   else ($dpi*xs:integer($meta/../contenus/largeur)) (: retrocompatibility :)
)
let $hPage := if ($hauteurPx) then ($hauteurPx)
else (	
   if (($nbIlls = 1) and ($illUn/@y <= 1)) then ($illUn/@h) 
   else ($dpi*xs:integer($meta/../contenus/hauteur))
)
let $urlIIIFexterne := $illUn/../../../../../metad/urlIIIF
let $baseiiif := concat("http://gallica.bnf.fr/iiif/ark:/12148/",$id,"/f",$pageOrder,"/")
let $urlGallica := if ($source = "local") then (concat($dossierLocal,$illUn/../../../../../metad/fichier,"_",$pageOrder,".jpg"))
                   else if ($urlIIIFexterne) then ($illUn/../../../../../metad/url) (: other DLs :)
                   else ( concat("http://gallica.bnf.fr/ark:/12148/",$id,"/f",$pageOrder,".item")) (: Gallica :)
let $idSuiv := $illUn/../../../../../metad/IDsuiv (: MD de la page - metadata for the page :)
 
let $URLiiif := if ($urlIIIFexterne) then ($urlIIIFexterne)
                else (: default is Gallica :)
                 (if ($rot=0) then (concat($baseiiif,"full/",$largeurAff,"/",$rot,"/native.jpg")) else (
                   concat($baseiiif,"full/,",$largeurAff,"/",$rot,"/native.jpg")
                 ))
let $URLiiifEdit := if ($urlIIIFexterne) then ($urlIIIFexterne)
                else (: default is Gallica :)
                 (if ($rot=0) then (concat($baseiiif,"full/",$largeur,"/",$rot,"/native.jpg")) else (
                   concat($baseiiif,"full/,",$largeur,"/",$rot,"/native.jpg")
                 ))
let $date := $illUn/../../../../../metad/dateEdition
(: plus rapide :)
let $url := if ($source = "local") then
             (concat($dossierLocal,$illUn/../../../../../metad/fichier,"_",$pageOrder,".jpg"))
            else ($URLiiif)
let $urlEdit := if ($source = "local") then
             (concat($dossierLocal,$illUn/../../../../../metad/fichier,"_",$pageOrder,".jpg"))
            else ($URLiiifEdit)
let $numPage := $illUn/../../@ordre
(: calcul du ratio taille affichage/taille image - ratio display/image size :)
let $ratio := if ($rot=0) then (fn:number($largeurAff) div fn:number($lPage))
              else (fn:number($largeurAff) div fn:number($hPage))
let $ratio_segmentDoc := if ($rot=0) then (fn:number($largeur) div fn:number($lPage))
                        else (fn:number($largeur) div fn:number($hPage))
let $exportSeg :=  concat($baseiiif,$segDoc/@x,",",$segDoc/@y,",",$segDoc/@w,",",$segDoc/@h,"/1000,/",$rot,"/native.jpg") 
(: menu de navigation - navigation menu :)
return
<div>
<div>

<a href="{$urlGallica}" target="_blank" title="Gallica">
<img src="{$url}"></img></a>

{if ($segDoc) then (
  <div>
 <div> {attribute  class  {'img item-doc'}}
       {attribute  id {concat('doc-',$pageOrder) }}
       {attribute  style  {concat('left:',$ratio * $segDoc/@x,";top:",$ratio * $segDoc/@y,";width:", $ratio * $segDoc/@w,";height:",$ratio * $segDoc/@h)}}   
        {if ($debug) then (<span class="txtlight">x : {data($segDoc/@x)} -
         y : {data($segDoc/@y)} - l : {data($segDoc/@w)} - h : {data($segDoc/@h)}</span>)}
<div style="width:90px;top-margin:-10px"> {attribute  class  {'menu-tip'}}
<ul  class="main-navigation" id="liste">
   <li><a  class="fa" id="small" title="Exporter l'image" href="{$exportSeg}" target="_blank">&#xf03e;</a></li>
   <li><a  class="fa" id="small" title="Exporter les métadonnées (JSON)" href="#">&#xf121;</a></li>   
    <li><a  class="fa"  title="Corriger la segmentation" href="javascript:segmentDoc('{$corpus}','{$id}', '{$illUn/@n}','{$sourceEdit}','{$urlEdit}',{$ratio_segmentDoc},0,0,{$lPage},{$hPage},{$rot})">&#xf016;</a></li>
<li><a  class="fa"  title="Supprimer la segmentation" href="javascript:suppSegmentDoc('{$corpus}','{$id}', '{$illUn/@n}', '{$pageOrder}','{$sourceEdit}',)">&#xf014;</a></li>
 </ul>
</div>
</div>
</div>
      ) else ()
 }

<p class="menu-nav"><b>{string($meta/titre)}</b> <br></br>
&#8193;date : {$date} <br></br>
&#8193;illustrations : {$nbIlls} <br></br>
&#8193;largeur page : {string($lPage)} - hauteur page : {string($hPage)} (px)<br></br>
&#8193;rotation :  {string($rot)}°<br></br>
&#8193;page #{$pageOrder}:{$nPages}<br></br>
&#8193;CBIR : {$CBIR} / CS > {$CS}<br></br>
<span lang="fr">&#8193;catégorie :</span><span lang="en">&#8193;categorie:</span>  {$type}<br></br>
{if ($pageOrder != 1) then (<a class="fa" style="margin-top:10px;margin-right:4px;font-size:22pt;" title="Page précédente" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder}-1,{$nPages},'{$CBIR}','{$CS}',{$module})">&#xf0d9;</a>) else ()}
<span class="fa" style="font-size:18pt">&#xf016;</span>
{if ($pageOrder < $nPages) then (<a class="fa" style="font-size:22pt;" title="Page suivante" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder}+1,{$nPages},'{$CBIR}','{$CS}',{$module})">&#xf0da;</a>) else ()}
<br></br>
<span class="fa" style="line-height: 2.5;font-size:18pt;padding-left:0.5em">&#xf0c5;</span>
{if ($type = "P") then (<a class="fa" style="font-size:22pt;" title="Numéro suivant" href="javascript:displayIssue('{$corpus}','{$idSuiv}','{$CBIR}','{$CS}')">&#xf0da;</a>)}
<br></br>
<a class="fa" style="font-size:22pt;padding-left:0.5em" title="Zoom -" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder},{$nPages},'{$CBIR}','{$CS}',{$module}-0.25)">-</a>  <a class="fa" style="font-size:22pt;padding-left:0.5em" title="Zoom +" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder},{$nPages},'{$CBIR}','{$CS}',{$module}+0.25)">+</a>
</p>

<div>  {attribute  class  {'menu-tipSeg'}}

<ul  class="main-navigation" id="liste">
   <li><a  class="fa" id="small" title="Créer une illustration" href="javascript:createIll('{$corpus}','{$id}','{$pageOrder}','{$illSuiv}','{$lPage}','{$hPage}')" >&#xf125;</a></li>
   <li><a  id="small" title="Renuméroter les illustrations" href="javascript:renumberIlls('{$corpus}','{$id}','{$pageOrder}')" >
   <span style="font-size:5.5pt" class="fa-stack">
    <span class="fa fa-circle-o fa-stack-2x"></span>
    <span class="fa-stack-1x">1</span>
</span></a></li>
 </ul>
</div> 

<div>
<div id="cropper">
   <div id="image-cropper"></div>
</div>

<div>
<div class="resizer-buttons" id="resizer-buttons">
<button lang="fr" class="button resizer-result" id="resizer-result">Créer</button>
<button lang="en" class="button resizer-result" id="resizer-result">New</button>
<button lang="fr" class="button resizer-quit" id="resizer-quit">Fermer</button>
<button lang="en" class="button resizer-quit" id="resizer-quit">Quit</button><br></br>
</div>
<br></br>
 <form class="form-horizontal" id="coords">        
                             <div class="">
                                <label>Illustration </label>
                                <span class="col-xs-7" id="idIll"></span>
                            </div>
                            <div class="form-group">
                                <label>Annotations </label>
                                <span class="col-xs-7" style="font-weight:bold" id="crops"></span>
                            </div>
                            <div class="form-group">
                                <label class="col-xs-5 control-label"><em>x</em></label>
                                <div class="col-xs-7">
                                    <input type="text" name="x" id="x-1" class="form-control" value="0" />
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="col-xs-5 control-label"><em>y</em></label>
                                <div class="col-xs-7">
                                    <input type="text" name="y" id="y-1" class="form-control" value="0" />
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="col-xs-5 control-label"><em>largeur</em></label>
                                <div class="col-xs-7">
                                    <input type="text" name="width" id="width-1" class="form-control" value="0" />
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="col-xs-5 control-label"><em>hauteur</em></label>
                                <div class="col-xs-7">
                                    <input type="text" name="height" id="height-1" class="form-control" value="0" />
                                </div>
                            </div>
                            
                        </form>
      </div>        
   </div>
 <div>
 <iframe style="color:black;z-index:6;float:left;height:50px;width:500px" id="ligneLog" name="ligneLog" frameborder="1" src="">
  <p>Erreur : votre navigateur ne supporte pas les iframe !</p>
</iframe>
<div id="bottom">  &#8193;</div>
</div>

</div>
{
 if ($subhits) then (
 (: traiter toutes les illustrations de la page - processing all the illustrations on the page :)
  for $ill in $subhits

    let $illSuiv := concat($numPage,'-',$nbIlls+1)
    let $idIll := $ill/@n
    let $pub := $ill/@pub
    (: get all the classes from the CBIR source :)
    let $cbirClasses := if ($CBIR='*') then ($ill/contenuImg[@CS>=$CS]) else ($ill/contenuImg[@source=$CBIR and @CS>=$CS])
    (: get all the faces from the CBIR source :)
    let $vgs := $ill/contenuImg[text()=$faceClass]
    let $nVsg :=  if ($vgs) then (count($vgs)) else (0)
    (: get all the text :)
    let $txts := $ill/contenuText
    let $nTxt :=  if ($txts) then (count($txts)) else (0)
    let $CBIRClassesNorm := fn:string-join($cbirClasses, ', ') (: classes sémantiques :)
    let $personne := functx:gender($CBIRClassesNorm,'classes')
    let $genre := $ill/genre[@source="final"]
     let $fonction := $ill/fonction[@source="final"]
    let $technique := $ill/tech[@source="final"]
    let $label := substring(replace($ill/leg,'''','&#8217;'),1,25)
    let $label := if (not ($label)) then (substring(replace($ill/titraille,'''','&#8217;'),1,25)) else ($label)    
    let $x := xs:integer($ill/@x)
    let $y := xs:integer($ill/@y)
    let $l := xs:integer($ill/@w)
    let $h := xs:integer($ill/@h)
    (: padding around the illustration :)
    (:let $delta := if (((1+$delta)*$l>$lPage) or ((1+$delta)*$h>$hPage)) then (0) else ($delta):)
    let $deltaL := if ((1+$delta)*$l>$lPage) then ($lPage - $l) else ($l * $delta)
    let $deltaH := if ((1+$delta)*$h>$hPage) then ($hPage - $h) else ($h * $delta)
    let $deltaL2 := xs:integer($deltaL*0.5)
    let $deltaH2 := xs:integer($deltaH*0.5)
    (: marges autour de l'illustration :)
    let $x2 := if ($x - $deltaL2 < 1) then (1) else ($x - $deltaL2)
    let $y2 := if ($y - $deltaH2 < 1) then (1) else ($y - $deltaH2)
    let $l2 := if (($x2 + $l + $deltaL) > $lPage) then ($lPage - $x2) else ($l + $deltaL)
    let $h2 := if (($y2 + $h + $deltaH) > $hPage) then ($hPage - $y2) else ($h + $deltaH)
    let $rotation := if ($ill/@rotation) then ($ill/@rotation) else (0)
    let $iiif :=   if ($rotation=0) then ( concat( $baseiiif, $x,",",$y,",",$l,",",$h,"/",$largeur,",/",$rotation,"/native.jpg")) else (concat( $baseiiif, $x,",",$y,",",$l,",",$h,"/,",$largeur,"/",$rotation,"/native.jpg"))
    (: url IIIF pour l'illustration avec une marge autour :)
    let $iiifDelta :=  if ($rotation=0) then ( concat( $baseiiif, $x2,",",$y2,",",$l2,",",$h2,"/",$largeur,",/",$rotation,"/native.jpg") ) else
       ( concat( $baseiiif, $x2,",",$y2,",",$l2,",",$h2,"/,",$largeur,"/",$rotation,"/native.jpg") )
    let $urlIll := if ($source = "local") then ($urlGallica) else ($iiif)
    let $filtre := if ($ill/@filtre) then ("FT") else () (: filtered illustrations :)
    let $pub := if ($ill/@pub) then ("pub") else ()      (: ads :)
    (: rapport L sur H de l'illustration 
    let $ratio_lh := $l div $h :)
    (: ratio illustration affichée dans le cropper / dimension de l'illustration  :)
    let $ratio_ill_segment := if ($rotation=0) then (fn:number($largeur) div fn:number($l2))
                        else (fn:number($largeur) div fn:number($h2))
    (: ratio illustration affichée / dimension de la page  :)
    let $ratio_ill_segmentDoc := if ($rotation=0) then (fn:number($largeur) div fn:number($lPage))
                        else (fn:number($largeur) div fn:number($hPage))
    let $ratio_ill := if ($rotation=0) then (fn:number($largeur) div fn:number($l))
                        else (fn:number($largeur) div fn:number($h))
    let $largAff := if ($rotation=0) then (xs:integer($l)) else (xs:integer($h))
    let $hautAff := if ($rotation=0) then (xs:integer($h)) else (xs:integer($l))
    let $imgFormat := if ($urlIIIFexterne) then ("/default.jpg") (: hack for Welcome Library :)
             else ("/native.jpg") (: gallica case :)
    let $export :=  if ($iiif) then ($urlIll)
                    else (concat( $URLiiif,$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h,"/1000,/",$rotation,$imgFormat) )
return
<div>
<div class="div_img">
 <div> {attribute class {concat('img item-obj fa ', $filtre, $pub)} }
       {attribute  id  {concat('ill-',$idIll) }}
      {attribute style   {if ($rotation=0) then (
        concat('left:',$padding+($ratio * $x),";top:",$padding+($ratio*$y),";width:",
      $ratio * xs:integer($l),";height:",$ratio * xs:integer($h)))
      else (
        concat('right:',$padding+($ratio * $y),";top:",$padding+($ratio*$x),";width:",
      $ratio * xs:integer($h),";height:",$ratio * xs:integer($l))
      )
    }}

{if (not ($filtre)) then (
<div>
{if ($debug) then (<p style="margin:10px"><span class="txtlight">illustration <b>{data($idIll)}</b>
<br></br>
{if ($pub) then (<span class="txtlight">publicité</span>)}<br></br><br></br>
{data($label)}...<br></br><br></br>
 {substring(data($CBIRClassesNorm),1,50)} 
<br></br><br></br>
technique : {data($technique)}<br></br>
fonction : {data($fonction)}<br></br>
genre : {data($genre)}<br></br>
personnes : {data($personne)}<br></br>
#faces : {data($nVsg)}<br></br>
#textes : {data($nTxt)}<br></br>
#classes : {data(count($cbirClasses))}</span></p>) else 
(<span class="txtlight">&#8193; illustration  <b>{data($idIll)}</b> </span>)}
<div> {attribute  class  {'menu-tip'}}
<ul class="main-navigation" id="liste">
<li><a id="linkShare" title="Diffuser l'illustration" class="fa" href="#">&#xf045;</a> 
 <ul>
  
   <li><a  class="fa" id="small" title="Exporter l'image" href="{$export}" target="_blank">&#xf03e;</a></li>
   <li><a  class="fa" id="small" title="Exporter les métadonnées (JSON)" href="#">&#xf121;</a>
   <ul> 
    <li><a  class="fa" id="small" title="de l'illustration" href="javascript:exportIllJson('{$corpus}','{$id}','{$ill/@n}')" target="_blank">&#xf03e;</a></li>
     <li><a  class="fa" id="small" title="du document" href="javascript:exportDocJson('{$corpus}','{$id}')" target="_blank">&#xf0c5;</a></li>
    </ul>
    </li>
 </ul>
 </li>
 
<li><a  title="Gérer les visages" id="norm" class="fa" href="#">&#xf007;</a>
 <ul>
     <li><a  title="Créer un visage de femme"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'F','{$sourceEdit}','{$urlIll}',{$ratio_ill},{$x},{$y},{$l},{$h},{$rotation})">&#xf182;</a></li>
     <li><a  title="Créer un visage d'homme"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'M','{$sourceEdit}','{$urlIll}',{$ratio_ill},{$x},{$y},{$l},{$h},{$rotation})">&#xf183;</a></li>
     <li><a  title="Créer un visage d'enfant"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'C','{$sourceEdit}','{$urlIll}',{$ratio_ill}, {$x},{$y},{$l},{$h},{$rotation})">&#xf1ae;</a></li>
      <li><a  title="Supprimer tous les visages"  class="fa" id="norm"  href="javascript:suppVisages('{$corpus}', '{$id}', '{$ill/@n}','{$nVsg}','{$sourceEdit}')">&#xf014;</a></li>
 </ul>
</li>

<li><a  title="Signaler des personnes " id="norm" class="fa" href="#">&#xf183;</a>
 <ul>
 <li><a  title="Signaler une femme" id="norm" class="fa" href="javascript:personne('{$corpus}','woman', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;</a></li>
 <li><a  title="Signaler un homme"  class="fa" href="javascript:personne('{$corpus}','man', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf183;</a></li>
 <li><a  title="Signaler un enfant"  class="fa" id="norm"  href="javascript:personne('{$corpus}','child', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf1ae;</a></li>
 <li><a  title="Signaler un couple"  class="fa" href="javascript:personne('{$corpus}','couple', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf183;</a></li>
 <li><a  title="Signaler un groupe de femmes"  class="fa" href="javascript:personne('{$corpus}','group of women', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf182;</a></li>
 <li><a  title="Signaler un groupe d'hommes"  class="fa" href="javascript:personne('{$corpus}','group of men', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf183;&#xf183;</a></li>
 <li><a  title="Signaler un groupe mixte"  class="fa" href="javascript:personne('{$corpus}','group of people', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf183;&#xf182;&#xf183;</a></li>
 <li><a  class="fa" title="Signaler une foule"  href="javascript:personne('{$corpus}','crowd', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf0c0;</a>
 </li>
</ul>
</li>

 <li><a  class="fa" title="Actualité"  href="javascript:tag('{$corpus}','news', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf017;</a></li>
 
  <li><a  class="fa"  title="Signaler un texte relatif à l'illustration" onclick="document.body.style.cursor='wait'; return true;"  href="javascript:segmentTxt('{$corpus}','{$id}', '{$ill/@n}',{$nTxt}+1,'{$sourceEdit}','{$urlEdit}',{$ratio_ill_segmentDoc},0,0,{$lPage},{$hPage},{$rotation})">&#xf031;</a>
  <ul>
  <li><a  title="Supprimer tous les textes"  class="fa" id="norm"  href="javascript:suppTextes('{$corpus}', '{$id}', '{$ill/@n}','{$nTxt}','{$sourceEdit}')">&#xf014;</a></li>
  </ul>
  </li>
  
<li><a  title="Modifier l'illustration" id="norm" class="fa" href="#">&#xf0c4;</a>
 <ul>
  <li><a  class="fa"  title="Resegmenter l'illustration"  href="javascript:segment('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}','{$iiifDelta}',{$ratio_ill_segment},{$x},{$y},{$x2},{$y2},{$l2},{$h2},{$rotation})">&#xf125;</a></li>
  <li><a  class="fa"  title="Reset pleine page"  href="javascript:reset('{$corpus}','{$id}','{$ill/@n}','{$sourceEdit}',{$lPage},{$hPage},{$rotation})">&#xf0e2;</a></li>
  {if ($rotation = 0) then (
    <div>
    <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration vert."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V')">&#xf248; --</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V13')">&#xf248; 1/3</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au 2nd tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V23')">&#xf248; 2/3</a></li>
    
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au 4/5e"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V45')">&#xf248; 4/5</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration horiz."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H')">&#xf248; |</a></li>
      <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H13')">&#xf248; 1/3</a></li>
       <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au 2e tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H23')">&#xf248; 2/3</a></li>
     </div>) else
       (<div>
    <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration vert."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H')">&#xf248; --</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H13')">&#xf248;</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au 2nd tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H23')">&#xf248;</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration horiz."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V')">&#xf248; |</a></li>
      <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V13')">&#xf248;</a></li>
       <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au 2e tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V23')">&#xf248;</a></li>
     </div>)}
     
     <li><a  class="fa"  title="Ajouter une segmentation de niveau document"  href="javascript:segmentDoc('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}','{$urlEdit}',{$ratio_ill_segmentDoc},0,0,{$lPage},{$hPage},{$rotation})">&#xf016;</a></li>
 </ul>
</li>

 
 <li><a  title="Supprimer l'illustration" id="norm" class="fa" href="javascript:suppIll('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf014;</a>
 <ul>
 <li><a  class="fa" title="Filtrer"  href="javascript:filtreIll('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf056;</a></li>
  <li><a  class="fa" title="Supprimer"  href="javascript:suppIll('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf014;</a></li>
   <li><a  title="Signaler une publicité"  class="fa"  href="javascript:filtrePub('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf217;</a>
    <ul>       
      <li><a  title="Signaler une ill. éditoriale"  class=""  href="javascript:deFiltrePub('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">X</a></li>
    </ul>  
   </li>
 </ul>
 </li> 
 </ul>
 </div>
  </div>
) else (
<div>
<span class="txtlight">&#8193; ill {data($idIll)}</span>
<div> {attribute  class  {'menu-tip'}} {attribute  style  {'width:50px;'}}
<ul class="main-navigation" id="liste" >
  <li><a  title="Supprimer l'illustration" id="norm" class="fa" href="javascript:suppIll('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf014;</a></li>
  <li><a  class="fa" title="Défiltrer"  href="javascript:deFiltreIll('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf0e2;</a></li>
  </ul>
   </div>
</div>
)}

 {if ($personne != "") then (
  (: afficher les icones de type Personne - display the Person icons :)
        <div> {attribute  class  {concat('fa fa-user item-',$personne)}}   </div>
      ) else ()
 }

 
 
 { (: afficher les crops des textes - display the txt crops 
  let $req := concat($CBIRsource," and text()='", $faceClass, "' and @CS>=",$CS) :)
  let $textes := $ill/contenuText
  let $nVisagesCBIR := count($textes)
  for $texte in $textes  
   let $idTxt :=  $texte/@n
   let $typeTxt :=  fn:upper-case($texte/@type)
   let $filtreObj :=  if ($texte/@filtre) then ("FT") else ()
   let $txt :=  $texte
   return
      <div> {attribute  class  {concat('imgv item-txt',$filtreObj) }} {attribute  id  {concat('txt-',$idTxt) }}
      {(: note : les textes sont positionnés relativement à la page :)
        if ($rotation=0) then (attribute  style  {concat('left:',$ratio * $texte/@x - $ratio*$ill/@x,";top:",$ratio * $texte/@y - $ratio *$ill/@y,";width:", $ratio * $texte/@w,";height:",$ratio * $texte/@h)}) else (
        attribute  style  {concat('right:',$ratio * $texte/@y - $ratio *$ill/@y,";top:",$ratio * $texte/@x - $ratio *$ill/@x,";width:", $ratio * $texte/@h,";height:",$ratio * $texte/@w)}
      )}
      <span class="txtlight">&#8193; txt {data($idTxt)}@ill {data($idIll)} &#8193;{data($typeTxt)}
      <br></br>&#8193; <b>{data($txt)}</b></span>
<div> {attribute  class {'menu-tipv'}}
<ul class="main-navigation">
<li><a  title="Saisir le texte" id="norm" class="fa" 
href="javascript:saisirTexte('{$corpus}','{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">[ ]</a></li>
<li><a  title="Supprimer le texte" id="norm" class="fa" 
href="javascript:texte('{$corpus}','D', '{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">&#xf05e;</a></li>
<li><a  title="Texte de niveau page" id="norm" class="fa" 
href="javascript:texte('{$corpus}','page', '{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">&#xf016;</a></li>
<li><a  title="Légende d'illustration" id="norm" class="fa" 
href="javascript:texte('{$corpus}','leg', '{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">&#xf03e;</a></li>
<li><a  title="Texte intra illustration" id="norm" class="fa" 
href="javascript:texte('{$corpus}','txt', '{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">T</a></li>
<li><a  title="Identifiant d'illustration, numéro de page, tampon" id="norm" class="fa" 
href="javascript:texte('{$corpus}','id', '{$id}','{$ill/@n}','{$idTxt}','{$sourceEdit}')">I</a></li>
 </ul>
</div>
</div>
   }
 
 { (: afficher les crops de classe  :)
  if ($display) then (
   for $obj in   $ill/contenuImg[@x and @y and @w and @h and not(text()="face")]  
   let $label := $obj
   let $sourceCBIR := $obj/@source
   let $filtreObj :=  if ($obj/@filtre) then ("FT") else ()
   return      
       <div> {attribute class {concat('imgv item-tag',$filtreObj) }}  
      {attribute  style  {concat('left:',$ratio * $obj/@x,";top:",$ratio * $obj/@y,";width:",
      $ratio * $obj/@w,";height:",$ratio * $obj/@h)}}
      <span class="txtlight">{data($label)} ({data($sourceCBIR)}) : {data($obj/@x)},{data($obj/@y)}</span>
      </div>)
     }
       
 { (: afficher les crops des visages - display the face crops :)
  let $visages := if($CBIR='*') then ($ill/contenuImg[text()=$faceClass and @CS>=$CS]) else ($ill/contenuImg[@source=$CBIR and text()=$faceClass and @CS>=$CS])
  let $nVisagesCBIR := count($visages)
  for $visage in $visages
   let $sexe :=  $visage/@sexe
   let $nom :=  if ($visage/@nom) then (' item-name') else () (: named person :)
   let $idVsg :=  $visage/@n
   let $scoreCBIR := fn:format-number($visage/@CS,"9.99")
   let $sourceCBIR := $visage/@source

   (: affichage du menu Visages - display the Face menu :)
   return
      <div> {attribute  class  {concat('imgv item-face',$sexe,$nom)} } {attribute  id  {concat('face-',$idVsg)} }
      {if ($rotation=0) then (attribute  style  {concat('left:',$ratio * $visage/@x,";top:",$ratio * $visage/@y,";width:", $ratio * $visage/@w,";height:",$ratio * $visage/@h)}) else (
        attribute  style  {concat('right:',$ratio * $visage/@y,";top:",$ratio * $visage/@x,";width:", $ratio * $visage/@h,";height:",$ratio * $visage/@w)}
      )}
      <span class="txtlight">face {data($sexe)}&#8193;
      {if ($debug) then (<span>({data($sourceCBIR)}-{data($scoreCBIR)})</span>)}
      <br></br>
      {if ($debug) then (<div>ID: {data($idVsg)}</div>)}
      </span>
<div> {attribute  class {'menu-tipv'}}
<ul class="main-navigation">
<li><a  title="Ce n'est pas un visage" id="norm" class="fa" 
href="javascript:visage('{$corpus}','D', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf05e;</a></li>


 <li><a  title="Visage Femme" id="norm" class="fa" href="javascript:visage('{$corpus}','F', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf182;</a></li>
 <li><a  title="Visage Homme"  class="fa" href="javascript:visage('{$corpus}','M', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf183;</a></li>
  <li><a  title="Visage Enfant" id="norm" class="fa" href="javascript:visage('{$corpus}','C', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf1ae;</a></li>
  <li><a  title="Visage nommé" id="norm" class="fa" href="javascript:visage('{$corpus}','N', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf2ba;</a></li>
 </ul>
</div>
</div>
   }
    </div>
</div>
</div>
)
else
 (<div class="grid-warn">
 <div class="img"><img alt="pas de résultat" title="pas de résultat" src="/static/no-result.png"></img>
 <p>Query : {data($eval-string)}</p>
 </div></div>
)
}
</div>

(:   )  if else keyword="" :)
}

<script src="static/cropper.js"></script>
<script src="static/misc.js"></script>

<script>


// MAIN
localize('{$locale}');

//Array.from(document.querySelectorAll("button")).forEach(function (e) {{
//     e.style.display = 'none';
//  }});

console.log("end of init");
////////////////////////////////

// global variables    
var VScorpus ;
var VSsexe;
var VSidIll;
var VSid;
var VSidAnn; // id annotation en cours
var action;
var VSx2; // padding around the illustration
var VSy2 ;
var VSl2 ;
var VSh2 ;
var VSratio ;
var VSrot ;
var VScorpus;
var VSx0; // initial coords before segmentation
var VSy0; 
var VSxCrop; // new segmentation coord. after cropping
var VSyCrop;
var divCropper;

// flash the screen
function animer(id) {{
 console.log("flash id : "+id);
 var e = document.getElementById(id) ;
 e.removeAttribute("class");
 void e.offsetWidth; // astuce pour permettre de recommencer animation
 e.setAttribute("class", "anim");
}}

// call a xquery script
function popitup2(url,windowName) {{
       animer('body');
       newwindow=window.open(url,"ligneLog");
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}

// Filtrer une illustration
function filtreIll(corpus,id, n, source) {{
console.log("filtre id : "+id);
popitup2('/rest?run=filter.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}

// Défiltrer une illustration
function deFiltreIll(corpus,id, n, source) {{
console.log("unfilter ID: "+id+ " / "+n);
popitup2('/rest?run=unFilter.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}
    
// Supprimer une illustration
function suppIll(corpus,id, n, source) {{
console.log("supprimer id : "+id);

removeElement("ill-"+n);
popitup2('/rest?run=delIll.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}

// Supprimer une segmentation document
function suppSegmentDoc(corpus,id,nill,npage,source) {{
console.log("supprimer segment page : "+npage);

removeElement("doc-"+npage);
popitup2('/rest?run=delSegmentDoc.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ nill + '&amp;source=' + source) ;
    }}
    
// Filtrer une publicité illustrée
function filtrePub(corpus,id, nIll, source) {{
 console.log("id : "+id);

 popitup2('/rest?run=filterAd.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ nIll + '&amp;source=' + source) ;
    }}
function deFiltrePub(corpus,id, nIll, source) {{
 console.log("id : "+id);

 popitup2('/rest?run=unFilterAd.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ nIll + '&amp;source=' + source) ;
    }}
        
// Indiquer des personnes
function personne(corpus, p, id, n, source) {{
console.log("personne : "+ p);
console.log("id : "+id);
popitup2('/rest?run=person.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;person='+ p + '&amp;source=' + source) ;
    }}

// Gérer les visages
function visage(corpus, action, id, idIll, idVsg, source) {{
console.log("action : "+ action);
console.log("id : "+id);
console.log("idVsg : "+idVsg);
console.log("mode : "+ source);

 if ((action =="D") || (action =="FT")) {{
  removeElement("face-"+idVsg);
 }}
 popitup2('/rest?run=sex.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idVsg='+ idVsg + '&amp;cmd='+ action+ '&amp;source=' + source) ;
}}

// Supprimer tous les visages d une ill
function suppVisages(corpus, id, idIll, nVsg, source) {{
console.log("id : "+id);
console.log("mode : "+ source);

popitup2('/rest?run=delFaces.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;source=' + source) ;
for (i = 1; i != nVsg+1; i++) {{
 console.log(i) 
 removeElement("face-"+idIll+"-"+i);
}}

}}

// Supprimer tous les textes d une ill
function suppTextes(corpus, id, idIll, ntxts, source) {{
console.log("id : "+id);
console.log("mode : "+ source);

popitup2('/rest?run=delTxts.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;source=' + source) ;
for (i = 1; i != ntxts+1; i++) {{
 removeElement("txt-"+idIll+"-"+i);
}}
}}

function saisirTexte(corpus, id, idIll, idTxt, source) {{
console.log("id : "+id);
console.log("idTxt : "+idTxt);
console.log("mode : "+ source);

var texte = saisie();
if (texte != null) {{
  console.log("texte : "+ texte);
  popitup2('/rest?run=text.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idTxt='+ idTxt + '&amp;cmd=I&amp;source=' + source + '&amp;texte='+ texte) ;
 }} else {{console.log("... quit")}}
}}

// Gérer les textes
function texte(corpus, action, id, idIll, idTxt, source) {{
console.log("action : "+ action);
console.log("id : "+id);
console.log("idTxt : "+idTxt);
console.log("mode : "+ source);

if (action =="D") {{
  removeElement("txt-"+idTxt);
}}
popitup2('/rest?run=text.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idTxt='+ idTxt + '&amp;cmd='+ action+ '&amp;source=' + source) ;
    }}


function ajoutVisage(corpus, id, idIll, idVsg, sexe, source, urliiif, ratio_ill, x, y, l, h, rot ) {{
 console.log("nouveau visage : "+ sexe);
 console.log("id : "+id);
 console.log("idIll : "+idIll);
 console.log("mode : "+ source);
 console.log("rotation : "+ rot);
 console.log("x : "+ x);
 console.log("y : "+ y);
 console.log("l : "+ l);
 console.log("h : "+ h);
  
 VScorpus = corpus;
 VSsexe = sexe;
 VSidIll = idIll;
 VSid = id;
 VSidAnn = idVsg;
 action = "visage"
 VSx2 = 0; // no padding
 VSy2 = 0;
 VSl2 = l;
 VSh2 = h;
 VSratio = ratio_ill;
 VSrot = rot;

 //resize.bind({{url: urliiif,}});
 affCroppie(urliiif,  ratio_ill);

    }}


// Corriger la segmentation de l illustration
function segment(corpus,id, idIll, source, urliiif,  ratio_ill, x0, y0, x2, y2, l2, h2, rot) {{
console.log("id : "+id);
console.log("idIll : "+idIll);
console.log("mode : "+ source);
console.log("rotation : "+ rot);
console.log("ratio affichage : "+ ratio_ill);
console.log("x_0 : "+ x0);
console.log("y_0 : "+ y0);
console.log("x_padding : "+ x2);
console.log("y_padding : "+ y2);
console.log("l_padding : "+ l2);
console.log("h_padding : "+ h2);

 VSsource  = source;
 VScorpus = corpus;
 VSidIll = idIll;
 VSid = id;
 action = "segment";
 VSx2 = x2;
 VSy2 = y2;
 VSl2 = l2;
 VSh2 = h2;
 VSratio = ratio_ill;
 VSrot = rot;
 VSx0 = x0;
 VSy0 = y0;
 
 affCroppie(urliiif,  ratio_ill);
 window.setTimeout(jumpBottom, 1200);
    }}

// Ajouter une segmentation pour le "document" (carte postale, affiche, couverture)
function segmentDoc(corpus,id, idIll, source, urliiif, ratio_ill, x2, y2, l2, h2, rot) {{
console.log("id : "+id);
console.log("idIll : "+idIll);
console.log("mode : "+ source);
console.log("rotation : "+ rot);
console.log("ratio affichage : "+ ratio_ill);
console.log("x2 : "+ x2);
console.log("y2 : "+ y2);
console.log("l2 : "+ l2);
console.log("h2 : "+ h2);

 VSsource  = source;
 VScorpus = corpus;
 VSidIll = idIll;
 VSid = id;
 action = "segmentDoc";
 VSx2 = x2;
 VSy2 = y2;
 VSl2 = l2;
 VSh2 = h2;
 VSratio = ratio_ill;
 VSrot = rot;

 affCroppie(urliiif, ratio_ill);
 window.setTimeout(jumpBottom, 1200);
    }}
        
// Ajouter une  segmentation de bloc de texte
function segmentTxt(corpus,id, idIll, idTxt, source, urliiif,ratio_ill, x2, y2, l2, h2, rot) {{console.log("id : "+id);
console.log("idIll : "+idIll);
console.log("mode : "+ source);
console.log("rotation : "+ rot);
console.log("ratio affichage : "+ ratio_ill);
console.log("x2 : "+ x2);
console.log("y2 : "+ y2);
console.log("l2 : "+ l2);
console.log("h2 : "+ h2);

 VScorpus = corpus;
 VSidIll = idIll;
 VSidAnn = idTxt;
 VSid = id;
 action = "txt";
 VSx2 = x2;
 VSy2 = y2;
 VSl2 = l2;
 VSh2 = h2;
 VSratio = ratio_ill;
 VSrot = rot;

 affCroppie(urliiif, ratio_ill);
 window.setTimeout(jumpBottom, 1000);
}}
    
function jumpBottom(){{
    jump('bottom');
}}

function jump(h){{
    var top = document.getElementById(h).offsetTop;
    window.scrollTo(0, top);
}}

// Scinder en 2 illustrations
function copyIll(corpus,id, idIll, idNew, source,mode) {{
 console.log("id : "+id);
 console.log("idIll : "+idIll);
 console.log("mode : "+ source);

 popitup2('/rest?run=copyIll.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idNew='+ idNew + '&amp;source=' + source + '&amp;mode=' + mode) ;
window.setTimeout(reloadPage, 300);
    }}

// Renuméroter les illustrations
function renumberIlls(corpus,id, page) {{
 console.log("id : "+id);
 console.log("page : "+ page);

 popitup2('/rest?run=renumber.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;page='+ page) ;
 window.setTimeout(reloadPage, 300);
}}
 
// Créer une illustration
function createIll(corpus,id, page, idIll, w,h) {{
 console.log("id : "+id);
 console.log("page : "+ page);
 console.log("ID ill : "+ idIll);
 if (w == ''){{w=500}}
 if (h == ''){{h=500}}
 console.log("w : "+ w);
 console.log("h : "+ h);
  
 popitup2('/rest?run=createIll.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;page='+ page + '&amp;idIll='+ idIll + '&amp;w=' + w + '&amp;h=' + h) ;
 window.setTimeout(reloadPage, 300);
}}
   
// Reset segmentation illustration: x=1, y=1, w=l, h=h
function reset(corpus,id, idIll, source, l, h, rot ) {{
 console.log(" ... reset"); 
 console.log("id : "+id);
 console.log("idIll : "+ idIll);
 console.log("mode : "+ source);
 
 popitup2('/rest?run=reset.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;source=' + source + '&amp;l=' + l + '&amp;h=' + h) ;
 window.setTimeout(reloadPage, 300);
}}

// Mise à jour des tags
function updateTags(corpus, id, n, source, x0, y0, xn, yn, rot ) {{
  console.log("...update tags coordinates");  
  
  window.setTimeout(popitup2('/rest?run=updateTagsSeg.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ id + '&amp;idIll='+ n + '&amp;source=' +source+ '&amp;x0='+x0 + '&amp;y0='+y0 +'&amp;xn='+ xn + '&amp;yn='+ yn), 2000); 
}}
    
// To fix gender
function fixGenre(corpus,id, n, type, source) {{
 console.log("id: "+id);
 console.log("n: "+n);
 console.log("change to: "+type);
 popitup2('/rest?run=updateGenre.xq&amp;locale={$locale}&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n  + '&amp;type=' + type + '&amp;source=' + source ) ;
    }}


// display the whole page with illustrations
function displayPage(corpus, id, page, npages, cbir, cs, module) {{
 console.log("id: "+ id);
 console.log("n° page: "+ page);
 console.log("pagination : "+ npages);
 if (page > npages) {{ console.log("Oups...")}}
 else {{
  window.open('/rest?run=display.xq&amp;locale={$locale}&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;nPages='+npages+'&amp;CBIR='+cbir+'&amp;CS='+cs+'&amp;module='+module+'&amp;sourceTarget=&amp;keyword=',"_self" )}}
    }}

// display the next issue (for periodicals)
function displayIssue(corpus, id, cbir, cs) {{
 console.log("id suivant: "+ id);
 window.open('/rest?run=display.xq&amp;locale={$locale}&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;CS='+cs+'&amp;pageOrder='+1+'&amp;CBIR='+cbir+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}

// display the illustrations on the same page
function samePage(corpus, id, page) {{
 console.log("id : "+ id);

 window.open('/rest?run=findIllustrations-app.xq&amp;locale={$locale}&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}

// display the illustrations in the same document
function sameDoc(corpus, id) {{
console.log("id : "+ id);

 window.open('/rest?run=findIllustrations-app.xq&amp;locale={$locale}&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}

// Ajouter des tags
function tag(corpus,tag, id, n, source) {{
 console.log("tag : "+ tag);
 console.log("id : "+id);
 popitup2('/rest?run=insertTag.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;tag='+ tag + '&amp;source=' + source) ;
    }}
    


// display the cropper
function affCroppie(url, ratio_ill) {{
 console.log("largeur affichage (px) : ",{$largeur});
 console.log("ratio ill : ",ratio_ill);
 console.log(url);
 
 var image = new Image();
 image.onload = function () {{
       document.body.style.cursor='default';
       new Cropper(this, {{
                     update: function (coordinates) {{
                         for (var i in coordinates) {{  // coordinates in illustration space
                                document.getElementById(i + '-1').value =  parseInt(coordinates[i]/ratio_ill);
                                        }}
                                    }}
                                }});
                        
                            }};
  document.body.style.cursor='wait';   
  image.src = url; 
  var div = document.getElementById('cropper');
  div.style.display =  'inline-block' ;
  divCropper = document.getElementById("image-cropper");
  divCropper.addEventListener('keydown', touchesCrop);

  document.getElementById("image-cropper").appendChild(image);  
  var coords = document.getElementById('coords');
  coords.style.display =  'inline-block' ;
  var divBoutons = document.getElementById('resizer-buttons');
  divBoutons.style.display =  'inline-block' ;
  
  if ((action == "segment" ) || (action == "segmentDoc" )) {{ 
     document.getElementById('crops').innerHTML = "(".concat(action,')');}} 
   else {{
     document.getElementById('crops').innerHTML = "(".concat(action,') : ', VSidAnn - 1); 
     }} 
  document.getElementById('idIll').innerHTML = VSidIll;
  
 }}

Array.from(document.querySelectorAll(".resizer-quit")).forEach(function (e) {{
     e.addEventListener('click',quitCropper)  }});


function quitCropper() {{
      console.log("... quit");
      if (action=="segment") {{
          console.log("... updating tags");
          updateTags(VScorpus, VSid, VSidIll, VSsource, VSx0, VSy0, VSxCrop, VSyCrop, VSrot );
        }}
      window.setTimeout(reloadPage, 500);
}};

function creerCrop(ev) {{ 
        console.log("...cropping");
        //divCropper.addEventListener('keydown', touchesCrop);
        console.log("id: "+VSid);
        console.log("ill id: "+VSidIll);
        // crops in the illustration coordinates space
        x = document.getElementById('x-1').value
        console.log("x_crop: "+x);
        y = document.getElementById('y-1').value
        console.log("y_crop: "+y);
        l = document.getElementById('width-1').value
        console.log("l_crop: "+ l);
        h = document.getElementById('height-1').value
        console.log("h_crop: "+ h);
        // padding in the illustration coordinates space
        console.log("x_padding: "+ VSx2);
        console.log("y_padding: "+ VSy2);
        console.log("l_padding: "+ VSl2);
        console.log("h_padding: "+ VSh2);
        console.log("ratio affichage/reel : " + VSratio);
        
        // we add the illustration x padding to the x cropping
        if (VSrot==0) {{
          VSxCrop = VSx2 + parseInt(x) - 1;
          VSyCrop = VSy2 + parseInt(y) - 1;
          lCrop = parseInt(l);
          hCrop = parseInt(h);
         }} else
        {{ // works for 90° rotation       
          VSxCrop = VSx2 + parseInt(y) - 1;
          VSyCrop = VSy2 + VSh2 - l - parseInt(x) - 1;
          lCrop = parseInt(h);
          hCrop = parseInt(l);
        }}
        console.log("xCrop: "+ VSxCrop);
        console.log("yCrop: "+ VSyCrop);
        console.log("lCrop: "+ lCrop);
        console.log("hCrop: "+ hCrop);
        console.log("action: "+ action);
        switch (action) {{
         case 'visage':
          console.log("...Visage");
          popitup2('/rest?run=addFace.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;idVisage='+ VSidAnn + '&amp;sexe='+ VSsexe+ '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+ VSxCrop + '&amp;y='+VSyCrop+ '&amp;l='+lCrop+ '&amp;h='+hCrop);
          document.getElementById('crops').innerHTML = VSidAnn;
          VSidAnn++; 
          break;

         case 'txt':
          console.log("...SegmentTxt");
          popitup2('/rest?run=addTxt.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;idTxt='+ VSidAnn + '&amp;sexe='+ VSsexe+ '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+VSxCrop + '&amp;y='+VSyCrop+ '&amp;l='+lCrop+ '&amp;h='+hCrop);
          document.getElementById('crops').innerHTML = "(".concat(action,') : ', VSidAnn); 
          VSidAnn++;
          break;
          
         case 'segmentDoc':
          console.log("...SegmentDoc");
          popitup2('/rest?run=segmentDoc.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;idTxt='+ VSidAnn + '&amp;sexe='+ VSsexe+ '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+VSxCrop + '&amp;y='+VSyCrop+ '&amp;l='+lCrop+ '&amp;h='+hCrop);
          break;
          
         case 'segment' :
          console.log("...Segment");
          popitup2('/rest?run=segment.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+VSxCrop+ '&amp;y='+VSyCrop+ '&amp;l='+lCrop+ '&amp;h='+hCrop);
                   
           //window.setTimeout(reloadPage, 700);
        }}
}}

Array.from(document.querySelectorAll(".resizer-result")).forEach(function (e) {{
     e.addEventListener('click', creerCrop)  }});

//document.querySelector('.resizer-result').addEventListener('click', creerCrop) ;

// raccourcis clavier     
function touchesCrop(event) {{
  if ((event.code == 'KeyN') || (event.code == 'Enter')) {{
    console.log('event: '+event.code);
    creerCrop();
  }} 
}}
  
document.addEventListener('keydown', touchesCrop);
       




document.onkeyup = function(e) {{
  if (e.which == 77) {{
    alert("M key was pressed");
  }} else if (e.which == 66) {{
    alert("B key");
  }}
}};

function reloadPage() {{
   console.log("reloadPage...");
   document.location.reload(true);
}}

</script>


<script>
console.log("end script");
</script>
</body >
</html>
  };


(: Execution de la requete sur la base BaseX - le nom de la base doit etre donne ici
   The BaseX database must be specify here                :)

let $url := $corpus    (: collection BaseX  :)
return
try {
    if (not (gp:isAlphaNum($corpus))) then (
    (: do nothing :)
    <div>
      <h2>Une erreur est survenue !</h2>
      <p>Erreur corpus : {$url}</p>
    </div>
) else (
    local:createHTMLOutput($corpus)
  )}
catch * {
    <h2>Une erreur est survenue !</h2>,
    'Erreur [' || $err:code || '] : ' || $err:description,
       <br></br>,
    $err:value, " module : ", $err:module, "(", $err:line-number, ",", $err:column-number, ")",
    <p>Merci de bien vouloir contacter gallica@bnf.fr afin de la signaler.</p>
    } 
  