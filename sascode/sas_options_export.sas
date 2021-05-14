/*Enhanced logging options for performance and debugging*/
options fullstimer source source2 msglevel=i mprint notes;
/*SASTRACE options for remote database access */
options sastrace=",,,dsa" sastraceloc=saslog nostsuffix;
/*List Options*/
proc options;
run; 
/*Obtain all options from the dictionary table and create an output table*/
/*The options could then be used as macros in programs later on*/
proc sql;
create table _ds_options as 
 select * from dictionary.options;
quit;
/*Obtain all Libnames*/
proc sql;
create table _ds_libnames as
select * from dictionary.libnames;
quit;
/*Obtain all members*/
proc sql;
create table _ds_members as
select * from dictionary.catalogs;
quit;

/*libname listing*/
libname _all_ list;
/*Long option listing - shows groups and other information*/
proc options define value lognumberformat;
run;

