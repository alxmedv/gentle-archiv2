exec dbo.invoke_ga
	@job_name = 'ga_Wanted_x2',
	@job_proc = 'prga_Wanted',
	@pTableName = 'bricklink.dbo.Wanted',
	@pKeyCol = 'wantedID',
	@pNbOfRowsToMove = 10000000,
	@pContJob = 1,
	@degree = 8,
	@async = 1

--exec [dbo].[populate_ga] 'ga_Wanted', 1

exec [dbo].[cleanup_ga] @status = 'failed'
exec dbo.create_ga_job 'ga_Wanted_x2'

exec dbo.stop_ga 'ga_Wanted_x2'


exec [dbo].[cleanup_ga] @status = 'orphaned'
exec [dbo].[cleanup_ga] @status = 'stopped'
exec [dbo].[cleanup_ga] @status = 'failed'




select * from ga_config 

select top 3 gs.*, gl.minut from ga_status gs 
left join (select job_id,datediff(minute,min(ts),max(ts)) minut from ga_log group by job_id) gl 
on gs.job_id = gl.job_id
order by start_time desc

select top 100 * from ga_log order by ts desc

