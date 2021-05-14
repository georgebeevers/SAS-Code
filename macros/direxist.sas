%macro DirExist(dir) ; 
   %LOCAL rc fileref return; 
   %let rc = %sysfunc(filename(fileref,&dir)) ; 
   %if %sysfunc(fexist(&fileref))  %then %let return=1;    
   %else %let return=0;
   &return
%mend DirExist;

/* Usage */
%macro dir_message(config_location=);
%if %DirExist(&config_location.) =1 %then 
%do;
%put NOTE:Directory Exists...Proceeding;
%end;
%if %DirExist(&config_location.) =0 %then
%do;
%put NOTE: Directory does not exist;
%put NOTE: Exit now;
%goto exit_now_no_obs;
%end;
%exit_now_no_obs:
%mend;
%dir_message(config_location=C:\Documents and Settings\);
%dir_message(config_location=aaa);
