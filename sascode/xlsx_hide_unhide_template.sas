/*Copy to prep area*/
%put %sysfunc(pathname(work));
/*Workook template needs to be held as XLSM (macro enabled) with the following VBA which works when the*/
/*book opens.*/

/*TEST NOTE - need to understand how this works with a linux server. In theory it should be fine as the XLS */
/*engine allows interaction between local and the server.*/

/*VBA WORKSHEET*/
/*Private Sub Workbook_Open()*/
/*Sheets("Males").Visible = False*/
/*Sheets("Females").Visible = False*/
/*End Sub*/

/*============================================================================================================*/
/* COPY TO SERVER LOCATION			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Batch Processes - make sure than an NFS or SAMBA mount is present to allow automation of the transfer	  */
/* Interactive - Copy files task, libname XLXS (serial) could be used but NFS is better						  */
/*------------------------------------------------------------------------------------------------------------*/
/*This example takes a maco enabled workbook which has hide sheets upon opening*/
/*Private Sub Workbook_Open()*/
/*Sheets("Males").Visible = False*/
/*Sheets("Females").Visible = False*/
/*End Sub*/
%sys_file_copy(path=C:\temp\xlsx_out\prep\hidden.xlsm,newpath=%sysfunc(pathname(work))\hidden.xlsx);

/*ods TRACE on;*/
/*Assign a libname to the XLSX*/
libname xlsin "%sysfunc(pathname(work))\hidden.xlsx";
/*delete the raw data*/
/*Delete the hidden sheets*/
proc datasets lib=xlsin;
delete Males Females;
run;
/*Insert new data*/
data xlsin.Males xlsin.Females;
  set sashelp.class;
  if sex='M' then output xlsin.Males;
  else output xlsin.Females;
run;
/*Clear the libname*/
libname xlsin clear;
/*ods TRACE off;*/

/*Send back to the LAN location as XLSM and when the user opens the workbook the sheets will be hidden*/
/*No warning or information will be presented to the user*/
%sys_file_copy(path=%sysfunc(pathname(work))\hidden.xlsx,newpath= C:\temp\xlsx_out\prep\george_new_file.xlsm);


