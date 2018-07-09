#!/usr/bin/perl -w

# A FAIRE
#########
# extraire les infos des DMDID


#######################
# Generates metadata from METS/ALTO digitized newspapers (Europeana Newspapers) :
# usage : perl extractMD.pl [-LI] olren|ocren|olrbnf|ocrbnf titre IN OUT xml|json|csv
# -L : extraction of illustrations metadata  : captions, dimensions...
# -I : compute ARK identifiants (BnF only)
# mode :  documents type :  olren, ocren, olrbnf, ocrbnf
# title: newspaper title for the Europeana Newspapers corpus (otherwise, use "generic")
# IN : documents folder
# OUT : metadata folder
# format : xml|json|csv


# use strict;
use warnings;
use 5.010;
use LWP::Simple;
use Data::Dumper;
use XML::Twig;
use Path::Class;
use Path::Class::Entity;
use Benchmark qw(:all) ;
#use utf8::all;
use Date::Simple qw(date);
use Try::Tiny;
use Switch;
use List::MoreUtils 'first_index';

$t0 = Benchmark->new;

# Pour avoir un affichage correct sur STDOUT
binmode(STDOUT, ":utf8");

#################
#  debug mode
$DEBUG = 0;
#################



###########################################
# IMAGES
# ------
####### parameter TO BE DEFINED ##########
# COMMENT this line to look for the DPI (resolution) in the manisfeste
$DPIdefaut=400;	#  placer en commentaire pour analyser la résolution dans le manifeste
####### parameter TO BE DEFINED ##########
# COMMENT this line to analyse the color mode in the manifest
$couleurDefaut = "gris"; # placer en commentaire pour analyser le mode de couleur dans le manifeste, sinon :  "gris" / "mono" (sepia, etc.)  / "coul"

# Image resolution
$facteurDPI=25.4; # for DPI conversion to mm
# A8 surface (mm2). The illustrations size is expressed as a multiple of A8 size
$A8 = 3848; # surface d'un A8 en mm2 (= format d'une carte de jeu). La taille des ill. est exprimée en multiple de A8


# DOCUMENTS
# ---------
####### parameter TO BE DEFINED ##########
$unknown = "inconnu";  # to be localized
####### parameter TO BE DEFINED ##########
# UNCOMMENT this line to set a default IPTC theme
# $themeDefaut = "16"; #  IPTC theme
####### parameter TO BE DEFINED ##########
# The collection type
$typeDoc="P"; # documents type :  P (newspapers) /  R (magazine) / M (monograph) / I (image)
####### parameter TO BE DEFINED ##########
# UNCOMMENT this line to se a default image type (picture, drawing, map...)
#$genreDefaut="gravure"; # photo, gravure, dessin...
####### parameter TO BE DEFINED ##########
# max length of OCR texts to be extrated (in characters)
$maxTxt=2500; # longueur max des textes OCR extraits (en caracteres)

# FILTERING
# ---------
#$seuilLargeur=300; # tailles minimales d'une illustration en pixels
#$seuilHauteur=200;
####### parameter TO BE DEFINED ##########
# minimum ratio size of the illustration (% of the page surface, 0.01=1%))
$seuilTaille = 0.01; # ratio de taille minimum de l'illustration en % de la page (0,01=1%)
####### parameter TO BE DEFINED ##########
# for newspapers, upper margin of the front page to be excluded
$ratioOurs = 5; # pour filtrer les illustrations de la zone supérieure (1/5 a 1/8) de la page de une
####### parameter TO BE DEFINED ##########
# maximum width/height ratio to filter ribon-like illustrations
$ratioBandeau = 8; # ratio L/H, pour filtrer les illustrations étroites (bandeau, cul-de-lampe)
######################################

#######################################
### variables globales / global var ###
# hash table for the metadata
%hash = (); # table de hashage metadonnees/valeurs
# liste des pages ALTO analysées
$hash{"lpages"}=" "; # ALTO pages analysed
# reversed hash
%rhash = (); # hash inversé

## including the library to output XML or JSON ##
require "../bib-XML.pl"; ## importation macros d'export XML ou JSON ##

## classification of illustrations genres from the OCR types
%genres = (  ## classification des genres des illustrations en fonction des typages présents dans l'OCR
	"carte map TAG_map"  => "carte", # map
	"formula TAG_formula" => "formule" , # math formula
	"manuscript TAG_manuscript" => "manuscrit", # manuscript
	"music musicScore TAG_musicScore" => "partition");  # music score


##########################################################
# PARAMETRES pour les motifs GREP / GREP patterns parameters

## motifs de recherche dans le manifeste METS           ##
## patterns to analysed the METS manifest               ##
## OCR Europeana Newspapers + OLR Europeana Newspapers ##
$paramMotifNbPagesALTO_OCREN = "FILEID=\"FID(.+)ALTO";
$paramMotifNbPagesALTO_OLREN = "area FILEID=\"ALTO" ;
$paramMotifTitre_OCREN = "\<mods:title\>(.+)\<\/mods:title\>" ;
$paramMotifTitre_OLREN = "\<title\>(.+)\<\/title\>" ;
$paramMotifDate_OCREN = "\>(.+)\<\/mods:dateIssued";
$paramMotifDate_OLREN = $paramMotifDate_OCREN;
$paramMotifCouleur_OLREN = "\>(.+)\<\/mix:bitsPerSampleValue";
#$paramMotifCouleur_OCREN = $paramMotifCouleur_OCREN;

## motifs de recherche dans la structure logique OLR METS ##
## patterns to analysed the METS OLR structMap            ##
$motifArticle = "TYPE=\"ARTICLE\"";
$motifIllustration = "TYPE=\"ILLUSTRATION\"";
#$motifTitreArticle = "TYPE=\"ARTICLE\"";
$motifSurtitreArticle = "TYPE=\"OVERLINE\"";
#$motifBody = "TYPE=\"BODY\"";
$motifLabel = "LABEL\=(.+)\>";
$motifArea = "BETYPE\=";
#$motifDMDID = "DMDID\=\"(.+)\"";
$motifDMDID = "DMDID\=\"DMD\.(\\d+)\"";
$motifParagraphe = "BEGIN=\"P.+_TB.+\"";  # P1_TB00003
$motifIDblock = "BEGIN\=\"(.+)\"/>";

## spécifiques à OLR Europeana Newspapers  ##
## specific to OLR Europeana Newspapers    ##
$motifNumAlto_OLREN = "FILEID\=\"ALTO(.+)\" BEGIN"; # FILEID="ALTO00008"

## motifs de recherche dans le manifeste RefNum BnF ##
## patterns to analysed the BnF refNum manifest     ##
$paramMotifNbPagesALTO_OCRBNF = "\<nombrePages\>(\\d+)\<\/nombrePages";
$paramMotifNbVuesALTO_OCRBNF = "\<nombreVueObjets\>(\\d+)\<\/nombreVueObjets";
$paramMotifTitre_OCRBNF = "\<titre\>(.+)\<\/titre\>" ;
$paramMotifDate_OCRBNF = "\>(.+)\<\/dateEdition\>";
# $paramMotifNotice_OCRBNF = "12148\/(.*?)\<\/reference\>"; # non greedy
# <reference type="NOTICEBIBLIOGRAPHIQUE">ark:/12148/cb42568994f</reference>
$paramMotifNotice_OCRBNF = "BIBLIOGRAPHIQUE\"\>(.*?)\<\/reference\>";
$paramMotifCouleur_OCRBNF = "profondeur=\"(\\d+)\"";
$paramMotifDPI_OCRBNF = "resolution=\"(\\d+),";

## motifs de recherche dans le manifeste METS OLR BnF ##
## patterns to analysed the BnF OLR METS manifest     ##
#$paramMotifNbPagesALTO_OLRBNF = "paginationA\"\>(\\d+)\<\/dc:title\>"; # par_dc:paginationA">2</dc:title>
$paramMotifNbPagesALTO_OLRBNF = "FILEID=\"ocr";
#$paramMotifTitre_OLRBNF = "\<titre\>(.+)\<\/titre\>" ;
$paramMotifDate_OLRBNF = "date\>(.+)\<\/dc:date\>";
$paramMotifNotice_OLRBNF = "12148\/(.*?)\<\/dc:relation"; # non greedy
$paramMotifCouleur_OLRBNF = "bitsPerSampleValue\>(.*?)\<\/mix:bitsPerSampleValue";
$paramMotifDPI_OLRBNF = "numerator\>(\\d+)<\/mix:numerator";

## motifs de recherche dans la structure logique METS OLR BnF ##
## patterns to analysed the BnF METS OLR structMap       ##
#$motifParagraphe_OLRBNF = "BEGIN=\"PAG_._TB.+\"";  # PAG_1_TB000017
$motifNumAlto_OLRBNF = "FILEID\=\"ocr\.(.+)\" BEGIN"; # FILEID="ocr.1"
#$motifIDill_OLRBNF = "BEGIN=\"PAG_._IL.+\"";  # PAG_1_IL000017
$motifSurtitreArticle = "TYPE=\"TOPHEADING\"";


## motifs de recherche OCR ALTO communs 		 ##
## commun patterns to analysed ALTO OCR      ##
$motifTxtALTO = "<TextBlock";
$motifIllustrationALTO = "\<Illustration";
$motifTableALTO = "TYPE=\"table";
$motifPubALTO = "TYPE=\"advertisement";
$motifIDALTO = "ID=\"(\\w+)\"";
$motifALTOlarg = "WIDTH=\"(\\d+)\"";
$motifALTOhaut = "HEIGHT=\"(\\d+)\"";
$motifALTOx = "HPOS=\"-?(\\d+)\""; # il peut y avoir des coordonnees negatives...
$motifALTOy = "VPOS=\"-?(\\d+)\"";
$motifALTORotation = "ROTATION=\"-?(\\d+)\""; # rotation aussi
#$motifALTORotation = "ROTATION=\"-?(\\d+).+\""; # rotation aussi
$motifTypeIllALTO = "TYPE=\"(\\w+)\"";
#$motifIDTxtBlock = "TB"; # "PAG_00000017_TB000011"
$motifIDIllBlock = "IL"; # "PAG_00000017_IL000011"

########## motifs spécifiques ALTO ############
########## specific ALTO patterns  ############
# Europeana Newspapers
$paramMotifIDBlockOCREN = "Page1_Block";  # Example: "Page1_Block38"
$paramMotifPubALTO_OCREN = "TYPE=\"Advertisement";
$paramMotifPubALTO_OLREN = $paramMotifPubALTO_OCREN ;
$paramMotifTableALTO_OCREN = "TYPE=\"Table";
$paramMotifTableALTO_OLREN = $paramMotifTableALTO_OCREN;
$paramMotifIllustrationALTO_OLREN = "TYPE=\"Illustration";
# BnF
$paramMotifPubALTO_OLRBNF = "TAGREFS=\"TAG_advertisement"; # TAGREFS="TAG_advertisement"
$paramMotifTypeIllALTO_OLRBNF = "TAGREFS=\"(\\w+)\"";  # ALTO v2 : avec tags
$paramMotifIllustrationALTO_OLRBNF = "\<Illustration|\<GraphicalElement";
$paramMotifIDTxtBlockOCRBNF = "TB"; # "PAG_00000017_TB000011"

############### Autres parametres ######################
############### Other parameters  ######################
# nom des dossiers intra document numérique
# folder names within the digital document package
$paramRepALTO_OCREN="alto";
$paramRepALTO_OLREN="ALTO";
$paramRepALTO_OCRBNF="X";
$paramRepALTO_OLRBNF="ocr";
$paramRepTOC_OLRBNF="moc";
$repTOC="";

# nommage des manifestes METS et refNum
# name of the manifests
$paramSuffixe_OCREN="_mets.xml";
$paramSuffixe_OLREN="-METS.xml";
$paramSuffixe_OCRBNF=".xml";
$paramPrefixe_OCRBNF="X";
$paramPrefixe_OLRBNF="manifest";

# nommage des fichiers ALTO : extraction du numéro de page
# name of the ALTO files: extracting the page number
$numFicALTOdebut = -8; # index of the first digit (from the end)
$numFicALTOlong = 4; # number of digits

# detection des supplements sur la longueur des noms de fichier Europeana
# detecting newspapers supplements for Europeana
$paramSupplements_OCREN=18;
$paramSupplements_OLREN=10;
##################################


##################################
# API Gallica Issues
$urlAPI = "https://gallica.bnf.fr/services/Issues?ark=";
# motifs de recherche API
# patterns to analyse the API results
$motifArk = "ark\=\"(.+)\" ";
$motifJour = "dayOfYear\=\"(.+)\"";


###### Notices / Records ######
# ID ark des notices des titres de presse
# ark IDs of the bibliographic record for newspapers titres
%hashNotices = ();
$hashNotices{"Nantes"} = "cb41193663x";
$hashNotices{"Rennes"}= "cb32830550k";
$hashNotices{"Caen"}= "cb41193642z";
$hashNotices{"Matin"}= "cb328123058";
$hashNotices{"Gaulois"}="cb32779904b";
$hashNotices{"JDPL"}= "cb39294634r";
$hashNotices{"PJI"}= "cb32836564q";
$hashNotices{"Parisien"}="cb34419111x";
$hashNotices{"Humanite"}="cb327877302";
$hashNotices{"Echo"}="cb34429768r";
$hashNotices{"Figaro"}="cb34355551z";
$hashNotices{"Constitutionnel"}="cb32747578p";
$hashNotices{"Intransigeant"}="cb32793876w";
$hashNotices{"Univers"}="cb34520232c";
$hashNotices{"Presse"}="cb34448033b";
$hashNotices{"Croix"}="cb343631418";
#$hashNotices{"generic"}="00000000";
######################

# Divers / Misc.
# ID of the bibliographic record
my $noticeEN; # id de notice
# color mode of the pages (extracted from the manifest)
my @couleurs; # modes de couleur des pages numérisées, extrait du manifeste

# Hash for publication date/ark ID
@dateARKs = ();  # Hash des dates/arks
#$dateARKs{"20.10.1895"} = "ark:/12148/bpt6k716144h";
##################


#### ligne de commande ####
#### parsing the command line ####
# documents mode: ocren, olren, ocrbnf...
$MODE=""; # mode : ocren, olren, ocrbnf...

# output formats
@FORMATS = (); # formats de sortie
@FORMATS_OK = ("xml", "json", "csv", "txt");

# options
# extraction of illustrations metadata
$extractILL=0; # extraire les MD sur les illustrations
# computing the ark IDs
$calculARK=0;  # calculer les identifiants ark

#######################################
### variables globales / global var ###
# error code
my $codeErreur = 0;
# document ID currently analysed
my $id; # id du document en cours
# total number of documents
$nbDoc=0; # nbre de documents traites
# total number of illustrations
$nbTotIll=0; # nbre d'illustrations trouvees
# total number of illustrations which have been filtered
$nbTotIllFiltrees=0; # nbre d'illustrations filtrées
# OLR: total number of illustrations which have been filtered
$nbTotIllFiltreesOLR=0; # nbre d'illustrations filtree OLR
# missing METSs
$noMETS=""; # METS absents
# missing ALTOs
$noALTO=""; # ALTO absents
# unknown arks
$noArk=""; # Arks inconnus
# Arks with problem
$bugsArk=""; # Arks avec probleme
# ALTO page currently analysed
$numPageALTO=1; # page ALTO en cours
# nombre d'illustrations dans la page
#$numIll=0;
# nombre d'illustrations decrites (on filtre les plus petites)
#$numIllDecrites=0;
# ID of the ALTO block currently analysed
$idBlocAlto =""; # ID du bloc ALTO en cours
# IDs of the ALTO text blocks which are related to the illustrations
# this structure is a table (page level) of table (illustration level)
@listeIDsTxt = (); # ID des blocs ALTO de texte a associer aux illustrations : # tableau (page) de tableaux (illustration)
# same for the captions
@listeIDsLeg = ();
# ID des DMDID des articles
@listeDMDIDs = (); # list of IDs of the DMDID articles


### Parsing XML (XML::Twig) ####
# à laisser avant le code d'appel si ne marche pas #
$handlerALTO = {
	'/alto/Layout/Page/PrintSpace' => \&getALTO,
	#'TextBlock'  => \&getALTO,
};


# parsing XML du ALTO pour extraire les textes requis : $elt contient le <PrintSpace>
# les ID des blocs sont dans $listeIDsTxt et $listeIDsLeg
# XML ALTO parsing to extract the texts we are looking for: $elt contains the <PrintSpace>
# the blocks IDs are stored in $listeIDsTxt and $listeIDsLeg
sub getALTO {my ($t, $elt) = @_;

	  my $tmp;
	  my $idTmp;
	  my $scal;

	  #say Dumper \@listeIDsTxt ;

	  if ($DEBUG) {say "getALTO / elt: ".$elt->name();}
	  # $numPageALTO : var globale, page en cours
		# $numPageALTO : globale var, #page under processing
	  if (defined ($listeIDsTxt[$numPageALTO])) {
	  # liste des blocs à chercher pour cette page
		# list of blocks to be looked for
	  $aref = $listeIDsTxt[$numPageALTO]; #listeIDsTxt est un tableau (niveau numéro_de_page) de tableaux (niv. ID_de_blocs)
	  # pour chaque ID de bloc
	  for ($i=0; $i<=@$aref-1; $i++)  {
	  	 $idTmp = $listeIDsTxt[$numPageALTO][$i];
	  	 if (defined($idTmp)) {
	  	   if ($DEBUG) {say "txt ID to look for: ".$idTmp;}
	  	   # récupérer le contenu texte du bloc
	  	   $scal = getALTOtxt($elt,$idTmp); # get the text content
	       # si OCR : prendre le bloc n-1 en plus pour obtenir plus de texte
	       if (index($MODE,"ocr") !=-1) { # if OCR mode, get the n-1 block to have more text
	       	 $idTmp = incIdBlocALTO($idTmp, -1,$motifIDTxtBlock) ;
	         $scal = $scal." ".getALTOtxt($elt,$idTmp);
	       }
	       # concatener les 2 blocs et raccourcir les textes
	       $hash{$numPageALTO."_ill_".$i."txt"} = subTxt($scal); # shorten the text
	  	  }
	  	 } # fin for
	  	}
	  # idem pour chercher les eventuelles legendes
    if (index($MODE,"ocr") !=-1)  { # same for caption
	   $aref = $listeIDsLeg[$numPageALTO];
	   for ($i=0; $i<=@$aref-1; $i++) {
	  	 $idTmp = $listeIDsLeg[$numPageALTO][$i];
	  	 if (defined($idTmp)) {
	  	   if ($DEBUG) {say "caption ID to look for: ".$idTmp;}
	  	   $scal = getALTOtxt($elt,$idTmp);

	  	   # on essaye aussi de prendre le bloc de txt suivant si la légende est courte
	  	   if (length($scal) < 10) { # we try to get the n+1 text block
	  	     $idTmp = incIdBlocALTO($idTmp, 1, $motifIDTxtBlock);
	  	     $scal = $scal." ".getALTOtxt($elt,$idTmp);}
	  	   $hash{$numPageALTO."_ill_".$i."leg"} = subTxt($scal);
	  	   }
	  } # for
	 }
}


####################################
####################################
############# MAIN ################
####################################
####################################

$MODE=shift @ARGV;

if ((not (defined($MODE)) or (substr ($MODE,0,1) eq "-") && (scalar(@ARGV)<5)) or (scalar(@ARGV)<4))  {
	die "\nUsage : perl extractMD.pl [-options]  ocren|ocrbnf|olren|olrbnf titre IN OUT csv|json|xml
[L]: include the illustrations description
[I]: compute ARK IDs (BnF only)
ocren, olren, ocrbnf, olrbnf:  documents origin
title: document title if needed for olrbnf mode and to compute BnF ark IDs
(otherwise, use 'generic')
IN: input folder of the digital documents
OUT:  output folder for the metadata
csv,json,xml : export format for the metadata
	";
}

if (not defined $typeDoc) {
	say " \n## unknown documents type! Must be set in typeDoc var";
	die
}
else {
	say " \n... WARNING: Running the script for '$typeDoc' documents \n  P (newspaper) /  R (magazine) / M (monograph) / I (image)";
}

# gestion des options
# mode d'extraction : (OCR ou OLR) et calcul des arks
if($MODE eq "-L"){ # option to extract illustrations
 $extractILL= 1;
 $MODE=shift @ARGV;
} elsif ($MODE eq "-I"){ # option to compute ark IDs
 $calculARK=1;
 $MODE=shift @ARGV;}
elsif (($MODE eq "-LI") or ($MODE eq "-IL")){
 $extractILL = 1;
 $calculARK=1;
 $MODE=shift @ARGV;}

# option: mode
if ($MODE eq "ocren"){
	$ratioBandeau = 7; # on est plus severe pour filtrer plus / more filtering for newspapers
	$repALTO=$paramRepALTO_OCREN;
	$suffixeManif =$paramSuffixe_OCREN;
	$prefixeManif ="";
	$supplements = $paramSupplements_OCREN;
	$motifNbPagesALTO = $paramMotifNbPagesALTO_OCREN;
	$motifTitre=$paramMotifTitre_OCREN;
	$motifDate = $paramMotifDate_OCREN;
	#$motifCouleur = $paramMotifCouleur_OCREN;
	# structure logique
	$motifPubALTO =$paramMotifPubALTO_OCREN;
	$motifTableALTO =$paramMotifTableALTO_OCREN;
	#$motifIllustrationALTO =$paramMotifIllustrationALTO_OCREN;
	$motifIDTxtBlock = $paramMotifIDBlockOCREN;
  #$motifIDIllBlock = $motifIDBlockOCREN;

} elsif ($MODE eq "olren") {
	$repALTO=$paramRepALTO_OLREN;
	$suffixeManif =$paramSuffixe_OLREN;
	$prefixeManif ="";
	$supplements = $paramSupplements_OLREN;
	$motifNbPagesALTO = $paramMotifNbPagesALTO_OLREN;
	$motifTitre=$paramMotifTitre_OLREN;
	$motifDate = $paramMotifDate_OLREN;
	$motifCouleur = $paramMotifCouleur_OLREN;
	# structure logique
	$motifNumAlto =$motifNumAlto_OLREN;
	$motifPubALTO =$paramMotifPubALTO_OLREN;
	$motifTableALTO =$paramMotifTableALTO_OLREN;
	$motifIllustrationALTO =$paramMotifIllustrationALTO_OLREN;
	$motifIDTxtBlock = $paramMotifIDBlockOLREN;

	#$motifIDill = $motifIDBlockOCREN;

} elsif ($MODE eq "ocrbnf") {
	$repALTO=$paramRepALTO_OCRBNF;
  $suffixeManif =$paramSuffixe_OCRBNF;
  $prefixeManif =$paramPrefixe_OCRBNF;
  $motifTitre=$paramMotifTitre_OCRBNF;
  $motifDate = $paramMotifDate_OCRBNF;
  $motifCouleur = $paramMotifCouleur_OCRBNF;
  $motifDPI = $paramMotifDPI_OCRBNF;
  $motifNbPagesALTO = $paramMotifNbPagesALTO_OCRBNF;
  $motifNbVuesALTO = $paramMotifNbVuesALTO_OCRBNF;
  $motifNotice = $paramMotifNotice_OCRBNF;
  # structure logique
  #$motifPubALTO =$paramMotifPubALTO_OCRBNF;
  #$motifTable =$paramMotifTable_OCR;
  #$motifIllustrationALTO =$paramMotifIllustrationALTO_OCR;
  $motifIDTxtBlock = $paramMotifIDTxtBlockOCRBNF;
  #$motifIDIllBlock = $motifIDIllBlockOCRBNF;

} elsif ($MODE eq "olrbnf") {
	$repALTO=$paramRepALTO_OLRBNF;
	$repTOC=$paramRepTOC_OLRBNF;
  $suffixeManif =$paramSuffixe_OCRBNF;
  $prefixeManif =$paramPrefixe_OLRBNF;
  #$motifTitre=$paramMotifTitre_OLRBNF;
  $motifDate = $paramMotifDate_OLRBNF;
  $motifCouleur = $paramMotifCouleur_OLRBNF;
  $motifDPI = $paramMotifDPI_OLRBNF;
  $motifNbPagesALTO = $paramMotifNbPagesALTO_OLRBNF;
  $motifNotice = $paramMotifNotice_OLRBNF;
  # structure logique
  #$motifParagraphe = $motifParagraphe_OLRBNF;
  $motifNumAlto = $motifNumAlto_OLRBNF ;
  #$motifTable =$paramMotifTable_OCR;
  #$motifIllustrationALTO =$paramMotifIllustrationALTO_OCR;
  $motifIDTxtBlock = $paramMotifIDTxtBlockOCRBNF;
  #$motifIDIllBlock = $motifIDIllBlockOCRBNF;
  # OCR
  $motifPubALTO=$paramMotifPubALTO_OLRBNF;
  $motifTypeIllALTO=$paramMotifTypeIllALTO_OLRBNF;
  $motifIllustrationALTO=$paramMotifIllustrationALTO_OLRBNF;
  }
else {
  die "##  $MODE:  unknown mode!\n";}

# titre du document (pour le calcul des arks)
# document title (for ark computing)
$titreDefaut=shift @ARGV;
if ($calculARK==1) {
	#################################################
	## for BnF monographies : ark IDs importation  / set a %arksMono hash ##
	if ($typeDoc eq "M")
	   {require "arks-mono.pl"}	## pour les BnF monographies, il faut fournir une liste d'ark ID --> %arksMono ##

  # for Europeana corpus, we need to find the ID in the hash
  if (index($MODE, "en") != -1) {  # il faut trouver l'ID de notice dans le hash : cas des corpus EN
		 say "  title: ".$titreDefaut."\n";
		 if ($hashNotices{$titreDefaut}) {
		   $noticeEN = $hashNotices{$titreDefaut};}
	   else
	    {
				say "##  Unknown bibliographic record's ID for title \"$titreDefaut\"!";
				say "##  You must choose the title as:";
				foreach my $key ( keys %hashNotices ) {
				 print $key." - ";}
				 say "\n";
				die
		}
	  } # otherwise, the ID will be extrated from the manifest
		# sinon ne rien faire, la notice sera extraite du manifeste BnF
}

#$noticeEN = $hashNotices{$titre};

$DOCS=shift @ARGV;
# repertoire de stockage des documents a traiter / input folder
if(-d $DOCS){
		say "\nReading $DOCS...";
	}
	else{
		die "##  $DOCS doesn't exist!\n";
	}

# dossier de stockage des metadonnees extraites / output folder
$OUT=shift @ARGV;
if(-d $OUT){
		say "Writing in $OUT...";
	}
	else{
		mkdir ($OUT) || die ("##  Error while creating folder: $OUT\n");
    say "Creating $OUT...";
	}

# extraction des formats de sortie
while(@ARGV){
	$f =	shift @ARGV;
	if($f ~~ @FORMATS_OK) {
	   push @FORMATS, $f;
  } else {die "##  Format \"$f\" unknown!\n";
  }
}

# analyse récursive du dossier
# recurse analysis of the input folder
my $dir = dir($DOCS);
say "--- documents: ".$dir->children(no_hidden => 1)."\n";


$dir->recurse(depthfirst => 1, preorder => 1, callback => sub {
	my $obj = shift;
	my $codeErreur = 0;

	# avoid the toplevel folder
	if (index ($DOCS,$obj->basename) == -1)  { # sauter le dossier courant
	if (($obj->is_dir) ){
		say "\n...folder: ".$obj->basename;
		# we are on a document folder
		if (($obj->basename ne $repALTO) and ($obj->basename ne $repTOC)) { # on est sur un dossier de document
		   $id = $obj->basename;
		   print "\n*************************************\n".$id."... ";
		   $codeErreur = genererMD($obj,$id); # analyser le manifeste / analysing the manifest
		   if ($codeErreur == -1) {
		    say "\n##  The manifest is missing!\n";}
		   else {$nbDoc++;}

		 }
		 # cas de l'OLR BnF avec une table logique METS distincte
		 # we have a METS OLR structure in a distinct file: BnF case
		 elsif ($obj->basename eq $repTOC) {
  			#say "\n".$obj->basename;
		   	say "\n------------------------  OLR structure detected: ".$id."... ";
		   	#say "  filtered illustrations: ".$nbTotIllFiltrees;
		   	#say "M".$id.$suffixeManif;
		   	my $toc = $obj->file("M".$id.$suffixeManif);
		   	if (-e $toc) {
		      #return lireMD($manifeste,$idDoc);
		      open my $fh, '<:encoding(UTF-8)', $toc or die "Can't open: $toc !";
		      extraireIllOLR($fh);
		      #$codeOLR=1;
		      #ecrireMD($id);
	      }
	      else{
		       say "## $toc is missing!";
		       $noMETS=$noMETS.$id." ";}
		    }
		 elsif ($obj->basename eq $repALTO)
		  { # we are on an ALTOs folder
		 	if  (($codeErreur != -1)) { # analyser les ALTO
		 	  my $nbrePages = genererMDALTO($obj,$obj->parent->basename);
		 	  #$hash{"pages"} = $numPageALTO-1;
		      if ($nbrePages == 1) {
		  	    say "\n## ALTO are missing!";
		  	    $noALTO = $noALTO.$id." ";
		      }
		      if (($nbrePages) != $hash{"pages"}) { # pages lues / pages annoncées dans le manifeste
		  	    say "\n## ALTO unconsistent! expected: ".$hash{"pages"}." / found: ".$nbrePages ;
		  	    $hash{"pages"} = $nbrePages; # corriger le nbre de pages réelles
		  	    $noALTO = $noALTO.$id." ";
		      }
		     }
		     # exporter les metadonnees selon les formats choisis
				 # export the metadata
		     #if ($MODE ne "olrbnf") { # on n'a pas besoin de la toc, on peut finir
		     	 if ($codeErreur != -1) { #and ($codeOLR==1)) {
  		         ecrireMD($id);
  		     }
  		     else {$nbDoc--;
  		     	say "????????? Fatal ERROR ???????";
  		     	die}
  		   #}
  		} # fin analyser ALTO

  		} # fin if obj is_dir
	}
 return PRUNE;
});

#say Dumper @listeDMDIDs;

say "\n\n=============================";
say "$nbDoc documents analysed on ".$dir->children(no_hidden => 1);
say "$nbTotIll illustrations";
say "$nbTotIllFiltrees ill. filtered on the form factor / $nbTotIllFiltreesOLR filtered thanks to the OLR";
if ($MODE eq "olrbnf") {
say "  remaining: ".($nbTotIll - $nbTotIllFiltreesOLR - $nbTotIllFiltrees)}
else {say "  remaining: ".($nbTotIll - $nbTotIllFiltrees)}
say "missing METS: ".$noMETS;
say "missing ALTO: ".$noALTO;
say "Ark IDs unknown: ".$noArk;
say "Fatal errors: ".$bugsArk;
say "=============================";

$t1 = Benchmark->new;
$td = timediff($t1, $t0);
say "the code took:",timestr($td);

########### FIN ##################
##################################


# ----------------------
# traitement des MD d'un document via son METS ou son refNum
# processing the bibliographic metadata from a METS or refNum manifest
sub genererMD {
	my $rep=shift;
	my $idDoc=shift;
  #my $handler=shift;

	if ($MODE eq "olrbnf") { # pour traiter le cas des nouveaux manifestes METS BnF de la forme manifest.xml
	  	  $manifeste = $rep->file($prefixeManif.$suffixeManif)}
	else {
				$manifeste = $rep->file($prefixeManif.$idDoc.$suffixeManif)}

	if(-e $manifeste){
		   return lireMD($manifeste,$idDoc);
	     }
	else{
		   say "## $manifeste doesn't exist!";
		   $noMETS=$noMETS.$idDoc." ";
		   return -1;
	   }
}


# ----------------------
# analyser un manifeste
# manifest analysis
sub lireMD {
	my $ficMETS=shift;
	my $idDoc=shift; # ID document
	#my $handler=shift;

	my $titre = $unknown;
	my $date = $unknown;
  my $nbPages;
  my $junk;
  my $notice ;
  my @pages ;

    # RAZ des structures de donnees
	%hash = ();
	undef %rhash;
	undef @listeIDsTxt;
	undef @listeIDsLeg;

  $hash{"type"}=$typeDoc;

	print "...loading the manifest: $ficMETS\n--------------------------\n";

  # extraire par regexp (plus rapide que XML
  open my $fh, '<:encoding(UTF-8)', $ficMETS or die "Can't open: $ficMETS!"; # manifeste refNum ou METS en utf8

  if ($MODE eq "ocrbnf") { # OCR BnF case: some metadata are in the refNum manifest
    ( $junk, $titre , $junk, $date, $junk, $nbPages, $junk, $notice ) = do { local $/; <$fh> =~ m/($motifTitre).*($motifDate).*($motifNbPagesALTO).*($motifNotice)/s }; # $/ : lire tout le fichier
    # if #pages is not available, try to use the number of images
    if (not $nbPages) {
    	seek $fh, 0, 0;
    	( $junk, $titre , $junk, $date, $junk, $notice,$junk,$nbPages,) = do { local $/; <$fh> =~ m/($motifTitre).*($motifDate).*($motifNotice).*($motifNbVuesALTO)/s };
    	}
  }
  elsif ($MODE eq "olrbnf") { # OLR BnF case
    ( $junk,  $date, $junk, $notice, $junk) = do { local $/; <$fh> =~ m/($motifDate).*($motifNotice)/s };
    # date and record's ID are in the  manifest
    seek $fh, 0, 0;
		# looking for #pages
    ( @pages ) = do { local $/; <$fh> =~ m/$motifNbPagesALTO/g};
    if (@pages)
         { $nbPages = scalar (@pages);}
   	else {say "## unknown pages number (pattern: $motifNbPagesALTO ) ##"; }
		# the title is not in the manifest...

    $titre = $titreDefaut;
  }
  else { #  Europeana case
  	( $junk, $titre , $junk, $date ) = do { local $/; <$fh> =~ m/($motifTitre).*($motifDate)/s }; # $/
  	$notice = $noticeEN; # record's ID is not in the METS manifest
  	# looking for #pages
	  seek $fh, 0, 0;
  	( @pages ) = do { local $/; <$fh> =~ m/$motifNbPagesALTO/g};   # /g : dans tout le fichier
  	if (@pages)
         { $nbPages = scalar (@pages);}
   	else {say "## unknown pages number (pattern: $motifNbPagesALTO ) ##"; }
  }

  $titre ||= $unknown;
  $hash{"titre"} = $titre;

  $notice ||= $unknown;
  $hash{"notice"} = $notice;

  $nbPages ||= "0";
  $hash{"pages"} = $nbPages ;

  if (defined ($date))
    {   #$dateISO = Date::Simple->new($date);
    	# <dateEdition>1944/09/27</dateEdition>
			say " date: $date";
			my $tmp = $date;
    	$tmp =~ tr/\//-/; # transformer le / du refNum en -
			#say $tmp;
    	if (($tmp =~ m/^(\d{4})-(\d\d)-(\d\d)$/) or # yyyymmdd
    	 	($tmp =~ m/^(\d{4})-(\d\d)$/) or						# yyyymm
    	  ($tmp =~ m/^(\d{4})$/) ) {								# yyyy
    		say ".. ISO date OK: ".$tmp;
    		$date=$tmp;
       }
			 elsif ($tmp =~ m/^(\d\d)-(\d\d)-(\d{4})$/) { # ddmmyyyy
				 $date = join "-", reverse split /\-/, $tmp; # reformatter en date ISO
				 say ".. ISO date OK: ".$date;
			 }
			 else {
       	   say "  ## non-ISO date: ".$tmp;}
     }
  else {say "  ## date is missing! (pattern:$motifDate)";
        $date = $unknown}

  $hash{"date"} ||= $date;

  if (index($MODE, "en") !=-1) { # cas Europeana
    if (length($idDoc)>$supplements) { # les supplements ont une extension _02_1
		  $hash{"supplement"}="TRUE";}
		else {$hash{"supplement"}="FALSE";}}
	else {	$hash{"supplement"}="FALSE";}

	say " title: ".$titre;
  say " date: ".$date;
  say " pages: ".$nbPages;
  say " bibliographic record: ".$notice;

  # looking for illustrations
  if ($extractILL==1) { # on cherche des illustrations (si demandé)
	 # looking for the color mode
   if ((not defined ($couleurDefaut)) and (defined ($motifCouleur))) { # trouver la profondeur de couleur de la numérisation
   	seek $fh, 0, 0;  # on revient au debut du fichier
   	#say $motifCouleur;
   	(@couleurs) = do { local $/; <$fh> =~ m/$motifCouleur/g};
   	#say Dumper (@couleurs);
		if (not @couleurs) {
			say " ## color mode can't be found! (pattern: $motifCouleur)";
			die}
		else {
			say " color mode (page 1): ".$couleurs[0];}
		} elsif (not (defined ($couleurDefaut)) and not defined($motifCouleur)) {
 		 say " \n## unknown default color mode! (must be set in couleurDefaut var)";
 		 say "## and no pattern for searching in the manifest (motifCouleur var)";
 		 die
	 }
	 else {say " default color mode: $couleurDefaut"}


   # looking for the DPI
   if (not (defined ($DPIdefaut)) and defined($motifDPI)) { #trouver la résolution
   	# trouver la profondeur de couleur de la numérisation dans le manifeste
   	seek $fh, 0, 0;  # on revient au debut du fichier
   	(my $DPI) = do { local $/; <$fh> =~ m/$motifDPI/s};
   	if (defined ($DPI)) {
   	  if ($MODE eq "olrbnf") {
				$DPIdefaut = $DPI/10000; }
   	  else {$DPIdefaut = $DPI}
    } else {
			say " ## DPI can't be found! (pattern: $motifDPI)";
			die}
   } elsif (not (defined ($DPIdefaut)) and not defined($motifDPI)) {
		 say " \n## unknown default DPI! (must be set in DPIdefaut var)";
		 say "## and no pattern for searching in the manifest (motifDPI var)";
		 die
	 }

   say " DPI: ".$DPIdefaut;

   # cas OLR : on cherche illustrations+legendes dans le manifeste
   if ($MODE eq "olren") { # la structure logique est dans le manifeste
   	  extraireIllOLR($fh); }
   #elsif ($MODE eq "olrbnf")  # la structure logique est dans un fichier toc distinct
   }
  say "\n-------------------------- manifest end";
	return 1;
}


# Looking for illustrations in OLR manifests
sub extraireIllOLR{my $fh=shift;

	my @articles ;
	my $legendes = 0;
	my $caption="";
	my $titreArticle="";
	my $idTitre;
	my $IDalto="";
	my $IDill="";
	my $DMDIDarticle;
  my $numPageEnCours = 1; # numero de page en cours dans le parcours du manifeste OLR
  my $illEnCours;
  my $overline;
  my $numIll=0; # pour chq page
  my $numIllDoc=0; # pour le doc

  #say "...extraireIll";

   # compter  les articles / counting the articles
   seek $fh, 0, 0;
   ( @articles ) = do { local $/; <$fh> =~ m/$motifArticle/g};
   $hash{"articles"} = scalar (@articles);
   if ($DEBUG) {say " number of articles: ".scalar (@articles);}
   say "---------";

   seek $fh, 0, 0;
   while (my $line = <$fh>) {
     # on detecte s'il y a un surtitre a un article
     if ($line =~ /$motifSurtitreArticle/) { $overline = 1;}
     # on cherche le titre de l'article
		 # looking for article title
     if ($line =~ /$motifArticle/) {
      ( $titreArticle ) = $line =~ m/$motifLabel/;
      ( $DMDIDarticle ) = $line =~ m/$motifDMDID/;
			#say "DMD : $DMDIDarticle";
      if ($DEBUG) {
      	if (defined $titreArticle) {say "--> article title: ".$titreArticle;}
      	else {say "--> untitled article"}}
      # RAZ de l'ID du titre
      undef $idTitre ; }

    # on cherche l'ID du bloc ALTO du titre de l'article, qui se trouve un peu plus bas
		# looking for article title ID
    if (	(not defined ($idTitre)) && ( $line =~ /$motifParagraphe/))  {
   	  ( $idTitre ) = $line =~ m/$motifIDblock/;
   	  if (defined $overline) { # si on a un surtitre
   	  	if ($DEBUG) {say "  *** overline ***";}
   	  	$idTitre= incIdBlocALTO($idTitre,1,$motifIDTxtBlock);
				$overline=0;} # on veut le bloc d'apres, on incremente
   	  #if ($DEBUG) {say "num ID titre article : ".$numIDtitre;}
    }

   # on cherche une illustration et le texte de la legende
	 # looking for illustrations and captions
   if ($line =~ /$motifIllustration/) {
   	  #say "  ** illustration ! **";
   	  $numIllDoc++;
   	  ( $caption ) = $line =~ m/$motifLabel/; # on recupere des string "..." ou rien (ill. sans legende)
   	  if ($DEBUG) {if (defined $caption) {say " caption: $caption"; }}
   	  $illEnCours = 1;
      $numIll++; }

   # si on a trouve precedemment une illustration, on cherche le num de page correspondant et l'ID ALTO
	 # if we have an illusration, look for page number and ALTO ID
   if ((defined $illEnCours) && ($line =~ /$motifArea/)) { #chercher la ligne qui contient la ref vers la page ALTO contenant l'illustration
    	( $IDalto ) = $line =~ m/$motifNumAlto/;  # numero du fichier ALTO : entier
    	( $IDill ) = $line =~ m/$motifIDblock/; # ID de l'illustration : PAG_2_IL000002
     	$IDalto = int($IDalto) ;

    	#if ($IDalto > $numPageEnCours) { # on a change de page : RAZ  du numéro d' illustration
    	say "\n...found an illustration on #page $IDalto";
			$tmp = $hash{$IDalto."_blocsIllustration"};
    	if ($tmp) { # on a une illustration de plus sur la page $IDalto
				$hash{$IDalto."_blocsIllustration"} = $tmp+1; # one more illusration on page $IDalto
				$numIll = $tmp+1}
			else { # on a la premiere illusration de la page $IDalto
				$hash{$IDalto."_blocsIllustration"} = 1; # first illusration on page $IDalto
				$numIll = 1}

			#$numPageEnCours = $IDalto;
    	#$numIll = 1;
    	#say "\n New #page:  ".$numPageEnCours;}

    	#if ($DEBUG) {say " ** $numIll illustrations on page: $IDalto" }

    	# si OLR BnF, il y a parfois des GraphicalElement référencés par erreur
			# if OLR BNF use case, we need to filer GraphicalElement
    	if (($MODE eq "olrbnf") and (index ($IDill,"_GE") != -1))
    	 {$hash{$IDalto."_ill_".$numIll."filtre"} = 2;
    	 	$nbTotIllFiltreesOLR++;
    	 	say " ** OLR filter:  GraphicalElement **"}

    	# on stocke les DMDID pour plus tard
    	# storing the DMDID
    	if (defined($DMDIDarticle))  {
    		    $listeDMDIDs[$IDalto][$numIll] = $DMDIDarticle;}

    	if (defined $caption) {$hash{int($IDalto)."_ill_".$numIll."leg"} = $caption;}

			if ($DEBUG) {say "...writing in the hash -> #page: $IDalto / #ill: $numIll / ill. ID: $IDill";}
    	$hash{int($IDalto)."_ill_".$numIll."id"} = $IDill;

    	# le titre de l'article englobant l'illustration
      if ( (defined($titreArticle)) && (length($titreArticle) != 0)) {
          #say "  hash --> ID titre : ". $numIDtitre. " - ". substr $titreArticle,0,30 ;
          $hash{int($IDalto)."_ill_".$numIll."titre"} = $titreArticle;
          if (index ($titreArticle,"Publicit") !=-1) {
          	$hash{int($IDalto)."_ill_".$numIll."pub"} = "true";
          	say " ** Advertisement **"}
          }

      # on stocke pour plus tard le numero de l'ID du bloc texte ALTO suivant le titre
			# text blcok ID following the title
      # $listeIDtxt = tableau de tableaux
      if (defined ($idTitre)) {
      	     say " *** title ID: ".$idTitre;
           	 $txtApres = incIdBlocALTO($idTitre,1,$motifIDTxtBlock);
           	 $listeIDsTxt[$IDalto][$numIll] = $txtApres;

        }

    	if (defined $titreArticle) {
    	  	say " title: ".(substr $titreArticle,0,30);}
    	if (defined $caption) {
    	    say " caption: ".(substr $caption,0,30);}
      say " ill ID: $IDill  ";
    	if (defined $txtApres)
    	   {say " text ID: $txtApres";}
    	#say "**";

     	#$caption = "";	# RAZ des tampons jusqu'au prochain "match"
    	undef $overline;
    	undef $illEnCours;
    	undef $txtApres;
     }
    } # fin du while ligne

   $hash{$numPageEnCours."_blocsIllustration"} = $numIll;
    say " processing #page $numPageEnCours is done: ".($numIll-1)." found";
    say "\n----------- total number : ".$numIllDoc;

}


# -------------
# incrémenter (ou décrementer) un ID de bloc ALTO en fonction du mode et du type de bloc
# increment (or decrement) ALTO block ID
sub incIdBlocALTO {
	my $id=shift;
	my $increment=shift;
	my $motif=shift;

	my @tmp = split($motif,$id);
  my $res = $tmp[1];
  if (not  $res) {
  	say "## error in incIdBlocALTO: ID : $id / pattern: $motif ##";
    return undef}

  if ($increment == 0) {  # si le parametre = 0, on veut le bloc n° 1
        $res = 1}
  else {$res = $tmp[1] + $increment;}

  if ( index ($MODE,"bnf") != -1) { # on construit un ID de bloc texte
         return $tmp[0].$motifIDTxtBlock.sprintf '%06s',$res; # sur 6 digits
     }
  else { # cas EN
         return $tmp[0].$motifIDTxtBlock.sprintf '%05s',$res; # sur 5 digits
       }
   }


###############
# analyser les fichiers ALTO
# analysis of ALTO files
sub genererMDALTO {
	my $rep=shift;
	my $idDoc=shift;
  my $codeErreur;

  my $nbrePagesALTO = 0;

  #say "genererMDALTO";
  #say Dumper(@listeDMDIDs);
  #say Dumper(@listeIDsTxt);

  while (my $fichier = $rep->next) {
			if ((substr $fichier, -4) eq ".xml") {
		    #$numPageALTO = int(substr $fichier,-6,3); # SBB
				$numPageALTO = int(substr $fichier,$numFicALTOdebut,$numFicALTOlong);  #recup du num de page dans le nom de fichier : X0000002.xml
		    say "\n#page: ". int($numPageALTO);

		    $codeErreur=lireMDALTO($fichier,$idDoc); #,$handler
		    if ($codeErreur == -1) {say "\n##  a problem occured during ALTO analysis: $fichier\n";}
		    else {
					$nbrePagesALTO++;
					if ($hash{"lpages"}) {
						$hash{"lpages"} = $hash{"lpages"}.$numPageALTO.","}  # liste des num de pages ALTO
					else {$hash{"lpages"} = $numPageALTO.","}
			}
		  }
    }
   say "\n $nbrePagesALTO ALTO pages analysed";
   say "-------------------------- ALTO: END";
   return $nbrePagesALTO;
}


################
# analyse d'un fichier ALTO et ecriture du fichier des metadonnees
# analysis of an ALTO file, writing the metadata
sub lireMDALTO {
	my $fichier=shift;
	my $idDoc=shift; # ID document

  my $angleRotation = 0;
  my $mots = 0;
  my $textes = 0;
  my $pubs = 0;
  my $ills = 0;
  my $tabs = 0;
  my $ligneTxtAvant="";
  my $IDtxt;
  my $tmp;
  my $typeIll = "";
  my $largeurPage = 0; # dimensions de la page en px
  my $hauteurPage = 0;
  my $numIllEnCours=0;
  my $filtre;

  # RAZ des nombres d'illustrations
  $nbIll = 0;
  #$numIllDecrites = 0;

  print "--------------\nALTO analyse #page ".$numPageALTO.": $fichier \n";

  open my $fh, '<', $fichier or die "Can't open: $fichier !";

  #say Dumper (%hash);

  # gestion des illusration spécifiques : seules certaines sont decrites ds la toc METS
  if ($MODE eq "olrbnf")
    	   { # recuperer le nb d'illustrations deja detectees
    	   	$numIllEnCours = $hash{$numPageALTO."_blocsIllustration"};
    	   	$numIllEnCours ||=  0;
          if ($DEBUG) {say " #page $numPageALTO / number of ill. in the OLR: ".$numIllEnCours;}
          }

  # calcul de la taille du document
  #if ($numPageALTO == 1) {
  {local $/;
 	# dimensions de page
  	( $largeurPage ) = <$fh> =~ m/$motifALTOlarg/;
  	seek $fh, 0, 0;
    ( $hauteurPage ) = <$fh> =~ m/$motifALTOhaut/;

    if (not defined($largeurPage) or not defined($largeurPage)) {
      say " ## Issue: extracting page dimension ##";
      return -1;
    }
    #$largeurPage = $largeurPage;
    #$hauteurPage = $hauteurPage;
    $hash{"largeur"} = $largeurPage; # pixels
    $hash{"hauteur"} = $hauteurPage;
  }
  #if ($DEBUG) {say "L : ". $largeurPage." x H : ".$hauteurPage} ;

  seek $fh, 0, 0;
  while (my $ligne = <$fh>) {
   	# extraction des nombres d'elements
    $mots++  if $ligne =~ /<String/;
    if ($ligne =~ /$motifTxtALTO/) { # on est sur un bloc de texte
    	#say $ligne;
    	($tmp) = $ligne =~ m/$motifALTORotation/; # angle de rotation applique a un bloc de texte?

    	if (defined  ($tmp)) {
    		$angleRotation = int($tmp);
    		# on assume que si il y a rotation sur un bloc, toute les elements de la page le sont et donc les images aussi
    	  if ($DEBUG) {say "Rotation : $angleRotation";}
    	  $hash{$numPageALTO."rotation"} = $angleRotation;
    	}
    	$textes++;
      $ligneTxtAvant = $ligne;}

    # compter publicites et tableaux
    $pubs++ if $ligne =~ /$motifPubALTO/;
    $tabs++ if $ligne =~ /$motifTableALTO/;

    # illustrations
    #say $motifIllustrationALTO;
    if ($ligne =~ /$motifIllustrationALTO/) { # on a trouve une illustration
   	 $nbIll++;
     $nbTotIll++; # var globale
     #say $ligne."\n";
     if ($extractILL==1) { 	# on cherche des illustrations (si demande)
    	# extraire les dimensions
    	($idBlocAlto) = $ligne =~ m/$motifIDALTO/;
    	say "\nID ill : ".$idBlocAlto;

    	my ( $typeIll ) = $ligne =~ m/$motifTypeIllALTO/;
    	my ( $x ) = $ligne =~ m/$motifALTOx/;
    	my ( $y ) = $ligne =~ m/$motifALTOy/;
    	my ( $hauteur ) = $ligne =~ m/$motifALTOhaut/;  #  pixels
    	my ( $largeur ) = $ligne =~ m/$motifALTOlarg/;
    	#$largeur = int($largeur);
    	#$largeur = int($largeur);


    	$ratio =  ($largeur*$hauteur)/($largeurPage*$hauteurPage)  ; # ratio illustration/page en %
    	if ($DEBUG) {
    		print " L page : ". $largeurPage." x H page : ".$hauteurPage;
    		print " / x ill : ". $x." - y : ".$y;
    		print " / L ill : ". $largeur." x H : ".$hauteur ;
    		print " / ratio surface : ".$ratio;
    		print " / ratio hauteur : ".($hauteurPage/$ratioOurs)."\n";
    		if (defined $typeIll) {say "  type : ".$typeIll;}
    		}

    	#say $idBlocAlto." - ".$largeur."x".$hauteur;

    	# filtrer les petites illustrations si petite taille
    	#if (($MODE eq "olr") && ($ratio < $seuilTaille))  # ET pas de texte associe
    		#(not (exists($hash{$numPageALTO."_ill_".$numIll."leg"})))
    		#&& (not (exists($hash{$numPageALTO."_ill_".$numIll."titre"}))))

			# si OLR BnF
    	if ($MODE eq "olrbnf")
    	   {
    	   	$tmp = getNumIllHash($numPageALTO, $idBlocAlto); # chercher si deja décrite dans l'OLR
    	   	if ($tmp == -1) {
						 	$tmp = getNumIllHash(int($numPageALTO+1), $idBlocAlto);
							if ($tmp == -1) { #
	    	   	    $filtre="2";
							}
					}
    	   	if ($tmp == -1) {
							$numIllEnCours++;
							$filtre="2";$nbTotIllFiltreesOLR++;
							say "*** OLR filter: the ill. is not referenced in the OLR ToC  ***";}
					else {
    	   		  $sauvNumIllEnCours = $numIllEnCours; # oui : utiliser le numéro trouvé
    	   		  $numIllEnCours = $tmp;
    	   		  undef $filtre;}
					}
    	else
    	   {$numIllEnCours++;
    	   	undef $filtre;}	# cas standard

    	print " processing #ill: ".$numIllEnCours ;


    	#if ($MODE ne "olrbnf") { # si OLR BnF on ne filtre pas les illustrations par leur taille
    	 if (($ratio < $seuilTaille) # filtrer les illustrations de petites tailles
    	  or ($largeur/$hauteur > $ratioBandeau) #  pour filtrer les images étroites (filets, bandeaux)
    		or (($typeDoc ne "M") and ($numPageALTO==1) and (($y+$hauteur)<($hauteurPage/$ratioOurs))) # pour filtrer les ours de presse et revue
    		)
    	      {$filtre="1";$nbTotIllFiltrees++;
    	      if ($DEBUG) {say " ** image filtree  : ratio : $ratio (seuil = $seuilTaille) - l/h : ".
    	      	$largeur/$hauteur." (seuil : $ratioBandeau)";}
						print "   - \n";
    	  }
    	  else { # on garde les illustrations
    	 	  print "   + \n";}
      #}

    	# ecrire les MD dans le hash
    	if ($filtre) {
    		$hash{$numPageALTO."_ill_".$numIllEnCours."filtre"} = "1";}

    	$hash{$numPageALTO."_ill_".$numIllEnCours."x"} = int($x);
    	$hash{$numPageALTO."_ill_".$numIllEnCours."y"} = int($y);
    	$hash{$numPageALTO."_ill_".$numIllEnCours."w"} = int($largeur);
    	$hash{$numPageALTO."_ill_".$numIllEnCours."h"} = int($hauteur);
    	$hash{$numPageALTO."_ill_".$numIllEnCours."id"} = $idBlocAlto;
    	if (defined $typeIll) {  # genre lu dans l'OCR
    	 	  $hash{$numPageALTO."_ill_".$numIllEnCours."genre"} = $typeIll ;}

    	 # mode OCR : on cherche du texte dans l'OCR
    	 if ( index($MODE,"ocr") !=  -1) {
    	   #  on stocke pour plus tard l'ID du bloc texte ALTO avant l'illustration
    	   # ($listeIDtxt = tableau de tableaux)
    	   ( $IDtxt ) = $ligneTxtAvant =~ m/$motifIDALTO/;
    	   #say "IDtxt : ".$IDtxt;
         if (defined($IDtxt) && ($IDtxt ne "")) {
              $listeIDsTxt[$numPageALTO][$numIllEnCours] = $IDtxt;  # on cherche l'ID de l'éventuel bloc de texte qui suit l'illustration (légende)
           	  if ( $MODE eq "ocrbnf") {
           	    # bloc de texte suivant
           	    $IDleg =  incIdBlocALTO($IDtxt,1,$motifIDTxtBlock);  }
              else { # cas EN : tous les blocs sont numérotés en séquence
                $IDleg = incIdBlocALTO($IDtxt,2,$motifIDTxtBlock);    #+1 = illustration; +2 = bloc apres
              }
              #if ($DEBUG) {say "  -> ID txt avant  : ".$numIDtxt;}

           }
           else { # pas de txt avant : cas de l'illustration en premier dans la page
           	  #my @tmp = split($motifIDIllBlock,$idBlocAlto); # recuperer le num de page
           	  $IDleg = incIdBlocALTO($idBlocAlto, -1,$motifIDIllBlock); # on tente un ID = 1...
           }

           #le numero de l'ID du bloc texte ALTO apres l'illustration
           if ($IDleg) {
           	if ($DEBUG) {say "  -> ID legende  : ".$IDleg;}
           	$listeIDsLeg[$numPageALTO][$numIllEnCours] = $IDleg;}

         } # if mode = OCR
    	 #say "\n";
    	 #}
    	#} # if filtre petites images

       } # if $extractILL
      } #if $ligne =~ /$motifIllustrationALTO/
      if (($MODE eq "olrbnf")  and (defined $sauvNumIllEnCours))
         {$numIllEnCours = $sauvNumIllEnCours;
         	undef $sauvNumIllEnCours}

   } # fin while

   # il y a p-e des blocs de texte a extraire de l'OCR ALTO
   if (defined($listeIDsTxt[$numPageALTO]) or
      ((index($MODE,"ocr")!=-1) && defined($listeIDsLeg[$numPageALTO]))) {   # cas  OCR
     lireTexteALTO($fichier);}

  $hash{$numPageALTO."_mots"} = $mots;
  $hash{$numPageALTO."_blocsTexte"} = $textes;
  $hash{$numPageALTO."_blocsPub"} = $pubs;
  $hash{$numPageALTO."_blocsIllustration"} = $nbIll;
  #$hash{$numPageALTO."_illustrations"} = $numIllDecrites;
  $hash{$numPageALTO."_blocsTab"} = $tabs;
  if ($DEBUG) {say "\n** Illustrations in ALTO : ".$nbIll}
  close $fh;
}

# renvoie le numéro d'illustration dans la structure de données (@hash) à partir d'un ID de bloc d'illustration et de la pge
# get the illustration number from the block ID and the page
sub getNumIllHash {my $IDalto=shift;
			my $IDill=shift;
			#my $numIll=shift;

  if ($DEBUG) {say "... looking for #$IDill on #page $IDalto";}

	if (not %rhash) { %rhash = reverse %hash;} # inverser le hash
	my $key = $rhash{$IDill}; # chercher la clé qui correspond à l'ID du bloc
	if ($key) {
		  if ($DEBUG) {say " key: ".$key;}
		  my $motif = $IDalto."_ill_(\\d+)id"; # la clé est de la forme '2_ill_1id'
		  ( my $num ) = $key =~ m/$motif/;		# extraire le numéro de l'illustration
		  if ($DEBUG) {say " #ill: ".$num;}
	    return $num
     }
   else { # l'illustration n'est pas dans les hash : renvoyer un nouveau numéro
    if ($DEBUG) {say " can't find: $IDill";}
    return -1}
}


# -------------
# extraire les textes d'un fichier ALTO
# get the text from the ALTO file
sub lireTexteALTO {
	#my $id=shift;
	my $fichier=shift;

	   if ($DEBUG) {
	   	say "\n-----------------\nALTO extraction texte : ".$fichier;}

	   #say Dumper(\@listeIDsTxt);
	   #say Dumper(\@listeIDsLeg);

	   #  extraire par parsing XML
	   $t = XML::Twig -> new(output_filter=>'safe');
	   $t -> setTwigHandlers($handlerALTO); # parser avec un handler Twig
	   try {
	     $t -> parsefile($fichier);
	     #say Dumper ($t);
	     }
	   catch {
        warn "### FATAL error while reading ALTO: $_ ###";
        say  "########################################";
       };
	   $t -> purge(); # decharger le contenu parse
	   #say "-------------------- ALTO extraction texte ";
}


# raccourcir les textes
sub subTxt {
		my $texte=shift;

	 return (substr $texte, 0, $maxTxt);
}

# extraire le texte d'un bloc
sub getALTOtxt {
		my $elt=shift;
	  my $id=shift;

				#say $elt->name();
	       say "-> getTxt : ".$id;
	       my $xpath = '//TextBlock[@ID="'.$id.'"]';
	  	   my @bloc = $elt->get_xpath($xpath);
	  	   if ( scalar(@bloc) == 0)
	  	    { if ($DEBUG) {say "** bloc $id absent ou non texte ! **";}
	  	    	return ""}
	  	   else {
	  	     my @array = map { $_ -> att('CONTENT') } $bloc[0] -> get_xpath('TextLine/String');
	         my $scal = join(" ", @array);
	         # supprimer les - de cesure (a la hache...)
	         $scal =~ s/- //g;
	         if ($DEBUG) {print "    txt : ". (substr $scal, 0, 50) . " ...\n" ;}
	         #print "    txt : ". (substr $scal, 0, 30) . " ...\n" ;
	  	     return $scal
	  	   }
}




###################
sub calculerARK {my $id=shift;

	if ($calculARK == 1) {
		  if ($typeDoc eq "M") {calculerARKmono($id)} # cas des arks listés dans un fichier
		  else
		    {calculerARKperio($id)} # cas des arks de periodiques
	}
}

# ----------------------
# Ecriture des metadonnees
sub ecrireMD {my $id=shift;

  # calculer l'ID ark
  calculerARK($id);

  # generer tous les formats
  foreach my $f (@FORMATS) {
  		         exportMD($id,$f);
  		      }
}

#######################
#    exporter les MD d'un document
#    Document metadata export
#    cf. bib-XML.pl

# exporter les MD d'une page
# export the page metadata
sub exportPage {my $id=shift; # id document
	my $p=shift;   # numero de page
	my $format=shift;  # format d'export
	my $fh=shift;  # file handler

			my $coeffDPI;
	    if (defined $DPIdefaut) {
				$coeffDPI = $facteurDPI/$DPIdefaut;}
	    my $filtre;
	    my $une;
	    my $derniere;
	    my $couleur="";

	    say "... for #page: $p";
      #say Dumper %hash;

      %atts = ("ordre"=> $p);
  	  writeEltAtts("page",\%atts,$fh);
  	  writeElt("nbMot",$hash{$p."_mots"},$fh);
  	  writeElt("blocTexte",$hash{$p."_blocsTexte"},$fh);
  	  writeElt("blocTab",$hash{$p."_blocsTab"},$fh);
  	  writeElt("blocPub",$hash{$p."_blocsPub"},$fh);

      $nbIll =  $hash{$p."_blocsIllustration"};
      if ($nbIll) {
      writeElt("blocIll",$nbIll,$fh);
      if (($nbIll != 0) && ($extractILL==1)) {
      	writeOpenElt("ills",$fh);
      	# boucler sur les illustrations de la page
        for($i = 1; $i <= $nbIll; $i++) {
       	 print "     #ill: ".$i;
       	 my $idill =  $hash{$p."_ill_".$i."id"};
       	 if (not defined $idill) {
       	 	say " #### FATAL error:  illustration $i unknown!";
       	 	$bugsArk=$bugsArk.$id." ";
       	 	}
       	 else {
       	 if ($DEBUG) {say "    ID ill : ".$idill ;}
       	 my $w = $hash{$p."_ill_".$i."w"}; # en pixels
       	 my $h = $hash{$p."_ill_".$i."h"};
       	 my $larg = $w*$coeffDPI; # en mm
       	 my $haut = $h*$coeffDPI;
       	 my $taille = int($larg*$haut/$A8); # taille en nombre de A8
       	 #if ($DEBUG) { say "largeur : $larg (mm) / hauteur : $haut (mm) / taille : $taille";}

       	 # digitization color mode
       	 if (defined $couleurDefaut) { # utiliser la couleur par défaut
       	   	     $couleur = $couleurDefaut}
       	 else {
       	   	    #say Dumper (@couleurs);
       	   	  	if (@couleurs) {
       	   	  		my $tmp = $couleurs[$p-1];
       	   	  		#say " -> couleur : ".$tmp;
       	   				if ($tmp eq "1") {$couleur = "gris"}  # n&b
	           			 elsif ($tmp eq "8") {$couleur = "gris"} # gris
	           			 else {$couleur = "coul"}} # couleur
           			else {say " ## color mode unknown!"}
           		}
					 if ($DEBUG) {say "   color: $couleur"} ;

       	   if ($p==1) {  # illustration en une
       	   	    $une = "true";
       	   	    undef $derniere;
       	  	    #print {$fh} "une=\"true\">";
       	  	    }
       	   elsif ($p==$hash{"pages"}) { # illustration en derniere page
       	   	    $derniere = "true";
       	   	    undef $une
       	  			#print {$fh} "derniere=\"true\">";
       	  			}

       	   # si l'illustration est filtrée, positionner l'attribut
       	 	 if (defined $hash{$p."_ill_".$i."filtre"})
					 	{print "    ->filtered\n";}
       	   else {print "\n"}

       	   # ecrire les attributs
       	   %atts =("n"=>$p."-".$i,"x"=>$hash{$p."_ill_".$i."x"}, "y"=>$hash{$p."_ill_".$i."y"},
       	   "w"=>$w, "h"=>$h,  "taille"=>$taille,"couleur"=>$couleur,"rotation"=>$hash{$p."rotation"},
       	   "pub"=>$hash{$p."_ill_".$i."pub"},"une"=>$une,"derniere"=>$derniere,"filtre"=>$hash{$p."_ill_".$i."filtre"} );
  	       writeEltAtts("ill",\%atts,$fh);

       	   # classification
       	   my $tmp =  $hash{$p."_ill_".$i."genre"};  # types extrait de l'OCR
       	   $tmp = definirGenre($tmp);
       	   if ($tmp) {
       	   	 if ($DEBUG) {say "    genre extracted from the OCR: ".$tmp;}
       	   	 	$CS = 1 # CS = 1
       	      }
       	   if ((not $tmp) and (defined $genreDefaut)) { # genre par défaut
       	   	  if ($DEBUG) {say "    default genre: ".$genreDefaut; }
       	   	  $CS = 0.8;
       	   	  $tmp = $genreDefaut;
       	      }
       	   if ($tmp) {
       	     %atts = ("CS"=>$CS,"source"=>"md");  # source = metadata
       	     writeEltAtts("genre",\%atts,$fh,$tmp); }

       	   if (defined $themeDefaut) {
       	   	# CS =0.8
       	   	%atts = ("CS"=>0.8,,"source"=>"md"); # source = metadata
       	   	writeEltAtts("theme",\%atts,$fh,$themeDefaut);  # sujet IPTC
       	   	}

       	   if (index($MODE, "olr")!=-1) {  # il y a des titres uniquement en OLR
       	     $tmp =  $hash{$p."_ill_".$i."titre"};
       	     if ($tmp) {
       	       writeElt("titraille",escapeXML($tmp),$fh); }
       	     }
       	   $tmp = 	$hash{$p."_ill_".$i."leg"};
           if ($tmp && (index($tmp, "Untitled") == -1)) {
              writeElt("leg",escapeXML($tmp),$fh);}

           $txt = $hash{$p."_ill_".$i."txt"};
           # OLR : il peut arriver que le texte soit identique a la légende : ne pas le garder
           # substring pour supprimer les guillemets
           if ((($txt) && index($MODE,"ocr")!=-1)
            	or (($txt) && ($MODE eq "olren") && ( (not(defined($tmp))) or ($txt ne substr ($tmp,1,length($tmp) - 2))))) {
               #say "\n...TXT...";
               writeElt("txt",escapeXML($txt),$fh); }
            writeEndElt("ill",$fh);
         	 }
      } # fin for
      writeEndElt("ills",$fh);
      } # fin if
    }
    writeEndElt("page",$fh);
    }

# -----------------
# mapping du genre
# genre mapping
sub definirGenreold {my $genre=shift;

   switch ($genre) {
			case "map"		{return "carte"}
			case "carte"		{return "carte" }
			case "advertisement"		{ return "pub" }
			case "musicScore"		{return "partition" }
			case "dessin" 	{return "dessin" }
			case "Illustration" {return undef}
		else  { if ($DEBUG) {say "############ unknown genre: $genre  ################";}
			      return undef}
    }
}

sub definirGenre {my $genre=shift;

	 if (defined $genre) {
     my ($match) = grep {$_ =~ /$genre/} keys %genres;
     if ($match) {
   	   return $genres{$match}; }
     else { if ($DEBUG) {say "############ unknown genre: $genre! ";}
			      return undef
         }
      }
   else   { return undef
            }
 }

# ----------------------
# calcul d'un ark de monographie à partir de la liste des ID
# computing a monography ark ID from a file of IDs
sub calculerARKmono {my $id=shift;

	say "\n...computing ARK from IDs file: ".$id;
	#if ($DEBUG) {say Dumper (%arksMono);}

	($match) = grep {$_ =~ /$id/} keys %arksMono;
  if ($match) {
    say " -> match from IDs file: $match";
    $hash{"id"} = $match;
    return 0;
  }
  else {
  say "\n ## ID $id is missing in the IDs file! ##";
   $noArk=$noArk.$id." ";
    return -1  }
}


# ----------------------
# calcul d'un ark a partir d'un ID et d'une date de periodique
# computing a ark ID for a serial, based on the date
sub calculerARKperio {my $id=shift;

    	my $ark;
    	my $date = $hash{"date"}; # c'est une date ISO
    	my $supp = $hash{"supplement"};
    	my $extsupp = "";
    	my $annee;
    	my $urlDate;
    	my $i=0;
    	my $notice= $hash{"notice"};

    	say "\n...computing ARK: ".$date;

    	if (not defined ($notice)) {
    		say " ## unknown bibliographic record, can't process the ark ID!";
    	  return -1}

      if ($supp eq "TRUE") {
      	  #on a affaire a un fascicule qui est un supplement;
      	  $extsupp = ".supp";  }

      # cas de la presse Europeana Newspapers
	  if (index($MODE, "en") != -1) {
        $ark = $dateARKs{$date.$extsupp}; }  # on cherche dans le hash avec la cle date
      else {
      	 foreach my $key ( keys %dateARKs )   	{ # on cherche si une entree contient la date
         	 		if (index($dateARKs{$key},$id) != -1) {
         	 		  $ark = $dateARKs{$key} }
         	 	}
      }

      if ($ark) {
      	say "--> ark: ".$ark;
      	$hash{"id"} = $ark;
      	return 0;
      } else { # pas trouve dans le hash : il faut appeler l'API date
      	 # appeler l'API avec notice et annee
      	 $annee = substr $date,0,4; # format YYYY-MM-DD
         print "API: ".$annee." -> ";
         #  http://gallica.bnf.fr/services/Issues?ark=cb32830550k/date&date=1900
         $urlDate = $urlAPI.$notice."/date&date=".$annee;
         say $urlDate;
         # appeler l'API date
         $reponseAPI = get($urlDate);
         #print $reponseAPI;
         if ($reponseAPI)  {
          # remplir le hash par ligne
          @reponseXML = split '\n', $reponseAPI;
          #say $reponseXML[4];

          # remplir le hash
          foreach my $line (@reponseXML) {
          if (index($line,"<issue ") != -1) {
          	#say "L: ".$line;
          	( $tmpArk ) = $line =~ m/$motifArk/;
          	if ($MODE ne "ocrbnf") { # cas de la presse Europeana Newspapers
          		( $jour ) = $line =~ m/$motifJour/;
           		my ($year, $day_of_year) = ($annee, $jour);
           		# calculer le jour
           		my $jour = date("$year-01-01") + $day_of_year - 1;
           		#say "Jour : ".$jour;
           		if (exists($dateARKs{$jour})) { # il y a deja un fascicule avec cette date : cas edition du jour + supplement
           	     # NB : l'API ne permet pas de distinguer edition du jour et supplements
           	     # on suppose qu'elle liste d'abord l'edition
           		   say "-- a supplement exists: $jour - $tmpArk";
           		   # il faut inverser les arks car le script Perl traite d'abord les supplements (pour EN)
           		   	 $edArk = $dateARKs{$jour};
           		   	 delete($dateARKs{$jour});
                 	 $dateARKs{$jour.".supp"} = $edArk;
                 	 $dateARKs{$jour} = $tmpArk;
                   say "-- second: $edArk";
                }
             else {
               $dateARKs{$jour} = $tmpArk;}
              }
           else  # cas documents  bnf : on remplit le tableau avec les arks
            {
            	$dateARKs{$i} = $tmpArk;
            	$i++;
            }
          }}

         #if ($DEBUG) {say Dumper (%dateARKs); }
         if (index($MODE, "en") != -1) { # cas de la presse Europeana Newspapers
          # maintenant que le hash est rempli pour l'annee cherchee, on peut extraire l'ark
            $ark = $dateARKs{$date.$extsupp};
            }
         else { # cas documents  bnf : on cherche l'ark a partir de l'ID (en fait, il suffirait de calculer le car. de controle ark... )
         	 foreach my $key ( keys %dateARKs )
         	 	{
         	 		if (index($dateARKs{$key},$id) != -1) {
         	 		  $ark = $dateARKs{$key} }
         	 	}
         }

         if ($ark) {
      	     say  " --> matched ark: ".$ark;
      	     $hash{"id"} = $ark;
      	     return 0;
          } else {
          	say "\n   ## date ".$date." is missing in the Gallica Issues API!";
          	$noArk=$noArk.$id." ";
          	return -1
            }
         }
        else {
          say "\n   ## Gallica Issues API: no response!";
          $noArk=$noArk.$id." ";
          return -1}
    }
  }



=BEGIN
	# recuperation des textes ALTO a partir des ID contenus dans @listeIDsTxt (liste de listes)

	sub getALTOold {my ($t, $elt) = @_;

		   say "elt : ".$elt->name();
		   my $idCB = $elt->att(ID);
		   say "getALTO : ".$idCB;
		   # on est sur le bloc de l'illustration
		   #my @tmp = $elt->get_xpath('ComposedBlock[@ID="'.$idBlocAlto.'"]');
		   #return unless @tmp;
		   # on cherche un bloc texte avant l'illustration
	 	   my @tmp = $elt->prev_sibling;
	 	   #say Dumper (@tmp);
		   if ($tmp[0]->name() eq "TextBlock") {
		   	    print " *txt* : ".$tmp[0]->att(ID)."\n";
		   	    my @array = map { $_ -> att('CONTENT') } $tmp[0] -> get_xpath('TextLine/String');
		        $scal = join(" ", @array);
		        #print $scal;
		        say "txt : ". substr $scal, 0, 30  ;
		        $hash{$numPageALTO."_ill_".$idCB."txt"} = $scal;
		    }
		   #$t -> purge();
	}

	#### ne sert plus
	sub getALTOold {my ($t, $elt) = @_;

		  my $tmp;
		  my $idTB = $elt->att(ID);

		  $aref = $listeIDsTxt[$numPageALTO];
	      $n = @$aref - 1;
		  for ($i=0; $i<=$n; $i++) {
		   $tmp = $listeIDsTxt[$numPageALTO][$i];

	       if ((defined($tmp)) && ($idTB eq $tmp))  # version OLR : ((int(substr $idTB,-5))==$tmp))
	       {
	       	print "id TB : ".$idTB;
	 	      #say Dumper (@tmp);
		      if ($elt->name() eq "TextBlock") {
		         #print " *txt suivant* : ".$tmp[0]->att(ID)."\n";
	           my @array = map { $_ -> att('CONTENT') } $elt -> get_xpath('TextLine/String');
		       my $scal = join(" ", @array);
		       #print $scal;
		       print "    txt : ". (substr $scal, 0, 50) . " ...\n" ;
		       $hash{$numPageALTO."_ill_".$i."txt"} = substr $scal, 0, $maxTxt;  # raccourcir les textes
	           last;}  # interrompre la boucle
	       }
	      }
	      if ($MODE=="ocren"){
	      $aref = $listeIDsLeg[$numPageALTO];
	      $n = @$aref - 1;
	      say "nb legendes : ".$n;
		  for ($i=0; $i<=$n; $i++) {
		   $tmp = $listeIDsLeg[$numPageALTO][$i];

	       if ((defined($tmp)) && ($idTB eq $tmp))
	       {
	       	print "id TB : ".$idTB;
		      if ($elt->name() eq "TextBlock") {
	           my @array = map { $_ -> att('CONTENT') } $elt -> get_xpath('TextLine/String');
		       my $scal = join(" ", @array);
		       #print $scal;
		       print "    leg : ". (substr $scal, 0, 50) . " ...\n" ;
		       $hash{$numPageALTO."_ill_".$i."leg"} = substr $scal, 0, $maxTxt;  # raccourcir les textes
	           last;}  # interrompre la boucle
	       }
	      }
	    }

		 #$t -> purge();
	}

	# ----------------------
	# r�cup�ration des m�tadonn�es biblio : # pas utilis�, parsing XML trop lent
	#sub getMD {my ($t, $elt) = @_;
		   #my $id = $elt->att('id');
	#	   $hash{"titre"} = $elt->child(0)->child(0)->child(0)->child(0)->child(0)->text();
	#	   $hash{"date"} = $elt->child(0)->child(0)->child(0)->child(2)->child(0)->text();
	#	   $t -> purge();
	#	}

	# r�cup�ration des pages
	#sub getNbPages {my ($t, $elt) = @_;
	#	   $hash{"pages"} = scalar($elt->child(0)->children);
	#	   say  "      PAGES :     ",    $hash{"pages"};
	#	   $t -> purge();
	#	}


	# r�cup�ration des articles
	#sub getNbArticles {my ($t, $elt) = @_;
	#	   $hash{"articles"} = scalar($elt->get_xpath('//mets:div[@TYPE="ARTICLE"]'));
	#	   say  "      ARTICLES :     ",    $hash{"articles"};
	#	   $t -> purge();
	#	}

	# r�cup�ration des infos ALTO
	#sub getALTO {my ($t, $elt) = @_;

		   #my $page = $elt->child(0)->att(PHYSICAL_IMG_NR);
		#   if ($numPageALTO == 1) {
		 #    $hash{"largeur"} = int($elt->child(0)->att(WIDTH)*25.4/$DPI);
		  #   $hash{"hauteur"} = int($elt->child(0)->att(HEIGHT)*25.4/$DPI);
		   #  }

		   #$hash{$page."_mots"} = scalar($elt->get_xpath('//String'));
		   #$hash{$page."_blocsTexte"} = scalar($elt->get_xpath('//TextBlock'));
		   #$hash{$page."_blocsPub"} = scalar($elt->get_xpath('//ComposedBlock[(@TYPE="Advertisement")]'));
		   #$hash{$numPageALTO."_blocsTab"} = scalar($elt->get_xpath('//ComposedBlock[(@TYPE="Table")]'));
		   #$hash{$numPageALTO."_illustrations"} = scalar($elt->get_xpath('//Illustration'));

	#	   $t -> purge();
	#	}

	# pas utilise, parsing XML trop lent
	# filtrer sur les sections  du METS
	#$handlerMETS = {
		#'mets:dmdSec[@ID="MODSMD_ISSUE1"]'  => \&getMD,   # m�tadonn�es biblio
	 # 'mets:structMap[@TYPE="PHYSICAL"]'  => \&getNbPages,
	 # 'mets:structMap[@TYPE="LOGICAL"]'  => \&getNbArticles,  # nombre d'articles
	#};


	# filtrer sur les ALTO : blocs de texte
	#$handlerALTOold = {
		##'/alto/Layout/Page/PrintSpace' => \&getALTO,
		#'ComposedBlock[@TYPE="Illustration"]'  => \&getALTO,
	#};
	=END
