%macro meta_get_objspawn_host();
data work.objspawn;
	keep host_name port; /* Only keep hosts and port for Object Spawners. */
	retain port; /* Keep port for all iterations. */

	/* Declare and initialize variables. */
	length type id objspwn_uri tree_uri mach_uri host_name conn_uri port $ 50;
	call missing(of _character_);

	/* This is the XML Select query to locate Object Spawners. */
	obj="omsobj:ServerComponent?@PublicType='Spawner.IOM'"; /* Test for definition of Object Spawner(s) in Metadata. */
	objspwn_cnt=metadata_resolve(obj,type,id);

	if objspwn_cnt > 0 then
		do n=1 to objspwn_cnt; /* Get URI for each Object Spawner found. */
			rc=metadata_getnobj(obj,n,objspwn_uri); /* Get associated attributes for the object spawner (connection port and hosts) */
			rc=metadata_getnasn(objspwn_uri,"SoftwareTrees",1,tree_uri);
			rc=metadata_getnasn(objspwn_uri,"SourceConnections",1,conn_uri);
			rc=metadata_getattr(conn_uri,"Port",port);
			mach_cnt=metadata_getnasn(tree_uri,"Members",1,mach_uri); /* For each host found, get the host name and output it along with the port number to the dataset. */

			do m=1 to mach_cnt;
				rc=metadata_getnasn(tree_uri,"Members",m,mach_uri);
				rc=metadata_getattr(mach_uri,"Name",host_name);
				output;
			end;

		end;
	else put "No Object Spawners defined in Metadata.";
run; /* WORK.OBJSPAWN now contains a list of hosts running Object Spawners. */
%mend;