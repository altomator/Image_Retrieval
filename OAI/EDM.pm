package EDM;

use base qw( XML::SAX::Base );
use Data::Dumper;

sub new {
  my $self = {
    insideTitle => 0,
    title => ''
  };
  return( bless $self, 'EDM' );
}

sub title {
  my $self = shift;
  return( $self->{ title } );
}
sub date {
  my $self = shift;
  return( $self->{ date } );
}
sub subject {
  my $self = shift;
  return( ($self->{ subject }) );
}
sub creator {
  my $self = shift;
  return( $self->{ creator } );
}
sub type {
  my $self = shift;
  return( $self->{ type } );
}
sub format {
  my $self = shift;
  return( $self->{ format } );
}
sub description {
  my $self = shift;
  return( $self->{ description } );
}
sub language {
  my $self = shift;
  return( $self->{ language } );
}
sub edmLanguage {
  my $self = shift;
  return( $self->{ edmLanguage } );
}
sub source {
  my $self = shift;
  return( $self->{ source } );
}
sub isReferencedBy {
  my $self = shift;
  return( $self->{ isReferencedBy } );
}
sub resource {
  my $self = shift;
  return( $self->{ resource } );
}

## SAX Methods
sub start_element {
  my ( $self, $element ) = @_;
  if ( $element->{ Name } eq 'dc:title' ) {
    $self->{ insideTitle } = 1;
    return
  }
  if ( $element->{ Name } eq 'dc:date' ) {
    $self->{ insideDate } = 1;
    return
  }
  if ( $element->{ Name } eq 'dc:subject' ) {
    $self->{ insideSubject } = 1;
    return
  }
  if ( $element->{ Name } eq 'dc:creator' ) {
    $self->{ insideCreator } = 1;
    return
  }
  if ( $element->{ Name } eq 'edm:type' ) {
    $self->{ insideType } = 1;
    return
  }
  if ( $element->{ Name } eq 'dc:format' ) {
    $self->{ insideFormat } = 1;
    return
  }
  if ( $element->{ Name } eq 'dc:description' ) {
    $self->{ insideDescription } = 1;return
  }
  if ( $element->{ Name } eq 'dc:language' ) {
    $self->{ insideLanguage } = 1;return
  }
  if ( $element->{ Name } eq 'edm:dataProvider' ) {
    $self->{ insideSource } = 1;return
  }
  if ( $element->{ Name } eq 'edm:isShownAt' ) {
    my %attrs = %{$element->{Attributes}};
    while ( my ($name, $value) = (each (%attrs))) {
      $self->{ resource } = $value->{"Value"};
      last;
      }
    return
 }
  if ( $element->{ Name } eq 'edm:language' ) {
    $self->{ insideEdmLanguage } = 1;return
  }
  if ( $element->{ Name } eq 'dcterms:isReferencedBy' ) {
    my %attrs = %{$element->{Attributes}};
      while ( my ($name, $value) = (each (%attrs))) {
        foreach my $v (values($value)) {
        if (index($v,'iiif')!=-1) {
          $self->{ isReferencedBy } = $v;
        }
      }
  }
 }
}

sub end_element {
  my ( $self, $element ) = @_;
  if ( $element->{ Name } eq 'dc:title' ) {
    $self->{ insideTitle } = 0;return
  }
  if ( $element->{ Name } eq 'dc:date' ) {
    $self->{ insideDate } = 0;return
  }
  if ( $element->{ Name } eq 'dc:subject' ) {
    $self->{ insideSubject } = 0;return
  }
  if ( $element->{ Name } eq 'dc:creator' ) {
    $self->{ insideCreator } = 0;return
  }
  if ( $element->{ Name } eq 'edm:type' ) {
    $self->{ insideType } = 0;return
  }
  if ( $element->{ Name } eq 'dc:format' ) {
    $self->{ insideFormat } = 0;return
  }
  if ( $element->{ Name } eq 'dc:description' ) {
    $self->{ insideDescription } = 0;return
  }
  if ( $element->{ Name } eq 'dc:language' ) {
    $self->{ insideLanguage } = 0;return
  }
  if ( $element->{ Name } eq 'edm:language' ) {
    $self->{ insideEdmLanguage } = 0;return
  }
  if ( $element->{ Name } eq 'edm:dataProvider' ) {
    $self->{ insideSource } = 0;return
  }
  if ( $element->{ Name } eq 'edm:isShownAt' ) {
    $self->{ insideResource } = 0;return
  }
  if ( $element->{ Name } eq 'dcterms:isReferencedBy' ) {
    $self->{ insideIsReferencedBy } = 0;
  }
}
sub characters {
  my ( $self, $chars ) = @_;
  if ( $self->{ insideTitle } ) {
    $self->{ title } .= $chars->{ Data };return
  }
  if ( $self->{ insideDate } ) {
    $self->{ date } .= $chars->{ Data };return
  }
  if ( $self->{ insideSubject } ) {
    $self->{ subject } .= $chars->{ Data };
    $self->{ subject } .= " - "; # we can have multiple subjects
    return
  }
  if ( $self->{ insideCreator } ) {
    $self->{ creator } .= $chars->{ Data };return
  }
  if ( $self->{ insideType } ) {
    $self->{ type } .= $chars->{ Data };
    $self->{ type } .= ":"; # we can have multiple types
    return
  }
  if ( $self->{ insideFormat } ) {
    $self->{ format } .= $chars->{ Data };return
  }
  if ( $self->{ insideDescription } ) {
    $self->{ description } .= $chars->{ Data };return
  }
  if ( $self->{ insideLanguage } ) {
    $self->{ language } .= $chars->{ Data };return
  }
  if ( $self->{ insideEdmLanguage } ) {
    $self->{ edmLanguage } .= $chars->{ Data };return
  }
  if ( $self->{ insideSource } ) {
    $self->{ source } .= $chars->{ Data };
  }

}

# renvoyer 'true'
1;
