# Certbotod User Guide

## Overview

The certbotod script automates the management of SSL certificates. It supports renewing existing certificates and creating new ones, with options for self-signed certificates and self-verification.

## Installation

```shell
curl -sSL https://raw.githubusercontent.com/wiexon/dfiles/main/certbotod/install.sh | sh
```

Alternatively you can clone the project and run `sh install.sh`

## Usage

```Bash
./certbotod <command> [options]
```

## Commands:
* **renew**: Renews an existing certificate.
* **new**: Creates a new certificate.

## Network Name Option (`-n`)

The `-n <networkName>` option allows you to specify the network name to use for container-based operations. The default network name is `wiexon`.

**Example Usage:**

To renew a certificate using a custom network name:

```bash
certbotod renew -n my-network
```

**Key Points:**

- The `-n` option is available for both `new` and `renew` commands.
- The default network name is `wiexon` if not specified.
- Specifying a custom network name can be useful for managing multiple network environments or isolating certificate operations.

## Options for the new command:

* **-s** : Silent mode. Skips interactive prompts and requires providing all information through options.
* **-d \<domain\>** : Specifies the domain name for the certificate. Required in silent mode.
* **-g** : Generates a self-signed certificate.
* **-v** : Performs self-verification, mapping ports 80 and 443 for the verification process.


## Interactive Input (without -s flag):
If not running in silent mode, the script will prompt for the domain name, ask whether to create a self-signed certificate, and optionally ask about self-verification.

## Cron Job Setup

To automate certificate renewals, you can set up a cron job to run `certbotod renew` regularly. Here's an example configuration that runs the command every day at 3:15 AM without generating any log output:

```bash
15 3 * * * /usr/local/bin/certbotod renew >/dev/null 2>&1
```

**Explanation:**

- **`15 3 * * *`:** This specifies the time and frequency of the job:
    - `15`: Minutes (15th minute of the hour)
    - `3`: Hours (3 AM)
    - `* * *`: Days of the month, months, and days of the week (all values, meaning every day)
- **`/usr/local/bin/certbotod renew`:** The command to execute.
- **`>/dev/null 2>&1`:** Redirects both standard output and standard error to the null device, suppressing any output or logs.

**To set up the cron job:**

1. Open your crontab file by running `crontab -e`.
2. Paste the provided line into the crontab file.
3. Save the file to activate the cron job.

