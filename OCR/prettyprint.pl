#!/usr/bin/perl -w


use strict;
use warnings; 
use 5.010;


use Data::Dumper; 
use Path::Class;
use Parallel::ForkManager;

use Benchmark qw(:all) ;


my $t0 = Benchmark->new;

#use XML::Tidy;

# Pour avoir un affichage correct sur STDOUT
binmode(STDOUT, ":utf8");





# repertoire de stockage des documents
my $DOCS = "DOCS";

# nbre de documents traités
my $nbDoc=0;
	

   



if(scalar(@ARGV)!=1){
	die "Usage : perl unzip.pl 
	in - dossier des documents a traiter
	
	";
}
while(@ARGV){
	$DOCS=shift;
	
	if(-e $DOCS){
		print "Lecture de $DOCS...\n";
	}
	else{
		die "$DOCS n'existe pas !\n";
	}
}

print "\n-----------------------------\n";

############ 1 : 49
############ 4 : 34 
############ 20 : 25
############ 30 : 24 

my $pm = new Parallel::ForkManager(30);

my $dir = dir($DOCS);
$dir->recurse(depthfirst => 1, callback => sub {
	my $obj = shift;
	#say $obj;
	
	if ((not ($obj->is_dir)) && (index($obj->basename, ".xml") != -1 ) && (index($obj->basename, "mets") == -1 )) {
		   my $file = $obj->basename;
		   
		   print "\n ".$obj."... ";
		   #my $tidy_obj = XML::Tidy->new('filename' => $obj);
		   #$tidy_obj->tidy();
		   #$tidy_obj->write();
		   
		   
		   my $cmd =  "\n xml_pp -i ".$obj ;
		   say $cmd;
		   $pm->start and next; # do the fork
		   system $cmd;
		 	 $pm->finish; # do the exit
		 	  
		  $nbDoc++;	   
		 } 
	      
	});


$pm->wait_all_children;

print "\n-----------------------------\n";
print "$nbDoc documents traites\n";

print "=============================\n";
# FIN


  	
my $t1 = Benchmark->new;
my $td = timediff($t1, $t0);
say "the code took:",timestr($td);                