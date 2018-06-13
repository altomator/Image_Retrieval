#!/usr/bin/perl -w


#######################

# USAGE: perl traiterIMGs.pl -service  IN
#   service: see below
#   IN : input folder

# OBJECTIVES:
# Reprocess and enrich the illustrations metadata


# use strict;
use warnings;
use 5.010;
use LWP::Simple;
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
use GD;
use Color::Rgb;
use JSON qw( decode_json );
#use Parallel::ForkManager;
#use IPC::Shareable;

binmode(STDOUT, ":utf8");

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


############  Parameters  ###########################
my $couleur="mono"; # default color mode (to be set if using the -color option): mono, gris, coul
my $illThemeNew="16";     # default IPTC theme (to be set if using the -setTheme option)
my $documentType="PA";   # document type to be fixed with the -fixType option : PA = music score, C = map
my $illGenreOld="graphique";   # illustration genre to be looked ()-fixType and -setGenre options)
my $illGenreNew="photog"; # illustration genre to be set with the -setGenre option
my $classifSource="md"; # illustration genre source : TensorFlow, md, hm, cw (-fixSource, -setGenre or -delGenre options)

## Images parameters used for IIIF calls ##
my $factIIIF = 15;   # size factor for IIIF image exportation (%)
my $modeIIIF ="linear"; # export using $factIIIF size factor even for small images
# To avoid small images to be over reduced, set $modeIIIF to any other value
my $expandIIIF=0.1 ; # expand/reduce size factor for image cropping. The final size will be x by 1+$expandIIIF
# Used for OCR (expand), image classification (crop), faces extraction (expand)
my $reDimThreshold = 600;  # threshold (on the smallest dimension) under which the output factor $factIIIF is not applied (in pixels)
#my $seuilExport = 50; # threshold (biggest dimension) under which the illustration is not exported

####################################
# for Classification APIs
my $processIllThreshold = 250;  # max ill to be processed
my $classifCBIR="ibm"; # classification service : dnn, ibm, google, aws (-CC -fixCBIRsource options)
my $classifAction;     # CC / DF. Set from the option asked by the user
#my $sizeIllThreshold=0.01; # do not classify illustrations if size <
my $CSthreshold=0.1 ;   # confidence score threshold for using data classification

### comment the next line to classify everything ###
my $genreClassif="affiche dessin gravure photo photog"; # classify illustrations only if genre is equal to $genreClassif
#my $genreClassif="affiche bd carte dessin gravure graphique photo photog";

# IBM Watson
my $endPointWatson= "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/";
my $apiKeyWatson= "9f342fa2919764a43782be4c74b32af049836872";
# for Google Vision API : compte jpmoreux@gmail.fr
$endPointGoogle= "https://vision.googleapis.com/v1/images:annotate?key=";
$apiKeyGoogle= "AIzaSyD9zSaYk5nVubWTTZw_oLpVZ-GK4uXMXlE";

# for human faces detection
my $carreVSG=1 ;     # 1:1 format

# patterns for Watson API
my $motifClasseWatson = "\"class\": \"(.+)\"";       # "class": "beige color"
my $motifScoreWatson = "\"score\": (\\d+\.\\d+)";    # "score": 0.32198
# for Face Detection API
my $motifGenderWatson = "\"gender\": \"(.+)\"";    # "gender": "MALE",
#my $motifAgeMax = "\"max\": (\\d+)";    # "max": 54
my $motifAgeMinWatson = "\"min\": (\\d+)";    # "min": 44
my $motifHautWatson = "\"height\": (\\d+)";    # "height": 540
my $motifLargWatson = "\"width\": (\\d+)";    # "width": 640
my $motifXoWatson = "\"left\": (\\d+)";    # "left": 140
my $motifYoWatson = "\"top\": (\\d+)";    # "top": 140

# patterns for Google API
my $motifClasseGoogle = "\"description\": \"(.+)\"";
my $motifScoreGoogle = "\"score\": (\\d+\.\\d+)";
my $motifCoulRGoogle = "\"red\": (\\d+)";
my $motifCoulVGoogle = "\"green\": (\\d+)";
my $motifCoulBGoogle = "\"blue\": (\\d+)";
my $motifTexteGoogle = "\"description\": (.+)";
my $motifVerticesGoogle = "\"vertices\": \\[(.*?)\\]"; # non-greedy
my $motifCropYGoogle = "\"y\": (\\d+)";

######################
# for importation of external data (TensorFlow classification data or image hashing)
my $dataFile = "data.csv"; # input file name

# for TensorFlow : parameters
my $lookForAds=1 ;		# to be unset for OLR newspapers where ads are already recognized
my $TFthreshold=0.2; 	# threshold for confidence score
my $classesNumber;		# number of classes in the TensorFlow classification data
my $forceTFgenre=1; 		# force TF classifications on metadata classifications (in unify)
my @externalData; # data structure for import
my @listeDocs ;
my @listeClasses ;

# for image hashing and other stuff
%imageData = (); # hash table of file name/hash value  pairs

# for exportation of classes
my $OUTFile="classes.txt";
my $OUTfh;

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
print "-----------\ncolor table: $n values\n";

#getColorName("100","23","39");


#######################################################

#################
#  pattern for XML document analysis
# for ARK IDs
$motifArk = "\<ID\>(.+)\<\/ID\>" ;
# for illustrations
$motifIll = "<ill " ;
##################

# Gallica root IIIF URL
$urlIIIF = "http://gallica.bnf.fr/iiif/ark:/12148/";
$urlGallica = "http://gallica.bnf.fr/ark:/12148/";

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

# illustration ID currently analysed
my $idIll="1";

# output folder
my $OUT = "OUT_img";

# document type set on the command line: newspapers, monographs, img...
my $TYPE;


$msg = "\nUsage : perl toolbox.pl -service IN [-document type]
services :
-info: give some stats on the illustrations
-del : suppress the files with no illustrations
-nIDs : renumber the illustrations ID
-extr : extract the illustration files
-extrFiltered : extract the filtered illustrations files
-extrFace : extract the faces files
-extrGenre : extract the illustration files of a specific genre
-extrNotClassif: extract the illustration files not yet classified
-color: identify the color mode
-setColor : set the color mode
-setTheme : set the theme
-setGenre : set the genre
-fixType : set the document type from the illustration genre
-fixSource : set the classification source
-fixCBIRsource : set the CBIR source (IBM Watson, AWS, Google)
-fixCBIRClassif
-fixAd : set the ad attribute from article title (for OLR newspapers only)
-unify : compute the final classification (genre, filter, pub)
-unifyTheme : compute a theme
-CC : classify image content with an API
-DF : detect faces with an API
-OCR : extract texts with OCR
-importCC : import content classification data
-importDF : import face detection data
-extrCC : list the Watson classes
-delCC : suppress the content classification metadata
-delDF : suppress the face detection metadata
-delGenre : suppress the genre classifications
-delEmptyGenre : suppress the empty genre classifications
-delFilter : suppress the filtering attributes (genre, ad)
-importTF : process the TensorFlow data to classify the illustration genres
-TFunFilter : use the TensorFlow data to unfilter false positive filtered illustrations
-hash : import the hash data
-data: find data.bnf.fr links

IN : input files directory

document type: -p --> newspapers (to be used with the TF option)

	";



#say findDataBnf("bpt6k70861t","work");
#die;

####################################
####################################
##             MAIN               ##

say " *** CBIR mode: $classifCBIR ***";

if (scalar(@ARGV)<2)  {
	die $msg;
}

# list of subroutines
my %actions = ( del => \&del,
                info => "hd_info", # handler XML:Twig
                nIDs => "hd_updateID",
                extr => "hd_extract",
								extrFiltered => "hd_extractFiltered",
								extrGenre => "hd_extractGenre",
                extrNotClassif => "hd_extractNotClassif",
                extrFace => \&extrFace,
								fixFace => \&fixFace,
								color => "hd_color",
                setColor => "hd_updateColor",
                setTheme => "hd_updateTheme",
								setGenre => "hd_updateGenre",
								fixType => "hd_fixType",
								fixSource => "hd_fixSource",
								fixLeg => "hd_fixLeg",
								fixCBIRsource => "hd_fixCBIRsource",
								fixCBIRClassif => "hd_fixCBIRClassif",
								fixAd => "hd_fixAd",
								fixGenre => "hd_fixGenre",
								fixRot => "hd_fixRotation",
								unify => "hd_unify",
								unifyTheme => "hd_unifyTheme",
                delCC => "hd_deleteContent",
                delDF => "hd_deleteContent",
								delGenre => "hd_deleteGenre",
								delEmptyGenre => "hd_deleteEmptyGenre",
								delEmptyLeg => "hd_deleteEmptyLeg",
								delFilter => "hd_deleteFilter",
								CC => "hd_classifyCC",
								DF => "hd_classifyDF",
								OCR => "hd_OCR",
								importDF => "hd_importCC",
								importCC => "hd_importCC",
								extrCC => "hd_extrCC",
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
$TYPE=shift @ARGV;
if ($TYPE) {say "--- Document type: $TYPE"}

# classification type
switch ($SERVICE) {
 case "importCC" {$classifAction="CC"}
 case "importDF" {$classifAction="DF"}
 case "CC" {$classifAction="CC"}
 case "extrCC" {$classifAction="CC"}
 case "DF"  {$classifAction="DF"}
 case "delDF"  {$classifAction="DF"}
 case "delCC"  {$classifAction="CC"}
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
		mkdir ($OUT) || die ("###  Can't creat folder $OUT!  ###\n");
    say "Making folder $OUT...";
	}

##############
# output the classification data in a txt file for service extrCC
if ($SERVICE eq "extrCC") {
	say "Writing in $OUTFile";
	open($OUTfh, '>',$OUTFile) || die "### Can't write in $OUTFile file: $!\n";
}

################
# TensorFlow, hash or face detection case: we have to extract the classification data first (from a .csv file)
if ((index($SERVICE, "import") != -1) or ($SERVICE eq "hash")) {
	 say "Reading $dataFile...";
	 # building the data
	 open(DATA, $dataFile) || die "### Can't open $dataFile file: $!\n";
	 #seek $fhTF, 0, 0;
   my $nbData=0;
   while (<DATA>) {
   	 #say $_;
     $nbData += 1;
     push @externalData, [split /\t/]; # tokenize the data using TAB character
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

#isTFclassify("bpt6k6534085k");
#say isHashed("bpt6k65340845-93-2.jpg");
#die;

# image hasing and face detection
if (($SERVICE eq "hash") or ($SERVICE eq "importDF") or ($SERVICE eq "importCC")) {
   # building the hash list: file name \t hash value
   foreach (@externalData) {
     #say $_->[0] ;		#  illustration file name
     chop $_->[1];
     $imageData{$_->[0]} = $_->[1] ; #  value
     #say $_->[1];
    }
}

#say isFD("btv1b103365581-1-1");
#die

# reading the metadata documents
my $dir = dir($DOCS);
say "--- documents : ".$dir->children(no_hidden => 1);

#my $pm = new Parallel::ForkManager(4);

# recurse analysis of the folder
$dir->recurse(depthfirst => 1, callback => sub {
	my $obj = shift;

  if ((($SERVICE eq "CC") or ($SERVICE eq "DF")) and ($classifCBIR eq "ibm") and ($nbTotIll >= $processIllThreshold)) {
    say "## $processIllThreshold processed: stop ##";
    last
  }
	if ($obj->basename ne $DOCS)  { # jumper the current folder
	  if (($obj->is_dir) ){
		   say "\n dossier : ".$obj->basename;
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
say "$nbDoc documents analysed on ".$dir->children(no_hidden => 1);
if ($nbTot != 0) {say " $nbTot illustrations";}
if ($nbFailIll != 0) {say " $nbFailIll failed illustrations";}
if ($SERVICE eq "del") {
  say "$nbTotIll files deleted ";	}
elsif ($SERVICE eq "info") {
  say "$nbTotIll illustrations ";
	say "(including $nbTotFiltre filtered)";
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
	say " * $nbTotPub pub classifications";
  say " * $nbTotCC illustrations with $classifCBIR image content indexing";
  say " * $nbTotDF illustrations with $classifCBIR face detections";
}
else {
  say "$nbTotIll illustrations processed ";
  if ($nbTotDF!=0) {say "$nbTotDF faces processed"}
}

say "=============================";

if ($SERVICE eq "extrCC") {
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
   say "### $classesNumber classes ?! ###";
   die
}
else {
  say "-> $classesNumber classification classes found";
  say @listeClasses;}

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
# supprimer les fichiers de MD sans images decrites
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
sub extrFace {
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

  my $t = XML::Twig->new(
    twig_handlers => {
       '/analyseAlto/contenus/pages/page/ills/ill/contenuImg["face"]' => \&hd_extractFace, },
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


  # try the Stories query
  my $databnf = findDataBnf($idArk,"studie");
	# try the Works query
  if (not defined $databnf) {
		$databnf = findDataBnf($idArk,"work");
	  }

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

say "looking for $req...";

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
else {
  say "#### Query $req undefined!";
	return undef}

my $sparql = sparql->new();
my $res = $sparql->query($endPointData,$query);
if (defined $res) {
	#say " Response: ".$res;
	my @rows = split(/\s+/, $res); # split on separators
	if ($req eq "work")
	  {shift @rows; # discard the header, which has 3 lines
	   shift @rows;
	  shift @rows;}
	else {shift @rows} # one line
	#say Dumper (@rows);
	if (@rows)  {
	 while (my $row = shift @rows) {
	   #my $row = shift @rows;  # take the first line
 		 #my @urls = split("\"", $row); #the line can contains multiple URLs
 		 @tmp = grep(/$req/i, $row); # find an URL with the keyword
		 if (@tmp)
		   {#say "--> hit";
	       last}
		}

	  if (@tmp) {
			$tmp[0] =~ s/"//g; # suppress the ""
			return $tmp[0]}
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
sub hd_extrCC {
   my ($t, $elt) = @_;
   my $tmp;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nbTotIll++;
    my $classif = $ill->att("classif"); # classif attribute
    if ((defined $classif) and (index($classif, $classifAction.$classifCBIR)!=-1)) { # we have CC classification
		  # the  classification elements
		  #my @contenus= $ill->children( 'contenuImg');
			say "...looking for $classifAction$classifCBIR tags";
			my $nav = "contenuImg[\@source='".$classifCBIR."']";
			my @contenus= $ill->children($nav);
			say "nbre de MD CC : ".scalar(@contenus);
			foreach my $contenu (@contenus) {
      	print $OUTfh $contenu->text()."\n";
			}
    }
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
     	   say "..content: ".$ct;
         if (index($cTag,"DF") != -1) {  # face detection case
           if ($ct eq "face" ) {
             print " - ";
             $contenu->delete;}
         }
         else {  # content classification case
          if ($ct ne "face" ) {
            print " - ";
            $contenu->delete;}
         }
      }
    }
    else {print " no $cTag classification"}
   }
}

#


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
     foreach my $genre (@genres) {
			my $source = $genre->att("source");
      if ((not $genre->text()) or ($genre->text() eq "") or ((defined $source) and ($source eq $classifSource))) {
       	  print " -$classifSource ";
					$nbTotIll++;
          $genre->delete;}
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

sub hd_deleteEmptyLeg {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
     $nill = $ill->att('n');
     print "\n$nill: ";

     # suppress the empty elements and the short ones
     my @legs= $ill->children('txt');
     foreach my $leg (@legs) {
      if ((not $leg->text()) or (length($leg->text()) < 4)) {
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


# set a data.bnf.fr URL attribute
sub hd_data {
    my ($t, $elt, $url) = @_;

    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			if (not $ill->att('filtre')) {	 # do not compute filtered illustrations
			  print " +";
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
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
      $nbTot+=1;
    	$nill = $ill->att('n');
    	my $filtre = $ill->att('filtre');
			my $pub = $ill->att('pub');
    	if ((not $filtre) ) {	   # do not export filtered illustrations
				IIIF_get($ill,$idArk,$nill,$page)}
    	else { say " $nill : filtered  illustration "}
   }
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
				say " genre : $genre";
				IIIF_get($ill,$idArk,$nill,$page)}
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
				IIIF_get($ill,$idArk,$nill,$page)}
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
    	$filtre = $ill->att('filtremd');
    	if ($filtre) {	   # export filtered illustrations
				IIIF_get($ill,$idArk,$nill,$page)}
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
  my $url;
  #say "l : ".$w;
	#say "h : ".$h;
  # handle the rotation
	my $rotation = $ill->att('rotation');
	$rotation ||= "0";
	#handle the image size
	if ($modeIIIF eq "linear")  {
    $redim = "/pct:$factIIIF"
  }
 else { # avoid too small images
   if (($w < $reDimThreshold) or ($h < $reDimThreshold)) {
		$redim = "/full"}
	 else {
		$redim = "/pct:$factIIIF";
	  }
  }
	switch ($mode) {
	 case "ocr" { # expand the illustration to get some text around
		my $deltaW = $w*0.1; # enlarge a little bit horizontaly
		my $deltaH = $h*$expandIIIF;
		my $x = $ill->att('x')-$deltaW/2;
		if ($x<=0) {$x=0};
		my $y = $ill->att('y')-$deltaH/4; # expand 1/4 above the illustration
		if ($y<=0) {$y=0};
		$url = $idArk."/f$page/".$x.",".$y.",".($w+$deltaW).",".($h+$deltaH).$redim."/$rotation/native.jpg";
	}
	case "zoom" {
		my $deltaW = $w*$expandIIIF; # reduce
		my $deltaH = $h*$expandIIIF;
		my $x = $ill->att('x')+$deltaW/2;
		my $y = $ill->att('y')+$deltaH/2;
		$url = $idArk."/f$page/".$x.",".$y.",".($w-$deltaW).",".($h-$deltaH).$redim."/$rotation/native.jpg";
	}
	else {
		$url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$w.",".$h.$redim."/$rotation/native.jpg";
	}
 }
	say " --> ".$url;
	return $url;
}

# extract a IIIF file in /tmp/
sub IIIF_get {my $ill=shift;
							my $idArk=shift;
	            my $nill=shift;
							my $page=shift;

		my $tmp = "$OUT/$idArk-$nill.jpg";
		if (-e $tmp) {say "$tmp already exists!"}
		else {
      my $url = setIIIFURL($ill,$page,"std");
			say "$nill --> ".$url;
			$nbTotIll+= IIIF_extract($url,$tmp)
		}
}

## extract an illustration file with the IIIF API
sub IIIF_extract {my $url=shift;
	                my $fic=shift;

       unlink $fic;
       getstore($urlIIIF.$url, $fic);
	     if (-e $fic) {
         return 1;}
       else {
		     say "### IIIF : $urlIIIF$url \n can't extract! ###";
         $nbFailIll+= 1;
		     return 0;
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
 my $classif = $ill->att('classif');
 #if ((defined $classif) && (index($classif, $classifAction." ") != -1)) {
 if ((defined $classif) && (index($classif, $classifAction.$classifCBIR) != -1)) {   # do not classify twice
		say "$nill -> already $classifAction$classifCBIR classified!";
		#say "$nill -> already $classifAction classified!";
		return 0}
 #my $size = $ill->att('taille');
 #if ($size < $sizeIllThreshold) {
	#			say "$nill  -> illustration is too small! (size=$size)"; # do not classify small ill.
	#			return 0}
 if (defined $genreClassif) { # a filter on genres exists
   my $genre = getGenre($ill);
   if (not $genre) {
     say "$nill  -> illustration has no genre: classify anyway";
     return 1}
   if (index($genreClassif,$genre) ==-1) {
			say "$nill  -> illustration is not a $genreClassif!"; # classify only a specific genre
			return 0}
	 else {return 2}
  }
	else
   {return 1} # classify whatever the genre is
}


sub OCRReady {my $ill=shift;

 my $nill = $ill->att('n');
 my $filtre = $ill->att('filtre');
 if (defined $filtre) {	# do not classify the filtered illustrations
 	 say "$nill -> filtered";
 	 return 0}

 my $genre = getGenre($ill);
 if (not $genre) {
     say "$nill  -> illustration has no genre";
     return 0}
 if (index($genreClassif,$genre) ==-1) {
		 	 say "$nill  -> illustration is not a $genreClassif!"; # classify only a specific genre
		 	 return 0}

 #my @titraille = $ill->children('titraille');
 my @leg = $ill->children('leg');
 my @txt = $ill->children('txt');
 if ((not @leg) and (not @txt)) {
	return 1
 }
 else {
	 say "$nill  -> illustration has some text!";
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
    say " page: $page";
		# get the pages number
		my $tmp = $elt->parent->parent->parent->parent;
		my $pages = $tmp->get_xpath('metad/nbPage', 0);
		#say $pages->text();

	  #if ($pages->text()	<= 1) {  # only ocr multipage documents (monog, series)
	 	# say " ### pages=1 ###";
	 	# return 0}

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			if (OCRReady($ill)) {
    	 # tmp image file
       my $iiifFile = "$OUT/$idArk-$nill.jpg";
			 my $url = setIIIFURL($ill,$page,"ocr");
	     # call the APIs
			$res = callGoogleOCR($url);

			if ($res and ($res ne "")) { # API call succeed
					$nbTotIll++;
					#updateClassif($ill);
					$res =~ s/\\n/ - /g; # suppress the \n
					if (length($res) > 50) {
						say "\n OCR -> ".substr($res,50);
					} else {say "\n OCR -> ".$res;}
					 # write the new metadata in the XML
          $ill->insert_new_elt('txt', $res)->set_atts("source"=>"google");
					}
			else {
					say " ** no OCR output **"
					}
	     }
   } #for
}

## call the content classification API
sub hd_classifyCC {
    my ($t, $elt) = @_;

		my @res;
		my $nbClasses=0;
		my $fact = (100.0/$factIIIF)*0.95; # ratio to set the dimensions in the original image space

    my $page = $elt->parent->att('ordre');
    say "#####\n page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			if (classifyReady($ill)) {
    	 # tmp image file
       my $iiifFile = "$OUT/$idArk-$nill.jpg";

	     # call the APIs
			switch ($classifCBIR)  {
	 				case "ibm"			{
						my $url = setIIIFURL($ill,$page,"std");
						if (IIIF_extract($url,$iiifFile)) {  # extract the file locally
						   @res = callWatsonCC($iiifFile);}
						 }
					case "google"		{
						my $url = setIIIFURL($ill,$page,"zoom");
						@res = callGoogleCC($url);}
          else { say "## unknown CBIR mode: $classifCBIR ##"}
				 }

			if (scalar(@res)>1) { # API call succeed
					$nbTotIll++;
					updateClassif($ill);
					say Dumper @res;

					#my $tmp = scalar(@res)/2; # list of classes + list of scores
					#foreach my $i  (0..int($tmp)-1) { # look
					#	say $res[$i];
						#if (isAlpha($res[$i])) {
						 # $nbClasses++;}
					#}
					my $nbClasses = $res[0];
					say "--> $nbClasses classes";
					if ($classifCBIR eq "google") { # we have a cropping and we associate it with the first tags (assumption...)
					 my $deltaW = $ill->att('w')*$expandIIIF; # to accommodate the zoom -> see setIIIFURL()
					 my $deltaH = $ill->att('h')*$expandIIIF;
					 my $x = int($res[1+$nbClasses]*$fact)+$deltaW;
					 my $y = int($res[1+$nbClasses+1]*$fact)+$deltaH;
					 my $l = int($res[1+$nbClasses+2]*$fact);
					 my $h = int($res[1+$nbClasses+3]*$fact);
           foreach my $i  (1..$nbClasses) {
						 my $label = $res[$i];
						 my $CS = $res[$i+$nbClasses+4] || 1; # float number pattern : to be fixed!
						 if ($i<=3) {
							say "  $i ... crop on tag $label ($CS)";
							$ill->insert_new_elt('contenuImg', $label)->set_atts("x"=>$x,"y"=>$y,"l"=>$l,"h"=>$h,"CS"=>$CS, "source"=>$classifCBIR);
					 	 } else {
							say "  $i : $label ($CS)";
							$ill->insert_new_elt('contenuImg', $label)->set_atts("CS"=>$CS, "source"=>$classifCBIR)
						}
					}
					 }  # other CBIR source with no cropping
						else {
						 foreach my $i  (1..$nbClasses) {
							my $label = $res[$i];
							my $CS = $res[$i+$nbClasses] || 1; # the float number pattern must be fixed!
							say "  $i : $label ($CS)";
              $ill->insert_new_elt('contenuImg', $label)->set_atts("CS"=>$CS, "source"=>$classifCBIR);}
						}
					}
	     }
 } #for
}


# call the Watson API and return the list of classes followed by the confidence scores
sub callWatsonCC {my $ill=shift;

	my @classes;
	my @scores;

	my $cmd=  "curl -X POST -F \"images_file=@".$ill."\" \"".$endPointWatson."classify?api_key=$apiKeyWatson&version=2016-05-20\"";
	#say "cmd : ".$cmd;
	my $res = `$cmd`;
	say "res : ".$res;
	if ($res and (index($res, "ERROR") == -1))   {
	 	(@classes) = do { local $/; $res =~ m/$motifClasseWatson/g };
	 	(@scores) = do { local $/; $res =~ m/$motifScoreWatson/g };
		#say Dumper @classes;
		return (scalar(@classes),@classes,@scores);
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
	 }
}

sub writeGoogleJSON {my $img=shift;
										 my $JSONfile=shift;
										 my $mode=shift;

		my $OUT;

open($OUT, '>',$JSONfile) || die "### Can't write in $JSONfile file: $!\n";
print $OUT "{
\"requests\": [
	{
		\"image\": {
		\"source\": {
				\"imageUri\": \"$img\"
			}
	 },
		\"features\": [";
	switch ($mode) {
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

sub callGoogleCC {my $url=shift;

	my @classes;
	my @scores;
	my @couleurs;
  my $res;
  my $json = "/tmp/request.json";

  say $urlIIIF.$url;
	say "Writing in $json";
	writeGoogleJSON($urlIIIF.$url, $json, "CC");

	my $cmd=  "curl -v -s -H \"Content-Type: application/json\" $endPointGoogle$apiKeyGoogle --data-binary \@$json";
	say "cmd : ".$cmd;
	$res = `$cmd`;
	#say "res : ".$res;
	if ($res and (index($res, "error") == -1))   {
		(@classes) = do { local $/; $res =~ m/$motifClasseGoogle/g };
	 	(@scores) = do { local $/; $res =~ m/$motifScoreGoogle/g };
		($coulR) = do { local $/; $res =~ m/$motifCoulRGoogle/ };
		($coulV) = do { local $/; $res =~ m/$motifCoulVGoogle/ };
		($coulB) = do { local $/; $res =~ m/$motifCoulBGoogle/ };
		($vertices) = do { local $/; $res =~ m/$motifVerticesGoogle/s };

		#($cropy) = do { local $/; $res =~ m/$motifCropYGoogle/ };
		my @crop = decodeVertices("{\"vertices\": [".$vertices."]}");
		#say Dumper (@crop);
		say " dominante color : R : $coulR / G: $coulV / B: $coulB";
		my $couleur = getColorName($coulR,$coulV,$coulB);
		if ($couleur) {
			#say "... $couleur";
			return (scalar(@classes)+1,@classes,$couleur,@crop,@scores)}
			else {return (scalar(@classes),@classes,@crop,@scores)}
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
	 }
}

sub decodeVertices {my $str=shift;

	my $x0 = 10;
	my $y0 = 10;
	my $width;
	my $height;

	#say $str;
	my $decoded = decode_json($str);
	#print  Dumper($str);

	my @vertices = @{ $decoded->{'vertices'} };
	#foreach my $v ( @vertices ) {
	#	my $x = $v->{"x"} || 0;
	#	my $y = $v->{"y"} || 0;
	if (defined $vertices[0]->{"x"})  {
  	 $x0 = $vertices[0]->{"x"}}
	if (defined $vertices[0]->{"y"})  {
	   $y0 = $vertices[0]->{"y"}}
	if (defined $vertices[1]->{"x"})  {
	 	  $width = $vertices[1]->{"x"} - $x0}
	if (defined $vertices[2]->{"y"})  {
		 	$height = $vertices[2]->{"y"} - $y0}
	return ($x0,$y0,$width,$height)
}

sub callGoogleOCR {my $url=shift;

	my @classes;
  my $res;
  my $json = "/tmp/request.json";

  say $urlIIIF.$url;
	say "Writing in $json";
	writeGoogleJSON($urlIIIF.$url, $json, "OCR");

	my $cmd=  "curl -v -s -H \"Content-Type: application/json\" $endPointGoogle$apiKeyGoogle --data-binary \@$json";
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

## call the face detection API
sub hd_classifyDF {
    my ($t, $elt) = @_;

    my $redim;
    my $rotation;
		my $fact = 100.0/$factIIIF; # ratio to set the dimensions in the original image space
    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my $classify = classifyReady($ill);
			if ($classify) {
       $nill = $ill->att('n');
    	 # tmp image file
       my $iiifFile = "$OUT/$idArk-$nill.jpg";
			 my $url = setIIIFURL($ill,$page,"std");
       if (IIIF_extract($url,$iiifFile)) {
				 # call the APIs
				 switch ($classifCBIR)  {
	 				case "ibm"			{@res = callWatsonDF($iiifFile);}
					case "google"		{@res = callGoogleDF($iiifFile);}
				 }
				 if (@res) { # the API call succeed
					$nbTotIll++;
					updateClassif($ill);
					if ($res[0]) { # the API returned some results
						# write the new metadata in the XML
						#say Dumper (@res);
						$nbVisages = int ((scalar(@res)/8)+0.5); # @res is a list of 8 array values
						say " ** number of faces: $nbVisages";
            foreach my $i  (0..$nbVisages-1) {
							my $score = $res[$i*2+$nbVisages+1]; # two scores, for age and gender
							if ($score >= $CSthreshold) {
								if ($res[$i] eq "MALE") {$sexe="M";}
								else {$sexe = "F";}
								}
							else 	{$sexe = "P";# gender unknown
										 $score=1}
						  say " -> $sexe ($score)";
							my $age = $res[$i+$nbVisages*7]*1.2;  # the API returns age_min
							#if ((defined $ageMin) and (defined $ageMax))
							#       {$age = ($ageMin + $ageMax)/2}
							say " -> age : $age";
							#if ($age) {
							$ill->insert_new_elt( 'contenuImg', "face" )->set_atts("sexe"=>$sexe,"CS"=>$score,"age"=>$age,"source"=>$classifCBIR,
										 "x"=>int($res[$i+$nbVisages*3]*$fact),"y"=>int($res[$i+$nbVisages*4]*$fact),"l"=>int($res[$i+$nbVisages*5]*$fact), "h"=>int($res[$i+$nbVisages*6]*$fact));}
							#else  {
							#  $ill->insert_new_elt( 'contenuImg', "face" )->set_atts("sexe"=>$sexe,"CS"=>$score,"source"=>$classifCBIR,
								#		 "x"=>int($res[$i*9+3]*$fact),"y"=>int($res[$i*9+4]*$fact),"l"=>int($res[$i*9+5]*$fact), "h"=>int($res[$i*9+6]*$fact));}
							}
	     }
		 }
	 }
  } #for
}

# call the Watson API on a file
# return: the list of classes followed by the confidence scores
sub callWatsonDF {my $ill=shift;

	my @classes;
	my @scores;

	my $cmd=  "curl -X POST -F \"images_file=@".$ill."\" \"".$endPointWatson."detect_faces?api_key=$apiKeyWatson&version=2016-05-20\"";
	#say "cmd : ".$cmd;
	my $res = `$cmd`;
	say "res : ".$res;

	if ($res and (index($res, "ERROR") == -1))   {
		(@genders) = do { local $/; $res =~ m/$motifGenderWatson/g };
		(@scores) = do { local $/; $res =~ m/$motifScoreWatson/g };
		(@agesMin) = do { local $/; $res =~ m/$motifAgeMinWatson/g };
		#(@agesMax) = do { local $/; $res =~ m/$motifAgeMax/g };
		(@Xo) = do { local $/; $res =~ m/$motifXoWatson/g };
		(@Yo) = do { local $/; $res =~ m/$motifYoWatson/g };
		(@Larg) = do { local $/; $res =~ m/$motifLargWatson/g };
		(@Haut) = do { local $/; $res =~ m/$motifHautWatson/g };
		if (@genders) {
		  return (@genders,@scores,@Xo,@Yo,@Larg,@Haut,@agesMin);}
		else {return (-1)}
	}
	else {
	 	say " ### API error: ".$res;
	 	return undef
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

 # ---------------------- Face Detection importation -------------------
 # Say if an illustration is listed in the data
 sub isFD {
 	my $nomFic=shift;

 	say "--> isFD $nomFic?";
     my $tmp=$imageData{$nomFic};
     if ($tmp) {
       #say Dumper (@faces);
     	return $tmp;
     }
     else {
       say "### $nomFic not in the data! ###\n";
       return undef}
 }

 # import the classification data (e.g. from OpenCV/dnn)
 sub hd_importCC {
     my ($t, $elt) = @_;

     my $fact = 100.0/$factIIIF; # ratio to set the dimensions in the original image space
     my @ills = $elt->children('ill');

     for my $ill (@ills) {
      $nill = $ill->att("n");
      say "\nn : $nill";
      $nill = "$idArk-$nill";
			# do we have some data?
			my $res = isFD($nill);
     	if ($res) {
      # do we need to classify?
			my $classify = classifyReady($ill);
      if ($classify) {
			   my $threshold = ($classify==1) ? $CSthreshold*2 :	$CSthreshold; # increase the threshold for difficult cases
				 say " threshold: ".$threshold;
         $nbTotIll++;
         updateClassif($ill);
         my @data = split(/\ +/, $res); # split on space character
         for my $d (@data) {
     	     say " data: $d"; # returns label,x,y,w,h,confidence score
            my @md = split(/\,+/, $d);
            my $score =$md[5];
            if ($score >= $threshold) {
              $nbTotDF++;
							switch ($SERVICE)  {
								# face detection
								case "importDF" {
              	$ill->insert_new_elt('contenuImg', $md[0])->set_atts("sexe"=>"P","CS"=>$score,"source"=>$classifCBIR,
 						 "x"=>int($md[1]*$fact),"y"=>int($md[2]*$fact),"l"=>int($md[3]*$fact), "h"=>int($md[4]*$fact));}
						 	  # generic case
								case "importCC" {
								my $label = $md[0];
								if ($label eq "tvmonitor")  {
									say " ## don't import 'tvmonitor' label";
									return;}
							  if (index("car cow bird dog horse sheep",$label) !=-1) {
									say " # +animal";
							    $ill->insert_new_elt('contenuImg',"animal")->set_atts("CS"=>$score,"source"=>$classifCBIR);
								}

              	$ill->insert_new_elt('contenuImg', $label)->set_atts("CS"=>$score,"source"=>$classifCBIR,
 						 "x"=>int($md[1]*$fact),"y"=>int($md[2]*$fact),"l"=>int($md[3]*$fact), "h"=>int($md[4]*$fact));
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

## extract the faces as image files
sub hd_extractFace {
    my ($t, $elt) = @_;

   if ($elt->text() eq "face") {
     say "Face : ".$elt->att('age')." ans - sexe : ".$elt->att('sexe');
     my $ill = $elt->parent;
     my $page = $ill->parent->parent->att('ordre');
     say " page: $page";
     my $tmp = "$OUT/$idArk-$page-".$ill->att('n').".jpg";
	   unlink $tmp;

	 # handle rotation
	 $rotation = $elt->parent->att('rotation');
	 $rotation ||= "0";

	 # dimensions
	 my $largVSG = $elt->att('l');
	 my $hautVSG = $elt->att('h');

	 # 1:1 format?
	 if ($carreVSG==1) {
	 	if ( $largVSG >= $hautVSG) {  # we take the largest dimension
	     $deltaL = $largVSG*$expandIIIF;
			 $deltaH= $deltaL; # delta: to crop larger than the face
	     $hautVSG = $largVSG;
	      }
	 	else  {
	 		$deltaH = $hautVSG*$expandIIIF; $deltaL= $deltaH;
	 		$largVSG = $hautVSG;}
	 } else {
	 	  $deltaL = $largVSG*$expandIIIF;
	 	  $deltaH = $hautVSG*$expandIIIF;
	}

	 say " L :".$deltaL	;say " H :".$deltaH	;

	 my $url = $urlIIIF.$idArk."/f$page/".($ill->att('x')+$elt->att('x')-$deltaL/2).",".($ill->att('y')+$elt->att('y')-$deltaH/2).","
	 .($largVSG+$deltaL).",".($hautVSG+$deltaH)."/pct:$factIIIF/$rotation/native.jpg";
	 say "--> ".$url;
     getstore($url, $tmp);
	 if (-e $tmp) {
       $nbTotIll++;}
     else {
		 say "### IIIF : $url \n can't extract! ###";
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
		if (($ill->att('w') < $reDimThreshold) or ($ill->att('h') < $reDimThreshold)) {
			$redim = "/full"}
		 else {
			$redim = "/pct:$factIIIF";
		}
		my $url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$ill->att('w').",".$ill->att('h').$redim."/$rotation/native.jpg";
		say "$nill --> ".$url;
		if (IIIF_extract($url,$ficImg)) {
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
    	$ill->set_att("couleur",$couleur);
    	$nbTotIll++;
    }
}

# reset a specific genre (from a specific source)
sub hd_updateGenre {
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
    		 $ill->insert_new_elt("genre","$illGenreNew")->set_atts("source"=>$classifSource);
				 print " +";
				 $nbTotIll++;
			}
    }
  }
}

sub hd_fixGenre {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my @genres = $ill->children('genre');
    	if (not @genres) {
    		 $ill->insert_new_elt("genre","$illGenreNew")->set_atts("source"=>$classifSource);
				 print " +";
				 $nbTotIll++;
			}
    }
}

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
# unify option needs to be ran after fixSource
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
sub hd_fixAd {
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

# get the genre
sub getGenre {
    my $ill=shift;

    #say "\n n : ".$ill->att('n');
	 if ($ill->children('genre')) {
		 my $genreFinal = $ill->get_xpath('./genre[@source="final"]', 0);
     #say $genreFinal->text();
		 if ($genreFinal) {
			 return $genreFinal->text();
		 }
   }
  return undef
}

# set the final genre and the filters
sub setFinal {
	my $ill=shift;
	my $mode=shift;  # "hm"/"md"/"tf"
  my $genre=shift;

	say " -> $mode: $genre";
	$ill->insert_new_elt("genre",$genre)->set_atts("source"=>"final");
	# ad case?
	if (index($genre,"publicit")!=-1) {
		$ill->set_att("pub",1)}
	# filter case?
	my $filtre = "filtre".$mode;
	if (index($genre,"filtre") !=-1){
				$ill->set_att($filtre,1);
				$ill->set_att("filtre",1)}
}

# unify the genre in the <genre source=final> element
sub hd_unify {
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
			 if ($ill->children('genre')) {
				@genreFinal = $ill->get_xpath('./genre[@source="final"]');
				if (@genreFinal) {  # Reset
				  for my $g ( @genreFinal ) {
				   $g->delete()}
				 }
				$genreMD = $ill->first_child_text('genre[@source="md"]');
				$genreTF = $ill->first_child_text('genre[@source="TensorFlow"]');
				$genreHM = $ill->first_child_text('genre[@source="hm"]');

				# process the results
				if ($genreHM) { # top priority
				  $final = $genreHM;
					setFinal($ill,"hm",$final)

				} # priority on metatada except if TF is forced
				elsif ($genreMD and ($genreMD ne "inconnu") and ($genreMD ne "")
				    and ((not $forceTFgenre) or ($forceTFgenre and not $genreTF)))  {
					$final = $genreMD;
					setFinal($ill,"md",$final);
					# special case: text ads must be filtered
 					if (($genreMD eq "publicite") and ($genreTF eq "filtretxt")) {
						say " -> tf : filtretxt";
						$ill->set_att("filtretf",1);
						$ill->set_att("filtre",1)
					}
				} # use TF classification
				elsif (defined $genreTF) {
					$final = $genreTF;
					setFinal($ill,"tf",$final)
				}
			}
			if (not defined $final)
				 {say "** no final genre **"}
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

# delete filter attributes that are built automatically generated
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

# reset the document type from a genre classification
sub hd_fixType {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $tmp = $ill->first_child('genre');
    	if ((defined $tmp) and ($tmp->text() eq $illGenreOld)) {
				$nbTotIll++;
				# suppress the genre
				# $tmp->delete; # non, on garde pour la facette GENRE
				# suppress the type
				my $meta = $elt->parent->parent->parent->parent->first_child;
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

# set the image genre from TensorFlow classification data
sub hd_TFfilter {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $nill = $ill->att("n");
			my $page = $elt->parent->att('ordre');
    	$nill = "$idArk-$nill";

    	if (($TYPE) and ($TYPE="-p"))
			 {@genreIll = isTFclassify_news($nill,$page);}
			 else {@genreIll = isTFclassify($nill);}
			#say Dumper @genreIll;
			my $genre = $genreIll[0];
    	if ($genre ne "-1") {
				my $CS = $genreIll[1];
    	  say " illustration genre: $genre (CS: $CS)";
    	  $ill->insert_new_elt('genre', $genre)->set_atts("CS"=>$CS,"source"=>"TensorFlow");
    	  $nbTotIll++;
    	}
    }
}

# try to detect some false positive filtered illustrations (MD) thanks to the TensorFlow classification data
# aims a specific genre set by $illGenreNew
sub hd_TFunFilter {
    my ($t, $elt) = @_;

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $nill = $ill->att("n");
			say $nill;
			my $page = $elt->parent->att('ordre');
    	$nill = "$idArk-$nill";
			my $genre = $ill->get_xpath('./genre[@source="final"]', 0); # the final genre
			my $genreMD = $ill->get_xpath('./genre[@source="md"]', 0); # the MD genre
			if (($genre) and ($genreMD)) {
			 print " genre: ".$genre->text()."\n";
			 if ((index($genre->text(),"filtre") == -1) and ($genreMD->text() ne "filtre")) {
				say "...not a filtered MD genre!";}
			 else {
			 @genreIll = isTFclassify($nill);
			 $genre = $genreIll[0];
    	 if ($genre ne "-1") {
			  if ($genre eq $illGenreNew) {
					my $CS = $genreIll[1];
    	  	say "... unfilter illustration with genre: $genre (CS: $CS)";
    	  	$ill->insert_new_elt('genre', $genre)->set_atts("CS"=>$CS,"source"=>"TensorFlow");
					# delete the filter information
					my $genreMD = $ill->get_xpath('./genre[@source="md"]', 0);
					say " ... deleting genre".$genreMD->text();
					$genreMD->delete();
    	  	$nbTotIll++; }
					else {say " the TF genre is not a $illGenreNew: can't be unfiltered"}
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
	my $nomFic=shift;
	my $page=shift;

  my $top1CS=0;
	my $top2CS=0;

	say "TensorFlow newspapers: $nomFic (page : $page)";

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
		my $genre = $listeClasses[$indiceClasse1];
		switch ($genre) {
				case "filtreornement"		{ # difficult classes: higher confidence score
					# if the confidence score is > threshold
		  		if ($top1CS > $TFthreshold*1.2) {
		     		return ($genre,$top1CS);
					  say " $top1CS CS for '$genre' is < $TFthreshold*1.2 threshold!";}
	 	    }
				case "publicite"		{
					say "ad...";
		  	 if  ($lookForAds) {
					if (($page != 1) # can't be an ad on cover page (assumption...)
						and ($top1CS > $TFthreshold*1.1)) # if the confidence score is > threshold
						{return ($genre,$top1CS);}
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
						return ($genre,$top1CS);}
					else {say " $top1CS CS for '$genre' is < $TFthreshold threshold!";}
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
	my $nomFic=shift;

  my $tmpCS=0;

	say "TensorFlow: ".$nomFic;

	#to do : use a hash
	foreach my $i  (0..scalar(@listeDocs)-1) {
	 if (index($listeDocs[$i],$nomFic) != -1) { # the illustration name is in the TensorFlow data
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
		my $genre = $listeClasses[$indiceClasse];
		if ($tmpCS > $TFthreshold) {		# if the confidence score is > threshold
		     say " TF genre: $genre";
		     return ($genre,$tmpCS);} # return the class  and its confidence value
	 	else {
	 	 		say " $tmpCS CS for '$genre' is < $TFthreshold threshold!";
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

	say "isHashed $nomFic?";
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
				$ill->set_att("hash"=>"");
				say "#### illustration hash is missing: $nill";
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

 say ".. looking for $r $v $b";
 my $proche = $imgFoo->colorClosest($r,$v,$b); # GD function
 if  ($proche != -1) {
 	my @tmp = $imgFoo->rgb($proche);
 	print " -> rgb: $tmp[0] $tmp[1] $tmp[2]\n"; # RGB values

  my $color = rgb2hex($tmp[0],$tmp[1],$tmp[2]); # Hex value
  print " -> hex: $color\n";

  while( my ($k,$v) = each(%COLORS) ) {
  #print $v."\n";
   if ($v eq $color) {
   	print "hit : $k\n";
	 	return $k;
   	last}
  }
 return undef
 }
}

# ----------------------
# not used anymore #
# changer le filtre
sub TFfilter {
	my $fic=shift;
	my $nomFic=shift;

	say "*********************************\nfichier : ".$fic;

  #si le document a ete traite par TF
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
