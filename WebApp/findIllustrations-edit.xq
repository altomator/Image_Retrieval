(:
 HTM form to edit classification illustration metadata
:)


declare namespace functx = "http://www.functx.com";

declare option output:method 'html';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
declare variable $corpus as xs:string external ;
declare variable $id as xs:string external  ; (: document ID :)
declare variable $n as xs:string external  ;  (: illustration number :)
declare variable $iiif as xs:string external  ;  (:  IIIF url :)
declare variable $title as xs:string external  ; (: titre - title :)
declare variable $subtitle as xs:string external  ; (: sous-titre : titraille :)
declare variable $type as xs:string external  ;
declare variable $iptc as xs:string external :="00" ; (: theme :)
declare variable $color as xs:string external  ; (: couleur :)
declare variable $illType as xs:string external  ; (: dessin, gravure, etc. :)
declare variable $locale as xs:string external := "" ;
declare variable $source as xs:string external := "" ;


(: Construction de la page HTML 
   HTML page creation :)
declare function local:createOutput() {
<html>
   <head>
  <link rel="stylesheet" type="text/css" href="/static/edit.css"></link>  
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"></link>
   
 <!-- Construction de la page HTML -->
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/> 
<title>Gallica.pix : edit</title>
</head>
<body onload="init()">

<div class="form">  
<p class="titrePage"><span lang="fr">Correction des métadonnées des illustrations</span><span lang="en">Illustrations metadata correction</span></p>
<div class="help-tip">
<p><span lang="fr">Participez à l&#x27;enrichissement de la collection
en corrigeant les métadonnées des illustrations  (thème, genre...). 

<br></br><br></br>
<b>Note</b> : les types "texte", "ornement", "couverture" et "filtre" conduisent au retrait de l&#x27;illustration de la base</span></p>
<p><span lang="en">Participate in the enrichment of the collection by correcting the illustrations metadata (theme, genre...). 

<br></br><br></br>
<b>Note</b>: The "Text", "Ornament", "Cover" and "Filter" genres lead to the removal of the illustration from the base.</span></p>
</div>


<p id="debug"></p> 

<form onKeyPress="return checkSubmit(event)" action="/rest?" method="get">


<input type="hidden" name="id" value="{$id}"/>
<input type="hidden" name="n" value="{$n}"/>

 
 <div class="champ1">Document&#8193;&#8193; 
  <label class="gris"> {data($title)}</label>    
</div>

<div class="champ"><span lang="fr">Titre</span><span lang="en">Title</span>&#8193;&#8193;
 <label class="gris">{data($subtitle)}</label>
</div> 

<div class="thumb">  
  <a id="linkIIIF" title="Voir l'illustration" href="javascript:window.open('{$iiif}','_blank','height=350,width=580,top=200,left=400,menubar=0,status=0,toolbar=0,titlebar=0,location=0')" target="_blank"> <span class="fa" style="font-size:30pt;padding-left:30px">&#xf1c5;</span></a>
</div>
 
<hr align="left" size="1" width="50%" noshade = ""></hr>    
<div class="champ">
  <label lang="fr">Thème</label><label lang="en">Theme</label>&#8193; &#8193;
 
 <select name="iptc" id="themeSelect"> 
  <option value="00"> </option> 
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
  <option lang="fr" value="07">Sante</option>
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
 </div>

  <div>     
    <input type="radio" id="gris" name="color" value="gris"></input> <label lang="fr">Gris</label><label lang="en">Grayscale</label> &#8193;
    <input type="radio" id="mono" name="color" value="mono"></input> <label lang="fr">Monochrome</label><label lang="en">Monochrome</label> &#8193;
    <input type="radio" id="coul" name="color" value="coul"></input> <label lang="fr">Couleur</label><label lang="en">Color</label>    
  </div>
  
  <img  class="types" src="/static/affiche.jpg"></img> 
  <img  class="types" src="/static/bd.jpg"></img>
  <img  class="types" src="/static/carte.jpg"></img>
  <img  class="types" src="/static/dessin.jpg"></img>
   <img class="types" src="/static/graphe.jpg"></img>
  <img  class="types" src="/static/gravure.jpg"></img>
  <img class="types" src="/static/manuscrit.jpg"></img>
  <img class="types" src="/static/partition.jpg"></img>
  <img class="types" src="/static/photo.jpg"></img>
  <img class="types" src="/static/photog.jpg"></img>  
  
 
   
  <div class="champTypes">
   <input type="radio" name="illType" accesskey="a" id="affiche" value="affiche"></input><label lang="fr">Affiche</label><label lang="en">Poster</label>&#8193;
   <input type="radio" name="illType" accesskey="b" id="bd" value="bd"></input><label lang="fr">BD</label><label lang="en">Comics</label>&#8193;
   <input type="radio" name="illType" accesskey="c" id="carte" value="carte" ></input> <label lang="fr">Carte</label><label lang="en">Map</label>&#8193;
   <input type="radio" name="illType" accesskey="d" id="dessin" value="dessin"></input> <label lang="fr">Dessin</label><label lang="en">Drawing</label>&#8193;
    <input type="radio" name="illType" id="graphique" value="graphique"></input> <label lang="fr">Graphique</label><label lang="en">Graph</label>&#8193;
   <input type="radio" name="illType"  accesskey="g" id="gravure" value="gravure"></input> <label lang="fr">Gravure</label><label lang="en">Engrawing</label>
   <input type="radio" name="illType"  accesskey="m" id="manuscrit" value="manuscrit"></input> <label lang="fr">Manuscrit</label><label lang="en">Manuscr.</label>
   <input type="radio" name="illType"  id="partition" value="partition"></input> <label lang="fr">Partition</label><label lang="en">Music</label>
 <input type="radio" name="illType"   id="photo" value="photo"></input> <label lang="fr">Photo</label><label lang="en">Photo</label>
    <input type="radio" name="illType"  accesskey="p" id="photog" value="photog"></input> <label lang="fr">Photogr.</label><label lang="en">Photoengr.</label>  
      
   <br></br> 
   
    <img class="types" src="/static/texte.jpg"></img>
    <img class="types"  src="/static/ornement.jpg"></img>&#8193; &#8193; &#8193;
     <img class="types" src="/static/couv.jpg"></img>&#8193;
      <img class="types" src="/static/filtre.jpg"></img>
    
     <br></br>
    <input type="radio" name="illType" accesskey="f" id="filtretxt" value="filtretxt"></input> <label lang="fr">Texte</label><label lang="en">Text</label>&#8193;
    <input type="radio" name="illType" accesskey="o" id="filtreornement" value="filtreornement"></input> <label lang="fr">Ornement</label><label lang="en">Ornament</label> &#8193; 
     <input type="radio" name="illType" id="filtrecouv" value="filtrecouv"></input> <label lang="fr">Couvert.</label><label lang="en">Cover</label>&#8193; 
    <input type="radio" name="illType" id="filtre" value="filtre"></input> <label lang="fr">Filtre</label><label lang="en">Filter</label>&#8193; 
  </div>

 
<input  lang="fr" accesskey="s" type="button" class="button" value="Enregistrer" onclick="updateBase('{$corpus}');"></input>
<input lang="en" accesskey="s" type="button" class="button" value="Save" onclick="updateBase('{$corpus}');"> </input>
<input type="hidden" name="corpus" value="{$corpus}"/>  
&#8193;<button type="button"  class="button" lang="fr"
        onclick="window.open('', '_self', ''); window.close();">Annuler</button> 
<button type="button"  class="button" lang="en"
        onclick="window.open('', '_self', ''); window.close();">Cancel</button>
        
<iframe style="height:30px;width:200px;float:right;" name="ligneAff" frameborder="0" src="">
  <p>Erreur : votre navigateur ne supporte pas les iframe !</p>
</iframe>   
  </form> 
  </div>
   
<script>
function popitup1(url) {{
  console.log("url : "+url);
  newwindow=window.open(url,'_blank','height=150,width=280,top=200,left=400,menubar=0,status=0,toolbar=0,titlebar=0,location=0');
  if (window.focus) {{newwindow.focus()}}
  return false;
     }}

// appeler un XQuery,afficher le resultat dans ligneAff, temporiser puis fermer la fenêtre
function popitup2(url) {{
       //animer('body');
       newwindow=window.open(url,"ligneAff");
       if (window.focus) {{newwindow.focus()}}
       window.setTimeout(close, 1000);
       //window.close();
       return false;
     }} 
     
// localiser les interfaces
function localize (language)
{{
  console.log("localize: "+language);
  if (language.includes('fr')) {{
     lang = ':lang(fr)';
     hide = '[lang]:not(' + lang + ')';
     show = '[lang]' + lang;
     
     document.getElementById('linkIIIF').title="Voir l'illustration";
   }} 
   else 
    {{
     lang = ':lang(en)';
     hide = '[lang]:not(' + lang + ')';
     show = '[lang]' + lang;
     
     document.getElementById('linkIIIF').title="See the illustration";
   }} 
   console.log("lang: "+lang);
   Array.from(document.querySelectorAll(hide)).forEach(function (e) {{
      e.style.display = 'none';
    }});
    Array.from(document.querySelectorAll(show)).forEach(function (e) {{
      e.style.display = 'unset';
    }});
  
}}

function isNotEmpty(value) {{
    return  (value.length != 0);
}}

// update de la base XML     
function updateBase(corpus) {{
console.log("update base: "+ corpus);

id = '{data($id)}';
console.log("id: "+id);
n = '{data($n)}';
console.log("n: "+n);


// recuperer les choix utilisateur
iptc=""
iptc = document.getElementById('themeSelect').value; 
console.log("theme: "+iptc);

iptcInit = '{data($iptc)}';
console.log("initial theme: "+iptcInit);
// comparer avec la valeur en base
if ((iptcInit == iptc) || (iptc =="00")) {{iptc=""}}
console.log("final theme: "+iptc);

illType=""
radios = document.getElementsByName('illType');
for (var i=0;   radios.length>i; i++)
{{
 if (radios[i].checked)
 {{
  illType = radios[i].value;
  console.log("radio: " + illType);
  break;
 }}
}};
console.log("type: "+illType);

typeInit = '{data($illType)}';
console.log("type initial : "+typeInit);
if (typeInit == illType) {{illType=""}}
console.log("type final : "+illType);

color=""
radios = document.getElementsByName('color');
for (var i=0;   radios.length>i; i++)
{{
 if (radios[i].checked)
 {{
  color = radios[i].value;
  console.log("color: " + color);
  break;
 }}
}}
colInit = '{data($color)}';
console.log("initial color: "+colInit);
if (colInit == color) {{color=""}}
console.log("final color: "+color); 

source = '{data($source)}';

 popitup2('/rest?run=updatebase.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n +  '&amp;iptc=' + iptc + '&amp;illType=' + illType + '&amp;color=' + color  +  '&amp;source=' + source) ;
    }}
 
 
// initialiser les champs du formulaire    
function init() {{
  //langue = (navigator.language) ? navigator.language : navigator.userLanguage;
  langue = '{$locale}';
  //window.onload=localize(langue);  
  localize('{$locale}'); 
   
  val = '{data($color)}';    
  if (isNotEmpty(val) ) {{
    console.log("color: "+val);
    if  (val != 'inconnu') {{
      document.getElementById(val).checked = 'true';}}
  }}
 
  val = '{data($illType)}'; 
  if (isNotEmpty(val)) {{
    console.log("type: "+val);
    if  (val != 'inconnu') {{
     document.getElementById(val).checked = 'true';}}
 }}
    
  //document.getElementById("debug").innerHTML = '('+ "{data($type)}" + ')';
  
  // bloquer edition du sous-titre des documents images (car egal au titre)
  //var e = document.getElementById('subtitle');
  //e.readOnly = ('{data($type)}' == 'I') ? true : false;  
  //e.style.color = ('{data($type)}' == 'I') ? 'gray' : 'black'; 
     
  // theme IPTC
   val = '{data($iptc)}';
   iptc = (isNotEmpty(val)) ? '{data($iptc)}' : "00";
   console.log("theme: "+iptc);
   // il y a 2x plus d items (FR + EN)
   if (iptc=="00") {{
     document.getElementById('themeSelect').getElementsByTagName('option')[0].selected = 'selected'}}
   else if (langue.includes('fr')) {{
      console.log("fr");
     document.getElementById('themeSelect').getElementsByTagName('option')[Number(iptc)*2-1].selected = 'selected';}}
   else 
     {{
       console.log("en");
       document.getElementById('themeSelect').getElementsByTagName('option')[Number(iptc)*2].selected = 'selected';}}
  }}

function showhide(id) {{
       var e = document.getElementById(id);
       e.style.display = (e.style.display == 'block') ? 'none' : 'block';
     }}
     
// la touche Entrer envoie le formulaire     
function checkSubmit(e) {{
   if(e.keyCode == 13) {{
     updateBase('{$corpus}');
   }}
}}


     
</script>
</body>   
</html>
  };        


let $data := $corpus   (: collection BaseX  :)  
  return
    local:createOutput()