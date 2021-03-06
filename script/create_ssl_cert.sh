#!/bin/bash

# This script creates a new SSL/TLS certificate signed by a root certificate that is common to all builds.
# That way we can have a different certificate for each .onion domain, but at the same time a single root
# certificate for all to be installed on the client side, simplifying deployment. (For anything other than
# a browser, though, certificate pinning is highly recommended instead of relying on this!)

# Check the command line arguments.
if (( $# < 2 ))
then
    >&2 echo "Error: not enough arguments provided"
    exit 1
fi
if (( $# > 3 ))
then
    >&2 echo "Error: too many arguments provided"
    exit 1
fi

# Load the build configuration variables.
source /vagrant/script/config.sh

# Switch to the output directory, so we can use relative paths.
pushd "$2" >/dev/null

# If no root cert was created, make one now.
if [ -e "${CA_CERT}" ]
then
    echo "Root certificate found at: ${CA_CERT}"
else
    echo "Root certificate not found, generating a new one..."
    openssl genrsa -out "${CA_KEY}" ${SSL_KEY_SIZE} >/dev/null 2>&1
    openssl req -new -x509 -utf8 -days ${CA_CERT_DAYS} -key "${CA_KEY}" -out "${CA_CERT}" >/dev/null 2>&1 <<EOF
${CA_CERT_COUNTRY}
${CA_CERT_STATE}
${CA_CERT_CITY}
${CA_CERT_COMPANY}
${CA_CERT_UNIT}
${CA_CERT_DN}
${CA_CERT_EMAIL}
EOF
    chmod 444 "${CA_CERT}"
    chmod 400 "${CA_KEY}"
    echo "New root key created at: ${CA_KEY}"
    echo "New root certificate created at: ${CA_CERT}"
    #openssl x509 -in "${CA_CERT}" -text -noout
fi

# Generate the key for the new certificate.
echo "Generating new SSL certificate..."
SSL_PASS="$(makepasswd)"
if (( $# > 2 ))
then
    SSL_CERT=$3
else
    SSL_CERT=$1
fi
openssl genrsa -out "${SSL_CERT}.key" ${SSL_KEY_SIZE} >/dev/null 2>&1
openssl req -new -utf8 -key "${SSL_CERT}.key" -out "${SSL_CERT}.csr" >/dev/null 2>&1 <<EOF
${CA_CERT_COUNTRY}
${CA_CERT_STATE}
${CA_CERT_CITY}
${CA_CERT_COMPANY}
${CA_CERT_UNIT}
$1
${CA_CERT_EMAIL}
${SSL_PASS}
${CA_CERT_EMAIL}
EOF
openssl x509 -req -days ${SSL_CERT_DAYS} -in "${SSL_CERT}.csr" -CA "${CA_CERT}" -CAkey "${CA_KEY}" -set_serial 01 -out "${SSL_CERT}.crt" >/dev/null 2>&1
openssl pkcs12 -export -out "${SSL_CERT}.p12" -inkey "${SSL_CERT}.key" -in "${SSL_CERT}.crt" -chain -CAfile "${CA_CERT}" >/dev/null 2>&1 < $(echo "${SSL_PASS}")
echo "New SSL certificate created for domain: $1"

# Go back to the original current directory.
popd >/dev/null
