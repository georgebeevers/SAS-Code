/**********************************************************************************************************************
 * Name:          meta_extractexternalfiles.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about External Tables and Columns
 *                
 * Parameters:    Table           - Name of table to be created 
 *                IncludeColumns  - Yes:Include Column object information, No: Only 
 *                drop_uri        - Yes:Drop the URI column that contains the ExternalTable object ID
 *                                  No: Keep the URI column that contains the ExternalTable object ID
 *                Name            - If specified, must be the Name of the ExternalTable object to be searched for.
 *                                  If no name is specified, all ExternalTable objects will be returned.
 *                Path            - If specified the external file object must reside within the specified path.
 *                
 * Created:       14. May. 2012, Michael Larsen, SAS Institute
 *                20. Jan. 2014, Michael Larsen, SAS Institute - Added attributes for the infile statement.
 *                
 **********************************************************************************************************************/
%macro meta_extractexternalfiles(
       Table=ExternalFiles
      ,IncludeColumns=No
      ,drop_uri=YES
      ,Name=
      ,Path=
      );
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %if %str(&IncludeColumns) = %str() %then
    %let IncludeColumns = NO;
  %let IncludeColumns = %upcase(&IncludeColumns);
  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  %let Repository= %sysfunc(compress (%sysfunc( getoption(metarepository)),'"'));
  %put NOTE: Extracting information from Metadata Server: &Server, Repository: &Repository;

  data &Table;
    length tables_uri tab_uri $80 
      source_uri sasvar_uri $80
      Name  $80 
      Updated 8 cUpdated $25 Server $60 Repository $60 Type $30 ID $17
    ;
    retain server "&server" Repository "%unquote(&Repository)";
    call missing(tables_uri, tab_uri, source_uri, sasvar_uri, Name, Updated, cUpdated,ID);
    Type = "ExternalFile";

    %if %length(&Name) = 0 %then
      %do;
        ntab=metadata_getnobj("omsobj:ExternalTable?@Id contains '.'",1,tab_uri);
      %end;
    %else
      %do;
        ntab=metadata_getnobj("omsobj:ExternalTable?@Name = '"||"%unquote(&Name)"||"'",1,tab_uri);
      %end;

    if ntab <= 0 then
      put 'WARNING: Did not find any External Files in Metadata Server.';
    else put 'NOTE: Found ' ntab 'External Files in Metadata Server.';
    do ntables=1 to ntab BY 1;
      %if %length(&Name) = 0 %then
        %do;
          ntab=metadata_getnobj("omsobj:ExternalTable?@Id contains '.'",ntables,tab_uri);
        %end;
      %else
        %do;
          ntab=metadata_getnobj("omsobj:ExternalTable?@Name = '"||"%unquote(&Name)"||"'",ntables,tab_uri);
        %end;

      rc=metadata_getattr(tab_uri,"id",ID);
      rc=metadata_getattr(tab_uri,"Name",Name);
      rc=metadata_getattr(tab_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);

      * OwningFile;
      length own_uri prop_uri efi_prop_uri efi_notes_uri $80 FilePath $250 efi_name $40 delimiter $10
        cvalue $100 lrecl 8 startobs 8 obs 8 createview $5 casesensitivecolumns $5 specialcharrsincolumns $5
        infileencoding $20 infileoptions $100 infileoverride $100 missingvalues_numbers $1 missingvalues_special $2 filenamequoting $6;
      call missing(own_uri, prop_uri, FilePath, efi_name, efi_prop_uri, efi_notes_uri, delimiter,
        cvalue, lrecl, startobs, obs, delimiter, createview, casesensitivecolumns,
        specialcharrsincolumns, infileencoding, infileoptions, infileoverride, missingvalues_numbers,
        missingvalues_special, filenamequoting );
      createview = 'false';
      filenamequoting = 'single';
      casesensitivecolumns = 'false';
      specialcharrsincolumns = 'false';
      rc=metadata_getnasn(tab_uri,"OwningFile",1,own_uri);

      if rc > 0 then
        do;
          rc=metadata_getattr(own_uri,"FileName",FilePath);
          props=metadata_getnasn(own_uri,"PropertySets",1,prop_uri);

          do prop=1 to props;
            rc=metadata_getnasn(own_uri,"PropertySets",prop,prop_uri);
            rc=metadata_getattr(prop_uri,"Name",efi_name);

            if efi_name = 'EFI_FILE_STRUCTURE' then
              do;
                set_props=metadata_getnasn(prop_uri,"SetProperties",prop,efi_prop_uri);

                do set_prop=1 to set_props;
                  rc=metadata_getnasn(prop_uri,"SetProperties",set_prop,efi_prop_uri);
                  rc=metadata_getattr(efi_prop_uri,"Name",efi_name);
                  select (efi_name);
                    when ('DELIMTER')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",prop,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);

                        if efi_name = 'INFILEDELIMITER' then
                          rc=metadata_getattr(efi_notes_uri,"StoredText",delimiter);
                      end;

                    when ('FIXEDWIDTH')
                      do;
                        /* Properties: PAD, TRUNCOVER, OVERLAP */
                      end;
                    when ('CONSECUTIVEDELIMITERS')
                      do;
                        /* Properties: DSD option */
                      end;
                    when ('DELIMITERQUOTING')
                      do;
                        /* Properties: DELIMITER??? option */
                      end;
                    when ('MISSOVER')
                      do;
                        /* Properties: MISSOVER option */
                      end;
                    when ('MULTIRECORDSPERLINE')
                      do;
                        /* Properties: FLOWOVER???? option */
                      end;
                    when ('OVERRIDEDELIMITER')
                      do;
                        /* Properties: DLMSTR???? option */
                      end;
                    otherwise put 'WARNING: Unhandled property: ' efi_name ', ExternalTable: ' name ' (EFI_FILE_STRUCTURE)';
                  end;
                end;
              end;
            else if efi_name = 'EFI_GENERAL' then
              do;
                set_props=metadata_getnasn(prop_uri,"SetProperties",prop,efi_prop_uri);

                do set_prop=1 to set_props;
                  call missing(efi_notes_uri, efi_name);
                  rc=metadata_getnasn(prop_uri,"SetProperties",set_prop,efi_prop_uri);
                  rc=metadata_getattr(efi_prop_uri,"Name",efi_name);
                  select (efi_name);
                    when ('CREATEVIEW')
                      do;
                        rc=metadata_getattr(efi_prop_uri,"DefaultValue",createview);
                        createview = ifc(createview='true',createview,'false','false');
                      end;

                    when ('DOUBLEQUOTE') 
                      filenamequoting = 'double';
                    when ('CASESENSITIVECOLUMNS')
                      do;
                        rc=metadata_getattr(efi_prop_uri,"DefaultValue",casesensitivecolumns);
                        casesensitivecolumns = ifc(casesensitivecolumns='true',casesensitivecolumns,'false','false');
                      end;

                    when ('SPECIALCHARACTERSINCOLUMNS') 
                      rc=metadata_getattr(efi_prop_uri,"DefaultValue",specialcharrsincolumns);
                    when ('INFILEENCODING')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",1,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);
                        rc=metadata_getattr(efi_notes_uri,"StoredText",infileencoding);
                      end;

                    when ('INFILEOPTIONS')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",1,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);
                        rc=metadata_getattr(efi_notes_uri,"StoredText",infileoptions);
                      end;

                    when ('INFILEOVERRIDE')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",1,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);
                        rc=metadata_getattr(efi_notes_uri,"StoredText",infileoverride);
                      end;

                    when ('MISSINGVALUES_NUMBERS')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",1,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);
                        rc=metadata_getattr(efi_notes_uri,"StoredText",missingvalues_numbers);
                      end;

                    when ('MISSINGVALUES_SPECIAL')
                      do;
                        rc=metadata_getnasn(efi_prop_uri,"Notes",1,efi_notes_uri);
                        rc=metadata_getattr(efi_notes_uri,"Name",efi_name);
                        rc=metadata_getattr(efi_notes_uri,"StoredText",missingvalues_special);
                      end;

                    when ('LRECL')
                      do;
                        rc=metadata_getattr(efi_prop_uri,"DefaultValue",cvalue);
                        lrecl = input(cvalue,8.);
                      end;

                    when ('STARTRECORD')
                      do;
                        rc=metadata_getattr(efi_prop_uri,"DefaultValue",cvalue);
                        startobs = input(cvalue,8.);
                      end;

                    when ('OBS')
                      do;
                        rc=metadata_getattr(efi_prop_uri,"DefaultValue",cvalue);
                        obs = input(cvalue,8.);
                      end;

                    when ('READDIRECTORY');
                    otherwise put 'WARNING: Unhandled property: ' efi_name ', ExternalTable: ' name ' (EFI_GENERAL)';
                  end;
                end;
              end;
          end;
        end;

      * ResponsibleParty;
      length resp_uri $80 Responsible $50;
      resp_uri = "";
      Responsible = "";
      rc=metadata_getnasn(tab_uri,"ResponsibleParties",1,resp_uri);

      if rc > 0 then
        do;
          rc=metadata_getattr(resp_uri,"NAME",Responsible);
        end;

      * Trees;
      length Trees_uri $80 FolderName $40;
      FolderName = "";
      rc=metadata_getnasn(tab_uri,"Trees",1,Trees_uri);
      rc=metadata_getattr(Trees_uri,"NAME",FolderName);

      * ParentTree;
      length Path $500 ParentTree_uri $80 ParentTree_name $40;
      ParentTree_uri = "";
      ParentTree_name = "";
      Path = FolderName;
      parentRc = 1;

      do while (parentRc = 1);
        parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
        rc=metadata_getattr(ParentTree_uri,"NAME",ParentTree_name);

        if parentRc = 1 then
          Path = trim(ParentTree_Name) || '/' || Path;
        Trees_uri = ParentTree_uri;
      end;

      if "&Path." ne "" then
        do;
          if Path ne "%unquote(&Path.)" then
            continue;
        end;

      %if %str(&IncludeColumns) = %str(YES) %then
        %do;
          length columnID $17 varname $40 ColumnUpdated 8 length $4 coltype $1 colAllowNull $1 collabel $100 colformat colinformat $40;
          format ColumnUpdated datetime.;
          call missing(varname, length, columnID, coltype, ColumnUpdated, collabel, colformat, colinformat, colAllowNull);
          nvars = metadata_getnasn(tab_uri,"Columns",1,sasvar_uri);

          do ncolumns=1 to nvars;
            rc=metadata_getnasn(tab_uri,"Columns",ncolumns,sasvar_uri);
            rc=metadata_getattr(sasvar_uri,"Name",varname);
            rc=metadata_getattr(sasvar_uri,"SASColumnLength",length);
            rc=metadata_getattr(sasvar_uri,"SASColumnType",coltype);
            rc=metadata_getattr(sasvar_uri,"Desc",collabel);
            rc=metadata_getattr(sasvar_uri,"IsNullable",colAllowNull);
            colAllowNull = ifc(colAllowNull='0','N','Y','N');
            rc=metadata_getattr(sasvar_uri,"SASFormat",colformat);
            rc=metadata_getattr(sasvar_uri,"SASInformat",colinformat);
            rc=metadata_getattr(sasvar_uri,"ID",columnID);
            rc=metadata_getattr(sasvar_uri,"MetadataUpdated",cUpdated);
            ColumnUpdated=input(cUpdated,datetime18.5);
            output;
          end;

          drop ncolumns nvars;
        %end;
      %else
        %do;
          output;
        %end;
    end;

    drop tables_uri ntables rc ntab  cUpdated   ParentTree_Name parentRc FolderName 
      prop_uri efi_prop_uri efi_notes_uri efi_name props prop set_props set_prop
      cvalue;

    %if &drop_uri=YES %then
      %do;
        drop sasvar_uri tab_uri resp_uri own_uri source_uri Trees_uri ParentTree_uri;
      %end;

    format Updated datetime.;
  run;

  proc sort data=&Table;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
