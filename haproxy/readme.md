

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