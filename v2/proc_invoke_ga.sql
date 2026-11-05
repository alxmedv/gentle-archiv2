USE DBA
GO

if not exists (select 1 from sys.types where name='gaBatchKeyType')
	create type gaBatchKeyType as table (rowkey bigint);

if not exists (select 1 from sys.tables where name = 'ga_status') 
	create table ga_status (
		job_id uniqueidentifier not null, job_part tinyint, 
		start_time datetime default getdate(), job_name nvarchar(200) not null, 
		parallel_degree smallint, 
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
		trgTableName varchar(200) not null, params nvarchar(max),
		comm_rows int
	);

if not exists (select 1 from sys.tables where name = 'ga_log') 
	create table ga_log (logid int identity(1,1), job_id uniqueidentifier, 
	ts datetime default getdate(), job_name nvarchar(200), msg nvarchar(max), parm bigint)
go



create or alter procedure [dbo].[invoke_ga] 
	@pTableName sysname,
	@pKeyCol sysname, 
	@job_name sysname = NULL, 
	@job_proc sysname = NULL, 
	@pTrgTableName sysname = NULL,
	@pWhereAnd nvarchar(max) = NULL,
	@pNbOfRowsToMove bigint = NULL,
	@pCommRows int = NULL,
	@pContJob bit = 0,
	@degree tinyint = 0,
	@async bit = 0,
	@silent bit = 0
	
as

set nocount on

declare @job_id uniqueidentifier;
declare @srcTableName sysname;
declare @params_txt nvarchar(max);
declare @comm_rows int = isnull(@pCommRows,1000);
declare @est_count bigint = 0, @comm_count bigint = 0;
declare @last_keyid bigint = NULL;
declare @stmt nvarchar(max);

set @srcTableName = PARSENAME(@pTableName, 1);
set @job_name = isnull(@job_name,'ga_'+@srcTableName);
set @pTrgTableName = isnull(@pTrgTableName,replace(@pTableName,@srcTableName,'ga_'+@srcTableName));
set @job_proc = isnull(@job_proc,'pr'+@job_name);
set @params_txt = @pWhereAnd 

select top 1 
	@job_id = job_id 
from ga_status 
where job_name = @job_name 
	and hashbytes('SHA2_256',isnull(params,'')) = hashbytes('SHA2_256',isnull(@params_txt,''))
	and replace(status_desc,'(x)','') not in ('failed','completed','stopped','failed init')
order by start_time desc
	
if @job_id is null
begin

	begin try

		--if config is not created - very first invoke
		if not exists (select 1 from ga_config where job_name = @job_name) 
			insert into ga_config (job_name, jobProc, srcTableName, srckeycol, trgTableName, params, comm_rows)
			values (@job_name, @job_proc, @pTableName, @pKeyCol, @pTrgTableName, @params_txt, @comm_rows);
		else 
		begin
			if exists (
			select 1 from ga_config where job_name = @job_name
			and (
			hashbytes('SHA2_256',isnull(params,'')) != hashbytes('SHA2_256',isnull(@params_txt,''))
			or jobProc!=@job_proc or srcTableName!=@pTableName or srckeycol!=@pKeyCol
			or trgTableName!=@pTrgTableName)
			)
			raiserror('Configuration mismatch for the job name', 16, 1);
		end


		if @pContJob = 1 -- if continued job, get the last key id
		select top 1 @last_keyid = last_keyid from ga_status
		where cont_job = 1 and job_name = @job_name 
			and hashbytes('SHA2_256',isnull(params,'')) = hashbytes('SHA2_256',isnull(@params_txt,''))
			and replace(status_desc,'(x)','') in ('failed','completed','stopped')
		order by start_time desc

		select @job_id = newid()

		insert into ga_status (job_id,start_time,job_name,status_desc,parallel_degree,
		job_async,params,requested_rows,
		estimated_rows,committed_rows,cont_job,last_keyid) 
		values (@job_id,getdate(),@job_name,'init',@degree,
		@async,@params_txt,@pNbOfRowsToMove,
		@est_count,@comm_count,@pContJob,@last_keyid);

		--test target table
		if object_id(@pTrgTableName, N'U') is null
		raiserror('Configured target table does not exist', 16, 1);
		--v.2. test by running an empty batch
		
		--test SP
		if object_id(@job_proc, N'P') is null 
		raiserror('Configured stored procedure does not exist', 16, 1);

		if object_id('ga_jobindex_' + cast(@job_id as nvarchar(200))) is not null
		raiserror('The job index table exists', 16, 1);

		select @stmt =
			'select '
			+ case when isnull(@pNbOfRowsToMove,0) > 0
				then 'top ('+cast(@pNbOfRowsToMove as nvarchar(20))+') ' else '' end
			+ @pKeyCol + ' as rowkey,'
			+ ' row_number() over (order by '+@pKeyCol+' asc ) as rownum'
			+ ' into "ga_jobindex_' + cast(@job_id as nvarchar(200))+'"'
			+ ' from '+@pTableName+' with (nolock) where 1=1 ' + isnull(@params_txt,'')
			+ case when isnull(@last_keyid,0) > 0 
				then ' and '+@pKeyCol+'>'+cast(@last_keyid as varchar(20)) else '' end
			+ '; set @ec = @@rowcount;'
		if @stmt is null
			raiserror('Enumerate statement is NULL', 16, 1);

		if @silent = 0
		select @stmt as stmt
		
		execute sp_executesql @stmt, @params = N'@ec bigint out', @ec = @est_count output;
		update ga_status set estimated_rows = @est_count where job_id = @job_id;
		
		if @silent = 0
		print 'Init success'

	end try
	begin catch
		update ga_status set status_desc = 'failed init' where job_id = @job_id
		if @silent = 0
		print error_message()
	end catch
end
else
	print 'job exists ' + @job_name

if @silent = 0
select * from ga_config where job_name = @job_name

if @silent = 0
select * from ga_status where job_id = @job_id


