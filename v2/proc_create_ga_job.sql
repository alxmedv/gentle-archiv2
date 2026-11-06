use DBA
go

create or alter procedure create_ga_job
	@pjob_name nvarchar(200) 
as

declare @job_id uniqueidentifier;
declare @degree int = 0;
declare @async bit = 0;
declare @params_txt varchar(max) = '';
declare @est_count bigint = 0, @req_count bigint = 0, @com_count bigint = 0;
declare @jobname nvarchar(128);

select top 1 
	@job_id = job_id, 
	@est_count = estimated_rows,
	@req_count = requested_rows,
	@degree = parallel_degree,
	@async = job_async,
	@params_txt = whereand
from ga_status 
where job_name = @pjob_name and status_desc in ('init') order by start_time

if @job_id is null or (@degree>0 and @async=0)
begin
	print 'The requested job cannot be started'
	print '@job_id='+cast(@job_id as varchar(50))+', @est_count='+cast(@est_count as varchar(10))
	+', @degree='+cast(@degree as varchar(10))+', @async='+cast(@async as varchar(10))
	update ga_status set status_desc = 'stopped', end_time=getdate()
	where job_id = @job_id;
	return;
end

if @job_id is not null and @est_count=0
begin
	print 'The requested job is empty'
	print '@job_id='+cast(@job_id as varchar(50))+', @est_count='+cast(@est_count as varchar(10))
	update ga_status set status_desc = 'completed', end_time=getdate()
	where job_id = @job_id;
	return;
end

if @async = 1
	exec create_ga_job_async @job_id;
else 
	exec populate_ga @job_name=@pjob_name

GO

