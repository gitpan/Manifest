#-*-perl-*-

use ExtUtils::MakeMaker;
WriteMakefile(NAME => 'File::Manifest',
	      PREREQ_PM => { File::Recurse => 0, Checksum::External => 0 },
	      EXE_FILES => ['manifest'],
	      VERSION_FROM => 'Manifest.pm',
              'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'},
	      );
