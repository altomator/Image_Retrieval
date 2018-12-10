#!/usr/bin/perl -w

# usage : perl extractARKs_SRU.pl OUT.txt
# Extract ark IDs of digital documents in response of a SRU Gallica request
# Output can then be the input of extractMD_OAI.pl script to obtain the documents metadata

# The request must be set in the $req var


#####################
# use strict;
use warnings;
use 5.010;
use Data::Dumper;
use utf8::all;
use LWP::Simple;
#use Switch;


#####################
$DEBUG = 1;


#####################################
#####################################
# Requests samples

# affiches
#my $req ="gallica%20all%20%22affiche%22%20%20and%20(dc.type%20all%20%22image%22)%20and%20(gallicapublication_date>=%221910/01/01%22%20and%20gallicapublication_date<=%221920/12/31%22)%20and%20(provenance%20adj%20%22bnf.fr%22)";
# Agence Meurisse
#"gallica%20all%20%22agence%20meurisse%22%20and%20(dc.type%20all%20%22image%22)%20and%20(gallicapublication_date%3E=%221914/01/01%22%20and%20gallicapublication_date%3C=%221918/12/31%22)";
# Guerre 14-18
#my $req ="%28bibliotheque%20adj%20%22Biblioth%C3%A8que%20nationale%20de%20France%22%29%20and%20%28dc.subject%20all%20%22Guerre%20mondiale%20%201914-1918%22%29%20and%20%28dc.type%20all%20%22image%22%29%20and%20%28gallicapublication_date%3E%3D%221914/01/01%22%20and%20gallicapublication_date%3C%3D%221920/01/01%22%29%20";
# coq
#my $req ="gallica%20all%20%22coq%22%20%20and%20(dc.type%20all%20%22image%22)%20and%20((bibliotheque%20adj%20%22Biblioth%C3%A8que%20nationale%20de%20France%22))%20and%20(provenance%20adj%20%22bnf.fr%22)&suggest=10";
# cheval
#my $req ="gallica%20all%20%22cheval%22%20%20and%20(dc.type%20all%20%22image%22)%20and%20((bibliotheque%20adj%20%22Biblioth%C3%A8que%20nationale%20de%20France%22))%20and%20(provenance%20adj%20%22bnf.fr%22)&suggest=10";
# lion
#my $req ="gallica%20all%20%22lion%22%20%20and%20(dc.type%20all%20%22image%22)%20and%20((bibliotheque%20adj%20%22Biblioth%C3%A8que%20nationale%20de%20France%22))%20and%20(provenance%20adj%20%22bnf.fr%22)&suggest=10";
# chien
#my $req ="gallica%20all%20%22chien%22%29%20and%20dc.type%20all%20%22image%22&suggest=0";
#my $req ="gallica%20all%20%22chien%22%20%20and%20(dc.type%20all%20%22image%22)&suggest=10&keywords=";
# maps
#my $req ="dc.subject%20all%20%22Guerre%20mondiale%22%20%20and%20(dc.type%20all%20%22carte%22)";
# Normandie
#my $req ="gallica%20all%20%22BNormand1%22%20%20and%20%28ocr.quality%20all%20%22Texte%20disponible%22%29&suggest=10";
#my $req ="gallica%20all%20%22HNormand1%22%20%20and%20%28ocr.quality%20all%20%22Texte%20disponible%22%29&suggest=10&collapsing=false";
# equestre
#my $req ="dc.subject%20any%20%22cavalerie%20cavaleries%20cheval%20chevaux%20chevaline%20chevalines%20courre%20écuries%20équestre%20équestres%20équitation%20haras%20hippiques%20hippisme%20hippodromes%20hippomobile%20maréchalerie%20remonte%20trotteurs%22%20and%20%28ocr.quality%20all%20%22Texte%20disponible%22%&collapsing=false";
#my $req ="dc.subject%20any%20%22cavalerie%20cavaleries%20cheval%20chevaux%20chevaline%20chevalines%20courre%20écuries%20équestre%20équestres%20équitation%20haras%20hippiques%20hippisme%20hippodromes%20hippomobile%20maréchalerie%20remonte%20trotteurs%22%20and%20(ocr.quality%20all%20%22Texte%20disponible%22)&suggest=10&collapsing=false";
# pour obtenir les arks d'un périodique : collapsing=false
#my $req = "gallica%20all%20%22tombouctou%22%20%20and%20%28dc.type%20all%20%22carte%22%20or%20dc.type%20all%20%22image%22%29&filter=provenance%20all%20%22bnf.fr%22";
# TOURS #
my $req = "(dc.title%20all%20%22tours%22%20and%20dc.subject%20all%20%22tours%22%20)%20%20and%20(dc.type%20all%20%22carte%22%20or%20dc.type%20all%20%22image%22)";


#####################
# API SRU
$urlAPISRU = "https://gallica.bnf.fr/SRU?version=1.2&operation=searchRetrieve&query="; # Gallica SRU API endpoint
#$urlGallica = "http://gallica.bnf.fr/ark:/12148/";

# number of records extracted at each call
$module = 50;

#<srw:numberOfRecords>6063</srw:numberOfRecords>
$motifRecords = "numberOfRecords\>(\\d+)\<\/srw" ;
$motifArks = "identifier\>(.*)\<\/dc" ;



###############################
# Output number of record hits for a SRU request
sub getNumberRecordsSRU {my $req=shift;

	  my $urlAPI = $urlAPISRU.$req."&startRecord=1&maximumRecords=1";
	  if ($DEBUG==1) {say $urlAPI}

		my $cmd=  "curl --request GET --url '$urlAPI'";
		#$reponseAPI = get($urlAPI);
    my $reponseAPI = `$cmd`;

    if (defined $reponseAPI) {
      if ($DEBUG==1) {say $reponseAPI;}
      (my $tmp)  = $reponseAPI =~ m/$motifRecords/;
			if (defined $tmp) {
         return $tmp;}
			else {
				say "## SRU Gallica: can't get the number of records";
				return -1
			}
    }
    else {
    	say "## SRU Gallica: no response";
    	return -1 ;
    }
  }

# Output the records by sequence of $module items
sub getRecordsSRU {my $req=shift;
				   my $start=shift;

	  my $urlAPI = $urlAPISRU.$req."&startRecord=$start&maximumRecords=$module";
	  if ($DEBUG==1) {say $urlAPI}

  my $cmd=  "curl --request GET --url '$urlAPI'";
	#$reponseAPI = get($urlAPI);
	my $reponseAPI = `$cmd`;

  if (defined $reponseAPI) {
      if ($DEBUG==1) {
      	say $reponseAPI;
      	}
      (my @arks)  = do { local $/; $reponseAPI =~ m/$motifArks/g };
      if ($DEBUG==1) {say Dumper (\@arks);}
      return @arks;

    }
    else {
    	say "## SRU Gallica: no response";
    	return -1 ;
    }
  }


#####################################
########### main ##############
#####################################

if (scalar(@ARGV)<1) {
	die "\nUsage : perl extractMD_SRU.pl OUT.txt
OUT.txt :  ark IDS list
	\n";
}


# Output file of the list of IDs
$OUT=shift @ARGV;

if(-e $OUT){
		unlink $OUT;}

say "\n...Gallica request: $req\n";

my $nbRecords = getNumberRecordsSRU($req);
if ($nbRecords == -1){
	die
} else {
	open my $fh, '>>', $OUT;
	say "writing in: ".$OUT;

  say "\n# of records: ".$nbRecords;
  for (my $i = 0; $i <= $nbRecords/$module; $i++) {
   say "i: ".(($i*$module)+1)." - ".(($i+1)*$module);
   my @arks = getRecordsSRU($req,($i*$module)+1);

   foreach (@arks)
   {
   	if (index($_,"ark") !=-1)  {
   	  my $ark =substr $_,22; # removing the beginning of the URL
   	  #chop($ark);
      print $fh "getRecordOAI(\"$ark\");\n";  }
    }
  }
  close $fh;
}

die;
#####################




say "\n=============================";
say "  $nbRecords records";

say "--------------------";
