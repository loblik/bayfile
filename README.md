# bayfile

Is a simple command-line client to [bayfiles.com][bayfiles] file sharing service. It's written in Perl and it uses official JSON API of the website.

## features

* upload a file 
* show transfer progress
* verify file integrity (compare digests)
* allow logging in
* listing files

## dependencies

All you need is Perl and following modules. If some of them is not shipped with your distribution you can [get it from CPAN][cpan].


* WWW::Curl::Simple
* JSON
* Digest::SHA

## usage
    usage: bayfile [OPTIONS] [FILE] ...
    
    options:
      -h  print this help end exit
      -u  username
      -p  password

    account options:
      -l  list files

## bugs/contact

If you have found something or you have some idea how to improve the script and you are not using github you can reach me in some other way.

* mail: lobl.pavel [at] gmail.com
* irc: loblik (freenode, twice-irc)
* jabber: loblik [at] jabber.cz

[bayfiles]: http://bayfiles.com/ "bayfiles.com"
[cpan]: http://www.cpan.org/modules/INSTALL.html "How to install CPAN modules"
