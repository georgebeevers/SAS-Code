* --------------------------------------------------------------------;
* Catalog      : macros                                               ;
* Program Name : metadata_transattr.sas                               ;
*                                                                     ;
* --------------------------------------------------------------------;
* Function:                                                           ;
* Use the metadata_getnatr function to gather attribute information.  ;
*                                                                     ;
* Parameters:                                                         ;
*   omsobj  - Specify the full OMSOBJ / URI reference for the         ;
*     metadata object for which you want to get the full tree         ;
*     e.g. OMSOBJ:JOB\AB12CD34.EF56GH78                               ;
*     Alternatively, specify a dataset with a variable containing a   ;
*     list of OMSOBJ references                                       ;
*   uri     - The column which holds the OMSOBJ / URIs when a dataset ;
*     is used (default "uri").                                        ;
*   attr    - Specify the attribute for which you want to retrieve    ;
*     information. When blank it will extract all attributes.         ;
*   out_ref - The <library>.<dataset> that output is stored in when   ;
*     the "DATA" type is used (default "work._transattr_output_").    ;
*   type    - Whether the output is directed to DATA, the LOG or the  ;
*     OUTPUT window (default "DATA").                                 ;
*   put     - Y/N flag to put information to the log (default "N").   ;
* --------------------------------------------------------------------;
* Version Date      Author of    Change  Brief Description of         ;
* Number  Issued    Modification Req No. Modification                 ;
* ======= ========= ============ ======= =============================;
* 1.0.0   26MAR2018 L Mitchell   N/A     Created                      ;
* 1.0.1   15NOV2018 L Mitchell   N/A     Fixed issue with put         ;
* --------------------------------------------------------------------;
 
%macro metadata_transattr(omsobj=, uri=uri, attr=, out_ref=work._transattr_output_, type=DATA, put=N) / mindelimiter=','
des = 'Use the metadata_getnatr function to gather attribute information.';
 
  options minoperator;
 
  %*** Set macro variables to be local to avoid conflicts. ;
  %local exe_cmd uri_count;
 
  %*** Give execute command a default value of 0. ;
  %let exe_cmd = 0;
 
  %*** If the value of omsobj is a datset that exists then do ... ;
  %if %sysfunc(exist(%superq(omsobj))) %then %do;
 
    %*** If the put flag is used, then put information to the log. ;
    %if %sysfunc(upcase(%superq(put))) = Y %then %do;
      %put ;
      %put INFO: A dataset has been detected as input (%superq(omsobj)). ;
    %end;
 
    %*** Get the contents of the dataset that we know exists. ;
    proc contents noprint
      data = %superq(omsobj)
      out = work.contents;
    run;
 
    %*** Count how many variables match the URI macro variable (it will be either 0 or 1). ;
    proc sql noprint;
      select count(*) 
      into :uri_count separated by ''
      from work.contents
      where upcase(name) = upcase("%superq(uri)")
    ;quit;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        contents
        ;
      run;
    quit;
 
    %*** If the URI count is equal to 1 then set execute command and define the input. ;
    %if &uri_count. = 1 %then %do;
 
      %*** If the put flag is used, then put information to the log. ;
      %if %sysfunc(upcase(%superq(put))) = Y %then %do;
        %put INFO: The variable %superq(uri) has been detected in the dataset (%superq(omsobj)). ;
        %put ;
      %end;
 
      %*** Set execute command. ;
      %let exe_cmd = 1;
 
      %*** Create a dataset with the distinct OMSOBJ stored in the URI variable. ;
      proc sql;
      create table work._uri_input_ as 
        select distinct 
          %superq(uri) as uri length=64
        from %superq(omsobj)
      ;quit;
 
    %end;
    %*** If the URI count is equal to 0 then put an (er)ror to the log. ;
    %else %do;
      %put %str(ER)ROR: The variable %superq(uri) has NOT been detected in the dataset (%superq(omsobj)). ;
    %end;
 
  %end;
  %*** ... otherwise check if the value begins with OMSOBJ: ... ;
  %else %if %sysfunc(substr(%sysfunc(upcase(%superq(omsobj))),1,%length(OMSOBJ:))) = OMSOBJ: %then %do;
    
    %*** If the put flag is used, then put information to the log. ;
    %if %sysfunc(upcase(%superq(put))) = Y %then %do;
      %put ;
      %put INFO: An Ontology Management Studio Object has been detected as input (%superq(omsobj)). ;
      %put ;
    %end;
 
    %*** Set execute command. ;
    %let exe_cmd = 1;
 
    %*** Create a single row dataset with the OMSOBJ stored in the URI variable. ;
    data work._uri_input_;
      length 
        uri $64.
        ;
      uri = "%superq(omsobj)";
    run;
 
  %end;
  %*** ... otherwise put an (er)ror to the log. ;
  %else %do;
    %put %str(ER)ROR: An invalid value has been detected as input (%superq(omsobj)). ;
  %end;
 
  %*** Only execute the next section when execute command is set equal to 1. ;
  %if &exe_cmd. = 1 %then %do;
 
    %*** If any of the correct types are passed then perform the metadata call. ;
    %if %sysfunc(upcase(%superq(type))) in DATA, LOG, OUTPUT %then %do;
 
      %*** If there is no attr value populated then perform a general metadata attribute query. ;
      %if %sysevalf(%superq(attr)=,boolean) = 1 %then %do;
 
        data work._transattr_output_1a_ (keep=uri attr value);
          set work._uri_input_;
          length
            attr $256
            value $512
            ;
          rc1=1;
          i=1;
          %*** Loop until the return code is 0 indicating there is not an i+1 attribute. ;
          do until(rc1<=0);
            %*** Walk through all possible attributes for the object. ;
            rc1=metadata_getnatr(uri,i,attr,value);
            if (rc1>0) then do;
              output;
            end;
            i=i+1;
          end;
        run;
 
      %end; 
      %*** If there is an attr value populated then perform a specific metadata attribute query. ;
      %else %do;
 
        data work._transattr_output_1a_ (keep=uri attr value);
          set work._uri_input_;
          length
            attr $256
            value $512
            ;
          attr = "%superq(attr)";
          rc1=metadata_getattr(uri,attr,value);
          if (rc1>=0) then do;
            output;
          end;
        run;
 
      %end;
 
      %*** Find the max utilised length for each unique attribute. ;
      proc sql;
      create table work._transattr_output_1b_ as 
        select 
          attr,
          max(length(value)) as max_length
        from work._transattr_output_1a_
        group by attr
      ;quit;
 
      %*** Count how many distinct attributes there are. ;
      proc sql noprint;
        select count(*) into :attr_count
        from work._transattr_output_1b_ 
      ;quit;
 
      %*** Strip out the leading spaces that are written to the macro variable ahead of the number. ;
      %let attr_count = %sysfunc(strip(&attr_count.));
 
      %*** 1.0.1 - If the put flag is used, then put information to the log. ;
      %if %sysfunc(upcase(%superq(put))) = Y %then %do;
        %put INFO: attr_count = &attr_count.;
      %end;
 
      %if &attr_count. > 0 %then %do;
 
        %*** Read all attribute names and max utilised lengths into macro variable arrays. ;
        proc sql noprint;
          select 
            attr,
            max_length 
          into 
            :attr1-:attr&attr_count.,
            :len1-:len&attr_count.
          from work._transattr_output_1b_ 
        ;quit;
 
        %*** Transpose the data using macro variable arrays and defined utilised lengths. ;
        proc sql;
        create table work._uri_output_ as 
          select 
            uri
            %do i=1 %to &attr_count.;
              ,max(case when attr = "&&attr&i.." then value else '' end) as &&attr&i.. length=&&len&i..
            %end;
          from work._transattr_output_1a_ 
          group by uri
          order by uri
        ;quit;
 
      %end;
      %else %do;
        
        proc sql;
        create table work._uri_output_ as 
          select 
            uri
          from work._transattr_output_1a_ 
          order by uri
        ;quit;
 
      %end;
 
      %*** Delete the temp table(s). ;
      proc datasets lib=work nolist;
        delete
          _transattr_output_1a_
          _transattr_output_1b_
          ;
        run;
      quit;
 
    %end;
 
    %*** If the type is DATA then output to the specified output reference. ;
    %if %sysfunc(upcase(%superq(type))) = DATA %then %do;
      data %superq(out_ref);
        set work._uri_output_;
      run;
    %end;
 
    %*** If the type is LOG then print the information to the log. ;
    %else %if %sysfunc(upcase(%superq(type))) = LOG %then %do;
      data _null_;
        set work._uri_output_;
        put (_all_)( = );
      run;
    %end;
 
    %*** If the type is OUTPUT then print the information to the results / output window. ;
    %else %if %sysfunc(upcase(%superq(type))) = OUTPUT %then %do;
      proc print
        data = work._uri_output_;
        var _all_;
      run;
    %end;
 
    %*** Otherwise put an (ER)ROR to the log. ;
    %else %do;
      %put %str(ER)ROR: The only valid values for "type" are "DATA", "LOG" and "OUTPUT";
    %end;
 
  %end;
 
  %if %sysfunc(exist(work._uri_input_)) %then %do;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        _uri_input_
        ;
      run;
    quit;
 
  %end;
 
  %if %sysfunc(exist(work._uri_output_)) %then %do;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        _uri_output_
        ;
      run;
    quit;
 
  %end;
 
%mend metadata_transattr;
