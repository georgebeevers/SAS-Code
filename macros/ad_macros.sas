/****************************************************************************************************/
/* filename for location where macro %mduimpl saves its generated XML.                                                                                          */
/* This can be a fully qualified filename including the path and .xml                                                                                          */
/* extension.                                                                                                                                                     */
/****************************************************************************************************/
filename keepxml "%sysfunc(pathname(WORK))/request.xml" lrecl=1024;

%macro transmemkeyid;
   %if %upcase(&keyidvar)^=DISTINGUISHEDNAME %then %do;
      proc sql;
         update &idgrpmemstbl
            set memkeyid = 
                case when (select unique &keyidvar from &extractlibref..ldapusers 
                              where memkeyid = distinguishedName)            
                                 is missing then memkeyid           
                     else (select unique &keyidvar from &extractlibref..ldapusers            
                              where memkeyid = distinguishedName)           
                end;           
      quit;     
   %end;
%mend;

/****************************************************************************************************/
/* MACRO: ldapextrpersons                                                                                                                                       */
/*                                                                                                                                                           */
/* To extract user information from ActiveDirectory (AD), the LDAP datastep                                                                                     */
/* interface is used to connect and query AD.                                                                                                                    */
/*                                                                                                                                                           */
/* This macro is used within a datastep which has established an ldap                                                                                                     */
/* connection.  Because some servers will limit the number of directory                                                                                                */
/* entries retrieved on a single search, the datastep will be built with a                                                                                                  */
/* series of filters that are used in this macro to select the entries that                                                                                   */
/* will be processed by the macro.                                                                                                                                          */
/*                                                                                                                                                           */
/* AD ships with standard schemas that define much of the information                                                                                               */
/* needed here. However, the standard schema is often extended with                                                                                              */
/* additional site-specific attributes.  If your site has extended the                                                                                          */
/* scehma, you will need to obtain this information from your local Active                                                                                            */
/* Directory administrator and modify the ldapextrpersons macro accordingly.                                                                                  */
/****************************************************************************************************/
%macro ldapextrpersons(ldapusers=,attrs=sAMAccountName memberof );
  shandle=0;
  num=0;
  
  /* The attrs datastep variable contains a list of the ldap attribute */
  /* names from the standard schema. */
  attrs="&attrs.";        
  /*****************************************************************/
  /* Call the SAS interface to search the LDAP directory.  Upon    */
  /* successful return, the shandle variable will contain a search */
  /* handle that identifies the list of entries returned in the    */
  /* search.  The num variable will contain the total number of    */
  /* result entries found during the search.                       */
  /*****************************************************************/
  call ldaps_search( handle, shandle, filter, attrs, num, rc, 'pr=500' );
  put filter=;

  if rc NE 0 then do;
    msg = "msg 1: "||sysmsg();
    if msg NE "WARNING: No results found." then do;
      put msg;
    end;
  end;

  do eIndex = 1 to num;
    numAttrs=0;
    entryname='';
    
    call ldaps_entry( shandle, eIndex, entryname, numAttrs, rc );
    if rc NE 0 then do;
      msg = sysmsg();
      put msg;
    end;

    sAMAccountName="";  
    memberof="";
	mail="";
	displayname="";

    /* for each attribute, retrieve name and values */
    if (numAttrs > 0) then do aIndex = 1 to numAttrs;      
      attrName='';
      numValues=0;        
      call ldaps_attrName(shandle, eIndex, aIndex, attrName, numValues, rc);
      if rc NE 0 then do;
        put aIndex=;
        msg = sysmsg();
        put msg;
      end;

      /* get the value(s) of the attributes. */
      if attrName="sAMAccountName" then do;
        call ldaps_attrValue(shandle, eIndex, aIndex, 1, sAMaccountName, rc);
        if rc NE 0 then do;
          msg = sysmsg();
          put msg;
        end;
      end;

	        /* get the value(s) of the attributes. */
/*	  Email Address*/
      if attrName="mail" then do;
        call ldaps_attrValue(shandle, eIndex, aIndex, 1, mail, rc);
        if rc NE 0 then do;
          msg = sysmsg();
          put msg;
        end;
      end;
/*Displayname*/
	    if attrName="displayName" then do;
        call ldaps_attrValue(shandle, eIndex, aIndex, 1, displayName, rc);
        if rc NE 0 then do;
          msg = sysmsg();
          put msg;
        end;
      end;

/*Memberof*/
      else if attrName="memberOf" then do;
        do getvalues = 1 to numValues;
          call ldaps_attrValue(shandle, eIndex, aIndex, getvalues, _MEMBEROF(getvalues), rc);
          if rc NE 0 then do;
            msg = sysmsg();
            put msg;
          end;
        end;
      end;
    end;  /* end of attribute loop */


    i=1;
    do until (_MEMBEROF(i) = "");
      MEMBEROF=_MEMBEROF(i);
      output;
      i+1;
    end;

    /*******************************************************************/
    /* It is possible that the ldap query returns entries that do not  */
    /* represent actual persons that should be loaded into metadata.   */
    /* When one of these entries is encountered, skip adding the       */
    /* observation to the ldapusers dataset.  This example expects     */
    /* valid users to have an emplyeeID.  If your ActiveDirectory does */
    /* not use the employeeID attribute, then this condition will need */ 
    /* to be modified.  The condition should resolve to true only when */
    /* the current entry should be defined in the metadata as a user.  */
    /*                                                                 */
    /* Note: Changing the expression below to simply use               */
    /*       distinguishedName instead of employeeID may not be useful.*/
    /*       Every entry will have a distinguishedName, thus the       */
    /*       expression would always be true and no entries would be   */
    /*       filtered.                                                 */
    /*******************************************************************/

  end;
  /* end of entry loop */

  /* free search resources */
  if shandle NE 0 then do;
    call ldaps_free(shandle,rc);
    if rc NE 0 then do;
      msg = sysmsg();
      put msg;
    end;
  end;

%mend;

%macro get_ldap_users/parmbuff;

  %let syspbuff=%substr(&syspbuff,2,%eval(%length(&syspbuff)-2));

  %let ADPerBaseDN=%qscan(%bquote(&syspbuff.),1,|);
  %let filter=%qscan(%bquote(&syspbuff.),2,|);
  %let ds=%qscan(%bquote(&syspbuff.),3,|);
  %let attrs=%qscan(%bquote(&syspbuff.),4,|);

  data &extractlibref..&ds.
    (keep= sAMAccountName memberof mail displayname);

    length entryname $200 attrName $100 filter mail $200 sAMAccountName $32 memberof displayname $256;
    array _MEMBEROF(32767) $256 _temporary_;

    handle = 0;
    rc     = 0;
    option = "OPT_REFERRALS_ON";
                    
    /* open connection to LDAP server */     
    call ldaps_open( handle, &ADServer, &ADPort, "&ADPerBaseDN", &ADBindUser, &ADBindPW, rc, option ); 
    if rc NE 0 then do;
      msg = sysmsg();
      put msg;
    end;
                     
    timeLimit=0;
    sizeLimit=0; 

    base='';  /* use default set at _open time */
    referral = "OPT_REFERRALS_ON";
    restart = ""; /* use default set at _open time */
                     
    call ldaps_setOptions(handle, timeLimit, sizeLimit, base, referral, restart, rc);           

    filter="&filter.";
    %ldapextrpersons(ldapusers=&ds.,attrs=&attrs.);

    /* close connection to LDAP server */
    call ldaps_close(handle,rc);
    if rc NE 0 then do;
      msg = sysmsg();
      put msg;      
    end;
  run;
%mend get_ldap_users;

/*%get_ldap_users(&ADPerBaseDN1.|(&amp.(objectClass=user)(samAccountName=sukgeb))|LDAPUSERS_sukgeb|sAMAccountName memberof mail displayname);*/
