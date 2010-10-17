use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Maplat::Web::ComputerDB',
    VERSION_FROM      => 'lib/Maplat/Web/ComputerDB.pm', # finds $VERSION
    PREREQ_PM         => {
	    Maplat	=> 0.994,
            "PDF::Report" => 0,
            "WWW::Mechanize" => 0,
            "Readonly" => 0,
	    "HTML::TableExtract"	=> 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (#ABSTRACT_FROM  => 'lib/Maplat/Web/Logging.pm', # retrieve abstract from module
       AUTHOR         => 'Rene Schickbauer <rene.schickbauer@gmail.com>') : ()),
);
