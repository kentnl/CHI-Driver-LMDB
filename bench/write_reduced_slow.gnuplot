width=0.0001
bin(x)=width*(floor(x/width)+0.5)
set boxwidth (width * 0.9) absolute

set datafile separator ','

set style fill transparent solid 0.5

set key autotitle columnheader

set grid ytics lc rgb "#777777" lt 0 back



set terminal pngcairo enhanced rounded size 1300,768 font "Droid Sans" dashed
set output 'write_reduced_slow.png'
set title 'Histogram of write times for batches of 10 writes with 1-transaction-per-write under different sync settings'
set xlabel 'Seconds for 10 cache writes'
set ylabel 'Frequency of given time'
set samples 10000
plot \
  'results/write_reduced/lmdb_sync_nosync_multi.csv' using (bin($1)):(1.0) smooth freq with boxes title columnhead(1),\
  'results/write_reduced/lmdb_sync_sync_multi.csv' using (bin($1)):(1.0) smooth freq with boxes title columnhead(1),\




