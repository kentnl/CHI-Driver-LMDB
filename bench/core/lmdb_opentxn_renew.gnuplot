width=0.000005
bin(x)=width*(floor(x/width)+0.5)
set boxwidth (width * 0.9) absolute

set datafile separator ','

set style fill transparent solid 0.05

set key autotitle columnheader

set grid ytics lc rgb "#777777" lt 0 back


set terminal pngcairo enhanced rounded size 1300,768 font "Droid Sans" dashed
#set logscale x 1.1
set output 'lmdb_opentxn_renew.png'
set title 'Histogram of read times for batches of 10 open/close transactions'
set xlabel 'Seconds for 10 transaction open/closes'
set ylabel 'Frequency of given time'
set samples 10000
plot \
  'results_reduced/lmdb_opentxn_renew.csv' using (bin($1)):(1.0) smooth freq with boxes title columnhead(1),\
  'results_reduced/lmdb_opentxn_renew.csv' using (bin($2)):(1.0) smooth freq with boxes title columnhead(2),\
  'results_reduced/lmdb_opentxn_renew.csv' using (bin($3)):(1.0) smooth freq with boxes title columnhead(3),\
  'results_reduced/lmdb_opentxn_renew.csv' using (bin($4)):(1.0) smooth freq with boxes title columnhead(4)





