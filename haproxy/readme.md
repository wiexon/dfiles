# HAProxy Configuration File (haproxy.cfg) Cheat Sheet

General Syntax:

- Lines starting with # are comments.
- Configuration blocks are enclosed in curly braces { }.
- Indentation is not required but improves readability.
- Keywords are case-insensitive.

Global Configuration:

- global: Encloses global settings for HAProxy.
- Common directives:
    - maxconn: Maximum concurrent connections.
    - log: Logging configuration.
    - chroot: Change root directory for security.
    - user: Switch to a different user account.
    - daemon: Run as a daemon in the background.

Frontends:

- frontend <name>: Defines a frontend responsible for accepting incoming connections.
- Common directives:
    - bind: Binds to a specific IP address and port.
    - mode: Sets the load balancing mode (e.g., http, tcp).
    - default\_backend: Specifies the default backend to use.
    - acl: Defines access control lists for traffic routing.
    - use\_backend <backend\_name> if <condition>: Conditionally routes traffic to different backends based on ACLs.

Backends:

- backend <name>: Defines a backend group of servers for load balancing.
- Common directives:
    - server <name> <address>:<port>: Adds a server to the backend.
    - balance: Sets the load balancing algorithm (e.g., roundrobin, leastconn).
    - option: Sets various backend options (e.g., httpchk, redispatch).
    - default <option> <value>: Sets default values for options within the backend.

Other Directives:

- listen: Combines frontend and backend definitions for convenience.
- defaults: Sets default values for frontends and backends.

Example Configuration:

```lombok.config
global
    maxconn 2000
    log /dev/log local0

frontend http
    bind *:80
    mode http
    acl is_admin path_beg /admin
    use_backend admin_servers if is_admin
    default_backend webservers

backend webservers
    balance roundrobin
    default-server inter 30s fall 3 rise 2
    server web1 192.168.1.10:80 check
    server web2 192.168.1.11:80 check
```

Additional Notes:

- Refer to the official HAProxy documentation for a comprehensive list of directives and options.
- Test your configuration thoroughly before deploying it in a production environment.
- Use tools like haproxy -c -f haproxy.cfg to check for configuration errors.





___




here is an example to route to different port with ssl along with complex ACL 

```
frontend https_dev
 bind *:448 ssl crt /usr/local/etc/haproxy/certs/
 option forwardfor
 http-request add-header "X-Forwarded-Proto" "https" 
 
 acl app_be_domain       hdr(host) -i dev.${PLATFORM_FQDN}:448
 acl nr_one_domain   hdr(host) -i one.nr.${PLATFORM_FQDN}:448
 acl nr_two_domain  hdr(host) -i two.nr.${PLATFORM_FQDN}:448
 acl nr_api_domain       hdr(host) -i api.nr.${PLATFORM_FQDN}:448
 
 acl tb_api_acl           path_beg /api/ /v2/ /v3/ /oauth2/ /login/oauth2/ /swagger /webjars /static/rulenode/ /static/widgets/

 acl contents_route      path_beg /contents/
 acl api_link_route   path_beg /api_link/

 use_backend aws-be if app_be_domain !tb_api_acl !api_link_route !contents_route
 use_backend be_two if app_be_domain tb_api_acl
 use_backend be_one if app_be_domain contents_route
 use_backend be_api if app_be_domain api_link_route
 use_backend nr_one_backend if nr_one_domain
 use_backend nr_two_backend if nr_two_domain
 use_backend be_api if nr_api_domain
 #default_backend db
```


Example to setup a beckend link to aws or similler:

```
backend aws-be
 http-request set-header Host public-bucket-name.s3-website-ap-southeast-1.amazonaws.com
 server tbd1 public-bucket-name.s3-website-ap-southeast-1.amazonaws.com:80

```