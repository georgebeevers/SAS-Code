/*List Logger Current Configuration*/
/*Support Ticket - https://support.sas.com/kb/51/911.html*/

%include 'C:\SAS\Config\Lev1\SASMeta\MetadataServer\metaparms.sas';
proc iomoperate;
list types;
run;
/*IOMOPERATE Controls*/
/*CONNECT*/
/*CONTINUE CLUSTER*/
/*CONTINUE SERVER*/
/*DISCONNECT*/
/*FLUSH AUTHORIZATION CACHE*/
/*LIST ATTRIBUTES*/
/*LIST CATEGORIES*/
/*LIST CLASSIDS*/
/*LIST CLIENTS*/
/*LIST CLUSTER CLIENTS*/
/*LIST CLUSTER SESSIONS*/
/*LIST CLUSTER STATE*/
/*LIST COMMANDS*/
/*LIST DEFINED SERVERS*/
/*LIST DNSNAME*/
/*LIST INFORMATION*/
/*`*/
/*LIST LOG CONFIGURATION*/
/*LIST SERVERTIME*/
/*LIST SESSIONS*/
/*LIST STATE*/
/*LIST TYPES*/
/*LIST UNIQUEID*/
/*PAUSE CLUSTER*/
/*PAUSE SERVER*/
/*QUIESCE CLUSTER*/
/*QUIESCE SERVER*/
/*RESET CLUSTER PERFORMANCE*/
/*RESET PERFORMANCE*/
/*SET ATTRIBUTE*/
/*SET LOG CONFIGURATION*/
/*STOP CLUSTER*/
/*STOP SERVER*/
/*STOP SESSION*/

/*List Clients connected*/
/*This process will read the latest log entries and can provide a quick view of what is held in the logs.*/
/*It saves having to navigate to the install location*/
proc iomoperate 
   uri=&connection.;
/*   list COMMANDS; */
   LIST LOG out=metadata_log (where=(entry contains "APPNAME"));
quit;

PROC IOMOPERATE;
    CONNECT uri=&connection.
        servertype=OBJECTSPAWNER;
    LIST COMMANDS;
	LIST SPAWNED SERVERS out=servers;
	LIST ATTRIBUTES out=attribs;
	LIST LOG out=metadata_log (where=(entry contains "APPNAME"));
QUIT;


PROC IOMOPERATE;
    LIST TYPES;
QUIT;

PROC IOMOPERATE;
CONNECT uri=&connection.;
    LIST CLIENTS;
QUIT;




proc iomoperate; 
   connect host=&metaserver.
           port=&metaport.
           user=&metauser.
           pass=&metapass.;

   list attributes category="Loggers"; 
quit;
/*Set Metadata tracing Options*/
/*This will set tracers for Authenticating to the metadata server*/
proc iomoperate; 
   connect host=&metaserver.
           port=&metaport.
           user=&metauser.
           pass=&metapass.;

   list attributes category="Loggers";    
   set attribute category="Loggers" name="Audit.Authentication" value="Trace";
   set attribute category="Loggers" name="App.tk.LDAP" value="Trace";
   set attribute category="Loggers" name="App.tk.eam" value="Trace"; 
   
quit;
/*Rest Options*/
proc iomoperate; 
   connect host=&metaserver.
           port=&metaport.
           user=&metauser.
           pass=&metapass.;

   set attribute category="Loggers" name="Audit.Authentication" value="NULL";
   set attribute category="Loggers" name="App.tk.LDAP" value="NULL";
   set attribute category="Loggers" name="App.tk.eam" value="NULL"; 
   list attributes category="Loggers";  
   
quit;