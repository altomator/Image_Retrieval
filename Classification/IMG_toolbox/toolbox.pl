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

binmode(STDOUT, ":utf8");

############  Parameters  ###########################
my $couleur="gris"; # default color mode (to be set if using the -color option): mono, gris, coul
my $theme="16";     # default IPTC theme (to be set if using the -theme option)
my $documentType="C";   # document type to be fixed with the -fixType option : PA = music score, C = map
my $illGenre="carte";   # illustration genre to be looked for with the -fixType option
my $illGenreSource="md"; # illustration genre source to be fixed with the -fixGenre option

my $facteurIIIF = 50;   # size factor for IIIF image exportation (%)
my $factTtIIIF = 30;   # size factor for Watson image treatment (%)
my $seuilReDim = 500;  # threshold under which the output factor is not applied

# for Watson API
$apikey= "913e0225c1111607c33114df7e09242dfef63c8d";
# for human faces detection
my $facteurVSG=0.5 ; # size factor
my $carreVSG=1 ;     # 1:1 format

# patterns for Watson API
my $motifClasse = "\"class\": \"(.+)\"";       # "class": "beige color"
my $motifScore = "\"score\": (\\d+\.\\d+)";    # "score": 0.32198
# for Face Detection API
my $motifGender = "\"gender\": \"(.+)\"";    # "gender": "MALE",
my $motifAgeMax = "\"max\": (\\d+)";    # "max": 54
my $motifAgeMin = "\"min\": (\\d+)";    # "min": 44
my $motifHaut = "\"height\": (\\d+)";    # "height": 540
my $motifLarg = "\"width\": (\\d+)";    # "width": 640
my $motifXo = "\"left\": (\\d+)";    # "left": 140
my $motifYo = "\"top\": (\\d+)";    # "top": 140

# for TensorFlow : parameters to set
my $TF = "results.csv"; # input file name of TensorFlow classification data
my $seuilTF=0.40; 			# threshold for confidence score
my $classesNumber=7;		# number of classes in the TensorFlow classification data
my @TFdata;
my @listeDocs ;
my @listeClasses ;


#######################################################


#############
#  pattern for XML document analysis
$motifArk = "\<ID\>(.+)\<\/ID\>" ;
#  pattern for illustrations
$motifIll = "<ill " ;


# URL IIIF
$urlIIIF = "http://gallica.bnf.fr/iiif/ark:/12148/";


##################
# ID ark
my $idArk;
# number of documents analysed
my $nbDoc=0;
# number of illustrations
my $nbTotIll=0;
my $nbTotFiltre=0;
my $nbTotCC=0;
my $nbTotDF=0;
my $nbTotCol=0;
my $nbTotThem=0;
my $nbTotGenTF=0;
my $nbTotGenMD=0;
my $nbTotGenInconnu=0;

# illustration ID currently analysed
my $idIll="1";

# output folder
my $OUT = "OUT_img";



$msg = "\nUsage : perl traiterIMGs.pl -service IN
services :
-info: give some stats on the illustrations
-del : suppress the files with no illustrations
-nIDs : renumber the illustrations ID
-extr : extract the illustration files
-extrFace : extract the faces files
-color: identify the color mode
-setColor : set the color mode
-setTheme : set the theme
-fixType : set the document type from the illustration genre
-fixGenre : set the illustration genre source
-unifyGenre :
-CC : classify image content with Watson API
-DF : detect faces with Watson API
-extrCC : list the Watson classes
-delCC : suppress the content classification metadata (Watson)
-delDF : suppress the face detection metadata (Watson)
-TF : filtrer d'après TensorFlow

IN : dossier des documents a traiter
	";


####################################
####################################
##             MAIN               ##

if (scalar(@ARGV)<2)  {
	die $msg;
}

my %actions = ( del => \&del,
                info => "hd_info", # handler XML:Twig
                nIDs => "hd_updateID", # handler XML:Twig
                extr => "hd_extract",  	 # handler XML:Twig
                extrFace => \&extrFace,
								color => "hd_color",
                setColor => "hd_updateColor",  # handler XML:Twig
                setTheme => "hd_updateTheme",
								fixType => "hd_fixType",
								fixGenre => "hd_fixGenre",
								unifyGenre => "hd_unifyGenre",
                delCC => "hd_deleteCC",
                delDF => "hd_deleteDF",
								CC => "hd_classifyCC",
								DF => "hd_classifyDF",
								extrCC => "hd_extrCC",
								TF => "hd_TFfilter"
              );

$SERVICE=shift @ARGV;

# suppress the -
$SERVICE= substr($SERVICE,1);

if (not($actions{$SERVICE})) {
 die $msg}

$DOCS=shift @ARGV;

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


# TensorFlow case: we have to extract the TF data first (from a .csv file)
if ($SERVICE eq "TF") {
	 say "Lecture de $TF...";
	 # building the data
	 open(DATA, $TF) || die "### Can't open $TF file: $!\n";
	 #seek $fhTF, 0, 0;
   while (<DATA>) {
   	 #say $_;
     push @TFdata, [split /\t/]; # tokenize the data using Tab character
   }
   # building the classes list
   @listeClasses = @{$TFdata[0]}; # dereferencing the first table (which is the headings)
   pop @listeClasses; # suppress the values foundClass, realClass...
   pop @listeClasses;
   pop @listeClasses;
   pop @listeClasses;
   # building the documents list
   shift @TFdata; # suppress the first item (headings)
   foreach (@TFdata) {
     #say $_->[-1] ;
     push @listeDocs, $_->[-1] # the last cell is the illustration file name
    }
   #shift @listeDocs;

	 say Dumper @TFdata;
	 #say Dumper @listeDocs;
	 say Dumper @listeClasses;
}

#isTFclassify("btv1b53016262q");
#die;

# reading the metadata documents
my $dir = dir($DOCS);
say "--- documents : ".$dir->children(no_hidden => 1);


$dir->recurse(depthfirst => 1, callback => sub {
	my $obj = shift;

	if ($obj->basename ne $DOCS)  { # sauter le dossier courant
	  if (($obj->is_dir) ){
		   say "\n dossier : ".$obj->basename;
		 } else {
		 	# analyser les fichiers XML
		 	if (index($obj->basename , "DS_Store") == -1) {
		 		if (ref ($actions{$SERVICE})) {
		 		   $nbDoc += $actions{$SERVICE}->($obj,$obj->basename);} # call of an ad hoc function
		 			else
		 			 {$nbDoc += generic($obj,$obj->basename);}}  # call of a generic function
		 	  }
  		}
});

say "\n\n=============================";
say "$nbDoc documents analysed on ".$dir->children(no_hidden => 1);
if ($SERVICE eq "del") {
  say "$nbTotIll files deleted ";	}
elsif ($SERVICE eq "info") {
  say "$nbTotIll illustrations ";
	say "($nbTotFiltre filtered)";
  say " * $nbTotThem theme classifications ";
	say " * $nbTotGenInconnu unknown genre";
  say " * $nbTotGenMD MD genre classifications ";
	say " * $nbTotGenTF TF genre classifications ";
  say " * $nbTotCol color classifications ";
  say " * $nbTotCC Watson classifications ";
  say " * $nbTotDF Watson face detections ";}
else {
  say "$nbTotIll illustrations processed ";}
say "=============================";


########### end MAIN ##################
#######################################



###############################
# call of a generic service via a XML:Twig handler
sub generic {
	my $fic=shift;
	my $nomFic=shift;

	say "*** Call of a generic service on file: ".$fic;
	my $fh = $fic->openr;
	my $xml = $fic->slurp;

	# ID ark
	($idArk) = do { local $/; $xml =~ m/$motifArk/ };  # variable globale
	if (not (defined $idArk)) {
  	   say "### ID unknown!";
       return -1}

   say " ID: $idArk";
   my $service=$actions{$SERVICE};
   say " service: ".$service;
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
    return 0;
  };

  # commit the changes on the XML content
	open  $fh, '>', $fic or die $!;
	$t->print($fh);
	return 1;
}


# ----------------------
# supprimer les fichiers de MD sans images decrites
sub del {
	my $fic=shift;
	my $nomFic=shift;

	say "*********************************\nfichier : ".$fic;

	my $fh = $fic->openr;
	my $xml = $fic->slurp;
  # les images
	(@ills ) = do { local $/; $xml =~ m/$motifIll/g };

	say "nb images : ".scalar(@ills);
	if (scalar(@ills)==0) {
		$nbTotIll++;
	  $fic->remove()
	  }
	return 1;
}


# ----------------------
# extract the faces as image files (non generic because the XPath is specific)
sub extrFace {
	my $fic=shift;
	my $nomFic=shift;

	say "*********************************\nfichier : ".$fic;
	my $fh = $fic->openr;
	my $xml = $fic->slurp;

	($idArk) = do { local $/; $xml =~ m/$motifArk/ }; # ID ark
	if (not (defined $idArk)) {
  	   say "### ID unknown! ###";
       return -1}
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
	return 1;
}


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
    warn "### ERREUR sur lecture : $_ ###";
    say  "########################################";
    return 0;
  };

	open  $fh, '>', $fic or die $!;
	$t->print($fh);
	return 1;
 }
 else {say " -> $nomFic : document non present dans la base TensorFlow";
 	return 0}
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
     if (index($tmp,"CC") !=-1) { # we have CC classification
        $nbTotCC++;}
     if (index($tmp,"DF") !=-1){ # face detection
       $nbTotDF++;}
    }
		undef $tmp;
    $tmp = $ill->att("couleur"); # color attribute
    if (defined $tmp) {
      $nbTotCol++;}
		undef $tmp;
    $tmp = $ill->first_child('theme'); # theme element
    if (defined $tmp) {
      $nbTotThem++;}
		undef $tmp;
    #$tmp = $ill->first_child('genre'); # genre element
		my @genres= $ill->children( 'genre');
		foreach my $genre (@genres) {
			  $source = $genre->att("source");
				say $source;
				if ($genre->text() eq "inconnu") {$nbTotGenInconnu++}
				if ($source eq "md") {$nbTotGenMD++}
				if ($source eq "TensorFlow") {$nbTotGenTF++}
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
		undef $tmp;
    $tmp = $ill->att("classif"); # classif attribute
    if ((defined $tmp) and (index($tmp,"CC") !=-1)) { # we have CC classification
		  # the  classification elements
		  my @contenus= $ill->children( 'contenuImg');
			foreach my $contenu (@contenus) {

      	say $contenu->text();
			}
    }
	}
}

# suppress all the content classification metadata (CC)
sub hd_deleteCC {
   my ($t, $elt) = @_;

   my @ills = $elt->children('ill');
   for my $ill ( @ills ) {
    $nill = $ill->att('n');
    print "\n$nill: ";
    # suppress the  classif attribute
    my $tmp = $ill->att("classif");
    if ((defined $tmp) and (index($tmp,$SERVICE) !=-1)) { # we have CC classification
     $ill->del_att("classif");
     if (index($tmp,"DF") !=-1){
       $ill->set_att("classif","DF"); # set DF (Detect Faces) again
      }
     $nbTotIll++;
     # suppress the  classification elements
     my @contenus= $ill->children( 'contenuImg');
     #say "nbre de MD CC : ".scalar(@contenus);
     foreach my $contenu (@contenus) {
     	say $contenu->text();
       if ( $contenu->text() ne "face" ) {
       	  print " - ";
          $contenu->delete;}
      }
    }
    else {print " no CC classification"}
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

## extract the illustrations as image files with IIIF
sub hd_extract {
    my ($t, $elt) = @_;

    my $redim;
    my $rotation;
    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
    	$filtre = $ill->att('filtre');
    	if (not (defined $filtre) ) {	   # do not export filtered illustrations
       my $tmp = "$OUT/$idArk-$nill.jpg";
	     # handle rotation
	     $rotation = $ill->att('rotation');
	     $rotation ||= "0";
	     # handle image size
	     #if (($ill->att('w') < $seuilReDim) or ($ill->att('h') < $seuilReDim)) {
	     #  $redim = "/full"} # full size
	     #	else {
	       # reduce at x%
	       $redim = "/pct:$facteurIIIF";
	     #}
	     my $url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$ill->att('w').",".$ill->att('h').$redim."/$rotation/native.jpg";
	     say "$nill --> ".$url;
       $nbTotIll+= IIIF_extract($url,$tmp);
    } else { say "$nill : filtered illustration "}
   }
}


## extract an illustration with the IIIF API
sub IIIF_extract {my $url=shift;
	                my $fic=shift;

       unlink $fic;
       getstore($urlIIIF.$url, $fic);
	     if (-e $fic) {
         return 1;}
       else {
		     say "### IIIF : $urlIIIF.$url \n can't extract! ###";
		     return 0;
			 }
}

## call the content classification API
sub hd_classifyCC {
    my ($t, $elt) = @_;

    my $redim;
    my $rotation;
    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
    	$filtre = $ill->att('filtre');
    	if (defined $filtre) {	# do not classify the filtered illustrations
    		  say "$nill -> filtered";
    		  next}
    	$classif = $ill->att('classif');
    	if ((defined $classif) && (index($classif, $SERVICE) != -1)) {   # do not classify twice
    	   	say "$nill  -> already $SERVICE classified!";
    	    next}
    	 # tmp image file
       my $tmp = "$OUT/$idArk-$nill.jpg";
	     unlink $tmp;
	     # handle the rotation
	     $rotation = $ill->att('rotation');
	     $rotation ||= "0";
	     #handle the image size
	     if (($ill->att('w') < $seuilReDim) or ($ill->att('h') < $seuilReDim)) {
	       $redim = "/full"}
	     	else {
	       $redim = "/pct:$factTtIIIF";
	     }
	     my $url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$ill->att('w').",".$ill->att('h').$redim."/$rotation/native.jpg";
	     say "$nill --> ".$url;
       if (IIIF_extract($url,$tmp)) {
	     	 # call the Watson API
	     	 $cmd=  "curl -X POST -F \"images_file=@".
	   		 $tmp."\" \"https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classify?api_key=$apikey&version=2016-05-20\"";
				 say "cmd : ".$cmd;
				 $res = `$cmd`;
				 say "res : ".$res;
				 if ($res and (index($res, "error") == -1))   {
						(@classes) = do { local $/; $res =~ m/$motifClasse/g };
						(@scores) = do { local $/; $res =~ m/$motifScore/g };
						say Dumper (@classes);
						# write the new metadata in the XML
						$ill->set_att("classif",$SERVICE);
            foreach my $i  (0..scalar(@classes)-1) {
              $ill->insert_new_elt( 'contenuImg', $classes[$i] )->set_att("CS",$scores[$i]);}
						$nbTotIll++;
						}
					else {
						say " ### API error: ".$res;}
	     }
   } #for
}

## call the face detection API
sub hd_classifyDF {
    my ($t, $elt) = @_;

    my $redim;
    my $rotation;
		my $fact = $factTtIIIF/100;
    my $page = $elt->parent->att('ordre');
    say " page: $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	$nill = $ill->att('n');
			undef $tmp;
    	$tmp = $ill->att('filtre');
    	if (defined $tmp) {	# do not classify the filtered illustrations
    		  say "$nill -> filtered";
    		  next}
			undef $tmp;
			$tmp = $ill->first_child('genre');
			#say Dumper $tmp;
		  if ((not defined $tmp) or ($tmp->text() ne "photo")) {	# classify the photos only
		    	say "$nill -> not a photo";
		    	next}
    	$classif = $ill->att('classif');
    	if ((defined $classif) && (index($classif, $SERVICE) != -1)) {   # do not classify twice
    	   	say "$nill  -> already $SERVICE classified!";
    	    next}
    	 # tmp image file
       my $tmp = "$OUT/$idArk-$nill.jpg";
	     unlink $tmp;
	     # handle the rotation
	     $rotation = $ill->att('rotation');
	     $rotation ||= "0";
	     #handle the image size
	     if (($ill->att('w') < $seuilReDim) or ($ill->att('h') < $seuilReDim)) {
	       $redim = "/full"}
	     	else {
	       $redim = "/pct:$factTtIIIF";
	     }
	     my $url = $idArk."/f$page/".$ill->att('x').",".$ill->att('y').",".$ill->att('w').",".$ill->att('h').$redim."/$rotation/native.jpg";
	     say "$nill --> ".$url;
       if (IIIF_extract($url,$tmp)) {
	     	 # call the Watson API
	     	 $cmd=  "curl -X POST -F \"images_file=@".
	   		 $tmp."\" \"https://gateway-a.watsonplatform.net/visual-recognition/api/v3/detect_faces?api_key=$apikey&version=2016-05-20\"";
				 say "cmd : ".$cmd;
				 $res = `$cmd`;
				 say "res : ".$res;
				 if ($res and (index($res, "error") == -1))   {
					 (@genders) = do { local $/; $res =~ m/$motifGender/g };
					 (@scores) = do { local $/; $res =~ m/$motifScore/g };
					 (@agesMin) = do { local $/; $res =~ m/$motifAgeMin/g };
					 (@agesMax) = do { local $/; $res =~ m/$motifAgeMax/g };
					 (@Xo) = do { local $/; $res =~ m/$motifXo/g };
					 (@Yo) = do { local $/; $res =~ m/$motifYo/g };
					 (@Larg) = do { local $/; $res =~ m/$motifLarg/g };
					 (@Haut) = do { local $/; $res =~ m/$motifHaut/g };
						#say Dumper (@genders);
						# write the new metadata in the XML
						$ill->set_att("classif",$classif." ".$SERVICE);
						say " ** number of faces: ".scalar(@genders);
            foreach my $i  (0..scalar(@genders)-1) {
							$age = $agesMin[$i];
							if (defined $agesMax[$i]) {$age = $age + $agesMax[$i]; $age = $age/2}
							say "age : ".$age;
							if ($genders[$i] eq "MALE") {
								$sexe="M";}
							else
								{$sexe = "F";}
							$ill->insert_new_elt( 'contenuImg', "face" )->set_atts("sexe"=>$sexe,"CS"=>$scores[$i],"age"=>$age,
								 "x"=>$Xo[$i]*$facteur,"y"=>$Yo[$i]*$facteur,"l"=>$Larg[$i]*$facteur, "h"=>$Haut[$i]*$facteur);
							}
						$nbTotIll++;
						}
					else {
						say " ### API error: ".$res;}
	     }
   } #for
}

## extract the faces as image files
sub hd_extrFace {
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
	     $deltaL = $largVSG*$facteurVSG; $deltaH= $deltaL; # delta: to crop larger than the face
	     $hautVSG = $largVSG;
	      }
	 	else  {
	 		$deltaH = $hautVSG*$facteurVSG; $deltaL= $deltaH;
	 		$largVSG = $hautVSG;}
	 } else {
	 	  $deltaL = $largVSG*$facteurVSG;
	 	  $deltaH = $hautVSG*$facteurVSG;
	}

	 say " L :".$deltaL	;say " H :".$deltaH	;

	 my $url = $urlIIIF.$idArk."/f$page/".($ill->att('x')+$elt->att('x')-$deltaL/2).",".($ill->att('y')+$elt->att('y')-$deltaH/2).","
	 .($largVSG+$deltaL).",".($hautVSG+$deltaH)."/pct:$facteurIIIF/$rotation/native.jpg";
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
				$already++;
				next}
		$ficImg = "$OUT/$idArk-$nill.jpg";
		unlink $ficImg;
		# handle the rotation
		$rotation = $ill->att('rotation');
		$rotation ||= "0";
		#handle the image size
		if (($ill->att('w') < $seuilReDim) or ($ill->att('h') < $seuilReDim)) {
			$redim = "/full"}
		 else {
			$redim = "/pct:$factTtIIIF";
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
    	$ill->set_att("couleur","$couleur");
    	$nbTotIll++;
    }
}

# reset the theme
sub hd_updateTheme {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $tmp = $ill->first_child('theme');
    	if (defined $tmp) {$tmp->delete;} # if a theme already exists, suppress it
    	$ill->insert_new_elt("theme","$theme");
    	$nbTotIll++;
    }
}

# reset the genre
sub hd_fixGenre {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			$nbTotIll++;
    	my @genres = $ill->children('genre');
			for my $g ( @genres ) {
    	if (defined $g) {
				say $g->text();
				$g->set_att("source",$illGenreSource);
    	  }

			}
    }
}

# unify the genre
sub hd_unifyGenre {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
			my $filtre = $ill->att("filtre"); # filtered illustrations
	    if (not defined $filtre) {
			 $nbTotIll++;
			 if ($ill->children('genre')) {
				$genreMD = $ill->get_xpath('./genre[@source="md"]', 0);
				$genreTF = $ill->get_xpath('./genre[@source="TensorFlow"]', 0);
				# process the results
				if ((defined $genreMD) and ($genreMD->text ne "inconnu")) {
					say "md : ".$genreMD->text
				}
				elsif (defined $genreTF) {
					say "TF : ".$genreTF->text
				}
			}
		 }
    }
}

# reset the document type
sub hd_fixType {
    my ($t, $elt) = @_;

		my $page = $elt->parent->att('ordre');
		say " page : $page";

    my @ills = $elt->children('ill');
    for my $ill ( @ills ) {
    	my $tmp = $ill->first_child('genre');
    	if ((defined $tmp) and ($tmp->text() eq $illGenre)) {
				say " ** hit ** ";
				$nbTotIll++;
				# suppress the genre
				$tmp->delete;
				# suppress the type
				my $meta = $elt->parent->parent->parent->parent->first_child;
				$meta->first_child('type')->delete;
				# and replace it with the right type
				$meta->insert_new_elt("type","$documentType");
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

    	$nill = $ill->att("n");
    	$nill = "$idArk-$nill";
    	@genreIll = isTFclassify($nill);
    	if (defined $genreIll[0]) {
    	  say " illustration genre: $genreIll[0] ($genreIll[1])";
    	  $ill->insert_new_elt( 'genre', $genreIll[0])->set_atts("CS"=>$genreIll[1],"source"=>"TensorFlow"); # set genre
				if ((index($genreIll[0],"filtre") != -1) and ($genreIll[1] > $seuilTF)) {  # it's a noisy illustration
					say "...filtered";
					$ill->set_att("filtre",1);
				}
    	  $nbTotIll++;
    	}
    	else {say "\n### $nill not in the TensorFlow data! ###"}

    }
}


# Say if an illustration is listed in the TensorFlow classifications with the required confidence score
sub isTFclassify {
	my $nomFic=shift;

  my $tmpCS=0;

  #say $nomFic;
	#my $tmp = substr($nomFic, 0, -4);
	say "traiteTF : ".$nomFic;

	#@elements = grep /$nomFic/, @listeDocs;
	foreach my $i  (0..scalar(@listeDocs)-1) {
	 if (index($listeDocs[$i],$nomFic) != -1) { # the illustration name is in the TensorFlow data
	 	my @ligne=@{$TFdata[$i]}; # the CSV data for the illustration
	 	#say Dumper @ligne;
	 	undef $indiceClasse;
	 	foreach my $j (0..$classesNumber-1) { # look for the highest confidence score in the line
	 		my $CS = $ligne[$j];
	 		#say $j." - ".$CS;
	 		if ($CS > $tmpCS) {
	 			if ($DEBUG) {say "hit: $CS";}
	 			$tmpCS = $CS;
	 		  $indiceClasse = $j}
	 	}
	 	#if ((defined $indiceClasse) && ($tmpCS > $seuilTF)) {		# if the confidence score is > threshold
		if ((defined $indiceClasse)) {
		 return ($listeClasses[$indiceClasse],$tmpCS);} # class found and its confidence value
	 	else
	 	 {
	 	 	say " $tmpCS CS for '$listeClasses[$indiceClasse]' is < $seuilTF threshold!";
	 	 	return undef}
	  }
	 }
	 return undef

}









# ----------------------
