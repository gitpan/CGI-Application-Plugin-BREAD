use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		    => 'CGI::Application::Plugin::BREAD',
    'VERSION_FROM'	=> 'lib/CGI/Application/Plugin/BREAD.pm', # finds $VERSION
    'PREREQ_PM'		=>  {
                            'CGI::Application'  => 4.0,
                            'HTML::Template'    => 1,
                            'HTML::FillInForm'  => 1,
                            'HTML::Pager'       => 0.03,
			    'Class::DBI::FormBuilder'	=> 0,
			    'Class::DBI'		=> 0
                        }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (AUTHOR       => 'Jason Purdy <jason@purdy.info>') : ()),
);
