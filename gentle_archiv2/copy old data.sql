/*
Params:

1) ProbeId
2) MeasurementTypes (værdi 0 til 2). Eller alternativt kan ønskes alle MeasurementTyper (Dvs alle data)
3) Ældre end en defineret ”ReceivedTimes”. 
4) _maxNbOfLinesToMove:  Antal af de ældste linjer der skal flyttes og slettes.
5) Parallel degree
6) Async

Status dataset:
1) JobId
2) Status: Initialized, Running, Failed, Complete
3) StartTimestamp
4) % complete
*) Params

Call with params: Init, if running with the same parameters, return status failed (reason same job is running)
Call with JobId parameter - return status dataset

*/

--drop synonym [dbo].[VoltLoglinesSrc] 
--create synonym [dbo].[VoltLoglinesSrc] for [MetriCorr_WebTest].[dbo].[VoltLoglines]
--create synonym [dbo].[VoltLoglinesTrg] for [dbo].[VoltLoglines]



if not exists (select 1 from sys.tables where name = 'job_log') 
create table job_log (logid int identity(1,1), ts datetime default getdate(), job nvarchar(200), msg nvarchar(max), parm bigint)

if not exists (select 1 from sys.tables where name = 'job_status') 
	create table job_status (
		job_id uniqueidentifier, 
		start_time datetime default getdate(), 
		job_name nvarchar(200), 
		parallel_degree smallint,
		job_async bit,
		params varchar(max),
		status_desc nvarchar(20), 
		est_count bigint,
		com_count bigint
	)


declare @job_name nvarchar(200) = 'Arc_VoltLoglines';
declare @job_id uniqueidentifier;
declare @degree int = 0;
declare @async bit = 0;
declare @params_txt varchar(max) = '';
declare @est_count bigint = 0, @comm_count bigint = 0;

declare @pProbeId int = 100;
declare @pMeasurementTypes int;
declare @pMaxReceivedTime datetime = dateadd(yy,-2,getdate());
declare @pNbOfLinesToMove bigint;


declare @commitsize int = 10000;
declare @commited int = 0;
declare @maxjobsize int = power(10,7)
declare @maxProbeLogLineId bigint = 0;
declare @lastProbeLogLineId bigint = 0;
declare @newlastProbeLogLineId bigint = 0;
declare @lastProbeLogLineReceivedTime datetime;

declare @output table ([ProbeLogLineId] int );
declare @rowcount int = 0;

select @job_id = newid()

select @params_txt = 
	case when @pProbeId IS NOT NULL then 'and [ProbeId] = '+cast(@pProbeId as nvarchar(20))+' ' else '' end +
	case when @pMeasurementTypes IS NOT NULL then 'and [MeasurementTypes] = '+cast(@pProbeId as nvarchar(20))+' ' else '' end +
	case when @pMaxReceivedTime IS NOT NULL then 'and [ReceivedTime] < '''+convert(nvarchar(20),@pMaxReceivedTime,20)+''' ' else '' end 
	

insert into job_status (job_id,start_time,job_name,status_desc,parallel_degree,job_async,params,est_count,com_count) 
values (@job_id,getdate(),@job_name,'init',@degree,@async,@params_txt,@est_count,@comm_count);

declare @stmt nvarchar(max);

select @stmt = N'select @ec = count(*) from [VoltLoglinesSrc] where 1=1 '+@params_txt

execute sp_executesql @stmt, @params = N'@ec bigint out', @ec = @est_count output;

update job_status 
set est_count = @est_count, status_desc = 'run' where job_id=@job_id

select * from job_status 

BEGIN TRY

	select @lastProbeLogLineId = max ([ProbeLogLineId]) from [dbo].[VoltLoglines_PT]

	select @maxProbeLogLineId = max ([ProbeLogLineId]) from [dbo].[VoltLoglines] 

	set identity_insert [dbo].[VoltLoglines_PT] on

	while @lastProbeLogLineId < @maxProbeLogLineId and @commited < @maxjobsize
	BEGIN

		BEGIN TRANSACTION

		insert into [dbo].[VoltLoglinesTrg]
				([ReceivedTime], [Uac], [Warning], [ProbeLogLineId], [ProbeId], [dataSource], [DataSourceId], [UserId], [TagId], [Edc], [Power], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [Eoff], [UpdateDone], [EoffStructure], [CampaignId], [WebRegisteredTime])
		output inserted.[ProbeLogLineId] into @output
		select top (@commitsize)
		[ReceivedTime], [Uac], [Warning], [ProbeLogLineId], [ProbeId], [dataSource], [DataSourceId], [UserId], [TagId], [Edc], [Power], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [Eoff], [UpdateDone], [EoffStructure], [CampaignId], [WebRegisteredTime]
		from [VoltLoglinesSrc]
		where [ProbeLogLineId] > @lastProbeLogLineId order by [ProbeLogLineId]
		--OPTION(MAXDOP 1)

		set @rowcount = @@ROWCOUNT;

		delete s from [VoltLoglinesSrc] s join @output o on s.[ProbeLogLineId]=o.[ProbeLogLineId];

		if  @@ROWCOUNT = @rowcount 
			COMMIT TRANSACTION
		else 
			ROLLBACK TRANSACTION

		insert into job_log (job,parm, msg) values (@job, @newlastProbeLogLineId, 'Inserted '+cast(@rowcount as nvarchar(10))+' since ProbeLogLineId='+cast(@lastProbeLogLineId as nvarchar(10))+' into [dbo].[VoltLoglines_PT]');

		set @lastProbeLogLineId = @newlastProbeLogLineId;

		set @commited = @commited + @commitsize

	END

	set identity_insert [dbo].[VoltLoglines_PT] off

	IF @lastProbeLogLineId = @maxProbeLogLineId 
		insert into job_log (job,parm,msg) values (@job, @maxProbeLogLineId, 'Completed insert job into [dbo].[VoltLoglines_PT]');
END TRY
BEGIN CATCH
		insert into job_log (job,parm, msg) values (@job, @newlastProbeLogLineId, 'Job Cancelled on failure. '+ERROR_MESSAGE());
END CATCH