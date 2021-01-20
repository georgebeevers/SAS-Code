/*options symbolgen mlogic mprint;*/
%macro git_macro_compile(eg_git_loc=,out=,assign=);

/*Check the GIT file exists*/

%if %sysfunc(fileexist(&eg_git_loc.\EGGitSerialize.txt)) %then
%do;

	%global repos path;

	data _active (where=(workingFolder=ActiveRepo)) &out.;
	Attrib  workingFolder  length=$300  label='Working Folder'
			profileName  length=$50  label='GIT Profile Name'
			password  length=$300  label='GIT Password'
			username  length=$100  label='GIT User Name'
			email  length=$100  label='Email Address'
			repositoryName  length=$300  label='Repository Name'
			repositoryURI  length=$200  label='Repository URI'
			activeRepo  length=$300  label='GIT Active Repository';
        
		infile "&eg_git_loc.\EGGitSerialize.txt" truncover end=eof;
		input;

		/*	Set the PERL expression to workingFolder so that the string is broken up*/
		pid=prxparse('/workingFolder/');
		s=1;
		e=length(_infile_);
		call prxnext(pid,s,e,_infile_,p,l);

		do while(p>0);
			/*	Convert the delimiter to # and then scan on that for ease*/
			workingFolder=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),3,"#""QR");
			profileName=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),7,"#""QR");
			password=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),13,"#""QR");
			username=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),17,"#""QR");
			email=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),21,"#""QR");
			repositoryName=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),37,"#""QR");
			repositoryURI=scan(tranwrd(substr(_infile_,p,e-s),'"',"#"),42,"#""QR");

			CALL SCAN (_infile_, -3, position, length, ':');
			activeRepo=scan(substr(_infile_,position,length(_infile_)-position),2,":","QR");
/*			string=substr(_infile_,p,1000);*/
			output;
			call prxnext(pid,s,e,_infile_,p,l);
		end;

		/*Drop Variables*/
		drop pid s e p l position length;
	run;
/*Use the active GIT repo to set the required macro variables for later usage*/
	data _null_;
		/*Create Macro Variables*/
		/*Check here for syntax errror - not switching to the active dir*/
		set _active;

		/*if workingFolder=compressActiveRepo then do;*/
		call symput('repos',repositoryURI);
		call symput('path',workingFolder);

		/*	output;*/
		/*end;*/
	run;

	proc datasets lib=work noprint;
		delete _:;
	run;
		/*Check that the correct repository is being used*/
%if "%sysfunc(compress(&repos))" = "https://github.com/georgebeevers/SAS-Code.git" %then
%do;

%put INFO: Correct Repository Used;
%put INFO: Using &repos;
%put INFO: Assigning....."%sysfunc(compress(&path.))\macros\*";
%put INFO: Checking the assignment flag. Y=Assign;
	%if &assign="Y" %then %do;
		%put Assigning Macros;
%include "%sysfunc(compress(&path.))\macros\*";
		%end;
	%if &assign ne "Y" %then %do;
		%put INFO: Assign set to N or missing;
		%put INFO: No macros will be assigned;
		%end;
%end;
%if "%sysfunc(compress(&repos))" ne "https://github.com/georgebeevers/SAS-Code.git" %then
%do;
%put %str(ER)ROR: Incorrect GIT Repo used for assigning macros so aborting;
%put %str(ER)ROR: Check that your active repository is set correctly in Enterprise Guide;
%put %str(ER)ROR: It needs to be https://github.com/georgebeevers/SAS-Code.git;
%put %str(ER)ROR: You are using &repos.;
%put %str(ER)ROR: Change and rerun the process;
%put %str(ER)ROR: Incorrect GIT Repo used for assigning macros so aborting;
%end;
	%end;

	%else
	%put %str(ER)ROR: &eg_git_loc.\EGGitSerialize.txt does not exist. Check and try again.;
/*	%put %str(ER)ROR: Check the file location exists and try again;*/
/*	%put Check that the EGGitSerialize.txt file is present in APPDATA\Roaming\SAS\EnterpriseGuide\{V#}\;*/
/*%end;*/
%goto exit_now;

%exit_now:
%mend;
/*%git_checker(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8\,out=ALL,Assign="Y");*/



