/*http://proc-x.com/2016/02/using-proc-iomoperate-to-list-and-stop-your-sas-sessions/*/
/*%put %sysfunc(compress(&metaserver.,',));*/
/*%put metaserver=%sysfunc(dequote(&metaserver.));*/
/*%put metauser=%sysfunc(dequote(&metauser.));*/
/*%put metapass=%sysfunc(dequote(&metapass.));*/

/*%let connection="iom://%sysfunc(dequote(&metaserver.)):8581;bridge;user=%sysfunc(dequote(&metauser.)),pass=%sysfunc(dequote(&metapass.))";*/
/*%put &connection.;*/
/*%let connection2='iom://sukgeb.emea.sas.com:8581;bridge;user=sasadm@saspw,pass={sas002}457E222F38EE6FCA059B49C75A88E6085B5851B5';*/
/*%put &connection2;*/
%metaparms_read;
%mf_getquotedstr;
/*Create the IOM connection string*/
%let connection=%mf_getquotedstr(%str(iom://&metaserver.:8581;bridge;user=&metauser.,pass=&metapass.));
%put &connection.;


/*  %let connection2=%str(')""&connection.""%str(');*/
/*  %put &connection2;*/
/* Get a list of processes */
proc iomoperate uri=&connection.;
    list spawned out=spawned;
quit;

/* Use DOSUBL to submit a PROC IOMOPERATE step for   */
/* each SAS process to get details                   */
/* Then use PROC TRANSPOSE to get a row-wise version */
data _null_;
    set spawned;
    /* number each output data set */
    /* for easier appending later  */
    /* TPIDS001, TPIDS002, etc.    */
    length y $ 3;
    y = put(_n_,z3.);
    x = dosubl("
    proc iomoperate uri=&connection. launched='" || serverid || "';
    list attrs cat='Information' out=pids" || y || ";
    quit;
    data pids" || y || ";
    set pids" || y || ";
    length sname $30;
    sname = substr(name,find(name,'.')+1);
    run;
 
    proc transpose data=work.pids" || y || "
    out=work.tpids" || y || "
    ;
    id sname;
    var value;
    run;
    ");
run;
 
/* Append all transposed details together */
data allpids;
    set tpids:;
    /* calculate a legit datetime value */
    length StartTime 8;
    format StartTime datetime20.;
    starttime = input(UpTime,anydtdtm19.);
run;
proc datasets lib=work nolist;
delete tpids:;
delete spawned;
quit;

/*============================================================================================================*/
/* SPAWNED PROCESS KILLER			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This code can be used to kill any spawned workspace server connection. It needs to be run by the 		  */
/* SASADM@SASPW. Only run if you are sure you want to remvoe the process. Any work session and data would be  */
/* be lost. You may wish to warn a user before running														  */
/*------------------------------------------------------------------------------------------------------------*/
/*The ID is the UUID from the previous code to check spawned workspace server connections*/
proc iomoperate uri=&connection.;
	STOP spawned server 
		id="ECBAB9E0-C84D-4A7E-B221-E336EEC14948";
quit;                                                            
/* ID = value is the UniqueIdentifier (UUID)      */
/*  Not the process ID (PID)  */
/*Once this has been run it is advised that the PID is also passed to a command to ensure it has been revoved.*/
/*Kill -9 {PID}*/
/*It is possible to build this a utility or function as the data could be fed in via a macro call. */

/*Apply a Limit of Spawned Sesssion*/
/*Add to workspace server USERMODS file*/
/*
Lev1/SASApp/WorkspaceServer/WorkspaceServer_usermods.sh
LIMIT=4

COUNT=`ps -ef|grep bridge|grep spawned|grep $USER|wc -l`

if [[ $COUNT -gt $LIMIT ]]
then
  exit 1
fi
*/