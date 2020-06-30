DIR=$1

grep_first_number () {
	 sed 's/[^0-9]*\([0-9]*\).*/\1/g' $1
}

for f in `ls $DIR/*log`
do
	echo $f
	grep -o 'iteration no.*' $f | grep_first_number  > $f.tmp.iteration
	grep 'Conjectures proved (all iterations)' $f | grep_first_number \
		> $f.tmp.conjs-proved-all-iters
	grep 'Conjectures proved (this iteration)' $f | grep_first_number \
		> $f.tmp.conjs-proved-this-iter
	Rscript plot.R $f.tmp.*
	rm $DIR/*.tmp.*
done

