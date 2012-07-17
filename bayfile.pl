#!/usr/bin/perl

use strict;
use warnings;

use constant URL => 'http://api.bayfiles.com/v1';

use JSON;
use WWW::Curl::Easy;
use WWW::Curl::Form;
use Digest::SHA;
use Getopt::Std;

use Data::Dumper;

$|=1;

my $curl;
my $filename;
my $session;

my $username;
my $password;

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

  $curl->setopt(CURLOPT_URL, make_url($url));
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

  $curl->setopt(CURLOPT_URL, make_url($url));
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
  my $unit = 'B';

  $val /= 1024.0 and $unit = 'kB' if $val > 1024;
  $val /= 1024.0 and $unit = 'MB' if $val > 1024;
  $val /= 1024.0 and $unit = 'GB' if $val > 1024;

  my $ret;
  
  if ($val == int($val)) {
    $ret = sprintf "%d%s", $val, $unit;
  } else {
    $ret = sprintf "%.2f%s", $val, $unit;
  }

  return $ret;
}

sub make_url {

  my($url) = @_;

  $url = $url."?session=$session" if $session;
  
  return $url;
}

sub start_session {

  my $json_array = make_request(URL . "/account/login/$username/$password");
  $session = $json_array->{'session'};
}

sub end_session {

  my $json_array = make_request(URL . "/account/logout");
}

sub list_files {

  my $json_array = make_request(URL . "/account/files");

  foreach my $file (keys %$json_array) {

    next if $file eq 'error';
    
    my $info_token = $json_array->{$file}->{'infoToken'};
    my $filename = $json_array->{$file}->{'filename'};

    print $file." ";
    print $filename." ";
    print readable_size($json_array->{$file}->{'size'})." ";
    print "http://bayfiles.com/file/$file/$info_token/$filename\n";
  }

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

  -u  username
  -p  password

account options:
  -l  list files

EOF
   exit 0;
}

my %opt;
my $return_value = 0;

getopts("hu:p:l", \%opt);

print_usage() if ($opt{'u'} and !$opt{'p'});
print_usage() if ($opt{'p'} and !$opt{'u'});
  
$username = $opt{'u'} if $opt{'u'};
$password = $opt{'p'} if $opt{'p'};

$curl = WWW::Curl::Easy->new;
print_usage() if $opt{'h'};

start_session($username, $password) if ($opt{'u'});

print_usage() if ($opt{'l'} and !$opt{'u'});

if ($opt{'l'}) {
  list_files();
  goto END;
}

print_usage() if (@ARGV == 0);


while ($filename = shift @ARGV) {

  $return_value = 1 if upload_file();
} 

END:
end_session();

exit $return_value;

