package UCLA_Batch;

# MARC::Batch can't handle some data errors; this routine works around those errors
# by testing batch->next via eval, and skipping bad records
sub safenext {
  # Use existing MARC::Batch, if in scope
  $batch = shift unless $batch;
  die "MARC::Batch object not defined" unless $batch;

  # Make sure $rec is defined
  my $rec = MARC::Record->new();

  # Loop until good record found, or end of batch reached
  while (1) {
    eval { $rec = $batch->next(); };
    # If $rec is undefined here, we've reached end of $batch, so exit the loop
    last if not $rec;
    # If eval encountered an error, show it and try the next record in $batch
    if ( $@ ) {
      warn $@;
      next;
    } else {
      # No errors, and we have a defined record, so exit the loop
      last;
    }
  } # end of while
  return $rec;
}

# packages must return true (1)
1;

