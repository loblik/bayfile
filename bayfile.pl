#!/usr/bin/perl

use strict;
use warnings;

use constant URL => 'http://api.bayfiles.com/v1';

use JSON;
use WWW::Curl::Easy;
use WWW::Curl::Form;
use Digest::SHA;
use Getopt::Std;

$|=1;

my $curl;
my $filename;

sub progress_callback {

  my ($clientp,$dltotal,$dlnow,$ultotal,$ulnow) = @_;

  my $pct = 0;
  my $human = readable_size($ulnow);

  $pct = $ulnow * 100.0 / $ultotal if $ultotal;

  printf "\r%d/%db %s done [%d%%]   ", $ulnow, $ultotal, $human ,$pct;

  return 0;
}

sub compute_digest {

  my $file = $_[0];
  open my $fh, $file || die "cannot open file";
  
  binmode($fh);
  my $sha = Digest::SHA->new->addfile($fh)->hexdigest;
  close ($fh);

  return $sha;
}

sub parse_json {
  
  my ($response) = @_;

  # invalid JSON when asking for state
  if ($response =~ /(.*);/) {
    $response =~ s/\((.*)\);/$1/;
  }

  my $json_hash = decode_json($response);

  if (defined($json_hash->{'error'}) and 
      $json_hash->{'error'} ne '') {

    print "service error: ".$json_hash->{'error'}."\n";
    exit 2;
  }

  return $json_hash;
}

sub make_request {

  my ($url) = @_;
  my $response;

  $curl->setopt(CURLOPT_URL, $url);
  $curl->setopt(CURLOPT_WRITEDATA,\$response);

  if (my $retcode = $curl->perform) {
    
    print("req error: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
    exit 2;
  }

  return parse_json($response);
}

sub do_upload {

  my ($url) = @_;

  my $curlf = WWW::Curl::Form->new;

  $curlf->formaddfile($filename, 'file', "multipart/form-data" );

  my $response;

  $curl->setopt(CURLOPT_URL, $url);
  $curl->setopt(CURLOPT_WRITEDATA,\$response);
  $curl->setopt(CURLOPT_HTTPPOST, $curlf);
  $curl->setopt(CURLOPT_PROGRESSFUNCTION, \&progress_callback);
  $curl->setopt(CURLOPT_NOPROGRESS, 0);

  my $retcode = $curl->perform;

  if ($retcode != 0) {

    print "\n";
    print("error: ".$curl->errbuf."\n");
    return 2;
  }

  my $resp_array = parse_json($response);

  if ($resp_array->{'sha1'} ne compute_digest($filename)) {

    print "error digest mismatch, upload failed\n";
    return 2;
  }

  my $file_id = $resp_array->{'fileId'};
  my $file_info = $resp_array->{'infoToken'};

  print "\n";
  print " ".$resp_array->{'deleteUrl'}." [delete]\n";
  print " ".$resp_array->{'linksUrl'}." [links]\n";
  print " ".$resp_array->{'downloadUrl'}." [download]\n";
}

sub readable_size { 

  my ($val) = @_;
  my $unit = 'b';

  $val /= 1024.0 and $unit = 'kB' if $val > 1024;
  $val /= 1024.0 and $unit = 'MB' if $val > 1024;
  $val /= 1024.0 and $unit = 'GB' if $val > 1024;

  return sprintf "%.2f %s", $val, $unit;
}

sub upload_file {

  $curl = WWW::Curl::Easy->new;
  $curl->setopt(CURLOPT_HEADER,0);

  my $array = make_request(URL . '/file/uploadUrl');

  do_upload($array->{'uploadUrl'});
}

sub print_usage {

  print STDERR << "EOF";
usage: bayfile [OPTIONS] [FILE] ...

options:
  -h  print this help end exit

EOF
   exit 0;
}

my %opt;
getopts( "h", \%opt ) or usage();

print_usage() if $opt{'h'};
print_usage() if (@ARGV == 0);

my $return_value = 0;

while ($filename = shift @ARGV) {

  $return_value = 1 if upload_file();
}

exit $return_value;

