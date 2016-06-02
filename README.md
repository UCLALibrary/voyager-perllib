# voyager-perllib
Perl libraries (not Perl scripts) used for local Voyager script development.

Voyager comes with many Perl libraries, including MARC::Batch and related.  These get installed
into whatever `/m1/shared/bin/perl` is linked to:
```
voyager@wells:bin => /m1/shared/bin/perl -le 'print foreach @INC'
/m1/shared/perl/5.20.2_Oracle11/lib/site_perl/5.20.2/sun4-solaris-thread-multi
/m1/shared/perl/5.20.2_Oracle11/lib/site_perl/5.20.2
/m1/shared/perl/5.20.2_Oracle11/lib/5.20.2/sun4-solaris-thread-multi
/m1/shared/perl/5.20.2_Oracle11/lib/5.20.2
.
```

This repository is for additional libraries, or newer versions which we don't want
to install into the official Voyager locations.

