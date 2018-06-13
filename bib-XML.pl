#!/usr/bin/perl -w

#########################
# macros ecriture XML
#########################

use warnings;
use 5.010;


###################
#sub calculerARK {my $id=shift;

	### a instancier
	#say "calculerARK : vide";
#}

# ----------------------
#
sub exportMD {my $id=shift;
			      my $format=shift;
	          my $page=shift;

	#############
	my %atts;
	my $tmp;
	my $ficOut;

  #say Dumper (%hash);

  say "\n-------------------------- Writing MD: ".$id;

  if ((keys %hash)==0) {
  	say "  ## empty HASH  !  ##";
  	return }

  $nbTotDocs++;
  if (defined $page) {$ficOut = $OUT."/$id-$page.".$format}
  else {$ficOut = $OUT."/$id.".$format}
  # if exists, delete
  if(-e $ficOut){
		unlink $ficOut;
	}
  say $ficOut;

  open my $fh, , '>:encoding(UTF-8)', $ficOut;
  try {
  ####### XML #########
  if ($format eq "xml") {
   say "--> export XML";
   print {$fh} "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
   writeOpenElt("analyseAlto",$fh);
   writeOpenElt("metad",$fh);
   writeElt("type",$hash{"type"},$fh);
   if ($calculARK == 1) {
  		$tmp = $hash{"id"};
  		if ($tmp) {
  			writeElt("ID",$tmp,$fh); }
  		}
  writeElt("titre",$hash{"titre"},$fh);
  writeElt("dateEdition",$hash{"date"},$fh);
  if (defined ($hash{"notice"})) {writeElt("descr",$hash{"notice"},$fh);}
  writeElt("nbPage",$hash{"pages"},$fh);
  if (defined ($hash{"sujet"})) {writeElt("descr",$hash{"sujet"},$fh);}
  writeEndElt("metad",$fh);
  %atts = ("toc"=> $hash{"toc"},"ocr"=> $hash{"ocr"});
  writeEltAtts("contenus",\%atts,$fh);
  writeElt("largeur",$hash{"largeur"},$fh);
  writeElt("hauteur",$hash{"hauteur"},$fh);
  if ($hash{"articles"}){writeElt("nbArticle",$hash{"articles"},$fh);}

	# Exporting the content
  writeOpenElt("pages",$fh);

	if (defined $hash{"lpages"}) {
  	# OCR mode
  	#say $hash{"lpages"};
  	@lp = split ',', $hash{"lpages"};
		foreach my $p (@lp){
  	    exportPage($id,$p,$format,$fh);
     }
	} else { # OAI mode
  	for($p = 1; $p <= $hash{"pages"}; $p++) {
  	    exportPage($id,$p,$format,$fh);
     }
	 }
  writeEndElt("pages",$fh);
  writeEndElt("contenus",$fh);
  writeEndElt("analyseAlto",$fh);
  } # XML
  elsif ($format eq "json") {
		# to be done
  }
  else {
  	say " ## unknown format: $format ## ";
  	close $fh;
  	die
  }
  }
  catch {
        warn " ### ERROR while writing: $_";
       };

  close $fh;
}

#################################
sub writeElt {my $element=shift;
	          my $valeur=shift;
	          my $fh=shift;
  if (defined ($valeur)) {
  	print {$fh} "<$element>".$valeur."</$element>\n"; }
  else
    {#if ($DEBUG) {say "#### ERREUR $element XML : pas de valeur ####";
    	}
 }

sub writeOpenElt {my $element=shift;
	            my $fh=shift;

  	  print {$fh} "\t<$element>\n";
}

# element with attributes
sub writeEltAtts {my $element=shift;
				      my $atts=shift;
	            my $fh=shift;
	            my $valeur=shift;

  	  print {$fh} "<$element ";

  	  foreach my $k (keys %{$atts})
      {    if (defined $atts->{$k}) {
    		     print {$fh} " ".$k."=\"".$atts->{$k}."\"";}
    	     else {
    		     #if ($DEBUG) {say "#### ERREUR $element / $k : pas de valeur   ####";}
    		     if (($k eq "x") or ($k eq "y") or ($k eq "w") or ($k eq "h")) {
    		     	say "#### ERROR $element / $k : no value   ####";
    		     	die}
    		  }
      }
  	if (defined ($valeur)) {
  		   print {$fh} ">".$valeur;
  		   writeEndElt($element,$fh);
  		}
  	  else {print {$fh} ">";}
}

sub writeEndElt {my $element=shift;
	            my $fh=shift;

  	  print {$fh} "</$element>\n";
}

##################################
# JSON
sub writeJsonProp {my $att=shift;
	          my $valeur=shift;
	          my $fh=shift;

  if (defined ($valeur)) {
  	print {$fh} "\"\@$att\":\"".$valeur."\",\n"; }
  else
    {#if ($DEBUG) {say "#### ERREUR $element XML : pas de valeur ####";
    	}
 }
sub writeJsonEndProp {my $att=shift;
	          my $valeur=shift;
	          my $fh=shift;

  if (defined ($valeur)) {
  	print {$fh} "\"\@$att\":\"".$valeur."\"},\n"; }
  else
    {#if ($DEBUG) {say "#### ERREUR $element XML : pas de valeur ####";
    	}
 }

sub writeJsonOpenList {my $list=shift;
	          		   my $fh=shift;
	print {$fh} "\"$list\":{\n"; }

sub writeJsonOpenArray {my $array=shift;
	          		   my $fh=shift;
	print {$fh} "\"$array\":[\n"; }

sub writeJsonCloseArray {my $fh=shift;
	print {$fh} "]\n"; }

sub writeJsonOpen {my $fh=shift;
	print {$fh} "{ "; }

sub writeJsonClose {my $fh=shift;
	print {$fh} "}\n"; }

   ###############################################
#  echapper les caracteres de ponctuation
sub escapePunct {my $texte=shift;

  $texte =~ tr/&;:?!\()[].,/ /;
  return $texte;
}

# ----------------------
#  echapper les caracteres " : / pour la sortie JSON
sub escapeJSON {my $texte=shift;

  $texte =~ tr/\":\\/   /;
  return  $texte;

}

# ----------------------
# echapper les caracteres [ ] de dc:title / OIA + entites XML + supprimer bruit
sub escapeXML_OAI {my $texte=shift;

  if (defined ($texte)) {
  	$texte =~ s/\[Planche\]//; # bruit
  	$texte =~ s/\[Page de texte\]//;
  	$texte =~ s/\[Titre\]//;
    $texte =~ s/\'/_/ ;
    $texte =~ tr/[]//d;  # supprimer les crochets
    $texte =~ tr/\"<>;/   /;
    $texte =~ s/&/&amp;/g;
    }
  return $texte;
}

# ----------------------
#  echapper les caracteres & pour la sortie XML
sub escapeXML {my $texte=shift;

  $texte =~ tr/\"'&<>/    /;
  return $texte;

}


# renvoyer 'true'
1;
