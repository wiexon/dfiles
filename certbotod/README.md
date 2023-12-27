# Certbotod User Guide

## Overview

The certbotod script automates the management of SSL certificates. It supports renewing existing certificates and creating new ones, with options for self-signed certificates and self-verification.

## Installation

```Bash
# Download the file
wget -O /usr/local/bin/certbotod https://raw.githubusercontent.com/wiexon/dfiles/main/certbotod/certbotod.sh

# Make the file executable
chmod +x /usr/local/bin/certbotod
```
Alternatively you can clone the project and run `sh install-certbotod.sh`

## Usage

```Bash
./certbotod <command> [options]
```

## Commands:
* **renew**: Renews an existing certificate.
* **new**: Creates a new certificate.

## Options for the new command:

* **-s** : Silent mode. Skips interactive prompts and requires providing all information through options.
* **-d \<domain\>** : Specifies the domain name for the certificate. Required in silent mode.
* **-g** : Generates a self-signed certificate.
* **-v** : Performs self-verification, mapping ports 80 and 443 for the verification process.


## Interactive Input (without -s flag):
If not running in silent mode, the script will prompt for the domain name, ask whether to create a self-signed certificate, and optionally ask about self-verification.

## Additional Notes:
The script assumes the presence of functions like renew_cert, verify_fqdn, issue_self_signed_cert, and issue_new_cert for specific certificate operations.
Always ensure you have the necessary permissions to manage SSL certificates on your system.