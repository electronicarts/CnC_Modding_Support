#ifndef PATH_HEADER_RA3Music
#define PATH_HEADER_RA3Music

/*	This header file #defines events and tracks from one PathFinder project.

	For full docs see http://tools.eac.ea.com/audio/asphelp/
	For downloads see http://tools.eac.ea.com/enviro/audio/path/release/

 You will need to #include "path.h" and this .h file.
 The .mus files from the generate folder must be available; you will have to pass in full pathnames
 later.
 The .nam and .dbg files are not required for library operation, although the .nam file provides
 name information for library feedback messages (see PATH_addnamfile).

 First ensure that your SND, REAL, and/or EACore libraries are initialized correctly.

 You also need to provide a memory allocator, either EA::Allocator::IAllocator (for REAL):

   PATH_setallocator( IAllocator*, TagValuePair & )
   // TagValuePair you pass in (see IAllocator docs) will be used for all allocations.
   // It can be the default (NULLALLOCTVP).

or EA::Allocator::ICoreAllocator (for EACore):

   PATH_setcoreallocator( ICoreAllocator*, int flags )

Next "vector" PATH.lib to your preferred implementation routines. Your choices are:

   PATH_vectortoreal5()
   PATH_vectortoreal5async()
   PATH_vectortoreal6()
   PATH_vectortoreal6async()
   PATH_vectortoeacore()

As the names imply, the differences are which version of REAL to use, and whether to use synchronous or asynchronous file-loading. (Asynchronous is recommended.) If you do not use bank (RAM-resident) tracks, PATH performs no file-loading operations. There is no significant difference in overhead between the synch and asynch implementations.

Next "vector" PATH.lib to SND.lib:

   PATH_vectortosnd()


For debugging, you may want to filter what messages will be printf'd from Pathfinder. At a minimum, you should let any error messages through:

   PATH_setdebuggingchannels(kAddChannel, kPathErrorDebugChannel);

You may also want to re-vector the handler functions for PATH error, abort, and log messages. By default these are set to printf, REAL_abortmessage, and (null). See IPathToReal.

Next, load the Pathfinder-generated logic files (.mpf = "mapfile") into RAM and hand a pointer to Pathfinder.

   PATH_addmapfile( pmapfile );

If you are using multiple voices with a single project (eg. two stream instances to handle crossfading), call PATH_addmapfile() twice with the same file data (same pointer is OK).

*/

#ifndef PATH_ID_RA3Music
#define PATH_ID_RA3Music        0
#endif
/*
 Most calls in the API specify "projects", "tracks", or a "trackhandle".

	   trackhandle: PATH_TRACK_xxxx (as defined below)
	   tracks:      PATH_ALL_TRACKS, or one or more trackhandles ORÕd together
	   projects:    PATH_ALL_PROJECTS, or PATH_PROJECT( PATH_ID_xxxx ) (see below)

	The project PATH_ID_ constant below is a unique project ID. You can add
	   two instances of a single project mapfile for certain special purposes,
	   for example to run two streams with the same music data, eg. for crossfades.

*/

/*	Next, create your stream and bank tracks:

	  // args = trackhandle, .mus file path, stream latency
	  int result = PATH_createstreamtrack( PATH_TRACK_myStreamTrack, streamtrackpath, 500);
	  if (result >= PATH_OK)
	  {
	      // args = trackhandle, max # streamer requests, buffer size in seconds
	      result = PATH_createstreamimp( PATH_TRACK_myStreamTrack, 3, 1.5 );
	  }

You can create the "streamimp" (implementation) separately, or attach an existing one that you stole from an earlier, presumably now deceased, stream track. See AttachStreamInstance or PATH_attachstreamimp.

Creating a bank track works much the same way:

	  // args = trackhandle, .mus file path, max # sub-banks active at a time
	  int result = PATH_createbanktrack( PATH_TRACK_myBankTrack, banktrackpath, 2);
	  if (result >= PATH_OK)
	  {
	      // args = trackhandle
	      result = PATH_createbankimp( PATH_TRACK_myBankTrack );
	  }


If you're using bank tracks, you will need to perform at least one bank-load:

	  // args = trackhandle, sub-bank index
	  PATH_loadbank( PATH_TRACK_myBankTrack, 0 );



When it's time to close down you can just do:

	  PATH_shutdown( );


Or, if you need to close down a single track or a single project, use PATH_destroy with track handles or project flags:

	  // shuts down the "ambience" project, leaves others running
	  PATH_destroy( PATH_PROJECT( PATH_ID_ambience ) | PATH_ALLVOICES | PATH_ALL_TRACKS );


	  // disposes just myBankTrack
	  PATH_destroy( PATH_TRACK_myBankTrack );


*/


// Track handles. Can be OR'd together.
// Most PATH.lib functions require at least one track handle.

// (Often PATH_ALL can be used where track handles are requested.)

// You may not need the TRACKID constants, it's there for reference only.


// stream track handles
#ifndef PATH_TRACKID_Track
#define PATH_TRACKID_Track      0
#endif
#ifndef PATH_TRACK_Track
#define PATH_TRACK_Track    0x11000001
#endif
#ifndef PATH_TRACK_2Track
#define PATH_TRACK_2Track    0x21000001
#endif
#ifndef PATH_TRACK_BYTESPERSEC_Track
#define PATH_TRACK_BYTESPERSEC_Track    192004
#endif
#ifndef PATH_TRACKID_Track_Mem
#define PATH_TRACKID_Track_Mem      1
#endif
#ifndef PATH_TRACK_Track_Mem
#define PATH_TRACK_Track_Mem    0x11000002
#endif
#ifndef PATH_TRACK_2Track_Mem
#define PATH_TRACK_2Track_Mem    0x21000002
#endif
#ifndef PATH_TRACKCACHEABLE_Track_Mem
#define PATH_TRACKCACHEABLE_Track_Mem    213248
#endif
#ifndef PATH_TRACK_BYTESPERSEC_Track_Mem
#define PATH_TRACK_BYTESPERSEC_Track_Mem    177493
#endif


/*	To affect playback, you have two levers: control "level" and events.
	
	  Control "level" (usually "intensity") is a value from 0-127. The track composer
	  has laid out which nodes will play at given intensity levels.
		
	PATH_control(tracks, level);	    // change "level" for specified track(s)
	PATH_control(PATH_ALL, level);	  // change for all tracks
		
	"Events" cause more complex music changes. For example, the composer may have
	  defined a musical "overlay" to play overtop the main stream for a few seconds,
	  temporarily ducking its volume. Or an "event" may switch to a new song section.
		
		PATH_event(tracks, eventID);	         // specified track(s)
		PATH_event(PATH_ALL_TRACKS, eventID);	// all tracks in this event's project
		
	Sound artists can script events to perform several consecutive actions.
	  Event actions typically involve branching to new music, changing volume
	  or FX bus levels, waiting for a certain condition to become true, pausing
	  or unpausing a track, and so on.

	Because events may wait for conditions, multiple event scripts can remain active
	  concurrently. PATH_clearallevents() and PATH_numevents() can help manage event
	  conflicts. See the detailed docs.

	Legal eventIDs for this project are #defined below.
*/

#ifndef PATH_EVENT_SetPlayerAllied
#define PATH_EVENT_SetPlayerAllied       0x10D9047
#endif
#ifndef PATH_EVENT_SetPlayerSoviet
#define PATH_EVENT_SetPlayerSoviet       0x1A0EF03
#endif
#ifndef PATH_EVENT_SetPlayerJapan
#define PATH_EVENT_SetPlayerJapan       0x18303A7
#endif
#ifndef PATH_EVENT_SetAdvantagePlayer
#define PATH_EVENT_SetAdvantagePlayer       0x1F7413A
#endif
#ifndef PATH_EVENT_SetAdvantageEnemy
#define PATH_EVENT_SetAdvantageEnemy       0x1FF1A03
#endif
#ifndef PATH_EVENT_ResetAdvantage
#define PATH_EVENT_ResetAdvantage       0x181E44E
#endif
#ifndef PATH_EVENT_Base
#define PATH_EVENT_Base       0x18651BF
#endif
#ifndef PATH_EVENT_Threat1
#define PATH_EVENT_Threat1       0x123371E
#endif
#ifndef PATH_EVENT_Threat1_1
#define PATH_EVENT_Threat1_1       0x1080F8C
#endif
#ifndef PATH_EVENT_Threat2
#define PATH_EVENT_Threat2       0x12A6701
#endif
#ifndef PATH_EVENT_Combat
#define PATH_EVENT_Combat       0x1FDE638
#endif
#ifndef PATH_EVENT_UpYoursSoviet
#define PATH_EVENT_UpYoursSoviet       0x18D9AA6
#endif
#ifndef PATH_EVENT_UpYoursAllied
#define PATH_EVENT_UpYoursAllied       0x120E524
#endif
#ifndef PATH_EVENT_UpYoursEmpire
#define PATH_EVENT_UpYoursEmpire       0x19AD2E1
#endif
#ifndef PATH_EVENT_MenuTrack
#define PATH_EVENT_MenuTrack       0x1B9D554
#endif
#ifndef PATH_EVENT_BriefingTrack
#define PATH_EVENT_BriefingTrack       0x12671D4
#endif
#ifndef PATH_EVENT_CreditsTrack
#define PATH_EVENT_CreditsTrack       0x11247E0
#endif
#ifndef PATH_EVENT_StatsLoseTrack
#define PATH_EVENT_StatsLoseTrack       0x13A896F
#endif
#ifndef PATH_EVENT_StatsWinTrack
#define PATH_EVENT_StatsWinTrack       0x19D8959
#endif
#ifndef PATH_EVENT_Explore1
#define PATH_EVENT_Explore1       0x15CDE83
#endif
#ifndef PATH_EVENT_BigReveal
#define PATH_EVENT_BigReveal       0x1E625CA
#endif
#ifndef PATH_EVENT_Explore2
#define PATH_EVENT_Explore2       0x1558F90
#endif
#ifndef PATH_EVENT_Default
#define PATH_EVENT_Default       0x1E3396F
#endif
#ifndef PATH_EVENT_S_S01LeninIntro
#define PATH_EVENT_S_S01LeninIntro       0x100E0DF
#endif
#ifndef PATH_EVENT_S_S01JapanFleet
#define PATH_EVENT_S_S01JapanFleet       0x1777741
#endif
#ifndef PATH_EVENT_S_S01Hermitage
#define PATH_EVENT_S_S01Hermitage       0x147668E
#endif
#ifndef PATH_EVENT_S_S01FakeReinforcements
#define PATH_EVENT_S_S01FakeReinforcements       0x1D73285
#endif
#ifndef PATH_EVENT_S_S02KrasnaIntro
#define PATH_EVENT_S_S02KrasnaIntro       0x1EF8592
#endif
#ifndef PATH_EVENT_SR_S02KrasnaIntro
#define PATH_EVENT_SR_S02KrasnaIntro       0x15E0898
#endif
#ifndef PATH_EVENT_S_S02KrasnaJapBase
#define PATH_EVENT_S_S02KrasnaJapBase       0x19A8801
#endif
#ifndef PATH_EVENT_SR_S02KrasnaJapBase
#define PATH_EVENT_SR_S02KrasnaJapBase       0x1C7699A
#endif
#ifndef PATH_EVENT_S_S02KrasnaSickle1
#define PATH_EVENT_S_S02KrasnaSickle1       0x1B36E60
#endif
#ifndef PATH_EVENT_S_S02KrasnaSickle2
#define PATH_EVENT_S_S02KrasnaSickle2       0x1BA3C41
#endif
#ifndef PATH_EVENT_S_S02KrasnaSickle3
#define PATH_EVENT_S_S02KrasnaSickle3       0x1BD0C5E
#endif
#ifndef PATH_EVENT_S_S02KrasnaThreatMoment
#define PATH_EVENT_S_S02KrasnaThreatMoment       0x1D24932
#endif
#ifndef PATH_EVENT_S_S04GenevaIntro
#define PATH_EVENT_S_S04GenevaIntro       0x1E60D21
#endif
#ifndef PATH_EVENT_SR_S04GenevaIntro
#define PATH_EVENT_SR_S04GenevaIntro       0x1578107
#endif
#ifndef PATH_EVENT_S_S04AlliesChrono
#define PATH_EVENT_S_S04AlliesChrono       0x1FB6672
#endif
#ifndef PATH_EVENT_SR_S04AlliesChrono
#define PATH_EVENT_SR_S04AlliesChrono       0x10162E6
#endif
#ifndef PATH_EVENT_S_S04KrukovTellsYouOff
#define PATH_EVENT_S_S04KrukovTellsYouOff       0x1ACC615
#endif
#ifndef PATH_EVENT_SR_S04KrukovTellsYouOff
#define PATH_EVENT_SR_S04KrukovTellsYouOff       0x15090DF
#endif
#ifndef PATH_EVENT_S_S04Threat1_1
#define PATH_EVENT_S_S04Threat1_1       0x1BD8F15
#endif
#ifndef PATH_EVENT_S_S05MykonosIntro
#define PATH_EVENT_S_S05MykonosIntro       0x104EA75
#endif
#ifndef PATH_EVENT_SR_S05MykonosIntro
#define PATH_EVENT_SR_S05MykonosIntro       0x1FEEF13
#endif
#ifndef PATH_EVENT_S_S05MykonosDownload
#define PATH_EVENT_S_S05MykonosDownload       0x192B006
#endif
#ifndef PATH_EVENT_SR_S05MykonosDownload
#define PATH_EVENT_SR_S05MykonosDownload       0x13F16A7
#endif
#ifndef PATH_EVENT_S_S05MykonosRecaptureDownload
#define PATH_EVENT_S_S05MykonosRecaptureDownload       0x1B32AC0
#endif
#ifndef PATH_EVENT_S_S06IcelandIntro
#define PATH_EVENT_S_S06IcelandIntro       0x151067C
#endif
#ifndef PATH_EVENT_SR_S06IcelandIntro
#define PATH_EVENT_SR_S06IcelandIntro       0x1AB0270
#endif
#ifndef PATH_EVENT_S_S06Krukov
#define PATH_EVENT_S_S06Krukov       0x188F806
#endif
#ifndef PATH_EVENT_SR_S06Krukov
#define PATH_EVENT_SR_S06Krukov       0x1B1D713
#endif
#ifndef PATH_EVENT_S_S06IcelandThreat1_1
#define PATH_EVENT_S_S06IcelandThreat1_1       0x1A8BDB8
#endif
#ifndef PATH_EVENT_S_S06KrukovTraitor
#define PATH_EVENT_S_S06KrukovTraitor       0x13CE5E1
#endif
#ifndef PATH_EVENT_SR_S06KrukovTraitor
#define PATH_EVENT_SR_S06KrukovTraitor       0x16104C4
#endif
#ifndef PATH_EVENT_S_S06KrukovDefeated
#define PATH_EVENT_S_S06KrukovDefeated       0x1FC5138
#endif
#ifndef PATH_EVENT_SR_S06KrukovDefeated
#define PATH_EVENT_SR_S06KrukovDefeated       0x154C5EF
#endif
#ifndef PATH_EVENT_S_S07FujiIntro
#define PATH_EVENT_S_S07FujiIntro       0x1689A36
#endif
#ifndef PATH_EVENT_SR_S07FujiIntro
#define PATH_EVENT_SR_S07FujiIntro       0x1EB8F1D
#endif
#ifndef PATH_EVENT_S_S07FujiRobot
#define PATH_EVENT_S_S07FujiRobot       0x14621B4
#endif
#ifndef PATH_EVENT_SR_S07FujiRobot
#define PATH_EVENT_SR_S07FujiRobot       0x1C534A3
#endif
#ifndef PATH_EVENT_S_S07FujiThreat1_1
#define PATH_EVENT_S_S07FujiThreat1_1       0x102812C
#endif
#ifndef PATH_EVENT_S_S07FujiThreat1
#define PATH_EVENT_S_S07FujiThreat1       0x1A208B2
#endif
#ifndef PATH_EVENT_S_S08EasterIslandBuildUp
#define PATH_EVENT_S_S08EasterIslandBuildUp       0x19FCC99
#endif
#ifndef PATH_EVENT_S_S08EasterIslandEmissary
#define PATH_EVENT_S_S08EasterIslandEmissary       0x175F665
#endif
#ifndef PATH_EVENT_Reward1Soviet
#define PATH_EVENT_Reward1Soviet       0x147A3F3
#endif
#ifndef PATH_EVENT_S_A01BrightonIntro
#define PATH_EVENT_S_A01BrightonIntro       0x10BEE04
#endif
#ifndef PATH_EVENT_SR_A01BrightonIntro
#define PATH_EVENT_SR_A01BrightonIntro       0x1560C9D
#endif
#ifndef PATH_EVENT_S_A01BrightonThreat
#define PATH_EVENT_S_A01BrightonThreat       0x14E0532
#endif
#ifndef PATH_EVENT_S_A01BrightonCombat
#define PATH_EVENT_S_A01BrightonCombat       0x188BB02
#endif
#ifndef PATH_EVENT_S_A01BrightonExplore
#define PATH_EVENT_S_A01BrightonExplore       0x12E1BB0
#endif
#ifndef PATH_EVENT_S_A01BrightonFirstWave2min
#define PATH_EVENT_S_A01BrightonFirstWave2min       0x15209BE
#endif
#ifndef PATH_EVENT_S_A01BrightonFirstWave3min
#define PATH_EVENT_S_A01BrightonFirstWave3min       0x1EE6D89
#endif
#ifndef PATH_EVENT_S_A01BrightonWave2min
#define PATH_EVENT_S_A01BrightonWave2min       0x191FEFE
#endif
#ifndef PATH_EVENT_S_A01BrightonWave3min
#define PATH_EVENT_S_A01BrightonWave3min       0x12D9959
#endif
#ifndef PATH_EVENT_S_A02CannesBegin
#define PATH_EVENT_S_A02CannesBegin       0x1F7EA5E
#endif
#ifndef PATH_EVENT_S_A02CannesSpotted
#define PATH_EVENT_S_A02CannesSpotted       0x1B5629A
#endif
#ifndef PATH_EVENT_SR_A02CannesSpotted
#define PATH_EVENT_SR_A02CannesSpotted       0x1E882A5
#endif
#ifndef PATH_EVENT_S_A02CannesExplosion
#define PATH_EVENT_S_A02CannesExplosion       0x1B273F1
#endif
#ifndef PATH_EVENT_SR_A02CannesExplosion
#define PATH_EVENT_SR_A02CannesExplosion       0x11FCD3E
#endif
#ifndef PATH_EVENT_S_A03HeidelbergIntro
#define PATH_EVENT_S_A03HeidelbergIntro       0x172EB50
#endif
#ifndef PATH_EVENT_S_A03HeidelbergIronCurtainUp
#define PATH_EVENT_S_A03HeidelbergIronCurtainUp       0x1D3488B
#endif
#ifndef PATH_EVENT_S_A03HeidelbergIronCutainDown
#define PATH_EVENT_S_A03HeidelbergIronCutainDown       0x1336722
#endif
#ifndef PATH_EVENT_S_A04GibraltarIntro
#define PATH_EVENT_S_A04GibraltarIntro       0x1F6DF43
#endif
#ifndef PATH_EVENT_SR_A04GibraltarIntro
#define PATH_EVENT_SR_A04GibraltarIntro       0x15E4B8A
#endif
#ifndef PATH_EVENT_S_A04GibraltarExplore
#define PATH_EVENT_S_A04GibraltarExplore       0x157C56D
#endif
#ifndef PATH_EVENT_S_A04Threat1
#define PATH_EVENT_S_A04Threat1       0x1F77FD2
#endif
#ifndef PATH_EVENT_S_A04Threat1_1
#define PATH_EVENT_S_A04Threat1_1       0x19EFC92
#endif
#ifndef PATH_EVENT_S_A06RushmoreBegin
#define PATH_EVENT_S_A06RushmoreBegin       0x103FA18
#endif
#ifndef PATH_EVENT_S_A06RushmoreTowerDown
#define PATH_EVENT_S_A06RushmoreTowerDown       0x108E4F6
#endif
#ifndef PATH_EVENT_SR_A06RushmoreTowerDown
#define PATH_EVENT_SR_A06RushmoreTowerDown       0x1F4B38E
#endif
#ifndef PATH_EVENT_S_A06SetSkirmishOn
#define PATH_EVENT_S_A06SetSkirmishOn       0x162823C
#endif
#ifndef PATH_EVENT_S_A06SetSkirmishOff
#define PATH_EVENT_S_A06SetSkirmishOff       0x13EA296
#endif
#ifndef PATH_EVENT_S_A06RushmoreChase
#define PATH_EVENT_S_A06RushmoreChase       0x17B5480
#endif
#ifndef PATH_EVENT_S_A09LeningradIntro
#define PATH_EVENT_S_A09LeningradIntro       0x1190C3F
#endif
#ifndef PATH_EVENT_S_A09MicroMCVs
#define PATH_EVENT_S_A09MicroMCVs       0x1814001
#endif
#ifndef PATH_EVENT_S_A09PremierEscapes
#define PATH_EVENT_S_A09PremierEscapes       0x1F39D3D
#endif
#ifndef PATH_EVENT_SR_A09PremierEscapes
#define PATH_EVENT_SR_A09PremierEscapes       0x15B09D6
#endif
#ifndef PATH_EVENT_S_A09TMinus25Minutes
#define PATH_EVENT_S_A09TMinus25Minutes       0x1210B1D
#endif
#ifndef PATH_EVENT_S_A09TMinus1Minute
#define PATH_EVENT_S_A09TMinus1Minute       0x10C4AFE
#endif
#ifndef PATH_EVENT_S_A09Threat1_1
#define PATH_EVENT_S_A09Threat1_1       0x160772F
#endif
#ifndef PATH_EVENT_S_J02Threat1_1
#define PATH_EVENT_S_J02Threat1_1       0x112285F
#endif
#ifndef PATH_EVENT_S_J02Threat1
#define PATH_EVENT_S_J02Threat1       0x1788D6C
#endif
#ifndef PATH_EVENT_S_J02StalingradBegin
#define PATH_EVENT_S_J02StalingradBegin       0x1CDD3C4
#endif
#ifndef PATH_EVENT_SR_J02StalingradBegin
#define PATH_EVENT_SR_J02StalingradBegin       0x1606B69
#endif
#ifndef PATH_EVENT_S_J02StalingradStatueDown
#define PATH_EVENT_S_J02StalingradStatueDown       0x101CE46
#endif
#ifndef PATH_EVENT_SR_J02StalingradStatueDown
#define PATH_EVENT_SR_J02StalingradStatueDown       0x1763F49
#endif
#ifndef PATH_EVENT_S_J02StalingradEmpireVictory
#define PATH_EVENT_S_J02StalingradEmpireVictory       0x184D4A6
#endif
#ifndef PATH_EVENT_S_J03OdessaIntro
#define PATH_EVENT_S_J03OdessaIntro       0x12223A0
#endif
#ifndef PATH_EVENT_SR_J03OdessaIntro
#define PATH_EVENT_SR_J03OdessaIntro       0x193A87A
#endif
#ifndef PATH_EVENT_S_J03OdessaShogun
#define PATH_EVENT_S_J03OdessaShogun       0x183AAB0
#endif
#ifndef PATH_EVENT_SR_J03OdessaShogun
#define PATH_EVENT_SR_J03OdessaShogun       0x179AF68
#endif
#ifndef PATH_EVENT_S_J03OdessaShogunRampage
#define PATH_EVENT_S_J03OdessaShogunRampage       0x1821E63
#endif
#ifndef PATH_EVENT_S_J01SovVillageIntro
#define PATH_EVENT_S_J01SovVillageIntro       0x17DD135
#endif
#ifndef PATH_EVENT_SR_J01SovVillageIntro
#define PATH_EVENT_SR_J01SovVillageIntro       0x1D067F8
#endif
#ifndef PATH_EVENT_S_J01SovVillageStatueDown
#define PATH_EVENT_S_J01SovVillageStatueDown       0x139F42F
#endif
#ifndef PATH_EVENT_SR_J01SovVillageStatueDown
#define PATH_EVENT_SR_J01SovVillageStatueDown       0x14E04BE
#endif
#ifndef PATH_EVENT_S_J01Threat1
#define PATH_EVENT_S_J01Threat1       0x1F78AD5
#endif
#ifndef PATH_EVENT_S_J01Threat1_1
#define PATH_EVENT_S_J01Threat1_1       0x1259337
#endif
#ifndef PATH_EVENT_S_J07YokohamaIntro
#define PATH_EVENT_S_J07YokohamaIntro       0x1421D68
#endif
#ifndef PATH_EVENT_SR_JO7YokohamaIntro
#define PATH_EVENT_SR_JO7YokohamaIntro       0x1CBE512
#endif
#ifndef PATH_EVENT_S_J07YurikoCaptureMiniBase
#define PATH_EVENT_S_J07YurikoCaptureMiniBase       0x1F4A7AA
#endif
#ifndef PATH_EVENT_S_J07YurikoCaptureMiniBases
#define PATH_EVENT_S_J07YurikoCaptureMiniBases       0x1A7E4F8
#endif
#ifndef PATH_EVENT_S_J07BuildingsLost3
#define PATH_EVENT_S_J07BuildingsLost3       0x1D09A6A
#endif
#ifndef PATH_EVENT_S_J07BuildingsLost6
#define PATH_EVENT_S_J07BuildingsLost6       0x1BA6F41
#endif
#ifndef PATH_EVENT_S_J07Krukov
#define PATH_EVENT_S_J07Krukov       0x19C07FE
#endif
#ifndef PATH_EVENT_SR_J07Krukov
#define PATH_EVENT_SR_J07Krukov       0x1A528E3
#endif
#ifndef PATH_EVENT_S_J07ReinforcementsArrive
#define PATH_EVENT_S_J07ReinforcementsArrive       0x1826584
#endif
#ifndef PATH_EVENT_SR_J07ReinforcementsArrive
#define PATH_EVENT_SR_J07ReinforcementsArrive       0x1F594CF
#endif
#ifndef PATH_EVENT_S_J07SovietNavyArrive
#define PATH_EVENT_S_J07SovietNavyArrive       0x1FF5932
#endif
#ifndef PATH_EVENT_SR_J07SovietNavyArrive
#define PATH_EVENT_SR_J07SovietNavyArrive       0x1C969DF
#endif
#ifndef PATH_EVENT_S_A08HavanaIntro
#define PATH_EVENT_S_A08HavanaIntro       0x140D0B4
#endif
#ifndef PATH_EVENT_S_A08RealAPOCTanks
#define PATH_EVENT_S_A08RealAPOCTanks       0x1BB4D90
#endif
#ifndef PATH_EVENT_S_A08FirstCombat
#define PATH_EVENT_S_A08FirstCombat       0x14C990F
#endif
#ifndef PATH_EVENT_S_A08Kirovs
#define PATH_EVENT_S_A08Kirovs       0x1058D45
#endif
#ifndef PATH_EVENT_SR_A08Kirovs
#define PATH_EVENT_SR_A08Kirovs       0x13CAE1C
#endif
#ifndef PATH_EVENT_S_A08KirovEscaping
#define PATH_EVENT_S_A08KirovEscaping       0x1E2DD1E
#endif
#ifndef PATH_EVENT_SR_A08KirovEscaping
#define PATH_EVENT_SR_A08KirovEscaping       0x1BF3D43
#endif
#ifndef PATH_EVENT_S_A08KirovIntercepted
#define PATH_EVENT_S_A08KirovIntercepted       0x1F7EDD7
#endif
#ifndef PATH_EVENT_SR_A08KirovIntercepted
#define PATH_EVENT_SR_A08KirovIntercepted       0x1C1DEA4
#endif
#ifndef PATH_EVENT_S_S09NYCIntro
#define PATH_EVENT_S_S09NYCIntro       0x1968E74
#endif
#ifndef PATH_EVENT_S_S09NYCExplore
#define PATH_EVENT_S_S09NYCExplore       0x14C9096
#endif
#ifndef PATH_EVENT_S_S09RA2Moment
#define PATH_EVENT_S_S09RA2Moment       0x1CF2C6E
#endif
#ifndef PATH_EVENT_S_J04PearlHarborIntro
#define PATH_EVENT_S_J04PearlHarborIntro       0x1B92002
#endif
#ifndef PATH_EVENT_SR_J04PearlHarborIntro
#define PATH_EVENT_SR_J04PearlHarborIntro       0x18F2D61
#endif
#ifndef PATH_EVENT_S_J04Threat1
#define PATH_EVENT_S_J04Threat1       0x1178431
#endif
#ifndef PATH_EVENT_S_J04Threat1_1
#define PATH_EVENT_S_J04Threat1_1       0x10C5819
#endif
#ifndef PATH_EVENT_S_J04FleetArrive
#define PATH_EVENT_S_J04FleetArrive       0x186CD27
#endif
#ifndef PATH_EVENT_SR_J04FleetArrive
#define PATH_EVENT_SR_J04FleetArrive       0x1374121
#endif
#ifndef PATH_EVENT_S_A07TokyoIntro
#define PATH_EVENT_S_A07TokyoIntro       0x1DB3405
#endif
#ifndef PATH_EVENT_SR_A07TokyoIntro
#define PATH_EVENT_SR_A07TokyoIntro       0x1D9DC66
#endif
#ifndef PATH_EVENT_S_A07Nanocores
#define PATH_EVENT_S_A07Nanocores       0x1B646D0
#endif
#ifndef PATH_EVENT_SR_A07Nanocores
#define PATH_EVENT_SR_A07Nanocores       0x13551C9
#endif
#ifndef PATH_EVENT_S_A07Decimator
#define PATH_EVENT_S_A07Decimator       0x1D62C25
#endif
#ifndef PATH_EVENT_SR_A07Decimator
#define PATH_EVENT_SR_A07Decimator       0x1553914
#endif
#ifndef PATH_EVENT_S_A07Threat1
#define PATH_EVENT_S_A07Threat1       0x178786F
#endif
#ifndef PATH_EVENT_S_A07Threat1_1
#define PATH_EVENT_S_A07Threat1_1       0x1A946BC
#endif
#ifndef PATH_EVENT_S_J06SantaMonicaIntro
#define PATH_EVENT_S_J06SantaMonicaIntro       0x10D2037
#endif
#ifndef PATH_EVENT_SR_J06SantaMonicaIntro
#define PATH_EVENT_SR_J06SantaMonicaIntro       0x13B2D2E
#endif
#ifndef PATH_EVENT_S_A05NorthSeaIntro
#define PATH_EVENT_S_A05NorthSeaIntro       0x171C850
#endif
#ifndef PATH_EVENT_SR_A05NorthSeaIntro
#define PATH_EVENT_SR_A05NorthSeaIntro       0x12C29B5
#endif
#ifndef PATH_EVENT_S_A05NorthSeaBaseBuild
#define PATH_EVENT_S_A05NorthSeaBaseBuild       0x102F7C0
#endif
#ifndef PATH_EVENT_S_A05NorthSeaExplore
#define PATH_EVENT_S_A05NorthSeaExplore       0x16513DF
#endif
#ifndef PATH_EVENT_S_A05Threat1
#define PATH_EVENT_S_A05Threat1       0x15D7F9C
#endif
#ifndef PATH_EVENT_S_A05Threat1_1
#define PATH_EVENT_S_A05Threat1_1       0x15C96BB
#endif
#ifndef PATH_EVENT_S_A05Incoming
#define PATH_EVENT_S_A05Incoming       0x1F307AF
#endif
#ifndef PATH_EVENT_S_S03Base
#define PATH_EVENT_S_S03Base       0x1D43075
#endif
#ifndef PATH_EVENT_S_S03Threat1
#define PATH_EVENT_S_S03Threat1       0x16927E7
#endif
#ifndef PATH_EVENT_S_S03Threat1_1
#define PATH_EVENT_S_S03Threat1_1       0x161947A
#endif
#ifndef PATH_EVENT_S_J05DeepOceanIntro
#define PATH_EVENT_S_J05DeepOceanIntro       0x180D32E
#endif
#ifndef PATH_EVENT_S_J05Threat1_1
#define PATH_EVENT_S_J05Threat1_1       0x1CE3314
#endif
#ifndef PATH_EVENT_S_J05Threat1
#define PATH_EVENT_S_J05Threat1       0x1BD845F
#endif
#ifndef PATH_EVENT_S_J09AmsterdamIntro
#define PATH_EVENT_S_J09AmsterdamIntro       0x1D34AEC
#endif
#ifndef PATH_EVENT_S_J09SovietNukeAttack
#define PATH_EVENT_S_J09SovietNukeAttack       0x102503F
#endif
#ifndef PATH_EVENT_SR_J09SovietNukeAttack
#define PATH_EVENT_SR_J09SovietNukeAttack       0x134634C
#endif
#ifndef PATH_EVENT_S_J09Threat1_1
#define PATH_EVENT_S_J09Threat1_1       0x1F2D394
#endif
#ifndef PATH_EVENT_S_J08KremlinIntro
#define PATH_EVENT_S_J08KremlinIntro       0x1A61BAF
#endif
#ifndef PATH_EVENT_S_J08ShogunExecutioner
#define PATH_EVENT_S_J08ShogunExecutioner       0x1FBFC1B
#endif
#ifndef PATH_EVENT_SR_J08ShogunExecutioner
#define PATH_EVENT_SR_J08ShogunExecutioner       0x107ABD9
#endif
#ifndef PATH_EVENT_S_J08TimeMachineDestroyed
#define PATH_EVENT_S_J08TimeMachineDestroyed       0x190579D
#endif
#ifndef PATH_EVENT_SR_J08TimeMachineDestroyed
#define PATH_EVENT_SR_J08TimeMachineDestroyed       0x1E7A68E
#endif
#ifndef PATH_EVENT_S_J08BeginExecutionerCombat
#define PATH_EVENT_S_J08BeginExecutionerCombat       0x1EDF9A3
#endif
#ifndef PATH_EVENT_S_J08JapanGainGround
#define PATH_EVENT_S_J08JapanGainGround       0x123F35C
#endif
#ifndef PATH_EVENT_S_J08KrukovSetBack
#define PATH_EVENT_S_J08KrukovSetBack       0x18F3ACC
#endif
#ifndef PATH_EVENT_S_J08Threat1_1
#define PATH_EVENT_S_J08Threat1_1       0x130B8B9
#endif
#ifndef PATH_EVENT_S_MPBaseEasterIsland
#define PATH_EVENT_S_MPBaseEasterIsland       0x159EBEC
#endif
#ifndef PATH_EVENT_S_MPBaseRushmoreMarch
#define PATH_EVENT_S_MPBaseRushmoreMarch       0x16C6602
#endif
#ifndef PATH_EVENT_S_MPBaseJapan1
#define PATH_EVENT_S_MPBaseJapan1       0x14499B5
#endif
#ifndef PATH_EVENT_S_MPBaseJapan2
#define PATH_EVENT_S_MPBaseJapan2       0x14DC8A4
#endif
#ifndef PATH_EVENT_S_MPBaseDeepOcean
#define PATH_EVENT_S_MPBaseDeepOcean       0x11EDE2E
#endif
#ifndef PATH_EVENT_S_MPBaseRussia
#define PATH_EVENT_S_MPBaseRussia       0x19C3735
#endif
#ifndef PATH_EVENT_S_MPBaseBrightonAction
#define PATH_EVENT_S_MPBaseBrightonAction       0x1E2FBCF
#endif
#ifndef PATH_EVENT_S_MPBaseEurope
#define PATH_EVENT_S_MPBaseEurope       0x1A255A5
#endif
#ifndef PATH_EVENT_S_MPBaseMykonos
#define PATH_EVENT_S_MPBaseMykonos       0x1209FBF
#endif
#ifndef PATH_EVENT_S_MPBaseGibraltar
#define PATH_EVENT_S_MPBaseGibraltar       0x1247BF9
#endif
#ifndef PATH_EVENT_S_MPBaseCold
#define PATH_EVENT_S_MPBaseCold       0x1C055B1
#endif
#ifndef PATH_EVENT_S_MPBaseBrightonAttackWave
#define PATH_EVENT_S_MPBaseBrightonAttackWave       0x1FD9B9A
#endif
#ifndef PATH_EVENT_S_MPBaseNYC
#define PATH_EVENT_S_MPBaseNYC       0x121B3CA
#endif
#ifndef PATH_EVENT_S_MPCombat
#define PATH_EVENT_S_MPCombat       0x130A1D2
#endif
#ifndef PATH_EVENT_S_MPSetAdvantagePlayer
#define PATH_EVENT_S_MPSetAdvantagePlayer       0x1F75B32
#endif
#ifndef PATH_EVENT_S_MPSetAdvantageEnemy
#define PATH_EVENT_S_MPSetAdvantageEnemy       0x1A3D8BD
#endif
#ifndef PATH_EVENT_S_MPResetAdvantage
#define PATH_EVENT_S_MPResetAdvantage       0x1B13D00
#endif
#ifndef PATH_EVENT_S_Tutorial1
#define PATH_EVENT_S_Tutorial1       0x1F09F91
#endif
#ifndef PATH_EVENT_S_Tutorial2
#define PATH_EVENT_S_Tutorial2       0x1F9CE94
#endif
#ifndef PATH_EVENT_S_Tutorial3
#define PATH_EVENT_S_Tutorial3       0x1FEFECB
#endif
#ifndef PATH_EVENT_S_Tutorial4
#define PATH_EVENT_S_Tutorial4       0x19A6AA6
#endif
#ifndef PATH_EVENT_S_Tutorial5
#define PATH_EVENT_S_Tutorial5       0x19D5B87
#endif
#ifndef PATH_EVENT_S_Tutorial6
#define PATH_EVENT_S_Tutorial6       0x1940A98
#endif
#ifndef PATH_EVENT_S_TutorialMontage
#define PATH_EVENT_S_TutorialMontage       0x1C339F1
#endif
#ifndef PATH_EVENT_S_EndMissionWin
#define PATH_EVENT_S_EndMissionWin       0x119F787
#endif
#ifndef PATH_EVENT_S_EndMissionLose
#define PATH_EVENT_S_EndMissionLose       0x1B2B433
#endif
#ifndef PATH_EVENT_S_S09FinalVictory
#define PATH_EVENT_S_S09FinalVictory       0x1D09C0A
#endif
#ifndef PATH_EVENT_S_S09InvasionForce
#define PATH_EVENT_S_S09InvasionForce       0x158093B
#endif
#ifndef PATH_EVENT_SR_S09InvasionForce
#define PATH_EVENT_SR_S09InvasionForce       0x105E8E4
#endif
#ifndef PATH_EVENT_S_S08EasterIslandBase
#define PATH_EVENT_S_S08EasterIslandBase       0x131E7DD
#endif
#ifndef PATH_EVENT_S_08Threat1_1
#define PATH_EVENT_S_08Threat1_1       0x1944A1E
#endif
#ifndef PATH_EVENT_S_09Threat1_1
#define PATH_EVENT_S_09Threat1_1       0x156222F
#endif
#ifndef PATH_EVENT_SR_S01LeninIntro
#define PATH_EVENT_SR_S01LeninIntro       0x1020F7A
#endif
#ifndef PATH_EVENT_S_S07EmperorDead
#define PATH_EVENT_S_S07EmperorDead       0x1236E3A
#endif
#ifndef PATH_EVENT_S_J08PursuePremier
#define PATH_EVENT_S_J08PursuePremier       0x189975F
#endif
#ifndef PATH_EVENT_S_J09SovietsArrive
#define PATH_EVENT_S_J09SovietsArrive       0x1DA90AF
#endif
#ifndef PATH_EVENT_S_MPThreat1JapExploreAlt1
#define PATH_EVENT_S_MPThreat1JapExploreAlt1       0x196E865
#endif
#ifndef PATH_EVENT_S_MPThreat1JapExploreAlt2
#define PATH_EVENT_S_MPThreat1JapExploreAlt2       0x19FB9B6
#endif
#ifndef PATH_EVENT_S_MPThreat1Tropical
#define PATH_EVENT_S_MPThreat1Tropical       0x1D8BF59
#endif
#ifndef PATH_EVENT_S_MPThreat1_1JapExploreAlt1
#define PATH_EVENT_S_MPThreat1_1JapExploreAlt1       0x1FF0DE8
#endif
#ifndef PATH_EVENT_S_MPThreat1_1JapExploreAlt2
#define PATH_EVENT_S_MPThreat1_1JapExploreAlt2       0x1F65FEB
#endif
#ifndef PATH_EVENT_S_MPThreat1_1Tropical
#define PATH_EVENT_S_MPThreat1_1Tropical       0x1FF6196
#endif
#ifndef PATH_EVENT_S_MPThreat1BrightonAction
#define PATH_EVENT_S_MPThreat1BrightonAction       0x18BCC22
#endif
#ifndef PATH_EVENT_S_MPThreat1GibraltarExplore
#define PATH_EVENT_S_MPThreat1GibraltarExplore       0x1EB2B25
#endif
#ifndef PATH_EVENT_S_MPThreat1NYCExplore
#define PATH_EVENT_S_MPThreat1NYCExplore       0x13D27E4
#endif
#ifndef PATH_EVENT_S_MPThreat1_1BrightonAction
#define PATH_EVENT_S_MPThreat1_1BrightonAction       0x1E22B3F
#endif
#ifndef PATH_EVENT_S_MPThreat1_1GibraltarExplore
#define PATH_EVENT_S_MPThreat1_1GibraltarExplore       0x10F9716
#endif
#ifndef PATH_EVENT_S_MPThreat1_1NYCExplore
#define PATH_EVENT_S_MPThreat1_1NYCExplore       0x15FF951
#endif
#ifndef PATH_EVENT_S_MPThreat1SovExploreAlt
#define PATH_EVENT_S_MPThreat1SovExploreAlt       0x1078053
#endif
#ifndef PATH_EVENT_S_MPThreat1_1SovExploreAlt
#define PATH_EVENT_S_MPThreat1_1SovExploreAlt       0x1642A3F
#endif
#ifndef PATH_EVENT_S_A03HeidelbergThreat1_1
#define PATH_EVENT_S_A03HeidelbergThreat1_1       0x1094FB8
#endif
#ifndef PATH_EVENT_S_A03HeidelbergThreat1
#define PATH_EVENT_S_A03HeidelbergThreat1       0x17761CC
#endif
#ifndef PATH_EVENT_S_S08EasterIslandThreat1
#define PATH_EVENT_S_S08EasterIslandThreat1       0x16E3BB1
#endif
#ifndef PATH_EVENT_S09_Threat1
#define PATH_EVENT_S09_Threat1       0x1F3F6C3
#endif
#ifndef PATH_EVENT_S_MPThreat1RushmoreCombat
#define PATH_EVENT_S_MPThreat1RushmoreCombat       0x1050F18
#endif
#ifndef PATH_EVENT_S_MPThreat1_1RushmoreCombat
#define PATH_EVENT_S_MPThreat1_1RushmoreCombat       0x16CE93B
#endif
#ifndef PATH_EVENT_S_MPThreat1EurExpAlt
#define PATH_EVENT_S_MPThreat1EurExpAlt       0x1ABD9A3
#endif
#ifndef PATH_EVENT_S_MPThreat1_1EurExpAlt
#define PATH_EVENT_S_MPThreat1_1EurExpAlt       0x1EDEB5C
#endif
#ifndef PATH_EVENT_S_MPThreat1Brighton
#define PATH_EVENT_S_MPThreat1Brighton       0x1CDB123
#endif
#ifndef PATH_EVENT_S_MPThreat1_1Brighton
#define PATH_EVENT_S_MPThreat1_1Brighton       0x1EA6F1E
#endif
#ifndef PATH_EVENT_S_MPThreat1DeepOcean
#define PATH_EVENT_S_MPThreat1DeepOcean       0x1803F32
#endif
#ifndef PATH_EVENT_S_MPThreat1_1DeepOcean
#define PATH_EVENT_S_MPThreat1_1DeepOcean       0x1C60FBB
#endif
#ifndef PATH_EVENT_S_MPThreat1Iceland
#define PATH_EVENT_S_MPThreat1Iceland       0x146D8CF
#endif
#ifndef PATH_EVENT_S_MPThreat1_1Iceland
#define PATH_EVENT_S_MPThreat1_1Iceland       0x1A891F9
#endif

/*	You can make a Pathfinder track jump to any arbitrary Part by using
	  the PATH_jump function and the constants below.

	Normally you should avoid controlling playback this way. Use events instead.

	Note that the Part must actually belong to the the track you indicate or
	  it will have no effect.
*/


#define PATH_PART_Track_Explore1_entry      83  // only track 0
#define PATH_PART_Track_Explore2_entry      89  // only track 0
#define PATH_PART_Track_CombatSoviet_entry      92  // only track 0
#define PATH_PART_Track_CombatAllied_entry      365  // only track 0
#define PATH_PART_Track_CombatJapan_entry      651  // only track 0
#define PATH_PART_Track_Threat1_1A_entry      974  // only track 0
#define PATH_PART_Track_Threat1_1S_entry      977  // only track 0
#define PATH_PART_Track_CombatSovietS_entry      98  // only track 0
#define PATH_PART_Track_CombatSovietLoseA_entry      112  // only track 0
#define PATH_PART_Track_CombatSovietLoseS_entry      115  // only track 0
#define PATH_PART_Track_CombatSovietTL_N_entry      118  // only track 0
#define PATH_PART_Track_CombatSovietAlt_entry      121  // only track 0
#define PATH_PART_Track_CombatSovietWinA_entry      135  // only track 0
#define PATH_PART_Track_CombatSovietWinS_entry      138  // only track 0
#define PATH_PART_Track_Threat1T_Threat1_1_entry      986  // only track 0
#define PATH_PART_Track_Threat1_1_entry      1113  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1_entry      911  // only track 0
#define PATH_PART_Track_CombatSovietTW_N_entry      141  // only track 0
#define PATH_PART_Track_CombatSovietTL_W_entry      144  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_entry      147  // only track 0
#define PATH_PART_Track_CombatWT_Threat1_1_entry      924  // only track 0
#define PATH_PART_Track_S_FujiIntro_entry      1255  // only track 0
#define PATH_PART_Track_S_FujiExplore_entry      1261  // only track 0
#define PATH_PART_Track_S_FujiRobot_entry      1264  // only track 0
#define PATH_PART_Track_S_FujiExploreALTA_entry      1267  // only track 0
#define PATH_PART_Track_S_FujiExploreALTS_entry      1270  // only track 0
#define PATH_PART_Track_S_FujiThreat1_A_entry      1273  // only track 0
#define PATH_PART_Track_S_FujiuThreat1_S_entry      1276  // only track 0
#define PATH_PART_Track_S_FujiThreatT_Threat1_1_entry      1279  // only track 0
#define PATH_PART_Track_S_FujiCombatT_Threat1_1_entry      1282  // only track 0
#define PATH_PART_Track_CombatJapanS_entry      654  // only track 0
#define PATH_PART_Track_CombatJapanLoseA_entry      680  // only track 0
#define PATH_PART_Track_CombatJapanLoseS_entry      683  // only track 0
#define PATH_PART_Track_CombatJapanTL_N_entry      686  // only track 0
#define PATH_PART_Track_CombatJapanWinA_entry      689  // only track 0
#define PATH_PART_Track_CombatJapanWinS_entry      692  // only track 0
#define PATH_PART_Track_CombatJapanTW_N_entry      695  // only track 0
#define PATH_PART_Track_CombatJapanTL_W_entry      698  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_entry      701  // only track 0
#define PATH_PART_Track_S_S01LeninIntro_entry      1126  // only track 0
#define PATH_PART_Track_S_S01LeninExplore_entry      1132  // only track 0
#define PATH_PART_Track_S_S01JapanFleetCombat_A_entry      1135  // only track 0
#define PATH_PART_Track_S_S01Hermitage_entry      1138  // only track 0
#define PATH_PART_Track_S_S01FakeReinforcements_entry      1141  // only track 0
#define PATH_PART_Track_RewardSoviet1_entry      1325  // only track 0
#define PATH_PART_Track_S_FujiExplore_A_entry      1258  // only track 0
#define PATH_PART_Track_S_S02KrasnaIntro_entry      1144  // only track 0
#define PATH_PART_Track_S_S02KrasnaThreat_A_entry      1147  // only track 0
#define PATH_PART_Track_S_S02KrasnaThreat_S_entry      1150  // only track 0
#define PATH_PART_Track_S_S02KrasnaJapBase_entry      1153  // only track 0
#define PATH_PART_Track_Mem_S_S02KrasnaSickles_HIT1_entry      1888  // only track 1
#define PATH_PART_Track_Mem_S_S02KrasnaThreat_OVRLY1_entry      1895  // only track 1
#define PATH_PART_Track_CombatSoviet_A_entry      95  // only track 0
#define PATH_PART_Track_S_A01BrightonExplore_A_entry      1331  // only track 0
#define PATH_PART_Track_S_A01BrightonExplore_S_entry      1334  // only track 0
#define PATH_PART_Track_S_A01BrightonTExplo_Threat_entry      1363  // only track 0
#define PATH_PART_Track_S_A01BrightonTComb_Explo_entry      1372  // only track 0
#define PATH_PART_Track_S_A01BrightonThreat_S_entry      1369  // only track 0
#define PATH_PART_Track_CombatAlliedS_entry      368  // only track 0
#define PATH_PART_Track_S_A01BrightonTExploSE_Threat_entry      1375  // only track 0
#define PATH_PART_Track_Mem_S_S02KrasnaSickles_entry      1891  // only track 1
#define PATH_PART_Track_S_S05MykonosIntro_A_entry      1159  // only track 0
#define PATH_PART_Track_S_S05MykonosExplore_S_entry      1165  // only track 0
#define PATH_PART_Track_S_S05MykonosCount1_A_entry      1168  // only track 0
#define PATH_PART_Track_S_S05MykonosCount1_S_entry      1174  // only track 0
#define PATH_PART_Track_S_S05MykonosCount2_A_entry      1201  // only track 0
#define PATH_PART_Track_S_S05MykonosCount2_S_entry      1204  // only track 0
#define PATH_PART_Track_S_S05MykonosExplore_A_entry      1162  // only track 0
#define PATH_PART_Track_S_S05MykonosCount1_AR_entry      1171  // only track 0
#define PATH_PART_Track_S_A03EuropeExplore_A_entry      1396  // only track 0
#define PATH_PART_Track_S_A03EuropeExplore_S_entry      1399  // only track 0
#define PATH_PART_Track_S_A03EuropeExploreALT_A_entry      1402  // only track 0
#define PATH_PART_Track_S_A03EuropeExploreALT_S_entry      1405  // only track 0
#define PATH_PART_Track_S_A03IronCurtain_A_entry      1408  // only track 0
#define PATH_PART_Track_S_A03IronCurtain_S_entry      1411  // only track 0
#define PATH_PART_Track_Mem_S_A03IronCurtainStinger_entry      1899  // only track 1
#define PATH_PART_Track_S_A06RushmoreLimo_S_entry      1438  // only track 0
#define PATH_PART_Track_S_A06RushmoreTowerDown_A_entry      1429  // only track 0
#define PATH_PART_Track_S_A06RushmoreLimo_A_entry      1432  // only track 0
#define PATH_PART_Track_S_A06RushmoreLimoCmbt_A_entry      1435  // only track 0
#define PATH_PART_Track_S_A06RushmoreChase_A_entry      1504  // only track 0
#define PATH_PART_Track_S_A06RushmoreChase_S_entry      1507  // only track 0
#define PATH_PART_Track_Mem_S_A06RushmoreHIT1_entry      1903  // only track 1
#define PATH_PART_Track_Mem_S_A06RushmoreHIT2_entry      1907  // only track 1
#define PATH_PART_Track_S_A02CannesSpotted_A_entry      1378  // only track 0
#define PATH_PART_Track_S_A02CannesSpotted_S_entry      1386  // only track 0
#define PATH_PART_Track_S_A02CannesSpottedT_Explore_entry      1390  // only track 0
#define PATH_PART_Track_S_A02CannesExplosion_A_entry      1393  // only track 0
#define PATH_PART_Track_S_A06CannesSpotted_AR_entry      1382  // only track 0
#define PATH_PART_Track_CombatAlliedLoseA_entry      454  // only track 0
#define PATH_PART_Track_CombatAlliedLoseS_entry      457  // only track 0
#define PATH_PART_Track_CombatAlliedWinA_entry      460  // only track 0
#define PATH_PART_Track_CombatAlliedWinS_entry      463  // only track 0
#define PATH_PART_Track_CombatAlliedTW_N_entry      466  // only track 0
#define PATH_PART_Track_CombatAlliedTL_W_entry      469  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_entry      472  // only track 0
#define PATH_PART_Track_J02_River_A_entry      1552  // only track 0
#define PATH_PART_Track_J02_SovExploreALT_A_entry      1558  // only track 0
#define PATH_PART_Track_J02_SovExploreALT_S_entry      1561  // only track 0
#define PATH_PART_Track_J02_StatueDown_A_entry      1555  // only track 0
#define PATH_PART_Track_J02_EmpireVictorious_entry      1564  // only track 0
#define PATH_PART_Track_CombatJapanNEndSovExpAlt_entry      708  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1SovExpAlt_entry      915  // only track 0
#define PATH_PART_Track_Threat1_SovAltExp_A_entry      980  // only track 0
#define PATH_PART_Track_Threat1_SovAltExp_S_entry      983  // only track 0
#define PATH_PART_Track_Threat1T_SovExpAlt_entry      989  // only track 0
#define PATH_PART_Track_J03_OdessaIntro_A_entry      1567  // only track 0
#define PATH_PART_Track_J03_OdessaShogun_A_entry      1570  // only track 0
#define PATH_PART_Track_J03_OdessaThreat_A_entry      1573  // only track 0
#define PATH_PART_Track_J03_OdessaThreat_S_entry      1576  // only track 0
#define PATH_PART_Track_J03_ShogunRampage_A_entry      1579  // only track 0
#define PATH_PART_Track_J03_ShogunRampage_S_entry      1582  // only track 0
#define PATH_PART_Track_S_S01LeninExplore_A_entry      1129  // only track 0
#define PATH_PART_Track_S_A04GibraltarIntro_A_entry      1414  // only track 0
#define PATH_PART_Track_S_A04GibraltarDestroyAirbase_A_entry      1417  // only track 0
#define PATH_PART_Track_S_A04GibraltarDestroyAirbase_S_entry      1420  // only track 0
#define PATH_PART_Track_A04_GibraltarExplore_A_entry      1423  // only track 0
#define PATH_PART_Track_A04_GibraltarExplore_S_entry      1426  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1GibraltarExp_entry      927  // only track 0
#define PATH_PART_Track_Threat1_GibraltarExp_A_entry      992  // only track 0
#define PATH_PART_Track_Threat1_GibraltarExp_S_entry      995  // only track 0
#define PATH_PART_Track_CombatAlliedNEndGibraltarExp_entry      487  // only track 0
#define PATH_PART_Track_Threat1T_GibraltarExp_entry      998  // only track 0
#define PATH_PART_Track_J01_IntoTheFirefight_A_entry      1549  // only track 0
#define PATH_PART_Track_HMThreat1_Ax_entry      1585  // only track 0
#define PATH_PART_Track_HMThreat1_S_entry      1594  // only track 0
#define PATH_PART_Track_HMThreat1T_SovExpAlt_entry      1597  // only track 0
#define PATH_PART_Track_CombatT_HMThreat1_1SovExpAlt_entry      1600  // only track 0
#define PATH_PART_Track_CombatSoviet2_entry      204  // only track 0
#define PATH_PART_Track_CombatSoviet2_A_entry      207  // only track 0
#define PATH_PART_Track_CombatSoviet2S_entry      210  // only track 0
#define PATH_PART_Track_CombatSoviet2LoseA_entry      248  // only track 0
#define PATH_PART_Track_CombatSoviet2LoseS_entry      251  // only track 0
#define PATH_PART_Track_CombatSoviet2TL_N_entry      255  // only track 0
#define PATH_PART_Track_CombatSoviet2Alt_entry      258  // only track 0
#define PATH_PART_Track_CombatSoviet2WinA_entry      296  // only track 0
#define PATH_PART_Track_CombatSoviet2WinS_entry      299  // only track 0
#define PATH_PART_Track_CombatSoviet2TW_N_entry      303  // only track 0
#define PATH_PART_Track_CombatSoviet2TL_W_entry      306  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_entry      309  // only track 0
#define PATH_PART_Track_S_A01BrightonExploreVer2_A1_entry      1338  // only track 0
#define PATH_PART_Track_S_A01BrightonExploreVer2_S_entry      1360  // only track 0
#define PATH_PART_Track_S_A01BrightonExploreVer2_A2_entry      1344  // only track 0
#define PATH_PART_Track_S_A01BrightonExploreVer2_S1_entry      1350  // only track 0
#define PATH_PART_Track_S_A01BrightonExploreVer2_S2_entry      1354  // only track 0
#define PATH_PART_Track_S_A01BrightonTComb_ExploVer2_1_entry      1341  // only track 0
#define PATH_PART_Track_S_A01BrightonTComb_ExploVer2_2_entry      1347  // only track 0
#define PATH_PART_Track_UpYoursSoviet_entry      1116  // only track 0
#define PATH_PART_Track_SH_Grinder_A_entry      0  // only track 0
#define PATH_PART_Track_SH_Grinder_S_entry      3  // only track 0
#define PATH_PART_Track_SH_Grinder_LNK_entry      6  // only track 0
#define PATH_PART_Track_SH_Anthem_A_entry      9  // only track 0
#define PATH_PART_Track_SH_Anthem_S_entry      12  // only track 0
#define PATH_PART_Track_SH_Anthem_LNK_entry      15  // only track 0
#define PATH_PART_Track_SH_HM3_A_entry      18  // only track 0
#define PATH_PART_Track_SH_HM3_S_entry      21  // only track 0
#define PATH_PART_Track_SH_HM3_LNK_entry      24  // only track 0
#define PATH_PART_Track_SH_HMFFTL_S_entry      27  // only track 0
#define PATH_PART_Track_SH_HMFFTL_LNK_entry      30  // only track 0
#define PATH_PART_Track_SH_Briefing_A_entry      33  // only track 0
#define PATH_PART_Track_SH_Briefing_S_entry      36  // only track 0
#define PATH_PART_Track_SH_Credits_entry      39  // only track 0
#define PATH_PART_Track_SH_StatsSovLose_A_entry      47  // only track 0
#define PATH_PART_Track_SH_StatsSovLose_S_entry      50  // only track 0
#define PATH_PART_Track_SH_StatsSovWin_A_entry      53  // only track 0
#define PATH_PART_Track_SH_StatsSovWin_S_entry      56  // only track 0
#define PATH_PART_Track_S_S08EasterIsland_A_entry      1286  // only track 0
#define PATH_PART_Track_S_S08EasterIsland_S_entry      1289  // only track 0
#define PATH_PART_Track_S_S08Emissary_A_entry      1319  // only track 0
#define PATH_PART_Track_S_S08Emissary_S_entry      1322  // only track 0
#define PATH_PART_Track_S_S06IcelandIntro_A_entry      1231  // only track 0
#define PATH_PART_Track_S_S06IcelandIntro_AR_entry      1234  // only track 0
#define PATH_PART_Track_S_S06IcelandIntro_S_entry      1237  // only track 0
#define PATH_PART_Track_S_S06Krukov_A_entry      1240  // only track 0
#define PATH_PART_Track_S_S06Threat1v4_A_entry      1243  // only track 0
#define PATH_PART_Track_S_S06Threat1v4_S_entry      1246  // only track 0
#define PATH_PART_Track_S_S06KrukovTraitor_A_entry      1249  // only track 0
#define PATH_PART_Track_S_S06KrukovDefeated_A_entry      1252  // only track 0
#define PATH_PART_Track_S_S04GenevaIntro_A_entry      1156  // only track 0
#define PATH_PART_Track_S_S04AlliesChrono_A_entry      1604  // only track 0
#define PATH_PART_Track_S_S04ThreatChrono_S_entry      1610  // only track 0
#define PATH_PART_Track_S_S04KrukovTellsYouOff_A_entry      1613  // only track 0
#define PATH_PART_Track_S_S04ThreatChrono_A_entry      1607  // only track 0
#define PATH_PART_Track_S_S07YokohamaThreat_A_entry      1616  // only track 0
#define PATH_PART_Track_S_S07YokohamaThreat_S_entry      1619  // only track 0
#define PATH_PART_Track_S_S07Reinforcments_A_entry      1622  // only track 0
#define PATH_PART_Track_S_S07SovietNavy_A_entry      1625  // only track 0
#define PATH_PART_Track_UpYoursAllied_entry      1119  // only track 0
#define PATH_PART_Track_UpYoursEmpire_entry      1122  // only track 0
#define PATH_PART_Track_S_A09LeningradIntro_entry      1516  // only track 0
#define PATH_PART_Track_S_A09MicroChase_A_entry      1519  // only track 0
#define PATH_PART_Track_S_A09Threats_A_entry      1525  // only track 0
#define PATH_PART_Track_S_A09Threats_S_entry      1528  // only track 0
#define PATH_PART_Track_S_A09PremierEscapes_A_entry      1542  // only track 0
#define PATH_PART_Track_S_A09FinalMinute_A_entry      1546  // only track 0
#define PATH_PART_Track_CombatAlliedNEndSovietExpALT_entry      490  // only track 0
#define PATH_PART_Track_S_A08HavanaExplore_A_entry      1510  // only track 0
#define PATH_PART_Track_S_A08HavanaExplore_S_entry      1513  // only track 0
#define PATH_PART_Track_Explore1_S_entry      86  // only track 0
#define PATH_PART_Track_Mem_S_A08RealAPOCTanks_entry      1911  // only track 1
#define PATH_PART_Track_S_A08FirstCombat_A_entry      1628  // only track 0
#define PATH_PART_Track_S_A08Kirovs_A_entry      1631  // only track 0
#define PATH_PART_Track_HMThreat1_Az_entry      1588  // only track 0
#define PATH_PART_Track_S_A08AlliedReward_entry      1634  // only track 0
#define PATH_PART_Track_S_A08HavanaExploreALT_A_entry      1637  // only track 0
#define PATH_PART_Track_S_A08HavanaExploreALT_S_entry      1640  // only track 0
#define PATH_PART_Track_HMThreat_A_entry      1591  // only track 0
#define PATH_PART_Track_S_S09NYCExplore_A_entry      1643  // only track 0
#define PATH_PART_Track_S_S09NYCExplore_S_entry      1646  // only track 0
#define PATH_PART_Track_S_S09RA2Moment_A_entry      1649  // only track 0
#define PATH_PART_Track_S_J04PearlHarborIntro_A_entry      1652  // only track 0
#define PATH_PART_Track_S_J04HarborExplore_A_entry      1655  // only track 0
#define PATH_PART_Track_S_J04HarborExplore_S_entry      1658  // only track 0
#define PATH_PART_Track_S_J04JapoThreat_A_entry      1661  // only track 0
#define PATH_PART_Track_CombatJapanNEndHarborExplore_entry      716  // only track 0
#define PATH_PART_Track_S_J04FleetArrives_A_entry      1664  // only track 0
#define PATH_PART_Track_S_A07TokyoIntro_A_entry      1668  // only track 0
#define PATH_PART_Track_S_A07Decimator_A_entry      1671  // only track 0
#define PATH_PART_Track_CombatAlliedNEndHarborExp_entry      493  // only track 0
#define PATH_PART_Track_S_A01BrightonIntro_A_entry      1674  // only track 0
#define PATH_PART_Track_S_A01BrightonAction_A_entry      1677  // only track 0
#define PATH_PART_Track_S_A01BrightonAction_S_entry      1680  // only track 0
#define PATH_PART_Track_S_J06SantaMonicaIntro_A_entry      1683  // only track 0
#define PATH_PART_Track_S_A05DeepSeaBase_A_entry      1686  // only track 0
#define PATH_PART_Track_S_A05DeepSeaBase_S_entry      1689  // only track 0
#define PATH_PART_Track_S_A05NorthSeaThreat_A_entry      1692  // only track 0
#define PATH_PART_Track_S_A05NorthSeaIntro_A_entry      1695  // only track 0
#define PATH_PART_Track_Mem_S_A05EnemyUnit01_entry      1915  // only track 1
#define PATH_PART_Track_Mem_S_A05EnemyUnit02_entry      1919  // only track 1
#define PATH_PART_Track_S_A01BrightonThreat_A_entry      1366  // only track 0
#define PATH_PART_Track_CombatSovietNEndExploreCold_entry      150  // only track 0
#define PATH_PART_Track_Threat1_ColdExp_A_entry      1001  // only track 0
#define PATH_PART_Track_Threat1_ColdExp_S_entry      1004  // only track 0
#define PATH_PART_Track_Threat1T_ColdExp_entry      1007  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1ColdExp_entry      931  // only track 0
#define PATH_PART_Track_S_J05DeepOceanIntro_entry      1698  // only track 0
#define PATH_PART_Track_CombatJapanNEndSeaExplore_entry      719  // only track 0
#define PATH_PART_Track_CombatJapanWLSeaExplore_entry      768  // only track 0
#define PATH_PART_Track_S_J09SovNukeAttack_A_entry      1701  // only track 0
#define PATH_PART_Track_CombatJapanNEndEurAltExplore_entry      722  // only track 0
#define PATH_PART_Track_CombatJapanWLEurAltExplore_entry      771  // only track 0
#define PATH_PART_Track_S_J08JapanVictorious_A_entry      1710  // only track 0
#define PATH_PART_Track_S_J08JapanVictorious_S_entry      1713  // only track 0
#define PATH_PART_Track_S_J08TimeMachineDestroyed_A_entry      1716  // only track 0
#define PATH_PART_Track_CombatJapan2_entry      774  // only track 0
#define PATH_PART_Track_CombatJapan2S_entry      777  // only track 0
#define PATH_PART_Track_CombatJapan2LoseA_entry      811  // only track 0
#define PATH_PART_Track_CombatJapan2LoseS_entry      814  // only track 0
#define PATH_PART_Track_S_J08ShogunExecutioner_A_entry      1719  // only track 0
#define PATH_PART_Track_S_J08KrukovSetBack_entry      1722  // only track 0
#define PATH_PART_Track_S_J08JapanGainGround_entry      1748  // only track 0
#define PATH_PART_Track_S_J08BeginExecutionerCombat_entry      1782  // only track 0
#define PATH_PART_Track_S_S08Tropical_A_entry      1815  // only track 0
#define PATH_PART_Track_S_S08Tropical_S_entry      1818  // only track 0
#define PATH_PART_Track_S_J04JapanExplore2ALT_A_entry      1824  // only track 0
#define PATH_PART_Track_S_J04JapanExplore2ALT_S_entry      1827  // only track 0
#define PATH_PART_Track_S_J04JapoThreatALT_A_entry      1821  // only track 0
#define PATH_PART_Track_CombatJapanNEndJapAltExplore2_entry      725  // only track 0
#define PATH_PART_Track_CombatAllied2_entry      533  // only track 0
#define PATH_PART_Track_CombatAllied2_S_entry      536  // only track 0
#define PATH_PART_Track_CombatAllied2LoseA_entry      575  // only track 0
#define PATH_PART_Track_CombatAllied2LoseS_entry      578  // only track 0
#define PATH_PART_Track_CombatAllied2WinA_entry      582  // only track 0
#define PATH_PART_Track_CombatAllied2WinS_entry      585  // only track 0
#define PATH_PART_Track_CombatAllied2TW_N_entry      589  // only track 0
#define PATH_PART_Track_CombatAllied2TL_W_entry      592  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_entry      595  // only track 0
#define PATH_PART_Track_CombatJapan2TL_N_entry      840  // only track 0
#define PATH_PART_Track_CombatJapan2WinA_entry      843  // only track 0
#define PATH_PART_Track_CombatJapan2WinS_entry      846  // only track 0
#define PATH_PART_Track_CombatJapan2TW_N_entry      849  // only track 0
#define PATH_PART_Track_CombatJapan2TL_W_entry      852  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_entry      855  // only track 0
#define PATH_PART_Track_SH_StatsJapLose_A_entry      59  // only track 0
#define PATH_PART_Track_SH_StatsJapLose_S_entry      62  // only track 0
#define PATH_PART_Track_SH_StatsJapWin_A_entry      65  // only track 0
#define PATH_PART_Track_SH_StatsJapWin_S_entry      68  // only track 0
#define PATH_PART_Track_RewardAllied1_entry      1328  // only track 0
#define PATH_PART_Track_S_S09FinalVictory_entry      1830  // only track 0
#define PATH_PART_Track_S_S09InvasionForce_entry      1833  // only track 0
#define PATH_PART_Track_CombatSovietNEndNYC_entry      153  // only track 0
#define PATH_PART_Track_CombatSovietNEndTropical_entry      156  // only track 0
#define PATH_PART_Track_S_09Threat1_1_entry      1836  // only track 0
#define PATH_PART_Track_S_08Threat1_1_entry      1839  // only track 0
#define PATH_PART_Track_S_S07EmperorDead_entry      1842  // only track 0
#define PATH_PART_Track_S_J08PursuePremier_A_entry      1845  // only track 0
#define PATH_PART_Track_S_J08PursuePremier_S_entry      1848  // only track 0
#define PATH_PART_Track_S_J07YokohamaIntro_A_entry      1851  // only track 0
#define PATH_PART_Track_SH_StatsAllLose_A_entry      71  // only track 0
#define PATH_PART_Track_SH_StatsAllLose_S_entry      74  // only track 0
#define PATH_PART_Track_SH_StatsAllWin_A_entry      77  // only track 0
#define PATH_PART_Track_SH_StatsAllWin_S_entry      80  // only track 0
#define PATH_PART_Track_S_J09SovNukeAttack_S_entry      1704  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1Jap1Alt_entry      935  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1Jap2Alt_entry      939  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1Tropical_entry      943  // only track 0
#define PATH_PART_Track_Threat1_Jap1Alt_A_entry      1010  // only track 0
#define PATH_PART_Track_Threat1_Jap1Alt_S_entry      1013  // only track 0
#define PATH_PART_Track_Threat1T_Jap1Alt_entry      1016  // only track 0
#define PATH_PART_Track_Threat1_Jap2Alt_A_entry      1019  // only track 0
#define PATH_PART_Track_Threat1_Jap1Alt_S_entry      1022  // only track 0
#define PATH_PART_Track_Threat1T_Jap2Alt_entry      1025  // only track 0
#define PATH_PART_Track_Threat1_Tropical_A_entry      1028  // only track 0
#define PATH_PART_Track_Threat1_Tropical_S_entry      1031  // only track 0
#define PATH_PART_Track_Threat1T_Tropical_entry      1034  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_Jap1Alt_entry      858  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_Jap2Alt_entry      862  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_Tropical_entry      866  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_Tropical_entry      704  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_Jap1Alt_entry      598  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_Jap2Alt_entry      602  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_Tropical_entry      606  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_Jap1Alt_entry      475  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_Jap2Alt_entry      479  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_Tropical_entry      483  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_Jap1Alt_entry      312  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_Jap2Alt_entry      316  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_Tropical_entry      320  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_Jap1Alt_entry      159  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_Jap2Alt_entry      163  // only track 0
#define PATH_PART_Track_CombatJapanNEndJapAltExplore1_entry      728  // only track 0
#define PATH_PART_Track_Threat1_BrightonAction_A_entry      1046  // only track 0
#define PATH_PART_Track_Threat1_BrightonAction_S_entry      1049  // only track 0
#define PATH_PART_Track_Threat1T_BrightonAction_entry      1052  // only track 0
#define PATH_PART_Track_Threat1_NYCExplore_A_entry      1055  // only track 0
#define PATH_PART_Track_Threat1_NYCExplore_S_entry      1058  // only track 0
#define PATH_PART_Track_Threat1T_NYCExplore_entry      1061  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1BrightonAction_entry      947  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1NYCExplore_entry      951  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_BrightonAction_entry      167  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_GibraltarExplore_entry      171  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_BrightonAction_entry      324  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_GibraltarExplore_entry      328  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_NYC_entry      332  // only track 0
#define PATH_PART_Track_CombatAlliedNEndBrightonAction_entry      496  // only track 0
#define PATH_PART_Track_CombatAlliedNEndNYC_entry      500  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_BrightonAction_entry      610  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_GibraltarExplore_entry      614  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_NYC_entry      618  // only track 0
#define PATH_PART_Track_CombatJapanNEndBrightonAction_entry      732  // only track 0
#define PATH_PART_Track_CombatJapanNEndGibraltarExplore_entry      736  // only track 0
#define PATH_PART_Track_CombatJapanNEndNYC_entry      740  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_BrightonAction_entry      870  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_GibraltarExplore_entry      874  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_NYC_entry      878  // only track 0
#define PATH_PART_Track_Threat1_HMT_SovExploreALT_A_entry      1064  // only track 0
#define PATH_PART_Track_Threat1_HMT_SovExploreALT_S_entry      1067  // only track 0
#define PATH_PART_Track_Threat1_HMT_SovExploreALT_entry      1070  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1SovExpAlt_HM_entry      919  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_SovExploreAlt_entry      175  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_SovExploreAlt_entry      336  // only track 0
#define PATH_PART_Track_CombatAlliedNEndSovExploreAlt_entry      504  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_SovExploreAlt_entry      622  // only track 0
#define PATH_PART_Track_CombatJapanNEndSovExpAlt_HM_entry      711  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_SovExploreAlt_entry      882  // only track 0
#define PATH_PART_Track_Threat1_1v4_EurExploreALT_A_entry      1073  // only track 0
#define PATH_PART_Track_Threat1_1v4_EurExploreALT_S_entry      1076  // only track 0
#define PATH_PART_Track_Threat1_1v4_EurExploreALT_entry      1079  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1EurExploreALT_entry      955  // only track 0
#define PATH_PART_Track_CombatAlliedNEndThreat1v4_entry      514  // only track 0
#define PATH_PART_Track_Threat1_Tropical2_A_entry      1037  // only track 0
#define PATH_PART_Track_Threat1_Tropical2_S_entry      1040  // only track 0
#define PATH_PART_Track_Threat1_Tropical2_entry      1043  // only track 0
#define PATH_PART_Track_S_J09FinalShowdown_A_entry      1707  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1RushmoreCombat_entry      960  // only track 0
#define PATH_PART_Track_S_MPRushmoreLimoCombat_S_entry      1854  // only track 0
#define PATH_PART_Track_Threat1_1v4_RushmoreCombat_A_entry      1082  // only track 0
#define PATH_PART_Track_Threat1_1v4_RushmoreCombat_S_entry      1085  // only track 0
#define PATH_PART_Track_Threat1_1v4_RushmoreCombat_entry      1088  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_RushmoreCombat_entry      180  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_EurExploreAlt_entry      185  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_RushmoreCombat_entry      341  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_EurExploreAlt_entry      346  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_RushmoreCombat_entry      509  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_RushmoreCombat_entry      627  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_EurExploreAlt_entry      632  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_RushmoreCombat_entry      744  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_EurExploreAlt_entry      749  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_RushmoreCombat_entry      887  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_EurExploreAlt_entry      892  // only track 0
#define PATH_PART_Track_Threat1_Brighton_A_entry      1091  // only track 0
#define PATH_PART_Track_Threat1_Brighton_S_entry      1094  // only track 0
#define PATH_PART_Track_Threat1_Brighton_entry      1097  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1Brighton_entry      965  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_Brighton_entry      190  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_Brighton_entry      351  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_Brighton_entry      519  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_Brighton_entry      637  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_Brighton_entry      754  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_Brighton_entry      897  // only track 0
#define PATH_PART_Track_Threat1_1v3_DeepOcean_A_entry      1100  // only track 0
#define PATH_PART_Track_Threat1_1v3_DeepOcean_S_entry      1103  // only track 0
#define PATH_PART_Track_Threat1_1v3_DeepOcean_entry      1106  // only track 0
#define PATH_PART_Track_Threat1_Iceland_A_entry      1109  // only track 0
#define PATH_PART_Track_CombatT_Threat1_1Iceland_entry      970  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_DeepOcean_entry      195  // only track 0
#define PATH_PART_Track_CombatSovietNEnd_Iceland_entry      200  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_DeepOcean_entry      356  // only track 0
#define PATH_PART_Track_CombatSoviet2NEnd_Iceland_entry      361  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_DeepOcean_entry      524  // only track 0
#define PATH_PART_Track_CombatAlliedNEnd_Iceland_entry      529  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_DeepOcean_entry      642  // only track 0
#define PATH_PART_Track_CombatAllied2NEnd_Iceland_entry      647  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_DeepOcean_entry      759  // only track 0
#define PATH_PART_Track_CombatJapanNEnd_Iceland_entry      764  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_DeepOcean_entry      902  // only track 0
#define PATH_PART_Track_CombatJapan2NEnd_Iceland_entry      907  // only track 0



#endif

