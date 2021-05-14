data males females;
set sashelp.class;
  if sex='M' then output Males;
  else output Females;
run;

%let Template_Location=C:\temp\hsbc\XLS\Template;
%let template_name=sashelp_class_report_template.xlsx;
%let report_staging=C:\temp\hsbc\XLS\Staging;
%let report_name=sashelp_report_&sysdate..xlsx;
/*https://blogs.sas.com/content/sasdummy/2014/09/21/ods-excel-and-proc-export-xlsx/*/
/*%put &report_name.;*/
%sys_file_copy(path=&template_location.\&template_name.,newpath=%sysfunc(pathname(work))\&template_name.);
/*Use PROC EXPORT to keep the integrity of the workbook and only change the datasheets. This method works faster than */
/*libname XLSX which writes sequentially*/
/*Swap the data around so that males and femals will be on the wrong tabs. This allows us to demonstrate that the */
/*links in the XLSX are maintained.*/
proc export data=sashelp.class(where=(sex="F"))
  dbms=xlsx
  outfile="%sysfunc(pathname(work))\&template_name." replace;
  sheet="Males";
run;

proc export data=sashelp.class(where=(sex="M"))
  dbms=xlsx
  outfile="%sysfunc(pathname(work))\&template_name." replace;
  sheet="Females";
run;
/*Send the file back to the report staging location */
%sys_file_copy(path=%sysfunc(pathname(work))\&template_name.,newpath= &report_staging.\&report_name.);

/*Run the control XLSM to hide the Males and Females tab. Any other VBA could be applied*/

/*============================================================================================================*/
/* Create Lots 						                                    								  	  */
/*============================================================================================================*/


%let Template_Location=C:\temp\hsbc\XLS\Template;
%let template_name=sashelp_class_report_template.xlsx;
%let report_staging=C:\temp\hsbc\XLS\Staging;
%let report_name=sashelp_report_&sysdate.;
/*https://blogs.sas.com/content/sasdummy/2014/09/21/ods-excel-and-proc-export-xlsx/*/
/*%put &report_name.;*/
/*%sys_file_copy(path=&template_location.\&template_name.,newpath=%sysfunc(pathname(work))\&template_name.);*/
%let lots=10;

%macro export_lots();
%do i=1 %to &lots.;
%sys_file_copy(path=&template_location.\&template_name.,newpath=%sysfunc(pathname(work))\&template_name.);
proc export data=sashelp.class(where=(sex="M"))
  dbms=xlsx
  outfile="%sysfunc(pathname(work))\&template_name." replace;
  sheet="Males";
run;

proc export data=sashelp.class(where=(sex="F"))
  dbms=xlsx
  outfile="%sysfunc(pathname(work))\&template_name." replace;
  sheet="Females";
run;

%sys_file_copy(path=%sysfunc(pathname(work))\&template_name.,newpath= &report_staging.\&report_name._&i..xlsx);
%end;
%mend;
%export_lots;