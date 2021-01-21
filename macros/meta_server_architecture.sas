%macro meta_server_architecture(table=);
%let uriname=ServerComponent;
%let searchvar=id;
%let searchval=.;
%let searchvar=%trim(&searchvar);
%let searchval=%trim(&searchval);

/*options metaserver="&metaserver"*/
/*	metaport=&metaport*/
/*	metaprotocol=&metaprotocol*/
/*	metauser="&usr"*/
/*	metapass="&pw";*/
data _null_;
	length ver $20;
	ver=left(put(metadata_version(),8.));
	put ver=;
	call symput('METAVER',ver);
run;

%if %eval(&metaver>0) %then
	%do;   /* connected to metadata server */

data server_connections(keep=id name vendor productname softwareversion hostname port con_name app_pro com_pro authdomain )
	server_options    (keep=name server_opts);
	length mac_uri dom_uri con_uri urivar convar uri  $500
	id  $20 name vendor productname $50 softwareversion $10 port $4
	authdomain authdesc hostname con_name $40 app_pro com_pro  propname $20 pvalue pdesc $200 server_opts $500 
	assn attr value svar sval $200;
	nobj=1;
	n=1;

	/* Determine how many repositories are on this server. */
	sval=left(trim(symget("SEARCHVAL")));
	svar=left(trim(symget("SEARCHVAR")));
	urivar=cat("omsobj:", "&uriname", "?@",svar," contains '",sval,"'");
	put urivar;
	nobj=metadata_getnobj(urivar,n,uri);
	put nobj;

	do i=1 to nobj;
		nobj=metadata_getnobj(urivar,i,uri);
		put name=;
		put '-----------------------------------';
		rc=metadata_getattr(uri,"Name",Name);
		rc=metadata_getattr(uri,"id",id);
		rc=metadata_getattr(uri,"vendor",vendor);
		rc=metadata_getattr(uri,"productname",productname);
		rc=metadata_getattr(uri,"softwareversion",softwareversion);
		convar=cat('omsobj:',id);
		hostname=' ';
		nummac=metadata_getnasn(uri,
			"AssociatedMachine",
			1,
			mac_uri);

		if nummac then
			do;
				rc=metadata_getattr(mac_uri,"name",hostname);
			end;

		numcon=metadata_getnasn(uri,
			"SourceConnections",
			1,
			con_uri);
		port=' ';
		con_name=' ';
		app_pro=' ';
		com_pro=' ';

		if numcon>0 then
			do;
				/* server with connections */
				do k=1 to numcon;
					numcon=metadata_getnasn(uri,
						"SourceConnections",
						k,
						con_uri);

					/* Walk through all the notes on this machine object. */
					rc=metadata_getattr(con_uri,"port",port);
					rc=metadata_getattr(con_uri,"hostname",hostname);
					rc=metadata_getattr(con_uri,"name",con_name);
					rc=metadata_getattr(con_uri,"applicationprotocol",app_pro);
					rc=metadata_getattr(con_uri,"communicationprotocol",com_pro);
					numdom=metadata_getnasn(con_uri,
						"Domain",
						1,
						dom_uri);
					put numdom=;

					if numdom >=1 then
						do;
							rc=metadata_getattr(dom_uri,"name",authdomain);
							rc=metadata_getattr(dom_uri,"desc",authdesc);
						end;
					else authdomain='none';
					put authdomain=;
					output server_connections;
				end;
			end;
		else
			do;
				put 'Server with no connections=' name;

				if hostname ne ' ' then
					output server_connections;
			end;

		server_opts='none';
		numprop=metadata_getnasn(uri,
			"Properties",
			1,
			con_uri);

		do x=1 to numprop;
			numcon=metadata_getnasn(uri,
				"Properties",
				x,
				con_uri);

			/* Walk through all the notes on this machine object. */
			rc=metadata_getattr(con_uri,"propertyname",propname);
			rc=metadata_getattr(con_uri,"name",pdesc);
			rc=metadata_getattr(con_uri,"defaultvalue",pvalue);
			server_opts=cat(trim(pdesc),' : ',trim(pvalue));
			output server_options;
		end;
	end;
run;
%end;
proc sort data=server_connections;
	by name;
run;

proc sort data=server_options;
	by name;
run;

proc transpose data=server_options out=sopts prefix=opt;
	by name;
	var server_opts;
run;

data &table;;
	merge server_connections server_options;
	by name;
run;

proc datasets lib=work noprint;
delete SERVER_CONNECTIONS;
delete server_options;
delete sopts;
run;

%mend;

