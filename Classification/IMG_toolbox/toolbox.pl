#!/usr/bin/perl -w
#######################
# USAGE: perl toolbox.pl -service  IN option
#   service: see below
#   IN : input folder
#   option :
# OBJECTIVES:
# Handle and enrich the illustrations metadata


# use strict;
use warnings;
use 5.010;
use LWP::Simple;
use LWP::Protocol::https;  # for the https gallica URLs
use LWP::UserAgent;
use Data::Dumper;
use XML::Twig;
use Path::Class;
use Path::Class::Entity;
use Benchmark qw(:all) ;
use utf8::all;
use Date::Simple qw(date);
use Try::Tiny;
use Image::Info qw(image_info dim);
use Switch;
use sparql;
use Graphics::ColorNames 2.0, 'all_schemes'; #(qw( hex2tuple ));
use Graphics::ColorNames::HTML;
use Graphics::ColorNames::Netscape;
use Graphics::ColorNames::Windows;
use GD;
use Color::Rgb;
use JSON qw( decode_json );
use Lingua::Identify qw/langof set_active_languages/;
set_active_languages(qw/fr/);
use List::Util qw(sum);
use List::Util qw(min max);
use Algorithm::Combinatorics qw(combinations);

#use Parallel::ForkManager;
#use IPC::Shareable;

GD::Image->trueColor(1);

binmode(STDOUT, ":utf8");

my $ua = LWP::UserAgent->new(
    ssl_opts => { verify_hostname => 0 },
    protocols_allowed => ['https'],
);


############  Parameters  ###########################
my $couleur="gris"; # default color mode (to be set if using the -color option): mono, gris, coul
my $illThemeNew="16";     # default IPTC theme (to be set if using the -setTheme option)
my $documentType="P";   # document type to be fixed with the -fixType option : PA = music score, C = map
my $illTechOld="filtre";   # illustration technique to be looked for (-fixType and -setTech options)
my $illTechNew="imp photoméca"; # illustration technique to be set (-setTech or -fixNoTech options-
my $illGenreNew="publicité"; # same for genre
my $illGenreOld="filtre"; # same for genre
my $illFonctionNew="repro/dessin"; # same for function
my $classifSource="md"; # illustration genre source : TensorFlow, md, hm, cw (-fixSource, -setGenre or -delGenre options)
my $classifCC="Frises"; # classe to be set/look

## Images parameters used for IIIF calls ##
my $factIIIF = 30;   # size factor for IIIF image exportation (%)
my $modeIIIF = "linear"; # "linear": export using $factIIIF size factor even for small/big images
# To avoid small images to be over reduced, set $modeIIIF to any other value
my $expandIIIF = 0.0 ; # expand/reduce the cropping. The final size will be x by 1 +/- $expandIIIF (%)
# Used for OCR (enlarge), image classification (reduce), faces extraction (enlarge)
my $reDimMinThreshold = 800;  # threshold (on the smallest dimension) under which the output factor $factIIIF is not applied (in pixels)
my $reDimMaxThreshold = 1000;

####################################
# for Classification APIs
my $locale = "en";
my $processIllThreshold = 20000;  # max ill to be processed
my $classifCBIR; # classification service: dnn, ibm, google, yolo, aws (to be used with -CC -DF -fixCBIRsource... commands)
# must be set by the user on the command line
my $classifAction;     # CC / DF. Set from the option asked by the user
my $sizeIllThreshold = 0; # do not classify illustrations if size <
my $CSthreshold = 0.1 ;   # confidence score threshold for using data classification
my $classifOnlyIfNoText = 0;
my $classifOnlyIfSeg = 0;
my $duplicates_threshold = 1.5;
### comment the next line to classify everything ###
#my $techClassif="photoméca gravure textile"; # classify illustrations only if tech is equal to $techClassif
my $functionClassif="repro/dessin"; # same for function
#(to be used with extract, classify, unify)

# mapping old genre to technic
my %genre2tech = (  "gravure" => "estampe/gravure",
                    "dessin" => "dessin",
                    "photo" => "photo",
                    "photog" => "imp photoméca",
                    "manuscrit" => "texte",
                    "textile" => "textile"
                );

## These 2  mappings are called by fixTech2Tech ##
# mapping old tech to technic
my %tech2tech = (
                    "photo" => "imp photoméca",
                    "photog" => "imp photoméca",
                    "photo/argentique" => "photo",
                    "texte" => "imp photoméca",

                    "gravure" => "estampe/gravure"
                                );
# mapping tech to function: to be set up depending the context
my %tech2fonction = (
                        "photo" => "repro/photo",
                        "photog" => "repro/photo",
                        "estampe" => "repro/estampe",
                        "texte" => "repro/texte"

                                );

## This conversion is called by fixGenre2Fonction ##
# mapping genre to fonction
my %genre2fonction = (  "carte" => "carte",
                        "carte postale" => "carte postale",
                        "partition" => "partition",
                        "bd" => "bd",
                        "couverture" => "couverture",
                        "affiche" => "affiche",
                        "ornement" => "ornement",
                        "graphique" => "graphique",


                        "papier-peint"=> "papier-peint",
                        "illustration de presse/dessin"=> "repro/dessin",
                        "illustration de presse/graphique"=> "graphique",
                        "illustration de presse/carte"=> "carte"

                                                );

# IBM Watson : watsoncc6@gmail.com / M---7
# https://console.bluemix.net/
# https://console.bluemix.net/dashboard/apps
# test
#curl -X POST -u "apikey:" --form "images_file=@native.jpg" "https://gateway.watsonplatform.net/visual-recognition/api/v3/classify?version=2018-03-19"
my $endPointWatson= "https://gateway.watsonplatform.net/visual-recognition/api/v3/";
my $apiKeyWatson= "";


# for Google Vision API : compte jpmoreux@gmail.fr
$endPointGoogle= "https://vision.googleapis.com/v1/images:annotate?key=";
$apiKeyGoogle= "";
# max words kept for OCR
$OCRlength = 200;

# for human faces detection
my $carreVSG=1 ;     # 1:1 format

# patterns for Watson API
my $motifClasseWatson = "\"class\": \"(.+)\"";       # "class": "beige color"
my $motifScoreWatson = "\"score\": (\\d+\.\\d+)";    # "score": 0.32198
# for Face Detection API
my $motifGenreWatson = "\"gender\": \"(.+)\"";    # "gender": "MALE",
#my $motifAgeMax = "\"max\": (\\d+)";    # "max": 54
my $motifAgeMinWatson = "\"min\": (\\d+)";    # "min": 44
my $motifHautWatson = "\"height\": (\\d+)";    # "height": 540
my $motifLargWatson = "\"width\": (\\d+)";    # "width": 640
my $motifXoWatson = "\"left\": (\\d+)";    # "left": 140
my $motifYoWatson = "\"top\": (\\d+)";    # "top": 140

# patterns for Google API
my $motifClasseGoogle = "\"description\": \"(.+)\"";
my $motifScoreGoogle = "\"score\": (\\d+\.\\d+e?-?\\d+)";
my $motifCoulRGoogle = "\"red\": (\\d+)";
my $motifCoulVGoogle = "\"green\": (\\d+)";
my $motifCoulBGoogle = "\"blue\": (\\d+)";
my $motifCouleursGoogle = "\"colors\": \\[(.*)\\]"; # non-greedy
my $motifTexteGoogle = "\"description\": (.+)";
my $motifVerticesGoogle = "\"vertices\": \\[(.*?)\\]"; # non-greedy
#my $motifVerticesGoogle = "\"vertices\": \\[(.+)\\]";
my $motifCropYGoogle = "\"y\": (\\d+)";
# face detection
my $motifVisageGoogle = "\"boundingPoly\":" ;
my $motifScoreVisageGoogle = "\"detectionConfidence\": (\\d+\.\\d+)";

######################
# for importation of external data (TensorFlow classification data or image hashing)
my $dataFile = "data.csv"; # input file name
#my $dataFile = "TNA-hash.csv";

######################
# for translation of classification tags
#my $dataFile; # lexicon file for translation of CBIR tags
my $googleDict = "_lexiques/dict-google-en2fr.csv";
my $ibmDict = "_lexiques/dict-ibm-en2fr.csv";
my $yoloDict = "_lexiques/dict-yolo-en2fr.csv";
my $hmDict = "_lexiques/dict-hm-en2fr.csv";

# for TensorFlow : parameters
my $lookForAds=1 ;		# to be unset for OLR newspapers where ads are already recognized
my $TFthreshold=0.2; 	# threshold for confidence score
my $classesNumber;		# number of classes in the TensorFlow classification data
my $forceTFOnMD=0; 		# force TF classifications on metadata classifications (in unify)
my $forceTFOnHM=0; 		# force TF classifications on human classifications (in unify)
my @externalData; # data structure for import
my @listeDocs ;
my @listeClasses ;

# for image hashing and other stuff
%imageData = (); # hash table of file name/hash value  pairs

# for exportation of classes
my $OUTFile="classes-$locale.txt";
my $OUTfh;

# for accessing local image files
$localBasexInstall = "/Applications/basex924/webapp/static/img/";

# semantic tags stuff
my %CCfix = (
              "Textiles et tissus"=> "Textiles et tissus"
              );
my $CCupdate;

#### COLORS ####
# for color names identification
$rgb = new Color::Rgb(rgb_txt=>'./rgb.txt');
$imgFoo = new GD::Image(100, 100);
$n = 0;
our %COLORS;
tie %COLORS, 'Graphics::ColorNames', qw(HTML Netscape Windows);  #all_schemes();

foreach my $color (keys %COLORS) {
  #print $color;
  #print  " / ".$COLORS{$color}."\n";
  @rgb  = $rgb->hex2rgb($COLORS{$color});
	#print @rgb;
  $imgFoo->colorAllocate(@rgb);  #hex2tuple( $COLORS{$color}
  $n++;
}
#print "\n-----------\ncolor table: $n values\n";

my @couleurs =(
# ibm
'alabaster color','albâtre','alizarine red color','rouge alizarine','ash grey color','gris cendré','azure color','azur (couleur)',
'beige color','beige','black color','noir','blue color','bleu','bottle green color','vert bouteille','brick red color','rouge brique','carnation color',
'oeillet (couleur)','charcoal color','charbon (couleur)','chestnut color','noisette (couleur)','chocolate color','chocolat (couleur)','claret red color',
'rouge bordeaux (couleur)','coal black color','noir charbon','copper color','copper','cuivre','cuivre (couleur)','crimson color','pourpre','dark red color','rouge foncé',
'emerald color','émeraude (couleur)','gray color','gris','green color','vert','greenishness color','verdâtre','Indian red color','rouge indien','ivory color',
'ivoire (couleur)','jade green color','vert de jade','lemon yellow color','jaune citron','light brown color','marron clair','maroon color','marron','olive color',
'olive (couleur)','olive green color','vert olive','orange color','orange (couleur)','pale yellow color','jaune pâle','pink color','rose (couleur)','purple color',
'violet','reddish brown color','brun rougeâtre','reddish orange color','orange rougeâtre','rose color','rose pâle','sage green color','vert sauge','sanguine (red) color',
'sanguine (rouge)','sea green color','vert d\'eau','steel blue color','bleu acier','tan color','havane (couleur)','Tyrian purple color','pourpre tyrien','ultramarine color',
'bleu outremer','yellow color','jaune','khaki','kaki',

# google
'black','noir','black and white','noir et blanc','blue','bleu','blueviolet','bleu violet','beige','beige','brown','marron','cadetblue','bleu cadet','cornflowerblue','bleuet',
'darkbrown','marron foncé','darkgray','gris foncé','darkgreen','vert foncé','darkgreencopper','vert cuivre foncé','darkolivegreen','vert olive foncé','darkred','rouge foncé',
'darkslategrey','gris ardoise foncé','dimgrey','gris foncé','dustyrose','vieux rose','gray','gris','green','vert','greencopper','vert cuivre','greenyellow','vert jaune','grey',
'gris','indianred','rouge indien','lightblue','bleu clair','lightgray','gris clair','lightgrey','gris clair','lightsteelblue','bleu clair','lightwood','bois clair','limegreen',
'vert citron','mandarianorange','orange mandarine','mediumgoldenrod','jaune d\'or','mediumturquoise','turquoise moyen','midnightblue','bleu nuit','oldgold','vieil or','orange',
'orange','orangered','rouge-orange','palegreen','vert pâle','pink','rose','darktan','brun foncé','darkwood','bois foncé','maroon','bordeaux (couleur)','mediumwood','bois moyen',
'purple','violet','red','rouge','scarlet','écarlate','sienna','terre de sienne','newtan','beige pâle','salmon','saumon','teal','bleu canard','turquoise','turquoise','verydarkbrown',
'marron très foncé','verylightgrey','gris pâle','violet','violet','white','blanc','Caramel color','caramel (couleur)','Cobalt blue','bleu cobalt','Electric blue','bleu électrique',
'Majorelle blue','bleu majorelle'
);

#getColorName("100","23","39");
#say getColorName(87,82,85);
#die;

#say isColor("brun_rougeâtre");
#die

#######################################################

#################
#  patterns for XML document analysis
# for ARK IDs
$motifArk = "\<ID\>(.+)\<\/ID\>" ;
$motifNotice = "\<notice\>(.+)\<\/notice\>" ;
# for illustrations
$motifIll = "<ill " ;
##################

# Gallica root IIIF URL
$urlGallicaIIIF = "https://gallica.bnf.fr/iiif/ark:/12148/";
$urlGallica = "https://gallica.bnf.fr/ark:/12148/";
# TNA root url
$urlTNA = "https://images.nationalarchives.gov.uk/assetbank-nationalarchives/action/viewAsset?index=240&total=1000&view=viewSearchItem&id=";
# data.bnf.fr endpoint
my $endPointData = "http://data.bnf.fr/sparql";

# ID ark
my $idArk;
# number of documents analysed
my $nbDoc=0;
# number of illustrations
my $nbTot=0;
my $nbTotIll=0;
my $nbFailIll=0;
my $nbTotFiltre=0;
my $nbTotCC=0;
my $nbTotDF=0;
my $nbTotCol=0;
my $nbTotPub=0;
my $nbTotThem=0;
my $nbTotThemeMD=0;
my $nbTotThemeHM=0;
my $nbTotThemeCW=0;
my $nbTotThemeInconnuFin=0;
my $nbTotGen=0;
my $nbTotGenTF=0;
my $nbTotGenMD=0;
my $nbTotGenHM=0;
my $nbTotGenInconnu=0;
my $nbTotGenFin=0;
my $nbTotSourceGenInconnu=0;
my $nbTotData=0;
my $nbTotEchec=0;
my $nbTotTrans=0;

# illustration ID currently analysed
my $idIll;

# output folder
my $OUT = "OUT_img";
#my $OUT = "/Volumes/BNF-dev/Dev/GallicaPix/Gallica/Images_Gallica/Extraction-Vogue-v2_30";
#my $OUT = "/Volumes/BNF-demo/GallicaPix/Images_Gallica/_extraction-IMG-pour-Classif/FR-ads_1910-1920";

# option set on the command line
my $OPTION;

$msg = "\nUsage : perl toolbox.pl -service IN [options]
services:
-info: give some stats on the illustrations
-del : suppress the files with no illustrations
-setID : renumber the illustrations ID
-setFaceID : number the faces ID
-extr : extract the illustration files
-extrClasses : list the visual recognition classes
-extrCC : extract the illustration files of a specific class
-extrFiltered : extract the filtered illustrations files
-extrFace : extract the faces files
-extrGenre : extract the illustration files of a specific genre
-extrNotClassif: extract the illustration files not yet classified
-crops : generate the illustration crops as overlays
-color: identify the color mode
-setColor : set the color mode
-importColors : import color values (hex)
-importTNA : import images ID (The national Archives)
-setTheme : set the theme
-setTech : set the technique (drawing, photo, ...)
-fixNoTech: set the technique if unknown
-fixNoGenre: set the genre if unknown
-fixNoFunction: set the function if unknown
-setGenreFromCC : set the genre from the classification tags
-fixTech2Tech
-fixGenre2Tech
-fixGenre2Function
-fixType : set the document type from the illustration technique
-fixSource : set the classification source
-fixColor : set the color attribute on CBIR tags
-fixCBIRsource : set the CBIR source (IBM Watson, AWS, Google)
-fixCBIRClassif : update the classification attribute
-fixCC : update the tags from a dictionary
-fixLang : set the lang attribute to 'en' on CBIR tags
-fixGoogleHL
-fixPageSize : add the pixels size at the page level
-fixAd : set the ads attribute
-unifyFunction : compute the final function (function, filter, pub)
-unifyTech : compute the final technique (technique, filter, pub)
-unifyTheme : compute a final theme
-CC : classify image content with an API
-DF : detect faces with an API
-OCR : extract texts from illustrations
-importCC : import content classification data
-translateCC : translate content classification data
-importDF : import face detection data
-addCC : add a new tag
-delCC : suppress content classification tags
-delAllCC : suppress the content classification metadata
-delAllDF : suppress the face detection metadata
-delGenre : suppress the genre classifications
-delEmptyGenre : suppress the empty genre classifications
-delFilter : suppress the filtering attributes (genre, ad)
-delNoisyText : delete noisy text
-delDuplicates : filter duplicates illustrations
-importTF : process the TensorFlow data to classify the illustration genres
-TFunFilter : use the TensorFlow data to unfilter false positive filtered illustrations
-hash : import the hash data for image similarity
-data: find data.bnf.fr links

IN : input files directory

Options:
-document type (values: news), to be used with the -TF command
-CBIR mode: API or CNN model (values: ibm, google, yolo, dnn, hm, md) to be used with CC or DF options
-background color importation (values: bckg, no_bckg), to be used with the -importColors command
	";


#say findDataBnf("bpt6k70861t","work");
#die;

####################################
####################################
##             MAIN               ##

if (scalar(@ARGV)<2)  {
	die $msg;
}

# list of subroutines
my %actions = ( del => \&del,
                info => "hd_info", # handler XML:Twig
                setID => "hd_updateID",
                setFaceID => "hd_updateFaceID",
                extr => "hd_extract",
                crops =>  \&crops,
                updateCrops => "hd_updateCrops",
								extrFiltered => "hd_extractFiltered",
								extrGenre => "hd_extractGenre",
                extrNotClassif => "hd_extractNotClassif",
                extrFace => "hd_extractFace",  #\&extrFace,
								fixFace => \&fixFace,  # bug on CS=0
                filterFace => "hd_filterFace",
								color => "hd_color",
                setColor => "hd_updateColor",
                importColors => "hd_importColors",
                importTNA => "hd_importTNA",
                setTheme => "hd_updateTheme",
								setTech => "hd_updateTech",
                setGenreFromCC => "hd_setGenreFromCC",
								fixType => "hd_fixType",
								fixSource => "hd_fixSource",
								fixLeg => "hd_fixLeg",
								fixCBIRsource => "hd_fixCBIRsource",
								fixCBIRClassif => "hd_fixCBIRClassif",
                fixCC => "hd_fixCC",
                addCC => "hd_addCC",
                fixLang => "hd_fixLang",
                fixGoogleHL => "hd_fixGoogleHL",
                fixColor => "hd_fixColor",
                fixPageSize => "hd_fixPageSize",
								fixAd => "hd_fixAd",
								fixNoGenre => "hd_fixNoGenre",
                fixNoTech => "hd_fixNoTech",
                fixNoFunction => "hd_fixNoFunction",
                fixGenre2Tech => "hd_fixGenre2Tech",
                fixGenre2Function => "hd_fixGenre2Function",
                fixTech2Tech => "hd_fixTech2Tech",
                fixGenrePerio => "hd_fixGenrePeriodicals",
                fixDrawingPerio => "hd_fixDrawingPeriodicals",
								fixRot => "hd_fixRotation",
								unifyFunction => "hd_unifyFunction",
                unifyTech => "hd_unifyTech",
								unifyTheme => "hd_unifyTheme",
                delCC => "hd_delCC",
                delAllCC => "hd_deleteContent",
                delAllDF => "hd_deleteContent",
                delColors => "hd_deleteColors",
								delGenre => "hd_deleteGenre",
								delEmptyGenre => "hd_deleteEmptyGenre",
                delDuplicateGenre => "hd_delDuplicateGenre",
								delEmptyLeg => "hd_deleteEmptyLeg",
								delFilter => "hd_deleteFilter",
                delNoisyText => "hd_deleteNoisyText",
                delDuplicates => "hd_deleteDuplicates",
								CC => "hd_classifyCC",
								DF => "hd_classifyDF",
								OCR => "hd_OCR",
								importDF => "hd_importCC",
								importCC => "hd_importCC",
                translateCC => "hd_translateCC",
								extrClasses => "hd_extrClasses",
                extrCC => "hd_extrCC",
                extrMD => "hd_extrMD",
								importTF => "hd_TFfilter",
								TFunFilter => "hd_TFunFilter",
								data => \&data,
								hash => "hd_hash"

              );

# service selected by user
$SERVICE=shift @ARGV;

# suppress the -
$SERVICE= substr($SERVICE,1);

if (not($actions{$SERVICE})) {
 die $msg}

$DOCS=shift @ARGV;

# optional arg
$OPTION=shift @ARGV;

# classification type
switch ($SERVICE) {
 case "importCC" {$classifAction="CC"}
 case "importDF" {$classifAction="DF"}
 case "CC" {$classifAction="CC"}
 case "fixCC" {$classifAction="CC"}
 case "setGenreFromCC" {$classifAction="CC"}
 case "extrClasses" {$classifAction="CC"}
 case "extrMD" {$classifAction="CC"}
 case "DF"  {$classifAction="DF"}
 case "delAllDF"  {$classifAction="DF"}
 case "delAllCC"  {$classifAction="CC"}
 case "delCC"  {$classifAction="CC"}
 case "addCC"  {$classifAction="CC"}
 case "delColors"  {$classifAction="Color"}
 case "translateCC" {$classifAction="CC"}
 case "extrClasses" {$classifAction="CC"}
 case "extrCC" {$classifAction="CC"}
 case "extrNotClassif" {$classifAction="CC"}
 case "info"  {$classifAction="foo"}
 case "extrFace"  {$classifAction="foo"}
 case "filterFace"  {$classifAction="foo"}
}

if ($classifAction and not $OPTION) {
  die " ### CBIR mode (ibm, google, dnn, yolo, hm, md) must be set on the command line!\n";
} elsif ($classifAction) {
  $classifCBIR=$OPTION}

if ($SERVICE eq "importColors" and not $OPTION) {
    die " ### Background color option (no_bckg, bckg) must be set on the command line!\n";
  } elsif ($classifAction) {
    $classifCBIR=$OPTION}

if ((($SERVICE eq "DF") or ($SERVICE eq "CC")) and ($modeIIIF ne "linear")) {
    say " *** modeIIIF must be set to linear for object detection! *** \n ... fixing";
    $modeIIIF = "linear";
  }

if ($SERVICE eq "addCC") {
      say " ********************************************";
      print " PLEASE enter the tag's name (EN)\n >";
      $CCupdate = <STDIN>;
      chomp $CCupdate;
      say " a new '$classifCBIR' tag with value '$CCupdate' is going to be added to all the illustrations";
      continuer();
    }

if ($SERVICE eq "delCC") {
          say " ********************************************";
          print " PLEASE enter the tag's name (EN)\n >";
          $CCupdate = <STDIN>;
          chomp $CCupdate;
          say " all the '$classifCBIR' tags with value '$CCupdate' will be deleted";
          continuer();
        }
if ($SERVICE eq "delAllCC") {
          say " ********************************************";
          say " all the '$classifCBIR' tags will be deleted from all the illustrations";
          continuer();
                }

if ($SERVICE eq "fixCC")  {
          say " ********************************************";
          say " all the '$classifCBIR' tags are going to be updated";
          say " tags dictionary: ";
          foreach $key (keys %CCfix) {
            say " $key -> ".$CCfix{$key};
           }
          continuer();
        }

if (($SERVICE eq "DF") and ($classifCBIR eq "ibm")) {
   say " ********************************************";
   die " ### IBM Watson API no longer offers facial detection!\n";
  }

if (index("CC DF extrFace filterFace extr extrNotClassif OCR",$SERVICE) != -1) {
  say " ********************************************";
  if ($classifCBIR) {say " CBIR mode: $classifCBIR "}
  if ($techClassif) {say " techniques to be processed: $techClassif"}
  else {say " all techniques will be processed"}
  if ($functionClassif) {say " functions to be processed: $functionClassif"}
  else {say " all functions will be processed"}
  say " image mode (linear: apply the same % on all images; \n  std: apply the % except for small or large images): $modeIIIF ";
  say " image size % (MUST be 100% if we process the original image file): $factIIIF%";
  say " image min size: $reDimMinThreshold px";
  say " image max size: $reDimMaxThreshold px";
  say " image expansion/shrink %: ".100*$expandIIIF."%";
  continuer();
}

say  " ...service is '$SERVICE'";

if ($SERVICE eq "importCC") {
  say " ********************************************";
  say " file: $dataFile ";
  say " CS: $CSthreshold ";
  say " TensorFlow CS: $TFthreshold";
  say " IIIF factor: $factIIIF%";
  continuer();
}

if ( ($SERVICE eq "translateCC") ) {
  say " ********************************************";
  switch ($classifCBIR) { # translation of CBIR tags
    case "google" {$dataFile = $googleDict}
    case "ibm" {$dataFile = $ibmDict }
    case "yolo" {$dataFile = $yoloDict }
    case "hm" {$dataFile = $hmDict }
  }
  say "language: $locale";
  say " dictionary: $dataFile ";
  continuer();
}

if ($SERVICE eq "OCR") {
  say " ********************************************";
  say " max words: $OCRlength ";
  continuer();
}


if (($SERVICE eq "hash") or ($SERVICE eq "importColors") or ($SERVICE eq "importTNA") ) {
  say " ********************************************";
  say " file: $dataFile ";
  continuer();
}

if ($SERVICE eq "extrCC")  {
  say " ********************************************";

  say " class: $classifCC ";
  say " CBIR mode: $classifCBIR ";
  continuer();
}


if  ($SERVICE eq "extrClasses") {
  say " ********************************************";
  say " language: $locale";
  say " CBIR mode: $classifCBIR ";
  continuer();
}

# folders
if(-d $DOCS){
		say "Reading $DOCS folder...";
	}
	else{die "### Can't find $DOCS!   ###\n";
	}

if(-d $OUT){
		say "Writing in $OUT...";
	}
	else{
		mkdir ($OUT) || die ("###  Can't create folder $OUT!  ###\n");
    say "Making folder $OUT...";
	}


##############
# output the classification data in a txt file for service extrClasses
if (($SERVICE eq "extrClasses") or ($SERVICE eq "extrMD") or ($SERVICE eq "translateCC")){
	say "Writing in $OUTFile";
	open($OUTfh, '>',$OUTFile) || die "### Can't write in $OUTFile file: $!\n";
}

################
# TensorFlow, hash or face detection case: we have to extract the classification data first (from a .csv file)
if ((index($SERVICE, "import") != -1) or ($SERVICE eq "hash") or ($SERVICE eq "translateCC")) {
	 say "Reading $dataFile...";
	 # building the data
	 open(DATA, $dataFile) || die "### Can't open $dataFile file: $!\n";
	 #seek $fhTF, 0, 0;
   my $nbData=0;
   while (<DATA>) {
   	 #say $_;
     $nbData += 1;
     #push @externalData, [split /\t/]; # tokenize the data using TAB character
     push @externalData, [split /\;/]; # tokenize the data using ; character
   }
   close DATA;
   say "-> $nbData data";
}


####################
# TensorFlow service
if (index($SERVICE, "TF") != -1) {
   buildTFdata();
   #say Dumper @externalData;
	 #say Dumper @listeDocs;
}
continuer();

#isTFclassify("bpt6k6534085k");
#say isHashed("bpt6k65340845-93-2.jpg");
#die;

#say Dumper (@externalData);

# we build a dictionary
if (($SERVICE eq "hash") or ($SERVICE eq "importDF") or ($SERVICE eq "importColors")
  or ($SERVICE eq "importTNA")  or ($SERVICE eq "importCC") or ($SERVICE eq "translateCC")) {
   foreach (@externalData) {
     my $key = $_->[0] ;		#  illustration file name
     chop $_->[1];
     my $value = $_->[1] ;
     say " $key -> $value";
     $imageData{$key} = $value ; #  value
    }
    say "--- items in $dataFile file: ". keys %imageData;
    continuer();
}

#say Dumper %imageData;

##############
# for TRANSLATION: dictionary choice
if ($SERVICE eq "translateCC") {
    ##$dataFile = "dict-".$OPTION.".csv";
    say " all the '$classifCBIR' tags are going to be translated to FR";
    say " ********************************************";
    continuer();
  }

#say isHashed("bpt6k6519900k-33-3");
#die

#say en2fr("pointe d'argent");
#die

# reading the metadata documents
my $dir = dir($DOCS);
say "--- documents: ".$dir->children(no_hidden => 1);

#my $pm = new Parallel::ForkManager(4);

# recurse analysis of the folder
$dir->recurse(depthfirst => 1, callback => sub {
	my $obj = shift;

  if ((($SERVICE eq "CC") or ($SERVICE eq "DF")) and ($classifCBIR eq "ibm")
     and ($nbTotIll >= $processIllThreshold)) {
    say "## $processIllThreshold processed: stop ##";
    last
  }
	if ($obj->basename ne $DOCS)  { # jumper the current folder
	  if (($obj->is_dir) ){
		   say "\n ........folder: ".$obj->basename;
		 } else {
		 	# jump OSX files
		 	if (index($obj->basename , "DS_Store") == -1) {
				#$pm->start and next; # do the fork
		 		if (ref ($actions{$SERVICE})) {
		 		   $nbDoc += $actions{$SERVICE}->($obj,$obj->basename);} # call of an ad hoc function
		 			else
		 			 {$nbDoc += generic($obj,$obj->basename);}}  # call of a generic function
				#$pm->finish; # do the exit
				}
  		}
});

#$pm->wait_all_children;

say "\n\n=============================";
say "$nbDoc documents analysed in ".$dir->children(no_hidden => 1)." folders";
if ($nbTot != 0) {say " $nbTot illustrations analysed";}
if ($nbFailIll != 0) {say " $nbFailIll failed illustrations";}
if ($SERVICE eq "del") {
  say "$nbTotIll files deleted ";	}
elsif ($SERVICE eq "info") {
  say "$nbTotIll illustrations ";
	say "(including $nbTotFiltre filtered and $nbTotPub illustrated ads)";
  say "----------";
  say $nbTotIll - $nbTotFiltre - $nbTotPub;
	say " * $nbTotThem final theme classifications ";
  say "   $nbTotThemeMD MD   ";
	say "   $nbTotThemeHM HM   ";
	say "   $nbTotThemeCW CW   ";
	if ($nbTotThemeInconnuFin != 0) {say "   $nbTotThemeInconnuFin unknown final theme !!!!!!";}
	say " * $nbTotGen final genre classifications ";
	say "   $nbTotGenInconnu genres with no value";
	say "   $nbTotSourceGenInconnu genres with no valid source attribute";
  say "   $nbTotGenMD MD  ";
	say "   $nbTotGenTF TF   ";
	say "   $nbTotGenHM HM   ";
  say " * $nbTotCol color classifications ";

  say " * $nbTotCC illustrations with $classifCBIR image content indexing";
  say " * $nbTotDF illustrations with $classifCBIR face detections";
}
elsif (($SERVICE eq "translateCC") or ($SERVICE eq "delCC") or ($SERVICE eq "delAllCC") or ($SERVICE eq "fixLang") or ($SERVICE eq "fixColor")) {
  say " * $nbTotIll illustrations with $classifCBIR image content indexing";
  say " * $nbTotTrans tags processed";
}
else {
  say " $nbTotIll illustrations processed ";
  if ($nbTotDF!=0) {say "$nbTotDF data processed"}
}

say "=============================";

if (($SERVICE eq "extrClasses") or ($SERVICE eq "extrMD") or ($SERVICE eq "translateCC")){
	close($OUTfh);}
########### end MAIN ##################
#######################################


sub buildTFdata {

# build the TF classes list
@listeClasses = @{$externalData[0]}; # dereferencing the first table (which is the header)
pop @listeClasses; # suppress the last heading names: foundClass, realClass...
pop @listeClasses;
pop @listeClasses;
pop @listeClasses;
$classesNumber=scalar(@listeClasses);
if ($classesNumber<2){
   say "### $classesNumber classes ###";
   say "### something wrong with the CSV separator character? ###";
   die
}
else {
  say "-> $classesNumber classification classes found";
  say Dumper @listeClasses;}

# building the documents list
shift @externalData; # suppress the first item (headings)
foreach (@externalData) {
  #say $_->[-1] ;
  push @listeDocs, $_->[-1] # the last cell is the illustration file name
 }
#shift @listeDocs;
#say Dumper @externalData;
#say Dumper @listeDocs;
say "-> ".scalar(@externalData)." illustrations found in the data";

}

###############################
# call of a generic service via a XML:Twig handler
sub generic {
	my $fic=shift;
	my $nomFic=shift;

	#say "*** Call of a generic service on file: ".$fic;
	my $fh = $fic->openr;
	if (not defined $fh) {
		say "### Error while reading: $fic ###";
		return 0}
	my $xml = $fic->slurp;

	# ID ark
	($idArk) = do { local $/; $xml =~ m/$motifArk/ };  #  global var
	if (not (defined $idArk)) {
  	   say "### ID unknown!";
			 close $fh;
       return 0}

   say "\n ID: $idArk";
   my $service=$actions{$SERVICE};
   #say " service: ".$service;
   my $t = XML::Twig->new(
   twig_handlers => {
       '/analyseAlto/contenus/pages/page/ills' => \&$service,}, # call of a XML handler on each <ills> element
    pretty_print => 'indented',
    );

   try {
     $t -> parse($xml);   }
   catch {
    warn "### ERROR while reading: $_ ###";
    say  "########################################";
		close $fh;
    return 0;
  };

  # commit the changes on the XML content
	open  $fh, '>', $fic or die $!;
	$t->print($fh);
	close $fh;
	return 1;
}


# ----------------------
# supprimer les fichiers de MD sans images décrites
sub del {
	my $fic=shift;
	my $nomFic=shift;

	say "******\nfile: ".$fic;

	my $fh = $fic->openr;
	if (not defined $fh) {
		say "### Error while reading: $fic ###";
		return 0}
	my $xml = $fic->slurp;
  # process the images
	(@ills ) = do { local $/; $xml =~ m/$motifIll/g };

	say " nb images : ".scalar(@ills);
	if (scalar(@ills)==0) {
		$nbTotIll++;
	  $fic->remove()
	  }
	return 1;
}


# ----------------------
# extract the faces as image files (non-generic because the XPath is specific)
# ** obsolete! **
sub crops {
	my $fic=shift;
	my $nomFic=shift;

	say "**************\nfile : ".$fic;
	my $fh = $fic->openr;
	if (not defined $fh) {
		say "### Error while reading: $fic ###";
		return 0}
	my $xml = $fic->slurp;

	($idArk) = do { local $/; $xml =~ m/$motifArk/ }; # ID ark
	if (not (defined $idArk)) {
  	   say "### ID unknown! ###";
       return 0}
  say "ark : $idArk";
  say  '..parsing on /analyseAlto/contenus/pages/page';
  my $t = XML::Twig->new(
    twig_handlers => {
       '/analyseAlto/contenus/pages/page' => \&hd_crops, },
    pretty_print => 'indented',
    );

   try {
     $t -> parse($xml);   }
   catch {
    warn "### Error while reading: $_ ###";
    say  "########################################";
    return 0;
  };

	close $fh;
	return 1;
}

sub fixFace {
	my $fic=shift;
	my $nomFic=shift;

	say "**************\nfile : ".$fic;
	my $fh = $fic->openr;
	if (not defined $fh) {
		say "### Error while reading: $fic ###";
		close $fh;
		return 0}
	my $xml = $fic->slurp;

	($idArk) = do { local $/; $xml =~ m/$motifArk/ }; # ID ark
	if (not (defined $idArk)) {
  	   say "### ID unknown! ###";
			 close $fh;
       return 0}
  say "ark : $idArk";

  my $t = XML::Twig->new(
    twig_handlers => {
       '/analyseAlto/contenus/pages/page/ills/ill/contenuImg["face"]' => \&hd_fixFace, },
    pretty_print => 'indented',
    );

   try {
     $t -> parse($xml);   }
   catch {
    warn "### Error while reading: $_ ###";
    say  "########################################";
		close $fh;
    return 0;
  };
	open  $fh, '>', $fic or die $!;
  $t->print($fh);
	close $fh;
	return 1;
}

# ----------------------
# find alignements to data.bnf
sub data {
	my $fic=shift;
	my $nomFic=shift;

  my $databnf;

	say "**************\nfile : ".$fic;
	my $fh = $fic->openr;
	if (not defined $fh) {
		say "### Error while reading: $fic ###";
		return 0}
	my $xml = $fic->slurp;

  # periodical
  if ($documentType eq "P") {
    ($ark) = do { local $/; $xml =~ m/$motifNotice/ }; # ID ark
  	if (not (defined $ark)) {
    	   say "### document's record unknown (<notice>)! ###";
         return 0}
    say "ark : $ark";
    $databnf = findDataBnf($ark."/date","about");
  }
  else {
    ($ark) = do { local $/; $xml =~ m/$motifArk/ }; # ID ark
  	if (not (defined $ark)) {
    	   say "### document's ID unknown! ###";
         return 0}
    say "ark : $ark";
    # try the Stories query
    $databnf = findDataBnf($ark,"studie");
	  # try the Works query
    if (not defined $databnf) {
		  $databnf = findDataBnf($ark,"work");
	  }
  }

  # indexing the illustrations
	if (defined $databnf) {
	 say " data.bnf.fr: ".$databnf;
   my $t = XML::Twig->new(
    twig_handlers => {
       '/analyseAlto/contenus/pages/page/ills' => sub {\&hd_data(@_,$databnf)}, },
    pretty_print => 'indented',
    );
   try {
     $t -> parse($xml);   }
   catch {
    warn "### Error while reading: $_ ###";
    say  "########################################";
    return 0;
  };

	# commit the changes on the XML content
	open  $fh, '>', $fic or die $!;
	$t->print($fh);
	close $fh;
	return 1;
} else {
	say " no data.bnf.fr link";
	return 1;}
}

# Query the data.bnf SPARQL endpoint
sub findDataBnf {my $ark=shift;
	             my $req=shift;
 my @tmp;
 my $url;

 say "looking for $req...";

# https://gallica.bnf.fr/ark:/12148/cb327877302/date
my $query_perio = <<END;
PREFIX rdarelationships: <http://rdvocab.info/RDARelationshipsWEMI/>
PREFIX dcterms: <http://purl.org/dc/terms/>
SELECT ?s ?auteur
WHERE
{
 ?s ?p <$urlGallica$ark>;
    dcterms:contributor ?auteur.
}
END

my $query_stories = <<END;
PREFIX bnfroles: <http://data.bnf.fr/vocabulary/roles/>
PREFIX rdarelationships: <http://rdvocab.info/RDARelationshipsWEMI/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dcterms: <http://purl.org/dc/terms/>
SELECT ?studies
WHERE {
?s ?p <$urlGallica$ark>;
 dcterms:subject ?o.
?person owl:sameAs ?o.
?studies dcterms:subject ?person
}
END

my $query_work = <<END;
PREFIX rdarelationships: <http://rdvocab.info/RDARelationshipsWEMI/>
 SELECT *
 WHERE {
	?s ?p <$urlGallica$ark>;
		 rdarelationships:workManifested ?work.
 }
END

if ($req eq "studie") {$query=$query_stories}
elsif ($req eq "work") {$query=$query_work}
elsif ($req eq "about") {$query=$query_perio}
else {
  say "#### Query $req undefined!";
	return undef}

#say $query;

my $sparql = sparql->new();
my $res = $sparql->query($endPointData,$query);
if (defined $res) {
	say " Response: ".$res;
	my @rows = split(/\s+/, $res); # split on separators
	if ($req eq "work")
	  {shift @rows; # discard the header, which has 3 lines
	   shift @rows;
	  shift @rows;}
	else {shift @rows} # one line
	#say Dumper (@rows);
	if (@rows)  {
	 while (my $row = shift @rows) {
     say $row;
	   #my $row = shift @rows;  # take the first line
 		 #my @urls = split("\"", $row); #the line can contains multiple URLs
 		 @tmp = grep(/$req/i, $row); # find an URL with the keyword
		 if (@tmp)
		   { say "--> hit";
         $url = $tmp[0];
	       last}
		}
	  if ($url) {
			$url =~ s/"//g; # suppress the ""
      say $url;
			return $url}
	  else {
			 say "#### Can't decode SPARQL response: $res !";
			 return undef}
	} else {return undef}
}
else
 { say "#### SPARQL: failed!";
   return undef}
}




#######################
## XML:Twig handlers ##
#######################

# extract stats info
sub hd_info {
   my ($t, $elt) = @_;

   my $tmp;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nbTotIll++;
		undef $tmp;
    $tmp = $ill->att("filtre"); # filtered illustrations
    if (defined $tmp) {
      $nbTotFiltre++;}
    # classif attribute
		undef $tmp;
    $tmp = $ill->att("classif");
    if (defined $tmp) {
     if (index($tmp,"CC".$classifCBIR) !=-1) { # we have CC classification
        $nbTotCC++;}
     if (index($tmp,"DF".$classifCBIR) !=-1){ # we have face detection
       $nbTotDF++;}
    }
		undef $tmp;
    $tmp = $ill->att("couleur"); # color attribute
    if (defined $tmp) {
      $nbTotCol++;}
		undef $tmp;
		$tmp = $ill->att("pub"); # ad attribute
    if (defined $tmp) {
      $nbTotPub++;}
		undef $tmp;

    #$tmp = $ill->first_child('theme'); # theme element
		my @themes= $ill->children('theme');
    foreach my $theme (@themes) {
			my $source = $theme->att("source");
			if (defined $source) {
				if ($source eq "md") {$nbTotThemeMD++}
				elsif ($source eq "hm") {$nbTotThemeHM++}
				elsif ($source eq "cw") {$nbTotThemeCW++}
				elsif ($source eq "final") {
					if ($theme->text() eq "") {$nbTotThemeInconnuFin++}
					else {$nbTotThem++}
			} else {say "### theme with no source !!! ###";
							}
			}
    }

    #$tmp = $ill->first_child('genre'); # genre element
		my @genres= $ill->children( 'genre');
		foreach my $genre (@genres) {
			my $source = $genre->att("source");
		  if ($source) {
			 if (($genre->text() eq "inconnu") or ($genre->text() eq ""))
			  {say "### empty genre ###";
				 $nbTotGenInconnu++}
			 else {
				switch ($source) {
				 case "md" {$nbTotGenMD++}
				 case "TensorFlow" {$nbTotGenTF++}
				 case "hm" {$nbTotGenHM++}
				 case "final" {$nbTotGen++}
				 else {say "### unknown value for attribute source !!! ###";
			 				$nbTotSourceGenInconnu++}}
			  }
			}
 			else {say "### genre with no source attribute !!! ###"}
		}
  }
}

# extract stats info on classification
sub hd_extrClasses {
   my ($t, $elt) = @_;
   my $tmp;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nbTotIll++;
    my $classif = $ill->att("classif"); # classif attribute
    say "...looking for $classifAction$classifCBIR tags";
    if ((defined $classif) and (index($classif, $classifAction.$classifCBIR)!= -1)) { # we have CC classification
		  # the  classification elements
		  #my @contenus= $ill->children( 'contenuImg');

			my $nav = "contenuImg[\@source='".$classifCBIR."' and \@lang='$locale']";
			my @contenus= $ill->children($nav);
			say "CC metadata : ".scalar(@contenus);
			foreach my $contenu (@contenus) {
      	print $OUTfh $contenu->text()."\n";
			}
    }
	}
}

sub hd_extrCC {
   my ($t, $elt) = @_;
   my $tmp;

   my $page = $elt->parent->att('ordre');
   say "\n page: $page";

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nbTotIll++;
    my $classif = $ill->att("classif"); # classif attribute
    say "...looking for $classifAction$classifCBIR tags";
    if ((defined $classif) ) {
      #   and (index($classif, $classifAction.$classifCBIR)!= -1)) { # we have CC classification
			my $nav = "contenuImg[text()='$classifCC' and \@source='$classifCBIR' and \@lang='$locale']";
			my @contenus= $ill->children($nav);
			say " CC metadata : ".scalar(@contenus);
      if (scalar(@contenus) ==0) {
			#foreach my $contenu (@contenus) {
      	#say $contenu->text();
        if (IIIF_get($ill,$idArk,$ill->att('n'),$page)) {
          $nbTotIll++;}
		#	}
    }
    }
	}
}

sub hd_extrMD {
   my ($t, $elt) = @_;
   my $tmp;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nbTotIll++;
    say "...looking for $classifCBIR tags";

		  # the  classification elements
		  #my @contenus= $ill->children( 'contenuImg');

			my $nav = "contenuImg[\@source='".$classifCBIR."']";
			my @contenus= $ill->children($nav);
			say "CC metadata : ".scalar(@contenus);
			foreach my $contenu (@contenus) {
      	print $OUTfh $contenu->text()."\n";
    }
	}
}


sub removeClassif {
	my $classif=shift;
	my $service=shift;

 if ($classif eq $service) { return undef}
 else {
   my @services = split(/\ /, $classif);
   @services = grep {$_ ne $service} @services;
   return join(' ', @services)
 }
}

# suppress all the content classification metadata (CC or DF from a specific source)
sub hd_deleteContent {
   my ($t, $elt) = @_;

   my $cTag=$classifAction.$classifCBIR;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    print "\n$nill: ";
    # if ($ill->att('seg')) {
    # suppress the  classif attribute
    my $tmp = $ill->att("classif");
    if ((defined $tmp) and (index($tmp,$cTag) != -1)) { # we have classification
       my $newClassif = removeClassif($tmp,$cTag);
       $ill->del_att("classif");
       if ($newClassif) {$ill->set_att("classif",$newClassif)}
       $nbTotIll++;

       # suppress the  classification elements
       my $nav = "contenuImg[\@source='".$classifCBIR."']";
       my @contenus= $ill->children($nav );
       #say "nbre de MD CC : ".scalar(@contenus);
       foreach my $contenu (@contenus) {
         my $ct = $contenu->text();
     	   print "..content: ".$ct;
         if (index($cTag,"DF") != -1) {  # face detection case
           if ($ct eq "face" ) {
             print " - \n";
             $nbTotTrans++;
             $contenu->delete;}
         }
         else {  # content classification case
          if ($ct ne "face" ) {
            print " - \n";
            $nbTotTrans++;
            $contenu->delete;}
         }
      }
    }
  #}
    else {print " no $cTag classification"}
   }
}

sub hd_deleteColors {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    print "\n$nill: ";
    $nbTotIll++;

    # suppress the  classification elements
    my $nav = "contenuImg[\@source='".$classifCBIR."']";
    my @contenus= $ill->children($nav );
    #say "nbre de MD CC : ".scalar(@contenus);
    foreach my $contenu (@contenus) {
        my $ct = $contenu->text();
     	  say "..content: ".$ct;
        print " - ";
        $contenu->delete;
         }
      }
}

# translate to French all the content classification metadata (from a specific source)
sub hd_translateCC {
   my ($t, $elt) = @_;

   my $cTag=$classifAction.$classifCBIR;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    say "\n$nill: ";
    $nbTotIll++;
    # handle the  classification elements
    my $nav = "contenuImg[\@source='".$classifCBIR."' and \@lang='en']";
    my @contenus= $ill->children($nav);
    say "English CC contents: ".scalar(@contenus);
    foreach my $contenu (@contenus) {
         my $ct = $contenu->text();
         #my $score = $contenu->att('CS');
         #if ((length $ct < 3) and ($ct ne "ox")) {$contenu->delete;
           #print "  --deleting-- '$ct' \n";
         #} # suppress noisy tags
         if ($ct eq "face" ) { next} # don't translate "face" tag
         my $fr = en2fr($ct);
         if ($fr) { # do we already have a FR translation?
            my $query = $fr;
            $nav = "contenuImg[text()=\"".$query."\" and \@source='".$classifCBIR."' and \@lang='fr']";
            if ($ill->children($nav)) {
              print "  '$ct' already translated as '$fr'\n"}
            else {
     	        print "  translating '$ct' -> '$fr' \n";
              my $copy = $contenu->copy($contenu); # copy the EN tag
              $copy->set_att(lang => 'fr');
              $copy->set_text($fr);
              $copy->paste($ill); # paste the translation
              $nbTotTrans++;
                }
          }
          else {
            print " #### NO TRANSLATION for $ct #### \n\n";
            print $OUTfh "$ct\n";
        }
      }
   }
 }

# add a new tag
sub hd_addCC {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      $nill = $ill->att('n');
      say "\n$nill: ";
      $nbTotIll++;
      $ill->insert_new_elt('contenuImg', $CCupdate)
        ->set_atts("lang"=>"en","CS"=>"1.0","source"=>$classifCBIR);
      print " +";
      $nbTotTrans++;
    }
}

 # fix tags, using a dictionary
 sub hd_fixCC {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
     $nill = $ill->att('n');
     say "\n$nill: ";
     $nbTotIll++;
     # handle the  classification elements
     my $nav = "contenuImg[\@source='".$classifCBIR."' ]";
     my @contenus= $ill->children($nav);
     say "CC contents: ".scalar(@contenus);
     foreach my $contenu (@contenus) {
          my $ct = $contenu->text();
          $fix = $CCfix{$ct};
          if ($fix) { #
               $contenu->set_text($fix);
               $nbTotTrans++;
               say "$ct ... fixed to $fix"
             }
           }
       }
}

# fix technique from tags, using a dictionary
sub hd_setGenreFromCC {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    say "\n$nill: ";
    $nbTotIll++;
    # handle the  classification elements
    my $nav = "contenuImg[\@source='".$classifCBIR."' ]";
    my @contenus= $ill->children($nav);
    say "CC contents: ".scalar(@contenus);
    foreach my $contenu (@contenus) {
         my $ct = $contenu->text();
         $fix = $CCfix{$ct};
         if ($fix) {
             my @techs= $ill->children('tech');
             foreach my $tech (@techs) {
              if ($tech->text() eq $illTechOld) {
                  print " - ";
                  $nbTotIll++;
                  $tech->delete;}
              }
              $ill->insert_new_elt("tech","$illTechNew")->set_atts("source"=>$classifSource, "CS"=>"1");
              $ill->insert_new_elt("tech","$illTechNew")->set_atts("source"=>"final");
              say "$illTechOld ... fixed to $illTechNew"
            }
          }
      }
}

# del tags
sub hd_delCC {
   my ($t, $elt) = @_;

   my $cTag=$classifAction.$classifCBIR;
   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    say "\n$nill: ";
    $nbTotIll++;

    # handle the  classification elements
    my $nav = "contenuImg[\@source='".$classifCBIR."' ]";
    my @contenus= $ill->children($nav);
    say "CC contents: ".scalar(@contenus);
    foreach my $contenu (@contenus) {
         my $ct = $contenu->text();
         if ($ct eq $CCupdate) { #
              $contenu->delete;
              $nbTotTrans++;
              say "  $ct ... deleted"
            }
          }
      }

}


sub en2fr {my $ct=shift;
  print "looking for '$ct'... ";

  if (($tmp=$imageData{$ct}) or ($tmp=$imageData{lc($ct)}))  {
    return $tmp}
  else {return 0}
}

sub googleTrans {
  my $ct=shift;

    my @words = @ARGV;
    map uri_escape, @words;
    my $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=fr&dt=t&q=$ct";
    say $url;

    my $ua = LWP::UserAgent->new;
    $ua->agent('');

    my $res = $ua->get($url);
    say Dumper $res->content ;
    if ($res->is_success) {
        say "success!";
        # my $translated = decode_entities($res->content);
        if ($res->content =~ /\[\[\["(.*?)",/) {
            #my $translated = decode_entities($1);
            print "$1\n";
            return $1
        }
    }
    else {
        say $res->status_line;
        return -1
    }
}

# suppress all the detect faces metadata (DF)
sub hd_deleteDF {
    my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    print "\n$nill: ";
    # suppress the classif attribute
    my $tmp = $ill->att("classif");
    if ((defined $tmp) &&  (index($tmp,$SERVICE) !=-1)) { # we have classification
     $ill->del_att("classif");
     if (index($tmp,"CC") !=-1){
      $ill->set_att("classif","CC"); # set again CC
      }
     $nbTotIll++;
     # suppress the  classification elements
     my @contenus= $ill->children( 'contenuImg');
     #say "nbre de MD DF : ".scalar(@contenus);
     foreach my $contenu (@contenus) {
     	 say $contenu->text();
       if ( $contenu->text() eq "face" ) {
       	  print " - ";
          $contenu->delete;}
      }
    }
    else {print " no DF classification"}
   }
}

# suppress all the genre metadata of a specified source or the genre itself if empty
sub hd_deleteGenre {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print "\n$nill: ";

     # suppress the  classification element
     my @genres= $ill->children('genre');
     foreach my $genreElt (@genres) {
      if ((not $genreElt->text()) or ($genreElt->text() eq "")) {
        print " empty genre... ";
        $genreElt->delete}
      else {
          my $source = $genreElt->att("source");
          my $genre = $genreElt->text();
          if (((defined $source) and ($source eq $classifSource))
            and ((not(defined $illGenreOld) or ($genre eq $illGenreOld)))) {
  					       $nbTotIll++;
                   print " -$classifSource ";
                   $genreElt->delete
                 }
            }
        }
      }
    }

sub hd_delDuplicateGenre {
       my ($t, $elt) = @_;

       my @ills = $elt->children('ill');
       for my $ill ( @ills ) {
         $nill = $ill->att('n');
         say "\n$nill ";

         # suppress the  classification element
         my @genres= $ill->children('genre[@source="final"]');
         my $nbGenres = scalar @genres;
         if ( $nbGenres > 1) {
           say ".. duplicate genres! ($nbGenres)";
           say "-> we keep ".$genres[0]->text();
          for (my $i = 1; $i < $nbGenres; $i++){
           	  say  "   deleting ".$genres[$i]->text();
    					$nbTotIll++;
              $genres[$i]->delete;
          }
        }
        }
    }

sub hd_deleteEmptyGenre {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print "\n$nill: ";

     # suppress the  classification element
     my @genres= $ill->children('genre');
     foreach my $genre (@genres) {
      if ((not $genre->text()) or ($genre->text() eq "")) {
       	  print " - ";
					$nbTotIll++;
          $genre->delete;}
      }
    }
}

# delete
sub hd_deleteDuplicates {
   my ($t, $elt) = @_;

  no warnings 'uninitialized';
  my $npage = $elt->parent->att('ordre');
  say "--------------------------\n page: $npage";

  # building the combinaisons of illustration pairs
  my @listeIllus = ();
  my @ills = $elt->children('ill');
  if (@ills and scalar(@ills)>1 ) {

   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print " $nill  ";
     push(@listeIllus, $nill);
          }
    say "\n****";
    my $iter = combinations(\@listeIllus, 2);
    while (my $c = $iter->next) {
            say "\n pair: @$c";
            #say Dumper @$c ;
            $nillA = @$c[0];
            #say "illus A: ".$nillA;
            my @illA = $elt->children('ill[@n="'.$nillA.'"]');
            #say Dumper $illA[0];
            my @coordsA = [$illA[0]->att('x'),$illA[0]->att('y'),$illA[0]->att('w'),$illA[0]->att('h')];
            #say Dumper @coordsA;
            $nillB = @$c[1];
            #say "illus B: ".$nillB;
            my @illB = $elt->children('ill[@n="'.$nillB.'"]');
            my @coordsB = [$illB[0]->att('x'),$illB[0]->att('y'),$illB[0]->att('w'),$illB[0]->att('h')];
            @inter = intersection(@coordsA,@coordsB);
            if (@inter) {
              say " -->$nillA and $nillB have an intersection: ";
              say Dumper @inter;
              say "    looking for duplicates...";
              $area = ($inter[2] * $inter[3]);
              say "    intersaction area: $area";
              $areaA = ($coordsA[0][2] * $coordsA[0][3]);
              say "    A area: $areaA";
              $areaB = ($coordsB[0][2] * $coordsB[0][3]);
              say "    B area: $areaB";
              $ratio = max($areaA,$areaB)/min($areaA,$areaB);
              say "    ratio: $ratio";
              if ($ratio < $duplicates_threshold) {
                say "  --> candidates!\n filtering the smallest illustration ";
                $nbTotIll++;
                if ($areaB > $areaA) {$illA[0]->set_att("filtre","1")}
                else {$illB[0]->set_att("filtre","1")}
              }
            }
        }
    }
  }


# can be done more effectively in BaseX
sub hd_deleteEmptyLeg {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print "\n$nill: ";

     # suppress the empty elements and the short ones
     my @legs= $ill->children('txt');
     foreach my $leg (@legs) {
      if ((not $leg->text()) or (length($leg->text()) <= 3)) {
       	  print " - ";
					$nbTotIll++;
          $leg->delete;}
      }
    }
}

# suppress multiple <txt>
sub hd_fixLeg {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print "\n$nill: ";

     # suppress the doublons
     my @legs= $ill->children('txt');
     if (@legs and scalar(@legs)>1) {
          $legs[0]->delete;
					print " - ";
					$nbTotIll++;
				}
    }
}

# add the pixel size at the page level
sub hd_fixPageSize {
   my ($t, $elt) = @_;

   my $page = $elt->parent;
   my $npage = $page->att('ordre');
   say " page: $npage";

   my @ills = $elt->children('ill');
   if (scalar @ills == 1) {
        my $x = $ills[0]->att('x');
        my $y = $ills[0]->att('y');
        if (($x <= 1) and ($y <= 1)) {
          $page->set_att("largeurPx",$ills[0]->att('w'));
          $page->set_att("hauteurPx",$ills[0]->att('h'));
          say  " pixels size fixed on page $npage: $x,$y";
				  $nbTotIll++;
        }
			}
}

# set a data.bnf.fr URL attribute
sub hd_data {
    my ($t, $elt, $url) = @_;

    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			if (not $ill->att('filtre')) {	 # do not compute filtered illustrations
			  print " + ";
				$nbTotIll++;
				$ill->del_att("databnf");
				$ill->set_att("databnf",$url); # suppress the quotes
			}
		}
}

## extract the illustrations as image files with IIIF
sub hd_extract {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say "\n page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      $nbTot+=1;
    	$nill = $ill->att('n');
    	my $filtre = $ill->att('filtre');
			my $pub = $ill->att('pub');
      my $coul = $ill->att('couleur');
      #my $seg = $ill->att('seg');
      #if (($coul eq "coul")) {
    	if ($filtre or ($coul ne "coul")) {	  #or $pub # do not export filtered illustrations
				say " $nill : filtered/ad illustration ";
        next}
      if (defined $techClassif) { # a filter on techniques exists
         #say $ill->name;
         my $tech = getTech($ill);
         if (not $tech) {
              say " # illustration has no technique: use it anyway"}
         elsif (index($techClassif,$tech) ==-1) {
              say " # illustration is not a $techClassif!";
              next} # use only if  specific tech
        }
      if (IIIF_get($ill,$idArk,$nill,$page)) {
        $nbTotIll++;}
    #}
      #else {say " $nill : unsegmented illustration ";}
   }
}

## output the illustrations crops as overlays on an image
## and export the xywh coordinates as text files
sub hd_crops {
    my ($t, $elt) = @_; # elt is a a <page>

  my $fh;
  my @results;
  my $resize = $factIIIF/100;
  my $crops;

  my $CS =0.7;

  my $page = $elt;
  my $nPage = $page->att('ordre');
  say "\n page: $nPage";

  $ficTxt = "$OUT/$idArk-$nPage.txt";
  $ficCSV = "$OUT/$idArk-$nPage.csv";
  open($OUTtxt, '>',$ficTxt) || die "### Can't write in $ficTxt file: $!\n";
  open($OUTcsv, '>',$ficCSV) || die "### Can't write in $ficCSV file: $!\n";

  # segmentation exists at the page level
  my $segPage = $page->first_child('document');
  my $ills_elt = $page->first_child('ills');
  if ($ills_elt) {
     my @ills = $ills_elt->children('ill');
     say "...parsing illustrations" ;
     for my $ill ( @ills ) {
      $nbTot+=1;
    	$nill = $ill->att('n');
      say "  $nill";
    	my $filtre = $ill->att('filtre');
			my $pub = $ill->att('pub');
      #my $coul = $ill->att('couleur');
      my $seg = $ill->att('seg');
      if ($classifOnlyIfSeg and defined $seg) {
          say " .. $nill: unsegmented illustration ";
          next}
    	if ($filtre ) {	 # or $pub  # do not export filtered illustrations
				say " $nill : filtered/ad illustration ";
        next}
      if (defined $techClassif) { # a filter on techniques exists
         #say $ill->name;
         my $tech = getTech($ill);
         if (not $tech) {
              say " .. illustration has no technique!";
              next}
         elsif (index($tech,$techClassif) == -1) {
              say " .. illustration is not a $techClassif!";
              next} # use only if  specific genre
         }
       # we have a candidate
       push @results, $ill
       }   # loop end
       # processing the illustrations
       if (@results) {
         say " --> crops to export: ".scalar(@results);
         # extract the image file (page level)
         my $ficSrc = IIIF_getImg($idArk,$nPage);
         if ($ficSrc) {
          if (open($fh,$ficSrc)) {
           try {
              $imgSrc = newFromJpeg GD::Image($fh);  }
            catch {
              warn "### error while reading image! ###";
              say  "########################################";
              unlink $ficSrc;
              return
            }
          }
          else {
            say "## can't open file! ##";
            return}
          }
          else {return}
        # export $crops
        binmode STDOUT;
        open my $out, '>', $ficSrc or die;
        binmode $out;
        for my $ill ( @results ) {
         $nbTotIll++;
         $x = $ill->att('x')*$resize;
         $y = $ill->att('y')*$resize;
         $l = $ill->att('w')*$resize;
         $h = $ill->att('h')*$resize;
         $nIll = $ill->att('n');
         say " cropping illustration #$nill";
         $myCrop = new GD::Image($l,$h);
         $green = $myCrop->colorAllocate(0,255,0);
         $frame = $myCrop->colorAllocate(0,0,0);
         # create the crop
         $myCrop->filledRectangle(0, 0, $l, $h, $green);
         $myCrop->setThickness(3);
         $myCrop->rectangle(0, 0, $l, $h, $frame);
         $myCrop->string(gdLargeFont, 10, 10, $nIll, $frame);
         # merge with the source image
         $imgSrc->copyMerge($myCrop,$x,$y,0,0,$l,$h,40); # 50% opacity
         # export the coordinates as text
         say " writing coordinates in $ficTxt";
         print $OUTtxt "illustration $x $y $l $h\n"; # $CS
         print $OUTcsv "$idArk-$nIll;$x;$y;$l;$h;illustration\n";
         # text blocks?
         my @txts = $ill->children('contenuText');
         for my $txt ( @txts ) {
          $ntxt = $txt->att('n');
          if ($txt->att('filtre')) {
  				  say " $ntxt: filtered text block ";
            next}
          $x = $txt->att('x')*$resize;
          $y = $txt->att('y')*$resize;
          $l = $txt->att('w')*$resize;
          $h = $txt->att('h')*$resize;
          say " cropping text block #$ntxt";
          $myCrop = new GD::Image($l,$h);
          $red = $myCrop->colorAllocate(255,0,0);
          $frame = $myCrop->colorAllocate(255,255,255);
          # create the crop
          $myCrop->filledRectangle(0, 0, $l, $h, $red);
          $myCrop->setThickness(1);
          $myCrop->rectangle(0, 0, $l, $h, $frame);
          # merge with the source image
          $imgSrc->copyMerge($myCrop,$x,$y,0,0,$l,$h,40); # 40% opacity
          print $OUTtxt "text $x $y $l $h\n"; # $CS
          print $OUTcsv "$idArk-$ntxt;$x;$y;$l;$h;text\n";
         }
     }

     if ($segPage) {
       say " cropping the illustration at the page level ";
       $x = $segPage->att('x')*$resize;
       $y = $segPage->att('y')*$resize;
       $l = $segPage->att('w')*$resize;
       $h = $segPage->att('h')*$resize;
       $myCrop = new GD::Image($l,$h);
       $blanc = $myCrop->colorAllocate(0,0,0);
       $myCrop->transparent($blanc);
       $bleu = $myCrop->colorAllocate(0,0,200);
       $myCrop->setThickness(8);
       $myCrop->rectangle(0, 0, $l, $h, $bleu);
       $imgSrc->copyMerge($myCrop,$x,$y,0,0,$l,$h,90);
       print $out $imgSrc->jpeg;
     }
     # exporting file
     print $out $imgSrc->jpeg;
   }
    else {say ".. no illustration to crop have been detected on this page"}
 } else {say ".. no illustrations on this page"}

 close $OUTtxt;
 close $OUTcsv;
}

## extract the faces as image files
sub hd_extractFace {
my ($t, $elt) = @_;

my $ficImg;
my @contenus;

my $page = $elt->parent->att('ordre');
say "\n page: $page";

my @ills = $elt->children('ill');
for my $ill ( @ills ) {
  $nbTot+=1;
  my $filtre = $ill->att('filtre');
  my $pub = $ill->att('pub');
  if ($filtre or $pub) 	{  # do not export filtered illustrations
     say " # filtered/ad illustration ";
     next }
  if (defined $techClassif) { # a filter on technique exists
     #say $ill->name;
     my $tech = getTech($ill);
     if (not $tech) {
        say " # illustration has no technique: use it anyway"}
     elsif (index($techClassif,$tech) ==-1) {
        say " # illustration is not a $techClassif!";
        next} # use only if  specific genre
  }

  $nill = $ill->att('n');
  #say $classifCBIR;
  if ($classifCBIR eq "all") {
    @contenus = $ill->children('contenuImg["face"]');}
  else {
    @contenus = $ill->children('contenuImg["face" and @source="'.$classifCBIR.'"]')}

  for my $ct ( @contenus ) {
   if ($ct->text() eq "face") {
     if ($ct->att('sexe')) {
        say " Face: ".$ct->att('sexe');}
     my $CS = $ct->att('CS');
     say " CS: $CS";
     if ($CS < $CSthreshold) {
       say " # confidence $CS < $CSthreshold! #";
       next}
     # looking for a filename
     for (my $i = 1; $i <= 40; $i++) {
       $ficImg = "$OUT/$idArk-$nill-$i";
       if (not -e $ficImg.".jpg") {
        last}
      }
     $ficImg = $ficImg.".jpg";
	   unlink $ficImg;

	 # handle rotation
	 $rotation = $ct->parent->att('rotation');
	 $rotation ||= "0";

	 # dimensions
	 my $largVSG = $ct->att('w');
	 my $hautVSG = $ct->att('h');
   if ((not defined $largVSG) or (not defined $hautVSG) or ($largVSG <= 0) or ($hautVSG <= 0)) {
     say "### w=$largVSG h=$hautVSG :  null dimension! ###";
     next
   }

	 # 1:1 format?
	 if ($carreVSG==1) {
	 	if ( $largVSG >= $hautVSG) {  # we take the largest dimension
	     $deltaL = $largVSG*$expandIIIF;
			 $deltaH= $deltaL; # delta: to crop larger than the face
	     $hautVSG = $largVSG;
	      }
	 	else  {
	 		$deltaH = $hautVSG*$expandIIIF;
      $deltaL= $deltaH;
	 		$largVSG = $hautVSG;}
	 } else {
	 	  $deltaL = $largVSG*$expandIIIF;
	 	  $deltaH = $hautVSG*$expandIIIF;
	}
  # export size
  $w = $largVSG+$deltaL;
  $h = $hautVSG+$deltaH;

  #handle the image size
  $redim = IIIF_setSize("std",$w,$h);

	 say " width:".$w	;
   say " heigth:".$h	;
	 my $url = $urlGallicaIIIF.$idArk."/f$page/".($ill->att('x')+$ct->att('x')-$deltaL/2).",".($ill->att('y')+$ct->att('y')-$deltaH/2).","
	 .$w.",".$h."$redim/$rotation/native.jpg";
	 say "--> $url \n in $ficImg";
   my $cmd="curl --insecure '$url' -o $ficImg"; # insecure to avoid ssl problem
   #say $cmd;
   my $res = `$cmd`;
   say "res: ".$res;
	 if (-e $ficImg) {
       $nbTotIll++;}
     else {say "### IIIF : $url \n can't extract! ###"}
    }
  }
 }
}

## filter the duplicate faces
sub hd_filterFace {
my ($t, $elt) = @_;

my $ficImg;
my @contenus;
my @centres;

my $page = $elt->parent->att('ordre');
say "\n page: $page";

my @ills = $elt->children('ill');
for my $ill ( @ills ) {
  $nbTot+=1;
  my $filtre = $ill->att('filtre');
  my $pub = $ill->att('pub');
  if ($filtre or $pub) 	{  # do not export filtered illustrations
     say " # filtered/ad illustration ";
     next }

  $nill = $ill->att('n');
  say "\n ill: $nill";
  if ($classifCBIR eq "all") {
    @contenus = $ill->children('contenuImg[text()="face"]');}
  else {
    @contenus = $ill->children('contenuImg[text()="face" and @source="'.$classifCBIR.'"]')}
  my $faces = scalar(@contenus);
  say "--> $faces faces found";

  if ($faces <= 1) {
    next;}
  else {
   # compute all the face centers
   for my $ct ( @contenus ) {
    my $nc = $ct->att('n');
	  my $largVSG = $ct->att('w');
	  my $hautVSG = $ct->att('h');
    if ((not defined $largVSG) or (not defined $hautVSG) or ($largVSG <= 0) or ($hautVSG <= 0)) {
     say "### w=$largVSG h=$hautVSG :  null dimension! ###";
     next
    }
    my $xVSG = $ct->att('x');
    my $yVSG = $ct->att('y');

   # center of the faces
   my $x = ($xVSG + $largVSG)/2;
   my $y = ($yVSG + $hautVSG)/2;
	 #say " x_center: $x"	;
   #say " y_center: $y"	;
   push(@centres,[$nc,$x,$y,1]);
  }
  #say Dumper @centres;

  my @copies = ();
  my $cpt = 0;
  # deduplicate
  for my $c ( @centres ) {
     say  "\nface #$cpt : $c->[0]";
     if ($c->[3] == 0) {print " has been removed!\n";$cpt++;next}
     if (isDuplicate($cpt,@centres)) {
       say " --> face $c->[0] has a copy!";
       push(@copies, $c->[0]);}
     $cpt++;
  }
  if (scalar(@copies)>0) {
   say " ...duplicate faces to be deleted: ";
   #say Dumper @copies;
   # delete the duplicates
   for my $copy ( @copies ) {
    say "  ->deleting ".$copy;
      $nbTotIll++;
    @ct = $ill->children('contenuImg[@n="'.$copy.'"]');
    if (@ct)  {
       $ct[0]->delete}
   }}
  }
 }
}

sub isDuplicate {
  my ($current,@tab) = @_;

  #say Dumper @tab;

  my $match;
  say "..looking matches for face #$current";
  for (my $i = 0; $i < scalar @tab; $i++) {
    if ($i == $current) {next} # do not compare with self
    if ($tab[$i][3] == 0) {next}
    say "n: ".$i;
    my $distance = sqrt(($tab[$current][1] - $tab[$i][1])**2 + ($tab[$current][2] - $tab[$i][2])**2);
    my $deltax = abs(1- $tab[$current][1] / $tab[$i][1]);
    my $deltay = abs(1- $tab[$current][2] / $tab[$i][2]);
    say " geo distance: $distance";
    say " deltax: $deltax";
    say " deltay: $deltay";
    if  ($distance < 100)  {
      say "# match with face #$tab[$i][0] #";
      $tab[$i][3] = 0;
      return 1
    }
  }
  return undef;

}


# extract specific genre
sub hd_extractGenre {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
    	my $filtre = $ill->att('filtre');
			my $genre = $ill->first_child_text(\&is_genre);
    	if (not $filtre and $genre) {
				say " ->genre : $genre";
				if (IIIF_get($ill,$idArk,$nill,$page)) {
          $nbTotIll++
        }
      }
   }
}

sub hd_extractNotClassif {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
    	my $filtre = $ill->att('filtre');
			my $classif = $ill->att('classif');;
    	if ((not $filtre) and ((not $classif) or index($classif, $classifCBIR) == -1)) {
				#say " classif : $classif";
				if (IIIF_get($ill,$idArk,$nill,$page))
        {$nbTotIll++}
      }
   }
}

# check the genre and the source (human)
sub is_genre {
	    my ($element) = @_;

	    if ($element->text() eq $illGenreNew
	        and $element->att('source') eq 'hm' )
	     {return 1;}
	}

## extract the filtered illustrations as image files with IIIF
sub hd_extractFiltered {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
    	$filtre = $ill->att('filtre');
    	if ($filtre) {	   # export filtered illustrations
				if (IIIF_get($ill,$idArk,$nill,$page)) {$nbTotIll++}
        }
    	else { say " $nill : not a filtered illustration"}
   }
}

# compute the IIIF URL
sub setIIIFURL {my $ill=shift;
								my $page=shift;
								my $mode=shift; # std, ocr, zoom

	my $redim;
	my $w = $ill->att('w');
	my $h = $ill->att('h');
  my $prefix = $idArk."/f$page/"; # default
  my $postfix;
  my $urlIIIF = $urlGallicaIIIF; # default
  my $format = "native.jpg"; # default
  my $meta = $ill->parent->parent->parent->parent->parent->first_child;
  my $urlExt = $meta->first_child('urlIIIF'); # europeana...

  #say $resize;
  if ($urlExt) {
    $source=$meta->first_child('source')->text();
    $urlExt=$urlExt->text(); # extract the iiif url
    say " document has an external source: $source";
    switch ($source) {
     case "Wellcome Collection" {
       $prefix = "";
       $urlIIIF = $urlExt;
       $format = "default.jpg";
    }
    default {
      say "#### unknown source, can't compute the IIIF url! ####";
      die
    }
   }
  }

  # handle the rotation
	my $rotation = $ill->att('rotation');
	$rotation ||= "0";
	#handle the image size
  $redim = IIIF_setSize($modeIIIF,$w,$h);

	switch ($mode) {
	 case "ocr" { # expand the illustration to get some text around
		my $deltaW = int($w*0.1); # enlarge a little bit horizontaly
		my $deltaH = int($h*$expandIIIF); # enlarge verticaly to get some text before and after
		my $x = $ill->att('x')-int($deltaW/2);
		if ($x<=0) {$x=0};
		my $y = $ill->att('y')-int($deltaH/4); # expand 1/4 above the illustration
		if ($y<=0) {$y=0};
		$postfix = $x.",".$y.",".($w+$deltaW).",".($h+$deltaH).$redim."/$rotation/$format";
	}
	case "zoom" {
		my $deltaW = int($w*$expandIIIF); # reduce the illustration to avoid borders
		my $deltaH = int($h*$expandIIIF);
		my $x = $ill->att('x')+int($deltaW/2);
		my $y = $ill->att('y')+int($deltaH/2);
		$postfix = $x.",".$y.",".($w-$deltaW).",".($h-$deltaH).$redim."/$rotation/$format";
	}
	else {
		$postfix = $ill->att('x').",".$ill->att('y').",".$w.",".$h.$redim."/$rotation/$format";
	}
 }
	say " --> $urlIIIF$prefix$postfix";
	return $urlIIIF.$prefix.$postfix;
}

# compute the IIIF URL
sub setIIIFImgURL {my $id=shift;
								   my $page=shift;
								   my $mode=shift; # std, ocr, zoom

	my $redim;
  my $prefix = $idArk."/f$page/"; # default
  my $postfix;
  my $urlIIIF = $urlGallicaIIIF; # default
  my $format = "native.jpg"; # default

	#handle the image size
  $redim = IIIF_setSize($modeIIIF,0,0);

	$postfix = "full".$redim."/0/$format";

	say " --> $urlIIIF$prefix$postfix";
	return $urlIIIF.$prefix.$postfix;
}


# set the III export size
sub IIIF_setSize {my $mode=shift;
                  my $w=shift;
                  my $h=shift;

 my $resize = $factIIIF/100;
 my $wResize = $w*$resize;
 my $hResize = $h*$resize;

if ($mode eq "linear")  { # we do not handle max or min size
  return "/pct:$factIIIF"
}
else { # avoid too small or too large images
 say "l: ".$wResize;
 say "h: ".$hResize;
 if ($w > $h) { #landscape
  if ($hResize < $reDimMinThreshold)  { # testing the smallest dimension
     say "...too small image h=".$hResize." -> resizing at $reDimMinThreshold" ;
     return "/,$reDimMinThreshold";}
  elsif ($wResize > $reDimMaxThreshold) {
     say "...too large image w=".$wResize." -> resizing at $reDimMaxThreshold" ;
     return "/$reDimMaxThreshold,"; }
  else {
     return "/pct:$factIIIF";  }
  }
  else { #portrait
   if ($wResize < $reDimMinThreshold)  { # testing the smallest dimension
     say "...too small image w=".$wResize." -> resizing at $reDimMinThreshold" ;
     return "/$reDimMinThreshold,";}
   elsif ($hResize > $reDimMaxThreshold) {
     say "...too large image h=".$hResize." -> resizing at $reDimMaxThreshold" ;
     return "/,$reDimMaxThreshold"; }
   else {
     return "/pct:$factIIIF";  }
  }
 }
}

# extract a IIIF file
sub IIIF_get {my $ill=shift;
							my $id=shift;
	            my $nill=shift;
							my $page=shift;

    my $tmpID = $id;
    $tmpID =~ s/\//-/g; # replace the / with - to avoid issues on filename
		my $tmp = "$OUT/$tmpID-$nill.jpg";
		if (-e $tmp) {say "$tmp already exists!"}
		else {
      my $url = setIIIFURL($ill,$page,"std");
			say "$nill --> ".$url;
			return IIIFextract($url,$tmp)
		}
}

# extract a IIIF file in /tmp/
sub IIIF_getImg {my $id=shift;
							   my $page=shift;

    my $tmpID = $id;
    $tmpID =~ s/\//-/g; # replace the / with - to avoid issues on filename
		my $tmp = "$OUT/$tmpID-$page.jpg";
		if (-e $tmp) {say "$tmp already exists!"}
		else {
      my $url = setIIIFImgURL($id,$page,"std");
			say "$id --> ".$url;
			return IIIFextract($url,$tmp)
		}
}

## extract an illustration file with the IIIF API in $fic file
sub IIIFextract {my $url=shift;
	                my $fic=shift;

       unlink $fic;

       my $cmd="curl --insecure '$url' -o $fic";
       say $cmd;
       my $res = `$cmd`;
     	 #say "res: ".$res;
       #my $rc = getstore($urlIIIF.$url, $fic);
	     #if (is_error($rc)) {
       if ($res and (index($res,"ERROR")!=-1)) {
         say "### curl: $url \n can't extract: <$res>! ###";
         $nbFailIll+= 1;
		     return 0;}
       else {
         say "Writing in $fic";
		     return $fic
			 }
}

# copy a locally stored file in a tmp location
sub localExtract {my $ficIn=shift;
	                my $ficOut=shift;

       unlink $ficOut;
       my $cmd="cp '$localBasexInstall$ficIn' $ficOut";
       say $cmd;
       my $res = `$cmd`;
       if (not(-e $ficOut)) {
         say "### cp: can't copy $ficIn! ###";
         $nbFailIll+= 1;
		     return undef;}
       else {
         say "..writing in $ficOut";
		     return 1
			 }
}

# say if an ill can be classified
# returns:
# 0 : no
# 1 : yes but be carefull
# 2 : yes
sub classifyReady {my $ill=shift;

 my $nill = $ill->att('n');
 my $filtre = $ill->att('filtre');
 if (defined $filtre) {	# do not classify the filtered illustrations
		say "$nill -> filtered";
		return 0}

# filter on colors
#my $coul = $ill->att('couleur');
#if ((defined $coul) and not ($coul eq "coul")) {	# classify the color illustrations
#       say "$nill -> not a color picture";
#       return 0}

 my $classif = $ill->att('classif');
 #if ((defined $classif) && (index($classif, $classifAction." ") != -1)) { # do not classify twice
 if ((defined $classif) && (index($classif, $classifAction.$classifCBIR) != -1)) {   # do not classify twice (using the same API)
		say "$nill -> already $classifAction$classifCBIR classified!";
		#say "$nill -> already $classifAction classified!";
		return 0}

 # filter on size
 my $size = $ill->att('taille');
 if ((defined $size) and ($size < $sizeIllThreshold)) {
		say "$nill -> illustration is too small! (size=$size)"; # do not classify small ill.
	  return 0}

 # filter on text content
 if ($classifOnlyIfNoText) {
  my @leg = $ill->children('leg');
  my @txt = $ill->children('txt');
  if (@leg or @txt) {
   say "$nill  -> illustration has some text!";
	 return 0
  }
 }

 # filter on techniques
 if (defined $techClassif) { # a filter on tech exists
   my $tech = getTech($ill);
   if (not $tech) {
     say "$nill  -> illustration has no technique: classify anyway";
     return 1}
   if (index($techClassif,$tech) ==-1) {
			say "$nill  -> illustration is not a $techClassif!"; # classify only a specific tech
			return 0}
	 else {return 2}
  }
	else
   {return 1} # classify whatever the tech is

  # filter on functions
  if (defined $functionClassif) { # a filter on function exists
     my $f = getFunction($ill);
     if (not $f) {
       say "$nill  -> illustration has no function: classify anyway";
       return 1}
     if (index($functionClassif,$f) ==-1) {
  			say "$nill  -> illustration is not a $functionClassif!"; # classify only a specific tech
  			return 0}
  	 else {return 2}
    }
  	else
     {return 1} # classify whatever the genre is
}


sub OCRReady {my $ill=shift;

 my $nill = $ill->att('n');
 my $filtre = $ill->att('filtre');
 my $seg = $ill->att('seg');

 if (defined $filtre) {	# do not process the filtered illustrations
 	 say "$nill -> filtered";
 	 return 0}

if (not defined $seg) {	## only process the segmented illustrations
   	 say "$nill -> not segmented";
   	 return 0}

 if (defined $functionClassif) {
  my $f = getFunction($ill);
  if (not $f) {
     say "$nill -> illustration has no function";
     return 0}
  if (index($functionClassif,$f) ==-1) {
		 say "$nill -> illustration is not a $functionClassif!"; # classify only a specific genre
		 return 0}
 }

 #my @titraille = $ill->children('titraille');
 my @leg = $ill->children('leg');
 my @txt = $ill->children('txt');
 if ((not @leg) and (not @txt)) {
	return 1
 }
 else {
	 say "$nill -> illustration has some text!";
	 return 0}
}

# update the list of classification actions : CC / DF
sub updateClassif { my $ill=shift;

  say " classif: $classifAction$classifCBIR on ". $ill->att("n");
	my $classif = $ill->att('classif');
	if ($classif) {
		$ill->set_att("classif",$classif." ".$classifAction.$classifCBIR); }
	else {
		$ill->set_att("classif",$classifAction.$classifCBIR);
	}
}

sub isAlpha() {my $string=shift;

if($string =~ /[a-zA-Z ]/)
	{return 1;}
else
	{return 0}
}

## call the OCR API (Google)
sub hd_OCR {
    my ($t, $elt) = @_;

		my @res;

    my $page = $elt->parent->att('ordre');
    say "\n page: $page";
		# get the pages number
		my $tmp = $elt->parent->parent->parent->parent;
		my $pages = $tmp->get_xpath('metad/nbPage', 0);
		#say $pages->text();

    my $doc = $elt->parent->parent->parent->parent; # document level
    my $tmpFile = "/tmp/image.jpg";

	  #if ($pages->text()	<= 1) {  # only ocr multipage documents (monog, series)
	 	# say " ### pages=1 ###";
	 	# return 0}

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			if (OCRReady($ill)) {
       # extract the file
       if (IIIFcompliant($doc)) {  # IIIF case
            my $url = setIIIFURL($ill,$page,"ocr");
            $extracted = IIIFextract($url,$tmpFile)}
       else { # the file is local
           my $localFile = $doc->get_xpath('metad/fichier', 0);
           if ($localFile) {
             say "...local ID file: ".$localFile->text();
             my $localFileName = $localFile->text()."-".$nill.".jpg"; # last -1 is the illustration number (no multi-illustration without iiif)
             $extracted = localExtract($localFileName,$tmpFile)}
           else {
            say "### can't find file info! ###";
            next}
          }
      if ($extracted) { # call the API
	    # call the API
			$res = callgoogleOCR($tmpFile);
			if ($res and ($res ne "") ) { # API call succeed
					$nbTotIll++;
					#updateClassif($ill);
					$res =~ s/\\n/ - /g; # suppress the \n
					if (length($res) > $OCRlength) {
						say "\n OCR -> ".substr($res,$OCRlength);
					} else {say "\n OCR -> ".$res;}
					 # write the new metadata in the XML
          $ill->insert_new_elt('txt', $res)->set_atts("source"=>"google");

					}
			else {
					say " ** no OCR output **"
					}
	     }
     }
   } #for
}

sub IIIFcompliant {
    my ($doc) = @_;

    my $source = $doc->get_xpath('metad/source', 0);
    my $iiif = $doc->att('iiif');
    if ($source and ($source->text() eq "local") or  # retro compatility
      $iiif) {  # if this attribute exists, is value is always false
      say "...not IIIF compliant!";
      return undef}
    else {return 1}
}

## call the content classification API
sub hd_classifyCC {
    my ($t, $elt) = @_;

		my @res;
		my $nbClasses=0;
		my $fact = (100.0/$factIIIF)*0.95; # ratio to set the dimensions in the original image space
    my $tmpFile = "/tmp/image.jpg";

    my $doc = $elt->parent->parent->parent->parent; # document level
    my $page = $elt->parent->att('ordre');
    say "#####\n page: $page";
    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
      say "$nill...";
			if (classifyReady($ill)) {
	     # extract the file
       if (IIIFcompliant($doc)) {  # IIIF case
            my $url = setIIIFURL($ill,$page,"zoom");
            $extracted = IIIFextract($url,$tmpFile)}
       else { # the file is local
           my $localFile = $doc->get_xpath('metad/fichier', 0);
           if ($localFile) {
             say "...local ID file: ".$localFile->text();
             my $localFileName = $localFile->text()."-".$nill.".jpg"; # last -1 is the illustration number (no multi-illustration without iiif)
             $extracted = localExtract($localFileName,$tmpFile)}
           else {
            say "### can't find file info! ###";
            next}
          }
       if ($extracted) { # call the APIs
        switch ($classifCBIR)  {
          case "ibm"		{
						   @res = callibmCC($tmpFile);}
					case "google"		{
						   @res = callgoogleCC($tmpFile);}
          else { say "### unknown CBIR mode: $classifCBIR! ###"}
				 }

			  if (scalar(@res) > 1) { # API call succeed
          say " -->API call: success";
					$nbTotIll++;
					updateClassif($ill);
					#say Dumper @res;
					my $nbClasses = $res[0];
          my $nbCouleurs = $res[1];
					say "--> $nbClasses classes";
          say "--> $nbCouleurs colors";
					if ($classifCBIR eq "google") { # we have a cropping and we associate it with the first tags (assumption...)
					 my $deltaW = $ill->att('w')*$expandIIIF; # to accommodate the zoom -> see setIIIFURL()
					 my $deltaH = $ill->att('h')*$expandIIIF;
					 my $x = int($res[2+$nbClasses+$nbCouleurs]*$fact)+$deltaW;
					 my $y = int($res[2+$nbClasses+$nbCouleurs+1]*$fact)+$deltaH;
					 my $l = int($res[2+$nbClasses+$nbCouleurs+2]*$fact);
					 my $h = int($res[2+$nbClasses+$nbCouleurs+3]*$fact);
           # semantic tags
           foreach my $i  (1..$nbClasses) {
						 my $label = $res[1+$i];
						 my $CS = sprintf("%.2f",$res[$i+$nbClasses+$nbCouleurs+5]) || 1.0; # float number pattern : to be fixed!
						 if ($i<=4) { # we crop the first 4 tags
							say "  $i ... crop on tag $label ($CS)";
							$ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","x"=>$x,"y"=>$y,"w"=>$l,"h"=>$h,"CS"=>$CS, "source"=>$classifCBIR);
					 	 } else {
							say "  $i : $label ($CS)";
							$ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","CS"=>$CS,"source"=>$classifCBIR)
						}
					 }
           # color tags
           #scalar(@classes),$nbCouleurs,@classes,@couleurs,@crop,@scores,@coulR,@coulV,@coulB,);
           foreach my $i  (1..$nbCouleurs) {
             my $label = $res[1+$nbClasses+$i];
             say " CS: ".$res[$i+$nbClasses*2+$nbCouleurs+5];
             my $CS = sprintf("%.2f",5*$res[$i+$nbClasses*2+$nbCouleurs+5]) ; # to get the CSs more similar to the semantic
             my $r = $res[$i+$nbClasses*2+$nbCouleurs+5+$nbCouleurs];
             my $v = $res[$i+$nbClasses*2+$nbCouleurs+5+$nbCouleurs*2];
             my $b = $res[$i+$nbClasses*2+$nbCouleurs+5+$nbCouleurs*3];
             say "  color $i: $label ($CS) / r=$r g=$v b=$b";
             if (index ($label,"#") == -1) {
                 $ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","r"=>$r,"g"=>$v,"b"=>$b,"CS"=>$CS,"coul"=>"1","source"=>$classifCBIR)}
            else {$ill->insert_new_elt('contenuImg', $label)->set_atts("r"=>$r,"g"=>$v,"b"=>$b,"CS"=>$CS,"coul"=>"1","source"=>$classifCBIR)}
          }
        }  # other CBIR source with no cropping: IBM...
						else {
						 foreach my $i  (1..$nbClasses) {
							my $label = $res[1+$i];
							my $CS = $res[$i+$nbClasses+$nbCouleurs+1] || 1.0 ; # the float number pattern must be fixed!
              if (index($label, "color") == -1) {
							  say "  $i: $label ($CS)";
                $ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","CS"=>$CS, "source"=>$classifCBIR);}
              else {
                say "  color $i: $label ($CS)";
                $ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","coul"=>"1","CS"=>$CS, "source"=>$classifCBIR);}
              }
						}
					}
	     }
   }
 }#for
}

## call the face detection API
sub hd_classifyDF {
    my ($t, $elt) = @_; # $elt is the <ills> level

    my $redim;
    my $rotation;
    my $extracted;
    my $fact; # ratio to set the dimensions in the original illustration space
    my $doc = $elt->parent->parent->parent->parent; # document level
    my $tmpFile = "/tmp/image.jpg";

    my $page = $elt->parent->att('ordre');
    say "#####\n page: $page";
    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      $nill = $ill->att('n');
      say "$nill...";
			if (classifyReady($ill)) {
       if (IIIFcompliant($doc)) {  # IIIF case
        # compute the IIIF url to the image
        my $url = setIIIFURL($ill,$page,"std");
        if (index($url,"full") != -1) {
          $fact = 1}  # the illustration has been processed at full size
        else {$fact = 100.0/$factIIIF }
        $extracted = IIIFextract($url,$tmpFile) # extract the file locally
       } else {
        $fact = 1;
        my $localFile = $doc->get_xpath('metad/fichier', 0);
        if ($localFile) {
          say "...local file: ".$localFile->text();
          my $localFileName = $localFile->text().$nill."-1.jpg"; # last -1 is the illustration number (no multi-illustration without iiif)
          $extracted = localExtract($localFileName,$tmpFile)}
       else {
         say "### can't find file info! ###";
         next}
         }
       if (not $extracted) {
         next}
	     # now call the APIs
			 switch ($classifCBIR)  {
	 				case "ibm" {@res = callibmDF($tmpFile);}
					case "google"		{@res = callgoogleDF($tmpFile);}
          else { say "## unknown CBIR mode: $classifCBIR ##";}
				 }
       #say Dumper (@res);
       if (scalar(@res) > 1) { # API call succeed
			 #if (defined($res[0]) and  $res[0] != 0 ) { # the API call succeed
          say " --> API call: success!";
					$nbTotIll++;
          #say Dumper @res;
					updateClassif($ill);
					if ($res[0]) { # the API returned some results
						# write the new metadata in the XML
						say Dumper (@res);
						#$nbVisages = int ((scalar(@res)/8)+0.5); # @res is a list of 7 array values
            $nbVisages = $res[0];
						say "--> $nbVisages new faces";
            $visages =  scalar($ill->children('contenuImg[text()="face"]'));
            say "    $visages already defined faces";
            foreach my $i  (1..$nbVisages) {
              say $i;
              $nbTotDF++;
              my $l = int($res[$i+$nbVisages*5]);
              my $h = int($res[$i+$nbVisages*6]);
              say " l: $l - h: $h";
              if (($l <1) or ($h<1)) {
                say " ### ERROR: negative coord: w: $l / h: $h###";
                die
              }
							my $score = sprintf("%.2f", $res[$i+$nbVisages*2]); # two confidence scores, for age and gender
							if ($res[$i] eq "MALE")
                {$sexe="M";}
							elsif ($res[$i] eq "FEMALE")
                {$sexe = "F";}
							else 	{$sexe = "P";}# gender unknown

						  say " -> $sexe ($score)";
							my $age = $res[$i+$nbVisages*7]*1.2;  # the IBM API returns age_min
							#if ((defined $ageMin) and (defined $ageMax))
							#       {$age = ($ageMin + $ageMax)/2}
							say " -> age : $age";
              my $nv = $nill."-".($visages+$i);
							if ($age ne 0) {
							$ill->insert_new_elt( 'contenuImg', "face" )->set_atts("lang"=>"en","n"=>$nv,"sexe"=>$sexe,"CS"=>$score,"age"=>$age,"source"=>$classifCBIR,
										 "x"=>int($res[$i+$nbVisages*3]*$fact),"y"=>int($res[$i+$nbVisages*4]*$fact),"w"=>int($l*$fact),"h"=>int($h*$fact));}
							else  {
                $ill->insert_new_elt( 'contenuImg', "face" )->set_atts("lang"=>"en","n"=>$nv,"sexe"=>$sexe,"CS"=>$score,"source"=>$classifCBIR,
  										 "x"=>int($res[$i+$nbVisages*3]*$fact),"y"=>int($res[$i+$nbVisages*4]*$fact),"w"=>int($l*$fact),"h"=>int($h*$fact));}}
							}
		   } # api call
	 }
  } #for
}

# call the IBM Watson API and return the list of classes followed by the confidence scores
sub callibmCC {my $fic=shift;

	my @classes;
	my @scores;

  #say $urlIIIF.$url;
	#my $cmd=  "curl -X POST -F \"images_file=@".$ill."\" \"".$endPointWatson."classify?api_key=$apiKeyWatson&version=2016-05-20\"";
  #my $cmd =  "curl -u  \"apikey:".$apiKeyWatson."\" \"".$endPointWatson."classify?images_file=@".$fic."&version=2018-03-19\"";
  my $cmd =  "cd /tmp;curl -X POST -u \"apikey:".$apiKeyWatson."\" --form \"images_file=@".$fic."\" \"".$endPointWatson."classify?version=2018-03-19\"";

  say "\n** curl cmd: ".$cmd;
	my $res = `$cmd`;
	say "res: ".$res;
	if ($res and (index($res, "error") == -1))   {
	 	(@classes) = do { local $/; $res =~ m/$motifClasseWatson/g };
	 	(@scores) = do { local $/; $res =~ m/$motifScoreWatson/g };
		#say Dumper @classes;
		return (scalar(@classes),0,@classes,@scores); # 0 = no colors tags
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
	 }
}


sub writeGoogleJSON {my $tmpFile=shift;
										 my $JSONfile=shift;
										 my $mode=shift; # face detection/ocr/visual recognition

 my $OUT;
 #my $tmpImg = "/tmp/imageIIIF.jpg";
 #IIIFextract($url,$tmpImg);
 my $cmd = "base64 -i $tmpFile"; # conversion base 64
 my $res = `$cmd`;

 open($OUT, '>',$JSONfile) || die "### Can't write in $JSONfile file: $!\n";
 # using the url:
 #\"source\": {
 #     \"imageUri\": \"$res\"
 #   }

 print $OUT "{
\"requests\": [
	{
		\"image\": {
		  \"content\": \"$res\"
	 },
		\"features\": [";
	switch ($mode) {
  case "DF" {
  	  print $OUT "
  			{
  				\"type\": \"FACE_DETECTION\",
          \"maxResults\": \"30\"
  			}";}
	case "CC" {
	  print $OUT "
			{
				\"type\": \"LABEL_DETECTION\"
			},
			{
				\"type\": \"CROP_HINTS\"
			},
			{
				\"type\": \"IMAGE_PROPERTIES\"
			}";}
	 case "OCR" {
			  print $OUT "
					{
						\"type\": \"DOCUMENT_TEXT_DETECTION\"
					}"; }
		}
  print $OUT "
		],
	\"imageContext\": {
		\"languageHints\": [\"fr\"]
	  }
	}
]
}";
close $OUT;
}

#\"imageContext\": {
#	\"languageHints\": [\"fr\"],
#	\"cropHintsParams\": {
#		\"aspectRatios\": [1]
#		}

sub callgoogleCC {my $tmpFile=shift;

	my @classes;
	my @scores;
  my $nbCouleurs = 0;
  my @couleurs = ();
  my @vertices = ();
  my $res;
  my $json = "/tmp/request.json";

  #say $urlIIIF.$url;
	writeGoogleJSON($tmpFile, $json, "CC");

	my $cmd=  "curl --insecure --max-time 10 -v -s -H \"Content-Type: application/json\" $endPointGoogle$apiKeyGoogle --data-binary \@$json";
	say "cmd: ".$cmd;
	$res = `$cmd`;
  say "res: ".$res;

	if ($res and (index($res, "error") == -1))   {
		(@classes) = do { local $/; $res =~ m/$motifClasseGoogle/g };
	 	(@scores) = do { local $/; $res =~ m/$motifScoreGoogle/g };
		(@coulR) = do { local $/; $res =~ m/$motifCoulRGoogle/g };
		(@coulV) = do { local $/; $res =~ m/$motifCoulVGoogle/g };
		(@coulB) = do { local $/; $res =~ m/$motifCoulBGoogle/g };
    #(@tmpCouleurs) = do { local $/; $res =~ m/$motifCouleursGoogle/s };
		(@vertices) = do { local $/; $res =~ m/$motifVerticesGoogle/s }; # we keep the first crop

    #say "scores:";
    #say Dumper (@scores);

    #say "couleurs :";
    say Dumper (@coulR);
    say Dumper (@coulV);
    say Dumper (@coulB);
		#($cropy) = do { local $/; $res =~ m/$motifCropYGoogle/ };
		my @crop = decodeVertices(\@vertices);
    #say Dumper @crop;

    # @couleurs
    my @arr = (scalar(@coulR), scalar(@coulV), scalar(@coulB));
    if (min(@arr) != max(@arr)) { # google doesn't set an attribute if value=null --> inconsistency with my grep method
     say "## unconsistent colors format! ##";
     $nbCouleurs = 0}
    else {
      $nbCouleurs = max(@arr);
      say "colors: $nbCouleurs";
      foreach my $i  (0..$nbCouleurs-1) {
		   my $couleur = getColorName($coulR[$i],$coulV[$i],$coulB[$i]);
		   if ($couleur) {
         if (index ($couleur,"#") == -1) {
            push @couleurs, $couleur; # named color
		     } else {
            my $hexValue = $rgb->rgb2hex($coulR[$i],$coulV[$i],$coulB[$i]);
            say "..unnamed color: $hexValue";
            push @couleurs, "#$hexValue"
         }}
        else {
          say "## getColorName: error! ##"
        }
      }
     }
    return (scalar(@classes),$nbCouleurs,@classes,@couleurs,@crop,@scores,@coulR,@coulV,@coulB);
    #else {return (scalar(@classes),@classes,@crop,@scores)}
	}
	else {
	 	say " ### API error! $res ###" ;
	 	return undef
	 }
}


sub callgoogleOCR {my $tmpFile=shift;

	my @classes;
  my $res;
  my $json = "/tmp/request.json";

  #say $urlIIIF.$url;
	say "Writing $tmpFile in $json";
	writeGoogleJSON($tmpFile, $json, "OCR");

	my $cmd=  "curl --insecure --max-time 20 -v -s -H \"Content-Type: application/json\" $endPointGoogle$apiKeyGoogle --data-binary \@$json";
	say "cmd : ".$cmd;
	$res = `$cmd`;
	#say "res : ".$res;
	if ($res and (index($res, "error") == -1))   {
    ($texte) = do { local $/; $res =~ m/$motifTexteGoogle/ };
		#say "texte : ".$texte;
		return $texte;
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
	 }
}

sub callgoogleDF {my $url=shift;

	my @scores;
  my @faces;
  my @genres=();
  my @vides=();
  my $visages;
  my $res;
  my $json = "/tmp/request.json";

  #say $urlIIIF.$url;
	say "Writing in $json";
	writeGoogleJSON($url, $json, "DF");

	my $cmd=  "curl --max-time 10 -v -s -H \"Content-Type: application/json\" $endPointGoogle$apiKeyGoogle --data-binary \@$json";
	say "cmd: ".$cmd;
	$res = `$cmd`;
	#say "result: ".$res;
	if ($res and (index($res, "error") == -1))   {
		(@faces) = do { local $/; $res =~ m/$motifVisageGoogle/g };
    $visages = scalar(@faces);
    say " number of faces detected: $visages";
	 	(@scores) = do { local $/; $res =~ m/$motifScoreVisageGoogle/g };
    #say Dumper @scores;
		(@vertices) = do { local $/; $res =~ m/$motifVerticesGoogle/sg }; # we get all the vertices structures

    say " vertices from the API:";
    #say Dumper @vertices;
    say "-----------";
		#($cropy) = do { local $/; $res =~ m/$motifCropYGoogle/ };
    if (@vertices) {
		    my @crop = decodeVertices(\@vertices);
		    #say Dumper (@crop);
        for ($a=1;$a<=$visages;$a++)
	       { push @vides,0;
           push @genres,"P";
	         }
        # list of: genders, age CS, genre CS, X, Y, W ,H , age
        return ($visages,@genres,@vides,@scores,@crop,@vides);}
    else {
      say " ### no vertices in the API result!\n";
      return undef
    }
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
	 }
}

# take a list of json crops as input and return the dimensions as a list of:
# all the x0
# then all the y0
# ... width
# ... height
sub decodeVertices {my $arg = shift;

  my @vertices = @{$arg}; # get the reference to the array

	my @x0 = ();
	my @y0 = ();
	my @width=();
	my @height=();
  my $x;
  my $y;
  my $count=1;

say "decodeVertices...";
#say Dumper @vertices;
foreach my $v ( @vertices ) {
 if ($count%2 != 0) { # we have to consider on crop every 2 as the API returns 2 crops for each face
	my $decoded = decode_json("{\"vertices\": [".$v."]}");
	my @dv = @{ $decoded->{'vertices'} };
  say Dumper @dv;
	$x = $dv[0]->{"x"} || 0;

	#if (defined $dv[0]->{"x"})  { # first point: up/left
  	 #$x = $dv[0]->{"x"};
     push @x0, $x;
     print "x0: $x";
	#if (defined $dv[0]->{"y"})  {
  $y = $dv[0]->{"y"} || 0;
	   #$y = $dv[0]->{"y"};
     push @y0, $y;
     print " - y0: $y ";
	#if (defined $dv[2]->{"x"})  { # 3rd point: down/right
	my $tmp = $dv[2]->{"x"} || 0;
      push @width, $tmp - $x;
      print " - w: ".($tmp - $x);
	#if (defined $dv[2]->{"y"})  {
  $tmp = $dv[2]->{"y"} || 0;
  #$h = $dv[2]->{"y"} - $y;
      push @height, $tmp - $y;
      say " - h: ".($tmp - $y);
    }
   $count++;
  }
	return (@x0,@y0,@width,@height)
}

# call the Watson API on a file path
# return: the list of classes followed by the confidence scores
sub callibmDF {my $img=shift;

	my @classes;
	my @scores;

	#my $cmd=  "curl -X POST -F \"images_file=@".$ill."\" \"".$endPointWatson."detect_faces?api_key=$apiKeyWatson&version=2016-05-20\"";
	say "img file: ".$img;
#  my $cmd=  "curl -u  \"apikey:".$apiKeyWatson."\" \"".$endPointWatson."detect_faces?url=$url&version=2018-03-19\"";
  my $cmd =  "cd /tmp;curl -X POST -u \"apikey:".$apiKeyWatson."\" --form \"images_file=\@".$img."\"  \"".$endPointWatson."detect_faces?version=2018-03-19\"";
  say $cmd;
  my $res = `$cmd`;

	say "res : ".$res;

	if ($res and (index($res, "ERROR") == -1))   {
		(@genders) = do { local $/; $res =~ m/$motifGenreWatson/g };
    $visages = scalar(@genders);
    say " number of faces detected: $visages";
		(@scores) = do { local $/; $res =~ m/$motifScoreWatson/g };
		(@agesMin) = do { local $/; $res =~ m/$motifAgeMinWatson/g };
		#(@agesMax) = do { local $/; $res =~ m/$motifAgeMax/g };
		(@Xo) = do { local $/; $res =~ m/$motifXoWatson/g };
		(@Yo) = do { local $/; $res =~ m/$motifYoWatson/g };
		(@Larg) = do { local $/; $res =~ m/$motifLargWatson/g };
		(@Haut) = do { local $/; $res =~ m/$motifHautWatson/g };
		if (@genders) {
		  return ($visages,@genders,@scores,@Xo,@Yo,@Larg,@Haut,@agesMin);}
		else {return (0)}
	}
	else {
	 	say " ### API error: ".$res;
	 	return (0)
	 }
}

## fix the CS bug
sub hd_fixFace {
    my ($t, $elt) = @_;

   if (($elt->text() eq "face") and ($elt->att('CS') == 0)) {
     say "--> ".$elt->att('sexe');
		 $elt->del_att("CS");
		 $elt->set_att("CS","1");
		 $elt->del_att("sexe");
		 $elt->set_att("sexe","P");
		 $nbTotIll++;
	 }
 }

 # ---------------------- classification data importation -------------------


 # import the classification data (e.g. from OpenCV/dnn, yolo...)
 sub hd_importCC {
     my ($t, $elt) = @_;

     my $fact = 100/$factIIIF; # ratio to set the dimensions in the original image space
     my @ills = $elt->children('ill');

     for my $ill (@ills) {
      $nill = $ill->att("n");
      say "\nn : $nill";
      $nill = "$idArk-$nill";
			# do we have some data?
			my $res = isHashed($nill);
     	if ($res) {
      # do we need to classify?
			my $classify = classifyReady($ill);
      if ($classify) {
			   my $threshold = ($classify==1) ? $CSthreshold*1.2 :	$CSthreshold; # increase the threshold for difficult cases
				 say " threshold: ".$threshold;
         $nbTotIll++;
         updateClassif($ill);
         my @data = split(/_+/, $res); # split multiple detections on _ character
         for my $d (@data) {
     	     say " data: $d"; # returns label,x,y,w,h,confidence score
            my @md = split(/\,+/, $d);
            my $score = sprintf("%.2f",$md[5]);
            if ($score >= $threshold) {
              $nbTotDF++;
							switch ($SERVICE)  {
								# face detection
								case "importDF" {
              	$ill->insert_new_elt('contenuImg', $md[0])->set_atts("lang"=>"en","sexe"=>"P","CS"=>$score,"source"=>$classifCBIR,
 						 "x"=>int($md[1]*$fact),"y"=>int($md[2]*$fact),"w"=>int($md[3]*$fact), "h"=>int($md[4]*$fact));}
						 	  # generic case
								case "importCC" {
								my $label = $md[0];
								if (index($label,"_") != -1)  {
                  $label =~ s/_/ /g;# replace the _ with a space
									}
              	$ill->insert_new_elt('contenuImg', $label)->set_atts("lang"=>"en","CS"=>$score,"source"=>$classifCBIR,
 						 "x"=>int($md[1]*$fact),"y"=>int($md[2]*$fact),"w"=>int($md[3]*$fact), "h"=>int($md[4]*$fact));
					 }
					 }
            }
            else {
              say " # confidence $score < $threshold! #"
            }
           }
     	 }
       }
     }
 }

## reset the IDs numbering
sub hd_updateID {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say " page : $page";
    my $n=1;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	#my $n = $ill->att('n');
    	$ill->set_att("n",$page."-".$n);  # IDs has this pattern: n° page-n° illustration
    	say " n: ".$ill->att('n');
    	$n++;
    	$nbTotIll++;
    }
}

## reset the face IDs numbering
sub hd_updateFaceID {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
    say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      my @faces = $ill->children('contenuImg[text()="face"]');
      my $illID = $ill->att('n');
      my $n = 1;
      for my $face( @faces ) {
         my $faceID =  $illID."-".$n;
    	   $face->set_att("n", $faceID);  # IDs has this pattern: n° page-n° illustration
    	   say " ID set to: ".$faceID;
    	   $n++;}
    	$nbTotIll++;
    }
}

############################
# detect color
sub hd_color {
	my ($t, $elt) = @_;

  my $couleur;

	my $page = $elt->parent->att('ordre');
	say " page : $page";

	my @ills = $elt->children('ill');
	for my $ill ( @ills ) {
		$nill = $ill->att('n');
		undef $couleur;
		$couleur = $ill->att('couleur');
		if (defined $couleur) {	# do not analyse if available
				say "$nill -> color already defined";
				#$already++;
				next}
		$ficImg = "$OUT/$idArk-$nill.jpg";
		unlink $ficImg;
		# handle the rotation
		$rotation = $ill->att('rotation');
		$rotation ||= "0";

		#handle the image size
    $redim = IIIF_setSize("std",$w,$h);

		my $url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$ill->att('w').",".$ill->att('h').$redim."/$rotation/native.jpg";
		say "$nill --> ".$url;
		if (IIIFextract($url,$ficImg)) {
	 		my $info = image_info($ficImg);
	 		if (my $error = $info->{error}) {
     		say "### can't parse image info: \n$error";
  			}
			my $color = $info->{SamplesPerPixel};
			undef $couleur;
			switch ($color) {
				case "1"		{ $couleur="gris";  }
				case "3"		{ $couleur="coul";  }
				else		{ say "### color mode unknown: $color ###";
									next}
	    }
			say "** color : ".$couleur;
			$ill->set_att("couleur","$couleur");
			$nbTotIll++;
    }
	}
}

# reset the color mode
sub hd_updateColor {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      if (not($ill->att("couleur"))) {
      #if ($ill->att("couleur") eq "mono") {
    	  $ill->set_att("couleur",$couleur);
        print " +";
    	  $nbTotIll++;
      }
    }
}

# reset a specific technique (from a specific source)
sub hd_updateTech {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @techs = $ill->children('tech');
			for my $t ( @techs ) {
    	 my $tmp = $t->att('source');
    	 if ((defined $tmp) and ($tmp eq $classifSource) and ($t->text eq $illTechOld)) {
				 $t->delete;
    		 $ill->insert_new_elt("tech","$illTechNew")->set_atts("source"=>$classifSource);
				 print " +";
				 $nbTotIll++;
			}
    }
  }
}

# convert illustrations genre to technique
sub hd_fixGenre2Tech {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre');
    	for my $g ( @genres ) {
         $genreIll = $g->text;
    		 $techIll = $genre2tech{$genreIll};
         if ($techIll) {
				   say "  fixing genre/$genreIll -> tech/$techIll";
           $g->set_tag("tech");
           $g->set_text($techIll);
           print " +";
				   $nbTotIll++;}
			}
    }
}

# convert illustrations genre to fonction
sub hd_fixGenre2Function {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre');
      my @fonctions = $ill->children('fonction');
    	for my $g ( @genres ) {
         $genreIll = $g->text;
    		 $fonctionIll = $genre2fonction{$genreIll};
         if ($fonctionIll) {
           # delete fonction if exists
           for my $f ( @fonctions ) { $f->delete}
				   say "  fixing genre/$genreIll -> fonction/$fonctionIll";
           $g->set_tag("fonction");
           $g->set_text($fonctionIll);
				   $nbTotIll++;}
			}
    }
}

# convert illustrations tech to technique + fonction
sub hd_fixTech2Tech {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @techs = $ill->children('tech');
    	for my $t ( @techs ) {
         $techIll = $t->text;
         $source = $t->att('source');
    		 $newTechIll = $tech2tech{$techIll};
         $fonctionIll = $tech2fonction{$techIll};
         if ($newTechIll) {
				   say "  fixing tech/$techIll -> tech/$newTechIll";
           $t->set_text($newTechIll);
				   $nbTotIll++;}
         if (($fonctionIll) and $source eq "final") {
  				   say "  adding function -> fonction/$fonctionIll";
             $ill->insert_new_elt("fonction",$fonctionIll)->set_atts("source"=>"hm");
             $ill->insert_new_elt("fonction",$fonctionIll)->set_atts("source"=>"final");
  				}
			}
    }
}

# convert illustrations genres for periodicals
sub hd_fixGenrePeriodicals {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre[@source="final" or @source="hm" or @source="cwd"]');
      if (@genres) {
    	 for my $g ( @genres ) {
         $genreIll = $g->text;
         say "genre: ".$g->text;
         if (($genreIll ne "illustration de presse") and ($genreIll ne "filtre") and ($genreIll ne "publicite")) {
    		     say "  fixing genre: $genreIll -> genre: illustration de presse/$genreIll";
             $g->set_text("illustration de presse/".$genreIll);
             $techIll = $genre2tech{$genreIll};
				     $nbTotIll++;
           }
        }
      } else {
        say "  creating genre: illustration de presse";
        $ill->insert_new_elt("genre","illustration de presse")->set_atts("source"=>"hm");
        $ill->insert_new_elt("genre","illustration de presse")->set_atts("source"=>"final");
        $nbTotIll++;
       }

		}
}

# fix illustrations genres for periodicals
sub hd_fixDrawingPeriodicals {
    my ($t, $elt) = @_;

    my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre[@source="final" or @source="hm" or @source="cwd"]');
      my @techs = $ill->children('tech[@source="final"]');

      if (@techs and ($techs[0]->text() eq "dessin")) {
          say "  technique: ".$techs[0]->text();
          for my $g ( @genres ) {
            $g->set_text("illustration de presse/dessin");
            $nbTotIll++;}
    }}
}

# fix illustrations with no genre
sub hd_fixNoGenre {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre[@source="final"]');

    	if (not @genres) {
        my $tmp = $ill->att('pub');
     	  if ((defined $tmp) and ($tmp eq "1")) {
    		   $ill->insert_new_elt("genre","$illGenreNew")->set_atts("source"=>$classifSource);
           $ill->insert_new_elt("genre","$illGenreNew")->set_atts("source"=>"final");
				   print " +";
				   $nbTotIll++;}
			}
    }
}

# fix illustrations with no technique
sub hd_fixNoTech {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @techs = $ill->children('tech[@source="final"]');
    	if (not @techs) {
    		 $ill->insert_new_elt("tech","$illTechNew")->set_atts("source"=>$classifSource);
         $ill->insert_new_elt("tech","$illTechNew")->set_atts("source"=>"final");
				 print " +";
				 $nbTotIll++;
			}
    }
}

# fix illustrations with no genre
sub hd_fixNoFunction {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @fonctions = $ill->children('fonction[@source="final"]');
    	if (not @fonctions) {
    		 $ill->insert_new_elt("fonction","$illFonctionNew")->set_atts("source"=>$classifSource);
         $ill->insert_new_elt("fonction","$illFonctionNew")->set_atts("source"=>"final");
				 print " +";
				 $nbTotIll++;
			}
    }
}

# set ads genre on last pages
sub hd_fixAdGenre {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre');
			for my $g ( @genres ) {
    	 my $tmp = $g->att('source');
    	 if ((defined $tmp) and ($tmp eq $classifSource) and ($g->text eq $illGenreOld)) {
				 $g->delete; # suppress it
				 if ($page>2) {
    		 	$ill->insert_new_elt("genre","publicite")->set_atts("source"=>$classifSource);
				} else {
					$ill->insert_new_elt("genre","$illGenreNew")->set_atts("source"=>$classifSource);
				}
				 print " +";
				 $nbTotIll++;
			}
    }
  }
}

# reset the theme (from a specific source)
sub hd_updateTheme {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @themes = $ill->children('theme');
			for my $g ( @themes ) {
    	 my $tmp = $g->att('source');
    	 if ((defined $tmp) and ($tmp eq $classifSource)) {
				 $g->delete; # suppress it
    		 $ill->insert_new_elt("theme","$illThemeNew")->set_atts("source"=>"md");
				 print " +";
				 $nbTotIll++;
			}
    }
  }
}

# reset the source to say its a MD source (as opposite to TF or human)
# delete empty elements
# delete attributes pub, filtre
# NOTE : -unify option needs to be ran after fixSource
sub hd_fixSource {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			$nbTotIll++;
    	my @genres = $ill->children('genre');
			if (@genres) {
			 for my $g ( @genres ) {
		       if ((not $g->text()) or ($g->text() eq "")) {
		        	  say " - empty genre - ";
		           $g->delete;}
		      else {
					  say " genre : ".$g->text();
					  if (not $g->att('source')) {
				  	  $g->set_att("source",$classifSource);}
			    }
				}
			}
			my @themes = $ill->children('theme');
			if (@themes) {
			 for my $t ( @themes ) {
				 if ((not $t->text()) or ($t->text() eq "")) {
							say " - empty theme - ";
						 $t->delete;}
				else {
				  say $t->text();
				  if (not $t->att('source')) {
						$t->set_att("source",$classifSource);}
			  }
			 }
			}

			# ad
			if ($ill->att('pub')) {
				say " ->pub";
				#$ill->set_att("pubmd",1);
				$ill->insert_new_elt("genre","publicite")->set_atts("source"=>$classifSource);
				$ill->del_att("pub"); # suppress the old one
			}
			my @tmp = $ill->children('titraille');
			if (@tmp and ($tmp[0]->text() eq "Publicité")) {
				say " ->pub titraille";
				#$ill->set_att("pubmd",1);
				$ill->insert_new_elt("genre","publicite")->set_atts("source"=>$classifSource);
				$ill->del_att("pub"); # suppress the old one
			}
			# filter
			if ($ill->att('filtre')) {
				say " ->filter";
				#$ill->set_att("filtremd",1); # create a new one
			  $ill->del_att("filtre"); # suppress the old one
				# if no genre, create one
			  #if (not @genres) {
					#say " ->filter";
				$ill->insert_new_elt("genre","filtre")->set_atts("source"=>$classifSource);
				#}
			}
    }
}

# set the pub attribute if title="Publicité"
# to be used with OLR newspapers
# unify option needs to be ran after
sub hd_fixAdOLR {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

		my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			say " n : ".$ill->att("n");
			my @tmp = $ill->children('titraille');
			if (@tmp and ($tmp[0]->text() eq "Publicité")) { # article heading = "ad"
				my $genrePub = $ill->first_child_text(\&is_ad);
				#my $genrePub = $ill->get_xpath('.[genre="publicite"]', 0);
				#say $genrePub;
				#say scalar($genres);
			  if ($genrePub ne "publicite") {  # if not yet described as ad
					say " ->set as ad from heading";
					$nbTotIll++;
					$ill->insert_new_elt("genre","publicite")->set_atts("source"=>"md");
					#$ill->set_att("pub",1);
				}
			}
		}
	}

  sub hd_fixAd {
      my ($t, $elt) = @_;

  		my $page = $elt->parent->att('ordre');
  		say " page : $page";

  		my @ills = $elt->children('ill');
      for my $ill ( @ills ) {
  			say " n : ".$ill->att("n");
  			my @tmp = $ill->children('genre[text()="publicité" and @source="final"]');
  			if (@tmp ) {
  					$nbTotIll++;
            print "+";
  					$ill->set_att("pub"=>"1");
  				}
  			}
  		}


	sub hd_fixRotation {
	    my ($t, $elt) = @_;

			my $page = $elt->parent->att('ordre');
			say " page : $page";

			my @ills = $elt->children('ill');
	    for my $ill ( @ills ) {
				my $tmp = $ill->att("rotation");
				if ($tmp and ($tmp<0)) { #
				  say "rotation : ".$tmp;
					$tmp = 360+$tmp;
					say "---> ".$tmp;
					$nbTotIll++;
					$ill->set_att("rotation",$tmp);
					}
				}
			}

sub is_ad {
	    my ($element) = @_;

	    if ($element->text() eq 'publicite'
	        and $element->att('source') eq 'md' )
	     {return 1;}
	}

# fix the lang attribute
sub hd_fixLang {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say "\n page : $page ";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			$nbTotIll++;
			my @cbir = $ill->children('contenuImg');
			if (@cbir) {
			 $nbTotIll++;
			 for my $c (@cbir) {
         my $contenu = $c->text();
				 if ($contenu eq "face") {
						print " -face- ";}
				 else {
           if (not $c->att('lang')) {
             print "+";
             $nbTotTrans++;
             $c->set_att("lang",'en');}
           }
         }
     }
    }
  }

# fix the @coul attribute on ContentImg
sub hd_fixColor {
      my ($t, $elt) = @_;

  		my $page = $elt->parent->att('ordre');
  		say "\n page : $page ";

      my @ills = $elt->children('ill');
      for my $ill ( @ills ) {
  			$nbTotIll++;
  			my @cbir = $ill->children('contenuImg');
  			if (@cbir) {
  			 $nbTotIll++;
  			 for my $c (@cbir) {
           my $contenu = $c->text();
  				 if (isColor(lc($contenu)) and not $c->att('coul')) {
              print $contenu." - ";
              $nbTotTrans++;
              $c->set_att("coul",'1');}
             }
       }
      }
    }

sub isColor{my $string=shift;
 if ( grep( /^$string$/, @couleurs ) ) {
  return 1
 }
}

# fix the source attribute of image content classification using IBM/Watson
# delete empty elements
# recompute the "classif" attribute
sub hd_fixCBIRsource {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			$nbTotIll++;
			my $classifCC;
			my $classifDF;
			my $classif = $ill->att('classif');
			$ill->del_att("classif");
			my @cbir = $ill->children('contenuImg');
			if (@cbir) {
			 $nbTotIll++;
			 for my $c (@cbir) {
				 my $tmp = $c->text();
				 if ((not $tmp) or ($tmp eq "")) {
						say " - empty content - ";
						$c->delete;}
				 else {
				  # set the source attribute
					if (($tmp eq "face") or ($tmp eq "faceCA")) {$classifDF=1;}
					   else {$classifCC=1;}
				  if (not $c->att('source')) {
						print "+";
						$c->set_att("source",$classifCBIR);}
			  }
			} # end for
			# recreate the classif attribute
			if (($classifCC) and not ($classifDF)) { # set DF and CC again
	        $ill->set_att("classif","CCibm");
				  say "...CCibm";}
	    elsif (not $classifCC and $classifDF) {
				$ill->set_att("classif","DFibm");
				say "...DFibm";}
			elsif ($classifCC and $classifDF) {
				$ill->set_att("classif","CCibm DFibm");
			  say "...CCibm DFibm";}
			}
    }
}

# update the classif attribute : CC to CCibm / DF to DFibm
sub hd_fixCBIRClassif {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			$nbTotIll++;
			$nill = $ill->att('n');
			my $classif = $ill->att('classif');
			if ($classif) {
				$ill->del_att("classif");
				switch ($classif) {
					case "CC"		{$newClassif="CCibm"}
					case "DF"		{$newClassif="DFibm"}
					case "CC DF"		{$newClassif="CCibm DFibm"}
					case "DF CC"		{$newClassif="CCibm DFibm"}
					case "DFdnn"		{$newClassif="DFdnn"}
					case "DF DFdnn"		{$newClassif="DFibm DFdnn"}
					case "CC DFdnn"		{$newClassif="CCibm DFdnn"}
					case "DFdnn CC" {$newClassif="CCibm DFdnn"}
					case "CC DF DFdnn"		{$newClassif="CCibm DFibm DFdnn"}
					case "CC CCgoogle"		{$newClassif="CCibm CCgoogle"}
					case "CC DFdnn CCgoogle" {$newClassif="CCibm DFdnn CCgoogle"}
					case "CC DF CCgoogle" {$newClassif="CCibm DFibm CCgoogle"}
					else {$newClassif=$classif;
					say "#### $nill -> $classif: unknown! ####"; $nbFailIll++}
					}
				say "  $nill -> $newClassif";
	    	$ill->set_att("classif",$newClassif);
		  }
    }
}

# fix h and w when they don't exist on Google croppings
# replace with the illustration w & h
sub hd_fixGoogleHL {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      $wIll = int($ill->att('w'))*0.9;
      $hIll = int($ill->att('h'))*0.9;
			my @cbir = $ill->children('contenuImg[text()!="face" and @source="google"]');
			if (@cbir) {
			 $nbTotIll++;
			 for my $c (@cbir) {
         #say $c->text();
         $h = $c->att('h');
         $l = $c->att('w');
         if (defined $h and int($h) < 2) {
						print "+";
						$c->set_att("h",$hIll);}
         if (defined $l and int($l < 2)) {
   						print "+";
   						$c->set_att("l",$wIll);}
          }
			  }
			}
	}

  # fix croppings after a resegmentation of an illustration
  # x and y's crop are updated
  # eventually, w and h are set to illustration dimensions
  sub hd_updateCrops {
      my ($t, $elt) = @_;

  		my $page = $elt->parent->att('ordre');
  		say " page: $page";

      my @ills = $elt->children('ill[@seg="1"]');
      if (scalar(@ills) != 1) {
    	   say "--> we only process one illustration/page case";
         return}

      for my $ill ( @ills ) {
        $xIll = int($ill->att('x'));
        $yIll = int($ill->att('y'));
        $wIll = int($ill->att('w'));
        $hIll = int($ill->att('h'));
        say " illustration : x=$xIll , y=$yIll";
  			my @cbir = $ill->children('contenuImg[@source="dnn"]');
  			if (@cbir) {
  			 $nbTotIll++;
  			 for my $c (@cbir) {
           say $c->text();
           $x = $c->att('x');
           $y = $c->att('y');
           $w = $c->att('w');
           $h = $c->att('h');
           if (defined $x) {
              my $newX = int($x) - $xIll;
              if ($newX < 0) {$newX = 1}
  						say " x: $x -> $newX";
  						$c->set_att("x",$newX);}
           if (defined $y) {
              my $newY = int($y) - $yIll;
              if ($newY < 0) {$newY = 1}
              say " y: $y -> $newY";
     					$c->set_att("y",$newY)
            }
          if ((defined $w) and ($w > $wIll)) {$c->set_att("w",$wIll)}
          if ((defined $h) and ($h > $hIll)) {$c->set_att("h",$hIll)}
            }
  			  }
  			}
  	}

# get the illustration technique
sub getTech {
    my $ill=shift;

	 if ($ill->children('tech')) {
		 my $techFinal = $ill->get_xpath('./tech[@source="final"]', 0);
		 if ($techFinal) {
       say "-> technique: ".$techFinal->text();
			 return $techFinal->text();
		 }
   }
  return undef
}

# get the illustration function
sub getFunction {
    my $ill=shift;

	 if ($ill->children('tech')) {
		 my $functionFinal = $ill->get_xpath('./fonction[@source="final"]', 0);
		 if ($functionFinal) {
       say "-> function: ".$functionFinal->text();
			 return $functionFinal->text();
		 }
   }
  return undef
}

# set the final function and the filters
sub setFinal {
	my $ill=shift;
  my $element=shift;
	my $mode=shift;  # "hm"/"md"/"tf"
  my $f=shift;

	say " -> $element $mode: $f";
	$ill->insert_new_elt($element,$f)->set_atts("source"=>"final");
	# ads case?
	if (index($f,"publicit")!=-1) {
		$ill->set_att("pub",1)}
  else {
    #my $tmp = $ill->att("pub");
    #if (defined $tmp) {
    #  $ill->del_att("pub")}
    }
	# filter case?
  my $tmp = $ill->att("filtre"); # final filter classification
  if (defined $tmp) {
    $ill->del_att("filtre");
    print " -"}
	$tmp = "filtre".$mode;
	if (index($f,"filtre") != -1){
				$ill->set_att($tmp,1);
				$ill->set_att("filtre",1)}
}

# unify the function in the <function source=final> element
sub hd_unifyFunction {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			#my $filtre = $ill->att("filtre"); # filtered illustrations
	    #if (not defined $filtre) {
			 $nbTotIll++;
			 say " n : ".$ill->att('n');
			 my $final ;
			 if ($ill->children('fonction')) {
				@fonctionFinal = $ill->get_xpath('./fonction[@source="final"]');
				if (@fonctionFinal) {  # Reset
				  for my $f ( @fonctionFinal ) {
				   $f->delete()}
				}
				$fonctionMD = $ill->first_child_text('fonction[@source="md"]');
				$fonctionTF = $ill->first_child_text('fonction[@source="TensorFlow"]');
				$fonctionHM = $ill->first_child_text('fonction[@source="hm"]'); # or 'cwd'

				# process the results
				if ($fonctionHM and ((not $forceTFOnHM) or
           ($forceTFOnHM and not $fonctionTF))) { # top priority
				  $final = $fonctionHM;
					setFinal($ill,"fonction","hm",$final)

				} # priority on metatada except if TF is forced
				elsif ($fonctionMD and ($fonctionMD ne "inconnu") and ($fonctionMD ne "")
				    and ((not $forceTFOnMD) or ($forceTFOnMD and not $fonctionTF)))  {
					$final = $fonctionMD;
					setFinal($ill,"fonction","md",$final);
					# special case: text ads must be filtered
 					#if (($fonctionMD eq "publicite") and ($fonctionTF eq "filtretxt")) {
					#	say " -> tf : filtretxt";
					#	$ill->set_att("filtretf",1);
					#	$ill->set_att("filtre",1)
					#}
				} # use TF classification
				elsif (defined $fonctionTF) {
					$final = $fonctionTF;
					setFinal($ill,"fonction","tf",$final)
				}
			}
			if (not defined $final)
				 {say "** no final function! **"}
			}
}

sub hd_unifyTech  {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			#my $filtre = $ill->att("filtre"); # filtered illustrations
	    #if (not defined $filtre) {
			 $nbTotIll++;
			 say " n : ".$ill->att('n');
			 my $final ;
			 if ($ill->children('tech')) {
				@techFinal = $ill->get_xpath('./tech[@source="final"]');
				if (@techFinal) {  # Reset
				  for my $t ( @techFinal ) {
				   $t->delete()}
				 }
				$techMD = $ill->first_child_text('tech[@source="md"]');
				$techTF = $ill->first_child_text('tech[@source="TensorFlow"]');
				$techHM = $ill->first_child_text('tech[@source="hm"]'); # or 'cwd'

				# process the results
				if ($techHM and ((not $forceTFOnHM) or
           ($forceTFOnHM and not $techTF))) { # top priority
				  $final = $techHM;
          setFinal($ill,"tech","hm",$final)
				} # priority on metatada except if TF is forced
				elsif ($techMD and ($techMD ne "inconnu") and ($techMD ne "")
				    and ((not $forceTFOnMD) or ($forceTFOnMD and not $techTF)))  {
					$final = $techMD;
          setFinal($ill,"tech","md",$final)
				} # use TF classification
				elsif (defined $techTF) {
					$final = $techTF;
          setFinal($ill,"tech","tf",$final)
				}
			}
			if (not defined $final)
				 {say "** no final technique **"}
			}
}

# unify the theme in the <theme source=final> element
sub hd_unifyTheme {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			#my $filtre = $ill->att("filtre"); # filtered illustrations
	    #if (not defined $filtre) {
			 $nbTotIll++;
			 if ($ill->children('theme')) {
				@themesFinal = $ill->get_xpath('./theme[@source="final"]');
				if (@themesFinal) {  # Reset
				 for my $t ( @themesFinal ) {
				   $t->delete()}}
				$themeMD = $ill->get_xpath('./theme[@source="md"]', 0); # there can be only one theme by category
				$themeHM = $ill->get_xpath('./theme[@source="hm"]', 0);

				# process the results
				if (defined $themeHM) { # top priority
				  my $tmp = $themeHM->text;
					say " -> hm : $tmp";
					$ill->insert_new_elt("theme",$tmp)->set_atts("source"=>"final");
				} # else priority on metatada
				elsif ((defined $themeMD) and ($themeMD->text ne "inconnu") and ($themeMD->text ne "")) {
					say " -> md";
					my $tmp = $themeMD->text;
					$ill->insert_new_elt("theme",$tmp)->set_atts("source"=>"final");}
				else
				{say "** no final theme **"}
			}
		 #}
    }
}

# delete filter attributes that are automatically generated
sub hd_deleteFilter {
	my ($t, $elt) = @_;

	my $page = $elt->parent->att('ordre');
	print "\n page $page: ";

	my @ills = $elt->children('ill');
	for my $ill ( @ills ) {
		$nbTotIll++;
		my $filtre = $ill->att("filtre"); # final filter classification
		if (defined $filtre) {
			$ill->del_att("filtre");
		  print " -"}  # reset
		$filtre = $ill->att("pub"); # pub classification
			if (defined $filtre) {
				$ill->del_att("pub");
			  print " -"}  # reset
		$filtre = $ill->att("filtretf"); # filtered illustrations from TensorFlow
		if (defined $filtre) {
			$ill->del_att("filtretf");
		  print " -"}  # reset
		$filtre = $ill->att("filtremd"); # filtered illustrations from metadata
		if (defined $filtre) {
				$ill->del_att("filtremd");
			  print " -"}  # reset
	}
}


# unify the filtering on the filter attribute
sub hd_unifyFilter {
	my ($t, $elt) = @_;

	my $page = $elt->parent->att('ordre');
	say " page : $page";

	my @ills = $elt->children('ill');
	for my $ill ( @ills ) {
		$nbTotIll++;
		#my $filtre = $ill->att("filtre"); # filtered illustrations from MD + human corrections
		my $filtreMD = $ill->att("filtremd"); # filtered illustrations from MD
		my $filtreTF = $ill->att("filtretf"); # filtered illustrations from TensorFlow
		my $filtreHM = $ill->att("filtrehm"); # filtered illustrations from human

		if ($filtreHM or $filtreMD or (not (defined $filtreMD) and $filtreTF)) {
			$ill->set_att("filtre",1)}  # use TF classification data to filter

	}
}

# reset the document type from a tech classification
sub hd_fixType {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my $meta = $elt->parent->parent->parent->first_child;
    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $tmp = $ill->first_child('tech');
    	if ((defined $tmp) and ($tmp->text() eq $illTechOld)) {
				$nbTotIll++;
				# suppress
				# $tmp->delete; # non, on garde pour la facette GENRE
				# suppress the type
				$meta->first_child('type')->delete;
				# and replace it with the right type
				$meta->insert_new_elt("type",$documentType);
			}
    }
}


# set the DF metadata : a revoir
sub updatePerson {
    my ($t, $elt) = @_;

    my $classif;

    say "### DF / id illustration : ".$idIll;

    if ( $idIll eq $elt->att('n') ) {
    	$classif = $elt->{'att'}->{'classif'};
    	if (defined ($classif)) {
    	 $classif .= " DF";}
    		else {$classif = "DF";}

    	$elt->set_att("classif",$classif);
    	if (scalar(@genders) == 0) {
    	   say "--> pas de visage !";}

    	foreach my $i  (0..scalar(@genders)-1) {
       if ($genders[$i]eq "MALE") {
        $elt->insert_new_elt( 'contenuImg', "face" )->set_atts("genre"=>"H","age"=>$ages[$i]);}
        else
        {$elt->insert_new_elt( 'contenuImg', "face" )->set_atts("genre"=>"F","age"=>$ages[$i]);}
      }
    $elt->print;
    }

}


# ---------------------- TensorFlow -------------------

# set the image function from TensorFlow classification data
sub hd_TFfilter {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $nill = $ill->att("n");
			my $page = $elt->parent->att('ordre');
    	$nill = "$idArk-$nill";
      $nbTot++;
    	if (($OPTION) and ($OPTION="news"))
			 {@fonctionTF = isTFclassify_news($nill,$page);}
			 else {@fonctionTF = isTFclassify($nill);}
			#say Dumper @genreIll;
			my $f = $fonctionTF[0];
    	if ($f ne "-1") { # we have a classification
        if (defined $fonctionClassif and index($fonctionClassif,$f) ==-1) { # we only want to get some functions
             say " # illustration is not a $fonctionClassif!";
             return}
				my $CS = $fonctionTF[1];
    	  say " --> illustration function: $f (CS: $CS)";
    	  $ill->insert_new_elt('fonction', $f)->set_atts("CS"=>$CS,"source"=>"TensorFlow");
    	  $nbTotIll++;
    	}
    }
}

# try to detect some false positive filtered illustrations (MD) thanks to the TensorFlow classification data
# aims a specific function set by $illFonctionNew
sub hd_TFunFilter {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $nill = $ill->att("n");
			say $nill;
			my $page = $elt->parent->att('ordre');
    	$nill = "$idArk-$nill";
			my $genre = $ill->get_xpath('./fonction[@source="final"]', 0); # the final genre
			my $genreMD = $ill->get_xpath('./fonction[@source="md"]', 0); # the MD genre
			if (($genre) and ($genreMD)) {
			 print " function: ".$genre->text()."\n";
			 if ((index($genre->text(),"filtre") == -1) and ($genreMD->text() ne "filtre")) {
				say "...not a filtered MD function!";}
			 else {
			 @genreIll = isTFclassify($nill);
			 $genre = $genreIll[0];
    	 if ($genre ne "-1") {
			  if ($genre eq $illFonctionNew) {
					my $CS = $genreIll[1];
    	  	say "... unfilter illustration with function: $genre (CS: $CS)";
    	  	$ill->insert_new_elt('fonction', $genre)->set_atts("CS"=>$CS,"source"=>"TensorFlow");
					# delete the filter information
					my $genreMD = $ill->get_xpath('./fonction[@source="md"]', 0);
					say " ... deleting function".$genreMD->text();
					$genreMD->delete();
    	  	$nbTotIll++; }
					else {say " the TF function is not a $illFonctionNew: can't be unfiltered"}
    	 }
		 }
    }
	}
}

# Say if an illustration is listed in the TensorFlow classifications
# with the required confidence score
# return: class  and its confidence value
# for newspapers
sub isTFclassify_news {
	my $fichier=shift;
	my $page=shift;

  my $top1CS=0;
	my $top2CS=0;
  my $nomFic=$fichier;

	say "TensorFlow newspapers: $nomFic (page : $page)";
  $nomFic =~ s/\//-/g;# replace the / with - to avoid issues on filename

	#to do : use a hash
	foreach my $i  (0..scalar(@listeDocs)-1) {
	 if (index($listeDocs[$i],$nomFic) != -1) { # the illustration name is in the TensorFlow data
	 	my @ligne=@{$externalData[$i]}; # the CSV data for the illustration
	 	#say Dumper @ligne;
	 	my $indiceClasse1;
		my $indiceClasse2;

	 	foreach my $j (0..$classesNumber-1) { # look for the highest confidence score in the line
	 		my $CS = $ligne[$j];
	 		#say $j." - ".$CS;
	 		if ($CS > $top1CS) {
	 			#say "hit: $CS";
	 			$top1CS = $CS;
	 		  $indiceClasse1 = $j}
			}
		say "top1: $top1CS";
		my $fonction = $listeClasses[$indiceClasse1];
		switch ($fonction) {
				case "filtreornement"		{ # difficult classes: higher confidence score
					# if the confidence score is > threshold
		  		if ($top1CS > $TFthreshold*1.2) {
		     		return ($fonction,$top1CS);
					  say " $top1CS CS for '$fonction' is < $TFthreshold*1.2 threshold!";}
	 	    }
				case "publicite"		{
					say "ad...";
		  	 if  ($lookForAds) {
					if (($page != 1) # can't be an ad on cover page (assumption...)
						and ($top1CS > $TFthreshold*1.1)) # if the confidence score is > threshold
						{return ($fonction,$top1CS);}
					else {
						say "... can't be an ad here! Get 2nd choice";
						foreach my $j (0..$classesNumber-1) { # look for the 2nd highest confidence score
							my $CS = $ligne[$j];
							if (($CS > $top2CS) and ($CS<$top1CS)) {
					 			$top2CS = $CS;
					 		  $indiceClasse2 = $j}
					 	}
						say "top2: $top2CS";
						return ($listeClasses[$indiceClasse2],$top2CS);}
	 	    } else {
					say "... don't look for ads"
				}}
				else {
					if ($top1CS > $TFthreshold) {
						return ($fonction,$top1CS);}
					else {say " $top1CS CS for '$fonction' is < $TFthreshold threshold!";}
				}
	   }
	 	return "-1";
  }
 }
 say "\n### $nomFic not in the TensorFlow data! ###";
 return "-1"
}


# look for the classification data
sub isTFclassify {
	my $fichier=shift;

  my $tmpCS=0;
  my $nomFic=$fichier;

	say "TensorFlow: ".$nomFic;
  $nomFic =~ s/\//-/g;# replace the / with - to avoid issues on filename

	#to do : use a hash
	foreach my $i  (0..scalar(@listeDocs)-1) {
	 if (index($listeDocs[$i],$nomFic) != -1) { # the illustration filename is in the TensorFlow data
	 	my @ligne=@{$externalData[$i]}; # the CSV data for the illustration
	 	#say Dumper @ligne;
	 	undef $indiceClasse;
	 	foreach my $j (0..$classesNumber-1) { # look for the highest confidence score in the line
	 		my $CS = $ligne[$j];
	 		#say $j." - ".$CS;
	 		if ($CS > $tmpCS) {
	 			#say "hit: $CS";
	 			$tmpCS = $CS;
	 		  $indiceClasse = $j}
	 	}
		my $classif = $listeClasses[$indiceClasse];
		if ($tmpCS > $TFthreshold) {		# if the confidence score is > threshold
		     #say " TF genre: $genre";
		     return ($classif,$tmpCS);} # return the class  and its confidence value
	 	else {
	 	 		say " $tmpCS CS for '$classif' is < $TFthreshold threshold!";
	 	 		return "-1"}
   }
 }
 say "\n### $nomFic not in the TensorFlow data! ###";
 return "-1"
}


# ---------------------- Image Hashing -------------------
# Say if an illustration is listed in the data
sub isHashed {
	my $nomFic=shift;

	#say "isHashed $nomFic?";
    my $tmp=$imageData{$nomFic};
    if (defined $tmp) {
    	return $tmp;
    }
    else {
      say "\n### $nomFic not in the data! ###";
    return undef}
}


# set the image hash
sub hd_hash {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill (@ills) {
    	$nill = $ill->att("n");
    	$nill = "$idArk-$nill.jpg";
    	my $hash = isHashed($nill);
    	if ($hash) {
    	  say " illustration hash: $hash";
    	  $ill->set_att("hash"=>$hash); # set hash
    	  $nbTotIll++;
    	}
			else {
				$ill->set_att("hash"=>""); # no hash
				say "#### illustration hash is missing: $nill";
				$nbFailIll++;
			}
    }
}

# set the image color
sub hd_importColors {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill (@ills) {
      my $nav = "contenuImg[\@source='colorific']";
			my @contenus= $ill->children($nav);
      if (@contenus) {
        say ".. illustration is already color indexed";
        next
      }
      my $counter=1;
    	$nill = $ill->att("n");
    	$nill = "$idArk-$nill.jpg";
    	my $hash = isHashed($nill);
    	if ($hash) {
    	  say " illustration color values: $hash";
        my ($frg, $bkg) = split(/\t/, $hash); #separate background color to foreground colors
        my (@hexFrg) = split(/,/, $frg); #separate foreground colors

        for $hex (@hexFrg) { # main colors
          say "..adding $hex color ($counter)";
          my @myRgb  = $rgb->hex2rgb($hex);
          $ill->insert_new_elt('contenuImg', $hex)->set_atts("source"=>"colorific","ordre"=>$counter,"coul"=>"1","type"=>"frg",
          "r"=>$myRgb[0],"g"=>$myRgb[1],"b"=>$myRgb[2]);
          $counter++;
        }
        if (($OPTION eq "bckg") and  $bkg) {
          say "..adding background color $bkg";
          my @myRgb  = $rgb->hex2rgb($bkg);
          $ill->insert_new_elt('contenuImg', $bkg)->set_atts("source"=>"colorific","coul"=>"1","type"=>"bkg",
          "r"=>$myRgb[0],"g"=>$myRgb[1],"b"=>$myRgb[2]);
        }
    	  $nbTotIll++;
    	}
			else {
				#$ill->set_att("hash"=>""); # no hash
				say "#### illustration color values are missing: $nill";
				$nbFailIll++;
			}
    }
}

# look for the TNA image id and set the image library url
sub hd_importTNA {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    my $meta = $elt->parent->parent->parent->parent->first_child;
    for my $ill (@ills) {
      my $counter=1;
    	my $nill = $ill->att("n");
      my $tnaRecord = $idArk;
      $tnaRecord =~ s/-/\//g; # replace the - with /
      $tnaRecord =~ s/BT/BT /g;
    	my $hash = isHashed($tnaRecord);
    	if ($hash) {
    	  say " illustration TNA id: $hash";
        $meta->insert_new_elt('url', $urlTNA.$hash);
    	  $nbTotIll++;
    	}
			else {
				#$ill->set_att("hash"=>""); # no hash
				say "#### illustration TNA id is missing: $nill";
				$nbFailIll++;
			}
    }
}

# ---------------------- Misc -------------------



sub rgb2hex {
    $red=$_[0];
    $green=$_[1];
    $blue=$_[2];
    $string=sprintf ("%2.2X%2.2X%2.2X",$red,$green,$blue);
    return (lc $string);
}

sub getColorName {$r=shift;$v=shift;$b=shift;

 my $hex = "\#";

 say "->getColorName";
 if ((not defined $r) or (not defined $v) or (not defined $b)) {
   say " ## missing parameters ##";
   return undef
 }
 say ".. looking for $r $v $b";
 my $proche = $imgFoo->colorClosest($r,$v,$b); # GD function
 if  ($proche != -1) {
 	 my @tmp = $imgFoo->rgb($proche);
 	 print " -> rgb: $tmp[0] $tmp[1] $tmp[2]\n"; # RGB values
   my $hexColor = rgb2hex($tmp[0],$tmp[1],$tmp[2]); # Hex value
   print " -> hex: $hexColor\n";
   while( my ($k,$v) = each(%COLORS) ) {
   #print $v."\n";
   if ($v eq $hexColor) {
   	print "hit: $k\n";
	 	return $k;
   	last}
   }
   say "hit: FAILED";
   return $hex.$hexColor
 }
 return undef
}

sub intersection {
      my $illA = shift;
      my $illB = shift;

    my @a = @{$illA}; # get the reference to the array
    my @b = @{$illB};

    $x = max($a[0], $b[0]);
    $y = max($a[1], $b[1]);
    $w = min($a[0]+$a[2], $b[0]+$b[2]) - $x;
    $h = min($a[1]+$a[3], $b[1]+$b[3]) - $y;
    if (($w<0) or ($h<0)) {
        return () }
    #print "1"
    return ($x, $y, $w, $h)
}

# ----------------------
# not used anymore #
# changer le filtre
sub TFfilter {
	my $fic=shift;
	my $nomFic=shift;

	say "*********************************\nfichier : ".$fic;

  # si le document a ete traite par TF
  if (traiteTF($nomFic) ) {

	my $fh = $fic->openr;
	my $xml = $fic->slurp;

	# parser les elements <ills>
  my $t = XML::Twig->new(
  twig_handlers => {
       '/analyseAlto/contenus/pages/page/ills' => \&updateTFfilter,
        },
    pretty_print => 'indented',
    );

  try {
    $t -> parse($xml);   }
  catch {
    warn "### Error while reading: $_ ###";
    say  "########################################";
    return 0;
  };

	open  $fh, '>', $fic or die $!;
	$t->print($fh);
	return 1;
 }
 else {say " -> $nomFic : document unknown in TensorFlow data";
 	return 1}
}

sub continuer {
 say " ********************************************";
 print " OK to continue? (Y/N)\n >";
 my $rep = <STDIN>;
 chomp $rep;
 if (($rep eq "N") or ($rep eq "n")) {die}
}
