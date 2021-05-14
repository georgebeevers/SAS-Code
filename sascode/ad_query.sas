/*************************************************************************************************************/
/*  PROGRAM NAME: AD_QUERY_USER			      	                                    						 */
/*  DATE CREATED: 22-01-2021                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: EXTRACT ALL USERS IN CERTAIN GROUPS. THIS PROGRAM CAN BE USED TO TARGET SAS USERS WHEN 	 */
/*  ACTIVE DIRECTORY INTEGRATION IS BEING USED																 */
/*  				   																						 */
/*  MACROS:								  |              					                        		 */
/*	TRANSMEMKEYID																							 */
/*	LDAPEXTRPERSONS																							 */
/*  GET_LDAP_USERS                                                                 							 */
/*  GET_OBSCNT																								 */
/*	AD_GROUPS_TO_LOG.TXT - POST SETUP																		 */
/*																											 */
/* --------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							 */
/*  1.0 22-01-2021 GEORGE BEEVERS INITIAL VERSION                                  							 */
/* --------------------------------------------------------------------------------------------------------- */

/*SERVER DETAILS*/
/*Include the server address. Generally its port 389 but check internally*/
%let ADServer = "emea.sas.com";
%let ADPort   = 389;

/*MULITPLE AD SERVERS*/
/*Create the required string to bind on. When more than one AD server is used an additional sring can be created.*/
/*The prcess would be to check the first and then repeat using the second or third AD server*/
%let ADPerBaseDN1 =DC=emea,DC=SAS,DC=com;
/*%let ADPerBaseDN2 =DC=emea2,DC=SAS,DC=com*/

/*STRING OUTPUT*/
/*Check in Excel what is held in AD before running for everyone*/
/*CN=George Beevers,OU=users,OU=Manchester,OU=United Kingdom,DC=emea,DC=SAS,DC=com*/

/*ACCOUNT BINDING*/
/*What account is being used to extract from AD. It can be the user account or a systme account. Use a system */
/*account when you want to create a batch job*/
%let ADBindUser = "europe\sukgeb";
%let ADBindPW = "Cro14word!";
%let ADExtIDTag=SAS;
%let extractlibref=work;

/* %let keyidvar=employeeID;*/
/* %let keyidvar=distinguishedName;*/
%let keyidvar=uidNumber;
%let MetadataAuthDomain=DefaultAuth;
%let WindowsDomain=;

/* libname xxxx 'your_path_name'; */
%let importlibref=WORK;
%let amp = %nrstr(&);
/*============================================================================================================*/
/* GET A BASE LIST OF GROUPS		                                    								  	  */
/*============================================================================================================*/
/*The base list of groups is created by returning the results of an account which has all, or most of the required*/
/*SAS groups. You may need to run this against multiple accounts and its recommended that a batch account is used.*/
/*When you need to add extra groups these can be loaded from a flat file held on an external drive*/
%get_ldap_users(&ADPerBaseDN1.|(&amp.(objectClass=user)(samAccountName=sukgeb))|LDAPUSERS_sukgeb|sAMAccountName memberof );

/*Add any old groups*/
/*This process assumes that this file has already been created. It will be created as a base once the process has*/
/*run once. */
data WORK.OLD_GROUPS;
length MEMBEROF $256;
  infile "c:\temp\ad_groups_to_log.txt" lrecl=128 TERMSTR=crlf;
  input;
  MEMBEROF = _infile_;
run;

/*Append and exclude any*/
data WORK.ALL_GROUPS (keep=memberof); 
set WORK.OLD_GROUPS WORK.LDAPUSERS_sukgeb;
run;

*keep unique groups;
proc sort data=WORK.ALL_GROUPS nodupkey;
  by MEMBEROF;
run;

*write groups back to the samba control file;
data _null_;
set WORK.ALL_GROUPS;
  file "c:\temp\ad_groups_to_log.txt" TERMSTR=crlf;
  put MEMBEROF;
run;

/*Create macro variables of the groupnames to search the AD on*/
proc sql;
select memberof into: groupname1 -
from all_groups;
quit;
%put &groupname1;

%macro user_extract();
	%do i=1 %to %get_obscnt(all_groups);

/*Check for old tables and delete if they exist*/
		%if %sysfunc(exist(&extractlibref..LDAPUSERS_GLB&i.)) %then
			%do;

				proc delete data=&extractlibref..LDAPUSERS_GLB&i.;
				run;

			%end;
/*Print to the log the group which is being checked*/
		%put;
		%put %sysfunc(repeat(*,%eval(%length(FOR GROUP &&groupname&i..)+38)));
		%put ******************FOR GROUP &&groupname&i..*******************;
		%put %sysfunc(repeat(*,%eval(%length(FOR GROUP &&groupname&i..)+38)));
/*Extract the users in each group. The process will iterate up and use all of the groupnames found / created */
/*earlier*/
		%get_ldap_users(&ADPerBaseDN1.|(&amp.(objectClass=user)(memberOf=%nrstr(&&groupname&i..)))|LDAPUSERS_GLB&i.|sAMAccountName mail displayname);

/*Create a numbered extract for each of the searches*/
		data &extractlibref..LDAPUSERS_&i.;
			length D_START 4;
			format D_START ddmmyy10.;
			D_START = today();
			set &extractlibref..LDAPUSERS_GLB&i.(keep=samAccountName mail displayname);

			/*          &extractlibref..LDAPUSERS_RBB&i.(keep=samAccountName);*/
			length GROUPNAME $256;
			GROUPNAME = scan(scan("&&groupname&i..",1,","),2,"=");
		run;

	%end;
/*Load all of the extracts into one table*/
	data LDAPUSERS_ALL;
		length D_START 4 sAMAccountName $32 GroupName $256;
		label sAMAccountName="sAMAccountName" GroupName="GroupName";
		set

			%do i = 1 %to %get_obscnt(all_groups);
				&extractlibref..LDAPUSERS_&i.
			%end;
		;
	run;
/*Sort the data*/
	proc sort data=LDAPUSERS_ALL nodupkey;
		by GROUPNAME SAMACCOUNTNAME;
	run;
/*Delete the interim tables*/
	proc datasets lib=&extractlibref. nolist;
		%do i = 1 %to %get_obscnt(all_groups);
			delete LDAPUSERS_GLB&i. LDAPUSERS_RBB&i. LDAPUSERS_&i.;
		%end;
%mend;
%user_extract;

