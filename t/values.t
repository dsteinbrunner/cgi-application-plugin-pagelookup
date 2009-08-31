#!perl  

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
$dbh->do("create table cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path)");
$dbh->do("create table cgiapp_lang (lang, collation)");
$dbh->do("create table cgiapp_values (lang, internalId, param, value)");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('en/test1', 'en', 0, 't/templ/testLO.tmpl', '2009-8-11', 'daily', '0.8', 'HOME', 'PATH')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('en/test2', 'en', 1, 't/templ/testLO.tmpl', '2007-8-11', 'yearly', '0.7', 'HOME1', 'PATH1')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('de/test1', 'de', 0, 't/templ/testLO.tmpl', '2009-8-11', 'daily', '0.8', 'HEIMAT', 'Stra&szlig;e')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('de/test2', 'de', 1, 't/templ/testLO.tmpl', '2007-8-11', 'yearly', '0.7', 'HEIMAT1', 'Stra&szlig;e1')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('en/notfound', 'en', 2, 't/templ/testNLO.tmpl', '2007-8-11', 'never', NULL, 'HOME', 'PATH')");
$dbh->do("insert into  cgiapp_pages (pageId, lang, internalId, template, lastmod, changefreq, priority, home, path) values('de/notfound', 'de', 2, 't/templ/testNLO.tmpl', '2007-8-11', 'never', NULL, 'HEIMAT', 'Stra&szlig;e3')");
$dbh->do("insert into  cgiapp_lang (lang, collation) values('en','GB')");
$dbh->do("insert into  cgiapp_lang (lang, collation) values('de','DE')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('en',null, 'hop', 'Bunnies')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('en',null, 'skip', 'Happy')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('en',null, 'jump', 'Sky')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('de',null, 'hop', 'Hasen')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('de',null, 'skip', 'Gl&uuml;cklich')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('de',null, 'jump', 'Himmel')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('de',1, 'jump', 'Wolken')");
$dbh->do("insert into  cgiapp_values (lang, internalId, param, value) values('de',2, 'jump', 'Blau')");

use CGI;
use TestApp;

$ENV{CGI_APP_RETURN_ONLY} = 1;
use CGI::Application::Plugin::PageLookup::Value;
my $params = {remove=>['template','pageId','internalId','priority','lastmod','changefreq'],notfound_stuff=>1,xml_sitemap_base_url=>'http://xml/', 
	objects=>{
		test1=>'CGI::Application::Plugin::PageLookup::Value',
		test2=>'CGI::Application::Plugin::PageLookup::Value',
		test3=>'CGI::Application::Plugin::PageLookup::Value'
	}
};

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
        my $app = TestApp->new(QUERY => CGI->new(""), PARAMS=>$params);
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

  test1: Bunnies
  test2: Happy
  test3: Sky
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query( CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test1'}));
        response_like(
                $app,
                qr{^Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
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

  test1: Bunnies
  test2: Happy
  test3: Sky
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test2'}));
        response_like(
                $app,
                qr{^Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
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

  test1: Hasen
  test2: Gl&uuml;cklich
  test3: Himmel
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query( CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test1'}));
        response_like(
                $app,
                qr{^Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
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

  test1: Hasen
  test2: Gl&uuml;cklich
  test3: Wolken
  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test2'}));
        response_like(
                $app,
                qr{^Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
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

  test1: Bunnies
  test2: Happy
  test3: Sky

  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'en/test3'}));
        response_like(
                $app,
                qr{^Status: 404\|Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
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

  test1: Hasen
  test2: Gl&uuml;cklich
  test3: Blau

  </body>
  </html>
EOS
;

        my $app = TestApp->new(PARAMS=>$params);
        $app->query(CGI->new({'rm' => 'pagelookup_rm', pageid=>'de/test3'}));
        response_like(
                $app,
                qr{^Status: 404\|Expires: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Date: \w\w\w, \d?\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d \w\w\w\|Encoding: utf-8\|Content-Type: text/html; charset=utf-8$},
                $html,
                'TestApp, notfound'
        );
}
