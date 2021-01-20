/*============================================================================================================*/
/* DOWNLOAD GIT REPOSITORY			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* 1. GIT Repo = https://github.com/georgebeevers/SAS-Code.git												  */
/* 2. Clone in EnterPrise Guide, CLI or Desktop Application													  */
/* 3. Copy and paste the local direcotry path to macros into the statement below							  */
/*------------------------------------------------------------------------------------------------------------*/
/*DOWNLOAD GIT REPOSITORY*/
/*GIT Repo = https://github.com/georgebeevers/SAS-Code.git */
/*- Clone in EG*/
/*- Run the git_checker macro to assign the repos and path variables for usage*/
/*GIT path only with no assignment*/
%git_macro_compile(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8);

/*Incorrect Git path*/
%git_macro_compile(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\9);

/*Git path and assign ="Y"*/
%git_macro_compile(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8,assign="Y");

/*Git path, assign="Y" and Out=*/
%git_macro_compile(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8,assign="Y",out=ALL);
/*%git_checker(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8,assign="Y");*/

%put &repos;
%put &path;

%macro assign_local_git;

%if "%sysfunc(compress(&repos))" = "https://github.com/georgebeevers/SAS-Code.git" %then
%do;

%put INFO: Correct Repository Used;
%put INFO: Inlcuding and compiling all macros;
/*%include "%sysfunc(compress(&path.))\macros\*";*/
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
%mend;
%assign_local_git;


/*GET DETAILED TRANSFORM ROLES*/
/*Due to the truncation this uses and extra step to go into the step properties and class to obtain*/
/*the full transformrole being used. In some cases TransformationStep2 is present and this is not */
/*unique. The DESC is used to provided details on what transformation might be used. A user can change the */
/*description in SAS DI but we take it anyway. As its not a requirement to change the description the hope*/
/*is that it remains untouched or if its used extra text is added*/
/*If it has been used then the deployed code could be parsed for affected jobs to determine the*/
/*tranformation used*/
%get_job_transformrole_det();