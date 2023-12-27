#!/bin/bash

parse_flag() {
  OPTION_LETTER="$1"
  shift

  while getopts ":$OPTION_LETTER" opt; do
    case $opt in
      "$OPTION_LETTER")
        VAR_INPUT="yes"
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
      :)
        echo "Option -$OPTARG does not require an argument." >&2
        exit 1
        ;;
    esac
  done

  shift $((OPTIND-1))

  # If the option wasn't found, set VAR_INPUT to "no"
  VAR_INPUT="${VAR_INPUT:-no}"
}

#parse_flag f "$@"  # Use -f for this call
# Now you can check $VARIABLE_INPUT to see if -f was present


parse_args() {
  OPTION_LETTER="$1"
  shift

  while getopts ":$OPTION_LETTER:" opt; do
    case $opt in
      "$OPTION_LETTER")
        VAR_INPUT="$OPTARG"
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
  done

  shift $((OPTIND-1))
}

#parse_args s "$@"  # Use -s for this call
# Now you can access $VARIABLE_INPUT if -s was provided

#parse_args t "$@"  # Use -t for this call
# Now you can access $VARIABLE_INPUT if -t was provided


generate_self_signed_cert() {
  DOMAIN=$1
  CERT_DIR=$2

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
  TMP_DIR=$(mktemp -d)

  # Change to the temporary directory
  cd "$TMP_DIR"

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
O = Wiexon LLC
OU = DevOps
CN = ${DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
IP.1 = 127.0.0.1

EOF
  openssl req -new -key ${DOMAIN}.key -out ${DOMAIN}.csr -config csr.conf
  cat > cert.conf <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
IP.1 = 127.0.0.1

EOF

  openssl x509 -req \
      -in ${DOMAIN}.csr \
      -CA rootCA.crt -CAkey rootCA.key \
      -CAcreateserial -out ${DOMAIN}.crt \
      -days 3650 \
      -sha256 -extfile cert.conf

  cat ${DOMAIN}.crt ${DOMAIN}.key > ${DOMAIN}.pem

  # Move the PEM file to the desired directory and set permissions
  mv ${DOMAIN}.pem "$CERT_DIR"
  chmod 600 "$CERT_DIR/${DOMAIN}.pem"

  # Clean up temporary files
  cd ..
  rm -rf "$TMP_DIR"
}


check_docker_installed() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker before proceeding."
    exit 1
  fi

  echo "Docker is installed."
}

create_deploy_hook() {
  file_location="/etc/letsencrypt/renewal-hooks/deploy"
  file_path="$file_location/todeploy.sh"

  if [[ ! -f "$file_path" ]]; then
    mkdir -p $file_location
    cat <<EOF > "$file_path"
#!/bin/sh

# Set the path to the Let's Encrypt lineage directory
lineage_dir="$RENEWED_LINEAGE"

# Extract the domain name from the lineage directory
domain_name=$(basename "$lineage_dir")

# Set the output directory and file name for the combined PEM file
output_dir="/etc/letsencrypt/live-pem"
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
    echo "Created and made executable: $file_path"
  else
    echo "File already exists: $file_path"
  fi
}

verify_fqdn() {
  domain_name="$1"

  # Check for valid characters and structure
  if [[ ! "$domain_name" =~ ^[a-zA-Z0-9\-.]+$ ]]; then
    echo "Invalid characters in domain name."
    exit 1
  fi

  # Ensure at least one dot and a top-level domain
  if [[ ! "$domain_name" =~ \. || ! "$domain_name" =~ \.[a-zA-Z]{2,}$ ]]; then
    echo "Invalid domain name format. Must be a fully qualified domain name (FQDN)."
    exit 1
  fi

  echo "Valid FQDN: $domain_name"
}

DOC_NET="$2"
set_doc_net() {
  # If the second argument is provided, use it as the network name
  if [[ -n "$DOC_NET" ]]; then
    echo "updating the default docker network to $DOC_NET"
  else
    # Otherwise, set the default network name
    DOC_NET="wiexon"
  fi

  # Check if the Docker network exists
  if ! docker network ls | grep -q "$DOC_NET"; then
    # If it doesn't exist, create it
    docker network create "$DOC_NET"
    echo "Created Docker network: $DOC_NET"
  else
    echo "Docker network $DOC_NET already exists."
  fi
}


issue_self_signed_cert() {
  generate_self_signed_cert $DOMAIN /etc/letsencrypt/live-pem
}

issue_new_cert() {
  /usr/bin/docker run -it --rm --name certbot --network $DOC_NET -v "/etc/letsencrypt:/etc/letsencrypt" -v "/var/log/letsencrypt:/var/log/letsencrypt" $SELF_VERIFY_PORTS certbot/certbot certonly --standalone -d $DOMAIN

  if [[ $? -eq 0 ]]; then  # Check if certificate issuance was successful
    rm -rf /etc/letsencrypt/live-pem/$DOMAIN.pem
    cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/privkey.pem > /etc/letsencrypt/live-pem/$DOMAIN.pem
    /usr/bin/docker kill --signal=HUP haproxy || true
  else
    echo "Failed to issue certificate for $DOMAIN."
  fi
}

renew_cert() {
  create_deploy_hook
  /usr/bin/docker run -it --rm --name certbot --network $DOC_NET -v "/etc/letsencrypt:/etc/letsencrypt" -v "/var/log/letsencrypt:/var/log/letsencrypt" certbot/certbot renew
  /usr/bin/docker kill --signal=HUP haproxy || true
}


check_docker_installed
set_doc_net

if [[ $1 == "renew" ]]; then
  renew_cert
elif [[ $1 == "new" ]]; then

  parse_flag s "$@"
  SILENT=$VAR_INPUT
  if [[ $SILENT == "yes" ]]; then
    echo "Silent mode running"
    parse_args d "$@"
    DOMAIN=$VAR_INPUT
    verify_fqdn $DOMAIN
    parse_flag g "$@"
    SELF_SIGNED=$VAR_INPUT
    if [[ $SELF_SIGNED == "yes" ]]; then
      issue_self_signed_cert
    else
      parse_flag v "$@"
      SELF_VERIFY
      if [[ $SELF_VERIFY == "yes" ]]; then
        SELF_VERIFY_PORTS="-p 80:80 -p 443:443"
      else
        SELF_VERIFY_PORTS=""
      fi
      issue_new_cert
    fi
  else
    # Process for manual inputs for new certs
      read -p "Enter the domain name: " DOMAIN
      verify_fqdn $DOMAIN

      read -p "Self Signed? (yes/no) [no]: " SELF_SIGNED
      SELF_SIGNED=${SELF_SIGNED:-"no"}  # Set default to "no" if not provided

      if [[ $SELF_SIGNED == "yes" ]]; then
        issue_self_signed_cert
      else
        read -p "Perform self-verification? (yes/no) [no]: " SELF_VERIFY
        if [[ $SELF_VERIFY == "yes" ]]; then
          SELF_VERIFY_PORTS="-p 80:80 -p 443:443"
        else
          SELF_VERIFY_PORTS=""
        fi
        issue_new_cert
      fi
  fi

else
  echo "Invalid argument. Usage: $0 <renew|new>"
fi
