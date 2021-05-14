/*************************************************************************************************************/
/*  PROGRAM NAME: CREATE_CUSTOMER_MTG_DATA     	                                    						 */
/*  DATE CREATED: 27-08-2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: USE OPEN SOURCE DATA TO CREATE A CUSTOMER DATA TABLE CONTAINING FULL ADDRESS, CUSTOMER NAME,*/
/*  EMAIL ADDRESS AND TELEPHONE NUMBER.																		 */
/*  				   																						 */
/*  INPUTS:								  |              					                        		 */
/*	UK LAND REGISTRY DATA - https://www.gov.uk/government/statistical-data-sets/price-paid-data-downloads	 */
/*	FREE MAP TOOLS - https://www.freemaptools.com/download-uk-postcode-lat-lng.htm							 */
/*  OUTPUTS:                                                                       							 */
/*  																										 */
/*																											 */
/*																											 */
/* --------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							 */
/*  1.0                                                                            							 */
/* --------------------------------------------------------------------------------------------------------- */

/*============================================================================================================*/
/* TESTING OPTIONS - LEAVE FOR FUTURE DEVELOPMENT                          								  	  */
/*============================================================================================================*/
/*View the flatfile in the log for easier input*/
/*data _null_;*/
/*infile "C:\Users\sukgeb\Downloads\pp-complete.csv";*/
/*input; */
/*list;*/
/*run;*/
/*============================================================================================================*/
/* SET THE RANDBETWEEN MACRO FOR FLORRING VALUES                          								  	  */
/*============================================================================================================*/

%macro RandBetween(min, max);
	(&min + floor((1+&max-&min)*rand("uniform")))
%mend;
/*============================================================================================================*/
/* EXTRACT UK LAND REGISTRY DATA - START                                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* DATA IS AVAILABLE BY THE OGL LICENSE AND CAN BE DOWNLOADED IN YEARLY OR ONE SINGLE FILE. THIS PROCESS	  */
/* PULLS 2018-2020 (CURRENT AT WRITING) DATA. IF MORE IS NEEDED EXPAND THE RANGE OR PULL THE FULL FILE		  */
/* PPD SITE - https://www.gov.uk/government/statistical-data-sets/price-paid-data-downloads#single-file		  */
/* FULL FILE - http://prod.publicdata.landregistry.gov.uk.s3-website-eu-west-1.amazonaws.com/pp-complete.csv  */
/*------------------------------------------------------------------------------------------------------------*/

%macro get_ogl_data(year=);
	filename out "%sysfunc(pathname(work))\ppd_ogl_data_&year..csv";
/*Use proc http to download the file to the work directory*/
/*As the file is stored on S3 key checkging could be included to ensure integrity. Excluded in this build as not*/
/*required*/
	proc http
		url="http://prod.publicdata.landregistry.gov.uk.s3-website-eu-west-1.amazonaws.com/pp-&year..csv"
		method="get" out=out;
	run;
/*Read the downloaded CSVs into a SAS dataset*/
	data address_&year. (drop=v1 v2 v3);
		infile "%sysfunc(pathname(work))\ppd_ogl_data_&year..csv" delimiter=',' dsd truncover;
		format key PAON SOAN street $200. locality City_town district county $50. dttm $22.;
		input
			key $ soldprice dttm $ postcode $ v1 $ v2 $ v3 $ PAON $ SOAN $ Street $ Locality $ 
			City_Town $ District $ County $
		;
	run;

%mend;
%get_ogl_data(year=2020);
%get_ogl_data(year=2019);
%get_ogl_data(year=2018);
%get_ogl_data(year=2017);
/*Merge all of the files together and add a count. A count is required as a basic merge takes place on this*/
data address;
	set address_:;
	count +1;
run;
/*Clean up temporary SAS datasets*/
proc datasets lib=work;
delete address_:;
run;
/*============================================================================================================*/
/* EXTRACT UK LAND REGISTRY DATA - END                                  								  	  */
/*============================================================================================================*/

/*============================================================================================================*/
/* NAME LIST EXTRACT - START		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* USE OPEN SOURCE DATA TO CREATE A NAME LIST. US SOCIAL SECURITY SITE PRODUCES A LIST OF THE MOST COMMON	  */
/* NAMES. IT IS A BABY NAME DATABASE BUT USING IT WE CAN CREATE DUMMY NAMES									  */
/* SITE - https://www.ssa.gov/oact/babynames/limits.html
/*------------------------------------------------------------------------------------------------------------*/
filename out "%sysfunc(pathname(work))\names.zip";
/*Download the names zip file*/
proc http
	url="https://www.ssa.gov/oact/babynames/names.zip"
	method="get" out=out;
run;
/*Unzip the file and extract all contents*/
filename inzip ZIP "%sysfunc(pathname(work))\names.zip";
filename xl "%sysfunc(pathname(work))\yob.txt";

data _null_;
/*Wildcard on yob* to get all files*/
	infile inzip(yob*) 
		lrecl=256 recfm=F length=length eof=eof unbuf;
	file   xl lrecl=256 recfm=N;
	input;
	put _infile_ $varying256. length;
	return;
eof:
	stop;
run;
/*Read in all CSV files into one dataset*/
/*Create two random number strings to help with email and mortgage product creation later*/
data namelist;
	infile "%sysfunc(pathname(work))\yob.txt" delimiter=',' dsd truncover;
	format name $100. sex $1.;
	count+1;
	r=%RandBetween(1,44); /*Use to work with the email domains below*/
	s=%RandBetween(1,11); /*Use to work with the mortgage products below*/
	input
		name $ sex $
	;
run;

/*Create random order on the name which allows for a surname to be generated*/
data surname;
	set namelist;
	t = rand('uniform');
run;

proc sort data=surname;
	by t;
run;

data surname_c(drop=t);
	set surname (drop=count);
	count+1;
run;
proc datasets lib=work;
delete surname;
run;
/*============================================================================================================*/
/* NAME CREATION - END 				                                    								  	  */
/*============================================================================================================*/

/*============================================================================================================*/
/* EMAIL ADDRESS & PRODUCT LOOKUP - START                                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* CREATE A LOOKUP FOR EMAIL ADDRESS EXTENSIONS. THIS USES THE MOST COMMON ONES IN THE UK. IN ADDITION A SMALL*/
/* MORTGAGE PRODUCT LOOKUP HAS BEEN CREATED. IF MORE PRODUCTS ARE NEEDED THEN CHECK COMPARISON SITES AND 	  */
/* EXPANDED THE MACRO ARRAY ALONG WITH THE FORMAT RANGE														  */
/*------------------------------------------------------------------------------------------------------------*/
/*Add any new email extensions to the cards statement below*/
data email_ext;
	length domain $50.;
	count+1;
	input domain $;
	cards;
@aol.com
@att.net
@comcast.net
@facebook.com
@gmail.com
@gmx.com
@googlemail.com
@google.com
@hotmail.com
@hotmail.co.uk
@mac.com
@me.com
@mail.com
@msn.com
@live.com
@sbcglobal.net
@verizon.net
@yahoo.com
@yahoo.co.uk
@email.com
@fastmail.fm
@games.com
@gmx.net
@hush.com
@hushmail.com
@icloud.com
@iname.com
@inbox.com
@lavabit.com
@outlook.com
@btinternet.com
@virginmedia.com
@blueyonder.co.uk
@freeserve.co.uk
@live.co.uk
@ntlworld.com
@o2.co.uk
@orange.net
@sky.com
@talktalk.co.uk
@tiscali.co.uk
@virgin.net
@wanadoo.co.uk
@bt.com
run;
/*Mortgage products obtained from a comparison site*/
data mtg_products;
	infile datalines delimiter=',';
	count+1;
	length type $20. prodname $50.;
	input type $ prodname $ term rate;
	datalines;
FIXED,2 YEAR FIXED,2,1.84
FIXED,2 YEAR FIXED,2,1.99
FIXED,3 YEAR FIXED,3,2.25
FIXED,3 YEAR FIXED,3,2.75
FIXED,3 YEAR FIXED,3,3.19
FIXED,5 YEAR FIXED,5,1.99
FIXED,5 YEAR FIXED,5,2.25
FIXED,5 YEAR FIXED,5,2.44
VARIABLE,2 YEAR DISCOUNTED,2,1.99
VARIABLE,3 YEAR DISCOUNTED,3,2.99
VARIABLE,5 YEAR DISCOUNTED,5,4.24
;
run;
/*============================================================================================================*/
/* EMAIL ADDRESS & PRODUCT LOOKUP - END                                  								  	  */
/*============================================================================================================*/

/*============================================================================================================*/
/* POSTCODE DOWNLOAD - START		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* DOWNLOAD A FREE VERSION OF POSTCODES WITH LONGITUDE AND LATITUDE											  */
/* FULL SITE - https://www.freemaptools.com/download-uk-postcode-lat-lng.htm								  */
/*------------------------------------------------------------------------------------------------------------*/

/*Download Postcode lookup data*/
filename out "%sysfunc(pathname(work))\ukpostcodes.zip";

proc http
	url="https://www.freemaptools.com/download/full-postcodes/ukpostcodes.zip"
	method="get" out=out;
run;

/*Unzip and extract the member*/
filename inzip ZIP "%sysfunc(pathname(work))\ukpostcodes.zip";
filename xl "%sysfunc(pathname(work))\ukpostcodes.csv";

data _null_;
	/* using member syntax here */
	infile inzip(ukpostcodes.csv) 
		lrecl=256 recfm=F length=length eof=eof unbuf;
	file   xl lrecl=256 recfm=N;
	input;
	put _infile_ $varying256. length;
	return;
eof:
	stop;
run;

/*Create a lookup from the unzipped file*/
data latlong_lkp;
	infile "%sysfunc(pathname(work))\ukpostcodes.csv" delimiter=',' dsd truncover;
	input id	postcode $	latitude	longitude;
	;
run;
/*============================================================================================================*/
/* POSTCODE DOWNLOAD - END			                                    								  	  */
/*============================================================================================================*/
/*============================================================================================================*/
/* CREATE THE FINAL CUSTOMER TABLE USING THE PREVIOUS INPUTS               								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* REQUIRED TABLES - WORK.ADDRESS, WORK.EMAIL.EXT, WORK.LATLONG_LKP, WORK.MTG_PRODUCTS & WORK.SURNAME_C		  */
/* TEMPT TABLES MERGED TO CREATE A CUSTOMER MORTGAGE TABLE													  */
/*------------------------------------------------------------------------------------------------------------*/

proc sql;
	create table mtg_customer_data as
		select
			a.count as COUNT
			,a.name as FORENAME
			,c.name as SURNAME
			,a.sex AS SEX
			,b.soldprice as PURCHASE_PRICE
			,%RandBetween(50000, b.soldprice) as LOAN_AMOUNT
			,cat(put(%RandBetween(07700,07799),z5.)||" "||put(%RandBetween(0,999999),Z6.)) as CONTACT_NUMBER
			,cat(compress(a.name)||"."||compress(c.name),d.domain) as EMAIL_ADDRESS
			,propcase(b.PAON) as PRIMARY_ADDRESSS_OBJECT
			,propcase(b.SOAN) as SECONDARY_ADDRESS_OBJECT
			,propcase(b.street) as STREET
			,propcase(b.locality) as LOCALITY
			,propcase(b.City_town) AS "CITY/TOWN"n
			,propcase(b.district) as DISTRICT
			,propcase(b.county) as COUNTY
			,b.postcode as POSTCODE
			,datepart(input(b.dttm,anydtdtm.)) as PURCHASE_DATE format=date9.
/*			,propcase(e.type) as PRODUCT_TYPE*/
			,propcase(e.prodname) as PRODUCT_NAME
			,e.term as PRODUCT_TERM
			,e.rate as PRODUCT_RATE
			,f.latitude
			,f.longitude
		from namelist as a
			left outer join
				address as b
				on a.count =b.count
			left outer join
				surname_c as c
				on a.count=c.count
			left outer join
				email_ext as d
				on a.R=d.count
			left outer join
				mtg_products as e
				on a.s=e.count
			left outer join
				latlong_lkp as f
				on compress(b.postcode) =compress(f.postcode);
/*			where b.postcode is not null; removing missing Postcode but could retain and show DQ to set to company office*/
quit;
/*============================================================================================================*/
/* END OF PROGRAM											               								  	  */
/*============================================================================================================*/