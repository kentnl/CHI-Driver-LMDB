width=0.00002
set boxwidth (width * 0.9) absolute

bin(x)=width*(floor(x/width)+0.5)

set datafile separator ','

set style fill transparent solid 0.05

set key autotitle columnheader

set grid ytics lc rgb "#777777" lt 0 back


set terminal pngcairo enhanced rounded size 1300,768 font "Droid Sans" dashed
set logscale x 1.1
set output 'write_reduced.png'
set title 'Histogram of write times for batches of 10 writes with different backends/settings'
set xlabel 'Seconds for 10 cache writes'
set ylabel 'Frequency of given time'
set samples 10000
plot \
  'results/write_reduced/fastmmap.csv' using (bin($1)):(1.0) smooth freq with linespoints lw 2 title columnhead(1), \
  'results/write_reduced/lmdb_nosync_nosync_multi.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_sync_nosync_multi.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_nosync_sync_multi.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_sync_sync_multi.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_nosync_nosync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_sync_nosync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_nosync_sync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1),\
  'results/write_reduced/lmdb_sync_sync_single.csv' using (bin($1)):(1.0) smooth freq with linespoints title columnhead(1)




