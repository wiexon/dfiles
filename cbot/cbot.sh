#!/bin/bash

# Function to display help message
usage() {
  cat << EOF
Usage: $0 [OPTION [ARGUMENT]] COMMAND

  Options:

  -h                  Display this help message.
  -d <DomainName>     Specify the domain(s) for issuing the certificate. Multiple domains can be specified (e.g., -d example.com -d www.example.com).
  -s                  Generate a self-signed certificate (not recommended for production use).
  -n <DockerNetwork>  Specify the Docker network name to use (default: intranet).
  -v <DockerVolume>   Specify the Docker volume or directory location to store Let's Encrypt data (default: /etc/letsencrypt).
  -p                  Open port 80 temporarily for domain verification.
  -H <HAProxyDocName> Specify the HAProxy Docker Container name

  Commands:

  new                 Issue a new certificate.
  renew               Renew existing certificates.

  Example:
  $0 -d example.com -n intranet -v /bsse/letsencrypt -p new
  $0 -n intranet -v /base/letsencrypt -p renew

EOF
  exit 1
}

process_common_name(){
  #input="-d example.com -d www.example.com -d 210.10.10.40"
  local input="$*"
  COMNAME=$(echo $input | grep -oE '^\-d\s+[A-Za-z0-9\-\.\_]+' | awk '{ print $2 }')
}

process_alt_names(){
  #input="-d example.com -d www.example.com -d 210.10.10.40"
  local input="$*"
  ALTNAMES="[alt_names]"

  # Use grep to find all occurrences of '-d' followed by a string
  local matches
  matches=$(echo "$input" | grep -oE '\-d\s+[A-Za-z0-9\-\.\_]+')

  local index_dns=1
  local index_ip=1

  # Loop through each match and extract the value after '-d'
  while read -r match; do
      local value
      value=$(echo "$match" | awk '{print $2}')
      #echo "Found value: $value"

      # processing logic here
      if [[ $value =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          ALTNAMES="$ALTNAMES\nIP.$index_ip = $value"
          ((index_ip++))
      else
          ALTNAMES="$ALTNAMES\nDNS.$index_dns = $value"
          ((index_dns++))
      fi

  done <<< "$matches"
}

generate_self_signed_cert() {
  process_common_name "$DOMAINS"
  process_alt_names "$DOMAINS"

  DOMAIN=$COMNAME
  CERT_DIR=$VOLUME/rclive
  SSCERT_DIR=$VOLUME/sscerts/$DOMAIN

  # Check for openssl tool
  if ! command -v openssl &> /dev/null; then
    # Install openssl based on package manager
    if command -v yum &> /dev/null; then
      yum install -y openssl
    elif command -v apt &> /dev/null; then
      apt-get install -y openssl
    elif command -v apk &> /dev/null; then
      apk add openssl
    else
      echo "Error: Unable to determine package manager to install openssl."
      exit 1
    fi
  fi

  # Create a temporary directory
  #TMP_DIR=$(mktemp -d)
  rm -rf $SSCERT_DIR
  mkdir -p $SSCERT_DIR
  TMP_DIR=$SSCERT_DIR
  # Change to the temporary directory
  pushd "$TMP_DIR" || exit 1

  # Generate the certificate (using your existing code)
  openssl req -x509 \
             -sha256 -days 3650 \
             -nodes \
             -newkey rsa:2048 \
             -subj "/CN=${DOMAIN}/C=US/L=Houston" \
             -keyout rootCA.key -out rootCA.crt
  openssl genrsa -out ${DOMAIN}.key 2048
  cat > csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = Texus
L = Houston
O = Company
OU = Cert
CN = ${DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

$(echo -e "$ALTNAMES")

EOF
  openssl req -new -key ${DOMAIN}.key -out ${DOMAIN}.csr -config csr.conf
  cat > cert.conf <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

$(echo -e "$ALTNAMES")

EOF

  openssl x509 -req \
      -in ${DOMAIN}.csr \
      -CA rootCA.crt -CAkey rootCA.key \
      -CAcreateserial -out ${DOMAIN}.crt \
      -days 3650 \
      -sha256 -extfile cert.conf

  cat ${DOMAIN}.crt ${DOMAIN}.key > ${DOMAIN}.pem

  # Create the cert directory if not exists
  mkdir -p "$CERT_DIR"

  # Move the PEM file to the desired directory and set permissions
  rm -rf "$CERT_DIR/${DOMAIN}.pem"
  mv "${DOMAIN}.pem" "$CERT_DIR"
  chmod 600 "$CERT_DIR/${DOMAIN}.pem"

  popd || exit 0
}

check_docker_installed() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker before proceeding."
    exit 1
  fi

  echo "Docker is installed."
}

create_deploy_hook() {
  file_location="$VOLUME/renewal-hooks/deploy"
  file_path="$file_location/todeploy.sh"

  if [[ ! -f "$file_path" ]]; then
    mkdir -p $file_location
    cat > "$file_path" <<"EOF"
#!/bin/sh

# Set the path to the Let's Encrypt lineage directory
lineage_dir="$RENEWED_LINEAGE"

# Extract the domain name from the lineage directory
domain_name=$(basename "$lineage_dir")

# Set the output directory and file name for the combined PEM file
output_dir="/etc/letsencrypt/rclive"
output_file="$output_dir/$domain_name.pem"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Deleting the existing certificate before creating the new one
rm -rf "$output_file"

# Concatenate the full chain and private key contents into a new PEM file
cat "$lineage_dir/fullchain.pem" "$lineage_dir/privkey.pem" > "$output_file"

echo "PEM file updated at: $output_file"
EOF

    chmod +x "$file_path"
    echo "Deploy Hook Created and made executable: $file_path"
  else
    echo "Deploy Hook File already exists: $file_path"
  fi
}

verify_fqdn() {
  local domain_name="$1"

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

set_doc_net() {
  # Check if the Docker network exists
  if ! docker network ls | grep -q "$DOCNET"; then
    # If it doesn't exist, create it
    docker network create "$DOCNET"
    echo "Created Docker network: $DOCNET"
  else
    echo "Docker network exists: $DOCNET"
  fi
}

new_cert() {
  process_common_name
  local CERT_NAME=$COMNAME

  docker run -it --rm --name certbot --network $DOCNET -v "$VOLUME:/etc/letsencrypt" -v "/var/log/letsencrypt:/var/log/letsencrypt" $DOCEPORT certbot/certbot certonly --standalone --cert-name $CERT_NAME $DOMAINS

  if [[ $? -eq 0 ]]; then  # Check if certificate issuance was successful
    rm -rf /etc/letsencrypt/rclive/$CERT_NAME.pem
    cat /etc/letsencrypt/live/$CERT_NAME/fullchain.pem /etc/letsencrypt/live/$CERT_NAME/privkey.pem > /etc/letsencrypt/rclive/$CERT_NAME.pem
    docker kill --signal=HUP $HAPROXY_DCN || true
  else
    echo "Failed to issue certificate for $CERT_NAME."
  fi
}

renew_cert() {
  docker run -it --rm --name certbot --network $DOCNET -v "$VOLUME:/etc/letsencrypt" -v "/var/log/letsencrypt:/var/log/letsencrypt" $DOCEPORT certbot/certbot renew
  docker kill --signal=HUP $HAPROXY_DCN || true
}


# Initialize variables and scanning flags and agruments
DOMAINS=""
SELFSIGNED=false
DOCNET=intranet
VOLUME=/etc/letsencrypt
DOCEPORT=""
HAPROXY_DCN="haproxy"
while getopts ":hspd:n:v:H:" opt; do
  case $opt in
    h)
      usage
      ;;
    d)
      if [ -z "$OPTARG" ]; then
        echo "Error: -d argument requires a FQDN or IP address"
        exit 1
      fi
      DOMAINS="$DOMAINS -d $OPTARG"
      ;;
    s)
      if [ -n "$OPTARG" ]; then
        echo "Error: -s requires no argument"
        exit 1
      fi
      SELFSIGNED=true
      ;;
    n)
      if [ -z "$OPTARG" ]; then
        echo "Error: -n argument requires a name of docker network"
        exit 1
      fi
      DOCNET=$OPTARG
      ;;
    v)
      if [ -z "$OPTARG" ]; then
        echo "Error: -v argument requires a directory location for letsencrypt and certificates"
        exit 1
      fi
      VOLUME=$OPTARG
      ;;
    p)
      if [ -n "$OPTARG" ]; then
        echo "Error: -p requires no argument"
        exit 1
      fi
      DOCEPORT="-p 80:80"
      ;;
    H)
      if [ -z "$OPTARG" ]; then
        echo "Error: -H argument requires HAProxy Docker Container Name"
        exit 1
      fi
      HAPROXY_DCN=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done


mkdir -p "$VOLUME/rclive"
mkdir -p "$VOLUME/sscerts"

# Shift arguments to get the command and remaining arguments
shift $((OPTIND-1))
CMD=$1



# Check if the command is valid
if [[ "$CMD" = "new" ]]; then
  if [[ "$SELFSIGNED" == "true" ]]; then
    echo "Generating Self-signed certificate."
    generate_self_signed_cert
  else
    echo "Requesting certificate to letsencrypt authority."
    check_docker_installed
    set_doc_net
    new_cert
    create_deploy_hook
  fi
elif [[ "$CMD" = "renew" ]]; then
  echo "Certificate renew is requesting to letsencrypt authority."
  check_docker_installed
  set_doc_net
  create_deploy_hook
  renew_cert
else
  echo "Invalid command: '$CMD'" >&2
  usage
fi
