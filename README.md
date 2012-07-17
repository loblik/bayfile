# bayfile

Is a simple client to [bayfiles.com][bayfiles] file sharing service. It's written in Perl and it uses official JSON API of the website.

## features

* upload a file 
* show transfer progress
* verify file integrity (compare digests)

## dependencies

All you need is Perl and following packages. If these are not shipped with your distribution you can [get them from CPAN][cpan].


* WWW::Curl::Simple
* JSON
* Digest::SHA

## usage

[bayfiles]: http://bayfiles.com/ "bayfiles.com"
[cpan]: http://www.cpan.org/modules/INSTALL.html "How to install CPAN modules"
