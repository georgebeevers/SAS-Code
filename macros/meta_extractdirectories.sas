/**********************************************************************************************************************
 * Name:          meta_extractdirectories.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Directory objects
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractdirectories(Table=Directories);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

  data &Table ;
    length tran_uri Name $80 DirectoryName $500 cUpdated $25 Type $30 ID $17;
    call missing(Name,cUpdated,tran_uri,ID,DirectoryName);
    Type = "Directory";

    ntran=metadata_getnobj("omsobj:Directory?@Id contains '.'",1,tran_uri);
    do c1=1 to ntran;
      rc=metadata_getnobj("omsobj:Directory?@Id contains '.'",c1,tran_uri);

      rc=metadata_getattr(tran_uri,"id",ID);
      rc=metadata_getattr(tran_uri,"name",Name);
      rc=metadata_getattr(tran_uri,"DirectoryName",DirectoryName);
      rc=metadata_getattr(tran_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      output;
    end;
    format Updated datetime18.5;
    drop tran_uri cUpdated ntran rc c1 ;
  run;
  proc sort data=&Table ;
    by Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;

