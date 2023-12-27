verify_fqdn() {
  domain_name="$1"

  # Check for valid characters and structure
  if [[ ! "$domain_name" =~ ^[a-z0-9.-]+$ ]]; then
    echo "Invalid characters in domain name."
    exit 1
  fi

  # Ensure at least one dot and a top-level domain
  if [[ ! "$domain_name" =~ \. || ! "$domain_name" =~ \.[a-z]{2,}$ ]]; then
    echo "Invalid domain name format. Must be a fully qualified domain name (FQDN)."
    exit 1
  fi

  echo "Valid FQDN: $domain_name"
}
ff="aman.com"
verify_fqdn $ff



# This is a general haproxy model file
defaults
 mode http
 timeout connect 5000ms
 timeout client 50000ms
 timeout server 50000ms
 timeout tunnel  1h    # timeout to use with WebSocket and CONNECT

#enable resolving throught docker dns and avoid crashing if service is down while proxy is starting
resolvers docker_resolver
  nameserver dns 127.0.0.11:53


frontend stats
 bind *:8000
 stats enable
 stats hide-version
 stats uri /stats
 stats refresh 10s
 stats auth admin:HAPROXYSTAT_PASS


frontend http
 bind *:80
 acl letsencrypt_http_acl path_beg /.well-known/acme-challenge/
 redirect scheme https if !letsencrypt_http_acl
 use_backend letsencrypt_http if letsencrypt_http_acl
 # default_backend db


frontend https
 bind *:443 ssl crt /usr/local/etc/haproxy/certs/
 default_backend letsencrypt_http


backend letsencrypt_http
 server letsencrypt_http_server certbot:80 resolvers docker_resolver resolve-prefer ipv4
