/*object Spawner Logs*/
/*Outtbl = Table name of the output*/
/*History = today()-num_days*/
/*A large scan might be needed for the first run to generate the history. Post that the process could*/
/*be amended to run on a weekly basis. It will make it quicker and easier to manage as some log*/
/*management should be in place to archive old logs*/
%object_spawner_logs(outtbl=work.object_spawner_data,history=10);

/*Workspace Server Logs*/
/*Same as above*/
%workspace_Server_logs(outtbl=work.workspace_server_data,history=10);

