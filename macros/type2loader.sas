/************************************************************************************************************
 * Name:          Type2Loader.sas
 *
 * Type:          SAS macro
 *
 * Description:   Type 2 loader macro. The macro compares a Target and an Update table with each other and
 *                creates a history of all versions of a record on the Target Table.
 *
 * Parameters:    TargetTable
 *                Name of table to be updated
 *                
 *                UpdateTable
 *                Name of table containing updates to the Target Table
 *                
 *                FromVar
 *                Variable name containing valid from values in the Target Table
 *                
 *                ToVar
 *                Variable name containing valid to values in the Target Table
 *                
 *                LoadVar
 *                Variable name containing load datetime values in the Target Table
 *                
 *                IdVars
 *                The names of the columns that forms a unique key
 *                
 *                CompareVars
 *                The names of the columns that should be used when comparing the Target table with the Update Table.
 *                If none are specified, all columns will be compared.
 *                
 *                ValidFromDT
 *                A datetime constant containing the valid from datetime value, ie.: "01Sep2010:00:00:00"dt
 *                
 *                ValidToDT
 *                A datetime constant containing the valid to datetime value, ie.: "31Dec9999:23:59:59"dt
 *                
 *                LoadDT
 *                A datetime constant containing the load datetime value, ie.: "01Nov2010:00:00:00"dt
 *                This value will be put on all new or updated records.
 *                
 *                KeepVars
 *                The names of the columns that should be kept in the Target Table
 *                
 *                Surrogate_Key_Var
 *                Optional - Name of surrogate key.
 *                
 *                UpdateType
 *                Names the type of update.
 *                DELTA: Update Table contains updated or new records.
 *                FULL: Update Table contains all records, existing, new and updated records.
 *                
 *                CreatePrimaryKey
 *                If set to Y, will create a primary key using the columns from IdVars and the FromVar.
 *                
 * Created:       August 2010 Michael Larsen (sdkmik)
 * Changed:       June 2011 Michael Larsen (sdkmik) - Added support for Full compare
 *                October 2013 Michael Larsen - Added support for Surrogate key variable
 * Copyright (C) 2014 by SAS Institute Inc., Cary, NC 27512-8000 
 **********************************************************************************************************************/


%macro type2loader(TargetTable=, 
                    UpdateTable=, 
                    FromVar=, 
                    ToVar=, 
                    LoadVar=, 
                    IdVars=, 
                    CompareVars=, 
                    ValidFromDT=, 
                    ValidToDT=, 
                    LoadDT=, 
                    KeepVars=,
                    Surrogate_Key_Var=,
                    UpdateType=DELTA,
                    CreatePrimaryKey=N);
  
  %let Lib=%scan(&TargetTable,1);
  %let Tab=%scan(&TargetTable,2);
  %let Target=&Tab;
  %let LastID=%sysfunc(reverse(%scan(%sysfunc( reverse(&IdVars) ),1)));
  %let NewTarget=x_&Target;
  %let NewActive=x_&Target;
  %let UpdateType=%upcase(&UpdateType);
  
  %let TargetExist = %sysfunc( exist(&TargetTable));
  %if &TargetExist = 0 %then
    %do;
      /* Initial Load, create an empty Target table */
      data &TargetTable
        %if %str(&KeepVars) ne %str() %then %do;
            (keep=&KeepVars 
          %if %length(&Surrogate_Key_Var) > 0 %then %do;
                  &Surrogate_Key_Var
          %end;
            )
      %end;
        ;
        set &UpdateTable(obs=0);
        length &FromVar &ToVar &LoadVar 8  
      %if %length(&Surrogate_Key_Var) > 0 %then %do;
               &Surrogate_Key_Var 8
      %end;
             ;
        format &FromVar &ToVar &LoadVar datetime20.;
        informat &FromVar &ToVar &LoadVar datetime20.;
        label 
      %if %length(&Surrogate_Key_Var) > 0 %then %do;
          &Surrogate_Key_Var='SURROGATE KEY'
      %end;
          &Fromvar='VALID_FROM_DTTM'
          &Tovar='VALID_TO_DTTM'
          &Loadvar='LOAD_DTTM';
        stop;
      run; 
      /* Create an index on the Target table */
      %let idxstmt = idx1=(&IdVars &ToVar);
      proc datasets lib=&Lib nolist;
        modify &Target ;
      %if %length(&Surrogate_Key_Var) > 0 %then %do;
        index create SurKey = (&Surrogate_Key_Var &ToVar) / unique nomiss ;
      %end;
      %if %upcase(&CreatePrimaryKey) eq Y %then %do;
        ic create PrimKey = PRIMARY KEY (&IdVars &ToVar);
      %end;
        index create &idxstmt / nomiss ;
      quit;
    %end;
    %let idxname=idx1;

  /* Sort the UpdateTable by the key variables */
  proc sort data=&UpdateTable tagsort;
    by &IdVars;
  run;

  /* Get Max surrogate key value from the Target table */
  %let MaxIdValue = 0;
  %if %length(&Surrogate_Key_Var) > 0 %then %do;
    proc sql noprint;
      select max(&Surrogate_Key_Var) format=8. into : MaxIdValue
      from &Lib..&Target ;
    quit;
  %end;
  %if &MaxIdValue le 0 %then %let MaxIdValue = 0;

  /* Compare Target and Update tables */
  proc compare base=&Lib..&Target. (where=(&ToVar. = &ValidToDT.) )
               compare=&UpdateTable.
               out=Difference(keep=_Type_ &IdVars.) 
               outnoequal  noprint;
    id &IdVars;
    by &IdVars;
  %if %str(&CompareVars) ne %str() %then %do;
    var &CompareVars;
  %end;
  run;

  /* Update the Target table */
  data &Lib..&Target.;
    set &UpdateTable(keep=&IdVars. in=transaction) 
        Difference(keep=&IdVars.);
    by &IdVars. ;
    %if %length(&Surrogate_Key_Var.) > 0 %then %do;
      retain _MaxIdValue &MaxIdValue. ;
      drop _MaxIdValue;
    %end;
    retain _TransObs_ 0;
    _TransObs_ + transaction;
    if first.&lastid.;
    &ToVar. = &ValidToDT.;
    modify &Lib..&Target. key=&idxname. / unique;
    if not last.&lastId. and _iorc_=(%sysrc(_sok)) then do;
      if &ToVar. = &ValidToDT. then
        &ToVar.=&ValidFromDT.-1; /* Existing record has been updated, close the current and add the new record */
      replace; /* Close and output existing record */
      &FromVar.=&ValidFromDT.;
      &ToVar.=&ValidToDT.;
      set &UpdateTable. point=_TransObs_ ; /* Read the updated record */
      &LoadVar. = &LoadDT. ;
      output; /* output a new record */
    end;
    else if _iorc_=(%sysrc(_dsenom)) then do; /* New record, add it to the Target table */
      &FromVar.=&ValidFromDT.;
      &ToVar.=&ValidToDT.;
      &LoadVar. = &LoadDT. ;
    %if %length(&Surrogate_Key_Var) > 0 %then %do;
      _MaxIdValue + 1;
    &Surrogate_Key_Var. = _MaxIdValue;
    %end;
      set &UpdateTable. point=_TransObs_ ;  /* Read the new record */
      output;
      _error_=0;
    end;
    else if not _iorc_=(%sysrc(_sok)) then do; /* Error occurred */
      put
      'ERROR: An unexpected I/O error has occurred. Check your data and your program';
      _error_=0;
      stop;
    end;
  run;

  %if &UpdateType = FULL %then %do; /* Detect if any records are not in the transaction and close those records */
    data &Lib..&Target.;
      merge &Lib..&Target(keep=&IdVars. &ToVar. in=master cntllev=record where=(&ToVar. = &ValidToDT.)) 
            &UpdateTable.(keep=&IdVars. in=transaction) ;
      by &IdVars. ;
      if master and not transaction; /* Business Key no longer exist in the system (compared with the transaction) */
      if last.&lastid.;
      &ToVar. = &ValidToDT.;
      modify &Lib..&Target.(cntllev=record) key=&idxname. / unique;
      if _iorc_=(%sysrc(_sok)) then do;
        if &ToVar. = &ValidToDT. then
          &ToVar.=&ValidFromDT.-1; /* Existing record no longer exists, close the record */
        replace; /* Close and output existing record */
      end;
      else if not _iorc_=(%sysrc(_sok)) then do; /* Error occurred */
        put
        'ERROR: An unexpected I/O error has occurred. Check your data and your program';
        _error_=0;
        stop;
      end;
    run;
  %end;
  %let syslast=&Lib..&Target;
%mend;
