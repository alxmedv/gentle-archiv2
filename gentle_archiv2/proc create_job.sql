use [MetriCorr_WebTestOldData]
go

alter procedure create_job
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
	@params_txt = params
from job_status 
where job_name = @pjob_name and status_desc in ('init') order by start_time

if @job_id is null 
	return;

if @degree>0 and @async=0
	return;

if @async = 1
	exec create_job_async @job_id;
else 
	exec populate_archive @job_name=@pjob_name

GO

