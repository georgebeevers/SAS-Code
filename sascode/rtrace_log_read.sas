/*Get the listing of SASROOT files*/
/*Windows BASH terminal search*/
/*find "/mnt/c/Program Files/SASHome/SASFoundation/9.4/" -type f -name "*dll" >/mnt/c/temp/sasexe_dll.txt*/
/*Strip off the start of the mount and then capture the DLL group*/
data sasexe_path (drop=path newstr);
	length path newstr $500. group dll $30.;
	infile "c:\temp\sasexe_dll.txt" missover dsd;
	input Path;
	newstr=tranwrd(path,"/mnt/c/Program Files/SASHome/SASFoundation/9.4/","");
	GROUP=scan(newstr,1,"/");
	DLL=scan(newstr,-1,"/");
run;

/*proc freq data=sasexe_path;*/
/*table group;*/
/*run;*/

/*sukgeb_local_03162021_ 90329_RTRACE.log - STAT and good examples*/
data dll_prods_used sas_data_used;
attrib str length=$200.;
infile "C:\SAS\Config\Lev1\SASApp\WorkspaceServer\rtrace\sukgeb_local_03162021_ 90329_RTRACE.log" dlm=":" flowover  dsd;
input ;

	if index(_infile_,".dll") >0 then do
			str = scan(_infile_,-1,"\","QR");
			output dll_prods_used;
/*			str = scan(_infile_,-1,"\");*/
			end;
		if index(_infile_,".sas7bdat") >0 then do
			str = scan(_infile_,-1,"\","QR");
			output sas_data_used;
/*			str = scan(_infile_,-1,"\");*/
			end;
run;
