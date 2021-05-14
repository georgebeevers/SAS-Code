/*============================================================================================================*/
/* RANDOM NUMBER RANGE SAMPLE MACRO																		  	  */
/*============================================================================================================*/
%macro RandBetween(min, max);
	(&min + floor((1+&max-&min)*rand("uniform")))
%mend;
run;
/*============================================================================================================*/
/* INPUT THE NUMBER OF OBSERVATIONS (ACCOUNTS) IN THE SYNTHETIC DATA BUILD								  	  */
/* INPUT THE REPORTING MONTH																				  */
/*============================================================================================================*/
%let date		=01JUL2020;
%let timeseries =12;

/*============================================================================================================*/
/* CHECK AND RESET NUMBER OF OBSERVATIONS BASED ON THE DATA												  	  */
/*============================================================================================================*/
/*============================================================================================================*/
/* CHECK THE NUMBER OF OBSERVATIONS IN THE CUSTOMER DATASET (MTG_CUSTOMER_DATA) AND IF THE REQUESTED NUMBER OF*/
/* RECORDS (NUM_ACCS) IS GREATER THAN THE CUSTOMER DATASET THE OBSERVATIONS ARE REDUCED. IF MORE IS NEEDED 	  */
/* CHECK THE CUSTOMER DATASET BUILD SCRIPT AND INCLUDE MORE LAND REGISTRY POSTCODE DATA						  */
/*============================================================================================================*/
%macro totobs(mydata);
%global nrows;
    %let mydataID=%sysfunc(OPEN(&mydata.,IN));
    %let NROWS=%sysfunc(ATTRN(&mydataID,NOBS));
    %let RC=%sysfunc(CLOSE(&mydataID));
/*    &NROWS*/
%mend;
/*%put %totobs(work.mtg_customer_data);*/
%totobs(work.mtg_customer_data);
%put &nrows;
/*Override the max set by the customer table. Move will require changes to the customer extract. Less is fine.*/
/*%let num_accs	=1957046; */

/*============================================================================================================*/
/* FORMAT CREATION																						  	  */
/* SET THE FORMATS ACCORDING TO THE DATA NEEDED																  */
/* EXPAND / CONTRACT THE NUMBER, CHANGE THE VALUE NAMES / ADD NEW FORMAT NAMES								  */
/*============================================================================================================*/
proc format;
value FMT_BOOKID 		1='Residential' 2='BTL' ;
value FMT_PORTOFLIO 	1='Fixed' 2='Variable' 3='Interest Only';
value FMT_EMP_STATUS 	1='Employed' 2='Unemployed' 3='Self Employed' 4='Student' 5='Pensioner' 6='Other';
value FMT_FTB			1='Y' 2='N';
value FMT_INC_VERIFY 	1='Self Certified' 2='Verified' 3='Non Verfified Income' 4='Other';
value FMT_ORIG_CHAN		1='Branch' 2='Direct' 3='Internet' 4='Broker' 5='Other';
value FMT_PROP_TYPE		1='Detached' 2='Semi Detached' 3='Flat/Apartment' 4='Bungalow' 5='Terraced' 6='HMO' 7='Land' 8='Other';
run;
/*%macro port_split_loop(samp=,id=);*/
data temp ;
	call streaminit(123);
	
/*============================================================================================================*/
/* ASSIGN FORMATS FOR VARIABLES NEEDED							           								  	  */
/*============================================================================================================*/
	format DT_MONTH date9. CUSTID z12.  CURRENCY $4. BOOK FMT_BOOKID. PRODUCT_TYPE FMT_PORTOFLIO. EMP_STATUS FMT_EMP_STATUS. 
	FTB FMT_FTB. INC_VERIFY FMT_INC_VERIFY. ORIG_CHAN FMT_ORIG_CHAN. PROP_TYPE FMT_PROP_TYPE.
/*============================================================================================================*/
/* FINANCIAL GBP £ FORMATS										           								  	  */
/*============================================================================================================*/
	MTG_ACC_BAL MTGBAL_M1 - MTGBAL_M12 EAD_M1-EAD_M12 SPOTBAL_M1 - SPOTBAL_M12 
	IMPAIRMENT_CHG IAS35_PERFORMING IAS35_IMPAIRED IAS35_DEFAULT IFRS9_STG1 IFRS9_STG2			
	IFRS9_STG3 MTG_ACC_BAL CURR_ACC_BAL MTG_PAY INCOME NLMNLGBP30.;
/*============================================================================================================*/
/* CREATE 12 MONTHS DATA BASED ON [12]                                   								  	  */
/* CREATED VARIABLES																						  */
/* MTGBAL_M1-12 (BALANCE MINUS CURRENT MONTH																  */
/* EAD_M1-12 (EXPOSURE AT DEFAULT MINUS CURRENT MONTH														  */
/* SPOT_BAL_M1-12 (SPOT ACCOUNT BALANCE MINUS CURRENT MONTH													  */
/*============================================================================================================*/
	array MTGBAL_M[&timeseries.];
	array EAD_M[&timeseries.];
	array SPOTBAL_M[&timeseries.];
/*============================================================================================================*/
/* CREATE BOOK AND PORTFOLIO FLAG 		                                   								  	  */
/* FLAG IS SET BASED ON A PERCENTAGE OF THE TOTAL POPUALTION. 0.1 REPRESENTS 10%							  */
/* S[2] = SECURED OR UNSECURED 91% 9% SPLIT																	  */
/* P[6] = OPT, RET, CA, CC, LN, PCDL 18%*5 AND 10%		   													  */
/* CHANGE [NUMBER] AND THE SUBSEQUENT PERCENTAGES		  													  */
/*============================================================================================================*/
	array X[2] 		(0.91 0.09);/*BOOK*/
	array Y[3] 		(0.7 0.2 0.1);/*PORTFOLIO*/
	array Z[6] 		(0.6 0.02 0.3 0 0 0.08);/*EMP_STATUS*/
	array ZZ[2] 	(0.85 0.15);/*FTB*/
	array ZZZ[4] 	(0.2 0.75 0.04 0.01);/*INC_VERIFY*/
	array ZZZZ[5] 	(0.1 0.1 0.6 0.15 0.05);/*ORIG_CHAN*/
	array ZZZZZ[8] 	(0.2 0.2 0.2 0.1 0.1 0.1 0.05 0.05);/*PROP_TYPE*/
/*============================================================================================================*/
/* ITERATION START BASED ON NUMBER OF OBSERVATIONS REQUIRED		           								  	  */
/*============================================================================================================*/
	do m=1 to &nrows.;
		do  
			r=rand('Uniform');
			DT_MONTH 	= "&date."d;
			CUSTID		= put(%RandBetween(100000000, 200000000),z12.);
/*============================================================================================================*/
/* CREATE BOOK AND PORTFOLIO FLAG (DYNAMIC CHARACTER VARIABLES)            								  	  */
/*============================================================================================================*/
			BOOK = rand("Table", of X[*]);
			PRODUCT_TYPE = 	rand("Table", of Y[*]);
			EMP_STATUS = 	rand("Table", of Z[*]);
			FTB = 			rand("Table", of ZZ[*]);
			INC_VERIFY = 	rand("Table", of ZZZ[*]);
			ORIG_CHAN = 	rand("Table", of ZZZZ[*]);
			PROP_TYPE = 	rand("Table", of ZZZZZ[*]);
/*============================================================================================================*/
/* NUMERICAL DATA BASED ON RANGES (MIN & MAX NEEDED)                      								  	  */
/*============================================================================================================*/
			AGE 				= %RandBetween(18, 65); 		/*CUSTOMER AGE*/
			INCOME 				= %RandBetween(20000, 120000); 	/*INCOME*/
			TERM_REMAIN_MTHS 	= %RandBetween(1, 60); 			/*AGE*/
			DEP_NUM				= %RandBetween(0, 4); 			/*NUMBER OF DEPENDENCIES - CHILDREN*/
			IMPAIRMENT_CHG 		= %RandBetween(0, 50000);		/*IMPAIRMENT CHARGE*/
			IAS35_PERFORMING	= %RandBetween(0, 50000);		/*IAS35 PERFORMING BOOK CHARGE*/
			IAS35_IMPAIRED 		= %RandBetween(0, 50000);		/*IAS35 IMPAIRED*/
			IAS35_DEFAULT		= %RandBetween(0, 50000);		/*IAS35 DEFAULT*/
			IFRS9_STG1			= %RandBetween(0, 50000);		/*IFRS9 STAGE 1 ALLOCATION*/
			IFRS9_STG2			= %RandBetween(0, 25000);		/*IFRS9 STAGE 2 ALLOCATION*/
			IFRS9_STG3			= %RandBetween(0, 12500);		/*IFRS9 STAGE 3 ALLOCATION*/
			MTG_ACC_BAL 		= %RandBetween(20000, 500000); 	/*MORTGAGE ACCOUNT BALANCE*/
			CURR_ACC_BAL 		= %RandBetween(100, 5000);		/*CURRENT ACCOUNT BALANCE*/

/*============================================================================================================*/
/* MORTGAGE PAYMNETS								                     								  	  */
/* BASED ON PERCENTAGE OF THE BALANCE - ADJUST 0.002 TO CHANGE THE AMOUNT									  */
/*============================================================================================================*/
			MTG_PAY = round(mtg_acc_bal*0.002,0.1);					/*MORTGAGE MONTHLY PAYMENT*/
/*============================================================================================================*/
/* CURRENCY											                     								  	  */
/* SET TO GBP BUT CAN BE CHANGED DEPENDING ON THE NATURE OF THE BUSINESS									  */
/*============================================================================================================*/
			Currency="GBP";											/*CURRENCY*/
/*============================================================================================================*/
/* CALCULATIONS										                     								  	  */
/* CREATED BASED ON SIMPLE MATHS. CAN BE ADJUSTED															  */
/*============================================================================================================*/
			MTG_FEES	= MTG_PAY*.2;								/*MORTGAGE FEES@20%*/
			PD			= rand('Uniform');							/*PROBABILITY OF DEFAULT*/
			LGD			= rand('Uniform');							/*LOSS GIVEN DEFAULT*/
			EAD			= MTG_ACC_BAL*1.15;							/*EXPOSURE AT DEFAULT*/
/*============================================================================================================*/
/* HISTORICAL BALANCES								                     								  	  */
/* ARRAY CALCULATION OF MORTGAGE BALANCE, EAD AND SPOT BALANCE												  */
/*============================================================================================================*/
			do i=1 to &timeseries.;
				MTGBAL_M[i]	= MTG_ACC_BAL+(MTG_PAY*i);				/*MORTGAGE BALANCE FOR X MONTHS*/
				EAD_M[i]	= (MTG_ACC_BAL+(MTG_PAY*i)*1.15);		/*EAD FOR X MONTHS*/
				SPOTBAL_M[i]	= %RandBetween(-500, 2000);			/*CURRENT ACCOUNT SPOT BALANCE FOR X MONTHS*/
			end;
			output;
		end;
	end;
/*============================================================================================================*/
/* DROP TEMPORARY VARIABLES							                     								  	  */
/* TAKE CARE ON THE NAMES AND COLON DROPS																	  */
/*============================================================================================================*/
	drop r m i X: Y: Z:; 

	run;
/*============================================================================================================*/
/* JOIN WITH CUSTOMER DATA							                     								  	  */
/*============================================================================================================*/
data temp_num;
set temp;
count+1;
run;
proc sql;
create table mortgages (drop=count purchase_price loan_amount) as 
select
a.*
,a.MTG_ACC_BAL*(%RandBetween(1.1, 1.4)) as ORIG_LOAN_AMT
,b.*
from temp_num as a
left outer join 
mtg_customer_data as b
on a.count =b.count;
quit;

proc sort data=mortgages nodupkey;
by custid;
run;

%put %sysfunc(pathname(work));
