package UCLA::Worldcat::MARC;

use MARC::File::XML (BinaryEncoding => 'utf8', RecordFormat => 'MARC21');
use MARC::Batch;
use strict;
use warnings;
use utf8;
use feature qw(say);

########################################
# Initialize new instance with binary MARC record
sub new {
  my $class = shift;
  my $self = { 
    _marc => shift,
	_held_by_clu => shift,
	_holdings_count => shift
  };
  bless $self, $class;
  return $self;
}

########################################
# Bib level (LDR/07) accessor (get only)
sub bib_level {
  my $self = shift;
  return substr($self->{_marc}->leader(), 7, 1);
}

########################################
# Encoding level (LDR/17) accessor (get only)
sub encoding_level {
  my $self = shift;
  my $elvl = substr($self->{_marc}->leader(), 17, 1);
  # Replace blank with '#' for clarity in printing
  my $blank = '#';
  return $elvl =~ s/ /$blank/r;
}

########################################
# Held by CLU accessor (get only)
sub held_by_clu {
  my $self = shift;
  return $self->{_held_by_clu};
}

########################################
# Number of holdings accessor (get only)
sub holdings_count {
  my $self = shift;
  return $self->{_holdings_count};
}

########################################
# OCLC number accessor (get only)
# These are records from Worldcat, so have OCLC number in 001.
sub oclc_number {
  my $self = shift;
  return $self->{_marc}->field('001')->data();
}

########################################
# Record type (LDR/06) accessor (get only)
sub record_type {
  my $self = shift;
  return substr($self->{_marc}->leader(), 6, 1);
}

########################################
########################################
# Delegate to MARC record component
sub title {
  my ($self) = @_;
  return $self->{_marc}->title();
}

# Packages must return true (1)
1;

