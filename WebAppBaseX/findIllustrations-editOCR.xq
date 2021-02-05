(:
 HTM form to edit some illustrations metadata
:)


declare namespace functx = "http://www.functx.com";

declare option output:method 'html';
 
(: Arguments avec valeurs par defaut 
   Args and default values               :)
declare variable $corpus as xs:string external ;
declare variable $id as xs:string external  ; (: document ID :)
declare variable $n as xs:string external  ;  (: illustration number :)
declare variable $url as xs:string external  ;  (:  Gallica url :)
declare variable $type as xs:string external  ;
declare variable $title as xs:string external  ; (: titre - title :)
declare variable $subtitle as xs:string external  ; (: sous-titre : titraille :)
declare variable $caption as xs:string external  ; (: legende :)
declare variable $txt as xs:string external  ; (: texte :)
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
<title>Gallica.pix : OCR</title>
</head>
<body onload="init()">

<div class="form">  
<p class="titrePage"><span lang="fr">Corrigez l&#x27;OCR des illustrations</span><span lang="en">Correct the illustrations OCR</span></p>
<div class="help-tip">
<p><span lang="fr">Participez à l&#x27;enrichissement de la collection
en corrigeant le texte océrisé. </span></p>
<p><span lang="en">Participate in the enrichment of the collection by correcting the OCR. </span></p>
</div>


<p id="debug"></p> 

<form action="/rest?" method="get">


<input type="hidden" name="id" value="{$id}"/>
<input type="hidden" name="n" value="{$n}"/>

 
<div class="champ1">Document&#8193;&#8193; 
  <label class="gris"> {data($title)}</label>  
</div>

<!--
faire afficher la vignette de l illustration 

<div class="thumb">
 <img class="thumb" src="{data($iiif)}"></img>  
</div>
 -->
 
 <div class="champ" ><span lang="fr">Titre</span><span lang="en">Title</span>     
  <input type="text" id="subtitle" name="subtitle"  class="texte" value="{data($subtitle)}"></input>
</div>

<div class="thumb">
 <a id="linkIIIF" href="{$url}" target="_blank" title="Voir l'illustration"> <span class="fa" style="font-size:30pt;padding-left:30px">&#xf1c5;</span>  </a>
  </div>
  
 <div class="champ"><span lang="fr">Légende</span><span lang="en">Caption</span> <br></br> 
  <textarea name="caption" id="caption" cols="65" rows="3"  value="{data($caption)}">{data($caption)}</textarea>
 </div>
 
 <div class="champ"><span lang="fr">Texte</span><span lang="en">Text</span><br></br>  
  <textarea name="txt" id="txt" cols="65" rows="4"  value="{data($txt)}">{data($txt)}</textarea>
 </div>
 


 
<input lang="fr" type="button" class="button" value="Enregistrer" onclick="updateBase('{$corpus}');"></input>
<input lang="en" type="button" class="button" value="Save" onclick="updateBase('{$corpus}');"> </input>
<input type="hidden" name="corpus" value="{$corpus}"/>  
&#8193;<button type="button"  class="button" lang="fr"
        onclick="window.open('', '_self', ''); window.close();">Annuler</button> 
<button type="button"  class="button" lang="en"
        onclick="window.open('', '_self', ''); window.close();">Cancel</button>  
        
<iframe style="height:50px;width:200px;float:right;" name="ligneAff" frameborder="0" src="">
  <p>Erreur : votre navigateur ne supporte pas les iframe !</p>
</iframe> 
  </form> 
  
  
  </div>
   
   
<script>
// localiser les interfaces
function localize (language)
{{
  console.log("localize : "+language);
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
   console.log("lang : "+lang);
    document.querySelectorAll(hide).forEach(function (node) {{
      node.style.display = 'none';
     }});    
   document.querySelectorAll(show).forEach(function (node) {{
      node.style.display = 'unset';
    }}); 
    
}}

function isNotEmpty(value) {{
    return  (value.length != 0);
}}

function popitup(url,windowName) {{
       newwindow=window.open(url,windowName,'height=200,width=350,top=200,left=300,menubar=0,status=0,toolbar=0,titlebar=0,location=0');
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}

function popitup2(url) {{
       //animer('body');
       newwindow=window.open(url,"ligneAff");
       if (window.focus) {{newwindow.focus()}}
       window.setTimeout(close, 1000);
       return false;
     }} 
     
function gallica(url,windowName) {{
       newwindow=window.open(url,windowName,'height=800,width=1000,top=100,left=400');
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}
     

function updateBase(corpus) {{
  console.log("update base");

  id = '{data($id)}';
  console.log("id : "+id);
  n = '{data($n)}';
  console.log("n : "+n);


 // recuperer les données saisies par utilisateur
if ('{data($type)}' == 'I') {{soustitre=""}}  // image : champ non editable
else {{ 
soustitreInit = '{data($subtitle)}';
console.log("sous-titre initial : "+soustitreInit);
soustitre = document.getElementById('subtitle').value; 
if (soustitreInit == soustitre) {{soustitre=""}}
}}
console.log("sous-titre final : " + soustitre); 

legInit = '{data($caption)}';
console.log("leg initial : "+legInit);
leg = document.getElementById('caption').value; 
if (legInit == leg) {{leg=""}}
console.log("leg final : " + leg); 

txtInit = '{data($txt)}';
console.log("txt initial : "+txtInit);
txt = document.getElementById('txt').value; 
if (txtInit == txt) {{txt=""}}
console.log("txt final : " + txt);

source = '{data($source)}';

popitup2('/rest?run=updatebaseOCR.xq&amp;corpus='+corpus+ '&amp;id='+ id + '&amp;n='+ n +  '&amp;subtitle='+ soustitre +  '&amp;caption='+ leg  +  '&amp;txt=' + txt  +  '&amp;source=' + source) ;

}}
 
 
// initialiser les champs du formulaire    
function init() {{
  //langue = (navigator.language) ? navigator.language : navigator.userLanguage;
  //window.onload=localize(langue);
   localize('{$locale}'); 
  
  // bloquer edition du sous-titre des documents images (car egal au titre)
  var e = document.getElementById('subtitle');
  e.readOnly = ('{data($type)}' == 'I') ? true : false;  
  e.style.color = ('{data($type)}' == 'I') ? 'gray' : 'black';      
  }}

function showhide(id) {{
       var e = document.getElementById(id);
       e.style.display = (e.style.display == 'block') ? 'none' : 'block';
     }}
     
</script>
</body>   
</html>
  };        


let $data := $corpus   (: collection BaseX  :)  
  return
    local:createOutput()