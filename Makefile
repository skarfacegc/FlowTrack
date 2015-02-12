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

stop:
	-kill `cat log/main.pid`

clean: stop
	rm -rf cover_db/ TEST_FT_* tests_results.xml


distclean: stop clean
	rm Data/* log/*

run: stop
	sleep 2;
	./FlowTrack.pl

cleanrun: stop distclean run