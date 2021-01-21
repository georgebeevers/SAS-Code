%macro meta_extractroles(Table=Roles);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  data &Table;
    length identity_uri $80 Name Displayname $60 cUpdated $25 ID $17 PublicType $20 ;
    call missing(of _all_);
    nName=metadata_getnobj("omsobj:Identity?@ID contains '.'",1,identity_uri);
    do n1=1 to nName;
      rc=metadata_getnobj("omsobj:Identity?@Id contains '.'",n1,identity_uri);
      rc=metadata_getattr(identity_uri,"PublicType",PublicType);
      if PublicType ne 'Role' then continue;
      rc=metadata_getattr(identity_uri,"id",ID);
      rc=metadata_getattr(identity_uri,"NAME",Name);
      rc=metadata_getattr(identity_uri,"DisplayName",Displayname);
      rc=metadata_getattr(identity_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      output;
    end;
    drop nName n1 rc identity_uri cUpdated PublicType;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);
%mend;
/*%meta_extractroles;*/
