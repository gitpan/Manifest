#-*-perl-*-

use ExtUtils::MakeMaker;

sub MY::dist_basics {
  # otherwise there are two rules for manifest
  # makefiles suck!
}

WriteMakefile(NAME => 'File::Manifest',
	      PREREQ_PM => { File::Recurse => 0 },
	      EXE_FILES => ['manifest'],
	      VERSION_FROM => 'Manifest.pm',
              'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'},
	      );
