#!/usr/bin/perl -w

# perl extractMD.pl IMG_folder md_file
# take image files and a source metadata file as inputs and:
# - rename the image files as needed for the GallicaPix file naming convention
# - produced GallicaPix metadata files from a XML template

# use case: TNA Board of Trade / Designs collection
# https://discovery.nationalarchives.gov.uk

# the source metadafile must have been generated previously
# thanks to the TNA API

# use strict;
use warnings;
use 5.010;
use Data::Dumper;
use Path::Class;
use File::Slurp;
use File::Copy;
use Image::Size;

binmode(STDOUT, ":utf8");

# the GallicaPix XML file template
my $template = "modeleTNA.xml";

# Parameters to set
my $DEBUG = 1;
my $TNAserie = "BT"; # TNA Board of Trade
my $topic = "floral"; # tags to be added to all the illustrations
#my $author = "Christopher Dresser"; # default author
#my $defaultGenre = "textile"; # default genre (GallicaPix classification)

#  folders
my $DOCS ; # input folder : images to be processed
my $OUT = "MD_out"; # output MD folder for the xml metadata files
my $IMG = "IMG_out"; # output images folder : renamed images
my $MD ; # input metadata file
my $fh;

my $nDocs=0; # number of documents analysed
my $MDfiles=0; # number of metadata files produced

# GREP patterns to extract metadata from the XML source data (TNA data model)
$parentIDpattern = "\<parent\>(.+)\<\/parent\>" ; # it's a mongo id
$IDpattern = "\<id\>(.+)\<\/id\>" ; # it's a mongo id
$datePattern = "\<coveringFromDate\>(.+?)\<\/coveringFromDate\>" ; # date should be an ISO date
$descPattern = "\<description\>(.+?)\<\/description\>" ; # description: mixed stuff
$designNumberPattern ="design number\: ([0-9]+)" ; # extracted from description
$subjectPattern = "Subject\:(.+?)(\\.|-)" ; # can be anything...
$ownerPattern = "Proprietor\:(.+?)(\\.|-)" ; # owner -> dc:author
$classPattern = "Class.+?\:(.+?)(\\.|-)"; # wood, fabric, paper... -> dc:format
$folioPattern = "Folio (.+?)--";

# GREP patterns to look in the file names
$TNAidPattern = $TNAserie."(.*?)[.| |  ]" ;
#$motifID = "[N|n]°(.*?) - " ;

# illustration genre words network
%genres = (
	"fabrics damask woven" => "textile",
	"paper" => "gravure"
	);

sub proprifyStr { # this function modify its parameter
		 $_[0] =~ s/^\s+|\s+$//g; # remove white spaces begin/end
		 $_[0] =~ s/\.+$//; # remove . at the end
		 $_[0] =~ s/  / /g; # remove double white spaces
		 $_[0] =~ s/\t//g; # remove tab
		 $_[0] =~ s/	//g;
		 return $_[0]
}

sub proprifyExtref { # this function modify its parameter
			$_[0] =~ s/\&#34//g;
		 $_[0] =~ s/\<extref href=//g; # remove stuff
		 $_[0] =~ s/\>EXT/ EXT/g;
		 $_[0] =~ s/\<\/extref\>//g;
		 return $_[0]
}

sub escapePunct {my $texte=shift;
  $texte =~ tr/-&;:?!\()[].,/ /;
  return $texte;
}

sub isFabric { my $str=shift;
 @mots = split(' ',lc(escapePunct($str)));
 foreach my $t (@mots) {
 if ((length($t) < 4) or ($t =~ /^[0-9,.E*°]+$/ ) )
		{next} # don't process stop words and numbers
 $t =~ tr/*{}/ /;
 if ($DEBUG) {print $t." - ";}
 ($match) = grep {$_ =~ /\b$t\b/} keys %genres;
	if ($match) {
		 $genre = $genres{$match};
		 say "... genre: $genre";
		 return $genre}
  }
}


####### MAIN #######
if(scalar(@ARGV)!=2){
	die "Usage: perl extractMD_files.pl IMG md_file
	IMG: input folder of image files
	md_file: XML source metadata file

	";
}
while(@ARGV){
	$DOCS=shift;
	if(-e $DOCS){
		print "Reading $DOCS...\n";
	}
	else{
		die "## $DOCS does not exist!\n";
	}
	$MD=shift;
	if(-e $MD){
		print "Reading $MD...\n";
		open $fh, '<', $MD or die;
	}
	else{
		die "## $MD does not exist!\n";
	}
}

if(-d $OUT){
		say "Writing in $OUT...";
	}
	else{
		mkdir ($OUT) || die ("##  Error while creating folder: $OUT\n");
    say "Creating $OUT folder...";
	}

	if(-d $IMG){
			say "Writing images in $IMG...";
		}
		else{
			mkdir ($IMG) || die ("##  Error while creating folder: $IMG\n");
	    say "Creating $IMG folder...";
		}
print "\n-----------------------------\n";

my $dir = dir($DOCS);
my @files = read_dir($DOCS);
@files = sort @files;

for	(my $i = 0; $i <= scalar(@files)-1; $i++) {
	my $date;
	my $parentID;
	my $id;
  my $TNAid;
	my $description;

  # first extract MD from file names
  if  (index($files[$i], ".jpeg") != -1) {
		$nDocs++;
		# extract metadada from file name
		my $currentPath = $DOCS.'/'.$files[$i];
		(my $idFromFile) = do { local $/; $files[$i] =~ m/$TNAidPattern/ }; # extract ID from file name
	  $TNAid = $TNAserie.$idFromFile;
		my $tmpID = $idFromFile;
		$tmpID =~ tr/-/\//;  # replace - with /
		#$date =~ tr/-/ /;  # suppress -
		#$date =~ s/^\s+//; # suppress space at start
		#$dateISO = join "-", reverse split /\./, $date; #reformat as ISO
		say "****\n".$files[$i];
		say "... img ID: $TNAid";
		#say "... ID: $tmpID";
		#say "date:".$date;
		#say "... dateISO: $dateISO";
    #if (not defined($dateISO) or ($dateISO = "")) {die}

		# then extract MD from the XML TNA catalog data
		$xmlKey = "\<citableReference\>(.*)$tmpID\<\/citableReference\>" ; # ID pattern to fing our line record
		seek $fh, 0, 0;
		foreach my $line (<$fh>) { # looking for a line including this pattern
				(my $record) = $line =~ m/$xmlKey/;
				if (defined $record)  {
					($id) = $line =~ m/$IDpattern/;
					($parentID) = $line =~ m/$parentIDpattern/;
				  ($date) = $line =~ m/$datePattern/;
					if (defined $date)  {say "... date: $date"}
					($description) = $line =~ m/$descPattern/;
					if (defined $description)  {
						proprifyStr($description);
						proprifyExtref($description);
						say "... description: $description";
						($subject) = $description =~ m/$subjectPattern/;
						if (defined $subject)  {
							proprifyStr($subject);
							say "... subject: $subject";
						}
						($owner) = $description =~ m/$ownerPattern/;
						if (defined $owner)  {
							proprifyStr($owner);
							say "... publisher: $owner";
						}
						($designNumber) = $description =~ m/$designNumberPattern/;
						if (defined $designNumber){
							proprifyStr($designNumber);
							say "... design number: $designNumber";
						}
						($class) = $description =~ m/$classPattern/;
						if (defined $class){
							proprifyStr($class);
							say "... class: $class";
						}
						($folio) = $description =~ m/$folioPattern/;
						if (defined $folio){
							proprifyStr($folio)}
						else 	{$folio = "1"}
						say "... folio: $folio"
					}
				 	last;
				}
			}
    if (not (defined $id) ) {
			say "############## can't find record id: $tmpID! ###############";
			next;}
    else { # we can continue
		  $MDfiles++;
			# rename IMG file as a gallicapix file
			my $IMGfile = $TNAid;
			copy($currentPath,"$IMG/$IMGfile"."-".$folio."-1.jpg") or die "Copy failed: $!";
			# copy GallicaPix XML metadata template
			my $newMDfile = "$OUT/$TNAid".".xml";
			copy($template,$newMDfile) or die "Copy failed: $!";
			my $currentXML = read_file $newMDfile, {binmode => ':utf8'};
			$currentXML =~ s/idvalue/$TNAid/g;
			$currentXML =~ s/recordvalue/$id/g;
			$currentXML =~ s/parentvalue/$parentID/g;
			$currentXML =~ s/filevalue/$IMGfile/g;
			if (defined $date)  {$currentXML =~ s/datevalue/$date/g;}
			if (defined $description)  {$currentXML =~ s/descvalue/$description/g;}
			if ((defined $subject) and (index($subject,"not given") == -1))
				{$currentXML =~ s/subjectvalue/$subject/g;}
			else {
				$currentXML =~ s/subjectvalue//g;
				$currentXML =~ s/\<contenuImg CS="1.0" lang="en" source="md"\>\<\/contenuImg\>//g;
			}

			if (defined $owner)
				{$currentXML =~ s/publishervalue/$owner/g;}
			else
				{$currentXML =~ s/\<editeur\>publishervalue\<\/editeur\>//g;} # suppress the XML element
			if (defined $author)
					{$currentXML =~ s/authorvalue/$author/g;}
				else
					{$currentXML =~ s/\<auteur\>authorvalue\<\/auteur\>//g;}
			if (defined $designNumber)  {$currentXML =~ s/designnumbervalue/$designNumber/g;}
			if (defined $class)  {$currentXML =~ s/classvalue/$class/g;}
			else
			   {$currentXML =~ s/\<contenuImg CS="1.0" lang="en" source="md"\>classvalue\<\/contenuImg\>//g;
			    $currentXML =~ s/\<format\>classvalue\<\/format\>//g}
			if (defined $topic)  {$currentXML =~ s/topicvalue/$topic/g}
			else {
				 $currentXML =~ s/\<contenuImg CS="1.0" lang="en" source="md"\>topicvalue\<\/contenuImg\>//g;
				 $currentXML =~ s/topicvalue//g}
			# page number
			$currentXML =~ s/foliovalue/$folio/g;
			# document genre : imprints, picture, fabrics...
			if (defined $defaultGenre) {
				$currentXML =~ s/genrevalue/$defaultGenre/g;
			  say "... genre (default): $defaultGenre"} # the genre is a parameter
			elsif (isFabric($description) eq "textile") {
				$currentXML =~ s/genrevalue/textile/g;
			  say "genre: fabric" } # we can see from the metadata it's a fabric
			else {
				$currentXML =~ s/genrevalue/gravure/g;
			  say "genre: engraving" }# default

			#  extract image dimension
			($x, $y) = imgsize($currentPath);
			$currentXML =~ s/xvalue/$x/g;
			$currentXML =~ s/yvalue/$y/g;
			# write GallicaPix metadata file
			say " creating file: ".$newMDfile;
			write_file $newMDfile, {binmode => ':utf8'}, $currentXML;
		}
	}
}

close $fh;
print "\n-----------------------------\n";
print "$nDocs images processed\n";
print "$MDfiles metadata files generated\n";
print "=============================\n";

# end
