default: login
	curl "https://apps.hclib.org/services/patron/$$PATRON" \
		-b cookies.txt \

login:
	curl 'https://apps.hclib.org/services/login.cfm' \
		-H 'Pragma: no-cache' \
		-H 'Origin: https://apps.hclib.org' \
	--data "code=$$BARCODE&pin=$$PIN&lremember=1" --compressed \
	-c cookies.txt

PHONY: login
