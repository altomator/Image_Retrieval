(:
 Display a page, it's illustrations and face crops inside illustrations
 Affiche une page, ses illustrations et les visages dans les illustrations
:)

declare namespace functx = "http://www.functx.com";
declare option output:method 'html';

(: Arguments du formulaire avec valeurs par defaut
   Args and default values from the form              :)
declare variable $corpus as xs:string external ;  (: base - database :)
declare variable $id as xs:string external := "" ;  (: ID document / document ID :)
declare variable $pageOrder as xs:integer external  := 1 ; (: numéro de page / page number :)
declare variable $nPages as xs:integer external := 0  ; (: pagination  :)
declare variable $illType as xs:string external := "" ;   (: types du document : carte, photo... / document type: map, picture... Multiple types: gravure_photog  :)
declare variable $sourceData as  xs:string := "final"; (: source de données à interroger / target of the request :)

declare variable $CBIR as xs:string external := "*"; (: source des données de classification / source of the classification data: * / ibm / dnn / google :)
declare variable $CS as xs:decimal external := 0.1; (: seuil pour la classification / threshold on classification Confidence Score, from 0 to 10 - 0%-100% :)
declare variable $faceClass as xs:string external := "face"; (: nom du concept "visage" / name of the Face class "face" :)
declare variable $sourceEdit as  xs:string := "hm"; (: source des données annotées / source of the human annotations: hm / cwd :)
declare variable $locale as xs:string external := "" ; (: localisation / localization : "fr"/"en" :)

declare variable $debug as xs:integer external := 0 ;  (: developpement-production / switch dev-prod :)

(: module d'affichage des images : 0.5 / 1.0 / 2.0 / Size of the thumbnails :)
declare variable $module as xs:decimal external := 1;
(: largeur des images affichées :)
declare variable $largeur as xs:integer external := $module * 600; 
(: Gallica .medres=512 px en largeur
   Paris-match : 595 :)

(: mise en page HTML :)
declare variable $padding as xs:integer  := 5;
(: marge autour des illustrations iiif :)
declare variable $delta as xs:decimal  := 0.2;
(: facteur d'affichage  des illustrations iiif (%) :)
declare variable $pct as xs:decimal  := 50; (: 100 pour Paris Match :)

(: couleurs d'affichage du masque sur les visages 
Colors of the faces mask for Women, Man and no Gender:)
declare variable $coulF   := ";background-color: rgba(255,192,203,";
declare variable $coulM   := ";background-color: rgba(30,144,255,";
declare variable $coulP   := ";background-color: rgba(132,65,157,";

declare variable $dossierLocal  := "/static/img/" ;
(: -------- END parameters ---------- :)


(: Conversion de formats de date
   Date formats conversion       :)
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
<link rel="stylesheet" type="text/css" href="/static/croppie.css" />
<style> 
p {{
 color: black ;
 font-family: sans-serif;
 font-size: 9pt;
}}

body {{
    padding: {$padding}pt;
    
   }}
/* affichage des crops illustration - display the illustration crops */
/* illustration  */
.item-obj {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 2px;
   border-style: inset;
  border-color: rgba(255,127,80, 0.6);
  background-color: rgba(255,127,80,0.10);  /* orange */
  border-radius: 3px;
}}
/* illustration filtrée - filtered illustrations */
.filtre:before{{
	content:'&#xf00d;';
  font-weight: normal;
  padding-left:2px;
  font-size: 12pt;
  color: rgba(220, 20, 60, 0.7);   /* red */  
}}
.filtre {{
  background-color: rgba(100,100,100,0.80); 
  border-color: rgba(100,100,100, 0.7);
  border-style: dotted;
  border-width: 3px;
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
  z-index:6;
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
  z-index:6;
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
  z-index:6;
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
  z-index:6;
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
  z-index:6;
  border-width:2px;
  border-style: dotted;
  border-color: rgba(220,220,220, 0.7);
  background-color: rgba(220,220,220, 0.2);  /* gris */
  border-radius: 3px;
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
  width: { (235+xs:float($module)*50)}px;
  margin-top: 15px;
  margin-left: -15px;
}}

/* menu pour les visages - faces menu */
.menu-tipv{{
  width: { (50+xs:float($module)*50)}px;
  margin-top: -30px;
  margin-left: -30px;
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
   font-size:  {xs:float($module)*4+3}pt;;
   font-family: sans-serif;
   line-height: 1.2;
   color: white     
}}

.cropper {{  
  position: fixed;
  top: {$padding};
  right:100;
  border-width: 2px;
   }}
   
.menu-nav {{
  color:#cf6e33;
  float:right;
  line-height: 1.3;
  padding-top:10px;
  padding-right:36%
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
let $source := $illUn/../../../../../metad/source
let $type := $illUn/../../../../../metad/type
let $urlIIIFexterne := $illUn/../../../../../metad/urlIIIF
let $urlGallica := if ($source = "local") then (concat($dossierLocal,$illUn/../../../../../metad/fichier,"_",$pageOrder,".jpg"))
                   else if ($urlIIIFexterne) then ($illUn/../../../../../metad/url) (: other DLs :)
                   else ( concat("http://gallica.bnf.fr/ark:/12148/",$id,"/f",$pageOrder,".item")) (: Gallica :)   
let $idSuiv := $illUn/../../../../../metad/IDsuiv (: MD de la page - metadata for the page :)
let $URLiiif := if ($urlIIIFexterne) then ($urlIIIFexterne) 
                else if  ($debug = 1) then  (concat("http://gallica.bnf.fr/ark:/12148/",$id,"/f",$pageOrder,".medres")) 
                else  (concat("http://gallica.bnf.fr/iiif/ark:/12148/",$id,"/f",$pageOrder,"/full/",$largeur,"/0/native.jpg")) (: default is Gallica :) 
                    
let $date := $illUn/../../../../../metad/dateEdition
let $nPages := if ($nPages) then ($nPages) else ($illUn/../../../../../metad/nbPage)
(:let $rot := if ($illUn/@rotation) then ($illUn/@rotation) else (0):)
(: plus rapide :)
let $url := if ($source = "local") then 
             (concat($dossierLocal,$illUn/../../../../../metad/fichier,"_",$pageOrder,".jpg"))
            else ($URLiiif)

(: menu de navigation - navigation menu :)
return
<div>
<div>
<a href="{$urlGallica}" target="_blank" title="Gallica"><img src="{$url}"></img></a>
<p class="menu-nav">{$date} / #{$pageOrder}:{$nPages}<br></br>
CBIR : {$CBIR} / CS > {$CS}<br></br>
Genres :  {$illType}<br></br>
{if ($pageOrder != 1) then (<a class="fa" style="margin-top:10px;margin-right:4px;font-size:22pt;" title="Page précédente" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder}-1,{$nPages},'{$CBIR}','{$CS}')">&#xf0d9;</a>) else ()}
<span class="fa" style="font-size:18pt">&#xf016;</span>
{if ($pageOrder < $nPages) then (<a class="fa" style="font-size:22pt;" title="Page suivante" href="javascript:displayPage('{$corpus}','{$id}',{$pageOrder}+1,{$nPages},'{$CBIR}','{$CS}')">&#xf0da;</a>) else ()}
<br></br>
<span class="fa" style="line-height: 2.5;font-size:18pt;padding-left:1em">&#xf0c5;</span>
{if ($type = "P") then (<a class="fa" style="font-size:22pt;" title="Numéro suivant" href="javascript:displayIssue('{$corpus}','{$idSuiv}','{$CBIR}','{$CS}')">&#xf0da;</a>)}
<br></br>
<iframe style="color:black;z-index:6;float:right;padding-right:10%;margin-top:600;height:50px;width:300px" name="ligneLog" frameborder="1" src="">
  <p>Erreur : votre navigateur ne supporte pas les iframe !</p>
</iframe>
</p>
<div class="cropper">
 <div id="resizer-demo"></div> 

 <div class="actions">
   <button class="button resizer-result">Modifier</button>
  
 </div>
</div>
</div>
{ 
 if ($subhits) then ( 
 (: traiter toutes les illustrations - processing all the illustrations :) 
  for $ill in $subhits 
    let $nPage := $ill/../../@ordre
    let $illSuiv := concat($nPage,'-',$nbIlls+1)
    (: get all the classes from the CBIR source :) 
    let $cbirClasses := if($CBIR='*') then ($ill/contenuImg[@CS>=$CS]) else ($ill/contenuImg[@source=$CBIR and @CS>=$CS])
    (: get all the faces from the CBIR source :)
    let $vgs := $ill/contenuImg[text()=$faceClass]
    let $nVsg :=  if ($vgs) then (count($vgs)) else (0)
    let $CBIRClassesNorm := fn:string-join($cbirClasses, ', ') (: classes sémantiques :)     
    let $personne := functx:gender($CBIRClassesNorm,'classes') 
    let $genre := $ill/genre[@source="final"]        
    let $label := substring(replace($ill/leg,'''','&#8217;'),1,25)
    let $label := if (not ($label)) then (substring(replace($ill/titraille,'''','&#8217;'),1,25)) else ($label)
    let $URLiiif := concat("http://gallica.bnf.fr/iiif/ark:/12148/",$id,"/f",$pageOrder,"/") (: default is Gallica :)
    let $x := $ill/@x
    let $y := $ill/@y
    let $l := $ill/@w
    let $h := $ill/@h
    let $lPage := if ($ill/../../@l) then (xs:integer($ill/../../@l)) else (xs:integer($ill/../../../../largeurPx)) (: retrocompatibility :)
    let $hPage := if ($ill/../../@h) then (xs:integer($ill/../../@h)) else (xs:integer($ill/../../../../hauteurPx))
    let $delta := if (((1+$delta)*$l>$lPage) or ((1+$delta)*$h>$hPage)) then (0) else ($delta)
    let $deltaL := xs:integer($ill/@w * $delta)
    let $deltaH := xs:integer($ill/@h * $delta)
    let $x2 := if ($x - $deltaL*0.5 < 0) then (0) else (xs:integer($x - 0.5*$deltaL))
    let $y2 := if ($y - $deltaH*0.5 < 0) then (0) else (xs:integer($y - 0.5*$deltaH))
    let $l2 := if ($x2 + $l + $deltaL*0.5 > $lPage) then ($lPage - $x2) else ($l + $deltaL)
    let $h2 := if ($y2 + $h + $deltaH*0.5 > $hPage) then ($hPage - $y2) else ($h + $deltaH)
    let $rotation := 0 (:if ($ill/@rotation) then ($ill/@rotation) else (0) :)
    let $iiif :=   concat( $URLiiif, $x,",",$y,",",$l,",",$h,"/pct:",$pct,"/",$rotation,"/native.jpg") 
    let $iiifDelta :=   concat( $URLiiif, $x2,",",$y2,",",$l2,",",$h2,"/pct:",$pct,"/",$rotation,"/native.jpg") 
    let $urlIll := if ($source = "local") then 
             ($urlGallica)
            else ($iiif) 
    let $filtre := if ($ill/@filtre) then ("filtre") else () (: filtered illustrations :)
    let $pub := if ($ill/@pub) then ("pub") else ()      (: ads :)
    (: calcul du ratio taille affichage page/taille illustration - ratio illustration/page sizes :)        
    let $ratio := fn:number($largeur) div fn:number($lPage)    
return
<div> {attribute  class  {concat('img item-obj fa ', $filtre, $pub)} }
      {attribute  style  {concat('left:',$padding+($ratio * $x),";top:",$padding+($ratio*$y),";width:",
      $ratio * $l,";height:",$ratio * $h)}}
     {if (not ($filtre)) then (
       <div>
{if ($debug) then (<span class="txtlight">{data($label)}...<br></br><br></br>
{data($CBIRClassesNorm)}
<br></br><br></br>

genre : {data($genre)}<br></br>
personnes : {data($personne)}<br></br>
#faces : {data($nVsg)}<br></br>
#classes : {data(count($cbirClasses))}</span>)}    
<div> {attribute  class  {'menu-tip'}}
<ul class="main-navigation" id="liste">
<li><a  title="Ajouter dans l'illustration " id="norm" class="fa" href="#">&#xf067;</a>
 <ul>
 
     <li><a  title="Visage de femme"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'F','{$sourceEdit}','{$urlIll}',{$l div $h},{$x},{$y})">&#xf182;</a></li>
     <li><a  title="Visage d'homme"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'M','{$sourceEdit}','{$urlIll}',{$l div $h},{$x},{$y})">&#xf183;</a></li>
     <li><a  title="Visage d'enfant"  class="fa" id="norm"  href="javascript:ajoutVisage('{$corpus}', '{$id}', '{$ill/@n}',{$nVsg}+1,'C','{$sourceEdit}','{$urlIll}',{$l div $h},{$x},{$y})">&#xf1ae;</a></li>
 </ul>
</li>

 <li><a  title="Signaler une femme" id="norm" class="fa" href="javascript:personne('{$corpus}','woman', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;</a></li>
 <li><a  title="Signaler un homme"  class="fa" href="javascript:personne('{$corpus}','man', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf183;</a></li>
 <li><a  title="Signaler un enfant"  class="fa" id="norm"  href="javascript:personne('{$corpus}','child', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf1ae;</a></li>
 <li><a  title="Signaler un couple"  class="fa" href="javascript:personne('{$corpus}','couple', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf183;</a></li>
 <li><a  title="Signaler un groupe de femmes"  class="fa" href="javascript:personne('{$corpus}','group of women', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf182;</a></li>
 <li><a  title="Signaler un groupe d'hommes"  class="fa" href="javascript:personne('{$corpus}','group of men', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf183;&#xf183;</a></li>
 <li><a  title="Signaler un groupe mixte"  class="fa" href="javascript:personne('{$corpus}','group of people', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;&#xf183;&#xf182;&#xf183;</a></li>
 <li><a  class="fa" title="Signaler une foule"  href="javascript:personne('{$corpus}','crowd', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf0c0;</a></li> 
  <li><a  class="fa" title="Actualité"  href="javascript:tag('{$corpus}','news', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf017;</a></li>
<li><a  title="Modifier l'illustration" id="norm" class="fa" href="#">&#xf0c4;</a>
 <ul>
  <li><a  class="fa"  title="Resegmenter l'illustration"  href="javascript:segment('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}','{$iiifDelta}',{$l div $h},{$x2},{$y2})">&#xf125;</a></li>
    <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration vert."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V')">&#xf248; V</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V13')">&#xf248;</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration vert. au 2nd tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','V23')">&#xf248;</a></li>
     <li><a  class="fa" style="font-size:8pt"  title="Partager l'illustration horiz."  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H')">&#xf248; H</a></li>
      <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au premier tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H13')">&#xf248;</a></li>
       <li><a  class="fa" style="font-size:8pt"  title="Découper l'illustration horiz. au 2e tiers"  href="javascript:copyIll('{$corpus}','{$id}', '{$ill/@n}','{$illSuiv}','{$sourceEdit}','H23')">&#xf248;</a></li>
  <li><a  class="fa" title="Filter l'illustration"  href="javascript:filtre('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}')">&#xf014;</a></li>
 <li><a  title="Signaler une publicité"  class="fa"  href="javascript:filtrePub('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf217;</a></li>

 </ul>
</li>  
 </ul>
 </div>
  </div>
)
 else ()} 
 
 {if ($personne != "") then (
  (: afficher les icones de type Personne - display the Person icons :) 
        <div> {attribute  class  {concat('fa fa-user item-',$personne)}}   </div>
      ) else ()   
 }
 
 { (: afficher les crops des visages - display the face crops :)
  let $req := concat($CBIRsource," and text()='", $faceClass, "' and @CS>=",$CS)
  let $visages := if($CBIR='*') then ($ill/contenuImg[text()=$faceClass and @CS>=$CS]) else ($ill/contenuImg[@source=$CBIR and text()=$faceClass and @CS>=$CS])
  let $nVisagesCBIR := count($visages)
  for $visage in $visages       
   let $sexe :=  $visage/@sexe
   let $nom :=  if ($visage/@nom) then (' item-name') else ()
   let $idVsg :=  $visage/@n
   let $scoreCBIR := fn:format-number($visage/@CS,"9.99")
   let $sourceCBIR := $visage/@source
   
   (: affichage du menu Visages - display the Face menu :)
   return      
      <div> {attribute  class  {concat('imgv item-face',$sexe,$nom)} }
      {attribute  style  {concat('left:',$ratio * $visage/@x,";top:",$ratio * $visage/@y,";width:", $ratio * $visage/@l,";height:",$ratio * $visage/@h)}}
      <span class="txtlight">face {data($sexe)} 
      {if ($debug) then (<div>({data($sourceCBIR)}-{data($scoreCBIR)})</div>)}
      <br></br>
      {if ($debug) then (<div>id: {data($idVsg)}</div>)} 
      </span>
<div> {attribute  class {'menu-tipv'}}
<ul class="main-navigation">
<li><a  title="Ce n'est pas un visage" id="norm" class="fa" href="javascript:visage('{$corpus}','FT', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf05e;</a></li>

 <li><a  title="Visage Femme" id="norm" class="fa" href="javascript:visage('{$corpus}','F', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf182;</a></li>
 <li><a  title="Visage Homme"  class="fa" href="javascript:visage('{$corpus}','M', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf183;</a></li> 
  <li><a  title="Visage Enfant" id="norm" class="fa" href="javascript:visage('{$corpus}','C', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf1ae;</a></li>
  <li><a  title="Visage nommé" id="norm" class="fa" href="javascript:visage('{$corpus}','N', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf2ba;</a></li> 
 </ul>
</div>
</div>     
   }
   
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

<script src="/static/croppie.js"></script>

<script>
// localiser les interfaces
function localize (language)
{{
  console.log("localize : "+language);
  if (language.includes('fr')) {{
     lang = ':lang(fr)';
     hide = '[lang]:not(' + lang + ')';
     show = '[lang]' + lang;
     try {{
     //document.getElementById('linkShare').title="Partager l'illustration";
     //document.getElementById('linkCorrect').title="Corriger l'illustration";
     //document.getElementById('linkFilter').title="Filtrer";
     // document.getElementById('linkSimilar').title="Chercher des illustrations similaires" ;
    //  document.getElementById('linkD').title="Signaler un dessin" ;
    // document.getElementById('linkM').title="Signaler une carte" ;
    //  document.getElementById('linkPG').title="Signaler une photogravure" ;
   }}
   catch (e) {{
      console.log ("Error : "+e);  
     }}    
   }}
   else 
    {{
     lang = ':lang(en)';
     hide = '[lang]:not(' + lang + ')';
     show = '[lang]' + lang;
     try {{
     document.getElementById('linkShare').title="Share the illustration";
     document.getElementById('linkCorrect').title="Correct the illustration";
     document.getElementById('linkFilter').title="Filter the illustration";
    // document.getElementById('linkSimilar').title="Look for similar illustrations" ;
     }}
     catch (e) {{}}  
   }} 
   console.log("lang : "+lang);
   Array.from(document.querySelectorAll(hide)).forEach(function (e) {{
      e.style.display = 'none';
    }});
    Array.from(document.querySelectorAll(show)).forEach(function (e) {{
      e.style.display = 'unset';
    }});
}}

// MAIN
//locale = (navigator.language) ? navigator.language : navigator.userLanguage;
//window.onload=localize(locale);
//window.onload=localize('en');

localize('{$locale}'); 


console.log("end of init");

 

//  pour les panneaux pop-up
function showhide(id) {{
 console.log("showhide id : "+id);  
 var e = document.getElementById(id);
 e.style.display = (e.style.display == 'block') ? 'none' : 'block';
}}

function animer(id) {{
 console.log("flash id : "+id);
 var e = document.getElementById(id) ;
 e.removeAttribute("class"); 
 void e.offsetWidth; // astuce pour permettre de recommencer animation
 e.setAttribute("class", "anim");
}}


//  pour le post Facebook
function fbShare(url, titre, legende, descr, image) {{
        window.open('http://www.facebook.com/dialog/feed?app_id=728828667272654&amp;link='+ encodeURIComponent(url) + '&amp;redirect_uri' + encodeURIComponent(url)
 + '&amp;picture=' + encodeURIComponent(image) + '&amp;name='+ encodeURIComponent(titre) +
 '&amp;caption=' + encodeURIComponent(legende) + '&amp;description=' + encodeURIComponent(descr),
 'feedDialog', 'toolbar=0,status=0,width=500,height=450') ;
    }}

// pour les formulaires d edition (crowdsourcing)
function edit(locale, corpus, id, n, iiif, typeDoc, titre, titraille, legende, theme, genre, couleur,source) {{
  console.log("type : "+typeDoc);
  console.log("couleur : "+couleur);
  console.log("genre : "+genre);
  console.log("theme : "+theme);
  window.open('/rest?run=findIllustrations-edit.xq&amp;locale='+ locale + '&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;iiif='+ iiif
  + '&amp;type='+ typeDoc +'&amp;title='+ encodeURIComponent(cutString(titre,70)) + '&amp;subtitle=' + encodeURIComponent(cutString(titraille,75))  + '&amp;caption=' + encodeURIComponent(legende)  + '&amp;iptc=' + theme + '&amp;illType=' + genre + '&amp;color=' + couleur + '&amp;source=' + source , 'feedDialog',
  'toolbar=0,status=0,width=750,height=570,top=100,left=300') ;
    }}

// OCR
function editOCR(locale, corpus, id, n, url, typeDoc, titre, titraille, legende, texte, source) {{
  console.log("type : "+typeDoc);
  
  window.open('/rest?run=findIllustrations-editOCR.xq&amp;locale='+ locale + '&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;url='+ url
  + '&amp;type='+ typeDoc +'&amp;title='+ encodeURIComponent(cutString(titre,70)) + '&amp;subtitle=' + encodeURIComponent(titraille)  + '&amp;caption=' + encodeURIComponent(legende) + '&amp;txt=' + encodeURIComponent(texte) + '&amp;source=' + source , 'feedDialog',
  'toolbar=0,status=0,width=600,height=450,top=100,left=300') ;
    }}
    

// Indiquer des personnes
function personne(corpus, p, id, n, source) {{
console.log("personne : "+ p);
console.log("id : "+id);
popitup2('/rest?run=person.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;person='+ p + '&amp;source=' + source) ;
    }}
    
function visage(corpus,sexe, id, idIll, idVsg, source ) {{
console.log("sexe : "+ sexe);
console.log("id : "+id);
console.log("idVsg : "+idVsg);
console.log("mode : "+ source);
popitup2('/rest?run=sex.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idVsg='+ idVsg + '&amp;cmd='+ sexe+ '&amp;source=' + source) ;
    }}

var VScorpus;
var VSsexe;
var VSidIll;
var VSid;
var VSnVsg;
var VSsource;
var VSx2;
var VSy2;
var action;
var resize;
 
function ajoutVisage(corpus, id, idIll, idVsg, sexe, source, urliiif,ratio, x, y ) {{
 console.log("nouveau visage : "+ sexe);
 console.log("id : "+id);
 console.log("idIll : "+idIll);
 console.log("mode : "+ source);

 VScorpus = corpus;
 VSsexe = sexe;
 VSidIll = idIll;
 VSid = id;
 VSnVsg = idVsg;
 action = "addFace"
 VSx2 = 0;
 VSy2 = 0;

//resize.bind({{url: urliiif,}});
affCroppie(urliiif, ratio);

//popitup2('/rest?run=addFace.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idVisage='+ idVisage+ '&amp;sexe='+ sexe+ '&amp;source=' + source) ;
    }}
 
           
// Filtrer une illustration
function filtre(corpus,id, n, source) {{
console.log("filtre id : "+id);
popitup2('/rest?run=filtre.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}
    
// Filtrer une publicité illustrée    
function filtrePub(corpus,id, idIll, source) {{
console.log("pub id : "+id);

popitup2('/rest?run=filtrePub.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ n + '&amp;source=' + source) ;
    }}
    
// Demander la segmentation
function segment(corpus,id, idIll, source, urliiif,ratio, x2, y2) {{
console.log("id : "+id);
console.log("idIll : "+idIll);
console.log("mode : "+ source);
console.log("ratio : "+ ratio);

VScorpus = corpus;
VSidIll = idIll;
VSid = id;
action = "segment";
VSx2 = x2;
VSy2 = y2;

affCroppie(urliiif, ratio);

//popitup2('/rest?run=segment.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;source=' + source) ;
    }}

// Scinder en 2 illustrations
function copyIll(corpus,id, idIll, idNew, source,mode) {{
console.log("id : "+id);
console.log("idIll : "+idIll);
console.log("mode : "+ source);

popitup2('/rest?run=copyIll.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idNew='+ idNew + '&amp;source=' + source + '&amp;mode=' + mode) ;
window.setTimeout(reloadPage, 300);  
    }}
    
// To fix gender
function fixGenre(corpus,id, n, type, source) {{
console.log("id: "+id);
console.log("n: "+n);
console.log("change to: "+type);
popitup2('/rest?run=updateGenre.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n  + '&amp;type=' + type + '&amp;source=' + source ) ;
    }}


// display the whole page with illustrations            
function displayPage(corpus, id, page, npages, cbir, cs) {{
console.log("id: "+ id);
console.log("n° page: "+ page); 
console.log("pagination : "+ npages); 
if (page > npages) {{ console.log("Oups...")}}
else {{ 
window.open('/rest?run=display.xq&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;nPages='+npages+'&amp;CBIR='+cbir+'&amp;CS='+cs+'&amp;sourceTarget=&amp;keyword=',"_self" )}}
    }}

// display the next issue (for periodicals)            
function displayIssue(corpus, id, cbir, cs) {{
console.log("id suivant: "+ id);
window.open('/rest?run=display.xq&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;CS='+cs+'&amp;pageOrder='+1+'&amp;CBIR='+cbir+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}
                        
// display the illustrations on the same page            
function samePage(corpus, id, page) {{
console.log("id : "+ id);
  
window.open('/rest?run=findIllustrations-app.xq&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}

// display the illustrations in the same document            
function sameDoc(corpus, id) {{
console.log("id : "+ id);
  
window.open('/rest?run=findIllustrations-app.xq&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}
                    
// Ajouter des tags
function tag(corpus,tag, id, n, source) {{
console.log("tag : "+ tag);
console.log("id : "+id);
popitup2('/rest?run=insertTag.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;tag='+ tag + '&amp;source=' + source) ;
    }}
    
function popitup(url,windowName) {{
       newwindow=window.open(url,"editW",'height=120,width=320,top=200,left=400,menubar=0,status=0,toolbar=0,titlebar=0,location=0');
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}  

function popitup2(url,windowName) {{
       animer('body');
       newwindow=window.open(url,"ligneLog");
       if (window.focus) {{newwindow.focus()}}
       return false;
     }} 
         
function escapeRegExp(str) {{
    return str.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}}

function replaceAll(str, find, replace) {{
    return str.replace(new RegExp(escapeRegExp(find), 'g'), replace);
}}

function cutString(str,l) {{
  return  str.substring(0,l);
}}



function affCroppie(url, ratio) {{
 console.log("largeur : ",{$largeur});
 console.log("ratio : ",ratio);
 
 var el = document.getElementById('resizer-demo');
 if (ratio>1) {{ larg = {$largeur}; haut = {$largeur}/ratio  }} 
 else {{larg = {$largeur}*1.2*ratio; haut = {$largeur}*1.3 }}
 switch (action) {{
  case 'addFace':
   resize = new Croppie(el, {{
    viewport: {{ width: 0.15*{$largeur}, height:  0.15*{$largeur}  }},
    boundary: {{ width: larg, height:  haut  }},
    showZoomer: false, 
    enableResize: true,
    enableOrientation: true,
    mouseWheelZoom: 'ctrl',     
   }});
   break;       
   case 'segment' :
   resize = new Croppie(el, {{
    viewport: {{ width: 0.9*{$largeur}, height:  0.9*{$largeur}/ratio  }},
    boundary: {{ width: {$largeur}, height:  {$largeur}/ratio  }},
    showZoomer: false, 
    enableResize: true,
    enableOrientation: true,
    mouseWheelZoom: 'ctrl',     
   }});
   break;}}
          
  resize.bind({{url: url,}});
}}


document.querySelector('.resizer-result').addEventListener('click', function (ev) {{
 resize.result({{
  type: 'html'
  }}).then(function (html) {{
        console.log("...crop");
        // console.log(html.outerHTML);             
        points = resize.get().points;
        console.log("id: "+VSid);
        console.log("ill id: "+VSidIll);
        console.log(points);
        console.log("x: "+points[0]);
        console.log("y: "+points[1]);
        l = parseInt(points[2], 10) - parseInt(points[0],10)
        console.log("l: "+ l);
        h = parseInt(points[3], 10) - parseInt(points[1],10)
        console.log("h: "+ h); 
        console.log("x2: "+ VSx2);  
        console.log("y2: "+ VSy2); 
        ratioIIIF = 100/{$pct} ;
        console.log("ratio IIIF : "+ratioIIIF); 
    
        var xCrop = parseInt(VSx2 + ratioIIIF*points[0]);
        var yCrop = parseInt(VSy2 + ratioIIIF*points[1]);
        var lCrop = parseInt(ratioIIIF*l);
        var hCrop = parseInt(ratioIIIF*h);
        console.log("xCrop: "+ xCrop);  
        console.log("yCrop: "+ yCrop);
        console.log("lCrop: "+ lCrop);  
        console.log("hCrop: "+ hCrop);

        switch (action) {{
          case 'addFace':
          console.log("...VISAGE");
          popitup2('/rest?run=addFace.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;idVisage='+ VSnVsg + '&amp;sexe='+ VSsexe+ '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+xCrop + '&amp;y='+yCrop+ '&amp;l='+ratioIIIF*l+ '&amp;h='+ratioIIIF*h);
          break;
          
          case 'segment' :
          console.log("...SEGMENT");
          popitup2('/rest?run=segment.xq&amp;corpus='+ '{$corpus}' + '&amp;id='+ VSid + '&amp;idIll='+ VSidIll + '&amp;source=' + '{$sourceEdit}'+ '&amp;x='+xCrop+ '&amp;y='+yCrop+ '&amp;l='+lCrop+ '&amp;h='+hCrop)
          break;          
        }} 
        window.setTimeout(reloadPage, 300);       
       }}
      )
  }});

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
let $data := $corpus    (: collection BaseX  :)
  return
    local:createHTMLOutput($data)
