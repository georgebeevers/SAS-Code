/**********************************************************************************************************************
  *
  *  PROGRAM NAME	: meta_extractnotes
  *  VERSION		: 1.0
  *  PROGRAM TYPE   : Macro
  *  DIRECTORY      :       
  *  AUTHOR NAME    : Per Helmark
  *  CREATE DATE    : 30/10/2013
  *  DESCRIPTION    : Extracts quick notes from Metadata Server
  *  USAGE          : %meta_extractnotes(outdsn=notes, NoteType=PrivateNote Document);
  *  PARAMETERS	    : OutDSN - Name of the output dataset
  *					: NoteType - Specify the type(s) of note that should be extracted (PrivateNote, Document, StickyNote, ALL).
  *  INPUT          : None
  *  OUTPUT         : Table containing various types of notes that can be used as documentation in SAS Data Integration Studio
  *  DEPENDENCIES   : None
  *  NOTES    	    : Usefull to combine with meta_extracttables(IncludeColumns=Yes);
  *  CHANGE LOG	    : 31/10/2013 - Added extract of attached documents	
  *					  06/11/2013 - Added extract of sticky notes from DI jobs 
  *					  13/11/2013 - Added note type selection
  *
 **********************************************************************************************************************/

%macro meta_extractnotes(OutDsn=Notes, NoteType=ALL)/minoperator;
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

	%let server= %sysfunc( getoption(metaserver));
	%let Repository= %sysfunc(compress (%sysfunc( getoption(metarepository)),'"'));
	%put NOTE: Extracting information from Metadata Server: &Server, Repository: &Repository;

	data &outdsn;
		length Type TextType attr_nm $20 Name $80 ID $17 Note $1000 Updated 8 
			note_uri object_uri doc_uri Job_uri PropertySets_uri SetProperties_uri $80 
			ObjectType $50 ObjectID $17	cUpdated $25 ObjectName $80 StickyNote $32000
			nNotes nNote nDocs nDoc nJobs nJob nPropertySets nPropertySet nSetProperties nSetProperty 8
		;
		htmlpattern=prxparse("s/\s*(\<[^\>]*\>\s*)*([^\<]*)(\<[^\>]*\>\s*)*/$2/");
		stickynotepattern=prxparse("s/.*<StickyNoteNode>.*<Text>(.*)<\/Text>.*/$1/");

		%IF PRIVATENOTE in %upcase(&NoteType) or %upcase(&NoteType)=ALL %THEN
			%DO;
				call missing(note_uri);
				nNotes=metadata_getnobj("omsobj:TextStore?@Name = 'PrivateNote'",1,note_uri);

				do nNote=1 to nNotes;
					call missing(Type,object_uri,Name,Updated,cUpdated,ID,Note,ObjectType,ObjectID,ObjectName);
					rc=metadata_getnobj("omsobj:TextStore?@Name = 'PrivateNote'",nNote,note_uri);
					rc=metadata_getattr(note_uri,"Id",ID);
					rc=metadata_getattr(note_uri,"Name",Name);
					rc=metadata_getattr(note_uri,"StoredText",Note);
					rc=metadata_getattr(note_uri,"TextRole",Type);
					rc=metadata_getattr(note_uri,"MetadataUpdated",cUpdated);
					Updated=input(cUpdated,datetime18.5);
					rc=metadata_getnasn(note_uri,"Objects",1,object_uri);

					if object_uri ne '' then
						do;
							rc=metadata_resolve(object_uri,ObjectType,ObjectID);
							rc=metadata_getattr(object_uri,"Name",ObjectName);
						end;

					output;
				end;
			%END;

		%IF DOCUMENT in %upcase(&NoteType) or %upcase(&NoteType)=ALL %THEN
			%DO;
				call missing(doc_uri);
				nDocs=metadata_getnobj("omsobj:Document?@Id contains '.'",1,doc_uri);

				do nDoc=1 to nDocs;
					call missing(type,texttype,doc_uri,Name,Updated,cUpdated,ID);
					rc=metadata_getnobj("omsobj:Document?@Id contains '.'",nDoc,doc_uri);
					rc=metadata_getattr(doc_uri,"Id",ID);
					rc=metadata_getattr(doc_uri,"Name",Name);
					rc=metadata_getattr(doc_uri,"URI",note);
					rc=metadata_getattr(doc_uri,"MetadataUpdated",cUpdated);
					rc=metadata_getattr(doc_uri,"PublicType",Type);

					if Type='' then
						do;
							rc=metadata_getattr(doc_uri,"TextRole",Type);
						end;

					if Type='' then
						Type='Other';
					Updated=input(cUpdated,datetime18.5);
					object_uri='';
					ObjectType='';
					ObjectID='';
					ObjectName='';
					rc=metadata_getnasn(doc_uri,"Objects",1,object_uri);

					if object_uri ne '' then
						do;
							rc=metadata_resolve(object_uri,ObjectType,ObjectID);
							rc=metadata_getattr(object_uri,"Name",ObjectName);
						end;

					note_uri='';
					rc=metadata_getnasn(doc_uri,"Notes",1,note_uri);

					if note_uri ne '' then
						do;
							rc=metadata_getattr(note_uri,"StoredText",Note);
							rc=metadata_getattr(note_uri,"TextType",TextType);
						end;

					if upcase(TextType)='HTML' then
						do;
							note=prxchange(htmlpattern,1,note);
						end;

					output;
				end;
			%END;

		%IF STICKYNOTE in %upcase(&NoteType) or %upcase(&NoteType)=ALL %THEN
			%DO;
				call missing(Job_uri);
				nJobs=metadata_getnobj("omsobj:Job?@Id contains '.'",1,job_uri);

				do nJob=1 to nJobs;
					call missing(Job_uri,PropertySets_uri,SetProperties_uri,stickyNote,attr_nm);
					rc=metadata_getnobj("omsobj:Job?@Id contains '.'",nJob,Job_uri);
					rc=metadata_resolve(job_uri,ObjectType,ObjectID);
					rc=metadata_getattr(job_uri,"Name",ObjectName);
					nPropertySets=metadata_getnasn(job_uri,"PropertySets",1,PropertySets_uri);

					do nPropertySet=1 to nPropertySets;
						rc=metadata_getnasn(job_uri,"PropertySets",nPropertySet,PropertySets_uri);
						rc=metadata_getattr(PropertySets_uri,"Name",attr_nm);

						if attr_nm = 'USERPROPERTIES' then
							do;
								nSetProperties=metadata_getnasn(PropertySets_uri,"SetProperties",1,SetProperties_uri);

								do nSetProperty=1 to nSetProperties;
									rc=metadata_getnasn(PropertySets_uri,"SetProperties",nSetProperty,SetProperties_uri);
									rc=metadata_getattr(SetProperties_uri,"Name",attr_nm);

									if attr_nm = 'DiagramXML' then
										do;
											rc=metadata_getattr(SetProperties_uri,"DefaultValue",stickyNote);

											if prxmatch(stickynotepattern,stickyNote) then
												do;
													Note=prxchange(stickynotepattern,1,stickyNote);
													rc=metadata_getattr(SetProperties_uri,"Id",ID);
													rc=metadata_getattr(SetProperties_uri,"Name",Name);
													rc=metadata_getattr(SetProperties_uri,"MetadataUpdated",cUpdated);
													Updated=input(cUpdated,datetime18.5);
													Type='Sticky Note';
													output;
												end;
										end;
								end;
							end;
					end;
				end;
			%END;

		drop note_uri doc_uri object_uri nNotes nNote nDocs nDoc nJob nJobs nPropertySet nPropertySets nSetProperty nSetProperties
			rc cUpdated htmlpattern stickynotepattern texttype Job_uri PropertySets_uri SetProperties_uri stickyNote attr_nm;
		format Updated datetime.;
	run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
%*meta_extractnotes(OutDsn=Notes, NoteType=PrivateNote Document);
