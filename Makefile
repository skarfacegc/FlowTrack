jenkins: 
	cover --delete
	PERL5OPT=-MDevel::Cover=-coverage,statement,branch,subroutine,time,+ignore,".*prove.*","\.t" prove -r --timer --formatter=TAP::Formatter::JUnit > test_results.xml
	cover -report html
	cover -report clover
test: 
	prove -Pretty -r --verbose
cover: 
	cover --delete
	PERL5OPT=-MDevel::Cover=-coverage,statement,branch,subroutine,time,+ignore,".*prove.*","\.t" prove -r 
	sleep 2
	cover --launch
clean: 
	rm -rf cover_db/ TEST_FT_* tests_results.xml
distclean: clean
	rm Data/* log/*
