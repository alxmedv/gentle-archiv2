USE [MetriCorr_WebTestOldData]
GO

/****** Object:  StoredProcedure [dbo].[copy_VoltLoglines_par]    Script Date: 12-04-2024 16:37:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[Arc_ProbeLoglines_par] 
	@parkeys BatchKeyType READONLY
AS

	insert into [dbo].[ProbeLogLines]
			([ProbeLogLineId], [ProbeId], [ReceivedTime], [Thickness], [Uac], [Iac], [Jac], [Rs], [Idc], [Jdc], [Edc], [Rr], [Rc], [Warning], [SourceId], [Power], [dataSource], [DataSourceId], [UserId], [Eoff], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [UpdateDone], [CampaignId], [Latitude], [Longitude], [TempCoupon], [WebRegisteredTime], [EirFree])
	select 
		[ProbeLogLineId], [ProbeId], [ReceivedTime], [Thickness], [Uac], [Iac], [Jac], [Rs], [Idc], [Jdc], [Edc], [Rr], [Rc], [Warning], [SourceId], [Power], [dataSource], [DataSourceId], [UserId], [Eoff], [Temperature], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [UpdateDone], [CampaignId], [Latitude], [Longitude], [TempCoupon], [WebRegisteredTime], [EirFree]
		from [MetriCorr_WebTest].[dbo].[ProbeLogLines] with (nolock)
		where [ProbeLogLineId] in (select [rowkey] from @parkeys)
GO


