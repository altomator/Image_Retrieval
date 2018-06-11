#!/usr/bin/perl -w

# USAGE:
# perl extractMD_OAI.pl set OUT format
#    set OAI : gallica:corpus:1418 / gallica:corpus:1418Europeana  / gallica:corpus:BNUS1418Europeana
#    OUT : output folder
#    format : xml

# OBJECTIVES:
# 1. Extract the illustrations metadata of documents described in a OAI-PMH repository (from a set or from a list of IDs)
# 2. Enrich the metadata : theme classification, color mode, captions


#####################
# use strict;
use warnings;
use 5.010;
use Data::Dumper;
use utf8::all;
use Net::OAI::Harvester; # for OAI-PMH # Installation : cpan -fi Net::OAI::Harvester
use LWP::Simple;
use Lingua::Stem::Any;
use Switch;
use Try::Tiny;
use Image::Info qw(image_info dim);


######################
# global variables #
######################
%hash = ();	   	# hash table of metadata/value  pairs
$calculARK = 1;  #  ark IDs must be exported? (used in bib-XML.pl)
my $couleur;  	# color mode
my $genre;    	# illustration genre
my $theme;    	# illustration IPTC theme
my $portrait; 	# the illustration is a person portrait?
my $sujet;    	# illustration subject
my $pageExt;  	# page number to be extracted  -> see getRecordOAI_page()


#########################
### parameters to be set  ##
$DPI_photo = 600; # default DPI value for photos
$DPI_imp = 400; # default DPI value for print content
$facteur_imp= 25.4/$DPI_imp; # converting pixels to mm
$facteur_photo = 25.4/$DPI_photo;
$A8 = 3848; # A8 surface (mm2)

### uncomment the following parameters to set a default value
my $genreDefaut = "photo";    #  illustrations default genre
my $typeDefaut = "I";  # default source type  :  newspapers : P, magazine : R, monograph = M, image = I, manuscript = A, music scores = PA
#my $IPTCDefaut = "01";   # default IPTC theme
#my $couleurDefaut ="coul";  # default color mode: coul / gris / monochrome

# debugging mode
$DEBUG = 1;
########################


## import of XML output macros ##
require "../bib-XML.pl";


# API Pagination and Gallica
$urlAPI = "http://gallica.bnf.fr/services/Pagination?ark="; # Gallica Pagination API
$urlGallica = "http://gallica.bnf.fr/ark:/12148/"; # Gallica URL prefix
$urlOAI = "http://oai.bnf.fr/oai2/OAIHandler";  # Gallica OAINUM endpoint

# patterns for XML extraction
$motifOrdre = "\<ordre\>(\\d+)\<\/ordre\>" ;
$motifLargeur = "\<image_width\>(\\d+)\<\/image_width\>" ;
$motifHauteur = "\<image_height\>(\\d+)\<\/image_height\>" ;
$motifNumero = "\<numero\>(.*)\<\/numero\>" ;
$motifToc = "\<hasToc\>(\\w+)\<\/hasToc\>" ;
$motifOcr = "\<hasContent\>(\\w+)\<\/hasContent\>" ;
$motifLeg = "\<legend\>(.*)\<\/legend\>" ;
#$motifLeg = "\<numero\>(.*)\<\/numero\>" ;
$motifFirst = "\<firstDisplayedPage\>(\\d+)\<\/firstDisplayedPage\>" ;
$motifPage = ".*/f(\\d+)" ;

# Misc.
my $dateMin;   # to filter documents on dates
my $dateMax;
my $nbPages = 1;

# Counting #
$nbTotDocs=0;
$nbTotIlls=0;
$noClass = 0;$noGenre = 0;
$noRecord = 0; $nbDates = 0;
$nbPerio = 0;$nbMono = 0;$nbManu = 0;


# IPTC words network
my
# http://cv.iptc.org/newscodes/mediatopic/01000000
# themes
%iptc = (
	"guerr gard armé bataill militair pilot pillag canon épé boucli munit troph poilu poilus char chass invalid
  destroi  arme manoeuvr armii
  assaut monu offici camp   projectil   traducteur prisonni ennem sous-marin drapeau
   bas destruct biplan alert  fortification    mobilis casqu bombard médaill
   étendard dommag casemat   général bombardi capitain soldat casern croiseur navy
   fort képi raid torpilleur destroyer victoir drapeau masqu espionnag
   cadavr patrouilleur capitul commémor commémorativ canonni démolit cuirass antiaérien
   fleury douaumont verdun pruss autriche-hongr clemenceau"  => "16",
   #Conflits, guerres et paix

	"patrimoin spectacl  artist architectur amphitheatr peintur retabl
	chanson acteur  statu cloîtr symphon muraill aren chant piano poem parol
	tow  estamp costum beffrois mélod  poésie musiqu music  chansonnette-march
	allégor théâtr boulevard partit  hymn vals tour clocher trianon monument
	château opéra escali salon exposit colon   beffroy violoncel orgu
	panthéon bastill versaill concord porte  danse cinem
	franc espagn allemagn portugal roussillon lectur orchest concert"
	=> "01",
	# Arts, culture et div., patrimoine

  "proces tribunal" => "02",
  #Criminalité, droit et justice

  "naufrag inond incend érupt catastroph explos effondr cru" => "03",
  #Désastres et accidents

  "agriculteur commerc vêt transport bovin agricol ponton pont légum horticultur port banqu
  agricultur industr ciment charbon   hall prêt canal post recyclag manufactur cargo presse
  coton moulin chanti econom vent collect det assur emprunt" => "04",
  #Economie et finances

  "enseignement écol lycée scout bibliothequ class scolair" => "05",
  #Education

  "" => "06",
  #Environnement

  "hôpital réadapt greff gripp sanatorium  secrétariats-greff hygien
  tuberculos tubercul blessur amput ambulance alcool santé pharmac" => "07",
  #Sante

  "cheval serpent femm homm enfant person rein cardinal princess diplomat consul roi princ ministr
  ambassadeur empereur duc pape maharajah maréchal
  baigneux  famill épous joueur déput  président " => "08",
  "portr" => "08p",
  #Gens animaux insolite

  "manifest défil foul voier usin quais entretien associ grev cheminot
  restaur bureau secrétariat sapeurs-pomp foul ferm" => "09",
  #Social, Monde du travail

  "bain pêch viand foir caf viand oeuf commerc neig trottinet fromager parfumer
  marché cerceau  motocyclet épicer boucher gare  vacanc fêt roserai  orchestr polic
  jeux hiv ballon cyclist autobus palac  carbur piscin fontain promenad plag baigneur
  divert rob chambr  bicyclet mair  vill conducteur noël poulaill mariag journal
  balcon habit villag tourist tourism  hôtel pompi tricot danseur mall parisien
  canotag traîneau maison boulevard cognac cigaret lamp boisson eau tabac éclairag
  horloger magasin cirqu aliment parfum mode biscuiter " => "10",
  #Vie quotidienne et loisirs

  "inaugur réunion candidat élect officiel mission  emprunt parlement
   parlementair révolu trait ministériel armistic histoir
   interparlementair conférence congrès polit républ fronti histoir" => "11",
   #Politique, histoire

  "églis eglis basiliq cathédral process abbay  ecclésiast
  musulman cimeti  prêch crucifix baptistère cloch  funérair chapel nef
  saint toussaint rit pèlerin crémati calvair mess tomb" => "12",
  #Religion et croyance

  "avion camion navir machin construct  automobil  invent paquebot  dirigeabl
  tracteur train véhicul bateau tramway gru brise-glac aqueduc
   " => "13",
  #Science et technologie

  "réfugi rapatri prison administr polic humanitair cris bienfais  aérien
  orphelinat nobless sécur garder civil anniversair maman press" =>  "14",
  #Société

  "sport sportiv sportif coureur nageur nageux natat plongeur basket-ball cavali cross
  cours side-car lanceur saut perch aviron boxeur équip marathon
  parachut football rugby patinag hippodrom hippiqu jockey compétit water-polo athlet marathon
  stad cricket gymnast cord équit tennis" => "15",
  #Sport

  "" => "17" #Météo
    	 );



###############################
# illustration genre words network
%genres = (
	"musique musical music hymne chanson partition symphonie" => "partition",
	"monographie monograph"
	=> "monographie",
	"série serial" => "série",

	"carte plan cartes plans" => "carte",
	"estampes estampe lithographiées litho. lithographe lithographiée eaux-fortes
	gravures gravure eau-forte"
	=> "gravure",

	"dessins dessin sketch sketchbook drawings drawing  illustrateur dessinateur
	cartoons cartoon croquis satirique satiriques caricaturiste"
	=> "dessin",

	"photographie photograph photographique photogr photogr. phot.
	 aériennes aérienne "
	 => "photo",

	"manuscrit manuscript archive archives archival"
	=> "manuscrit"

	#"affiche"
	#=> "affiche"
	);

###############################

# lemmatisation
$stemmer = Lingua::Stem::Any->new(language => 'fr',
         exceptions => {
            fr => {

            	basilique => 'basiliq',
            	dettes => 'dette',
            	dette => 'dette',
            	gare => 'gare',
                cargos  => 'cargo',
                rue  => 'rue',
                rues  => 'rue',
                baptistère => 'baptistère',
                baptistères => 'baptistère',
                ambulance  => 'ambulance',
                ambulances  => 'ambulance',
                conférences => 'conférence',
                conférence => 'conférence',
                dirigeable => 'dirigeabl',
                képi  => 'képi',
                képis  => 'képi',
                congrès => 'congrès',
                danse => 'danse',
                marché => 'marché',
                mode => 'mode',
                monument => 'monument',
                monuments => 'monument',
                pape => 'pape',
                parlement => 'parlement',
                portant => 'portant',
                porte  => 'porte',
                opéra => 'opéra',
                opéras => 'opéra',
                poésie => 'poésie',
                santé => 'santé',
                }
            });


#######  Harvester instance
my $harvester = Net::OAI::Harvester->new(
            baseURL => $urlOAI
           # baseURL => 'http://catoai.bnf.fr/oai2/OAIHandler'   # OAICAT
);


####################################
# get one record
sub getRecordOAI {my $ark=shift;

	my $result = $harvester->getRecord(
		     metadataPrefix  => 'oai_dc',
		     identifier      => $ark
    );

  if ( my $oops = $result->errorCode() ) { say "## OAI $ark : ".$oops; die};

	my $header = $result->header();
  my $metadata = $result->metadata();
  my $id =substr $ark,11; # supprimer ark:/12148/
  my $tmp = getMD($metadata);
  if (defined ($tmp)) {
       exportMD($id,$format);
      }
    }

####################################
# get only one page of a document
sub getRecordOAI_page {my $ark=shift;

	# arks have this form:  ark:/12148/btv1b8625630v/f12.image
	($pageExt ) = $ark =~ m/$motifPage/; # set the global var
	say "\npage : ".$pageExt;
	$ark = substr $ark, 0, (length($ark) - length($pageExt) - 8) ; # remove the end
	#say " ark : ".$ark;
	my $result = $harvester->getRecord(
		     metadataPrefix  => 'oai_dc',
		     identifier      => $ark
    );

  if ( my $oops = $result->errorCode() ) { say "## OAI : ".$oops; die};

	my $header = $result->header();
  my $metadata = $result->metadata();
  my $id =substr $ark,11; # suppress "ark:/12148/" to get the ID
  my $tmp = getMD($metadata);
  if (defined ($tmp)) {
       exportMD($id,$format,$pageExt);   # we add the page number in the file name (in case several pages are asked for the same ID)
      }
    }

####################################
# comput the set size
sub getSizeOAI {my $set=shift;

	  my $r = 0;
    my $headers = $harvester->listAllIdentifiers(
        metadataPrefix  => 'oai_dc',
        'set' => $set
    );

    if ( my $oops = $headers->errorCode() ) { say "## OAI : ".$oops; die};
    while ( my $header = $headers->next() ) {  # a Net::OAI::Record::Header object
        $r++;
    }

    say "Records number: $r";
    }


####################################
# get the whole set
sub getOAI {my $set=shift;

## list the records set
my $records = $harvester->listAllRecords( ############  #listAllRecords
  'metadataPrefix'    => 'oai_dc',
  'set' => $set
    );

 # process the records
 while ( my $record = $records->next() ) {
  if (defined($record)) {
    my $header = $record->header();
    my $metadata = $record->metadata();

    #my $status = $header->status();
    if (not (defined ($metadata))) {
    # (($header->headerStatus() eq "deleted") or ($header->status() eq "deleted"))) {
    	say "###  OAI : problem on document $header->identifier()  ";
    	say Dumper ($header);
      	say Dumper ($metadata);
    }
    else {
     	my $id = getMD($metadata);
     	if (defined ($id)) {
      	  #my $fichier = $OUT."/".$id.".".$format;
       	  exportMD($id,$format);
       	  if (($nbTotDocs % 10)==0) {say $nbTotDocs;}
     	}
     	else
      	{say "### record can't be analysed ##";
       	$noRecord++;}
       }
		  }
    else{
    	say "## OAI : ".$record->errorCode();
    	}
  }
}


##################################################
####                MAIN                      ####
##################################################
my $identity = $harvester->identify();
my $OAIname = $identity->repositoryName();
if ((defined $OAIname ) and (length $OAIname>0))
  {say "OAI: ".$identity->repositoryName(),"\n";}
else {
	say "### OAI $urlOAI is not responding! ###";
	die}

if (scalar(@ARGV)<3) {
	die "\nUsage : perl extractMD.pl set OUT format
set : OAI set title
OUT : output folder
format : output format (xml)
	\n";
}

$set=shift @ARGV;

# output folder
$OUT=shift @ARGV;
if(-d $OUT){
		say "Writing in $OUT...";
	}
	else{
		mkdir ($OUT) || die ("##  Error while creating folder : $OUT\n");
    say "Creation de $OUT...";
	}

$format = shift @ARGV;


#####################################

# to get the OAI set size #
#getSizeOAI($set);

# to get the whole OAI set #
getOAI($set);

# to get one document #
#getRecordOAI("ark:/12148/btv1b8432784m");
#getRecordOAI("ark:/12148/btv1b10528666v");
#getRecordOAI("ark:/12148/btv1b53148749t");
#getRecordOAI("ark:/12148/btv1b55002885z");
#die

# to get one page
#getRecordOAI_page("ark:/12148/btv1b7100627v/f761.image");

# to load a list of arks in a external .pl file:
#require "arks.pl";

#####################################




say "\n=============================";
say "$nbTotDocs documents ";
say "$noRecord documents rejected ";
say "  $nbPerio  periodical records ";
say "  $nbMono monographs";
say "  $nbManu manuscripts";
say "  $nbDates dates";
say "$noClass no theme ";
say "$noGenre no illustration genre ";
say "--------------------";
say "illustrations: $nbTotIlls";
say "--------------------\n";


##################################################
####            end MAIN                      ####
##################################################



######################################
# extract the metadata
sub getMD {my $metadata=shift;

    	my $ark;
    	my $match;
    	my $id;

    	# Reset the hash
    	%hash = ();
    	undef $couleur;
    	undef $portrait;

    	my $tmp = $metadata->identifier();
    	if (defined ($tmp)) {
    		$id =substr $tmp,33; # suppress http://gallica.bnf.fr/ to get the ID
    	    $hash{"id"} = $id;}
    	else
    	  {say "## NOK / OAI $set : ID unknown ##";
    	  	say Dumper ($metadata)  ;
    	   return undef}

    	say "-----------------\nid : ".$id;

    	# to filter the periodical records
    	if (  $id =~ /date/ ) {
    		if ($DEBUG) {say "## NOK / periodical record : ID = ".$id;}
    		$nbPerio++;
    		return undef}

    	if (defined ($titre = $metadata->title())) {
    		$hash{"titre"} = escapeXML_OAI($titre);
    		if ($DEBUG) {say " title : ".$hash{"titre"};}
    	}
    	  # $hash{"1_ill_1_leg"} = escapeXML($titre);} # on copie le titre dans le champ légende (il s'agit d'images)
    	  # a revoir si docs multipages
    	else
    	   {if ($DEBUG) {say "## NOK / unknown title : ID = $id ##";}
    	}

    	# dates
    	$tmp = $metadata->date();
    	# filter on dates
    	if ((defined $dateMin) && (defined $tmp) && ($tmp < $dateMin)) {
    		if ($DEBUG) {say "## filter on date min : $dateMin";}
    		$nbDates++;
    	  return undef}
    	if ((defined $dateMax) && (defined $tmp) && ($tmp > $dateMax)) {
    		if ($DEBUG) {say "## filter on date max : $dateMax";
    			}
    		$nbDates++;
    	  return undef}


    	$tmp ||= "inconnu";
    	$hash{"date"} = $tmp;
    	if ($DEBUG) {say " date : $tmp";}

    	# source of document types : newspapers, image...
    	if (defined $typeDefaut) {   # if we have a default type
    	    $hash{"type"} = $typeDefaut}

    	# searching for illustrations genre  : photo/gravure/dessin/partition/carte/manuscrit
    	# dc:subjet
    	my @sujets = $metadata->subject();  # sometimes we have multiple subjet fields
    	my $sujet = join (' ',@sujets)  ;

    	# dc:author
    	my @auteurs = $metadata->creator();
    	my $auteur = join (' ',@auteurs)  ;

    	# dc:type
    	my @types = $metadata->type();
    	$type = join (' ',reverse @types)  ; # reverse because discriminative words are located at the end
    	#if ($DEBUG) {say "type : ".$tmp;}

    	# dc:format
    	my @formats = $metadata->format();
    	my $format = join (' ',@formats)  ;
    	# we add title because it can contains discriminative words
    	@mots = split(' ',lc(escapePunct($type." ".$format." ".$titre." ".$sujet." ".$auteur)));

    	# confronting the metadata to the words network for illustration genres
    	foreach my $t  (@mots) {
    		if ($DEBUG) {say $t." - ";}
    		($match) = grep {$_ =~ /\b$t\b/} keys %genres;
    	   if ($match) {
    	      $genre = $genres{$match};
    	      if ($genre eq "série") {
    	      	 say "## NOK / periodical : $id";
    	      	 $nbPerio++;
    	      	 return undef; # periodical records are useless here
    	      	 #$hash{"1_ill_1_genre"} = $typeOK;
    	      	 #$hash{"type"} = "R";  # il faut changer le type
    	      	}
    	      	elsif ($genre eq "monographie" ) {
    	      		say "## Monograph : $id";
    	      		$nbMono++;
    	      		# return undef;
    	      		#$hash{"1_ill_1_genre"} = $typeOK;
    	      	  #$hash{"type"} = "M";  # il faut changer le type
    	      	}
    	      	elsif ($genre eq "manuscrit" ) {
    	      		say "## Manuscript : $id";
    	      		$nbManu++;
    	      		#return undef;

    	      		#$hash{"1_ill_1_genre"} = $typeOK;
    	      	  #$hash{"type"} = "M";  # il faut changer le type
    	      	}
    	      	elsif ($genre eq "image" ) { # image générique, on ne sait rien de plus
     	      		#say "## Image : $tmp";
    	      		}
    	      last;
    	  }
    	}

    	if (not (defined $match)) {
    		say "\n### unknown illustration genre: @mots ##";
    	  $genre ="inconnu";
    		$noGenre++;}
    	else {
    	    say "\n illustration genre --> ".$genre}

    	# loooking for illustration color mode on dc:format
    	if ($genre eq "photo") {
    	    $couleur = "gris" ;}  # assumption
    	if ( $format  =~  m/.+coul\..+/) {
    	   $couleur = "coul";
    	  }
			$couleur ||= "inconnu";
    	if ($DEBUG) {say " color mode --> $couleur";}

    	# looking for theme
    	if (@sujets) {
    		$sujet = escapeXML_OAI($sujet);
    		$hash{"sujet"} = $sujet;
    		# searching for theme in the IPTC words network
    		$theme = extractIPTC($sujet);
    		if (not (defined ($theme))) {
    			if ($DEBUG) {say " FAIL on dc:subject"};
    		  $theme = extractIPTC($titre);} # next try on dc:title
    	}
    	else  # if no dc:subject, let's try on title
    	  {$sujet = $titre;
    	  $theme = extractIPTC($sujet);} #

  	  # last try
    	if (not (defined ($theme))) {
    	   if ($DEBUG) {say " FAIL on dc:subject and dc:title... try on person"; }
    	   # using regexp to find a person name
         if ( $sujet  =~  m/.+,\ .+(\d+) ?-(\d+) ?/)  # motif Stroehlin, Henri (1876-1918) ou (1876?-1918)
              { say " -> person";
                $theme = "08p";
                $portrait=1; }
         # try on dc:description
         if (defined($sujet = $metadata->description()))
              {  $theme = extractIPTC($sujet);}
         # try on document types
         if ($genre eq "partition")
             {$theme="01";}  # "arts"
         elsif ($genre eq "carte")
             {$theme="13";} # "siences"
        }
      # conclusion
      if (not (defined ($theme)))
             {if ($DEBUG) {say "########## unknown theme ##########\n";}
             	$theme = "inconnu";
              $noClass++;}
      else {
            	if ($DEBUG) {say "** IPTC --> $theme";}  }

    	# extract dimensions
    	@props = extractProperties($id);
    	if (@props) {
    	   if (not($props[0] =~ /^\d+?$/)) { # we need integer values (pixels)
             say "##################### PROBLEM w ".$props[0];
             return undef
            }
         if (not($props[1] =~ /^\d+?$/)) {
             say "##################### PROBLEM h ".$props[1];
             return undef
            }

    		 # the Gallica API doesn't return the DPI value
    		 if ($hash{"type"} eq "M") {  # different DPI depending on the document types
    		   $facteur= $facteur_imp;}
    		 else {$facteur= $facteur_photo;}

    	   $hash{"largeur"} = int($props[0]*$facteur); # document size in mm
    	   $hash{"hauteur"} = int($props[1]*$facteur);
    	   if ($DEBUG) {
    	       say "l: ".$props[0]." - h: ".$props[1]." (pixels)";
    	       say "width: ".$hash{"largeur"}." - high: ".$hash{"hauteur"}." (mm)";}
            $hash{"taille"} = int($hash{"largeur"}*$hash{"hauteur"} / $A8) ; # in termes of A8 size
        }
        else {say "#### API Gallica Pagination failed ####";
              return undef;
              }

    	return $id;
}

############################
# extract the IPTC theme from a string
sub extractIPTC {my $chaine=shift;

      if ($DEBUG) {say " extractIPTC : ".$chaine;}
        $chaine =~ s/ -- / /g;# suppress the --
    	$chaine = escapePunct($chaine); # suppress punctuation
        $chaine =~ s/  / /g;# suppress  double spaces from escapePunct()
    	if ($DEBUG) {say " string: ".$chaine;}
    	# tokenize on space or '
    	my @mots = split(' |\'|’',$chaine);
    	# lemmatise
    	my @motsLem  = $stemmer->stem(@mots);
    	#if ($DEBUG) {say "lemmes: ".Dumper(\@motsLem);}
    	# llok for a match in the IPCT hash
    	foreach my $m  (@motsLem) {
    	 	if ((length($m) > 2) && ($m =~ /^[a-zA-Zéèêëàâôïîç-]+$/))  {	# if word > 3 characters and alphanumeric
    	 	 	 if ($DEBUG) {say "word: ".$m;}
    	 	 	 ($match) = grep {$_ =~ /\b$m\b/} keys %iptc;	  # \b to start the match at beginning of word and stop at end
    	    if ($match) {
    	    	say "-> match: $match";
    	       return $iptc{$match};
    	       }
            }
          }
   return undef;
}

############################
# extract dimensions + some more info from and ark ID
sub extractProperties {my $id=shift;


     # cas du multipage :
     # une seule legende :
     # http://gallica.bnf.fr/services/Pagination?ark=btv1b84363424
     # http://oai.bnf.fr/oai2/OAIHandler?verb=GetRecord&metadataPrefix=oai_dc&identifier=ark:/12148/btv1b84363424

     # avec plusieurs légendes :
     # http://gallica.bnf.fr/services/Pagination?ark=btv1b8447273x
     # btv1b10315960d
     # btv1b105256695

     # une page :
     # http://gallica.bnf.fr/services/Pagination?ark=btv1b530158131
     #bpt6k383685v

     # pages de texte
     # http://gallica.bnf.fr/services/Pagination?ark=btv1b10315938r

    # reliure
    #http://gallica.bnf.fr/ark:/12148/btv1b55002864p/f1.planchecontact

    # call API Gallica
    my $url = $urlAPI.$id;
    my $legende1 ;
    my @legendes;
    my @pages;
    my @numeros;
    my @largeurs;
    my @hauteurs;
    my @lines;
    my $ok;

    say " ... calling the pagination service: $url";
    my $reponseAPI = get($url); # get is in LWP::Simple
    if ($reponseAPI)  {
     	# test if ToC
     	(my $toc) = do { local $/; $reponseAPI =~ m/$motifToc/s };
     	$hash{"toc"} = $toc;
     	if ($DEBUG) {say "** ToC: ".$toc;}
      # test if OCR
     	(my $ocr) = do { local $/; $reponseAPI =~ m/$motifOcr/s };
     	$hash{"ocr"} = $ocr;
     	if ($DEBUG) {say "** OCR: ".$ocr;}

     	# look for the opening page
     	($pageOuv) = do { local $/; $reponseAPI =~ m/$motifFirst/s };
     	$pageOuv ||= 1; # 1 if no opening paget
      if ($DEBUG) {say "** Opening page: ".$pageOuv;}
      # pages order
		 	@pages = do { local $/; $reponseAPI =~ m/$motifOrdre/g };
		 	$nbPages =  scalar @pages;
		 	$hash{"pages"} = $nbPages;
		 	if ($DEBUG) {say "** Pages number: ".$nbPages }
      # pages number, dimensions
     	(@numeros ) = do { local $/; $reponseAPI =~ m/$motifNumero/g };
      (@largeurs ) = do { local $/; $reponseAPI =~ m/$motifLargeur/g };
     	(@hauteurs ) = do { local $/; $reponseAPI =~ m/$motifHauteur/g };
    	if ($DEBUG) {
     					 #say Dumper(\@largeurs);
     					 #say Dumper(\@hauteurs);
     					 #say Dumper(\@numeros);
     			}
     	# test if the data is unconsistent
     	if ((scalar @pages) != (scalar @largeurs)) { # problem!
     			say "### unconsistent data for document $id: pages number: $nbPages / dimensions number: ".(scalar @largeurs);
     			return undef}

     	# looking for pair of caption/page number
     	@lines = split /\n/, $reponseAPI;
     	foreach my $line (@lines) {
     			#say $line;
     			(my $leg ) = $line =~ m/$motifLeg/;
     			if (defined $leg) {say " caption: ".$leg; $legCourant = $leg;}
     			(my $num ) = $line =~ m/$motifOrdre/;
     			if (defined $num) {
     				print "$num ";
     			  $numCourant = $num;}
     			if ((defined $legCourant) and  (defined $numCourant)){
     			  if ($DEBUG) {say "caption on page: ".$numCourant." : ".$legCourant;}
     			  $legendes[$numCourant-1]= $legCourant;
     			 undef $legCourant;undef $numCourant}
     		}

      if ($DEBUG) {say "\ncaptions: ".Dumper(\@legendes);}

      # common case where we only have one caption (one first page)
     	if (scalar @legendes == 1) {
     			if ($DEBUG)   {say " one caption";}
     			$legende1 = escapeXML_OAI($legendes[0]);
     		    if ($legende1 eq $hash{"titre"}) { # if caption== title, throw it away
     		      	 if ($DEBUG) {say " caption == title"; }
     			     undef $legende1;
     				 undef $legendes[0];}
     		}
     	# for some document types, we only keep the opening page
     	if (($genre eq "partition")  or ($genre eq "manuscrit")) {
  	            $hash{$pageOuv."_ill_1_w"} = $largeurs[$pageOuv-1];
  	            $hash{$pageOuv."_ill_1_h"} = $hauteurs[$pageOuv-1];
  	            $hash{$pageOuv."_ill_1_coul"} = getColor($id, $pageOuv);
  	        }
  	  elsif (defined $pageExt) { # if we only have a page to consider (getRecordOAI_page)
  	        	$hash{$pageExt."_ill_1_w"} = $largeurs[$pageExt-1];
  	          $hash{$pageExt."_ill_1_h"} = $hauteurs[$pageExt-1];
  	          $hash{$pageExt."_ill_1_coul"} = getColor($id, $pageExt);
  	        }
  	  else{ # std case: we have one illustration per page
     		   for (my $i = 1; $i <= $nbPages; $i++) {
     		   	  # we have to throw away the binding pages: "plat", "dos" keyword
     		      if ((index($numeros[$i-1], "plat ") == -1)
							  and (index($numeros[$i-1], "garde ") == -1)
								and $numeros[$i-1] ne "dos") {
     		  	    $hash{$i."_ill_1_w"} = $largeurs[$i-1]; # en pixels
     		        $hash{$i."_ill_1_h"} = $hauteurs[$i-1];
     		        $ok = 1;
     		        }

    			 # if only one caption,  duplicate the caption everywhere
    		   if (defined ($legende1)) {
    		         if ($DEBUG) {say "duplicated caption";}
    		         $hash{$i."_ill_1_leg"} = $legende1;}
    		   else { # std case
    		  	     $hash{$i."_ill_1_leg"} = escapeXML_OAI($legendes[$i-1]);}

    		   if ($ok) {
     		  	 	# guess the color mode
    		  	  if (not (defined $couleur))  {
     		         $hash{$i."_ill_1_coul"} = getColor($id, $i);}
     		      else {$hash{$i."_ill_1_coul"} = $couleur;}
     		    }

     		   }
    		 }
    		return ($largeurs[0],$hauteurs[0]) # return  dimensions of the first page
      }
    else {
          say "\n   ### API Gallica Pagination : no response! ###";
          return undef;
    }
}

############################
# get color mode from the image file
sub getColor {my $id=shift;
	            my $page= shift;

 #say "getColor: $page";
 if (defined $couleurDefaut) {
	   return $couleurDefaut}
 else {
	my $file = "/tmp/test.jpg";
	my $url = $urlGallica.$id.".thumbnail";
	#say $url;

	getstore($url, $file);

	my $info = image_info($file);
	#say Dumper ($info);
	if (my $error = $info->{error}) {
     say "Can't parse image info: \n$error";
  }

    #my $color = $info->{SamplesPerPixel};
	my $color = $info->{color_type};
	if ($color eq 'YCbCr') { # cas PNG/JPG
	   $color = $info->{SamplesPerPixel};}

	if ($DEBUG) {say "** color of page $page: ".$color;}
	 switch ($color) {
		case "1"		{ return "gris" }
		case "Gray"		{ return "gris" }
		case "3"		{ return "coul" }
		else		{ say " ### unknow color mode: $color ###";
			return undef }
	}
	}
}


#######################
#    export the metadata
#    cf. bib-XML.pl library

# exportPage($id,$p,$format,$fh);

#######################
#  export the metadata for a page
sub exportPage {my $id=shift;
	            	my $p=shift;        # page number
								my $format=shift;   # format : xml
	            	my $fh=shift;       # file handler

	if (exists $hash{$p."_ill_1_w"})  {  # don't export pages with no illustration
	  if ($DEBUG) {say "ExportPage n°$p"; }

	  $nbTotIlls++;
	  %atts = ("ordre"=> $p);
  	  writeEltAtts("page",\%atts,$fh);
  	  writeElt("blocIllustration",1,$fh);  #  one illustration per page
  	  writeOpenElt("ills",$fh);

  	  %atts =("n"=>$p."-1",  "x"=>1, "y"=>1, "w"=>$hash{$p."_ill_1_w"}, "h"=>$hash{$p."_ill_1_h"},
  	  "taille"=>$hash{"taille"}, "couleur"=>$hash{$p."_ill_1_coul"}); # n has this format : n° page-n° ill  (here n° ill = 1)
  	  writeEltAtts("ill",\%atts,$fh);
  	  if (defined $genreDefaut) {
    		      %atts = ("CS"=> "1");    # confidence value = 1
  	  	  	  writeEltAtts("genre",\%atts,$fh);
  	  	  	  print {$fh} $genreDefaut;
  	  	  	  writeEndElt("genre",$fh); }
  	  if ($genre ne "inconnu") {
  	  	  	  %atts = ("CS"=> "0.95");  # confidence = 0.95 (based on the document metadata)
  	  	  	  writeEltAtts("genre",\%atts,$fh);
  	  	  	  print {$fh} $genre;
  	  	  	  writeEndElt("genre",$fh);
  	  	      }
  	  if (defined ($IPTCDefaut)) {
  	  	    %atts = ("CS"=> "1");
  	  	  	writeEltAtts("theme",\%atts,$fh);
  	  	    print {$fh} $IPTCDefaut;
  	  	  	writeEndElt("theme",$fh)}
  	  elsif (defined($theme)) {
           %atts = ("CS"=> "0.8");  # confidence = 0.95 (based on the IPTC words network)
  	  	  	writeEltAtts("theme",\%atts,$fh);
  	  	    print {$fh} $theme;
  	  	  	writeEndElt("theme",$fh)}
  	 if (defined $portrait) {  	  	# if the illustration is a portrait
  	  	 %atts = ("CS"=> "1.0");
  	     writeEltAtts("contenuImg",\%atts,$fh);
  	     print {$fh} "person";
  	  	 writeEndElt("contenuImg",$fh);}
  	 # caption
  	 $tmp = $hash{$p."_ill_1_leg"};
  	 if (defined ($tmp) and (length($tmp)>0)) {writeElt("leg",$tmp,$fh);}
  	 # duplicate the document title in the illustration title (to be consistent with other document types (newspapers...)
  	 writeElt("titraille",$hash{"titre"},$fh);

  	 writeEndElt("ill",$fh);
  	 writeEndElt("ills",$fh);
  	 writeEndElt("page",$fh);
  	}
  	else {if ($DEBUG) {say "ExportPage n°$p: filtered illustration";}}
 }
