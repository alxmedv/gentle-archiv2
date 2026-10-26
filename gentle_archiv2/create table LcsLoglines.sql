

/****** Object:  Table [dbo].[LcsLoglines]    Script Date: 09-04-2024 17:44:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LcsLoglines](
	[LcsLoglineId] [int] NOT NULL,
	[ProbeId] [int] NOT NULL,
	[ReceivedTime] [datetime] NOT NULL,
	[Uac] [float] NULL,
	[Edc] [float] NULL,
	[Eoff] [float] NULL,
	[Power] [float] NULL,
	[Warning] [int] NOT NULL,
	[Temperature] [float] NULL,
	[dataSource] [int] NOT NULL,
	[DataSourceId] [int] NULL,
	[UserId] [uniqueidentifier] NULL,
	[TagId] [int] NOT NULL,
	[UtcTimeOffset] [float] NULL,
	[OriginalErrCode] [int] NULL,
	[SensorDetails] [nvarchar](48) NULL,
	[MeasurementTypes] [int] NOT NULL,
	[VonLcs] [float] NULL,
	[VoffLcs] [float] NULL,
	[RLcs] [float] NULL,
	[IonLcs] [float] NULL,
	[IoffLcs] [float] NULL,
	[ILcs] [float] NULL,
	[ULcsDc] [float] NULL,
	[ULcsAc] [float] NULL,
	[ILcsAc] [float] NULL,
	[RLcsAc] [float] NULL,
	[EoffStructure] [float] NULL,
	[UpdateDone] [bit] NULL,
	[CampaignId] [int] NOT NULL,
	[WebRegisteredTime] [datetime] NULL,
 CONSTRAINT [PK_dbo.LcsLoglines] PRIMARY KEY CLUSTERED 
(
	[LcsLoglineId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[LcsLoglines] ADD  DEFAULT ((0)) FOR [CampaignId]
GO

CREATE NONCLUSTERED INDEX [LcsLoglines_ProbeId_ReceivedTime] ON [dbo].[LcsLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
