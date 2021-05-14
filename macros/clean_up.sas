%macro clean_up(ds);
proc delete data=&ds.;
run;
%mend;
/*%clean_up(dataset_name);*/