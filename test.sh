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