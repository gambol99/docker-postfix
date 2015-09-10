#!/bin/bash

MYHOSTNAME="${MYHOSTNAME:-mail}"
MYDOMAIN="${MYDOMAIN:-example.com}"
MYNETWORKS=${MYNETWORKS:-"10.0.0.0/8, 127.0.0.0/8, 172.17.0.0/16"}
TLS_ENABLED=${TLS_ENABLED:-TRUE}
TLS_CERT_FILE=${TLS_CERT_FILE:-"/etc/ssl/certs/postfix.pem"}
TLS_KEY_FILE=${TLS_KEY_FILE:-"/etc/ssl/private/postfix.pem"}

annonce() {
  [ -n "$@" ] && echo "[v] $@"
}

usage() {
  cat <<EOF
  Usage: Postfix Email MTA
  Description: The container hold a postfix service for sending emails, it supports the following
    * TLS support from client to MTA
    * Postfix Relay Support

  Environment Variables:
    MYHOSTNAME        : the FQDN of the postfix server (defaults to $MYHOSTNAME)
    MYDOMAIN          : the domain to use in the mail server (defaults to $MYDOMAIN)
    MYNETWORKS        : the postfix mynetworks specification (defaults to $MYNETWORKS)
    TLS_ENABLED       : wheather or not you want TLS enabled (defaults ${TLS_ENABLED})
    TLS_CERT_FILE     : the path to the certficate to use for TLS, assuming self sign is not enabled (defaults ${TLS_CERT_FILE})
    TLS_KEY_FILE      : the path to the key to use for TLS, assuming self sign is not enabled (defaults ${TLS_KEY_FILE})
    TLS_SASL_PASSWD   : the path of any sasl password file used for relaying
    RELAY_HOST        : the relay host to use, if any (defaults to $RELAY_HOST)

EOF
}

failed() {
  [ -n "$@" ] && {
    echo "failed: $@";
    exit 1;
  }
}

postconf() {
  local setting="$1"
  local value="$2"
  [ -z "$setting" ] && failed "you have not specified a variable to set in postfix"
  [ -z "$value" ] && failed "you have not specified a value to set for setting: ${setting}"
  annonce "Setting ${setting} = ${value}"
  /usr/sbin/postconf -e "${setting}"="${value}" || failed "unable to set configuration for, ${setting}=${value}"
}

#
# Iterates the environment variables and pull out any postfix configuration
provision_postfix() {
  while read setting value; do
    if [[ "$setting" =~ ^POSTFIX_.*$ ]]; then
      arg=$(echo $setting | tr 'A-Z' 'a-z' | sed '/POSTFIX_//')
      postconf "$arg" "$value"
    fi
  done < <(set)
}

provision_relay_host() {
  annonce "Configuring the Postfix Relay Host: ${RELAY_HOST}"
  postconf "relayhost" "${RELAY_HOST}"
}

# Provision the TLS postfix configuration
provision_tls() {
  annonce "Configuring the TLS Postfix support"
  [ -n "${TLS_CERT_FILE}" ] || failed "you have not specified the TLS_CERT_FILE environment; the path to the certficate"
  [ -n "${TLS_KEY_FILE}" ]  || failed "you have not specified the TLS_KEY_FILE environment; the path to the key"
  [ -f "${TLS_CERT_FILE}" ] || failed "the certficate file: ${TLS_CERT_FILE} does not exist or is not a file"
  [ -f "${TLS_KEY_FILE}" ]  || failed "the key file: ${TLS_KEY_FILE} does not exist or is not a file"

  postconf "smtp_use_tls" "yes"
  postconf "smtpd_use_tls" "yes"
  postconf "smtpd_sasl_auth_enable" "yes"
  postconf "smtp_sasl_auth_enable" "yes"
  postconf "smtp_tls_security_level" "may"
  postconf "smtpd_tls_cert_file" "${TLS_CERT_FILE}"
  postconf "smtpd_tls_key_file" "${TLS_KEY_FILE}"
  postconf "smtpd_tls_auth_only" "no"
  postconf "smtpd_tls_loglevel" "3"
  postconf "smtp_sasl_security_options" "noanonymous"
  postconf "smtpd_tls_received_header" "yes"
  postconf "smtpd_tls_session_cache_timeout" "3600s"
  postconf "tls_random_source" "dev:/dev/urandom"
  postconf "smtp_tls_note_starttls_offer" "yes"
  postconf "smtp_sasl_mechanism_filter" "PLAIN LOGIN"
  # step: does the relay require authentication?
  if [ -n "${TLS_SASL_PASSWD}" ]; then
    [ -f ${TLS_SASL_PASSWD} ] || failed "the sasl password file: $TLS_SASL_PASSWD does not exist"
    annonce "Generating the postmap for the SASL password file: $TLS_SASL_PASSWD"
    /usr/sbin/postmap ${TLS_SASL_PASSWD} || failed "unable to generate the postmap file from: $TLS_SASL_PASSWD"
    postconf "smtp_sasl_password_maps" "hash:${TLS_SASL_PASSWD}"
  fi
  annonce "Finished configuring the TLS support"
}

provision() {
  # step: starting by provisioning the hostname and domain
  postconf "myhostname" "${MYHOSTNAME}"
  postconf "mydomain" "${MYDOMAIN}"
  postconf "mynetworks" "${MYNETWORKS}"
  postconf "smtpd_recipient_restrictions" "permit_mynetworks,reject_unauth_destination"

  # step: customize for TLS is required
  [ ${TLS_ENABLED} == "TRUE" ] && provision_tls
  # step: setup the relaying host is required
  [ -n "${RELAY_HOST}" ] && provision_relay_host
  annonce "Starting up the supervisor service"
  # step: generate the aliases
  /usr/bin/newaliases || failed "unable to generate the mail aliases"
  # step: cat the configuration to screen
  cat /etc/postfix/main.cf | sed -e /^#/d -e /^$/d
  # step: starting the supervisord service
  /usr/bin/supervisord -n
}

# step: are we showing the usage
case "$1" in
  -h|--help)  usage
              ;;
  *)          provision
              ;;
esac
