#!/usr/bin/env zsh

set -e

verbose=/tmp/.verbose

logfile="/tmp/.rospotrebnadzor.log"

newsurl="https://www.rospotrebnadzor.ru/region/rss/rss.php?SHOWALL_1=1"
rootdir="${HOME}/dev/covid/covid_rospotrebnadzor/"
datadir="$rootdir""data/"

dateformat='%F_%H'
linkshtml="$datadir""rss/rss""$(date +$dateformat).html"
linksmd="${linkshtml:r}.txt"

# If the file with the recent timestamp does not exist, download it
[ -f $linkshtml ] || curl -s -S "$newsurl" | iconv -f CP1251 -t UTF8 > $linkshtml  2> "$logfile"

[ -f $linksmd ] || pandoc $linkshtml -f html -t markdown --wrap=none -o $linksmd

if [[ -f $linksmd ]]; then
	:
else
	echo "Something went wrong"
	exit 1
fi

form_csv(){
	local day="$(echo $1 | cut -b 2,3)"
	local month="$(echo $1 | cut -b 5,6)"
	local year="$(echo $1 | cut -b 8-11)"
	local outfile="$datadir""raw/$year$month$day.html"
	local outplain="${outfile:r}.txt"
	local outseries="$datadir""series/"$year"_"$month"_"$day".csv"
	local url=$(echo $1 | sed 's/.*(//;s/).*//')

	[ -f $outfile ] || curl -s -S "https://www.rospotrebnadzor.ru$url" | iconv -f CP1251 -t UTF8 > "$outfile"

	if [[ -f $outplain ]]; then
		:
	else
		pandoc $outfile -f html -t plain -o "$outplain"
		[ -f $verbose ] && printf "made $outplain\n"
	fi


	if [[ -f $outseries ]]; then 
		:
	else
		[ -f $verbose ] && printf "Processing $outplain ...\n"
		< "$outplain" | sed -n -e '/[[:digit:]]\+\./p' \
			| sed 's/–//g;s/ случ.*//g' \
			| tr -d '|.-' \
			| sed 's/ *//;s/ *$//;s/ \+/ /g' \
			| cut -d ' ' -f 2- \
			| sed -n '/ /p' \
			| awk '{ $(NF -1) = $(NF - 1)","; print }' \
			> "$outseries"
		[ -f $verbose ] && printf "Written $outseries\n"

	fi

}

grep "О подтвер" "$linksmd" | while read -r line ; do
	form_csv "$line"
done

pushd "$rootdir" >/dev/null
git add . 
git commit -am "Update $(date +'%F_%T')" > /dev/null 2>&1 
git push > /dev/null 2>&1
popd > /dev/null
