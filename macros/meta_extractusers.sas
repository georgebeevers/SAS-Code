%macro meta_extractusers(Table=Users);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  data &Table;
    length identity_uri $80 Name Displayname $60 cUpdated $25 ID $17 PublicType $20 GroupID $17 GroupName $60
           GroupType $30 GroupDisplayname $60 group_uri $80 extid_uri $80 Context $100 Identifier $128;
    call missing(of _all_);
    nName=metadata_getnobj("omsobj:Identity?@ID contains '.'",1,identity_uri);
    do n1=1 to nName;
      rc=metadata_getnobj("omsobj:Identity?@Id contains '.'",n1,identity_uri);
      rc=metadata_getattr(identity_uri,"PublicType",PublicType);
      if PublicType ne 'User' then continue;
      rc=metadata_getattr(identity_uri,"id",ID);
      rc=metadata_getattr(identity_uri,"NAME",Name);
      rc=metadata_getattr(identity_uri,"DisplayName",Displayname);
      rc=metadata_getattr(identity_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      call missing(Context,Identifier);
      nExitId=metadata_getnasn(identity_uri,"ExternalIdentities",1,extid_uri);
      do n2=1 to nExitId;
        rc=metadata_getnasn(identity_uri,"ExternalIdentities",n2,extid_uri);
        rc=metadata_getattr(extid_uri,"Context",Context);
        rc=metadata_getattr(extid_uri,"Identifier",Identifier);
      end;

      nGroup=metadata_getnasn(identity_uri,"IdentityGroups",1,group_uri);
      do n2=1 to nGroup;
        rc=metadata_getnasn(identity_uri,"IdentityGroups",n2,group_uri);
        rc=metadata_getattr(group_uri,"id",GroupID);
        rc=metadata_getattr(group_uri,"NAME",GroupName);
        rc=metadata_getattr(group_uri,"PublicType",GroupType);
        rc=metadata_getattr(group_uri,"DisplayName",GroupDisplayname);

        output;
      end;
    end;
    drop nName n1 rc identity_uri cUpdated PublicType nGroup n2 group_uri;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);
%mend;
