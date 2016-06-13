SHELL := bash

info.json: login
	@curl --silent "https://apps.hclib.org/services/patron/1887832" \
		-b cookies.txt \
	| jq '.' \
  > info.json

books.json: info.json
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

getBookInfo = xargs -I '{}' curl --silent "https://www.googleapis.com/books/v1/volumes" -G --data-urlencode "q={}"
getBookInfoByISBN = xargs -I '{}' echo "isbn:{}" | $(getBookInfo)

booksToMarkdown: books.json
	@jq -c '.[]' $< | while read -r book; do \
		author=$$(jq -r '.author' <<<$$book); \
		isbn=$$(jq -r '.isbn' <<<$$book); \
		if [[ -z $$author ]]; then \
			author=$$(echo $$isbn | $(getBookInfoByISBN) | jq -r '.items[0].volumeInfo.authors | join(" and ")'); \
		fi; \
		title=$$(jq -r '.title' <<<$$book); \
		requestDate=$$(jq -r '.requestDate' <<<$$book); \
		simpleTitle=$$(sed 's/ [:|=].*//' <<<$$title); \
		authorDir=$$(echo $$author | $(slug)); \
		filename=$$(echo $$simpleTitle | $(slug)); \
		file=$$authorDir/$$filename.md; \
		notCheckedOutYet=$$(sed 's/null//' <<<$$requestDate); \
		[[ -n $$notCheckedOutYet ]] && file=requests/$$file; \
		[[ -d $$(dirname $$file) ]] || mkdir $$(dirname $$file); \
		if [[ -f requests/$$file && -z $$notCheckedOutYet ]]; then \
			mv requests/$$file $$file; \
			rmdir requests/$$file 2&>/dev/null; \
		fi; \
		if [[ -f $$file ]]; then \
			existingContent=$$(pandoc --to markdown $$file); \
		else \
			existingContent=''; \
		fi; \
		[[ -d $$(dirname $$file) ]] || mkdir $$(dirname $$file); \
		mergedMeta=$$(jq -s 'add' \
			<(m2j $$file | jq '.[] | del(.basename, .preview)') \
			<(echo $$book) \
		| json2yaml); \
		>&2 echo $$author -- $$simpleTitle; \
		echo -e "$$mergedMeta\n---\n\n$$existingContent" \
		> ./$$file; \
	done


login:
	@curl --silent 'https://apps.hclib.org/services/login.cfm' \
		-H 'Pragma: no-cache' \
		-H 'Origin: https://apps.hclib.org' \
	--data "code=$$BARCODE&pin=$$PIN&lremember=1" --compressed \
	-c cookies.txt

PHONY: books.json info.json search nonLibrary

credentials:
	echo $$PATRON -- $$BARCODE -- $$PIN

search:
	@echo $(terms) | $(getBookInfo) \
	| jq -r '.items | \
	  map(.volumeInfo) \
		| map(.title, (.authors | join(" and ")), "---\n")[] \
	'

isbn:
	@echo $(isbn) | $(getBookInfoByISBN)

# Use google's book search to pull metadata for not-library books
nonLibrary:
	@json=$$(echo $(terms) | $(getBookInfo) | jq '.items[0].volumeInfo | { \
		title: .title, \
		author: .authors | join(" and "), \
		isbn: .industryIdentifiers[0].identifier \
	}'); \
	title=$$(jq -r '.title' <<<$$json); \
	author=$$(jq -r '.author' <<<$$json); \
	authorDir=$$(echo $$author | $(slug)); \
	filename=$$(echo $$title | $(slug)); \
	file=$$authorDir/$$filename.md; \
	[[ -d $$(dirname $$file) ]] || mkdir $$(dirname $$file); \
	echo $$title -- $$author -- $$file; \
	echo -e "$$(json2yaml <<<$$json)\n---\n" > $$file; \

