package PRC::GitHub;
use namespace::autoclean;

use LWP::UserAgent;
use JSON::XS;
use YAML qw/LoadFile/;

=encoding utf8

=head1 NAME

PRC::GitHub - A Quick Library for GitHub calls

=head1 DESCRIPTION

This is a library to abstract GitHub calls, both POST and GET.
This library can use some optimization, but I avoided doing so for now.
Ideas: Don't create ua for each call, don't read secrets so many times, etc.

=head1 METHODS

=head2 authenticate_url

  $c->response->redirect(PRC::GitHub->authenticate_url);
  $c->detach;

Returns URL for GitHub authentication. Puts client_id in.

=cut

sub authenticate_url {
  my ($self) = @_;
  my $client_id = YAML::LoadFile('secrets.yml')->{client_id};
  return "https://github.com/login/oauth/authorize?scope=user%3Aemail&client_id=$client_id";
}

=head2 access_token

  my $token = PRC::GitHub->access_token('code');

Makes a POST to oauth/access_token and returns access_token.
If it errors, returns undef.

=cut

sub access_token {
  my ($self,$code) = @_;
  return undef unless $code;

  my $secrets   = YAML::LoadFile('secrets.yml');
  my $data_post = {
    code          => $code,
    client_id     => $secrets->{client_id},
    client_secret => $secrets->{client_secret},
  };

  my $ua = LWP::UserAgent->new;
  $ua->agent("PullRequestClub/0.1");

  my $req = HTTP::Request->new(POST => 'https://github.com/login/oauth/access_token');
  $req->content_type('application/json');
  $req->header(Accept => 'application/json');
  $req->content(encode_json($data_post));

  my $res = $ua->request($req);
  return undef unless $res->is_success;
  my $data = eval { decode_json($res->content) };
  return undef unless $data;
  return $data->{access_token};
}

=head2 user_data

  my $user_data = PRC::GitHub->user_data('access_token');

Makes a GET to /user, and returns user details in a hashref.
If it errors, returns undef.

=cut

sub user_data {
  my ($self, $token) = @_;
  return undef unless $token;

  my $ua = LWP::UserAgent->new;
  $ua->agent("PullRequestClub/0.1");

  my $req = HTTP::Request->new(GET => 'https://api.github.com/user');
  $req->header(Authorization => "token $token");
  $req->header(Accept => 'application/vnd.github.v3+json');

  my $res = $ua->request($req);
  return undef unless $res->is_success;
  my $data = eval { decode_json($res->content) };
  return $data;
}

=head2 primary_email

  my $primary_email = PRC::GitHub->primary_email($token);

Makes a GET to /user/emails, returns primary email address.
Returns undef on any error.

=cut

sub primary_email {
  my ($self, $token) = @_;
  return undef unless $token;

  my $ua = LWP::UserAgent->new;
  $ua->agent("PullRequestClub/0.1");

  my $req = HTTP::Request->new(GET => 'https://api.github.com/user/emails');
  $req->header(Authorization => "token $token");
  $req->header(Accept => 'application/vnd.github.v3+json');

  my $res = $ua->request($req);
  return undef unless $res->is_success;
  my $data = eval { decode_json($res->content) };

  # "data" is an arrayref of hashes
  # each item has keys email, primary, verified, visibility.
  # we will get email of first one that has primary = true
  my @primary_emails = grep {$_->{primary}} @$data;
  my $primary_email  = $primary_emails[0];
  return $primary_email->{email};
}

1;
