USE DBA
GO

if not exists (select 1 from sys.types where name='gaBatchKeyType')
create type gaBatchKeyType as table (rowkey bigint);
go


create or alter procedure [dbo].[invoke_ga] 
	@pTableName sysname,
	@pKeyCol sysname, 
	@job_name sysname = NULL, 
	@job_proc sysname = NULL, 
	@pTrgTableName sysname = NULL,
	@pWhereAnd nvarchar(max) = NULL,
	@pNbOfRowsToMove bigint = NULL,
	@pContJob bit = 1,
	--@degree tinyint = 0,
	@async bit = 0,
	@silent bit = 0
	
as

set nocount on

declare @degree tinyint = 0
/*
Params:

4) NbOfRowsToMove:  Antal af de ældste linjer der skal flyttes og slettes.
5) Parallel degree
6) Async

Status dataset:
1) JobId
2) StartTimestamp
3) Job
3) Status: init, run, failed, completed
4) Params

Call with params: Init, if running with the same parameters, return status failed (reason same job is running)
Call with JobId parameter - return status dataset

exec dbo.invoke_ga
	@pTableName = 'bricklink.dbo.Wanted',
	@pKeyCol = 'wantedID'


*/

declare @job_id uniqueidentifier;
declare @srcTableName sysname = PARSENAME(@pTableName, 1);
declare @params_txt nvarchar(max) = '';
declare @est_count bigint = 0, @comm_count bigint = 0;
declare @last_keyid bigint = NULL;
declare @stmt nvarchar(max);

set @job_name = isnull(@job_name,'ga_'+@srcTableName);
set @pTrgTableName = isnull(@pTrgTableName,replace(@pTableName,@srcTableName,'ga_'+@srcTableName));
set @job_proc = isnull(@job_proc,'pr'+@job_name);
set @params_txt = @pWhereAnd 

if not exists (select 1 from sys.tables where name = 'ga_status') 
	create table ga_status (
		job_id uniqueidentifier not null, job_part tinyint, 
		start_time datetime default getdate(), job_name nvarchar(200) not null, 
		--parallel_degree smallint, 
		job_async bit, 
		params nvarchar(max), status_desc nvarchar(20),  
		requested_rows bigint, estimated_rows bigint, committed_rows bigint, 
		cont_job bit, last_keyid nvarchar(20) 
	);

if not exists (select 1 from sys.tables where name = 'ga_config') 
	create table ga_config (
		job_name nvarchar(200) unique, 
		jobProc varchar(200) not null,
		srcTableName varchar(200) not null, srckeycol varchar(200) not null, 
		trgTableName varchar(200) not null, params nvarchar(max)
	);


if not exists (select 1 from ga_config where job_name = @job_name) 
	insert into ga_config (job_name, jobProc, srcTableName, srckeycol, trgTableName, params)
	values (@job_name, @job_proc, @pTableName, @pKeyCol, @pTrgTableName, @params_txt);

select top 1 @job_id = job_id from ga_status 
where job_name = @job_name and isnull(params,'') = isnull(@params_txt,'') 
and status_desc not like 'failed%'
and status_desc not like 'completed%'
and status_desc not like 'stopped%'
order by start_time desc
	
if @job_id is null
begin
	if @pContJob = 1
	select top 1 @last_keyid = last_keyid from ga_status
	where cont_job = 1 and job_name = @job_name and isnull(params,'') = isnull(@params_txt,'')
	order by start_time desc

	select @job_id = newid()

	insert into ga_status (job_id,start_time,job_name,status_desc,parallel_degree,job_async,params,requested_rows,
	estimated_rows,committed_rows,cont_job,last_keyid) 
	values (@job_id,getdate(),@job_name,'init',@degree,@async,@params_txt,@pNbOfRowsToMove,
	@est_count,@comm_count,@pContJob,@last_keyid);

	begin try
		--test if query is executable -- mostly testing @params_txt and @pTableName
		select @stmt = N'select @ec = count(*) from '+@pTableName+' where 1=0 '+@params_txt
		execute sp_executesql @stmt, @params = N'@ec bigint out', @ec = @est_count output;
		
		--test target table
		if object_id(@pTrgTableName, N'U') is null
		raiserror('Configured target table does not exist', 16, 1);
		--v.2. test by running an empty batch
		
		--test SP
		if object_id(@job_proc, N'P') is null 
		raiserror('Configured stored procedure does not exist', 16, 1);
		
		if @silent = 0
		print 'Init success'

	end try
	begin catch
		update ga_status set status_desc = 'failed init' where job_id = @job_id
		if @silent = 0
		print error_message()
	end catch
end

if @silent = 0
select * from ga_config where job_name = @job_name

if @silent = 0
select * from ga_status where job_id = @job_id


