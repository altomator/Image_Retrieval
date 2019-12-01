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
  #say "id: $id";
  say "\n\n--------------------- Writing MD for document: ".$id;

  if ((keys %hash)==0) {
  	say "  #### empty HASH! can't export MD... ####";
  	return 0}

	$tmp = $id;
	$tmp =~ s/\//-/g; # replace the / with - to avoid issues on filename
  if (defined $page) {$ficOut = $OUT."/$tmp-$page.".$format}
  else {$ficOut = $OUT."/$tmp.".$format}
  # if exists, delete
  if(-e $ficOut){
		unlink $ficOut;
	}
  say $ficOut;

  open my $fh, , '>:encoding(UTF-8)', $ficOut;
  try {
  ####### XML #########
  if ($format eq "xml") {
   say "...Exporting to XML format";
   print {$fh} "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
   writeOpenElt("analyseAlto",$fh);
   writeOpenElt("metad",$fh);
   writeElt("type",$hash{"type"},$fh);
	 if (defined ($hash{"types"})) {writeElt("types",$hash{"types"},$fh)}
   if ($calculARK == 1) {
		  say "   ** ark ID is needeed **";
  	  $tmp = $hash{"id"};
  		if ($tmp) {
				say "   ark is $tmp";
  			writeElt("ID",$tmp,$fh);
	    } else {
				say "  #### ID is missing! ####";
			}
  } else {
		say "   document ID is $id";
		writeElt("ID",$id,$fh);
	}
	if ($exportBnF) {
		if (defined ($hash{"titre"})) {writeElt("titre",$hash{"titre"},$fh)} else {writeElt("titre","inconnu",$fh)}
		if (defined ($hash{"date"})) {writeElt("dateEdition",$hash{"date"},$fh)} else {writeElt("dateEdition","inconnu",$fh)}
	}
	else { # compatibilité GallicaPix
			writeElt("titre",$hash{"titre"},$fh);
		  writeElt("date",$hash{"date"},$fh);}

	if (defined ($hash{"auteur"})) {writeElt("auteur",$hash{"auteur"},$fh);}
	if (defined ($hash{"lang"})) {writeElt("lang",$hash{"lang"},$fh);}
  #if (defined ($hash{"notice"})) {writeElt("notice",$hash{"notice"},$fh);}
	if (defined ($hash{"source"})) {writeElt("source",$hash{"source"},$fh);}
	if (defined ($hash{"url"})) {writeElt("url",$hash{"url"},$fh);}
	if (defined ($hash{"URLbaseIIIF"})) {writeElt("urlIIIF",$hash{"URLbaseIIIF"},$fh);}
	if ($exportBnF) {
		if (defined ($hash{"sujet"})) {writeElt("sujet",$hash{"sujet"},$fh)} else {writeElt("sujet","inconnu",$fh)}
	  if (defined ($hash{"description"})) {writeElt("descr",$hash{"description"},$fh)} else {writeElt("description","inconnu",$fh)}
		if (defined ($hash{"format"})) {writeElt("format",$hash{"format"},$fh)} else {writeElt("format","inconnu",$fh)}
		if (defined ($hash{"couverture"})) {writeElt("couverture",$hash{"couverture"},$fh)} else {writeElt("couverture","inconnu",$fh)}
		writeElt("genre",$hash{"genre"},$fh);
		writeElt("largeurPx",$hash{"largeurPx"},$fh);
	  writeElt("hauteurPx",$hash{"hauteurPx"},$fh);
		writeElt("ocr",$hash{"ocr"},$fh);
		writeElt("toc",$hash{"toc"},$fh);
		writeElt("caption",$hash{"caption"},$fh);
	}
		else { # compatibilité GallicaPix
	   if (defined ($hash{"sujet"})) {writeElt("desc",$hash{"sujet"},$fh)}}
	writeElt("nbPage",$hash{"pages"},$fh);
  writeEndElt("metad",$fh);
  %atts = ("toc"=> $hash{"toc"},"ocr"=> $hash{"ocr"});
  writeEltAtts("contenus",\%atts,$fh);
  writeElt("largeur",$hash{"largeur"},$fh);
  writeElt("hauteur",$hash{"hauteur"},$fh);
	writeElt("largeurPx",$hash{"largeurPx"},$fh);
  writeElt("hauteurPx",$hash{"hauteurPx"},$fh);
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
				return 0
       };

  close $fh;
	return 1
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
