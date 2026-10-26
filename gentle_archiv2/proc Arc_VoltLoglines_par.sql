USE [MetriCorr_WebTestOldData]
GO

/****** Object:  StoredProcedure [dbo].[copy_VoltLoglines_par]    Script Date: 12-04-2024 22:58:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[Arc_VoltLoglines_par] 
	@parkeys BatchKeyType READONLY
AS

	insert into [dbo].[VoltLoglines]
			([ReceivedTime], [Uac], [Warning], [ProbeLogLineId], [ProbeId], [dataSource], [DataSourceId], 
			[UserId], [TagId], [Edc], [Power], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], 
			[MeasurementTypes], [Eoff], [UpdateDone], [EoffStructure], [CampaignId], [WebRegisteredTime])
	select 
		[ReceivedTime], [Uac], [Warning], [ProbeLogLineId], [ProbeId], [dataSource], [DataSourceId], 
		[UserId], [TagId], [Edc], [Power], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], 
		[MeasurementTypes], [Eoff], [UpdateDone], [EoffStructure], [CampaignId], [WebRegisteredTime]
		from [MetriCorr_WebTest].[dbo].[VoltLoglines] with (nolock)
		where [ProbeLogLineId] in (select [rowkey] from @parkeys)
GO


