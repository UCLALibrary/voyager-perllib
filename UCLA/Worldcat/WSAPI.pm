package UCLA::Worldcat::WSAPI;

use Data::Dumper qw(Dumper);
use JSON qw(decode_json);
use LWP::UserAgent;
use MARC::File::XML (BinaryEncoding => 'utf8', RecordFormat => 'MARC21');
#use MARC::Batch;
use URI::Escape;
use UCLA::Worldcat::MARC;
use feature qw(say);
use strict;
use warnings;
use utf8;

# TODO: Consider adding this to $self?
my $browser = LWP::UserAgent->new();
$browser->agent('UCLA Library DIIT');

########################################
# Initialize new instance with OCLC API WSKEY
sub new {
  my $class = shift;
  my $self = { _wskey => shift };
  bless $self, $class;
  return $self;
}

########################################
# Search Worldcat via SRU
# For now, accept only a single search term (word or phrase).
sub search_sru {
  my ($self, $search_term, $index) = @_;

  # Set default index of title, if none provided by caller
  $index = 'srw.ti' if not $index;
  # Wrap search term in double quotes, then url-escape it
  $search_term = '"' . $search_term . '"';
  $search_term = uri_escape($search_term);

  my $wc_api = 'http://www.worldcat.org/webservices/catalog/search/sru';
  my $query = "query=$index=$search_term";
  # Consider adding explicit maximumRecords parameter; default is 10
  my $params = 'servicelevel=full&frbrGrouping=off&wskey=' . $self->{_wskey};

  my $wc_url = "$wc_api?$query&$params";
#say $wc_url;

  # Send the request and UTF-8 encode the response
  my $xml = $browser->get($wc_url)->decoded_content;
  utf8::encode($xml);

  my @marc_records = $self->_xml_to_marc($xml);

  #say Dumper @marc_records;
  #$self->_TEST(\@marc_records);
  return @marc_records;
}

########################################
# Search Worldcat via SRU's standard number index:
# Convenience method.
sub search_sru_sn {
  my ($self, $search_term) = @_;
  $self->search_sru($search_term, 'srw.sn');
}

########################################
# Convert MARCXML into binary MARC
sub _xml_to_marc {
  # OCLC's MARCXML seems to be incompatible with
  # the MARC::Record conversion routines, when
  # the XML represents more than one record.
  # Work around this by extracting the OCLC numbers
  # from OCLC's MARCXML, and using OCLC's single-record
  # lookup to retrieve each record, which then can
  # be converted to MARC.

  my ($self, $xml) = @_;
  my $pattern = '<controlfield tag="001">([0-9]{1,10})</controlfield>';
  my @oclc_numbers = ($xml =~ /$pattern/g);
  my @marc_records = ();
  foreach my $oclc_number (@oclc_numbers) {
    push(@marc_records, $self->_get_marc($oclc_number));
  }

  return @marc_records;
}

########################################
# Retrieve MARC record corresponding to the
# given OCLC number.
sub _get_marc {
  my ($self, $oclc_number) = @_;

  # Use OCLC's single-record lookup by OCLC number
  my $wc_api = 'http://www.worldcat.org/webservices/catalog/content';
  my $params = 'servicelevel=full&wskey=' . $self->{_wskey};
  my $wc_url = "$wc_api/$oclc_number?$params";
#say $wc_url;
  my $contents = $browser->get($wc_url)->decoded_content;
  utf8::encode($contents);

  # Convert to binary MARC, then create an enhanced record from that
  my $marc = MARC::Record->new_from_xml($contents, 'UTF-8');
  return UCLA::Worldcat::MARC->new($marc, $self->_get_holdings($oclc_number));
}

########################################
# Call OCLC Locations API to get number of holdings and
# whether CLU (UCLA) holds the record, by OCLC number.
sub _get_holdings {
  my ($self, $oclc_number) = @_;
  my $held_by_clu = 0; # FALSE
  my $number_of_holdings = 0;

  my $wc_api = 'http://www.worldcat.org/webservices/catalog/content/libraries';
  my $params = 'format=json&frbrGrouping=off&servicelevel=full&location=90095&wskey=' . $self->{_wskey};
  my $wc_url = "$wc_api/$oclc_number?$params";
#say $wc_url;
  
  my $contents = $browser->get($wc_url)->decoded_content;
  utf8::encode($contents);
  # Data in JSON, not XML
  my $json = decode_json($contents);
  # Bail out if this OCLC number has no holdings
  if ($json->{'diagnostics'}) {
    return ($held_by_clu, $number_of_holdings);
  }

  $number_of_holdings = $json->{'totalLibCount'};
  my @libraries = @{$json->{'library'}};
  foreach my $library (@libraries) {
    if ($library->{'oclcSymbol'} eq 'CLU') {
      $held_by_clu = 1; # TRUE
      last;
    };
  }

  return ($held_by_clu, $number_of_holdings);
}

########################################
# DEBUG: temporary test function
sub _TEST {
  my ($self, $marc_records_ref) = @_;
  my @marc_records = @$marc_records_ref; # I hate working with array refs
  foreach my $marc_record (@marc_records) {
    say $marc_record->oclc_number() . " : " . $marc_record->title();
	say "\tHoldings: " . $marc_record->holdings_count();
	say "\tHeld by CLU? " . $marc_record->held_by_clu();
	say "\tType: " . $marc_record->record_type() . " === Blvl: " . $marc_record->bib_level() . " === Elvl: " . $marc_record->encoding_level();
  }

}

########################################
# Packages must return true (1)
1;

