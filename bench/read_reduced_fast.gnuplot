width=0.00001
bin(x)=width*(floor(x/width)+0.5)
set boxwidth (width * 0.9) absolute

set datafile separator ','

set style fill transparent solid 0.05

set key autotitle columnheader

set grid ytics lc rgb "#777777" lt 0 back


set terminal pngcairo enhanced rounded size 1300,768 font "Droid Sans" dashed
#set logscale x 1.1
set output 'read_reduced_fast.png'
set title 'Histogram of read times for batches of 10 reads with different backends/settings'
set xlabel 'Seconds for 10 cache reads'
set ylabel 'Frequency of given time'
set samples 10000
plot \
  'results/read_reduced/fastmmap.csv' using (bin($1)):(1.0) smooth freq with linespoints lw 2 title columnhead(1), \
  'results/read_reduced/lmdb_nosync_nosync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/read_reduced/lmdb_sync_nosync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/read_reduced/lmdb_nosync_sync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/read_reduced/lmdb_sync_sync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1)




