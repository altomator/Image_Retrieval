//////////////// Misc ////////////

//  pour les panneaux pop-up
function showhide(id) {{
 console.log("showhide: "+id);
 var e = document.getElementById(id);
 e.style.display = (e.style.display == 'block') ? 'none' : 'block';
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

function saisie() {{
  var texte = prompt("Entrer le texte", "");
  if (texte != null) {{
    return texte
  }} 
}}

function removeElement(elementId) {{   
    var element = document.getElementById(elementId);
    element.parentNode.removeChild(element);
}}


// curseurs     
function wait(){{
  console.log("waiting...");
  document.body.style.cursor = 'wait';
}}

function normal(){{
  document.body.style.cursor = 'default'
}}

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
