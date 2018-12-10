#!/usr/bin/perl

use 5.010;
use warnings;
use Graphics::ColorNames 2.0, 'all_schemes'; #(qw( hex2tuple ));
use GD;
use Data::Dumper;
use Color::Rgb;

$rgb = new Color::Rgb(rgb_txt=>'./rgb.txt');

our %COLORS;
tie %COLORS, 'Graphics::ColorNames', qw(HTML Netscape Windows);  #all_schemes();

my $n=0;

sub rgbToHex {
    $red=$_[0];
    $green=$_[1];
    $blue=$_[2];
    $string=sprintf ("%2.2X%2.2X%2.2X",$red,$green,$blue);
    return (lc $string);
}


my $img = new GD::Image(100, 100);

foreach my $color (keys %COLORS) {
  print $color;
  print "\n";
  print  "valeur : ".$COLORS{$color}."\n" ;
  #print "\n";
  @rgb  = $rgb->hex2rgb($COLORS{$color});
  print @rgb;
  print "\n";
  $img->colorAllocate(@rgb );  #hex2tuple( $COLORS{$color}
  $n++;
  #$img->colorAllocate( $COLORS{$color} );
}
print "-----------\nscalar : $n";

print "\ntable pour fuscia : ";
print $COLORS{"fuscia"};
#print "\n valeurs rgb: ";
#my @tmp = hex2tuple( $COLORS{"darkmagenta"});
#print @tmp;
print "\n";

my $chocolat = $img->colorClosest(24,20,240);
print "index : ".$chocolat;

@tmp = $img->rgb($chocolat);
print "\n rgb: $tmp[0] $tmp[1] $tmp[2]\n";

my $color = rgbToHex($tmp[0],$tmp[1],$tmp[2]);
print $color;
print "\n";

while( my ($k,$v) = each(%COLORS) ) {
  #print $v."\n";
   if ($v eq $color) {
   print "hit : $k\n";
 last}
}

print "\$chocolat is supposed to be 210,105,30 but is actually @{[$img->rgb($chocolat)]}\n";
