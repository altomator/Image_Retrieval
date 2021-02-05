(:
 Recherche d'illustrations legendees dans une base BaseX
 Illustration Search in a BaseX database
:)


declare namespace functx = "http://www.functx.com";

declare option output:method 'html';


declare variable $TNA as xs:integer external := 1 ;  (: TNA project :)
declare variable $locale as xs:string external := "fr" ; (: langue :)
declare variable $CBIR as xs:string external := "*"; (: source de classification : * / ibm / dnn / google :)
declare variable $module as xs:decimal external := 1 ;
declare variable $debug as xs:integer external := 1 ;  (: switch dev/prod :)
(: -------- END arguments ---------- :)

(: Construction de la page HTML
   HTML page creation :)
declare function local:createOutput() {


<html>
   <head>
  <link rel="stylesheet" type="text/css" href="/static/common.css"></link>
  <link rel="stylesheet" type="text/css" href="/static/form.css"></link>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"></link>
  
<style>
select.corpus {{
  width: 200px
}}
</style>

 <!-- Construction de la page HTML / Building the HTML page -->
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>Gallica : recherche d&#x27;illustrations</title></head>

<body onload="launchFct()">
<div class="tetiere">
<div class="logo">
<a class="nolink" href="http://gallica.bnf.fr"><img src="/static/logo_header_1.png" alt="Gallica"></img></a>
<a class="nolink" href="/rest?run=findIllustrations-form.xq"><img src="/static/logo_header_2.png" alt="GallicaPix"></img></a></div>
<div class="titrePage">
<span class="couleurSecond" style="font-style:italic;font-weight:bold;margin-left:-8pt">P i x</span> &#8193;&#8193;&#8193;&#8193;&#8193;&#8193;&#8193;
<span lang="fr">Recherche d&#x27;illustrations multicollections</span><span lang="en">Image Retrieval</span>
</div>
</div>

<br></br>
<br></br>
<br></br>

<div id="top" >
<form class="form" action="/rest?" method="get">
<input type="hidden" name="run" value="findIllustrations-app.xq"></input>

<!-- pour filtrer par defaut les images non pertinentes / Filtering the illustrations -->
{if ($debug) then (
<input type="hidden" name="filter" value="1"/>)
}

<!-- gestion de la navigation dans les resultats / To handle the browsing of the results list -->
<input type="hidden" name="start" value="1"/>
<input type="hidden" name="action" value="first"/>

<!-- taille des vignettes / Size of the thumbnails in the results list page -->
<input type="hidden" name="module" value="{data($module)}"/>

<!-- localisation -->
<input type="hidden" name="locale" value='{$locale}'/>

<!-- similarity search  -->
<input type="hidden" name="similarity" value=""/>
<input type="hidden" name="rValue" value=""/>
<input type="hidden" name="gValue" value=""/>
<input type="hidden" name="bValue" value=""/>

<!-- format  -->
<input type="hidden" name="mode" />


<label lang="fr" >Corpus</label>
<label lang="en" >Corpora</label>&#8193;

<!-- bases BaseX / BaseX databases -->
<select name="corpus" class="corpus" id="corpus" onchange="javascript:populateDataCorpuslist();javascript:populateDatalist();">      
       <option value="1418">14-18</option>
       <option lang="fr" value="1418pub">Publicités 14-18</option>
       <option lang="en" value="1418pub">Ads 14-18</option>
        
        { if ($debug=1) then ( <option value="PM">Paris Match</option>) else ()}
        
        { if ($TNA=1) then (<option value="PP" lang="fr" >Papiers peints et textiles</option>)}
         { if ($TNA=1) then (<option value="PP" lang="en" >Wallpapers and textiles</option>)}
       
        { if ($debug=1) then ( <option value="partitions">Partitions</option>) else ()}
         <option  value="vogue">Vogue</option>
         <option lang="fr" value="zoologie">Zoologie</option>
         <option lang="en" value="zoologie">Zoology</option>
      { if ($debug=1) then (  <option value="test">Test</option>) }
      { if ($debug=1) then (  <option value="VT">VT</option>) }
      
 </select>&#8193;&#8193;&#8193;

<!-- Dataviz -->
<span lang="en"><a class="nolink fa" title="Draw a dataviz for the selected corpora" href="javascript:datavizDataset()">&#xf080;</a></span>
<span lang="fr"><a class="fa" title="Afficher un graphe pour le corpus sélectionné" href="javascript:datavizDataset()">&#xf080;</a></span>
&#8193;
&#8193;
<label>Source</label>&#8193;
<!-- source des documents / documents source -->
<select name="sourceTarget" class="source">
       <option> </option>
       <option value="gallica">Gallica</option>
       { if ($TNA=1) then (  <option value="TNA">TNA</option>) }
       <option value="Wellcome Collection">Wellcome Collection</option>
 </select>&#8193;&#8193;&#8193;&#8193;

<!-- Translation -->
<a class="nolink" title="English" href="/rest?run=findIllustrations-form.xq&amp;locale=en"><img src="/static/en.png" height="20px" style="margin-bottom:-5px;" alt="English"></img></a><a class="nolink" title="Français" href="/rest?run=findIllustrations-form.xq&amp;locale=fr"><img src="/static/fr.png" height="20px" style="margin-bottom:-5px;" alt="Français"></img></a>

<!-- Help texts -->
<div class="information">&#8193;<a class="fa fa-info-circle" style="font-size:12pt"  title="Information" href="javascript:showhide('helpDiv')"></a>
<div id="helpDiv" style="display:none;">
<hr align="left" size="1" noshade="" ></hr>
<h3>
<span lang="fr"><b>GallicaPix v1.3</b><br></br>
Nouveautés de la version 3 : grapheur <span class="fa">&#xf080;</span> (jeu de données, liste de résultats); exportation des résultats d&#x27;une requête (format JSON) ; exportation des annotations (format IIIF) ; indexation des couleurs ; indexation des illustrations (métadonnées technique/fonction/genre).<br></br>
Fonctionne mieux avec un navigateur web récent. Testé sur Chrome v67-v87 et Firefox v61-v84</span>
 <span lang="en"><b>GallicaPix v1.3</b><br></br>
New in version 3: plotter <span class="fa">&#xf080;</span> (dataset, results list); export query results as JSON; export annotations as IIIF format; color indexing; illustrations indexing (technique/function/genre metadata)<br></br>
 Works better on a modern web navigator. Tested on Chrome v67-v87 and Firefox v61-v84</span><br></br>
 <br></br>
 
 <hr align="left" style="margin-top:8px" size="1" width="20%" noshade = ""></hr>
<i>14-18</i><br></br> 
<b><span>Sources </span></b>: <a  href="https://gallica.bnf.fr" target="_blank" >Gallica (BnF)</a>, <a  href="https://wellcomecollection.org/" target="_blank">Wellcome Collection</a> <br></br>
<b><span lang="fr">Pages indexées</span><span lang="en">Indexed pages</span></b> : 475k  &#8193;
<span lang="fr"><b>Illustrations</b> : 222 290</span>
<span lang="en"><b>Illustrations</b> : 222.290</span> 
 &#8193;
<span lang="fr"><b>Publicités</b> : 65 688</span>
<span lang="en"><b>Illustrated ads</b> : 65.688</span> <br></br>

<small><b><span lang="fr">Période </span><span lang="en">Time period</span></b>: 1910-1920<br></br>
<b><span lang="fr">Presse</span><span lang="en">Newspapers</span></b> : Le Gaulois, Le Journal des débats politiques et littéraires, Le Matin, Ouest-Eclair (Rennes),  Le Petit Journal illustré, Le Petit Parisien, L&#x27;Humanité, L&#x27;Excelsior, La Guerre Mondiale...
<b><span lang="fr">Revues</span><span lang="en">Journals</span></b> : La Guerre aerienne, Cahier de la Guerre, Miroir, Pages de gloire, La Science et la Vie...  
<b>Monographies</b> : <span lang="fr">portfolios, journaux de régiments, etc.</span> <span lang="en">portfolios, regiments diaries, etc.</span> 
<b>Images</b> : <span lang="fr">estampes, photos, affiches, dessins, etc.</span><span lang="en">engravings, photos, posters, drawings, etc.</span></small>
<br></br> 

 <hr align="left" style="margin-top:8px" size="1" width="20%" noshade = ""></hr>
<i lang="fr">Papiers-peints et textiles</i><i lang="en">Wallpapers and textiles</i><br></br> 
<b><span>Sources </span></b>: <a  href="https://gallica.bnf.fr" target="_blank" >Gallica (BnF)</a>, <a  href="https://www.nationalarchives.gov.uk/" target="_blank">The National Archives</a> <br></br>
<span lang="fr"><b>Illustrations</b> : 3 753</span>
<span lang="en"><b>Illustrations</b>: 3.753</span>

<hr align="left" style="margin-top:8px" size="1" width="20%" noshade = ""></hr>
<i>Vogue</i><br></br> 
<b><span>Sources </span></b>: <a  href="https://gallica.bnf.fr" target="_blank" >Gallica (BnF)</a> <br></br>
<span lang="fr"><b>Illustrations</b> : 35 150 (publicités : 8 029 )</span>
<span lang="en"><b>Illustrations</b>: 35.150 (ads: 8.029)</span>

<hr align="left" style="margin-top:8px" size="1" width="20%" noshade = ""></hr>
<i lang="fr">Zoologie</i><i lang="en">Zoology</i><br></br> 
<b><span>Sources </span></b>: <a  href="https://gallica.bnf.fr" target="_blank" >Gallica (BnF)</a> <br></br>
<span lang="fr"><b>Illustrations</b> : 8 765</span>
<span lang="en"><b>Illustrations</b>: 8.765</span>
</h3>
</div>
</div>



<hr align="left" style="margin-top:8px" size="1" width="98%" noshade = ""></hr>

<div class="help-tip couleurSecond">
<p><span lang="fr">La recherche sur le critère  "mot clé" est tokenisée (découpage en mots ; casse, accents et ponctuation supprimés).
Avec la recherche <b>avancée</b>, il est possible de préciser plusieurs mots-clés en les séparant par une virgule et en les
combinant avec un opérateur  : <br></br>
- au moins un mot (OU logique)  :  "verdun,vaux,douaumont"  <br></br>
- tous les mots (ET logique) :  "fort,vaux"  <br></br>
- tous proches (distance de 20 mots, sans ordre) :  "bataille,Verdun"  <br></br>
- tous proches et ordonnés (distance de 20 mots avec ordre)  <br></br>
- phrase exacte (séquence de mots):  "fort de Vaux"  <br></br>
 <br></br>
Des jokers peuvent être utilisés : <br></br>
. &#8193;: tout caractère. Exemple : "199." <br></br>
.? &#8193;: zéro ou un caractère. Exemple : "élève.?" <br></br>
.* &#8193;: zéro ou plusieurs caractères. Exemple : "paris.*"<br></br>
.+ &#8193;: un ou plusieurs caractères.Exemple : "diplomat.+"  <br></br><br></br>
Une dernière option est la recherche floue, qui peut compenser les erreurs OCR.</span>
<span lang="en">
<b>Search on the "keywords" criteria</b> is tokenised (division into words, removal of case, accents and punctuation).
It is possible to specify several keywords by separating them with a comma and combining
with an operator: <br></br>
- any (logical OR)  :  "verdun,vaux,douaumont"  <br></br>
- all (logical AND) :  "fort,vaux"  <br></br>
- all closed (window of 20 words, no order) :  "bataille,Verdun"  <br></br>
- all closed and ordered (window of 20 words, ordered)  <br></br>
- sentence (exacte wording):  "fort de Vaux"  <br></br>
 <br></br>
 Wildcards can be used: <br></br>
. &#8193;: any character <br></br>
.? &#8193; : zero or one character <br></br>
.*  &#8193;: zero or more characters. Exemple : "diplomat.*"<br></br>
.+ &#8193;: one or more characters <br></br><br></br>
One last option is the fuzzy search, which partly compensates for OCR errors
</span>
</p>
</div>

 <div class="champ1"><label lang="fr">Mots clés</label><label lang="en">Keywords</label>&#8193;
  <input type="text" name="keyword" class="keyword"></input> &#8193;
  <label lang="fr" style="font-size:9pt">Rech. avancée</label><label lang="en" style="font-size:9pt">Advanced</label>
   <select class="kwTarget" name="kwTarget" id="kwTarget" onchange="javascript:populateSearchlist();" >
    <option > </option>
       <option lang="fr" value="any">Au moins un mot</option>
        <option lang="en" value="any">Any</option>
       <option lang="fr" value="all">Tous les mots</option>
       <option lang="en" value="all">All</option>
       <option lang="fr" value="all window 20 words">Tous les mots proches</option>
       <option lang="en" value="all window 20 words">All closed</option>
       <option lang="fr" value="all ordered distance at most 20 words">Tous proches et ordonnés</option>
       <option lang="en" value="all ordered distance at most 20 words">All closed and ordered</option>
       <option lang="fr" value="phrase">Phrase exacte</option>
       <option lang="en" value="phrase">Exacte wording</option>
   </select>
   &#8193;
   <select class="kwMode"  name="kwMode" id="kwMode" >
       <option> </option>
       <option lang="fr" value="using wildcards">Jokers</option>
       <option lang="fr" value="using fuzzy">Rech. floue</option>     
       <option lang="en" value="using fuzzy">Fuzzy</option>
       <option lang="en" value="using wildcards">Wildcards</option>
   </select>
</div>

  <hr align="left" style="margin-top:8px" size="1" width="98%" noshade =""></hr>
  <p class="inter">Collections</p>

<div class="help-tip couleurSecond">
   <p><span lang="fr"><b>Collections Gallica source des illustrations : </b> presse, revue, monographie, manuscrits, image, carte, partition musicale <br></br>
     <b>Titre :</b> titre de périodique ou titre de l&#x27;oeuvre. <i>Exemples :</i>  <br></br>
      - régiment <br></br>
      - Gaulois | Matin (recherche dans plusieurs titres)<br></br>
      - guerre.*aérienne (jokers)<br></br>
     <b>De/à : </b> date de publication au format jj/mm/aaaa<br></br>
     <b>Thème :</b> classification IPTC (cette métadonnée ne couvre pas toute la base)<br></br>
     <b>Supplément </b> (pour les périodiques uniquement) : restreindre aux suppléments<br></br>
     { if ($debug=1) then (<span><b>Publicité</b> (pour les périodiques uniquement) : restreindre aux pages contenant de la publicité<br></br></span> )
     else ()}
     <b>En une/Dernière</b> (pour les périodiques uniquement) : restreindre au première ou dernière pages<br></br></span>

    <span lang="en"><b>Gallica source collections of the illustrations: </b> newspapers, journals, monographies, manuscripts, images, maps, musical scores<br></br>
     <b>Title: </b> work title or newspaper title. <i>Examples:</i>  <br></br>
      régiment <br></br>
      Gaulois | Matin (searching in multiple titles)<br></br>
      guerre.*aérienne (wildcards)<br></br>
     <b>From/To: </b> publication date (jj/mm/aaaa)<br></br>
     <b>Theme:</b> IPTC classification (this metadata doesn&#x27;t cover all the database) <br></br>
     <b>Supplement</b> (for serials only): search only in supplements<br></br>
      { if ($debug=1) then (<span><b>Ad</b>  (for serials only): search only in pages including ads</span>)
     else ()}
     <b>Front page/Last page</b> (for serials only): search only in front/last pages<br></br></span>
     </p>
</div>

<div class="champ1">
<input type="checkbox" name="typeP" value="P" id="checkboxP" onClick="javascript:show('presseUniq');javascript:showTitles('presse')" ></input><label lang="fr">Presse</label><label lang="en">Newspaper</label>&#8193;
 
<input type="checkbox" name="typeR" value="R" id="checkboxR" onClick="javascript:show('presseUniq');javascript:showTitles('revue')" ></input><label lang="fr">Revue</label><label lang="en">Journal</label>&#8193;
<input type="checkbox" name="typeM" value="M"  onClick="javascript:hide('presseUniq');"></input> <label lang="fr">Monographie</label><label lang="en">Monograph</label>&#8193;
<!-- <input type="checkbox" name="typeA" value="A"  onClick="javascript:hide('presseUniq');"></input> <label lang="fr">Manuscrit</label><label lang="en">Manuscript</label>&#8193; -->
<input type="checkbox" name="typeI" value="I"  onClick="javascript:hide('presseUniq');"></input> Image&#8193;
   <input type="checkbox" name="typeC" value="C" onClick="javascript:hide('presseUniq')"></input> <label lang="fr">Carte</label><label lang="en">Map</label>&#8193;
<input type="checkbox" name="typePA" value="PA" onClick="javascript:hide('presseUniq')"></input> <label lang="fr">Partition</label><label lang="en">Music Score</label>
  </div>
<p class="inter">Document</p>
 <div class="champ"><label lang="fr">Titre</label><label lang="en">Title</label>&#8193;
 <input type="text" name="title" id="title" list="titles"></input>&#8193;&#8193;
 <datalist id="titles"></datalist>
  <label lang="fr">Auteur</label><label lang="en">Author</label>&#8193;
  <input type="text" name="author"></input>&#8193;&#8193;
   <label lang="fr">Editeur</label><label lang="en">Publisher</label>&#8193;
  <input type="text" name="publisher"></input>
  </div>
  
 <div class="champ">
   <label lang="fr">De</label><label lang="en">From</label>&#8193;   <input type="date" max="1945-12-31" name="fromDate" class="date" ></input>
  &#8193;<label lang="fr">à</label><label lang="en">To</label>&#8193; <input type="date" max="1945-12-31" name="toDate" class="date" ></input><br></br>
  </div>

<label  lang="fr" for="pays">Thème</label><label lang="en" for="pays">Theme</label>&#8193;
<!-- http://cv.iptc.org/newscodes/mediatopic
http://cv.iptc.org/newscodes/mediatopic/01000000
http://cv.iptc.org/newscodes/mediatopic/17000000
-->
 <select class="iptc" name="iptc"  style="margin-top:10px;margin-bottom:5px">
  <option value="00" selected="" > </option>
  <option lang="fr" value="01">Arts, culture et div.</option>
  <option lang="en" value="01">arts, culture and entertainment</option>
  <option lang="fr" value="02">Criminalité, droit et justice</option>
  <option lang="en" value="02">crime, law and justice</option>
  <option lang="fr" value="03">Désastres et accidents</option>
  <option lang="en" value="03">disaster, accident and emergency incident</option>
  <option lang="fr" value="04">Economie et finances</option>
   <option lang="en" value="04">economy, business and finance</option>
  <option lang="fr" value="05">Education</option>
   <option lang="en" value="05">education</option>
  <option lang="fr" value="06">Environnement</option>
   <option lang="en" value="06">environment</option>
  <option lang="fr" value="07">Santé</option>
  <option lang="en" value="07">health</option>
  <option lang="fr" value="08">Gens, animaux, insolite</option>
   <option lang="en" value="08">human interest</option>
  <option lang="fr" value="09">Social</option>
   <option lang="en" value="09">labour</option>
  <option lang="fr" value="10">Vie quotidienne et loisirs</option>
  <option lang="en" value="10">lifestyle and leisure</option>
  <option lang="fr" value="11">Politique</option>
   <option lang="en" value="11">politics</option>
  <option lang="fr" value="12">Religion et croyance</option>
  <option lang="en" value="12">religion and belief</option>
  <option lang="fr" value="13">Science et technologie</option>
<option lang="en" value="13">science and technology</option>
  <option lang="fr" value="14">Société</option>
  <option lang="en" value="14">society</option>
  <option lang="fr" value="15">Sport</option>
  <option lang="en" value="15">sport</option>
  <option lang="fr" value="16">Conflits, guerres et paix</option>
  <option lang="en" value="16">conflicts, war and peace</option>
  <option lang="fr" value="17">Météo</option>
  <option lang="en" value="17">weather</option>
  </select>
  
  <div id="presseUniq"  class="champ">
   <input type="radio"  name="page" value="true" ></input><label lang="fr">En une</label><label lang="en">Front page</label> &#8193;
  <input type="radio"  name="page" value="false"></input><label lang="fr">Dernière page</label><label lang="en">Last page</label> &#8193; <input type="checkbox"  name="special" value="1" ></input><label lang="fr">Supplément</label><label lang="en">Supplement</label> &#8193;
   <br></br> 
   <input name="illAd" type="checkbox"  value="1"></input>
   <label name="illAd" lang="fr">Publicité illustrée</label>
   <label name="illAd" lang="en">Illustred ads</label>
  &#8193;
 { if ($debug=1) then (
   <input type="checkbox"  name="illFreead" value="1"></input>)
   else ()}
  { if ($debug=1) then (<label lang="fr">Annonce</label>) else ()}
  { if ($debug=1) then (<label lang="en">Freeads</label>) else ()
 }&#8193;

  { if ($debug=1) then ( <input type="checkbox"  name="ad" value="1"  ></input>) else ()}
  { if ($debug=1) then (<label lang="fr">Filtrer les pages avec publicité</label>) else ()}
  { if ($debug=1) then (<label lang="en">Filter pages including ads</label>) else ()}
 </div>

 <hr align="left" style="margin-top:8px" size="1" width="98%" noshade =""></hr>


<div class="champ">

<div class="help-tip couleurSecond">
<p><span lang="fr">
Ces critères interrogent le contenu des images. <br></br><br></br>
 <b>Technique  de l&#x27;illustration</b> : dessin, estampe, photo, etc. <br></br>
  <b>Fonction et genre documentaire de l&#x27;illustration</b> : affiche, carte, portrait, etc. <br></br>
     <b>Personne, Concepts</b> : concepts produits par reconnaissance visuelle. Les résultats d&#x27;indexation de plusieurs services sont interrogeables (IBM Watson Visual Recognition, Google Cloud Vision, OpenCV/dnn, Yolo). Le mode 'md' interroge les seules métadonnées bibliographiques.<br></br>

Le premier champ Concept propose une liste de concepts prédéfinis liés au corpus étudié.
Ces concepts (par ex. Bateau) opérent avec des synonymes afin d&#x27;étendre la requête (vaisseau, croiseur...).<br></br>

Un service unique peut être choisi avec le critère Mode et dans ce cas, son vocabulaire est listé dans le second champ Concept. Le choix * permet d&#x27;interroger tous les modèles d&#x27;indexation.<br></br>

L&#x27;opérateur logique ET/OU permet de combiner les champs concepts ainsi que les autres critères du formulaire.
<br></br>

     <b>Mode colorimétrique de l&#x27;illustration</b> : noir et blanc, monochrome (sépia, cyanotype...), couleur <br>
     <b>Couleur dominante de l&#x27;illustration</b> : les couleurs (bleu, rouge, vert...) sont issues de la reconnaissance visuelle (toutes sources confondues)</br>

    
     <b>Taille</b> (de la plus petite illustration à la plus grande) : filtrer les illustrations de plus petite taille que le critère<br></br>
     <b>Densité</b> (pour les imprimés uniquement, nombre d&#x27;illustrations par page) :  filtrer les pages de plus petite densité d&#x27;illustration que le critère<br></br>
</span>

<span lang="en">
<b>These criteria query the images content.</b><br></br><br></br>
<b>Illustration&#x27;s technique</b> : drawing, print, photo, etc. <br></br>
<b>Illustration&#x27;s function and genre</b> : poster, map, portrait, etc. <br></br>
     <b>Person, concepts</b> : concepts of automatic classification by visual recognition (CBIR). Several sources are available (IBM Watson Visual Recognition, Google Cloud Vision, OpenCV/dnn, Yolo).<br></br>

The first Concept field makes available predefined concepts related to the selected corpora.
These concepts (e.g. Boat) use synonyms to extend the search (cruiser, ship...). <br></br>

A single model can be selected with the Mode criteria and then its vocabulary is listed in the second Concept field. <br></br>


Logical operator AND/OR combins the concepts criterias with the other criteria. <br></br>

     <b>Color </b> : grayscale, monochrome (sepia, cyanotype...), color<br>
     The color classes (blue, red, green...) are derived from the visual recognition classification</br>
     
     <b>Size </b> (from the smallest illustration to the largest):  filter the illustrations which are smaller  than the criteria <br></br>
     <b>Density </b> (for printed contents only, number of illustrations in a page, from 1 to 25): filter the pages which have a smaller density than the criteria <br></br>
</span></p>
</div>


<p  class="inter" style="margin-top:-30px;margin-bottom:2px">Illustration</p>
<label>Technique</label>&#8193;
    <select class="techFoncGen"  name="illTech">
    <option value="00" selected="" > </option>
    <option  lang="fr" value="dessin" >dessin</option><option lang="en" value="dessin">drawing</option>
    <option  lang="fr" value="estampe" >estampe</option><option lang="en" value="estampe">print</option>
    <option  lang="fr" value="imp photoméca" >imp. photomécanique</option><option value="imp photoméca" lang="en">photomechanical printing</option>
    <option  lang="fr" value="photo" >photographie</option><option lang="en" value="photo">photo</option>
    
     <div id="textile"><option value="textile" >textile</option ></div>
</select>
&#8193;&#8193;
<label lang="fr">Fonction</label><label lang="en">Function</label>&#8193;
<select class="techFoncGen" name="illFonction">
    <option value="00" selected=""> </option>
    <option  lang="fr" value="affiche" >affiche</option><option lang="en" value="affiche">poster</option>
    <option  lang="fr" value="bd" >bd</option><option lang="en" value="bd">comics</option>
     <option  lang="fr" value="carte" >carte, plan</option><option lang="en" value="carte">map</option>
     <option  lang="fr" value="carte postale" >carte postale</option><option lang="en" value="carte postale">post card</option>
     <option  lang="fr" value="couverture" >couverture</option><option lang="en" value="couverture">cover</option>
    <option  lang="fr" value="graphique" >graphe, schéma</option><option lang="en" value="graphique">graph</option>    
    <option  lang="fr" value="illustration de presse" >ill. de presse</option><option lang="en" value="illustration de presse">press illustration</option>
    <option  lang="fr" value="partition" >partition</option><option lang="en"  value="partition">music score</option>
   
    <option  lang="fr" value="papier-peint" >papier-peint</option><option lang="en" value="papier-peint">wallpapers</option>
    <option lang="fr" value="repro/dessin">repro. dessin</option><option lang="en" value="repro/dessin">drawing repro.</option>
    <option lang="fr" value="repro/estampe">repro. estampe</option><option lang="en" value="repro/estampe">engraving repro.</option>
    <option lang="fr" value="repro/photo">repro. photo</option><option lang="en" value="repro/photo">photo repro.</option>
</select>
&#8193;&#8193;
<label>Genre</label>&#8193;
<select class="techFoncGen" name="illGenre">
    <option value="00" selected=""> </option>
   <option lang="fr" value="paysage">paysage</option><option lang="en" value="paysage">landscape</option>
    <option   value="portrait" >portrait</option>
    <option lang="fr"  value="vue aérienne" >vue aérienne</option><option lang="en"  value="vue aérienne" >aerial vue</option>
   <option name="genrePub" lang="fr" value="publicité" >publicité</option> 
   <option name="genrePub" lang="en" value="publicité">ads</option> 
   </select>
&#8193;&#8193;


</div>

<p class="inter" style="margin-top:5px;margin-bottom:-12px">Concepts</p>
 <div class="champ">
<!-- <input type="checkbox" name="person" value="1"></input>-->
<label lang="fr">Personne</label><label lang="en">Person</label>
    <select class="persType" name="persType">
    <option value="00" selected="" > </option>
    <option  lang="fr" value="person" >Personne</option><option  lang="en" value="person">Person</option>
    <option  lang="fr" value="personW" >Femme</option><option  lang="en" value="personW">Woman</option>
   <option  lang="fr" value="personM" >Homme</option> <option  lang="en" value="personM">Man</option>
   <option  lang="fr" value="soldier">Soldat</option><option lang="en" value="soldier" >Soldier</option>
   <option  lang="fr" value="officer">Officier</option><option lang="en" value="officer" >Officer</option>
   <option  lang="fr" value="child">Enfant</option><option  lang="en" value="child">Child</option>
    
     <option  lang="fr" value="face">Visage</option><option lang="en" value="face" >Face</option>
     <option  lang="fr" value="faceW">Visage F</option><option lang="en" value="faceW" >Face (W)</option>
      <option  lang="fr" value="faceM">Visage M</option><option lang="en" value="faceM" >Face (M)</option>
       <option  lang="fr" value="faceC">Visage enfant</option><option lang="en" value="faceC" >Child face</option>
   </select>
    &#8193;
 Concepts
   <input type="text" name="classif1" id="classif1" class="classif" list="concepts1" />&#8193;
   <datalist id="concepts1"></datalist>

<label>Mode</label>
<select  name="CBIR" id="CBIR" onchange="javascript:populateDatalist();" list="CBIRs" >
    <option  value="*" selected="">*</option>
    <option value="ibm">IBM</option>
    <option value="google">Google</option>
    <option value="dnn">dnn</option>
    <option value="yolo">Yolo</option> 
    <option value="md">md</option>
     
     {if ($debug) then (     
       <option value="hm">hm</option>
    )
    }
</select>
<datalist id="CBIRs"></datalist>
 
 <input type="text" name="classif2" id="classif2" class="classif" list="concepts2" />&#8193;
 <datalist id="concepts2"></datalist>

 <label lang="fr">Confiance</label><label lang="en">Confidence</label>
    <select  name="CS" id="CS">
    <option  value="0">0%</option>
    <option  value="0.20" selected="">20%</option>
    <option value="0.5" >50%</option>
    <option value="0.75">75%</option>
    <option value="0.9">90%</option>
 </select>
    &#8193;
 <input type="radio" name="operator" value="and" checked="checked"></input><label lang="fr">et</label><label lang="en">and</label>&#8193;
 <input type="radio" name="operator" value="or "></input><label lang="fr">ou</label><label lang="en">or</label>
<br></br>
  </div>

 <!--
  <div class="champ">
  De la page&#8193;
  <input type="text" name="fromPage" class="page" ></input>
  &#8193;à la page &#8193;  <input type="text" name="toPage" class="page" ></input>
   </div>
 -->

<p class="inter" style="margin-top:3px;margin-bottom:-12px">Image</p>
  <div class="champ">
   <!--    <input type="radio" name="color" value="gris" ></input>Noir et blanc &#8193;  -->
    <input type="radio" name="color" value="gris"></input>&#8193;<label lang="fr"> N&amp;B</label><label lang="en">B&amp;W</label> &#8193;
    <input type="radio" name="color" value="mono"></input>&#8193;<label lang="fr"> Monochrome</label><label lang="en">Monochrome</label> &#8193;
    <input type="radio" name="color" value="coul"></input>&#8193;<label lang="fr"> Couleur</label><label lang="en">Color</label> &#8193;&#8193;

<select class="colName" name="colName" id="colName">
  <option value="00" selected="" > </option>
  <option value="beige" style="color:ivory">beige</option>
   <option lang="en" value="black" >black</option>
  <option lang="en" value="blue" style="color:blue">blue</option>
  <option lang="en" value="brown" style="color:brown">brown</option>
  <option lang="en" value="grey"  style="color:gray" >gray</option>
   <option lang="en" value="green"  style="color:green">green</option>
 <option lang="en" value="orange"  style="color:orange" >orange</option>
  <option lang="en" value="pink"  style="color:deeppink" >pink</option>
  <option lang="en" value="purple" style="color:purple">purple</option>
  <option lang="en" value="red"  style="color:red" >red</option>
  <option lang="en" value="yellow" style="color:gold">yellow</option>
   <option lang="fr" value="blue"  style="color:blue" >bleu</option>
    <option lang="fr" value="grey"  style="color:gray" >gris</option>
     <option lang="fr" value="yellow"  style="color:gold">jaune</option>
     <option lang="fr" value="brown"  style="color:brown">marron</option>
    <option lang="fr" value="black" >noir</option>
     <option lang="fr" value="orange"  style="color:orange">orange</option>
     <option lang="fr" value="pink"  style="color:deeppink">rose</option>
  <option lang="fr" value="red"  style="color:red" >rouge</option>
   <option lang="fr" value="green"  style="color:green">vert</option>
<option lang="fr" value="purple"  style="color:purple" >violet</option>
   </select>
  </div>
  
 
  <div class="champ">
      <label lang="fr">Taille</label><label lang="en">Size</label>&#8193;
 <span style="font-size:8pt;margin-right:-10pt" class="fa">&#xf1c5;</span><input type="range" name="size" min="1" max="60"></input><span class="fa">&#xf1c5;</span>&#8193;&#8193;&#8193;&#8193;&#8193;&#8193;
      <label lang="fr">Densité</label><label lang="en">Density</label>&#8193;  <span style="font-size:20pt;font-weight:bold;margin-right:-10pt">.</span><input type="range" name="density" min="1" max="25"></input><span  class="fa">&#xf00a;</span>
  </div>

<input lang="fr" style="margin-top:15px" type="submit" class="button" value="Chercher"></input>
<input lang="en" type="submit" class="button" value="Search"></input>&#8193;


  <img style="width:30px;float:right;padding-top:10px;padding-left:10px" src="/static/iiif.png"></img>
   <img style="width:25px;float:right;padding-top:15px" src="/static/basex.svg"></img>
    
  </form>
  </div>

   <p  style="margin-left:5px"><small><a style="color:gray" class="nolink" href="http://gallicastudio.bnf.fr/bo%C3%AEte-%C3%A0-outils/plongez-dans-les-images-de-14-18-en-testant-un-nouveau-moteur-de-recherche" target="_blank"><b><span lang="fr">GallicaPix, c&#x27;est quoi ?</span><span lang="en">GallicaPix, what&#x27;s that?</span></b></a> <a style="color:gray" class="nolink" href="mailto:jean-philippe.moreux@bnf.fr">Contact</a>
    <a style="color:gray" class="nolink" href="https://github.com/altomator/Image_Retrieval" target="_blank">GitHub</a><a style="color:gray" class="nolink" href="http://gallica.bnf.fr/html/und/conditions-dutilisation-des-contenus-de-gallica" target="_blank"><span lang="fr">CGU</span><span lang="en">TOS</span></a></small>
 </p>

<script src="/static/dict-ibm.txt">
// charger les classes de vocabulaire CBIR / download the CBIR vocabulary classes
</script>
<script src="/static/dict-ibm-zoo.txt"></script>
<script src="/static/dict-ibm-ads.txt"></script>
<script src="/static/dict-google.txt"></script>
<script src="/static/dict-all.txt"></script>
<script src="/static/dict-pp.txt"></script>
<script src="/static/dict-google-pp.txt"></script>

<script> {attribute  src  {'/static/misc.js'}} </script>
<script>

function getDB() {{
  return document.getElementById('corpus').value;
}}

function popitup(url,windowName) {{
       newwindow=window.open(url,"ligneLog");
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}
     
function show(id) {{
       console.log("show: "+id);
       var e = document.getElementById(id);
       e.style.display =  'inline-block' ;
     }}

function hide(id) {{
       console.log("hide: "+id);
       var e = document.getElementById(id);
       e.style.display =  'none' ;
     }}

function showByNames(id) {{
  console.log("show names:"+id);
  document.getElementsByName(id).forEach(function (node) {{
      node.style.display = 'inline-block';
     }});
    }}
         
function hideByNames(id) {{
  console.log("hide names: "+id);
  let elts = document.getElementsByName(id);
  elts.forEach((elt) => {{
       elt.style.display = 'none';
       console.log("..none..");
     }});
    }}

// au chargement de la page / when the page is loaded
function launchFct() {{
 // localize((navigator.language) ? navigator.language : navigator.userLanguage);
 localize('{$locale}');
 hide('presseUniq');
 populateDataCorpuslist();
 populateDatalist();

}}


function datavizDataset() {{
  var base = getDB();
  var lang = '{data($locale)}';
 
  var from;
  var to;
  var ad;
  
  console.log("calling dataviz for DB "+ base);
  switch (base) {{
     case "zoologie":
        from=1792;
        to=1944;
        ad="";
        break;
     case "vogue":
        from=1920;
        to=1940; 
        ad="1";
        break; 
     case "1418":
        from=1910;
        to=1920;
        ad=""; 
        break;  
     case "1418pub":
        from=1910;
        to=1920;
        ad="";         
         break; 
     case "PP":
        from=1795;
        to=1885;
        ad="";       
     }}
   console.log("from: "+ from + " to: ",to);  
    window.open('/rest?run=plotDataset.xq&amp;corpus='+ base + '&amp;fromYear='+from+'&amp;toYear='+to+'&amp;ad='+ad+'&amp;locale='+lang)
}}


// remplir la liste des concepts selon la base de données / handling the Concepts list relatively to the database
function populateDataCorpuslist() {{
  var str='';
  var data=new Array();
  var base = getDB();
   
  console.log("setting vocabulary_1 and CBIR modes for DB ("+base+"):");
  
  // filtering the CBIR modes
  var CBIRselect=document.getElementById("CBIR");
  switch (base) {{
     case "zoologie":
      show("colName");
      hideByNames("genrePub");hideByNames("illAd");
      CBIRselect.options.length=0;
      CBIRselect.options[0]=new Option("*", "*");     
      CBIRselect.options[2]=new Option("IBM", "ibm");
      CBIRselect.options[1]=new Option("md", "md");
      
     break;
     
     case "PP":   
     CBIRselect.options.length=0;          
     CBIRselect.options[0]=new Option("md", "md");
     CBIRselect.options[1]=new Option("Google", "google");
    // show("textile");
    // show("papier-peint");
     hide("colName");
     hideByNames("genrePub");hideByNames("illAd");
     break;
     
     case "vogue":   
     CBIRselect.options.length=0;    
     CBIRselect.options[0]=new Option("*", "*");       
     CBIRselect.options[2]=new Option("Yolo", "yolo");
     CBIRselect.options[1]=new Option("IBM", "ibm");    
     hide("colName");
     showByNames("genrePub");showByNames("illAd");
     localize('{$locale}');
     break;
     
    case "1418pub":
     show("colName");
     hideByNames("genrePub");hideByNames("illAd");
     CBIRselect.options.length=0;  
     CBIRselect.options[0]=new Option("*", "*");                 
     CBIRselect.options[1]=new Option("Yolo", "yolo");
     CBIRselect.options[2]=new Option("IBM", "ibm"); 
     CBIRselect.options[3]=new Option("hm", "hm");    
     break;
     
    case "test":
     show("colName");
     CBIRselect.options.length=0;         
     CBIRselect.options[0]=new Option("*", "*");
     CBIRselect.options[1]=new Option("Google", "google");
     CBIRselect.options[2]=new Option("IBM", "ibm");
     CBIRselect.options[3]=new Option("dnn", "dnn");
     CBIRselect.options[4]=new Option("Yolo", "yolo");
     CBIRselect.options[5]=new Option("md", "md");
     CBIRselect.options[6]=new Option("hm", "hm");
     break;
     
    default:  
     // hide("textile"); hide("papier-peint"); 
     show("colName"); 
     hideByNames("genrePub");hideByNames("illAd");
     CBIRselect.options.length=0;         
     CBIRselect.options[0]=new Option("*", "*");
     CBIRselect.options[1]=new Option("Google", "google");
     CBIRselect.options[2]=new Option("IBM", "ibm");
     CBIRselect.options[3]=new Option("dnn", "dnn");
     CBIRselect.options[4]=new Option("Yolo", "yolo");
     
     }}  
     
  // generating the concepts  
  var input = document.getElementById('classif1');
  input.value = "";
  if ('{$locale}'=="en") {{
  switch (base) {{
     case "zoologie":
     data = new Array("Bird","Butterfly", "Fish", "Insect","Invertebrate", "Mammal", "Shellfish", "Reptile", "Spider", "Vertebrate");   
      break;
    
    case "PP":
     data = new Array("Architecture", "Animal", "Flower", "Frieze","Geometric", "Grid","Person", "Plant", "Stripe");
      break;
      
    case "vogue":
     data = new Array("Aircraft","Bag", "Car","Chair", "Dress","Furniture", "Person");
      break;

    case "1418":
     data = new Array("Aircraft", "Airplane", "Armored vehicle", "Battle", "Boat", "Fortification", "Horse", "Tank", "Vehicle", "War", "Weapon");
      break;

    case "1418pub":
     data = new Array("aeroplane","bed","bench","bicycle","bird","boat","book","bottle","bowl","cake","car","cat","chair","clock","cow","cup","diningtable","dog","elephant","fork","handbag","horse","knife","motorcycle","orange","person","refrigerator","scissors","sofa","spoon","suitcase","tennis racket","tie","toothbrush","train","truck","umbrella","vase","wine glass");
      break;
      }}
     }} else {{

   switch (base) {{
     case "zoologie":
     data = new Array("Araignée", "Coquillage", "Crustacé",   "Insecte", "Invertebré", "Mammifère", "Oiseau","Papillon", "Poisson", "Reptile", "Vertébré");
      break;

    case "PP":
     data = new Array("Architecture","Animal", "Fleur", "Frises", "Géométrique", "Quadrillage", "Rayure", "Personne","Végétal" );
      break;
      
    case "1418":
     data = new Array("Arme", "Aéronef","Avion", "Bataille", "Bateau", "Cheval", "Fortification", "Guerre", "Tank","Véhicule","Véhicule blindé" );
      break;

    case "vogue":
     data = new Array("Avion","Chaise", "Meuble", "Robe","Sac", "Personne","Voiture");
      break;
      
    case "1418pub":
     data = new Array("avion","banc", "bateau","bol","bouteille", "bus","camion","canapé", "chaise","chat", "cheval","chien","ciseaux","couteau","cravate","cuillère","éléphant","fourchette","grille-pain","horloge","livre", "moto", "personne", "montre", "mouton", "oiseau", "réfrigérateur","sac","table", "tasse",  "train","vélo", "voiture", "vache","valise","verre");
     break;
     }}
     }}
  console.log(data.length);
  for (var i=0; i != data.length;++i){{
   str += '<option value="'+data[i]+'" />';
  }}
  var myList=document.getElementById("concepts1");
  myList.innerHTML = str;
}}


// remplir la liste des concepts selon API / handling the Concepts list relatively to the CBIR source
function populateDatalist() {{
  var str='';
  var data=new Array();
  var api = document.getElementById('CBIR').value;
  console.log("CBIR mode: "+ api);
  var base = document.getElementById('corpus').value;
  console.log("full vocabulary for DB ("+base+") and CBIR ("+api+"):");

  var input = document.getElementById('classif2');
  input.value = "";

  if ('{$locale}'=="en") {{
   switch (api) {{   
    case "dnn":
     if (base.includes("1418")) {{
       data = new Array("aeroplane", "bicycle", "bird", "boat","bottle", "bus", "car", "cat", "chair", "cow", "dog", "horse", "motorbike", "person",  "sheep", "train") }}
    break;

    case "yolo":
     if (base.includes("1418") || (base =="vogue"))  {{
      data = new Array("aeroplane","apple","backpack","banana","baseball bat","baseball glove","bear","bed","bench","bicycle","bird","boat","book","bottle","bowl","bus","cake","car","carrot","cat","cell phone","chair","clock","cow","cup","diningtable","dog","donut","elephant","fire hydrant","fork","frisbee","giraffe","hair drier","handbag","horse","hot dog","keyboard","kite","knife","laptop","microwave","motorbike","mouse","orange","oven","parking meter","person","pizza","pottedplant","refrigerator","remote","sandwich","scissors","sheep","sink","skateboard","skis","snowboard","sofa","spoon","sports ball","stop sign","suitcase","surfboard","teddy bear","tennis racket","tie","toaster","toilet","toothbrush","traffic light","train","truck","tvmonitor","umbrella","vase","wine glass","zebra")}}     
    break;

    case "ibm":
    if (base=="zoologie") {{
      data=dataIbmZoo_en}}
    else if (base=="1418pub") {{  
      data=dataIbmAds_en;}}
    else {{
      data=dataIbm_en;}}
    break;

    case "google":
      if (base=="PP") {{
      data=dataGooglePP_en}}
    else {{ data=dataGoogle_en;}}
      break;
    
    case "md":
     if (base=="zoologie") {{
      data=new Array("bird", "fish", "insect","invertebrate", "mammal", "shellfish", "reptile", "vertebrate")}}
     else if (base=="PP") {{
      data=dataPP_en}}
      break;
      
    default:
    console.log("default: *");
    data=dataAll_en;
   }}
  }} else {{

    switch (api) {{
    case "dnn":
     if (base.includes("1418")) {{
      data=data = new Array("avion","bateau", "bicyclette","bouteille", "bus","chaise","chat", "cheval","chien", "moto", "personne",  "mouton", "oiseau",  "train", "voiture", "vache")}}
    break;

     case "yolo":
     if (base.includes("1418")  || (base =="vogue"))  {{
      data=data = new Array("avion", "ballon", "banane", "banc", "bateau", "batte de baseball", "bol", "bouche incendie", "bouteille", "brosse à dent", "bus", "camion", "carotte", "cerf-volant", "chaise", "chat", "cheval", "chien", "ciseaux", "clavier", "coupe", "couteau", "cravate", "cuillère", "donut", "éléphant", "évier", "feux de circulation", "four", "fourchette", "frisbee", "gant de baseball", "gateau", "girafe", "grille-pain", "hot dog", "lit", "livre", "micro-onde", "mobile", "moniteur", "montre", "moto", "mouton", "oiseau", "orange", "ordinateur portable", "ours", "ours en peluche", "parapluie", "parcmètre", "personne", "pizza", "planche de surf", "plante en pot", "pomme", "raquette de tennis", "réfrigérateur", "sac", "sac à dos", "sandwich", "sèche-cheveux", "skateboard", "ski", "snowboard", "sofa", "souris", "stop", "table", "télécommande", "train", "vache", "valise", "vase","vélo", "verre à vin", "voiture", "wc", "zèbre")}}
    break;

    case "ibm":
    if (base=="zoologie") {{
      data=dataIbmZoo_fr}} 
    else if (base=="1418pub") {{  
      data=dataIbmAds_fr;}}     
    else {{data=dataIbm_fr}}
    break;

    case "google":
     if (base=="PP") {{
      data=dataGooglePP_fr}}
     else {{data=dataGoogle_fr}}
     break;

    case "md":
     if (base=="zoologie") {{
      data=new Array("coquillage,crustacé",  "insecte", "invertébré", "mammifère", "oiseau","poisson", "reptile", "vertébré")}}
      else if (base=="PP") {{
      data=dataPP_fr}}
      break;
      
    default:
    data=dataAll_fr
   }}

  }}
  console.log(data.length);
  for (var i=0; i != data.length;++i){{
   str += '<option value="'+data[i]+'" />';
  }}
  var my_list=document.getElementById("concepts2");
  my_list.innerHTML = str;
}}

// 
function showTitles(coll)
{{
  var data=new Array();
  var str='';
  var titles = document.getElementById('titles');
  var checkP = document.getElementById('checkboxP').checked == true;
  var checkR = document.getElementById('checkboxR').checked == true;
 
  switch (coll) {{ 
    case "presse":
    if (checkP) {{
      data=new Array("L'Action", "Le Constitutionnel","La Croix",
"Excelsior","Le Figaro",
"Le Gaulois",
"La Guerre mondiale",
"L'Humanité",
"Journal des débats politiques",
"La Presse",
"Le Matin",
"Ouest Eclair",
"L'Oeuvre",
"Le Petit Journal illustré",
"Le Petit Parisien",
"Le Siècle");
   }}
   break;
   
   case "revue":
   if (checkR) {{
      data=new Array("L'Ambulance","L'Aviation et l'automobilisme",
      "Les Cahiers de la guerre","La Guerre aérienne illustrée","L'image de la guerre",
      "Journal des sciences militaires",
"Ligue aéronautique","Le Miroir","Le Miroir des sports","Pages de gloire",
"La Restauration maxillo-faciale","Le Rire","La Science et la vie","La Vie aérienne illustrée","La Vie au grand air",);
      break;}}
   
   default:
 
  }} 
   

  console.log("titles: "+data.length);
  for (var i=0; i != data.length;++i){{
   str += '<option value="'+data[i]+'" />';
  }}
  var my_list=document.getElementById("titles");
  my_list.innerHTML = str;
}}

// text search options are not all compatible
function populateSearchlist()
{{
  var kwTarget = document.getElementById('kwTarget').value;
  var kwMode = document.getElementById('kwMode');
  console.log("kwTarget: "+kwTarget);
  var language = '{$locale}';
  
  if (kwTarget.includes("words")) {{
     console.log("filtering option! ");
     kwMode.options.length=0;         
     kwMode.options[0]=new Option(" ", " ");
     if (language.includes('fr')) 
      {{kwMode.options[1]=new Option("Rech. floue", "using fuzzy");}}
     else {{kwMode.options[1]=new Option("Fuzzy", "using fuzzy")}} 
   }}
  else {{
    kwMode.options.length=0;  
    kwMode.options[0]=new Option(" ", " ");
    if (language.includes('fr')) {{
      kwMode.options[1]=new Option("Jokers", "using wildcards");
      kwMode.options[2]=new Option("Rech. floue", "using fuzzy")}}
    else {{
      kwMode.options[2]=new Option("Wildcards", "using wildcards");
      kwMode.options[1]=new Option("Fuzzy", "using fuzzy");
      
    }}     
  }}
}}

// localisation / localize function
function localize (language)
{{
  console.log("localize : "+language);
  if (language.includes('fr')) {{
     lang = ':lang(fr)';
     cacher = '[lang]:not(' + lang + ')';
     montrer = '[lang]' + lang;
   }}
   else
    {{
     lang = ':lang(en)';
     cacher = '[lang]:not(' + lang + ')';
     montrer = '[lang]' + lang;
   }}
    console.log("lang : "+lang);
    Array.from(document.querySelectorAll(cacher)).forEach(function (e) {{
      e.style.display = 'none';
    }});
    Array.from(document.querySelectorAll(montrer)).forEach(function (e) {{
      e.style.display = 'unset';
    }});
}}
</script>
</body>
</html>
  };


let $data := "OUT"
  return
    local:createOutput()
