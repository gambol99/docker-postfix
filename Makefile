#
#   Author: Rohith
#   Date: 2015-07-17 12:49:20 +0100 (Fri, 17 Jul 2015)
#
#  vim:ts=2:sw=2:et
#

NAME=postfix
AUTHOR=gambol99

.PHONY: build test

default: build

build:
	sudo docker build -t ${AUTHOR}/${NAME} .

test:
	# You can test TLS is working with
	# openssl s_client -starttls smtp -crlf -connect localhost:25
	sudo docker run -ti --rm --net=host \
	  -p 25:25 -p 465:465 -p 587:587 \
		-v ${PWD}/tests:/var/run/secrets \
		-e TLS_ENABLED=TRUE \
		-e TLS_SASL_PASSWD=/var/run/secrets/sasl.passwd \
		-e TLS_CERT_FILE=/var/run/secrets/postfix.cert \
		-e TLS_KEY_FILE=/var/run/secrets/postfix.key \
		${AUTHOR}/${NAME}

usage:
	sudo docker run -ti --rm --net=host ${AUTHOR}/${NAME} usage
		
#-e RELAY_HOST=email-smtp.eu-west-1.amazonaws.com:25 \
