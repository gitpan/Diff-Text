use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Diff::Text',
    'VERSION_FROM'	=> 'Text.pm',
    'PREREQ_PM'		=> {'Algorithm::Diff' => 1.15, 'HTML::Entities' => 1.23}},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Text.pm', # retrieve abstract from module
       AUTHOR     => 'Joseph F. Ryan <ryan.311@osu.edu>') : ()),
);
