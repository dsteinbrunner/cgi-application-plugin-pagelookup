#!perl  -T

use strict;
use warnings;
use Test::More tests => 16;
use Test::Differences;
use lib qw(t/lib);

BEGIN {
	use_ok( 'CGI::Application::Plugin::PageLookup' );
}

use DBI;
unlink "t/dbfile";


my $dbh = DBI->connect("dbi:SQLite:t/dbfile","","");
$dbh->do("create table cgiapp_pages (pageId, lang, template, home, path)");
$dbh->do("create table cgiapp_lang (lang, collation)");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('en/test1', 'en', 't/templ/testL.tmpl', 'HOME', 'PATH')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('en/test2', 'en', 't/templ/testL.tmpl', 'HOME1', 'PATH1')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('de/test1', 'de', 't/templ/testL.tmpl', 'HEIMAT', 'Stra&szlig;e')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('de/test2', 'de', 't/templ/testL.tmpl', 'HEIMAT1', 'Stra&szlig;e1')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('en/notfound', 'en', 't/templ/testNL.tmpl', 'HOME', 'PATH')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, template, home, path) values('de/notfound', 'de', 't/templ/testNL.tmpl', 'HEIMAT', 'Stra&szlig;e3')");
$dbh->do("insert into  cgiapp_lang (lang, collation) values('en','GB')");
$dbh->do("insert into  cgiapp_lang (lang, collation) values('de','DE')");

use CGI;
use TestApp;

$ENV{CGI_APP_RETURN_ONLY} = 1;

sub response_like {
        my ($app, $header_re, $body_re, $comment) = @_;

        local $ENV{CGI_APP_RETURN_ONLY} = 1;
        my $output = $app->run;
        my ($header, $body) = split /\r\n\r\n/m, $output;
        $header =~ s/\r\n/|/g;
        like($header, $header_re, "$comment (header match)");
        eq_or_diff($body,      $body_re,       "$comment (body match)");
}

{
        my $app = TestApp->new(QUERY => CGI->new(""), PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        isa_ok($app, 'CGI::Application');

        response_like(
                $app,
                qr{^Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                "Hello World: basic_test",
                'TestApp, blank query',
        );
}

{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HOME
  <p>
  My Path is set to PATH
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query( CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test1'}));
        response_like(
                $app,
                qr{^Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, test1'
        );
}

{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HOME1
  <p>
  My Path is set to PATH1
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test2'}));
        response_like(
                $app,
                qr{^Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, test2'
        );
}


{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de-DE">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HEIMAT
  <p>
  My Path is set to Stra&szlig;e
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query( CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test1'}));
        response_like(
                $app,
                qr{^Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, test1'
        );
}

{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de-DE">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HEIMAT1
  <p>
  My Path is set to Stra&szlig;e1
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test2'}));
        response_like(
                $app,
                qr{^Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, test2'
        );
}

{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HOME
  <p>
  My Path is set to PATH

  My error message for you: en/test3
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test3'}));
        response_like(
                $app,
                qr{^Status: 404\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, notfound'
        );
}

{
my $html=<<EOS
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de-DE">
  <head><title>Test Template</title>
  <body>
  My Home Directory is HEIMAT
  <p>
  My Path is set to Stra&szlig;e3

  My error message for you: de/test3
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>{remove=>['template','pageId'],notfound_stuff=>1});
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test3'}));
        response_like(
                $app,
                qr{^Status: 404\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, notfound'
        );
}