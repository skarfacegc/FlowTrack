#!/usr/bin/perl
use strict ;
use Net::Flow qw(decode) ;
use IO::Socket::INET;
use Data::Dumper;
use Socket;



# { 'Length'=>4,'Id'=>8  }, # SRC_ADDR
# { 'Length'=>4,'Id'=>12 }, # DST_ADDR
# { 'Length'=>4,'Id'=>15 }, # NEXT-HOP
# { 'Length'=>2,'Id'=>10 }, # INPUT
# { 'Length'=>2,'Id'=>14 }, # OUTPUT
# { 'Length'=>4,'Id'=>2  }, # PKTS
# { 'Length'=>4,'Id'=>1  }, # BYTES
# { 'Length'=>4,'Id'=>22 }, # FIRST
# { 'Length'=>4,'Id'=>21 }, # LAST
# { 'Length'=>2,'Id'=>7  }, # SRC_PORT 
# { 'Length'=>2,'Id'=>11 }, # DST_PORT
# { 'Length'=>1,'Id'=>0  }, # PADDING
# { 'Length'=>1,'Id'=>6  }, # FLAGS
# { 'Length'=>1,'Id'=>4  }, # PROT
# { 'Length'=>1,'Id'=>5  }, # TOS
# { 'Length'=>2,'Id'=>16 }, # SRC_AS
# { 'Length'=>2,'Id'=>17 }, # DST_AS
# { 'Length'=>1,'Id'=>9  }, # SRC_MASK
# { 'Length'=>1,'Id'=>13 }, # DST_MASK
# { 'Length'=>2,'Id'=>0  }  # PADDING



my $receive_port = 2055 ;
my $packet = undef ;
my $TemplateArrayRef = undef ;
my $sock = IO::Socket::INET->new( LocalPort =>$receive_port, Proto => 'udp') ;

while ($sock->recv($packet,1548)) {

    my ($HeaderHashRef,$FlowArrayRef,$ErrorsArrayRef)=() ;
    
    ( $HeaderHashRef,
      $TemplateArrayRef,
      $FlowArrayRef,
      $ErrorsArrayRef)
	= Net::Flow::decode(
	\$packet,
	$TemplateArrayRef
	) ;
 
    print "Header\n" . Dumper($HeaderHashRef);
    print "Template\n" . Dumper($TemplateArrayRef);
    print "ArrayRef\n" . Dumper($FlowArrayRef);
    print "Errors\n". Dumper($ErrorsArrayRef);

    print "\n- Header Information -\n" ;
    foreach my $Key ( sort keys %{$HeaderHashRef} ){
	printf " %s = %3d\n",$Key,$HeaderHashRef->{$Key} ;
    }

    foreach my $TemplateRef ( @{$TemplateArrayRef} ){
	print "\n-- Template Information --\n" ;

	foreach my $TempKey ( sort keys %{$TemplateRef} ){
	    if( $TempKey eq "Template" ){
		printf "  %s = \n",$TempKey ;
		foreach my $Ref ( @{$TemplateRef->{Template}}  ){
		    foreach my $Key ( keys %{$Ref} ){
			printf "   %s=%s", $Key, $Ref->{$Key} ;
		    }
		    print "\n" ;
		}
	    }else{
		printf "  %s = %s\n", $TempKey, $TemplateRef->{$TempKey} ;
	    }
	}
    }

    foreach my $FlowRef ( @{$FlowArrayRef} ){
	print "\n-- Flow Information --\n" ;

	foreach my $Id ( sort keys %{$FlowRef} ){
	    if( $Id eq "SetId" ){
		print "  $Id=$FlowRef->{$Id}\n" if defined $FlowRef->{$Id} ;
	    }elsif( ref $FlowRef->{$Id} ){
		printf "  Id=%s Value=",$Id ;
		foreach my $Value ( @{$FlowRef->{$Id}} ){
		    printf "%s,",unpack("H*",$Value) ;
		}
		print "\n" ;
	    }else{
		printf "  Id=%s Value=%s\n",$Id,unpack("H*",$FlowRef->{$Id}) ;
            }
        }
    }
}
