width=0.00005
bin(x)=width*(floor(x/width)+0.5)
set boxwidth (width * 0.9) absolute

set datafile separator ','

set style fill transparent solid 0.05

set key autotitle columnheader

set grid ytics lc rgb "#777777" lt 0 back


set terminal pngcairo enhanced rounded size 1300,768 font "Droid Sans" dashed
set output 'write_reduced_medium.png'
set title 'Histogram of write times for batches of 10 writes with different backends/settings'
set xlabel 'Seconds for 10 cache writes'
set ylabel 'Frequency of given time'
plot \
  'results/write_reduced/fastmmap.csv' using (bin($1)):(1.0) smooth freq with boxes lw 2 title columnhead(1), \
  'results/write_reduced/lmdb_nosync_nosync_multi.csv' using (bin($1)):(1.0) smooth freq with boxes title columnhead(1),\
  'results/write_reduced/lmdb_nosync_sync_multi.csv' using (bin($1)):(1.0) smooth freq with boxes title columnhead(1),\




