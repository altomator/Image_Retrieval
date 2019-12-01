(:
 Recherche d'illustrations dans une base BaseX
 Illustration Search in a BaseX database
:)

declare namespace gpix="https://github.com/altomator/Image_Retrieval";
declare namespace functx = "http://www.functx.com";

declare option output:method 'html'; 

(: Parametres :)
declare variable $debug as xs:integer external := 0 ;  (: developpement-production / switch dev-prod :)

(: Arguments du formulaire avec valeurs par defaut
   Args and default values from the form     :)
declare variable $corpus as xs:string external ;  (: base - database :)
declare variable $TNA as xs:integer external := if ($corpus = "pp18") then (1) else (0) ;  (: TNA project :)
declare variable $sourceTarget as xs:string external ;  (: source des docs - documents source :)
declare variable $keyword as xs:string external  ; (: mot cle - keyword :)
declare variable $id as xs:string external := "" ;  (: ID de l'illustration / illustration ID :)
declare variable $kwTarget as xs:string external := "" ; (: opérateur de recherche / search operator on keyword:)
declare variable $kwMode as xs:string external := "" ; (: mode de recherche : joker, floue / search mode: wildcard, fuzzy :)
declare variable $title as xs:string external := "" ; (: titre du document - work title :)
declare variable $author as xs:string external := "" ; (: auteur du document - work author :)
declare variable $publisher as xs:string external := ""  ;
declare variable $special as xs:string external := "" ;  (: supplément ? / newspaper supplement? :)
declare variable $page as xs:string external  :="" ;  (: en une / front page :)
declare variable $pageOrder as xs:string external  :="" ; (: numéro de page / page number :)
declare variable $fromDate as xs:string external := ""; (: de la date / from date :)
declare variable $toDate as xs:string external := "";  (: toute la collection / all the collection :)
declare variable $typeM as xs:string external := "" ; (: collections: presse, monographie, image :)
declare variable $typeA as xs:string external := "" ;  
declare variable $typeR as xs:string external := "" ;
declare variable $typeI as xs:string external := "" ;
declare variable $typeP as xs:string external := "" ;
declare variable $typeC as xs:string external := "" ;
declare variable $typePA as xs:string external := "" ;
declare variable $illType as xs:string external := "" ; (: type du document : carte, photo... / document type: map, picture... :)
declare variable $iptc as xs:string external := "00" ; (: thème IPTC / IPTC topic :)
(: declare variable $person as xs:string external := "" ;  personne ? :)
declare variable $persType as xs:string external := "00" ; (: critere visage, personne : H/F/soldat... / person criteria :)
declare variable $operator as xs:string external := "and";  (: operateur ET-OU / AND-OR operator :) 
declare variable $color as xs:string external := "" ; (: couleur / color mode :)
declare variable $colName as xs:string external := "" ; (: nom de couleur / color name :)
declare variable $rValue as xs:string external := "" ; (: for similarity search on rgb values :)
declare variable $gValue as xs:string external := "" ;
declare variable $bValue as xs:string external := "" ;
declare variable $bkgColor as xs:string external := "" ;
declare variable $ad as xs:string external :="" ;  (: pages avec publicité filtrées si $ad=1 / pages with ad if $ad=1 :)
declare variable $illAd as xs:string external :="" ;  (: illustration de publicité / illustrated ads :)
declare variable $illFreead as xs:string external :="" ;  (: annonces / freeads :)
declare variable $size as xs:integer external := 31 ; (: 31 = valeur par defaut du slider 1-10 / illustration size :)
declare variable $density as xs:integer external := 26 ; (: 26 = valeur par defaut du slider 1-50 / density of illustrations on a page :)
declare variable $similarity as xs:string external := "" ; (: for similarity search on hashes :)
declare variable $CBIR as xs:string external := "*"; (: source des données de classification / source of the classification data: * / ibm / dnn / google :)
declare variable $classif1 as xs:string external := "" ; (: concept de classification / classification concept :)
declare variable $classif2 as xs:string external := "" ; (: concept de classification / classification concept :)
declare variable $faceClass as xs:string external := "face"; (: nom du concept "visage" / name of the Face class :)
declare variable $locale as xs:string external := "" ; (: localisation / localization : "fr"/"en" :)
declare variable $filter as xs:integer external := 1 ; (: filtrage / if filter=1, filtered illustrations are not displayed :)

(: Parametres divers 
   Misc. :)
declare variable $thumbDisplay as xs:integer  := 0 ;  (: display thumbnails or use IIIF protocol  :)
declare variable $display as xs:integer external := if ($TNA) then (0) else (1);  (: affichage des infos de classification / display of classification data :)
declare variable $crowd as xs:integer external := 0;  (: affichage des icones crowdsourcing / display of crowdsourcing icons  :)
declare variable $CS as xs:decimal external ; (: seuil pour la classification / threshold on classification Confidence Score, from 0 to 1 - 0%-100% :)
declare variable $CScolor as xs:decimal  := if ((0.8 - $CS) <= 0) then (0.1) else (0.8-$CS); (: tolérance pour la similarité par couleur / confidence for color similarity 0.1=10%, 0.2=20%... :)
declare variable $sourceData as  xs:string := "final"; (: source de données à interroger / target of the request 
bibliographique metadata: "md" / TensorFlow classification: "TensorFlow" / production annotations: "hm" or "cwd" (crowdsourcing) / computed "final" classification: final :)
declare variable $sourceEdit as  xs:string := if ($debug=0) then ("hm") (: cwd if crowdsourcing available :)
else ("hm"); (: source des données annotées / source of the human annotations: hm / cwd :)
declare variable $formFactor as xs:integer external := 0 ; (: facteur de forme : ill. verticale, horizontale / form factor :)
declare variable $order as xs:integer external := 0 ; (: affichage par date, taille / display order: date, size :)

(: nombre  de résultats affichables  / Number of results to be displayed :)
declare variable $maxRecords as xs:integer external := 2000 ;
declare variable $records as xs:integer external := if ($corpus="test") then (800) else (800) ;
(: pagination de la liste des resultats / Pagination system of the results list:)
declare variable $start as xs:integer external ;
declare variable $action as xs:string external := "first" ;

(:  modalité / rendering modality : xml/html/json :)
declare variable $mode as xs:string external := "html";
(: -------- END arguments ---------- :)

(: ---- paramètres / parameters ---- :)
(: nombre de classes affichables / visual classification classes to be displayed :)
declare variable $minClasses as xs:integer external := 30 ;
declare variable $maxClasses as xs:integer external := 75 ; (: only 75 buttons are predefined:)
declare variable $maxGenres as xs:integer external := 15 ;
(: longueur max de présentation des textes (en caracteres) / Max lenght of the texts to be displayed :)
declare variable $txtLength := 400;
declare variable $legLength  := 350;
(: module d'affichage des images : 0.5 / 1.0 / 2.0 / Size of the thumbnails :)
declare variable $module as xs:decimal external := if ($corpus="pp18") then (0.5) else (1) ;
(: seuil de largeur ou hauteur des illustrations a afficher en grand format (en pixels) /
Threshold of the illustrations to be displayed larger (pixels value) :)
declare variable $seuilGrand  := 4000;
(: couleurs d'affichage du masque sur les visages 
Colors of the faces mask for Women, Man and no Gender:)
declare variable $coulFaceF   := "rgba(255,192,203, 0.4)";  (: rose :)
declare variable $coulFaceM   := "rgba(30,144,255, 0.4)";   (: bleu :)
declare variable $coulFaceP   := "rgba(150,110,110, 0.4)";  (: brun rouge :)
(: declare variable $coulIconP := "rgba(140,110,110, 0.8)";   brun :)
declare variable $coulIconP := "rgba(132,65,157, 0.8 )";  (: violet :)

declare variable $dossierLocal  := "/static/img/" ;
declare variable $logFile := "/static/log.txt" ;
(: -------- END parameters ---------- :)

(: ----------- Variables ------------ :)
(: critère sur la source de la classification: ibm (Watson), google, dnn 
Criteria on the classification source: ibm (Watson), google, dnn :)
declare variable $CBIRsource := if ($CBIR="*") then () else (concat("@source='",$CBIR,"' and "));

(: -------- END variables  ---------- :)



declare function functx:is-a-number
  ( $value as xs:anyAtomicType? )  as xs:boolean {

   string(number($value)) != 'NaN'
 } ;
 
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
     case "classes" return (: we use the classification classes :)
    if (($classes contains text {"woman","girl","lady","female","sister "}) and
        ($classes contains text {'man','soldier','old_man','laborer','gentleman','marshal','artilleryman','fireman','workman','cavalryman','horseman','coachman','bandsman','serviceman','crewman','moustache','beard'}))
     then 
        ("Mixte")
     else (
        if ($classes contains text {"woman","girl","lady","female","sister"}) then 
          ("F")
        else (if ($classes contains text {'man','soldier','old_man','gentleman', 'laborer','marshal','artilleryman','fireman','workman','cavalryman','horseman','coachman','bandsman','serviceman','crewman','moustache','beard'}) then 
              ("M")
              else (      
                   if ($classes contains text {'person','portrait_picture','people'}) then 
                     ("P")
                   else ()
                   )
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

(: création de la requête XQuery :)
declare function local:createQuery($data) { 

(: critère sur la source (bibliotheque num)
Criteria on documents source (DLs) :)
let $source-predicate := if (not ($sourceTarget="")) then (
 if ($sourceTarget="gallica") then (" not(metad/url) and not(@iiif) and ") (: no source=Gallica (default behaviour) :)
 else (concat(" (metad/source[text()='", $sourceTarget, "']) and "))) else ()
  
(: mot clé sur les textes : remplacer la virgule par ',' 
replacing , -> ',' in the keyword :)
let $filtered-key :=  replace($keyword,'''','''''') (: XQuery issue with quote entity :)
let $filtered-key := replace($filtered-key, ",", "','") 
(: Mot-clé : on cherche dans les textes avec http://docs.basex.org/wiki/Full-Text ()
Keyword: we search in the texts with http://docs.basex.org/wiki/Full-Text :)
let $keyword-predicate := if ( ($keyword!="")) then (
  if (($kwTarget="") and ($kwMode="")) then (    
    concat( 
     "((titraille contains text {'",  $filtered-key, "'} any using stemming using language 'French')",
  " or (leg contains text {'",  $filtered-key, "'} any using stemming using language 'French')",
  " or (txt contains text {'",  $filtered-key, "'} any using stemming using language 'French')) ",  $operator," "   
(:  "(matches(titraille,'",  $filtered-key, "','is') ",  
  " or matches(leg,'",  $filtered-key, "','is') ", 
  " or matches(txt,'",  $filtered-key, "','is')) and ":)
   )
  )
  (: Recherche avancée avec contains() : tokenisation, options 
  Advanced search with contains() :)
  else (  
   concat(  
  "((titraille contains text {'",  $filtered-key, "'} ", $kwTarget," ",$kwMode,")",
  " or (leg contains text {'",  $filtered-key, "'} ", $kwTarget," ",$kwMode,")",
  " or (txt contains text {'",  $filtered-key, "'} ", $kwTarget," ",$kwMode,")) ", $operator," "
   ))
 )
 else ()
 
(: critère sur les titres :)
let $filtered-title :=  replace(fn:lower-case($title),'''','''''') (:  issue with quote entity :)
let $title-predicate := if (not ($filtered-title="")) then concat(
  "(metad/titre[contains(fn:lower-case(.),'",$filtered-title,"')]) and ") else ()
  
let $filtered-author :=  replace(fn:lower-case($author),'''','''''') 
let $author-predicate := if (not ($filtered-author="")) then concat(
  "(metad/auteur[contains(fn:lower-case(.),'",$filtered-author,"')]) and ") else ()
  
let $filtered-publisher :=  replace(fn:lower-case($publisher),'''','''''') 
let $publisher-predicate := if (not ($filtered-publisher="")) then concat(
  "(metad/editeur[contains(fn:lower-case(.),'",$filtered-publisher,"')]) and ") else ()
    
(: critère sur les ID :)
let $id-predicate := if  (not ($id = "")) then concat ( 
   " (metad/ID[text()='", $id, "']) and ") else ()   
   
(: critère sur les dates :)
let $fromDate-predicate := if (not ($fromDate="")) then concat(
   "  (metad/dateEdition ge '",
  $fromDate, "') and ") else ()
let $toDate-predicate := if (not ($toDate="")) then concat(
   " (metad/dateEdition le '",
  $toDate, "') and ") else ()

(: critère sur les supplements pour les périodiques :)
let $supp-predicate := if  (not ($special = "")) then (
   " (metad/suppl = ""TRUE"") and ") else ()

(: critère sur les types de docs : presse, revue, image, monographie 
Criteria on documents types :)
let $typeP-predicate := if (not ($typeP = "")) then (
  "  (metad/type = 'P') or ") else ()
let $typeR-predicate := if (not ($typeR = "")) then (
   " (metad/type = 'R') or ") else ()
let $typeM-predicate := if (not ($typeM = "")) then (
   " (metad/type = 'M') or ") else ()
let $typeA-predicate := if (not ($typeA = "")) then (
   " (metad/type = 'A') or ") else ()
let $typeI-predicate := if (not ($typeI = "")) then (
   " (metad/type = 'I') or ") else ()
let $typeC-predicate := if (not ($typeC = "")) then (
   " (metad/type = 'C') or ") else ()
let $typePA-predicate := if (not ($typePA = "")) then (
   " (metad/type = 'PA') or ") else ()
   
let $type-predicate := if ((not ($typeP = "")) or (not ($typeR = ""))
 or (not ($typeM = "")) or (not ($typeA = "")) or (not ($typeC = "")) or (not ($typePA = "")) or (not ($typeI = "")))
  then (
 concat ( "  (",
  $typeP-predicate,
  $typeR-predicate,
  $typeM-predicate,
  $typeA-predicate,
  $typeI-predicate,
  $typeC-predicate,
  $typePA-predicate, "0 ) and "))  (: pour neutraliser le dernier OU / neutralizing the last OR :)
  else ()

(: critère sur les pages : page de début, de fin  
Criteria on page position :)
let $npage-predicate := if  (not ($pageOrder = "")) then concat(
   "  (@ordre = ",
  $pageOrder, ") and ") else ()

(: critère sur la densité en illustrations 
Criteria on illustrations density :)  
let $densite-predicate := if  (not ($density = 26)) then concat(
   "  (blocIllustration > ",
  $density, ") and ") else ()
  
(: filtrer les pages avec au moins une publicite 
Filtering the page with at list one ad:)
let $pub-predicate := if  ($ad = "1") then (
   " ((not (blocPub)) or (blocPub < 1)) and ") else ()

(: critère sur la couleur : niveaux de gris, monochrome, couleur
Color criteria :)
let $couleur-predicate := if  (not ($color="")) then concat(
   " (@couleur = '",
  $color, "') and ") else ()
  
(: critère sur les types de documents: carte, dessin, photo...
Criteria on documents types: map, drawing, picture... :)  
let $genre-predicate := if  (not ($illType = "")) then ( 
  switch($illType)
     case "none" return concat(" not(genre[@source='",$sourceData,"']) and ")  (: les ill. sans genre :)
     default return concat(" (genre[text()='", $illType,"' and @source='",$sourceData,"']) and ") 
  )   else ()

(: critère sur le thème IPTC
Criteria on IPTC topic :)  
let $theme-predicate := if  (not ($iptc = "00")) then ( concat(
  "  (theme[text()='", $iptc,"' and @source='",$sourceData,"']) and ")) else ()
  
(: criteres sur la classification des images 
let $person-predicate := if  (not ($person="")) then ( concat (" ", $operator,
   " ((contenuImg='person') or (contenuImg='people') or (contenuImg='portrait picture')
  or ((contenuImg[text()='", $faceClass,"' and @CS>",$CS,"])) ) ")) else () (: or (contenuImg='face'):)
:)


(: critère sur la classification de personnes : femme, homme, enfant, soldat, etc.
Permière partie : classes IBM Watson
Deuxième partie : classes Google Cloud Vision 
Criteria on Person classification: woman, man, child, soldier... 
First part:  IBM Watson classes
Second part:  Google Cloud Vision classes  :)
let $persType-predicate := if  (not ($persType="00")) then (  

   (: PERSON :)
   switch($persType)
     case "person" return concat (
   " (contenuImg[",$CBIRsource, "(text()='", $faceClass,"' or text()='man'  or 
   (text() contains text {'person','adult','people','figure','portrait','human','head','laborer','gentleman','woman'} any)) and @CS>=",$CS,"]) ",  $operator," ") 
    (: WOMAN :)
     case "personW" return concat ( 
     " (contenuImg[",$CBIRsource, "(
     (text() contains text {'woman','female','sister','girl','lady'} any) or
      (text()='", $faceClass,"' and @sexe='F'))         
     and  @CS>=",$CS,"]) ",  $operator," ")      
     (: MAN :) 
     case "personM" return concat (
     " (contenuImg[",$CBIRsource, "(text()='man' or text()='old man' or
     (text() contains text {'laborer','gentleman','soldier','marshal','artilleryman','fireman','workman','cavalryman','horseman','coachman','bandsman','serviceman','crewman'} any) or
     (text()='", $faceClass,"' and @sexe='M'))     
     and @CS>=",$CS,"]) ",  $operator," ")       
     (: CHILD :)
     case "child" return concat (
     " (contenuImg[", $CBIRsource, "(text() contains text {'child','schoolmate','juvenile','Boy-Scout'} any)  and @CS>=",$CS,"]) ",  $operator," ")     
     (: SOLDIER :)
     case "soldier" return concat (
     " (contenuImg[",$CBIRsource, "(text() contains text {'military','warrior','partisan','fusilier','infantry','troop','marksman','uniform','soldier','army','cavalryman','guard','artilleryman','militia'} any not in {'military vehicle','military aircraft'})  and @CS>=",$CS,"]) ",  $operator," ")       
    (: OFFICER :)
    case "officer" return concat (
     " (contenuImg[",$CBIRsource, "(text() contains text {'officer','commander','attache','captain','general','lieutenant','generalissimo'} any)
    and @CS>=",$CS,"]) ",  $operator," ")   
    (: VISAGE/FACE :)
     case "face" return concat (
       " (contenuImg[", $CBIRsource, "(text() contains text {'head','mans face','portrait'} any) or text()='",$faceClass,"' and @CS>=",$CS,"]) ",  $operator," ")
     case "faceW" return concat (
       " (contenuImg[",$CBIRsource, "text()='",$faceClass,"' and @sexe='F' and @CS>=",$CS,"]) ",  $operator," ")
     case "faceC" return concat (
       " (contenuImg[",$CBIRsource, "text()='",$faceClass,"' and @sexe='C' and @CS>=",$CS,"]) ",  $operator," ")
     case "faceM" return concat (
       " (contenuImg[",$CBIRsource, "text()='",$faceClass,"' and @sexe='M' and @CS>=",$CS,"]) ",  $operator," ")
     case "Pface" return concat (
       " (contenuImg[",$CBIRsource, "text()='", $faceClass,"' and @sexe='P'  and  @CS>",$CS,"]) ",  $operator," ")
    (: default :)    
     default return  concat (" (contenuImg[", $CBIRsource, "(text() contains text {'",  $persType, "'} any)]) ", $operator," ")
   ) 
   else (   
   )  

(: Critère sur les classes liées au corpus
Criteria on corpus classification classes :)   
let $class1-predicate := if (not ($classif1=""))  then (
  
  if ($locale='en') then (
    switch($classif1)
     (: Classes générales prédéfinies, avec synonymes 
     Some generic classes with synonyms :)
     case "Boat" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'boat','submarine','cruiser','ship','craft','destroyer'} any)]) ", $operator," ")      
     case "Horse" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'horse','poney'} any)]) ", $operator," ") 
     case "Airplane" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'airplane','aeroplane'} any)]) ", $operator," ")  
     case "Aircraft" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'aircraft','aviation','aeroplane'} any)]) ", $operator," ")     
     case "Weapon" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'weapon','weaponry','firearm','gun','artillery','bomb','cannon','mortar'} any)]) ", $operator," ")  
      case "War" return 
      concat(" (contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'war','battle','camouflage','artillery','army','bomb'} any)]) ", $operator," ")      
     case "Fortification" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'fortification','ditch','defensive','bunker','geology','trench'} any)]) " , $operator," ")    
     case "Tank" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'tank','panzer'} any)]) ", $operator," ")
     case "Vehicle" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'vehicle','truck',' car','transport'} any)]) ", $operator," ")  
    case "Armored vehicle" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'armored vehicle','armored car','combat vehicle','tracked vehicle'} any)]) ", $operator," ")
   
     case "Battle" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and ((text()='battle') or (text()='bomb') or (text()='war'))]) ", $operator," ") 
      
     case "Plant" return 
       concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'plants','flowers','floral','botany','leaf','tree'} any)]) ", $operator," ")
     case "Character" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'characters','women','figures','putti','children'} any)]) ", $operator," ")    
     case "Animal" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'animals','birds','dog','insects','insect'} any)]) ", $operator," ")
     case "Flower" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'flower','flowers','floral','rose'} any)]) ", $operator," ")
     case "Rose" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'roses','rose'} any)]) ", $operator," ")
      case "Bird" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='en' and (text() contains text {'birds','bird'} any)]) ", $operator," ")
           
      case "none" return 
       concat("(not(contenuImg[@source='",$CBIR,"'])) ", $operator," ")       
     (: Cas général 
     Generic class :) 
     default return
       concat("(contenuImg[@CS>=", $CS, if ($debug) then (" and not(@filtre) ") else (), " and @lang='en' and (text() contains text {'", $classif1,"'} any) ]) ", $operator," ")
  )
  else (
  switch($classif1)
     (: Classes générales prédéfinies, avec synonymes 
     Some generic classes with synonyms :)
     case "Bateau" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'bateau','sous-marin','croiseur','navire','destroyer'} any)]) ", $operator," ")
     case "Cheval" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'cheval','poney'} any)]) ", $operator," ") 
     case "Aéronef" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'avion', 'aéronef','aviation','dirigeable'} any)]) ", $operator," ")  
     case "Avion" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'avion'} any)]) ", $operator," ")  
     case "Arme" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'arme','armerie','fusil','artillerie','bombe','canon','mortier'} any)]) ", $operator," ")  
      case "Guerre" return 
      concat(" (contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'guerre','bataille','camouflage','artillerie','armée','bombe'} any)]) ", $operator," ")     
      case "Fortification" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'fortification','fossé','tranchée','défense','bunker','géologie','casemate'} any)]) " , $operator," ")  
     case "Tank" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'tank','panzer','char (blindé)'} any)]) ", $operator," ")
      case "Véhicule blindé" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'véhicule (blindé)','véhicule blindé', 'véhicule de combat','véhicule à chenilles', 'véhicule militaire'} any)]) ", $operator," ")
      case "Véhicule" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'véhicule','camion','voiture','transport'} any)]) ", $operator," ")      
     case "Bataille" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and ((text()='bataille') or (text()='bombe') or (text()='guerre'))]) ", $operator," ")
      
     case "Végétaux" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'végétaux','plante','fleur','floral','botanique','feuilles','arbres','branchages'} any)]) ", $operator," ")
     case "Personnage" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'personnage','personnages','femmes','figures','putti','enfant'} any)]) ", $operator," ")
     case "Animaux" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'animaux','oiseaux','oiseau','chien','insectes'} any)]) ", $operator," ")
     case "Fleurs" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'fleur','fleurs','floral','roses','rose'} any)]) ", $operator," ")
     case "Rose" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'roses','rose'} any)]) ", $operator," ")
      case "Oiseaux" return 
      concat("(contenuImg[@CS>=", $CS, " and @lang='fr' and (text() contains text {'oiseaux','oiseau'} any)]) ", $operator," ")
      
     (: Cas général 
     Generic class :) 
     default return
     let $query :=  replace($classif1,'''','''''') (: quote issue for XQuery :)
     return
     concat("(contenuImg[@CS>=", $CS, if ($debug) then (" and not(@filtre) ") else ()," and @lang='fr' and  (text() contains text {'", $query,"'} any) ]) ", $operator," ")
   )
 ) else ()

(: Critère sur les classes (2e champ)
Criteria on classification classes (2nd criteria) :)   
let $class2-predicate := if  (not ($classif2=""))  then ( 
 let $query :=  replace($classif2,'''','''''') 
 return
  concat(" (contenuImg[",$CBIRsource, " @CS>=", $CS, if ($debug) then (" and not(@filtre) ") else (), " and @lang='", $locale,"' and (text() contains text {'", $query,"'} any) ]) ", $operator," ")
 ) else ()
 
 
let $tmp := concat ($persType-predicate, $class1-predicate, $class2-predicate)
let $classif-predicate := if ($tmp) then (
  fn:substring($tmp,1, fn:string-length($tmp)-4))  (: suppress the last operator :)
else ()
 
(: Critère sur les couleurs 
Criteria on colors :) 
let $colName-predicate := if  (not ($colName="00")) then (
   switch($colName)   (: option : (@couleur='coul') AND :)
     case "red" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'red','reddish','crimson','darkred','indianred','cooper','orangered'} any]) " , $operator," ")  
 
     case "blue" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'blue','azure','ultramarine','cadetblue','blueviolet','lightsteelblue','lightblue','richblue','midnightblue','cornflowerblue','midnightblue'} any] and 
    not (contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black and white','monochrome'}])) ", $operator," ") 
  
     case "green" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'green','greenishness','emerald','olive','darkgreen','darkgreencopper','darkolivegreen','huntergreen','limegreen','greencopper','darkgreencopper','darkolivegreen','mediumforestgreen','palegreen','evergreen','greenyellow'} any] and 
    not (contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black and white','monochrome'}])) ", $operator," ")
        
     case "black" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black','charcoal','coal','darkness','monochrome'} any]) ", $operator," ")
   
     case "grey" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'grey','gray','darkgray','dimgrey','darkslategrey','lightgray','lightgray','verylightgrey'} any]) ", $operator," ")
    
     case "orange" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'orange','orangered','mandarianorange'} any]) ", $operator," ")
       
     case "brown" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'maroon','chesnut','tan','chocolate','brown','verydarkbrown','darktan','darkbrown'} any] and 
      not (contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black and white','monochrome'}])) ", $operator," ")
       
     case "beige" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'alabaster','ivory','beige'} any] and
      not (contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black and white','monochrome'}])) ", $operator," ")  
         
     case "pink" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'pink','carnation','rose','dustyrose'} any] and
      not (contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'black and white','monochrome'}])) ", $operator," ")
       
     case "purple" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'purple','violet','mediumvioletred','blueviolet'} any]) ", $operator," ")

     case "yellow" return concat ("(contenuImg[",$CBIRsource, "@coul='1' and @CS>=", $CS," and @lang='en' and text() contains text {'yellow','greenyellow','mediumgoldenrod'} any]) ", $operator," ")
       
     default return  ()
   ) else ()

(: critere  facteur de forme : image horizontale, verticale :)
let $form-predicate := if (not ($formFactor = 0)) then concat(
   " (@h > ",
  $formFactor, "*@w) and ") else ()

let $taille-predicate := if (not ($size = 31)) then concat(
   "  (@taille > ",
  $size, ") and ") else ()
  
(: critere de similarite :)
let $sim-predicate := if  (not ($similarity = "")) then concat(
   " @hash and  (strings:levenshtein(@hash,'", $similarity, "') > ",$CS,") and ")
 else ()

let $colorsim-predicate := if  (not ($rValue = "")) then 
if ($bkgColor="false") then concat(
  "(contenuImg[@source='colorific' and (fn:abs(@r - ",$rValue,") <= fn:avg((@r,",$rValue,")) * ", $CScolor,
  ") and (fn:abs(@g - ",$gValue,") <= fn:avg((@g,",$gValue,")) * ", $CScolor, 
  ") and (fn:abs(@b - ",$bValue,") <= fn:avg((@b,",$bValue,")) * ", $CScolor,")]) and " )  
 else concat(
  "(contenuImg[@source='colorific' and @type='bkg' and (fn:abs(@r - ",$rValue,") <= fn:avg((@r,",$rValue,")) * ", $CScolor,
  ") and (fn:abs(@g - ",$gValue,") <= fn:avg((@g,",$gValue,")) * ", $CScolor, 
  ") and (fn:abs(@b - ",$bValue,") <= fn:avg((@b,",$bValue,")) * ", $CScolor,")]) and " ) 
    
(: critere sur les images filtrees (pour le debug)  :)
let $filtre-predicate := 
if ($debug) then ( 
  if ($filter) then ( 
 switch($filter)
     case 9 return  "  @filtre and " (: pour obtenir les ill. filtrées :)
     case 10 return  " @filtre and not(@pub) and " (: pour obtenir les ill. filtrées non pub :)
     case 1 return  "  not(@filtre) and " (: pour filtrer les ill. de bruit :)
     case 2 return  "  @filtremd and " (: pour afficher les ill. de bruit d'apres les MD :)
     case 3 return  "  @filtretf and " (: pour afficher les ill. de bruit d'apres TensorFlow :)
     case 4 return  "  @filtrehm and " (: pour afficher les ill. de bruit d'apres humains :)
     case 5 return  "  not (@filtremd) and " (: pour filtrer les ill. de bruit d'apres les MD :)
     case 6 return  "  not (@filtretf) and " (: pour filtrer les ill. de bruit d'apres TensorFlow :)
     case 7 return  "  (@filtretf) and not (@filtremd) and " (: pour afficher les ill. de bruit d'apres TensorFlow seul :)
     case 8 return  "  (@filtremd) and not (@filtretf) and " (: pour afficher les ill. de bruit d'apres les MD seules :)     
     default return () (: no filtering :)
 )
   else () ) 
  
(: pour la presse / for newspapers: front page - last page :)
let $une-predicate := if (not ($page = ""))  then (
   switch($page)
     case "true" return "  (@une) and "
     case "false" return " (@derniere) and "
     default return ()
 )
else ()
   
(: for ads :)   
let $pubIll-predicate := if ($debug) then (
  if ($illAd = "1")  then (
    " (@pub) and "
 ) else ( " (not(@pub)) and " ))
 
 
(: for freeads :)   
let $annonceIll-predicate := if ($debug) then (
  if ($illFreead = "1")  then (
    " (@annonce) and "
 ) else ( " (not(@annonce)) and " ))
 
(: collection('PJI')//analyseAlto[* ]/child::contenus[(pages/page[position()>=1]) and (pages/page[position()<=1]) and pages/page/ills/ill[matches(titraille,'premiers','i') ]] :)

 (:     collection('PJI')//contenus[(pages/page[position()>=1]) and (pages/page[position()<=1])]/child::pages/page/ills/ill[matches(titraille,'premiers','i') ] :)

(: catégories de critères de recherche  : metadonnees sur le document :)
let $queryOnMeta := if ($source-predicate or $title-predicate or $author-predicate or $publisher-predicate or $fromDate-predicate or $toDate-predicate or $id-predicate or $type-predicate or $supp-predicate) then (1) else (0)

(: construction de la requête :)
(: recherche  avec critere sur les metadonnees  :)
(: criteria on metadata  :)
let $meta-predicate := if ($queryOnMeta = 1) then (   
  let $tmp := concat
  ( "/analyseAlto[",
   $id-predicate,
   $source-predicate,
   $type-predicate,
   $title-predicate,
   $author-predicate,
   $publisher-predicate,
   $fromDate-predicate,
   $toDate-predicate,
   $supp-predicate)
  let $op := fn:substring($tmp,fn:string-length($tmp)-3) (: suppress the last operator and :)
  return
  if ($op = "and ") then (
    concat(fn:substring($tmp,1,fn:string-length($tmp)-4),"]"))
  else (concat($tmp,"]"))
) else ("/analyseAlto")

 
(: criteres  sur les pages  :)
(: criteria on pages  :)
let $queryOnPages := if (not ($ad="") or not($density = 26) or not($pageOrder="")) then (1) else (0)
let $page-predicate := if ($queryOnPages = 1) then (
  let $tmp := concat (
    "/contenus/pages/page[",
  $npage-predicate,
  $densite-predicate,
  $pub-predicate) 
  let $op := fn:substring($tmp,fn:string-length($tmp)-3) (: suppress the last operator and :)
  return
  if ($op = "and ") then (
    concat(fn:substring($tmp,1,fn:string-length($tmp)-4),"]"))
  else (concat($tmp,"]"))
) else ("/contenus/pages/page")


(: criteres  sur les illustrations  :)
(: criteria on illustrations  :)
let $queryOnIlls := if ($keyword-predicate or $couleur-predicate or $une-predicate
or $taille-predicate or $form-predicate or $genre-predicate or $theme-predicate or $colName-predicate or $classif-predicate  or $filtre-predicate or $pubIll-predicate or $annonceIll-predicate or $sim-predicate or $colorsim-predicate) then (1) else (0)

let $ill-predicate := if ($queryOnIlls = 1) then ( 
  let $classif := if ($classif-predicate) then (concat("(",$classif-predicate,")")) else ()
  let $tmp :=  concat (
  "/ills/ill[ ",
  $keyword-predicate,
  $couleur-predicate,
  $une-predicate,
  $taille-predicate,
  $form-predicate,
  $genre-predicate,
  $theme-predicate,
  (: $person-predicate,:)
  $colName-predicate,
  $filtre-predicate,
  $pubIll-predicate,
  $annonceIll-predicate,
  $sim-predicate,
  $colorsim-predicate,
  $classif)
  let $op := fn:substring($tmp,fn:string-length($tmp)-3) (: suppress the last operator and :)
  return
   if (($op = "and ") or ($op = "or  ")) then (
    concat(fn:substring($tmp,1,fn:string-length($tmp)-4),"]"))
    else (concat($tmp,"]"))
) else ("/ills/ill")
 
(: executer la requete :)
let $evalString := concat (
   "collection('",
   $data,
   "')",
   $meta-predicate,
   $page-predicate,
   $ill-predicate
 ) 
return $evalString
};


(: Construction des contenus XML
   XML content creation :)
declare function local:createXMLOutput($data) {

let $evalString := local:createQuery($data)
(: pour ne pas executer la requete   :)
(: let $hits := () :)
 
let $hits := local:evalQuery($evalString)   

let $nResults := count($hits) 
let $end :=  min (($start + $records -1, $nResults)) 
let $subhits :=  subsequence($hits,$start,$records) 
let $ascending := if (($order=0) or ($order=2)) then (fn:true()) else (fn:false())
let $sortBy := if (($order=0) or ($order=1)) then ("date") else ("size")       
let $sorted := 
  for $i in $subhits
  let $root := $i/../../../../.. 
  order by
    if ($sortBy eq "date") then 
      $root/metad/dateEdition
    else if ($sortBy eq "size") then 
      number($i/@h * $i/@w) 
    else 
      ()
  return <doc>
  {$root/metad}
  <page ordre="{$i/../../@ordre}" >
  {$i}
  </page>
  </doc>

let $results := if ($ascending) then
  $sorted
else
  fn:reverse($sorted)

return 
<GallicaPix db="{$corpus}">
<query>{$evalString}.</query>
<results hits="{$nResults}" start="{$start}" records="{$records}" sortedBy="{$sortBy}">{$results}</results>
</GallicaPix> 
};
 
declare function local:evalQuery($query) {
    let $hits := xquery:eval($query)
    return $hits
};


(: Construction de la page HTML
   HTML page creation :)
declare function local:createHTMLOutput($data) {

<html>
<head>
<link rel="stylesheet" type="text/css" href="/static/common.css"></link>
<link rel="stylesheet" type="text/css" href="/static/results.css"></link> 
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.css"></link>

<style> 
/* grille images mansory  */
#grid {{
   margin:5px;
   z-index: 0;
   padding-top: 0em;
 }}

.grid-item {{
  float: left;
 /* padding: 1px;*/
  width: 100px;
  height: 100px;
  border: 1px solid white;
 /* border-color: hsla(0, 0%, 0%, 0.5); */
    
}}

/* mode paysage */
.item-pg {{
  width: {xs:float($module)*400}px;
  height: {xs:float($module)*300}px;
}}
.item-pn {{
  width: {xs:float($module)*200}px;
  height: {xs:float($module)*150}px;
}}

/* mode vertical */
.item-vg {{
  width: {xs:float($module)*200}px;
  height: {xs:float($module)*300}px;
}}
.item-vn {{
  width: {xs:float($module)*100}px;
  height: {xs:float($module)*150}px;
}}

/* illustration horizontale très étroite */
.item-pe {{
  width: {xs:float($module)*200}px;
  height: {xs:float($module)*75}px;
}}

.grid-warn {{
  float: left;
  padding: 50px;
}}

/* affichage des crops */
/* objet  */
.item-obj {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 1px;
  border-style: solid;
  border-color: rgba(255,127,80, 0.6);
  background-color: rgba(255,127,80,0.25);  /* orange */
  border-radius: 3px;
}}

/* visage HOMME  */
.item-faceM {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 1px;
  border-style: solid;
  border-color: rgba(30,144,255, 0.6);
  background-color: {$coulFaceM}; 
  border-radius: 3px;
}}
/* visage FEMME  */
.item-faceF {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 1px;
  border-style: solid;
  border-color: rgba(255,192,203, 0.8);
  background-color: {$coulFaceF};
  border-radius: 3px;
}}
/* visage générique  */
.item-faceP {{
  position:absolute;
  padding: 1px;
  width:12px;
  height:12px;
  top: 3px;
  right: 3px;
  z-index:5;
  border-width: 1px;
  border-style: solid;
  border-color:rgba(160,110,110, 0.7);
  background-color: {$coulFaceP};  
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
  border-width: 1px;
  border-style: solid;
  border-color: rgba(255,165,0, 0.8);
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
  border-width:1px;
  border-style: dotted;
  border-color: rgba(220,220,220, 0.7);
  background-color: rgba(220,220,220, 0.2);  /* gris */
  border-radius: 3px;
}}

/* icones des PERSONNE */
/* NEUTRE */
.item-P:before{{
	content:'&#xf007;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size: {xs:float($module)*2+10}pt;
  /*color: rgba(132,65,157, 0.5);   violet */
   color: {$coulIconP};
}}
.item-P {{
  position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:5; 
}}
/* HOMME */
.item-M:before{{
	content:'&#xf183;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(30,144,255, 0.6);  /* bleu */
}}
.item-M {{
  position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:5; 
}}
/* FEMME */
.item-F:before{{
	content:'&#xf182;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(255,192,203, 0.8); 
}}
.item-F {{
  position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:5; 
}}
/* Mixte */
.item-Mixte:before{{
	content:'&#xf183;&#xf182;';
  padding-left:0px;
  padding-top:2px;
  font-weight: normal;
  font-size:{xs:float($module)*2+10}pt;
  color: rgba(110,110,110, 0.75); 
}}
.item-Mixte {{
  position:absolute;
  width:12px;
  height:12px;
  top: 8px;
  right: 8px;
  z-index:5; 
}}

/* Editer */
.item-edit:before{{
	content:'&#xf00c;';
  font-weight: normal;
  padding-left:1px;
  padding-top:-2px;
  font-size:9.5pt;
  color: rgba(154,205,50, 0.7);   /* vert */  
}}
.item-edit {{
  position:absolute; 
  width:13px;
  height:13px;
  top:8px;
  right:8px;
  z-index:8;
 /* background-color: rgba(60,179,113, 0.5); */
}}
.item-ocr:before{{
	content:'&#xf031;';
  font-weight: normal;
  padding-left:1px;
  padding-top:-2px;
  font-size:9.5pt;
  color: rgba(154,205,50, 0.7);   /* vert */  
}}
.item-ocr {{
  position:absolute; 
  width:13px;
  height:13px;
  top:8px;
  right:8px;
  z-index:8;
 /* background-color: rgba(60,179,113, 0.5); */
}}

/* filtre */
.item-filtre:before{{
	content:'&#xf00d;';
  font-weight: normal;
  padding-left:1px;
  padding-top:-2px;
  font-size:9.5pt;
  color: rgba(220, 20, 60, 0.8);   /* red */  
}}
.item-filtre {{
  position:absolute; 
  width:13px;
  height:13px;
  top:8px;
  right:8px;
  z-index:8;
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
.item-palette-30 {{
  position:absolute; 
  height:20px;
  bottom: 15px;
  left: 3px;
  z-index:2
}}
.item-palette-20 {{
  position:absolute; 
  height:15px;
  bottom: 15px;
  left: 3px;
  z-index:2; 
}}
.item-palette-10 {{
  position:absolute; 
  height:8px;
  bottom: 15px;
  left: 3px;
  z-index:2
}}
.item-source {{
  color: lightgrey;
  font-size: 8pt;
  font-family: sans-serif;
  z-index:2;
}}

/* menu flottant en bas des images */
ul li a {{
  font-size: {xs:float($module)*2+6}pt;
  
}}

ul.semantic li a {{
  font-size: {xs:float($module)*2+3}pt;
  height: 5pt
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
  margin-top: 5px;
  margin-left: 0px; 
  position: relative;
  z-index: 9;
  width: {if ($debug) then (340+xs:float($module)*50) else (100+xs:float($module)*50)}px;
}}

/* menu pour les objets - objects menu */
.menu-tipv{{
  width: { (10+xs:float($module)*40)}px;
  font-size: {xs:float($module)*2+8}pt;
  margin-top: -40px;
  margin-left: 5px;
  position: relative;
  background-color: rgba(185,165,165,0.4);  
  z-index: 10;
}}

.txt {{
  display: block;
   font-size: 7pt;
   font-family: sans-serif;
   line-height: 1.3;
   padding-top: 4px;
   color: white     
}}

.txtlight {{
   font-size: {xs:float($module)*1.5+4}pt;
   font-family: sans-serif;
   line-height: 1.2;
   color: rgba(255,255,255, 0.6)     
}}
</style>

 <!-- Construction de la page HTML -->
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>Gallica : Recherche d&#x27;illustrations</title>

</head>
<body id="body">
{
 
let $evalString := local:createQuery($data)

(: pour ne pas executer la requete :) 
(: let $hits := ()  :)
 let $hits := local:evalQuery($evalString) 
let $nResults := count($hits) 
let $start := 
      if ($action="&#xf104;") (: previous page :)
      then max(($start - $nResults, 1))
      else if ($action="&#xf105;")  (: next page:)
      then  if ($nResults < $start + $records)
            then $start
            else $start + $records
      else if ($action="first" or $action="&#xf100;" )
      then 1
      else if ($action="&#xf101;") (: last page:)
      then ($nResults - $records)
      else max(($start - $records, 1))


let $end :=  min (($start + $records -1, $nResults)) 
let $subhits :=  subsequence($hits,$start,$records) 
let $ascending := if (($order=0) or ($order=2)) then (fn:true()) else (fn:false())
let $sortBy := if (($order=0) or ($order=1)) then ("date") else ("size")    
    
let $sorted := 
  for $i in $subhits
  order by
    if ($sortBy eq "date") then 
      $i/../../../../../metad/dateEdition
    else if ($sortBy eq "size") then 
      number($i/@h * $i/@w) 
    else 
      ()
  return $i

let $itemsSorted := if ($ascending) then
  $sorted
else
  fn:reverse($sorted)
  
let $nbIlls := count($itemsSorted)    

return
<div id="top">
<form id="formulaire"  class="form" action="/rest?" method="get">
   <!-- transmettre les parametres issus du formulaire de recherche -->
   <input type="hidden" name="run" value="findIllustrations-app.xq"></input>
   <input type="hidden" name="keyword" value="{$keyword}"/>
   <input type="hidden" name="kwTarget" value="{$kwTarget}"/>
   <input type="hidden" name="sourceTarget" value="{$sourceTarget}"/>
   <input type="hidden" name="kwMode" value="{$kwMode}"/>
   <input type="hidden" name="title" value="{$title}"/>
   <input type="hidden" name="fromDate" value="{$fromDate}"/>
   <input type="hidden" name="toDate" value="{$toDate}"/>
   <input type="hidden" name="sup" value="{$special}"/>
   <input type="hidden" name="page" value="{$page}"/>
    <input type="hidden" name="iptc" value="{$iptc}"/>
   <input type="hidden" name="size" value="{$size}"/>
   <input type="hidden" name="density" value="{$density}"/>
   <input type="hidden" name="filter" value="{$filter}"/>
   <input type="hidden" name="ad" value="{$ad}"/>
   <input type="hidden" name="illAd" value="{$illAd}"/>
   <input type="hidden" name="corpus" value="{$corpus}"/>
   <input type="hidden" name="corpus" value="{$corpus}"/>
 <!--   <input type="hidden" name="person" value="{$person}"/> -->
 <!--   <input type="hidden" name="persType" value="{$persType}"/> -->
   <input type="hidden" name="colName" value="{$colName}"/>
   <input type="hidden" name="classif1" value="{$classif1}"/>
   <input type="hidden" name="classif2" value="{$classif2}"/>
   <input type="hidden" name="operator" value="{$operator}"/>
   <input type="hidden" name="CBIR" value="{$CBIR}"/> 
<!--  <input type="hidden" name="CS" value="{$CS}"/> --> 
   <input type="hidden" name="start" value="{$start}"/>
   <input type="hidden" name="locale" value="{$locale}"/>
   <input type="hidden" name="author" value="{$author}"/>
   <input type="hidden" name="publisher" value="{$publisher}"/>
    
  
<div id="formulaireMasque" class="formMasque couleurSecond" style="display:none">
  <div class="champ" style="margin-left:15em">
   <label><small>max</small> </label>
    <input id="ipnumber" class="couleurSecond" type="number" min="1" max="{$maxRecords}" name="records" value="{$records}"/>
    </div>    
  

&#8193;&#8193; 
<input id="selectTypeP" type="checkbox" name="typeP" value="P"></input><label lang="fr">Presse</label><label lang="en">News</label> 
  <input id="selectTypeR" type="checkbox" name="typeR" value="R"></input><label lang="fr">Revue</label><label lang="en">Journal</label>
<input id="selectTypeM" type="checkbox" name="typeM" value="M"></input><label lang="fr">Monog.</label><label lang="en">Monog.</label>
<input id="selectTypeA" type="checkbox" name="typeA" value="A"></input><label lang="fr">Manus.</label><label lang="en">Manus.</label>
   <input id="selectTypeI" type="checkbox" name="typeI" value="I"></input><label >Image</label>
&#8193;&#8193;
    <span style="font-size:8pt;" class="fa">&#xf1c5;</span>
     <select name="illType" id="selectGenre" class="couleurSecond" title="Genre">
      <option lang="fr" value=""> </option>
      <option lang="fr" value="affiche">affiche</option><option lang="en" value="poster">poster</option>
      <option lang="fr" value="bd">bd</option><option lang="en" value="bd">comics</option>
      <option lang="fr" value="carte">carte</option><option lang="en" value="carte">map</option>
      <option lang="fr" value="dessin">dessin</option><option lang="en" value="dessin">drawing</option>
      <option lang="fr" value="graphique">graphique</option><option lang="en" value="graphique">graph</option>
      <option lang="fr" value="gravure">gravure</option><option lang="en" value="gravure">engraving</option>
      <option lang="fr" value="manuscrit">texte</option><option lang="en" value="manuscrit">text</option>
      <option lang="fr" value="partition">partition</option><option lang="en" value="partition">music</option>
      <option lang="fr" value="photog">photograv.</option> <option lang="en" value="photog">photoengr.</option>
      <option lang="fr" value="photo">photo</option><option lang="en" value="photo">photo</option>
       {if ($TNA) then (<option value="textile">textile</option>)}
      <option lang="fr" value="none">inconnu</option><option lang="en" value="none">unknown</option>
   </select>
     &#8193;
   
     <span style="font-size:8pt;" class="fa">&#xf043;</span>
   <select name="color" id="selectCouleur" title="Couleur" class="couleurSecond">
    <option value=""> </option>
    <option lang="fr" value="gris">N&amp;B</option><option lang="en" value="gris">B&amp;W</option>
    <option lang="fr" value="mono">monoch.</option><option lang="en" value="mono">monochr.</option>
    <option lang="fr" value="coul">coul.</option><option lang="en" value="coul">color</option>
   </select>
     &#8193;
 
 <span style="font-size:8pt;" class="fa">&#xf2c0;</span>
    <select name="persType" id="persType" title="Personne" class="couleurSecond">
    <option value="00" selected="" > </option>
    <option  lang="fr" value="person">Personne</option><option  lang="en" value="person">Person</option>
    <option  lang="fr" value="personW">Femme</option><option  lang="en" value="personW">Woman</option>
   <option  lang="fr" value="personM">Homme</option> <option  lang="en" value="personM">Man</option> 
   <option  lang="fr" value="child">Enfant</option><option  lang="en" value="child">Child</option>
    <option  lang="fr" value="soldier">Soldat</option><option lang="en" value="soldier" >Soldier</option>
     <option  lang="fr" value="face">Visage</option><option lang="en" value="face" >Face</option>
     <option  lang="fr" value="faceW">Visage (F)</option><option lang="en" value="faceW" >Face (W)</option>
      <option  lang="fr" value="faceM">Visage (M)</option><option lang="en" value="faceM" >Face (M)</option>
   </select> &#8193;
   
    <span style="font-size:8pt;" class="fa">&#xf160;</span>
   <select name="order"  id="selectOrdre" title="Tri" class="couleurSecond">
   <option lang="fr" value="0">date croiss.</option><option lang="en" value="0">asc. date</option>
     <option lang="fr" value="1">date décr.</option> <option lang="en" value="1">desc. date</option>
      <option lang="fr" value="2">taille croiss.</option><option lang="en" value="2">asc. size</option>
       <option lang="fr" value="3">taille décr.</option><option lang="en" value="3">desc. size</option>
   </select>&#8193;&#8193;

  
 
 <label>Conf.</label>
 <select  name="CS" id="CS" class="couleurSecond">
    <option  value="0">0%</option>  
    <option  value="0.25">25%</option>  
    <option value="0.5">50%</option>
    <option value="0.75">75%</option>
    <option value="1">100%</option>
 </select> &#8193;
 
  <span style="font-size:8pt;" class="fa">&#xf065;</span>
     <select name="module" id="selectTaille" title="Vignette" class="couleurSecond">   
     <option  value="0.5">S</option>
      <option  value="1">M</option>
     <option value="1.5">L</option>
   </select>
  
<!-- similarity search  -->   
<input type="text" name="similarity" id="similarity" hidden="true"></input>
<input type="text" name="rValue" id="rValue" hidden="true"></input>
<input type="text" name="gValue" id="gValue" hidden="true"></input>
<input type="text" name="bValue" id="bValue" hidden="true"></input>
<input type="text" name="bkgColor" id="bkgColor" hidden="true"></input>
    
 &#8193; &#8193;
 
<!-- bouton Submit -->  
<input type="submit" class="button fa" name="action" title="Submit" value="&#xf1c0;"></input>
&#8193;   

 <!-- dépliement de la zone Info -->
<div class="information"><a  title="Information" class="fa fa-info-circle" style="font-size:12pt" href="javascript:showhide('infoContent')"></a></div>
<div id="infoContent" style="display:none;">
<hr align="left" size="2"  noshade="" ></hr>
<h3><span lang="fr">
Pour modifier le nombre maximum d&#x27;illustrations d&#x27;une page de résultats, utiliser le champ <b>max</b>.
Les flèches &#9664; et &#9654; permettent de naviguer de page en page.
Pour changer la taille d&#x27;affichage des vignettes, utiliser le menu <span class="fa">&#xf065;</span>.
Le menu CS permet de choisir le seuil de confiance de  l&#x27;indexation automatique (90% = plus de précision des résultats, mais en moins grand nombre).

<br></br> 
Le bouton <span class="fa">&#xf1c0;</span> permet d&#x27;appliquer les facettes sélectionnées (collection, genre, couleur...)<br></br>
Le volet de gauche affiche les genres, les périodes temporelles et l&#x27;indexation sémantique relatives aux illustrations affichées dans la page courante (et non à toutes les illustrations de la liste de résultats). 
 
<br></br> <br></br>
Au survol d&#x27;une vignette, un bouton <i>i</i> permet d&#x27;afficher les métadonnées et le texte associé à chaque illustration et 
 un menu  donne accès à plusieurs fonctions :<br></br>
 
<b>Diffuser</b> : <span class="fa">&#xf082;</span> publication de la vignette de l&#x27;illustration sur Facebook &#8193; <span class="fa">&#xf1fa;</span> envoi par courriel &#8193; <span class="fa">&#xf03e;</span> accès à l&#x27;image de l&#x27;illustration dans une fenêtre web &#8193;  <span class="fa">&#xf121;</span> export des métadonnées de l&#x27;illustration<br></br>



{ if ($debug=1) then (
<div>
<b>Corriger les métadonnées</b> :  <span class="fa">&#xf044;</span> édition des métadonnées de classification de l&#x27;illustration : thème, genre, OCR, présence de personnes &#8193; <span class="fa">&#xf01e;</span> angle de rotation &#8193; <span class="fa">&#xf125;</span> demande de segmentation de l&#x27;illustration<br></br> 

<b>Filtrer</b> : <span class="fa">&#xf01e;</span> signaler un défaut d&#x27;orientation  &#8193; <span class="fa">&#xf014;</span>  supprimer une image qui n&#x27;est pas une illustration &#8193; <span class="fa">&#xf217;</span> signaler une publicité illustrée  <br></br>
</div>)
else (<div><b>Signaler</b> :<span class="fa">&#xf125;</span> signaler un défaut de segmentation de l&#x27;illustration &#8193; <span class="fa">&#xf014;</span> &#8193; signaler une image qui n&#x27;est pas une illustration &#8193; <span class="fa">&#xf217;</span> signaler une publicité illustrée  <br></br>
</div>)}

    
<b>Rechercher</b> :  <span class="fa">&#xf016;</span> afficher les illustrations de la même page
&#8193; <span class="fa">&#xf0c5;</span> afficher toutes les illustrations du document &#8193; <span class="fa">&#xf002;</span> chercher des illustrations similaires<br></br>

<!-- Debug : <input type="checkbox" name="debug" value="1"></input> -->


<b>data.bnf</b> : quand il existe, lien  vers une page de data.bnf.fr consacrée au document<br></br><br></br>

<b>Reconnaissance visuelle</b>: <input type="checkbox" name="display" id="selectDisplay" value="1"></input> 
affiche les icones de classification et les emprises au sein de l&#x27;image (quand elles sont disponibles).<br></br> 
Les genres sont indiqués sur les visages (F : femme, M : homme, P : inconnu).<br></br>
Une icône <span class="fa">&#xf007;</span> indique que l&#x27;illustration contient la représentation d&#x27;une ou plusieurs personnes ; une icône <span class="fa">&#xf182;</span> pour une femme ;  <span class="fa">&#xf183;</span> pour un homme ; <span class="fa">&#xf1ae;</span> pour un enfant.
<br></br>
Les classes, les sources d&#x27;indexation et les indices de confiances sont également présentés : <br></br>
- IBM : API Watson Visual Recognition API<br></br>
- Google : API Google Cloud Vision API<br></br>
- dnn : modèle MobileNetSSD (module OpenCV/dnn) <br></br>
- Yolo : Yolo v3   <br></br>

Le seuil de confiance des données de classification  peut être paramétré dans le formulaire de recherche (20%-90%).
 
<br></br><br></br>

<!-- 
<b>Crowdsourcing</b> : <input type="checkbox" id="selectCrowd" name="crowd" value="1"></input> affiche les icones de crowdsourcing
<br></br>
Dans le coin supérieur droit, une icône <span class="fa">&#xf00c;</span> indique que l&#x27;illustration a déjà été éditée ; une icône  <span class="fa">&#xf046;</span> qu&#x27;une demande de segmentation a été faite ; une icône  <span class="fa">&#xf031;</span> que l&#x27;OCR a été corrigé  <br></br>
<br></br>
 -->
 
<!-- Afficher les illustrations non classifiées (pour le genre : photo, dessin, etc.) 
<input type="checkbox" name="illType" ></input>  value="null" -->
 </span>
</h3>

<h3><span lang="en">To change the maximum number of results displayed per page, use the  <b>max</b> field.
The arrows &#9664; and &#9654; are used to navigate from page to page. <br></br>
To change the thumbnail display size, use the  <span class="fa">&#xf065;</span> menu.<br></br>
The button  <span class="fa">&#xf1c0;</span> allows you to apply the selected facets (collection, genre, color...) <br></br>
The left pane displays the types, time periods and semantic indexing related to the illustrations displayed on the current page (and not to all illustrations in the results list).<br></br><br></br>

When hovering over a thumbnail, a button <i>i</i> displays the metadata and text associated with each illustration, and 
 a menu gives access to several functions:<br></br>
<b>Share</b> : <span class="fa">&#xf082;</span> Publishing the thumbnail of the illustration on Facebook &#8193; <span class="fa">&#xf082;</span> Sending the thumbnail by email &#8193;  <span class="fa">&#xf082;</span> Export the thumbnail to a web window for later Save as &#8193; <span class="fa">&#xf082;</span> export the illustration metadata <br></br>

{ if ($debug=1) then (
<div>
<b>Correct</b> :  <span class="fa">&#xf044;</span> Collaborative editing of some illustration metadata: theme, genre, person &#8193; <span class="fa">&#xf01e;</span> Fix the rotation &#8193; <span class="fa">&#xf125;</span> Ask for illustration segmentation<br></br> 

<b>Filter</b> : <span class="fa">&#xf01e;</span> report an orientation defect  &#8193; <span class="fa">&#xf014;</span>  report an image which is not an illustration &#8193; <span class="fa">&#xf217;</span> report an illustrated ad  <br></br>
</div>)
else (<div><b>Report</b> :<span class="fa">&#xf125;</span> report a segmentation defect &#8193; <span class="fa">&#xf01e;</span> report an orientation defect  &#8193; <span class="fa">&#xf014;</span> report an image which is not an illustration &#8193; <span class="fa">&#xf217;</span> report an illustrated ad <br></br>
</div>)}


<b>Search</b> :  <span class="fa">&#xf016;</span> Display all the  illustrations on the same  page
&#8193; <span class="fa">&#xf0c5;</span> Display all the document illustrations &#8193;  <br></br>

<!-- <span class="fa">&#xf002;</span> look for similar  illustrations -->
     
<b>data.bnf</b>: Link to a page of data.bnf.fr related to the illustration, if exists <br></br><br></br>

<b>Visual Recognition</b>: <input type="checkbox" name="display" id="selectDisplay" value="1"></input> Display the classification icons  and the croppings (if exists). <br></br>
Genres are displayed on the faces (F: woman, H: man, P: unknown).<br></br>

The  <span class="fa">&#xf007;</span> icon indicates that the &#x27;illustration contains the representation of one or more persons;  <span class="fa">&#xf182;</span> icon for a woman;  <span class="fa">&#xf183;</span> for a man;  <span class="fa">&#xf1ae;</span> for a child. <br></br>

Tags, source of indexing and confidence score are also presented: <br></br>
- IBM: Watson Visual Recognition API<br></br>
- Google: Google Cloud Vision API<br></br>
- dnn: MobileNetSSD model (OpenCV/dnn module) <br></br>
- Yolo: Yolo v3   <br></br>

A confidence score filter can be applied to the classification data.
  <br></br>

<!--
<b>Crowdsourcing</b>: In the upper right corner, an icon <span class="fa">&#xf00c; </span> indicates that the illustration has already been edited; &#8193; <span class="fa">&#xf046; </span> that a request for cropping has been made; <br></br> <span class="fa">&#xf031;</span>  that the OCR has been corrected  <br></br>
-->
</span>
</h3>


<h3><b><span lang="fr">Requête XQuery</span><span lang="en">XQuery request</span></b> : <span style="font-family:Monospace;font-size:9pt">{data($evalString)}</span>
<hr align="left" size="1"  noshade="" ></hr>
</h3>
</div>
 
<iframe style="height:80px;width:300px;float:right" name="ligneAff" frameborder="0" src="">
  <p>Erreur : votre navigateur ne supporte pas les iframe !</p>
</iframe>

</div>

<div id="showForm" >

<a class="fa couleurSecond" style="font-size:18px;vertical-align:middle" title="Home"  href="/rest?run=findIllustrations-form.xq&amp;locale={$locale}">&#xf015;</a>
<input title="page 0" style="margin-right:-8px" type="submit" class="buttonPages fa couleurSecond" name="action" 
value="&#xf100;"/>
<input  title="page-" type="submit" class="buttonPages fa couleurSecond" name="action" value="&#xf104;"/><span class="couleurSecond" style="margin-left:-5px;vertical-align:middle;font-size:10px;font-family:sans-serif;">{data($start)}-{data($end)}/{data($nResults)}</span>
<input  title="page+" style="margin-left:-5px" type="submit" class="buttonPages fa couleurSecond" name="action"  value="&#xf105;"/>
<input title="dernière page" style="margin-left:-8px" type="submit" class="buttonPages fa couleurSecond" name="action"  value="&#xf101;"/>
<a class="fa fa-plus-circle" title="Menu" style="font-size:18px;vertical-align:middle" href="javascript:showhide('formulaireMasque');javascript:showhide('classification')"></a>
</div>
</form>
 
 
<!-- onglet de classification --> 
<div id="classification"  class="form" style="display:none">

<span class="fa iconClassif">&#xf1c5;</span>

<!-- boutons Genres -->
<div class="button-groupClassif button-groupGenres filters-button-group">
<button id="tout_fr" title="Tout" lang="fr" class="fa button buttonClassif" style="font-size:7pt" data-filter="*">&#xf0e2;</button>
<button id="tout_en" title="All" lang="en" class="fa button buttonClassif" style="font-size:7pt" data-filter="*">&#xf0e2;</button>
<button id="g1" class="button buttonClassif" data-filter=""></button>
<button id="g2" class="button buttonClassif" data-filter=""></button>
<button id="g3" class="button buttonClassif" data-filter=""></button>
<button id="g4" class="button buttonClassif" data-filter=""></button>
<button id="g5" class="button buttonClassif" data-filter=""></button>
<button id="g6" class="button buttonClassif" data-filter=""></button>
<button id="g7" class="button buttonClassif" data-filter=""></button>
<button id="g8" class="button buttonClassif" data-filter=""></button>
<button id="g9" class="button buttonClassif" data-filter=""></button>
<button id="g10" class="button buttonClassif" data-filter=""></button>
<button id="g11" class="button buttonClassif" data-filter=""></button>
<button id="g12" class="button buttonClassif" data-filter=""></button>
<button id="g13" class="button buttonClassif" data-filter=""></button>
<button id="g14" class="button buttonClassif" data-filter=""></button>
<button id="g15" class="button buttonClassif" data-filter=""></button>
</div>

<!-- boutons Periodes -->
<span class="fa iconClassif">&#xf017;</span>
<div class="button-groupClassif button-groupDates filters-button-group">
<button id="d1" class="button buttonClassif" data-filter=""></button>
<button id="d2" class="button buttonClassif" data-filter=""></button>
<button id="d3" class="button buttonClassif" data-filter=""></button>
<button id="d4" class="button buttonClassif" data-filter=""></button>
<button id="d5" class="button buttonClassif" data-filter=""></button>
</div>

<!-- boutons Classes -->
<span class="fa iconClassif">&#xf1c9;</span>
<div class="button-groupClassif button-groupClasses filters-button-group">
<!-- <button id="ctout" class="button buttonClassif is-checked" data-filter="*">x</button> -->
<button id="c1" class="button buttonClassif" data-filter=""></button>
<button id="c2" class="button buttonClassif" data-filter=""></button>
<button id="c3" class="button buttonClassif" data-filter=""></button>
<button id="c4" class="button buttonClassif" data-filter=""></button>
<button id="c5" class="button buttonClassif" data-filter=""></button>
<button id="c6" class="button buttonClassif" data-filter=""></button>
<button id="c7" class="button buttonClassif" data-filter=""></button>
<button id="c8" class="button buttonClassif" data-filter=""></button>
<button id="c9" class="button buttonClassif" data-filter=""></button>
<button id="c10" class="button buttonClassif" data-filter=""></button>
<button id="c11" class="button buttonClassif" data-filter=""></button>
<button id="c12" class="button buttonClassif" data-filter=""></button>
<button id="c13" class="button buttonClassif" data-filter=""></button>
<button id="c14" class="button buttonClassif" data-filter=""></button>
<button id="c15" class="button buttonClassif" data-filter=""></button>
<button id="c16" class="button buttonClassif" data-filter=""></button>
<button id="c17" class="button buttonClassif" data-filter=""></button>
<button id="c18" class="button buttonClassif" data-filter=""></button>
<button id="c19" class="button buttonClassif" data-filter=""></button>
<button id="c20" class="button buttonClassif" data-filter=""></button>
<button id="c21" class="button buttonClassif" data-filter=""></button>
<button id="c22" class="button buttonClassif" data-filter=""></button>
<button id="c23" class="button buttonClassif" data-filter=""></button>
<button id="c24" class="button buttonClassif" data-filter=""></button>
<button id="c25" class="button buttonClassif" data-filter=""></button>
<button id="c26" class="button buttonClassif" data-filter=""></button>
<button id="c27" class="button buttonClassif" data-filter=""></button>
<button id="c28" class="button buttonClassif" data-filter=""></button>
<button id="c29" class="button buttonClassif" data-filter=""></button>
<button id="c30" class="button buttonClassif" data-filter=""></button>
<button id="c31" class="button buttonClassif" data-filter=""></button>
<button id="c32" class="button buttonClassif" data-filter=""></button>
<button id="c33" class="button buttonClassif" data-filter=""></button>
<button id="c34" class="button buttonClassif" data-filter=""></button>
<button id="c35" class="button buttonClassif" data-filter=""></button>
<button id="c36" class="button buttonClassif" data-filter=""></button>
<button id="c37" class="button buttonClassif" data-filter=""></button>
<button id="c38" class="button buttonClassif" data-filter=""></button>
<button id="c39" class="button buttonClassif" data-filter=""></button>
<button id="c40" class="button buttonClassif" data-filter=""></button>
<button id="c41" class="button buttonClassif" data-filter=""></button>
<button id="c42" class="button buttonClassif" data-filter=""></button>
<button id="c43" class="button buttonClassif" data-filter=""></button>
<button id="c44" class="button buttonClassif" data-filter=""></button>
<button id="c45" class="button buttonClassif" data-filter=""></button>
<button id="c46" class="button buttonClassif" data-filter=""></button>
<button id="c47" class="button buttonClassif" data-filter=""></button>
<button id="c48" class="button buttonClassif" data-filter=""></button>
<button id="c49" class="button buttonClassif" data-filter=""></button>
<button id="c50" class="button buttonClassif" data-filter=""></button>
<button id="c51" class="button buttonClassif" data-filter=""></button>
<button id="c52" class="button buttonClassif" data-filter=""></button>
<button id="c53" class="button buttonClassif" data-filter=""></button>
<button id="c54" class="button buttonClassif" data-filter=""></button>
<button id="c55" class="button buttonClassif" data-filter=""></button>
<button id="c56" class="button buttonClassif" data-filter=""></button>
<button id="c57" class="button buttonClassif" data-filter=""></button>
<button id="c58" class="button buttonClassif" data-filter=""></button>
<button id="c59" class="button buttonClassif" data-filter=""></button>
<button id="c60" class="button buttonClassif" data-filter=""></button>
<button id="c61" class="button buttonClassif" data-filter=""></button>
<button id="c62" class="button buttonClassif" data-filter=""></button>
<button id="c63" class="button buttonClassif" data-filter=""></button>
<button id="c64" class="button buttonClassif" data-filter=""></button>
<button id="c65" class="button buttonClassif" data-filter=""></button>
<button id="c66" class="button buttonClassif" data-filter=""></button>
<button id="c67" class="button buttonClassif" data-filter=""></button>
<button id="c68" class="button buttonClassif" data-filter=""></button>
<button id="c69" class="button buttonClassif" data-filter=""></button>
<button id="c70" class="button buttonClassif" data-filter=""></button>
<button id="c71" class="button buttonClassif" data-filter=""></button>
<button id="c72" class="button buttonClassif" data-filter=""></button>
<button id="c73" class="button buttonClassif" data-filter=""></button>
<button id="c74" class="button buttonClassif" data-filter=""></button>
<button id="c75" class="button buttonClassif" data-filter=""></button>
 </div>
<button id="moreClasses" title="+" style="margin-left: 5px;" class="button buttonClassif">...</button>  
</div>

<div id="grid">
 { 
  if ($itemsSorted) then
     
 for $ill at $counter in $itemsSorted  
    let $metad :=  $ill/../../../../../metad 
    let $id := $metad/ID    (: document ID :)
    let $n := $ill/@n (: illustration ID :)
    let $source := $metad/source 
    let $sourceAlias := if ($source and matches($source,"France")) then ("BnF") else ($source) 
    let $descr := $metad/descr    
    let $nbPages := $metad/nbPage
    let $iiif := $ill/../../../../../@iiif
    let $urlIIIFexterne := $metad/urlIIIF
    let $npage := if ($urlIIIFexterne) then (1) (: other DLs:  we only handle one page documents :)
                  else($ill/../../@ordre) (:  Gallica qualifier for page number :) 
    let $URLiiif := if ($urlIIIFexterne) then ($urlIIIFexterne) 
                    else (concat("https://gallica.bnf.fr/iiif/ark:/12148/",$id,"/f",$npage,"/")) (: default is Gallica :)    
    let $filtre := $ill/@filtre
    let $date := $metad/dateEdition
    let $annee := fn:head(fn:tokenize($date, '\-'))
    let $periode := if (functx:is-a-number($annee)) then (
      let $tmp := fn:round(fn:number($annee)) return
      if ($tmp<500) then ("antiquite") else 
      if ($tmp<1500) then ("moyen_age") else
      if ($tmp<1789) then ("moderne") else
      if ($tmp>=1789) then ("contemporain") 
      else ("inconnu") 
    ) else ('inconnu')
    
    (: éviter les pb ensuite avec les '   :)
    let $titre := replace($metad/titre,'''','&#8217;')  (: convertir les ' pour pouvoir passer en argument dans la fonction JS edit() :)
    let $auteur := $metad/auteur 
    let $editeur := $metad/editeur 
    let $titraille :=  replace($ill/titraille,'''','&#8217;')
    let $legende :=  replace($ill/leg,'''','&#8217;')  
    let $texte :=  replace($ill/txt,'''','&#8217;')    
    (: $ill/../../fn:count(preceding-sibling::page) + 1 :)   
    (: document source - source document :)
    let $urlDoc := if ($iiif) (: if @iiif is set, it implies @iiif=false (retrocompatibility issue) :)  
                   then (concat($dossierLocal,$metad/fichier,"-",$n,".jpg")) 
                   else if ($urlIIIFexterne) then ($metad/url) (: other IIIF compliant DLs :)
                   else ( concat("https://gallica.bnf.fr/ark:/12148/",$id,"/f",$npage,".item")) (: Gallica :) 
    (: image thumbnail to be displayed in the mosaic :) 
    let $urlThumb := if ($iiif) then (if ($module=0.5) then (
                    concat($dossierLocal,"_",$metad/fichier,"-",$n,".jpg")) else (  (: 2 thumbnail sets:)
                     concat($dossierLocal,"__",$metad/fichier,"-",$n,".jpg") )) 
                    else concat("https://gallica.bnf.fr/ark:/12148/",$id,"/f",$npage,".thumbnail") 
    (: color palettes :)                
    let $urlPalette :=  concat($dossierLocal,"palettes20/",$id,"-",$n,"_palette.png")
                                                  
    (: rotation de l'image :)
    let $rotation := if ($ill/@rotation) (: and (xs:integer($ill/@h) > xs:integer($ill/@w))) :)
      then ($ill/@rotation) else (0)
    (: largeur et '{$titraille}',hauteur de l'illustration à l'affichage en fonction de la rotation :)
    let $largIll := if ($ill/@rotation) then (xs:integer($ill/@h)) else (xs:integer($ill/@w))
    let $hautIll := if ($ill/@rotation) then (xs:integer($ill/@w)) else (xs:integer($ill/@h))
    (: paysage ou vertical :)
    let $orientation := if ($largIll > $hautIll) then (
     "p" ) else ( "v" )

     (: let $larg := $ill/@w div 6  pour garder la proportion de taille des images :)
     (: let $largMax := if ($larg gt 200) then (200) else ($larg)  pour ne pas dépasser la largeur de colonne de la grille :)
     let $codeTheme := $ill/theme[@source=$sourceData]
     let $theme :=
     switch ( $codeTheme )
       case "01" return "Arts, culture"
       case "02" return "Criminalité, droit et justice"
       case "03" return "Désastres et accidents"
       case "04" return "Economie et finances"
       case "05" return "Education"
       case "06" return "Environnement"
       case "07" return "Santé"
       case "08" return "Gens animaux insolite"
       case "09" return "Social, Monde du travail"
       case "10" return "Vie quotidienne et loisirs"
       case "11" return "Politique"
       case "12" return "Religion et croyance"
       case "13" return "Science et technologie"
       case "14" return "Société"
       case "15" return "Sport"
       case "16" return "Conflits, guerres et paix"
       default return "inconnu"
    (: colors with hex values :)   
    let $couleursHex := $ill/contenuImg[@source='colorific']  
    (: named colors :)
    let $couleursNoms := if ($CBIRsource) then ($ill/contenuImg[@coul and @source=$CBIR and @lang=$locale]) else ($ill/contenuImg[@coul and @lang=$locale])
    let $listeCouleursNoms := fn:string-join($couleursNoms, ', ') (: concatener les classes :)
    (: tags other than colors :) 
    let $classesNoms := if ($CBIRsource) then ($ill/contenuImg[not(@coul) and @lang=$locale and @CS>=$CS ]) else ($ill/contenuImg[not(@coul) and @lang=$locale  and @CS>=$CS]) 
    let $listeClassesNoms := fn:string-join($classesNoms, ', ') 
    let $tmp := replace($listeClassesNoms,' ','_') (: remplacer l'espace intraclasse par un -:)
    let $tmp := replace($tmp,'''','_') (: idem pour apostrophe :)
    let $tmp := replace($tmp,'/','_')
    let $tmp := replace($tmp,'\(','') (: css names can t include () :)
    let $tmp := replace($tmp,'\)','')
    let $tmp := replace($tmp,',_',' _') (: ajouter un _ au début de chq classe :)
    let $listeClassesNoms := if ($listeClassesNoms) then (concat ("_", $tmp)) (: classes CSS :) else ()
    let $tmp := replace($listeCouleursNoms,' ','_') (: remplacer l'espace intraclasse par un -:)
    let $tmp := replace($tmp,'''','_')
    let $tmp := replace($tmp,'\(','') (: css names can t include () :)
    let $tmp := replace($tmp,'\)','')
    let $tmp := replace($tmp,',_',' -') (: ajouter un - au début de chq classe couleur :)
    let $listeCouleursNoms := if ($listeCouleursNoms) then (concat ("-", $tmp))  else () 
    let $databnf :=  $ill/@databnf
    let $segment :=  $ill/@seg
    let $genresVsg := if ($CBIRsource) then (fn:string-join( $ill/contenuImg[@source=$CBIR and text()=$faceClass]/@sexe,' '))
                      else (fn:string-join( $ill/contenuImg[text()=$faceClass]/@sexe,' ')) 
    
    let $vgs := if ($CBIRsource) then ($ill/contenuImg[@source=$CBIR and text()=$faceClass]) else 
                   ($ill/contenuImg[text()=$faceClass])
    let $nVisages :=  if ($vgs) then (count($vgs)) else (0)  
    let $genresPersonnes :=  
     if ($listeClassesNoms) then (    (:  classification de sexe via les classes, on utilise les classes :)
       functx:gender($listeClassesNoms,'classes')
       )
     else ()
     (: (functx:gender($genresVsg,'faces')) :) (: on utilise les visages :)
    (: genre des illustrations : photo, gravure, dessin... :)      
    let $tmp := $ill/genre[@source=$sourceData]   
    let $genre := if ($tmp) then (fn:string-join($tmp, ' ')) else ("inconnu")    
    let $couleur := $ill/@couleur
    let $taille := number($ill/@taille)
    let $coll := $ill/../../../../../metad/type 	(: collection source du document : image, presse, etc. :)
    let $nomColl := if ($locale='fr') then (switch($coll)
     case "M" return "monographie"
     case "A" return "manuscrit"
     case "I" return "image"
     case "PA" return "partition"
     case "C" return "carte"
     case "P" return "presse"
     case "R" return "revue"
     default return "inconnu")
     else (
       switch($coll)
     case "M" return "monography"
     case "A" return "manuscript"
      case "I" return "image"
     case "PA" return "music score"
     case "C" return "map"
     case "P" return "newspaper"
     case "R" return "journal"
     default return "unknown"
     )
    let $lPage :=  xs:integer($ill/../../../../largeurPx)
    let $hPage :=  xs:integer($ill/../../../../hauteurPx)
    let $ratioIll :=  ($largIll *  $hautIll) div ( $lPage * $hPage) 
    
    (: taille d'affichage de l'illustration :)
    let $tailleIll :=  if ($counter = 1) then 
      ("n") (: first item must be a small one in Mansory grid. Bug? :)
      else (if ($largIll > ($hautIll*2)) then (
       "e")  (: illustration horizontale  étroite :)
      else (if (($coll="I") (: privilegier les images :)
            or ($largIll>$seuilGrand or $hautIll> $seuilGrand)) (: privilegier les grandes illustrations :)
      then ("g")  (: grande illustration :)
      else ("n"))) (: illustration normale :)

    (: calcul de la taille de la div qui va accueillir l'illustration :)
    let $largeur := if ($orientation="p") then ( (: mode paysage pour afficher l'illustration :)
      if ($tailleIll="g") then (xs:float($module)*400)
               else (xs:float($module)*200))
      else ( if ($tailleIll="g") then (xs:float($module)*200)
               else (xs:float($module)*100))

    let $hauteur := if ($orientation="p") then ( 	(: mode paysage  :)
      if ($tailleIll="g") then (xs:float($module)*300)
                     else (xs:float($module)*150))
      else ( if ($tailleIll="g") then (xs:float($module)*300)  	(: mode portrait pour afficher l'illustration :)
           else (xs:float($module)*150))

    let $iiifL := if ($rotation=0) then ($largeur) else ($hauteur)
    let $iiifH := if ($rotation=0) then ($hauteur) else ($largeur)
    (: composition de l'appel IIIF :)  
    let $imgFormat := if ($urlIIIFexterne) then ("/default.jpg") (: hack for Welcome Library :)
             else ("/native.jpg") (: gallica case :)
    let $iiifFinal :=   concat( $URLiiif,$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h,"/!",$iiifL,",",$iiifH,"/",$rotation,$imgFormat)
(:    let $thumbnail :=   concat( $URLiiif,$id,$np,"/",$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h,"/400,/",$rotation,$imgFormat) :)
      
    (: optimization  
    let $url := if (($thumbDisplay) and ($ratioIll>0.8)) then ($urlThumb) 
                else ($iiif):)
    (: if @iiif is set, it implies @iiif=false (retrocompatibility issue) :)            
    let $url := if ($iiif) then ($urlThumb)  (: not IIIF compliant :)
                else ($iiifFinal)
    (: image for download:)            
    let $export :=  if ($iiif) then ($urlDoc)
                    else (concat( $URLiiif,$ill/@x,",",$ill/@y,",",$ill/@w,",",$ill/@h,"/1000,/",$rotation,$imgFormat) )
    
    (: pour le crowdsourcing :)
    let $editMD:=  $ill/@edit
    let $editOCR:= $ill/@editocr
     
     (: si on a un critere sur les personnes/visages ou certaines classes, on affiche les zones 
    let $watson :=
      if ($watson or not($persType="00") or 
      matches("person car boat", $classif) ) then (1) 
    else 
      (0) 
      :)
              
  return
(: choix de la classe CSS de l illustration :)
<div>  {attribute class  {concat('grid-item',  concat (' item-',$orientation,$tailleIll),' ',data($listeClassesNoms), ' ', data($listeCouleursNoms),' ',data($genre),' ',data($periode))}}
{attribute  data-filter {data($genre)}}
{attribute  dates-filter {data($periode)}}
<div class="img">
<div class="help-tip">
<p>
{ if ($debug=1) then (
  <span class="txt">genres : {data($genresVsg)} - orientation : {data($orientation)} - rot. : {data($rotation)} - coul. : {data($couleur)} - taille aff. :  {data($tailleIll)} - taille :  {data($ill/@taille)} - l : {data($ill/@w)} (px) - h : {data($ill/@h)} (px) -  x : {data($ill/@x)} - y : {data($ill/@y)} - larg. : {data($largeur)}  - haut. : {data($hauteur)} - hash : {data($ill/@hash)}- edit MD : {data($editMD)} - edit OCR : {data($editOCR)} - data : {data($databnf)}<br></br></span> )
  else ()
}
<span class="titre">{data($titre)}</span> &#8193;  <br></br>
{ if (not(empty($auteur)) and not($auteur="inconnu")) then 
   (<span class="auteur">{data($auteur)}<br></br></span>)
else ()}
{ if (not(empty($editeur)) and not($editeur="inconnu")) then 
   (<span class="auteur">{data($editeur)} (ed.)<br></br></span>)
else ()}
{
  if ( not(empty($date)) ) then
( <span class="fa date">&#xf073;<span class="date">&#8193;{data($date)}</span> </span>)
else ()} &#8193; <span class="fa folio">&#xf1c4; <span class="folio">&#8193;{data($npage)}
</span></span>
<br></br>
{ if ( not(empty($source))) then ( <span class="source">Source : {data($source)}<br></br></span> )
 else ()} 
{ if ( not(empty($source))) then ( <span class="source">Descr. : {data($descr)}<br></br></span> )
 else ()}      
<span lang="fr" class="classif">collection : <b>{data($nomColl)}</b> &#8211; mode couleur : <b>{data($couleur)}</b> &#8211; rotation : <b>{data($rotation)}°</b> &#8211; theme : <b>{data($theme)}</b> &#8211; genre : <b>{data($genre)}</b>  {if ($genresPersonnes !="") then (<span>&#8211; personne : <b>{data($genresPersonnes)}</b></span>)}  
{if ($genresVsg !="") then (<span>&#8211; visage : <b>{data($genresVsg)}</b></span>)}
</span>  
<span lang="en" class="classif">collection: <b>{data($nomColl)}</b> &#8211; color mode: <b>{data($couleur)}</b> &#8211; rotation: <b>{data($rotation)}°</b> &#8211; theme: <b>{data($theme)}</b> &#8211; genre: <b>{data($genre)}</b>
{if ($genresPersonnes !="") then (<span>&#8211; person: <b>{data($genresPersonnes)}</b></span>)}  
{if ($genresVsg !="") then (<span>&#8211; face: <b>{data($genresVsg)}</b></span>)}
</span>

{if ($classesNoms != "") then (
<span class="classif">&#8211; classes {if ($CBIR != "*") then (<i>({data($CBIR)})</i>)} : </span>)} 
 
 <span class="classif"> 
{let $foo := ""
for $classe in $classesNoms
  let $label := $classe
  return <a class="classif classes"> {attribute  href  {concat ("javascript:searchClass('",$locale,"','",$corpus,"',""",$label,""",'",$CS,"')")}}{data($label)},</a>}
 </span>
 
{if ($couleursNoms !="" or ($couleursHex !="")) then ( 
<span class="classif">
    <span lang="en" class="classif">&#8211; colors:</span>
    <span lang="fr" class="classif">&#8211; couleurs :</span>
</span>)}
   

{if ($couleursNoms !="") then ( 
<span class="classif"> 
{ let $foo := ""
  for $color in $couleursNoms 
    let $label := $color  
    return if  ($color/@r) then (<a title="Trouver des illustrations incluant cette couleur" class="classif classes"  style="background-color: rgb({data($color/@r)},{data($color/@g)},{data($color/@b)})"> {attribute  href  {concat ("javascript:searchClass('",$locale,"','",$corpus,"',""",$label,""",'",$CS,"')")}}{data($label)}&#8193;</a>) else (<a title="Trouver des illustrations incluant cette couleur" class="classif classes"> {attribute  href  {concat ("javascript:searchClass('",$locale,"','",$corpus,"',""",$label,""",'",$CS,"')")}}{data($label)}&#8193;</a>) }</span>) 
} 

{if ($couleursHex !="") then ( 
  let $foo := ""
  for $color in $couleursHex 
    let $label := $color    
    return if ($color/@type='bkg') then (<a title="Trouver des illustrations ayant cette couleur en arrière-plan" class="classif classes" style="background-color: {data($color)}"> {attribute  href  {concat ("javascript:simColor('",$corpus,"','",$color/@r,"','",$color/@g,"','",$color/@b,"','true')")}}[{data($label)}&#8193;]</a>) else (<a title="Trouver des illustrations incluant cette couleur" class="classif classes" style="background-color: {data($color)}"> {attribute  href  {concat ("javascript:simColor('",$corpus,"','",$color/@r,"','",$color/@g,"','",$color/@b,"','false')")}}&#8193;{data($label)}&#8193;</a>))
  }
  
{
if (($titraille !="") and not ($titraille = $titre)) then (
<span class="article"><span lang="fr">Titre : </span><span lang="en">Title: </span>{data($titraille)}</span>)
}
{
if ($legende!="")
   then ( if (fn:string-length($legende) > $legLength) then
     (<span class="legende"><span lang="fr">Lég. :</span><span lang="en">Caption:</span> « {fn:substring($legende,1,$legLength)} »</span>)
     else (<span class="legende"><span lang="fr">Lég. :</span><span lang="en">Caption:</span> « {data($legende)} » </span>)
 )}
{ if ($texte!="")
   then (
     if (fn:string-length($texte) > $txtLength) then
       (<span class="txt">« {fn:substring($texte,1,$txtLength)} » (...) &#x25A0;</span>)
       else (<span class="txt">« {data($texte)} » &#x25A0;</span>)
       )
}
</p>
</div>
<figure> {attribute class {concat('item-',$orientation,$tailleIll)}}
<a href="{$urlDoc}" target="_blank" title="Consulter">
<img src="{$url}"></img>
</a> <!-- colors palette display-->
{if ((($corpus = "pp18")  or ($corpus = "zoologie")) and ($couleur = "coul") ) then (
  <div>
  <div> {attribute class {concat('item-palette-',xs:float($module)*20)}}<img style="max-width: 100%;max-height: 100%;" src="{$urlPalette}"></img>
  {if ($TNA) then (<span  class="item-source">{$sourceAlias}</span>)}</div>
</div>) 
}
{if ($crowd) then (
if (not(empty($segment))) then (
  <div class="fa item-seg"> </div>
)) 
}
{if ($crowd) then ( 
if ($editMD) then (
  <div class="fa item-edit"> </div>
))
}
{if ($crowd) then ( 
if ($editOCR) then (
  <div class="fa item-ocr"> </div>
))
}
 
{if ($display and not($persType="00")) then (
 (: afficher les crops des visages :)
  for $visage in if ($CBIR="*") then (
    $ill/contenuImg[text()=$faceClass and @CS>=$CS])
    else ($ill/contenuImg[@source=$CBIR and text()=$faceClass and @CS>=$CS])
   (: ratio entre largeur de l'illustration affichée et largeur réelle : approximation :)
  (: let $ratio := if ($orientation="v") then ((fn:number($largeur) div fn:number($ill/@w))) else ((fn:number($hauteur) div fn:number($ill/@h)*0.9))  :) 
   let $ratio := fn:number($largeur) div fn:number($ill/@w)*0.9
   let $sexe :=  $visage/@sexe
   let $idVsg :=  $visage/@n
   let $scoreCBIR := fn:format-number($visage/@CS,"9.99")
   let $sourceCBIR := $visage/@source
   return
      <div> {attribute class  {concat('imgv item-face',$sexe)} }
      {attribute  style  {concat('left:',$ratio * $visage/@x,";top:",$ratio * $visage/@y,";width:",
      $ratio * $visage/@l,";height:",$ratio * $visage/@h)}}
      <span class="txtlight">face {data($sexe)} ({data($sourceCBIR)}-{data($scoreCBIR)})</span>
      <div> {attribute  class {'menu-tipv'}}
<ul class="main-navigation">
<li><a  title="Ce n'est pas un visage" id="norm" class="fa" href="javascript:visage('{$corpus}','FT', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf05e;</a></li>
<li><a  title="Visage Femme" id="norm"  class="fa" href="javascript:visage('{$corpus}','F', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf182;</a></li>
 <li><a  title="Visage Homme"  class="fa" href="javascript:visage('{$corpus}','M', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf183;</a></li> 
  <li><a  title="Visage Enfant" id="norm" class="fa" href="javascript:visage('{$corpus}','C', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf1ae;</a></li>
  <li><a  title="Visage nommé" id="norm" class="fa" href="javascript:visage('{$corpus}','N', '{$id}','{$ill/@n}', '{$idVsg}','{$sourceEdit}')">&#xf2ba;</a></li> 
 </ul>
</div>
     </div>
) else ()}


{if ($display and (not (matches($persType,"face")) and not($persType="00")))  then ( 
 (: afficher les crops de type Personne avec leurs synonymes :)
  for $pers in  if ($CBIR="*") then (
    $ill/contenuImg[@x and @CS>=$CS and (text()="person" or text()='gentleman' or text()='head' or  text()='man' or text()='mans face' or text()='portrait picture'  or text()='figure drawing' or matches(text(),"person ") or matches(text()," person")  or matches(text(),"adult") or matches(text(),"people") or matches(text(),"human") ) ])
    else ($ill/contenuImg[@source=$CBIR and @x and @CS>=$CS and (text()="person" or text()='gentleman' or text()='man' or text()='head' or text()='mans face' or text()='portrait picture' or matches(text(),"person ") or matches(text()," person") or text()='figure drawing' or matches(text(),"adult") or matches(text(),"people") or matches(text(),"human")) ])    
   let $ratio := fn:number($largeur) div fn:number($ill/@w)*0.9
   let $scoreCBIR := fn:format-number($pers/@CS,"9.99")
   let $label := $pers
   let $sourceCBIR := $pers/@source
   return
      <div> {attribute class  {'item-obj'} }
      {attribute  style  {concat('left:',$ratio * $pers/@x,";top:",$ratio * $pers/@y,";width:",
      $ratio * $pers/@l,";height:",$ratio * $pers/@h)}}
      <span class="txtlight">{data($label)} ({data($sourceCBIR)}-{data($scoreCBIR)})</span>
     </div>
) else ()}


{if ($display and not ($classif2=""))  then ( 
 (: afficher les crops des autres classes :)
  for $obj in  if ($CBIR="*") then (
    $ill/contenuImg[@x and @CS>=$CS and fn:lower-case(text())=fn:lower-case($classif2) ]) 
    else ($ill/contenuImg[ @x and @CS>=$CS and @source=$CBIR and (fn:lower-case(text())=fn:lower-case($classif2))])    
   let $ratio := fn:number($largeur) div fn:number($ill/@w)*0.9
   let $scoreCBIR :=  fn:format-number($obj/@CS,"9.99")
   let $label := $obj
   let $sourceCBIR := $obj/@source
   return
      <div> {attribute class  {'imgv item-obj'} }
      {attribute  style  {concat('left:',$ratio * $obj/@x,";top:",$ratio * $obj/@y,";width:",
      $ratio * $obj/@l,";height:",$ratio * $obj/@h)}}
      <span class="txtlight">{data($label)} ({data($sourceCBIR)},{data($scoreCBIR)})</span>
      </div>
     ) else ()}

     
{if ($display and not ($classif1=""))  then ( 
 (: afficher les crops des autres classes :)
  for $obj in  if ($CBIR="*") then (
    $ill/contenuImg[@x and @CS>=$CS and fn:lower-case(text())=fn:lower-case($classif1) ])  (: lower-case pour gerer les classes génériques Airplane, Boat, etc. :)
    else ($ill/contenuImg[ @x and @CS>=$CS and @source=$CBIR and (fn:lower-case(text())=fn:lower-case($classif1))])    
   let $ratio := fn:number($largeur) div fn:number($ill/@w)*0.9
   let $scoreCBIR :=  fn:format-number($obj/@CS,"9.99")
   let $label := $obj
   let $sourceCBIR := $obj/@source
   return
      <div> {attribute class  {'imgv item-obj'} }
      {attribute  style  {concat('left:',$ratio * $obj/@x,";top:",$ratio * $obj/@y,";width:",
      $ratio * $obj/@l,";height:",$ratio * $obj/@h)}}
      <span class="txtlight">{data($label)} ({data($sourceCBIR)},{data($scoreCBIR)})</span>
<div> {attribute  class {'menu-tipv'}}
<ul class="main-navigation">
<li><a  title="Supprimer tous les tags '{$classif1}'" id="norm" class="fa" href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','FT')">&#xf05e;</a></li>

{if ($debug) then (<li><a class="fa" title="Remplacer tous les tags '{$classif1}' par :" href="#">&#xf097;</a>
<ul class="semantic"> 

      <li ><a   href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','other')">_other_</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','animal')">animal</a></li>
      <li><a   href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','airplane')">airplane</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','boat')">boat</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','bicycle')">bicycle</a></li>
       <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','bottle')">bottle</a></li>
     <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','truck')">truck</a></li>
    
     <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','house')">house</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','furniture')">furniture</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','motorcycle')">motorcycle</a></li>
       <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','bird')">bird</a></li>
       <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','person')">person</a></li>
        <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','fish')">fish</a></li>
        <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','face')">face</a></li>
      <li><a  href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','{$CBIR}','{$sourceEdit}','{$classif1}','car')">car</a></li></ul></li>) else () }
 </ul>
 </div>
</div>
) else ()}

{if ($display and (($genresPersonnes != "")  and (($classif1="person") or ($classif2="person") or matches($persType,"person")))) then (
  (: afficher les icones de type Personne :) 
        <div> {attribute class  {concat('fa fa-user item-',$genresPersonnes)}} {attribute style {if (not ($crowd) or (not($segment) and not($editMD))) then ("top:8px") else ("top:24px")}}  </div>
      ) else ()   
 }
</figure>

<div id="main-navigation"> {attribute class  {'menu-tip crowd'}}

<ul class="main-navigation" id="liste">

 <li><a id="linkShare" title="Diffuser l'illustration" class="fa" href="#">&#xf045;</a> 
 <ul>
   <li><a class="fa" id="big" title="Publier sur Facebook" href="javascript:fbShare2('{$urlDoc}', '{$titre}', 'GallicaPix','{$legende}', '{$iiif}')">&#xf082;</a></li>
   <li><a class="fa" id="big" title="Publier sur Twitter" href="javascript:TwitShare('{$urlDoc}', '{$titre}', '{$legende}', '{$iiif}')">&#xf099;</a></li>
   <li><a class="fa" id="big" title="Envoyer par courriel" href="mailto:?subject={$titre}&amp;body=Document : {$urlDoc} Image : {$iiif}">&#xf1fa;</a></li>
   <li><a  class="fa" id="small" title="Exporter l'image" href="{$export}" target="_blank">&#xf03e;</a></li>
   <li><a  class="fa" id="small" title="Exporter les métadonnées (JSON)" href="#">&#xf121;</a>
   <ul> 
    <li><a  class="fa" id="small" title="de l'illustration" href="javascript:exportIllJson('{$corpus}','{$id}','{$ill/@n}')" target="_blank">&#xf03e;</a></li>
     <li><a  class="fa" id="small" title="du document" href="javascript:exportDocJson('{$corpus}','{$id}')" target="_blank">&#xf0c5;</a></li>
    </ul>
    </li>
 </ul>
 </li>

 
   <li><a id="linkCorrect" title='{if ($debug) then ("Corriger les métadonnées de l''illustration") else ("Edition non autorisée")}' class="fa" href="#">&#xf00c;</a> 
   <ul>  
     { if ($debug) then ( <li><a  class="fa" title="Ajouter un tag sémantique" href="#">&#xf097;</a>
     {if ($corpus = "zoologie") then (
     <ul>       
      <li><a   href="javascript:tag('{$corpus}','bird', '{$id}', '{$ill/@n}','{$sourceEdit}')">bird ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','butterfly', '{$id}', '{$ill/@n}','{$sourceEdit}')">butterfly ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','fish', '{$id}', '{$ill/@n}','{$sourceEdit}')">fish ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','insect', '{$id}', '{$ill/@n}','{$sourceEdit}')">insect ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','invertebrate', '{$id}', '{$ill/@n}','{$sourceEdit}')">invertebrate ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','mammal', '{$id}', '{$ill/@n}','{$sourceEdit}')">mammal ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','shellfish', '{$id}', '{$ill/@n}','{$sourceEdit}')">shellfish ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','reptile', '{$id}', '{$ill/@n}','{$sourceEdit}')">reptile ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','spider', '{$id}', '{$ill/@n}','{$sourceEdit}')">spider ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','vertebrate', '{$id}', '{$ill/@n}','{$sourceEdit}')">vertebrate ({$sourceEdit})</a></li>
     </ul>
   ) else (
     <ul>       
      <li><a   href="javascript:tag('{$corpus}','airplane', '{$id}', '{$ill/@n}','{$sourceEdit}')">avion ({$sourceEdit})</a></li>
       <li><a   href="javascript:tag('{$corpus}','monoplane', '{$id}', '{$ill/@n}','{$sourceEdit}')">monoplan ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','biplane', '{$id}', '{$ill/@n}','{$sourceEdit}')">biplan ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','triplane', '{$id}', '{$ill/@n}','{$sourceEdit}')">triplan ({$sourceEdit})</a></li>
       <li><a   href="javascript:tag('{$corpus}','airship', '{$id}', '{$ill/@n}','{$sourceEdit}')">dirigeable ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','boat', '{$id}', '{$ill/@n}','{$sourceEdit}')">bateau ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','bicycle', '{$id}', '{$ill/@n}','{$sourceEdit}')">bicyclette ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','truck', '{$id}', '{$ill/@n}','{$sourceEdit}')">camion ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','motorbike', '{$id}', '{$ill/@n}','{$sourceEdit}')">motocyclette ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','train', '{$id}', '{$ill/@n}','{$sourceEdit}')">train ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','car', '{$id}', '{$ill/@n}','{$sourceEdit}')">voiture ({$sourceEdit})</a></li>
      <li><a   href="javascript:tag('{$corpus}','tank', '{$id}', '{$ill/@n}','{$sourceEdit}')">tank ({$sourceEdit})</a></li>
       <li><a   href="javascript:tag('{$corpus}','armored vehicle', '{$id}', '{$ill/@n}','{$sourceEdit}')">véhicule blindé ({$sourceEdit})</a></li>
     </ul>
   )
   }
    
    </li>   ) else () }
    
    { if ($debug) then ( 
    <li><a  class="fa" title="Supprimer un tag sémantique" href="#">&#xf014;</a>
      <ul>       
      {
        for $md in if ($CBIR="*") then ( $ill/contenuImg[@source="md" and not(@filtre) and @lang=$locale]) (: trick :)
                   else ($ill/contenuImg[@source=$CBIR and @lang=$locale and not(@filtre)]) 
        let $item := $md
        return
           if ($CBIR="*") then ( <li><a href="javascript:updateTag('{$corpus}','{$id}','{$ill/@n}','md','{$sourceEdit}','{$item}','FT')">{$item} (md)</a></li>) 
                   else
          (<li><a href="javascript:updateTag('{$corpus}','{$id}', '{$ill/@n}','{$CBIR}','{$sourceEdit}','{$item}','FT')">{$item} ({$CBIR})</a></li>)
      }
      )
      </ul> 
    </li>   ) else () }
    
   {if ($debug) then ( <li><a  class="fa" title="Signaler une image couleur"  href="javascript:couleur('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}','coul')">&#xf043;</a>
 <ul>
  <li><a   title="Dominante bleu"  href="javascript:tag('{$corpus}','blue color','{$id}','{$ill/@n}', '{$sourceEdit}')">B</a></li>
   <li><a   title="Dominante grise"  href="javascript:tag('{$corpus}','gray color','{$id}','{$ill/@n}', '{$sourceEdit}')">Gris</a></li>
  <li><a   title="Dominante jaune"  href="javascript:tag('{$corpus}','yellow color','{$id}','{$ill/@n}','{$sourceEdit}')">J</a></li>
  <li><a   title="Dominante marron"  href="javascript:tag('{$corpus}','maroon color','{$id}','{$ill/@n}', '{$sourceEdit}')">M</a></li>

   <li><a   title="Dominante orange"  href="javascript:tag('{$corpus}','orange color','{$id}','{$ill/@n}', '{$sourceEdit}')">O</a></li>
   <li><a   title="Dominante rose"  href="javascript:tag('{$corpus}','pink color','{$id}','{$ill/@n}', '{$sourceEdit}')">Rose</a></li>
  <li><a   title="Dominante rouge"  href="javascript:tag('{$corpus}','red color','{$id}','{$ill/@n}', '{$sourceEdit}')">R</a></li>
   <li><a   title="Dominante verte"  href="javascript:tag('{$corpus}','green color','{$id}','{$ill/@n}', '{$sourceEdit}')">V</a></li>
 </ul>
</li>) else ()}

   {if ($debug) then ( <li><a  class="fa" title="Signaler une image en niveaux de gris"  href="javascript:couleur('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}'), 'gris'">&#xf042;</a></li>) else ()}
    {if ($debug) then (<li><a  id="small" class="fa" title="Corriger thème et genre de l'illustration"  href="javascript:edit('{$locale}','{$corpus}','{$id}', '{$ill/@n}', '{$export}', '{$coll}', '{$titre}','{$titraille}', '{$legende}', '{$codeTheme}', '{$genre}', '{$couleur}','{$sourceEdit}')">&#xf044;</a></li>  ) else ()}
   {if ($debug) then (  <li><a  id="small" class="fa" title="Corriger l'OCR"  href="javascript:editOCR('{$locale}','{$corpus}','{$id}', '{$ill/@n}', '{$urlDoc}', '{$coll}', '{$titre}','{$titraille}', '{$legende}','{$texte}','{$sourceEdit}')">&#xf031;</a></li> ) else ()}
    
  {if ($debug) then (   <li><a   id="sbig" class="fa" title="Indiquer la présence de personnes" href="#">&#xf007;</a>
     <ul>      
      <li><a  title="Femme" id="norm" class="fa" href="javascript:personne('{$corpus}','woman', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf182;</a></li>
      <li><a  title="Homme"  class="fa" href="javascript:personne('{$corpus}','man', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf183;</a></li>
      <li><a  class="fa" id="norm" title="Foule"  href="javascript:personne('{$corpus}','crowd', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf0c0;</a></li> 

      <li><a  class="fa" id="norm" title="Enfant"  href="javascript:personne('{$corpus}','child', '{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf1ae;</a></li> 
     </ul>
    </li> 
    ) else ()} 

 {if ($debug) then (    
    <li><a  id="norm" class="fa" title="Signaler un visage" href="javascript:displayPage('{$locale}','{$corpus}','{$id}','{$npage}','{$nbPages}','{$CBIR}','{$CS}')">&#xf11a;</a>
   </li>) else ()} 
   </ul>
   </li>
   {if ($debug) then ( <li><a  class="fa" title="Supprimer une image qui n'est pas une illustration"  href="javascript:filtre('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf014;</a></li>) else ()}
   {if ($debug) then ( <li><a  class="fa" title="Signaler une image couleur"  href="javascript:couleur('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}','coul')">&#xf043;</a></li>) else ()}
   
   {if ($debug) then ( <li><a  class="fa" title="Signaler une image en niveaux de gris"  href="javascript:couleur('{$corpus}','{$id}', '{$ill/@n}', '{$sourceEdit}','gris')">&#xf042;</a></li>) else ()}
 {if ($debug) then ( <li><a   title="Signaler une publicité"  class="fa"  href="javascript:filtrePub('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf217;</a></li>) else ( )}
 {if ($debug) then (  <li><a id="linkD" title="Signaler un dessin"  class="fa" href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','dessin','{$sourceEdit}')">&#xf040;</a></li>) else ()} 
  {if ($debug) then ( <li><a    href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','graphique','{$sourceEdit}')">Graph</a></li>) else ()} 
  {if ($debug) then ( <li><a  title="Signaler une gravure"  href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','gravure','{$sourceEdit}')">G</a></li>) else ()} 
   {if ($debug) then (   <li><a title="Signaler du texte"  href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','manuscrit','{$sourceEdit}')">T</a></li>) else ()}  
    {if ($debug) then (  <li><a  id="linkPG" title="Signaler une photo"  href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','photo','{$sourceEdit}')">P</a></li>)else ()} 
   {if ($debug) then (  <li><a class="fa" id="linkPG" title="Signaler une photogravure"  href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','photog','{$sourceEdit}')">&#xf083;</a></li>)else ()} 
  {if ($debug) then (<li><a class="fa" id="linkM" title="Signaler une carte" href="javascript:fixGenre('{$corpus}','{$id}', '{$ill/@n}','carte','{$sourceEdit}')">&#xf0ac;</a></li> ) else ()} 
 {if ($debug) then (
  <li><a   title="Quart de tour° sens horaire"  href="javascript:rotation('{$corpus}',90, '{$id}', '{$ill/@n}','{$sourceEdit}')">90°</a>
      </li> 
) else ()} 
 
<li><a id="linkFilter" title='{if ($debug) then ("Modifier l''illustration") else ("Signaler un défaut")}' class="fa" href="#">&#xf0c4;</a>
 <ul> 
  {if ($debug ) then ( <li><a id="linkDisplayPage" class="fa" title="Corriger la segmentation" href="javascript:displayPage('{$locale}','{$corpus}','{$id}','{$npage}','{$nbPages}','{$CBIR}','{$CS}')">&#xf125;</a></li>) else (
   <li><a id="linkDisplayPage" class="fa" title="Signaler un défaut de segmentation" href="javascript:alert2log('{$corpus}','segmentation','{$id}','{$ill/@n}','{$sourceEdit}')">&#xf125;</a></li> 
  )
(:&#xf02d :)} 

{if ($debug) then (<li><a   id="big" class="fa" title="Corriger l'orientation de l'illustration" href="#">&#xf01e;</a>
     <ul>
      <li><a  title="Quart de tour sens anti-horaire"  href="javascript:rotation('{$corpus}',270, '{$id}', '{$ill/@n}','{$sourceEdit}')">-90°</a></li>
      <li><a  title="Angle de 0°"  href="javascript:rotation('{$corpus}',0, '{$id}', '{$ill/@n}','{$sourceEdit}')">0°</a></li>
      <li><a   title="Quart de tour° sens horaire"  href="javascript:rotation('{$corpus}',90, '{$id}', '{$ill/@n}','{$sourceEdit}')">90°</a>
      </li>
     </ul>    
   </li>   
   ) else (
      <li><a id="linkDisplayPage" class="fa" title="Signaler un défaut d'orientation" href="javascript:alert2log('{$corpus}','orientation','{$id}','{$ill/@n}','{$sourceEdit}')">&#xf01e;</a></li>
   )}
    
{if ($debug) then ( <li><a  class="fa" title="Supprimer une image qui n'est pas une illustration"  href="javascript:filtre('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf014;</a></li>) else (
      <li><a id="linkDisplayPage" class="fa" title="Signaler une image qui n'est pas une illustration" href="javascript:alert2log('{$corpus}','genre','{$id}','{$ill/@n}','{$sourceEdit}')">&#xf014;</a></li>
   )}


{if ($debug) then (  <li><a class="fa" title="Signaler une publicité illustrée"  href="javascript:filtrePub('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf217;</a></li>) else (
      <li><a id="linkDisplayPage" class="fa" title="Signaler une publicité illustrée" href="javascript:alert2log('{$corpus}','pub','{$id}','{$ill/@n}','{$sourceEdit}')">&#xf217;</a></li>
   )}

{if ($debug) then (  <li><a class="fa" title="Défiltrer"  href="javascript:deFiltre('{$corpus}','{$id}', '{$ill/@n}','{$sourceEdit}')">&#xf00c;</a></li>) else (
     
   )}

 </ul>
</li>

<li><a id="linkSearch" title="Rechercher d'autres illustrations" class="fa" href="#">&#xf002;</a> 
 <ul>  
   {if ( ($nbIlls > 1)) then ( <li><a id="linkSamePage" class="fa" title="Afficher les illustrations de la même page" href="javascript:samePage('{$locale}','{$corpus}','{$id}','{$npage}','{$CS}')">&#xf016;</a></li>) else ()}
   {if ( ($nbPages > 1)) then ( <li><a id="linkSameDoc" class="fa"  title="Afficher les illustrations du document"  href="javascript:sameDoc('{$locale}','{$corpus}','{$id}','{$CS}')">&#xf0c5;</a></li>) else ()}
 {(:if ($debug) then ( <li><a id="linkSimilar" class="fa"  title="Chercher des illustrations similaires" href="javascript:simFull('{$locale}','{$corpus}','{fn:string-join($ill/contenuImg[@CS>0.7],',')}')">&#xf002;</a></li>) else ():)}
 {if ($ill/@hash and (not($ill/@hash =''))) then ( <li><a id="linkSimilar" class="fa"  title="Chercher des illustrations similaires" href="javascript:sim('{$locale}','{$corpus}','{$ill/@hash}')">&#xf24d;</a></li>) }
 </ul>
 </li>
   {if (not(empty($databnf))) then (<li><a  title="Voir des documents liés sur data.bnf.fr" href="{$databnf}" target="_blank">data</a></li>)else()}
 </ul>
</div>
</div>
</div>
else
(<div class="grid-warn"><div class="img"><img alt="pas de résultat" title="pas de résultat" src="/static/no-result.png"></img></div></div>)
   }
</div>
</div>
(:   )  if else keyword="" :)
}

<p style="float:right;padding-right:10px"><a  style="font-size:12pt;" title="Haut de page" href="#top">&#9650;</a></p>


<script>
// localiser les interfaces
function localize (language)
{{
  console.log("localize: "+language);
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
      console.log ("Error: "+e);  
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
     document.getElementById('linkSimilar').title="Look for similar illustrations" ;
     }}
     catch (e) {{}}  
   }} 
   console.log("lang: "+lang);
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


// initialiser les menus avec les criteres du formulaire
// init the menus with form values

// crowdsourcing
//var selectCw = document.getElementById('selectCrowd');
//if('{$crowd}' =='1') {{
//        selectCw.checked = true;
//}};

// affichage des infos de classification (crops...)
var selectDisplay = document.getElementById('selectDisplay');
console.log('display: '+'{$display}');
if('{$display}' =='1') {{
        console.log("...setting Display");
        selectDisplay.checked = true;
}};

// affichage du CS
var selectCS = document.getElementById('CS');
console.log('CS: '+'{$CS}');
for(var i, j = 0; i = selectCS.options[j]; j++) {{
    if(i.value == '{$CS}') {{ 
        console.log("...setting CS");
        selectCS.selectedIndex = j; 
    }};;
}};

// types de documents
var selectTP = document.getElementById('selectTypeP');
if('{$typeP}' =='P') {{
        selectTP.checked = true;
}};
var selectTR = document.getElementById('selectTypeR');
if('{$typeR}' == 'R') {{
        selectTR.checked = true;
}};
var selectTM = document.getElementById('selectTypeM');
if('{$typeM}' =='M') {{
        selectTM.checked = true;
}};
var selectTA = document.getElementById('selectTypeA');
if('{$typeA}' =='A') {{
        selectTA.checked = true;
}};
var selectTI = document.getElementById('selectTypeI');
if('{$typeI}' =='I') {{
        selectTI.checked = true;
}};
var selectTC = document.getElementById('selectTypeC');
if('{$typeC}' =='C') {{
        selectTC.checked = true;
}};
var selectTPA = document.getElementById('selectTypePA');
if('{$typePA}' =='PA') {{
        selectTPA.checked = true;
}};

// couleur
console.log("color: "+'{$color}');
var selectC = document.getElementById('selectCouleur');
for(var i, j = 0; i = selectC.options[j]; j++) {{
    if(i.value == '{$color}') {{
       if ('{$locale}' == i.lang) {{
        selectC.selectedIndex = j; }};
    }};;
}};

console.log("size: "+'{$module}');
var selectT = document.getElementById('selectTaille');
for(var i, j = 0; i = selectT.options[j]; j++) {{
    if(i.value == '{$module}') {{
        selectT.selectedIndex = j;
        break;
    }}; 
}};

console.log("genre: "+'{$illType}');
var selectG = document.getElementById('selectGenre');
for(var i, j = 0; i = selectG.options[j]; j++) {{
    if(i.value == '{$illType}') {{
      if ('{$locale}' == i.lang) {{
        selectG.selectedIndex = j;
        break
    }}; }};
}};

console.log("person: "+'{$persType}');
var selectP = document.getElementById('persType');
for(var i, j = 0; i = selectP.options[j]; j++) {{
    if(i.value == '{$persType}') {{
      if ('{$locale}' == i.lang) {{
        selectP.selectedIndex = j;
        break
    }}; }};
}};

console.log("sort: "+'{$order}');
var selectO = document.getElementById('selectOrdre');
for(var i, j = 0; i = selectO.options[j]; j++) {{
    if(i.value == '{$order}') {{
       if ('{$locale}' == i.lang) {{
        selectO.selectedIndex = j;
        break;
    }}; }};    
}};

console.log("end of init");
 
//  pour les panneaux pop-up
function showhide(id) {{
 console.log("showhide id : "+id);  
 var e = document.getElementById(id);
 e.style.display = (e.style.display == 'block') ? 'none' : 'block';
}}

function animer(id) {{
 console.log("flash id: "+id);
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

//  pour le post Facebook
function fbShare2(url, titre, legende, descr, image) {{
        window.open('https://www.facebook.com/sharer.php?u='+ encodeURIComponent(url) + '&amp;redirect_uri' + encodeURIComponent(url)
 + '&amp;picture=' + encodeURIComponent(image) + '&amp;name='+ encodeURIComponent(titre) +
 '&amp;caption=' + encodeURIComponent(legende) + '&amp;description=' + encodeURIComponent(descr),
 'feedDialog', 'toolbar=0,status=0,width=500,height=450') ;
    }}
    
//  pour le post Twitter
function TwitShare(url, titre, legende, descr, image) {{
        window.open('https://twitter.com/intent/tweet?text='+ encodeURIComponent(titre) + " "+
 encodeURIComponent(legende) + " " + encodeURIComponent(descr) + "&amp;url=" + encodeURIComponent(url)
 +"&amp;hashtags=GallicaPix,Gallica" ,
 'feedDialog', 'toolbar=0,status=0,width=500,height=450') ;
    }}
    
// pour les formulaires d edition (crowdsourcing)
function edit(locale, corpus, id, n, iiif, typeDoc, titre, titraille, legende, theme, genre, couleur,source) {{
  console.log("collection: "+typeDoc);
  console.log("color: "+couleur);
  console.log("genre: "+genre);
  console.log("theme: "+theme);
  window.open('/rest?run=findIllustrations-edit.xq&amp;locale='+ locale + '&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;iiif='+ iiif
  + '&amp;type='+ typeDoc +'&amp;title='+ encodeURIComponent(cutString(titre,70)) + '&amp;subtitle=' + encodeURIComponent(cutString(titraille,75))  + '&amp;caption=' + encodeURIComponent(legende)  + '&amp;iptc=' + theme + '&amp;illType=' + genre + '&amp;color=' + couleur + '&amp;source=' + source , 'feedDialog',
  'toolbar=0,status=0,width=750,height=570,top=100,left=300') ;
    }}

// OCR
function editOCR(locale, corpus, id, n, url, typeDoc, titre, titraille, legende, texte, source) {{
  console.log("collection: "+typeDoc);
  
  window.open('/rest?run=findIllustrations-editOCR.xq&amp;locale='+ locale + '&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;url='+ url
  + '&amp;type='+ typeDoc +'&amp;title='+ encodeURIComponent(cutString(titre,70)) + '&amp;subtitle=' + encodeURIComponent(titraille)  + '&amp;caption=' + encodeURIComponent(legende) + '&amp;txt=' + encodeURIComponent(texte) + '&amp;source=' + source , 'feedDialog',
  'toolbar=0,status=0,width=600,height=450,top=100,left=300') ;
    }}
    
// Modifier l angle de rotation
function rotation(corpus, angle, id, n, source) {{
console.log("angle: "+angle);
console.log("id: "+id);
console.log("source: " + source);
popitup2('/rest?run=rotation.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;angle='+ angle + '&amp;source=' + source) ;
    }}

// Ajouter des tags
function tag(corpus, tag, id, n, source) {{
console.log("tag: "+ tag);
console.log("id: "+id);
popitup2('/rest?run=insertTag.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;tag='+ tag + '&amp;source=' + source) ;
    }}

// Modifier un tag
function updateTag(corpus, id, idIll, cbir, source, tagOld, tag) {{
console.log("tag: "+ tag);
console.log("id: " +id);
console.log("cbir: " +cbir);
console.log("source: "+source);
popitup2('/rest?run=updateTag.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;tagOld='+ tagOld+ '&amp;tag='+ tag + '&amp;cbir=' + cbir + '&amp;source=' + source) ;
    }}
        
// Indiquer des personnes
function personne(corpus, p, id, n, source) {{
console.log("person: "+ p);
console.log("id: "+id);
popitup2('/rest?run=person.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;person='+ p + '&amp;source=' + source) ;
    }}
  

// Signaler un probleme
function alert(corpus, pb, id, n, source) {{
console.log("problem: "+ pb);
console.log("id: "+id);
popitup2('/rest?run=alert.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;pb='+ pb + '&amp;source=' + source) ;
    }}
    
// Signaler un probleme
function alert2log(corpus, pb, id, n, source) {{
console.log("problem: "+ pb);
console.log("id: "+id);

popitup2('/rest?run=alert2log.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;pb='+ pb + '&amp;source=' + source) ;

    }}
            
function ajoutVisage(corpus, cmd, id, idIll, idVsg, source ) {{
console.log("sex: "+ cmd);
console.log("id: "+id);
console.log("idVsg: "+idVsg);

popitup2('/rest?run=addFace.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;idIll='+ idIll + '&amp;idVisage='+ idVsg+ '&amp;sexe='+ cmd+ '&amp;source=' + source);
    }}

// Signaler couleur
function couleur(corpus, id, n, source, mode) {{
console.log("color: " + mode);
popitup2('/rest?run=color.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source + '&amp;mode=' + mode) ;
    }}
        
// Filtrer une illustration
function filtre(corpus,id, n, source) {{
console.log("filter ID: "+id+" / "+n);
popitup2('/rest?run=filter.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}
    
// Filtrer une publicité illustrée    
function filtrePub(corpus, id, n, source) {{
console.log("pub ID: "+id);
popitup2('/rest?run=filterPub.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}
    
// Défiltrer une illustration
function deFiltre(corpus,id, n, source) {{
console.log("unfilter ID: "+id+ " / "+n);
popitup2('/rest?run=unFilter.xq&amp;corpus='+corpus + '&amp;id='+ id + '&amp;n='+ n + '&amp;source=' + source) ;
    }}
        
// Demander la segmentation
function segment(corpus,id, n) {{
console.log("ID: "+id);
popitup2('/rest?run=segment.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n) ;
    }}

// To fix gender
function fixGenre(corpus,id, n, type, source) {{
console.log("id: "+id);
console.log("n: "+n);
console.log("change to: "+type);
popitup2('/rest?run=updateGenre.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n  + '&amp;type=' + type + '&amp;source=' + source ) ;
    }}

    
// JSON export 
function exportIllJson(corpus,id,n) {{
console.log("json ID: "+id);
popitup('/rest?run=exportIllJson.xq&amp;corpus='+ corpus + '&amp;id='+ id + '&amp;n='+ n) ;
    }}

function exportDocJson(corpus,id) {{
console.log("json ID: "+id);
popitup('/rest?run=exportDocJson.xq&amp;corpus='+ corpus + '&amp;id='+ id) ;
    }}
    
// display the whole page with illustrations for segmentation           
function displayPage(locale, corpus, id, page, npages, cbir, cs) {{
console.log("id: "+ id); 

console.log("CS: "+ cs);   
window.open('/rest?run=display.xq&amp;locale='+ locale + '&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;nPages='+npages+'&amp;CBIR='+cbir+'&amp;CS='+cs+'&amp;sourceTarget=&amp;') ;
    }}
                
// display the illustrations on the same page            
function samePage(locale, corpus, id, page, cs) {{
console.log("id: "+ id);
  window.open('/rest?run=findIllustrations-app.xq&amp;locale='+ locale + '&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;pageOrder='+page+'&amp;CS='+cs+'&amp;operator=and&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}

// display the illustrations in the same document            
function sameDoc(locale, corpus, id, cs) {{
console.log("id: "+ id);
  
window.open('/rest?run=findIllustrations-app.xq&amp;locale='+ locale +'&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;id='+id+'&amp;CS='+cs+'&amp;operator=and&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}
 
// searching for a visual class             
function searchClass(locale, corpus, classif, CS) {{
console.log("classification: "+ classif);
  
window.open('/rest?run=findIllustrations-app.xq&amp;locale='+ locale +'&amp;action=first&amp;start=1&amp;corpus='+corpus+'&amp;classif2='+classif+'&amp;CS='+CS+'&amp;operator=and&amp;sourceTarget=&amp;keyword=',"_self" ) ;
    }}


                           
// Pour la recherche par similarite
function simFull(locale, corpus, tags) {{
console.log("tags: "+tags); 

window.open('/rest?run=findIllustrations-app.xq&amp;locale='+ locale + '&amp;action=first&amp;start=1&amp;corpus='+ corpus+'&amp;classif='+ tags+'&amp;keyword=&amp;sourceTarget=',"_self" ) ;
    }}


function sim(locale, corpus, hash) {{
 console.log("hash: "+hash);
 
 var form = document.getElementById("formulaire"); 
 // form.reset();   
 // init du champ avec la valeur du hash
 var sim = document.getElementById("similarity"); 
 sim.value=hash;
 
 // relancer le formulaire avec ce nouveau critere   
 form.submit();  
}}
 
// searching for a visual class             
function simColor(corpus, r, g, b, bkg) {{
  console.log("CS: "+{data($CScolor)} );
  console.log("color red: "+ r);
  console.log("color green: "+ g);
  console.log("color blue: "+ b);
  
  
  var form = document.getElementById("formulaire"); 
 // form.reset();   
 // init du champ avec la valeur à chercher
 var rv = document.getElementById("rValue"); 
 rv.value=r;
 var gv = document.getElementById("gValue"); 
 gv.value=g;
 var bv = document.getElementById("bValue"); 
 bv.value=b;
 var bkgv = document.getElementById("bkgColor"); 
 bkgv.value=bkg;
 
 // relancer le formulaire avec ce nouveau critere   
 form.submit();  
 
    }}
     
function popitup(url,windowName) {{
       newwindow=window.open(url,"editW",'height=120,width=320,top=200,left=400,menubar=0,status=0,toolbar=0,titlebar=0,location=0');
       if (window.focus) {{newwindow.focus()}}
       return false;
     }}  

function popitup2(url,windowName) {{
       animer('body');
       newwindow=window.open(url,"ligneAff");
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

</script>


<script> {attribute  src  {'https://unpkg.com/isotope-layout@3.0.6/dist/isotope.pkgd.js'}} </script>
<script> {attribute  src  {'https://unpkg.com/imagesloaded@4/imagesloaded.pkgd.js'}} </script>
<script>
//  pour la grille images Mansory
var elem = document.querySelector('#grid');
var msnry = new Isotope( elem, {{
    itemSelector: '.grid-item',
    columnWidth: 100
   // fitWidth: true,
   // horizontalOrder: true

}});

var imgLoad = imagesLoaded( grid ).on( 'progress', function() {{
  // layout Isotope after each image loads
  console.log( '...relayout');
 // msnry.layout();
}});

imgLoad.on( 'progress', function( instance, image ) {{
  var result = image.isLoaded ? 'loaded' : 'broken';
  //console.log( 'image is ' + result + ' for ' + image.img.src );
}});

msnry.layout()


// ### Classification display ###

var nbClasses = {data($minClasses)};

// setting up the radio buttons behavior 
function radioButtonGroup( buttonGroup ) {{
  buttonGroup.addEventListener( 'click', function( event ) {{
    // only work with buttons
    if ( !matchesSelector( event.target, '.buttonClassif' ) ) {{
      return;
    }}
    //console.log(event.target.textContent);
    var buttons = buttonGroup.querySelectorAll('.is-checked');
    buttons.forEach(function(item, index, array) {{
      item.classList.remove('is-checked')
    }});
    event.target.classList.add('is-checked');
  }});
}}

// reset the radio button to the All Genres  
function resetButtonGroup( buttonGroup ) {{
    console.log(".....resetButtonGroup");
    var buttons = buttonGroup.querySelectorAll('.is-checked');
    buttons.forEach(function(item, index, array) {{
      item.classList.remove('is-checked')
    }});
    //var allButton = document.getElementById('tout'+'_{$locale}');
    //allButton.classList.add('is-checked');
}}

//var buttonGroup = document.querySelector('.button-groupClasses');
//radioButtonGroup( buttonGroup );

// upgrading Arrays
Array.prototype.append = function(array)
{{
    this.push.apply(this, array)
}}

// filter the classes which are not visual reco classes
Array.prototype.filterClasses = function() {{
    var i;
    for(i = this.length; i--;){{
         //console.log(this[i]);
          if (!this[i].includes('_')) this.splice(i, 1);
        }}
  }};

// handling the classification data
//var classesArray = []; // visual recognition classes
//var genresArray_fr = ['affiche','bd','carte','dessin','graphique','gravure','manuscrit','partition','photo','photog','inconnu']; // illustration genres
//var genresArray_en = ['poster','comics','map','drawing','graph','engraving','text','music score','picture','photoengraving','unknown']; 
var genresArray_en = {{affiche: "poster", bd: "comics",carte:"map", dessin:"drawing", graphe:"graph",gravure:"engraving",manuscrit:"text",partition:"music score",photo:"photo",photogr:"photoengraving", textile:"fabrics", inconnu:"unknown"}}

var datesArray_en = {{antiquite: "antic", moyen_age: "middle_age", moderne:"modern", contemporain:"contemporary",inconnu:"unknown"}}

// filter functions
var filterFns = {{
  // show if number is greater than 50
  numberGreaterThan50: function( itemElem ) {{
    var number = itemElem.querySelector('.number').textContent;
    return parseInt( number, 10 ) > 50;
  }},
  // show if name ends with -ium
  ium: function( itemElem ) {{
    var name = itemElem.querySelector('.name').textContent;
    return name.match( /ium$/ );
  }}
}};

// bind the filter button click
var filtersElem = document.querySelectorAll('.filters-button-group');
for ( var i=0, len = filtersElem.length; i != len; i++ ) {{
  filtersElem[i].addEventListener( 'click', function( event ) {{
  // only work with buttons
  if ( !matchesSelector( event.target, '.buttonClassif' ) ) {{
    return;
  }}  
  var filterValue = event.target.getAttribute('data-filter');
  console.log("--> filter on: "+filterValue);
  // use matching filter function
  //filterValue = filterFns[ filterValue ] || filterValue;
  msnry.arrange({{ filter: filterValue }});
  window.setTimeout(setGenresButtons, 500);
  window.setTimeout(setDatesButtons,500); 
  window.setTimeout(setClassesButtons,500); 
  
  if (filterValue.includes('_')) {{  // filter on class
   var buttonGenres = document.querySelector('.button-groupGenres');
   //resetButtonGroup(buttonGenres); 
  }}
}});
}};

// bind the "More classes" button click
var moreClassesButton = document.getElementById('moreClasses');
  moreClassesButton.addEventListener( 'click', function( event ) {{  
  nbClasses = nbClasses+20;
  if (nbClasses > {data($maxClasses)}) {{ nbClasses = {data($maxClasses)} }};
  console.log("classes displayed set to: "+nbClasses);
  setClassesButtons();
}});

// counting the frequencies
function createItemsMap (wordsArray) {{
  // create map for word counts
  var wordsMap = {{}};
  wordsArray.forEach(function (key) {{
    if (wordsMap.hasOwnProperty(key)) {{
      wordsMap[key]++;
    }} else {{
      wordsMap[key] = 1;
    }}
  }});
  return wordsMap;
}}

function sortByCount (wordsMap) {{
  // sort by count in descending order
  var finalWordsArray = [];
  finalWordsArray = Object.keys(wordsMap).map(function(key) {{
    return {{
      name: key,
      total: wordsMap[key]
    }};
  }});
  finalWordsArray.sort(function(a, b) {{
    return b.total - a.total;
  }});
  return finalWordsArray;
}}

// looking for the genres in the genre buttons and build a frequency map
function setGenresArray() {{ 
 console.log("building the genres list...");
 
 var gArray = [];
 //if ({data($locale)="en"}) {{
 //     gArray = genresArray_en}}
 //   else {{gArray = genresArray_fr}} 
 
 var imgs = document.querySelectorAll('.grid-item');
 console.log("images displayed: "+imgs.length);
 imgs.forEach(function(item, index, array) {{
  if (item.style['display'] != 'none') {{  
    gArray.append([item.getAttribute('data-filter')]);  
   }};  
  }});   
 return gArray;
}}

// looking for the dates 
function setDatesArray() {{ 
 console.log("building the dates list...");
 
 var dArray = [];
 var imgs = document.querySelectorAll('.grid-item');
 console.log("images displayed: "+imgs.length);
 imgs.forEach(function(item, index, array) {{
  if (item.style['display'] != 'none') {{  
    dArray.append([item.getAttribute('dates-filter')]);  
   }};  
  }});   
 return dArray;
}}

function setDatesButtons () {{
 console.log("updating the dates buttons..."); 
 
 var dArray=setDatesArray();
 var datesMap = createItemsMap(dArray);
 var finalDatesArray = sortByCount(datesMap);
 var finalDates = finalDatesArray.length;
 console.log("periods found: " + finalDates);
 // set the buttons
 for ( var i=1, len = 5 ; i != len+1; i++ ) {{  // 5 periods
   var dateButton = document.getElementById('d'+i); 
   if (i > finalDates)  {{
    dateButton.style.display = 'none';
   }} else {{
   var tmp = finalDatesArray[i-1].name;
   console.log("date #"+i+" :"+tmp);
   if ({data($locale)="en"}) {{
      dateButton.title = "Filter on the '"+genresArray_en[tmp]+"' period within the displayed images ("+{data($records)}+")";
      dateButton.textContent = datesArray_en[tmp] +' ('+finalDatesArray[i-1].total+')'  ; 
    }}
    else {{
      dateButton.title = "Filtrer sur la periode '"+tmp+"' dans les images affichées)";
      dateButton.textContent = tmp +' ('+finalDatesArray[i-1].total+')'  ; }}     
    dateButton.setAttribute('data-filter','.'+tmp);
    dateButton.style.display = 'inline';
  }}
 }} 
}}

// looking for the Visual Reco. classes set on the grid-items and build a frequency map
function setClassesArray() {{ 
 console.log("building the classes list...");
 var cArray = [];
 var imgs = document.querySelectorAll('.grid-item');
 console.log("images displayed: "+imgs.length);
 imgs.forEach(function(item, index, array) {{
 if (item.style['display'] != 'none') {{ 
    var classes = item.classList;
    var tmp = Array.from(classes);
    tmp.filterClasses();
    cArray.append(tmp);
   }};  
  }});
 return cArray;
}}

function setGenresButtons () {{
 console.log("updating the genres buttons..."); 
 
 var gArray=setGenresArray();
 var genresMap = createItemsMap(gArray);
 var finalGenresArray = sortByCount(genresMap);
 var finalGenres = finalGenresArray.length;
 console.log("genres found: " + finalGenres);
 // set the genres buttons
 for ( var i=1, len = {data($maxGenres)} ; i != len+1; i++ ) {{
   var genreButton = document.getElementById('g'+i);
   if (i > finalGenres)  {{
    //console.log("hidding "+i);
    genreButton.style.display = 'none';
   }}
   else {{   
    var tmp = finalGenresArray[i-1].name;
    console.log("genre #"+i+" :"+tmp);
    if ({data($locale)="en"}) {{
      genreButton.title = "Filter on the '"+genresArray_en[tmp]+"' genre within the displayed images ("+{data($records)}+")";
      genreButton.textContent = genresArray_en[tmp] +' ('+finalGenresArray[i-1].total+')'  ; 
  }}
    else {{
      genreButton.title = "Filtrer sur le genre '"+tmp+"' dans les images affichées ("+{data($records)}+")";
      genreButton.textContent = tmp +' ('+finalGenresArray[i-1].total+')'  ; }}     
    genreButton.setAttribute('data-filter','.'+tmp);
    genreButton.style.display = 'inline';
  }}
 }} 
}}

// 
function setClassesButtons () {{
 console.log("updating the classes buttons..."); 
 
 var cArray=setClassesArray();
 var classesMap = createItemsMap(cArray);
 var finalClassesArray = sortByCount(classesMap);
 //console.log(finalClassesArray);
 var finalClasses = finalClassesArray.length;
 console.log("classes found: " + finalClasses);
 // set the classes buttons
 console.log("classes displayed: " + nbClasses);
 for ( var i=1, len = {data($maxClasses)} ; i != len+1; i++ ) {{
   var classButton = document.getElementById('c'+i);
   //console.log("#classe " + i);
   if (i>finalClasses || i>nbClasses)  {{
    //console.log("cache "+i);
    classButton.style.display = 'none';
   }}
   else {{   
    var tmp = finalClassesArray[i-1].name;
    //console.log("top class "+i+" :"+tmp);
    classButton.setAttribute('class','button buttonClassif');
    if (tmp.charAt(0) == '-') {{ //we have a color class if first char is -
         classButton.setAttribute('class','button buttonColor buttonClassif');
      }}
    if ({data($locale)="en"}) {{
      classButton.title = "Filter on the '"+tmp.substring(1)+"' class within the displayed images ("+{data($records)}+")"}}
    else {{
      classButton.title = "Filtrer sur la classe '"+tmp.substring(1)+"' dans les images affichées ("+{data($records)}+")"
     }}
    classButton.textContent = tmp.substring(1) +' ('+finalClassesArray[i-1].total+')'  ;  
    classButton.setAttribute('data-filter','.'+tmp); 
    classButton.style.display = 'inline';   
  }}
 }} 
}}

// set up the Genres buttons
setGenresButtons();

// set up the dates buttons
setDatesButtons();

// set up the Classes buttons
setClassesButtons();
   
console.log("end script");

</script>
</body >
</html>
  };


(: Execution de la requete sur la base BaseX - le nom de la base doit etre donne ici
   The BaseX database must be specify here  :)
let $data := $corpus   
let $HTMLmap := map {
   "method": "html",
   "html-version" : "5.0",   
   "encoding": "UTF-8"}
let $JSONmap := map {
   "format": "jsonml",
   "indent": "yes"
 }      
let $XMLmap := map {
   "method": "xml",
   "version": "1.0",
   "indent": "yes",
   "encoding": "UTF-8",
   "omit-xml-declaration": "no"
    } 
return
try {
    if ($mode="xml") then serialize(local:createXMLOutput($data),$XMLmap) 
    else if ($mode="json") then json:serialize(local:createXMLOutput($data),$JSONmap)
    else local:createHTMLOutput($data)}
catch * {
    <h2>Une erreur est survenue !</h2>,
    'Erreur [' || $err:code || '] : ' || $err:description,
       <br></br>,
    $err:value, " module : ", $err:module, "(", $err:line-number, ",", $err:column-number, ")",
    <p>Merci de bien vouloir contacter gallica@bnf.fr afin de la signaler.</p>
    } 