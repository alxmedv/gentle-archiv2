USE [MetriCorr_WebTestOldData]
GO

/****** Object:  StoredProcedure [dbo].[copy_VoltLoglines_par]    Script Date: 12-04-2024 22:58:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[Arc_LcsLoglines_par] 
	@parkeys BatchKeyType READONLY
AS

	insert into [dbo].[LcsLoglines]
			([LcsLoglineId], [ProbeId], [ReceivedTime], [Uac], [Edc], [Eoff], [Power], [Warning], [Temperature], [dataSource], [DataSourceId], [UserId], [TagId], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [VonLcs], [VoffLcs], [RLcs], [IonLcs], [IoffLcs], [ILcs], [ULcsDc], [ULcsAc], [ILcsAc], [RLcsAc], [EoffStructure], [UpdateDone], [CampaignId], [WebRegisteredTime])
	select 
		[LcsLoglineId], [ProbeId], [ReceivedTime], [Uac], [Edc], [Eoff], [Power], [Warning], [Temperature], [dataSource], [DataSourceId], [UserId], [TagId], [UtcTimeOffset], [OriginalErrCode], [SensorDetails], [MeasurementTypes], [VonLcs], [VoffLcs], [RLcs], [IonLcs], [IoffLcs], [ILcs], [ULcsDc], [ULcsAc], [ILcsAc], [RLcsAc], [EoffStructure], [UpdateDone], [CampaignId], [WebRegisteredTime]
		from [MetriCorr_WebTest].[dbo].[LcsLoglines] with (nolock)
		where [LcsLoglineId] in (select [rowkey] from @parkeys)
GO


