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
  # Set defaults
  $self->{'_max_records'} = 10;

  bless $self, $class;
  return $self;
}

########################################
# Accessor for max records per search (get/set).
sub max_records {
  my ($self, $max_records) = @_;
  # Set, if value provided
  $self->{'_max_records'} = $max_records if $max_records;
  return $self->{'_max_records'};
}

########################################
# Search Worldcat via SRU
# For now, accept only a single set of search terms (single scalar word/phrase, or array of words/phrases).
sub search_sru {
  my ($self, $search_terms_ref, $index) = @_;

  # If caller passed 1 scalar search term, instead of an array ref,
  # convert it to array ref.
  $search_terms_ref = [ $search_terms_ref ] if ref($search_terms_ref) ne 'ARRAY';

  # Set default index of title, if none provided by caller
  $index = 'srw.ti' if not $index;

  # Construct boolean OR search from array of search terms
  my $search_string;
  foreach my $search_term (@$search_terms_ref) {
    ###say "Term: ", $search_term;
	next if $search_term eq '';
	# Wrap search term in double-quotes
    $search_term = '"' . $search_term . '"';
	# Apply boolean OR, and index to use
	$search_string .= ' or ' if $search_string;
	$search_string .= "$index=$search_term";
	###say "Search: ", $search_string;
  }
  $search_string = uri_escape_utf8($search_string);
  return if ! $search_string;
###say $search_string;
  my $wc_api = 'http://www.worldcat.org/webservices/catalog/search/sru';
  my $query = "query=$search_string";
  my $params = 'servicelevel=full&frbrGrouping=off&maximumRecords=' . $self->{_max_records};
  $params .= '&wskey=' . $self->{_wskey};

  my $wc_url = "$wc_api?$query&$params";
###say $wc_url;

  # Send the request and UTF-8 encode the response
  my $xml = $browser->get($wc_url)->decoded_content;
  utf8::encode($xml);

  my @marc_records = $self->_xml_to_marc($xml);

  ###say Dumper @marc_records;
  ###$self->_TEST(\@marc_records);
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
# Experimental method for searching SRU via
# multiple indexes, contained in hash parameter.
sub search_sru_combo {
  my ($self, $search_terms_ref) = @_;
  my %search_terms = %{ $search_terms_ref };
  my $search_string = '';
  foreach my $index (keys %search_terms) {
	my $search_term = $search_terms{$index};
	
	# Wrap search term in double-quotes
    $search_term = '"' . $search_term . '"';

    # Add boolean AND if needed
	$search_string .= ' AND ' if $search_string;

	# Add index and search term
	$search_string .= "$index=$search_term";
  }
say $search_string;
  $search_string = uri_escape($search_string);
  return if ! $search_string;

  # TODO: Unify this duplicate code with search_sru routine
  my $wc_api = 'http://www.worldcat.org/webservices/catalog/search/sru';
  my $query = "query=$search_string";
  my $params = 'servicelevel=full&frbrGrouping=off&maximumRecords=' . $self->{_max_records};
  $params .= '&wskey=' . $self->{_wskey};

  my $wc_url = "$wc_api?$query&$params";
say $wc_url;

  # Send the request and UTF-8 encode the response
  my $xml = $browser->get($wc_url)->decoded_content;
  utf8::encode($xml);

  my @marc_records = $self->_xml_to_marc($xml);

  ###say Dumper @marc_records;
  $self->_TEST(\@marc_records);
  ###return @marc_records;
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
  my $json = '';
  # This can cause an error if $contents is invalid JSON
  eval {
    $json = decode_json($contents);
  };
  if ($@) {
    say "ERROR: Unable to get holdings JSON for OCLC $oclc_number";
	say $wc_url;
  } else {

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

