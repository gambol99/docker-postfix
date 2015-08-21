### *Postfix in a Service* ###

A Postfix container with TLS support

#### **TLS**

You need to generate the certificates for postfix to use. At present i'm using kubernetes secrets to pass the certs into the container

```shell
  # Generating a self-signed certificate
  [jest@starfury docker-postfix]$ openssl req -new -x509 -days 3650 -nodes -out postfix-cert -keyout postfix-key

  # You have to base64 encode them and place them in kubernetes
  [jest@starfury docker-postfix]$ head postfix-certs.yml
  apiVersion: v1
  kind: Secret
  metadata:
    name: mail-certs
  data:
    postfix-cert: |
      LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURoekNDQW0rZ0F3SUJBZ0lKQUxXSHlCQkVO
      TEZpTUEwR0NTcUdTSWIzRFFFQkN3VUFNRm94Q3pBSkJnTlYKQkFZVEFrZENNUTh3RFFZRFZRUUlE
      QVpNYjI1a2IyNHhEekFOQmdOVkJBY01Ca3h2Ym1SdmJqRWNNQm9HQTFVRQpDZ3dUUkdWbVlYVnNk
      Q0JEYjIxd1lXNTVJRXgwWkRFTE1Ba0dBMVVFQ3d3Q1NWUXdIaGNOTVRVd056RTRNVFEwCk9UUTRX
      ...
    postfix-key: |
      LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZB
      QVNDQktjd2dnU2pBZ0VBQW9JQkFRQ2ZzWXRrWnNmWGJvL1AKR2R3L3ZzcTdZWVJVSVR0VG9Mai9X
```

#### **Enviroment Variables**

> * TLS_ENABLED: wheather or not to enable TLS support for postfix service, default true
> * TLS_CERT_FILE: the location of the certificate to use for TLS, defaults: /etc/secrets/certs/postfix-cert
> * TLS_KEY_FILE: the location of the key file for TLS, defaults: /etc/secrets/certs/postfix-key
> * TLS_SASL_PASSWD: the location of the SASL file for authentication, defaults: /etc/secrets/sasl/postfix-sasl
> * RELAY_HOST: the host / address of a relay host to forward email
> * MYHOSTNAME: the hostname of the mail service, defaults to 'mail'
> * MYDOMAIN: the domain of the mail service, defaults to 'exmaple.com'
