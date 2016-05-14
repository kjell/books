info.json: login
	@curl --silent "https://apps.hclib.org/services/patron/1887832" \
		-b cookies.txt \
	| jq '.' \
  > info.json

books.json:
	@cat info.json | jq '.Itemsout + .Requests | map({ \
		title: .Title, \
		author: (.Author | split(", ") | reverse | join(" ") | gsub("[0-9]+-([0-9]+)? "; "")), \
		requestDate: .RequestDate, \
		isbn: (.SyndeticsIndexXML | scan("<ISBN>([0-9]+)</ISBN>"))[0], \
		renewals: .NumRenewals \
	})' > $@

slug = sed -e "s/'//g; s/[^[:alnum:]]/-/g" | \
	tr -s '-' | \
	tr A-Z a-z | \
	sed -e 's/--/-/; s/^-//; s/-$$//'

booksToMarkdown: books.json
	@jq -c '.[]' $< | while read -r book; do \
		author=$$(jq -r '.author' <<<$$book); \
		title=$$(jq -r '.title' <<<$$book); \
		isbn=$$(jq -r '.isbn' <<<$$book); \
		simpleTitle=$$(sed 's/ [:|=].*//' <<<$$title); \
		authorDir=$$(echo $$author | $(slug)); \
		filename=$$(echo $$simpleTitle | $(slug)); \
		file=$$authorDir/$$filename.md; \
		[[ -f $$file ]] && existingContent=$$(pandoc --to markdown $$file); \
		[[ -d $$authorDir ]] || mkdir ./$$authorDir; \
		echo "$$(jq '.' <<<$$book | json2yaml)\n---\n\n$$existingContent" \
		> ./$$file; \
	done


login:
	@curl --silent 'https://apps.hclib.org/services/login.cfm' \
		-H 'Pragma: no-cache' \
		-H 'Origin: https://apps.hclib.org' \
	--data "code=$$BARCODE&pin=$$PIN&lremember=1" --compressed \
	-c cookies.txt

PHONY: login

credentials:
	echo $$PATRON -- $$BARCODE -- $$PIN
