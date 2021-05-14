/*============================================================================================================*/
/* CREATE NMON SHELL SCRIPT			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This program will create a shell script on a Linux server which will capture NMON output for performance	  */
/* monitoring. It should be used in conjunction with mount benchmarking, LSF job analysis (runtime) and 	  */
/* regular log parsing to obtain performance metrics for run by run comparison								  */
/*------------------------------------------------------------------------------------------------------------*/
/*Create an NMON shell in SAS*/
options symbolgen mlogic mprint;
%let shell_loc=C:\temp\shell\ /*/home/sukgeb/*/;
%let file_name=sas_nmon_export;
%let interval=120;
%let count=90;
/*#############################################################################################################*/
/*NOTE     																									   */
/*Permission change will work on UNIX and LINUX systems but not in windows. The below will create a file	   */
/*and change the permissions to 777 so that the shell could be executed in a further step. Windows ignores.	   */
/*SAS Support		  																						   */
/*https://go.documentation.sas.com/?cdcId=pgmsascdc&cdcVersion=9.4_3.5&docsetId=hostunx&docsetTarget=p0upngkius4n84n17wt1u5znj2de.htm&locale=en*/
/*#############################################################################################################*/

data _null_;
	file "&shell_loc.&file_name..sh" PERMISSION='A::u::rwx,A::g::rwx,A::o::rwx';
	put '#Collect data every two minutes and continue for 24hrs';
	put '#-s 120 is 120 seconds / 2 minutes';
	put '#-c is the count which is set to 90';
	put '#If you want to run the below for a 24hr period you would need 720 counts as this is the number';
	put '#of seconds in a day (86400) divided by the capture pont (120). Adjust depending on requirements';
	put '#If longer periods are required think about scheduling the shell and then combine the outputs';
	put '#NOTE - check the size of the log on every server and ensure you have space before running';
	put '#If space is an issue consider smaller samples with more frequent summarisation';
	put;
	put '#NMON Support';
	put '#https://www.ibm.com/support/knowledgecenter/ssw_aix_72/n_commands/nmon.html#nmon__nmp-c';
	put;
	put '#SAS Support';
	put '#https://support.sas.com/kb/48/290.html';
	put;
	put '#START NMON COMMAND';
	put "nmon -f -T -s &interval. -c &count.";
	put '#END OF FILE';
run;

/*CLI CAT*/
/*If you have command line access as the ADMIN you can place the shells on the servers / LPARS by using a*/
/*CAT comamnd to pipe the contents to a file.*/
/*The following creates the shell, changes the permissions to 777, executes it in the chosen folder and then */
/*checks that its running. Run the steps seperately to test the setup*/
/*
cat >> nmon_collect.sh << EOF
#Collect data every two minutes and continue for 24hrs 
nmon -f -T -s 120 -c 90
EOF
chmod 777 nmon_collect.sh
./nmon_collect.sh
#Check the process is running
ps -ef |grep nmon
*/