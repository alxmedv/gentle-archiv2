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

exec dbo.create_ga_job 'ga_Wanted_x2'

exec dbo.stop_ga 'ga_Wanted_x2'


exec [dbo].[cleanup_ga] @status = 'orphaned'

exec [dbo].[cleanup_ga] @status = 'completed'

exec [dbo].[cleanup_ga] @status = 'stopped'

exec [dbo].[cleanup_ga] @status = 'failed'

exec [dbo].[cleanup_ga] @job_id='EFF8DBFD-9251-4860-AED4-B944BE9F41FD'




select * from ga_config 

select top 3 * from ga_status order by start_time desc

select * from ga_log order by ts desc

