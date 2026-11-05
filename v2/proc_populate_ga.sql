USE DBA
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create or ALTER procedure [dbo].[populate_ga]
	@job_name nvarchar(200),
	@threadno tinyint = NULL
as

declare @debug bit = 1;
declare @job_id uniqueidentifier;
declare @degree int = 0;
declare @async bit = 0;
declare @params_txt varchar(max) = '';
declare @est_count bigint = 0, 
		@trd_est_count bigint = 0, 
		@req_count bigint = 0, 
		@com_count bigint = 0;
declare @status_desc nvarchar(20);

declare @lastMaxKey bigint = 0
declare @commitsize int = 1000
declare @rowsaffect int = 0

declare @srctable nvarchar(200);
declare @srckeycol nvarchar(200);
declare @jobProc nvarchar(200);
declare @enumsqlstmt nvarchar(max);
declare @contJob bit;

declare @batchkeys AS gaBatchKeyType;

begin try


drop table if exists #jobkeys;
create table #jobkeys (rowkey int primary key clustered);

select top 1 
	@job_id = job_id, 
	@lastMaxKey = case when cont_job = 1 and status_desc = 'init' then isnull(last_keyid,0) else 0 end,
	@est_count = estimated_rows,
	@req_count = requested_rows,
	@degree = parallel_degree, 
	@async = job_async,
	@params_txt = params
from ga_status 
where job_name = @job_name 
	and (status_desc in ('init') or (parallel_degree > 0 and status_desc in ('run')))
order by start_time

if @job_id is null return

select 
@jobProc = jobProc, 		
@srctable = srcTableName, 
@srckeycol = srckeycol,
@commitsize = isnull(comm_rows, @commitsize)
from ga_config where job_name = @job_name; 

if @debug = 1
select @job_id as job_id, 
	@contJob as cont_Job,
	@est_count as estimated_rows,
	@req_count as requested_rows,
	@degree as parallel_degree,
	@async as job_async,
	@params_txt as params,
	@jobProc as jobProc, 		
	@srctable as srcTableName, 
	@srckeycol as srckeycol  

		
update ga_status 
set status_desc = 'run' where job_id=@job_id

--create job queue
select @enumsqlstmt =
	'select rowkey from "ga_jobindex_' + cast(@job_id as nvarchar(200))+'" where 1=1'
	+ case when @degree > 0 and @threadno is not null 
		then ' and rownum%'+cast(@degree as nvarchar(5))+'='+cast(@threadno as nvarchar(5))
		else '' end;

truncate table #jobkeys;
insert into #jobkeys (rowkey) execute (@enumsqlstmt);
select @est_count = count(*) from #jobkeys;

if @debug = 1
	select @enumsqlstmt as enumsqlstmt, @est_count as est_count 


insert into ga_log (job_id,parm,msg) 
values (@job_id, @threadno, 'estimated '+cast(@est_count as nvarchar(20))+' rows');

--update ga_status set estimated_rows = estimated_rows+@est_count where job_id = @job_id

set @com_count = @est_count;

while @com_count > 0
begin --while

	select @status_desc = status_desc from ga_status where job_id=@job_id
	if @status_desc = 'stopped'
		break;

	--populate batch keys
	delete @batchkeys;
	insert into @batchkeys (rowkey) select top (@commitsize) rowkey
	from #jobkeys where rowkey > @lastMaxKey order by rowkey;

	select @com_count = count(*), @lastMaxKey = isnull(max(rowkey),@lastMaxKey) from @batchkeys;
	
	begin

		--populate target table
		begin transaction;
		set @enumsqlstmt = @jobProc + ' @parkeys, @rows_affected OUT'

		exec sp_executesql @enumsqlstmt, 
			N'@parkeys gaBatchKeyType READONLY, @rows_affected bigint OUT', 
			@batchkeys, @rowsaffect out;

		if @debug = 1
			select @rowsaffect rowsaffect, @com_count com_count, @lastMaxKey as lastMaxKey

		if @rowsaffect <> @com_count
			throw  50001, N'insert rowcount mismatch with expected commit count', 1
	
		commit transaction;
	end

	insert into ga_log (job_id,parm,msg) 
	values (@job_id, @threadno, 'committed '+cast(@com_count as nvarchar(20))+' rows, lastid='+cast(@lastMaxKey as nvarchar(20)));

	update ga_status 
	set committed_rows = committed_rows + @com_count 
	where job_id=@job_id

end --while

if @com_count = 0 
	insert into ga_log (job_id,parm,msg) values (@job_id, @threadno, 'completed, lastid='+cast(@lastMaxKey as nvarchar(20)));


if exists (select 1 from ga_status where job_id=@job_id and committed_rows=estimated_rows)
begin
	update ga_status 
	set status_desc = 'completed', last_keyid = cast(@lastMaxKey as nvarchar(20)) 
	where job_id=@job_id

end 

end try
begin catch

	if @@trancount>0
		rollback transaction;
	
	insert into ga_log (job_id,parm,msg) 
	values (@job_id, @threadno, 'job failed : '+ERROR_MESSAGE()+', lastid='+cast(@lastMaxKey as nvarchar(20)));

	update ga_status 
	set status_desc = 'failed' where job_id=@job_id

end catch
