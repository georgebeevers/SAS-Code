/*============================================================================================================*/
/* MODIFY FILE PERMISSIONS IN SAS WITH NOXCMD (UNIX/ LINUX OS)             								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Filename = File to be modified, inlcuding extension														  */
/* PERM = Permissions to change the file to e.g. 644, 764 etc												  */
/* DEBUG = Set to Y to allow message to be returned to the log												  */
/* REVISED = Set to Y and Y for Debug to allow the revised permissions to be viewed in the log				  */
/*------------------------------------------------------------------------------------------------------------*/
%macro fmod(filename,perm,debug,revised=);
  
  %let old=%sysfunc(getoption(notes)) %sysfunc(getoption(source));
  options nonotes nosource;
   %local rc fid fidc Bytes CreateDT ModifyDT user group other;

   %let rc=%sysfunc(filename(onefile,&filename));
   %let fid=%sysfunc(fopen(&onefile));
/*   %let Bytes=%sysfunc(finfo(&fid,File Size (bytes)));*/
/*   %let CreateDT=%qsysfunc(finfo(&fid,Create Time));*/
/*   %let ModifyDT=%qsysfunc(finfo(&fid,Last Modified));*/
/*   %let ModifyDT=%qsysfunc(finfo(&fid,Last Modified));*/
   %if &debug=Y %then %do;
   %if &revised=Y %then 
  %put New Permissions %qsysfunc(finfo(&fid,Access Permission));
   %else
  %put Current Permissions %qsysfunc(finfo(&fid,Access Permission));
   %end;

   %let fidc=%sysfunc(fclose(&fid));

   %do octal = 1 %to 3;
  %let bit = %sysfunc(substr(&perm,&octal,1));
  %let permissions=%sysfunc(putn(&bit,binary3.));
  
  %let chars=;
  %if %substr(&permissions.,1,1)=1 %then %let chars=r; %else %let chars=-;
  %if %substr(&permissions.,2,1)=1 %then %let chars=&chars.w; %else %let chars=&chars.-;
  %if %substr(&permissions.,3,1)=1 %then %let chars=&chars.x; %else %let chars=&chars.-;

  %if &octal=1 %then %let user=&chars;
  %else %if &octal=2 %then %let group=&chars;
  %else %if &octal=3 %then %let other=&chars;
   %end;

   %if &perm > 600 and %index(&user,rw)>0 and &debug=N %then %do;
  data _null_;
  file "&filename." permission="A::u::&user.,A::g::&group.,A::o::&other." mod;
  run;
  %fmod(&filename,000,&debug.,revised=Y);  
   %end;
   %else %if &revised ne Y and &debug=Y %then %put Permissions not changed;
  options &old.;
%mend fmod;


/*%fmod(%sysfunc(pathname(work))/basic_perms.sas7bdat,777,N);*/