PROBLEM=$1
OUTPUT=$2

./eprover \
	-sRp \
	--auto-schedule \
	--cpu-limit=11 \
	--soft-cpu-limit=10 \
	--free-numbers \
	--memory-limit=2000 \
	--print-statistics \
	--tstp-format \
	$PROBLEM > $OUTPUT 2> $OUTPUT.err
