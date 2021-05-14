%macro metaparms_read(metaparm_loc=);
/*Read the contents of the metaparms file*/
/*Hardcoded path will need to be changed to reflect your environment*/
data temp; /* don't need dataset*/
	length var_name $30 macro_var $200;
	infile "&metaparm_loc." dlm=";" truncover; /* raw file in */
	input var_name macro_var $; /* read a record */
/*Options has been remvoed from the string where present. */
var_name=trim(left(tranwrd(scan(_infile_,1,"="),"options"," ")));
macro_var=scan(_infile_,2, "=");
run;
/*Transpose the variables for later use.*/
proc transpose data=temp out=trans(drop=_name_);
var macro_var;
id var_name;
run; 
/*Create macro variables*/
%global metaserver metauser metapass metaport metaprotocol metarepository metaconnect;
data _null_;
set trans;
call symput("metaserver",compress((dequote(metaserver))));
call symput("metauser",compress((dequote(metauser))));
call symput("metapass",compress((dequote(metapass))));
call symput("metaport",metaport);
call symput("metaprotocol",metaprotocol);
call symput("metarepository",metarepository);
call symput("metaconnect",metaconnect);
run;
/*Check Macro Output*/
%put |&metaserver|;
%put |&metauser|;
%put |&metapass|;
%put |&metaport|;
%put &metaprotocol;
%put &metarepository;
%put &metaconnect;
/*proc datasets lib=work;*/
/*delete temp;*/
/*delete trans;*/
/*run;*/
%mend;
/*%metaparms_read;*/
/**/
%metaparms_read(metaparm_loc=C:\SAS\Config\Lev1\SASMeta\MetadataServer\metaparms.sas);
/*%put |&metaserver|;*/
/*%put |&metauser|;*/
/*%put |&metapass|;*/
/*%put |&metaport|;*/
/*%put &metaprotocol;*/
/*%put &metarepository;*/
/*%put &metaconnect;*/


