!***********************************************************************
!*****************************  KEK, High Energy Accelerator Research  *
!*****************************  Organization                           *
!*** ucdte5 ******************                                         *
!*****************************    EGS5.0 USER CODE -  28 Jul 2012/1430 *
!***********************************************************************
!* This is a general User Code based on the cg geometry scheme.        *
!***********************************************************************
!***********************************************************************
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12

!-----------------------------------------------------------------------
!------------------------------- main code -----------------------------
!-----------------------------------------------------------------------


! for counting time
      use,intrinsic :: iso_fortran_env

!-----------------------------------------------------------------------
! Step 1: Initialization
!-----------------------------------------------------------------------
      implicit none
!     ------------
!     EGS5 COMMONs
!     ------------
      include 'include/egs5_h.f'                ! Main EGS "header" file
      include 'include/egs5_bounds.f'
      include 'include/egs5_brempr.f'
      include 'include/egs5_edge.f'
      include 'include/egs5_media.f'
      include 'include/egs5_misc.f'
      include 'include/egs5_stack.f'
      include 'include/egs5_thresh.f'
      include 'include/egs5_uphiot.f'
      include 'include/egs5_useful.f'
      include 'include/egs5_usersc.f'
      include 'include/egs5_userxt.f'
      include 'include/randomm.f'
      include 'include/counters.f'
      include "mpif.h"				! For MPI
      include 'mpi_include/egs5mpi_h.f'


!     ----------------------
!     Auxiliary-code COMMONs
!     ----------------------
      include 'auxcommons/aux_h.f'   ! Auxiliary-code "header" file
      include 'auxcommons/edata.f'
      include 'auxcommons/etaly1.f'
      include 'auxcommons/instuf.f'
      include 'auxcommons/lines.f'
      include 'auxcommons/nfac.f'
      include 'auxcommons/watch.f'

!     ------------------
!     cg related COMMONs
!     ------------------
      include 'auxcommons/geom_common.f'   ! geom-common file
      integer irinn
      integer,parameter :: maxch = 1000    !max channel of the detector
      integer,parameter :: maxtrans = 4096 !150 !max translation times
      integer,parameter :: maxspec = 18000  !max row of source.csv
      integer,parameter :: maxparam = 10
      integer,parameter :: GEOM_RPP = 1
      integer,parameter :: GEOM_RCC = 2
      integer,parameter :: GEOM_BOX = 6
      integer,parameter :: GEOM_END = 15
      integer,parameter :: PHANTOM_ONION = 0
      integer,parameter :: PHANTOM_TISSUE = 1
      integer,parameter :: PHANTOM_METAL = 2
      integer,parameter :: PHANTOM_FOUR_METAL = 3
      integer,parameter :: PHANTOM_FOUR_METAL_TEST = 4
      integer,parameter :: PHANTOM_FOUR_TISSUES = 5
      integer,parameter :: PHANTOM_SMALL = 6
      integer,parameter :: PHANTOM_SMALL_FOUR = 7
      integer,parameter :: PHANTOM_SQUARE = 8
      integer,parameter :: PHANTOM_SQUARE2 = 9

      common/totals/depe(4096),deltae,maxpict,transi
      real*8 depe,deltae,spec
      integer maxpict,transi

      real*8 totke,rnnow,phai,etot,availke,wtin,wtsum,gsum,
     * halfosl,offset

      real*8 csrad,ctx,cty,ctz,translation_pitch,xl,zl,gross,
     * htl,theta_rnd

	double precision ctdiss,ctdisd

      real tarray(2),tt,tt0,tt1,cputime,etime,ctang,parameters(maxparam)

      integer apch

      integer,dimension(maxch,maxtrans) :: phs!, mpi_phs

      integer
     * i,icases,idin,ie,ifti,ifto,ifct,imed,ireg,nlist,j,ntype,
     * cti,l,nos,cto,ctp,translation_times,ctstep,stepi,initstep,
     * haltstep,npr,ifto_original,ifto_dummy,nor,prmi,
     * phantom,beam!,mpi_ifct

      !for counting time
      integer(int32) :: time_begin_c,time_end_c, CountPerSec, CountMax

      real,dimension(2,maxspec) :: crt
      real,dimension(30,maxtrans+100) :: ctgeom

      character*24 medarr(MXMED)
      character*3  geomkind(15)
      character*8  geomzone(100)
      character*22 savepath
      character*22 degfile
      character*25 pictfile

      character(4) :: paramname(maxparam)

      integer totalcases,mpierr		!for MPI
      character*6 rank_str
      real*8 mpi_esum(MXREG)

! External phantom configuration file support
      integer,parameter :: MAXINSERTS=64
      logical ph_use_file
      real*8 ph_bg_radius,ph_cyl_y0,ph_cyl_dy
      integer ph_n_rcc,ph_n_rpp,ph_bg_med
      real*8 ph_rcc_cx(MAXINSERTS),ph_rcc_cz(MAXINSERTS)
      real*8 ph_rcc_r(MAXINSERTS)
      real*8 ph_rpp_x1(MAXINSERTS),ph_rpp_x2(MAXINSERTS)
      real*8 ph_rpp_y1(MAXINSERTS),ph_rpp_y2(MAXINSERTS)
      real*8 ph_rpp_z1(MAXINSERTS),ph_rpp_z2(MAXINSERTS)
      integer ph_nmed,ph_insert_med(MAXINSERTS)
      character*24 ph_medarr(MXMED)
      real*8 ph_chard(MXMED)
      integer ios,ios_geom,ios_mat

      NAMELIST /GEOMETRY/ ph_bg_radius,ph_cyl_y0,ph_cyl_dy,
     * ph_n_rcc,ph_rcc_cx,ph_rcc_cz,ph_rcc_r,
     * ph_n_rpp,ph_rpp_x1,ph_rpp_x2,ph_rpp_y1,
     * ph_rpp_y2,ph_rpp_z1,ph_rpp_z2
      NAMELIST /MATERIALS/ ph_nmed,ph_medarr,ph_chard,
     * ph_bg_med,ph_insert_med


!------------------
!     EGS5-MPI Init
!------------------

      call egs5mpi_init

!     ----------
!     Open files
!     ----------
!----------------------------------------------------------------
!     Units 7-26 are used in pegs and closed.  It is better not
!     to use as output file. If they are used, they must be opened
!     after getcg etc. Unit for pict must be 39.
!----------------------------------------------------------------

	    write(rank_str, '(I6.6)') mpi_rank

      !open(6,FILE='egs5job.out',STATUS='unknown')
      !open(40,FILE='source150kv.csv',STATUS='old')
      open(40,FILE='source.csv',STATUS='old')
      !open(40,FILE='source270kv_theta60_cu0.3mm.csv',STATUS='old')
      open(50,FILE='parameter.csv',STATUS='old')


!     ====================
      call counters_out(0)
!     ====================
!-----------------------------------------------------------------------
! Advanced Option for Geometory data(User might change these items)
!-----------------------------------------------------------------------
      offset=0.00004d0    !offset energy of enegy bin
      deltae=0.0004d0     !delta energy of energy bin
      ctx=0.30d0
      cty=0.30d0
      ctz=0.075d0
      maxpict=100
      npreci=3   ! PICT data mode for CGView in free format
      ifti=4     ! Input unit number for cg-data
      ifct=61    ! Output unit number for the CT-data
      !mpi_ifct=62 ! Output unit number for the CT-data(for mpi)
      ifto_original=39    ! Output unit number for pictfile
      ifto_dummy=41   !Output unit number for dummy pictfile
      apch=1     ! Initialization of apch
      phantom=PHANTOM_TISSUE
!     Phantom Type:
!     0:Onion, 1:Tissue, 2:Metal, 3:FourMetal,
!     4:FourMetalTest(wo/Ni), 5:FourTissues,
!     6:small, 7:smallfour, 8:square, 9:square2
      beam=1     ! Beam Type (0:Parallel, 1:Fan)
      savepath="share" ! Path for output
!-----------------------------------------------------------------------
! initiallization variables
!-----------------------------------------------------------------------

      do i=1,4096
        depe(i)=0.D0
      end do

      !ctdis=-1.0d0
      npr = 1
      ctdiss=-1.0d0
      ctdisd=-1.0d0
      ctstep=-1
      initstep=0
      ncases=0
	    totalcases=0
      gross=0.0d0
      gsum=0.0d0
      geomkind(1)='RPP'
      geomkind(2)='RCC'
      geomkind(3)='SPH'
      geomkind(4)='TRC'
      geomkind(5)='TOR'
      geomkind(6)='BOX'
      geomkind(7)='REC'
      geomkind(8)='TEC'
      geomkind(9)='ELL'
      geomkind(10)='WED'
      geomkind(11)='ARB'
      geomkind(12)='HAF'
      geomkind(13)='HEX'
      geomkind(14)='GEL'
      geomkind(15)='END'
!-----------------------------------------------------------------------
! read variables
!-----------------------------------------------------------------------
      write(6,*) "read variables"
      flush(6)
      do prmi=1, maxparam
        read(50, *) paramname(prmi),parameters(prmi)
      end do
      close(unit=50)
      read(40,*) crt(1,apch),crt(2,apch)
      if(crt(2,apch).eq.0) then
        write(6,*) "The first count of source.csv can't be zero"
        flush(6)
        stop
      end if
      do
        apch=apch+1
        read(40,*,end=90) crt(1,apch),crt(2,apch)
      end do
90    continue
      apch=apch-1
      close(unit=40)
      ctdiss = parameters(npr)
      npr=npr+1
      ctdisd = parameters(npr)
      npr=npr+1
      ctdisd = ctdisd - ctdiss
!      read *, ctdis
      !ctdis=ctdis/2
      if(ctdiss.le.0.0 .or. ctdisd.le.0.0) then
        write(6,*) "distance must be greater than 0!"
        flush(6)
        stop
      end if
      translation_pitch = parameters(npr)
      npr=npr+1

!      read *, translation_pitch
      if(translation_pitch.le.0.0) then
        write(6,*) "translation must be greater than 0!"
        flush(6)
        stop
      end if

      ctx = translation_pitch !adjust ctx, cty to translation pitch
      cty = translation_pitch
      !ctz = translation_pitch

      translation_times = parameters(npr)
      npr=npr+1
!      read *, translation_times
      htl=((translation_times-1)*translation_pitch)/2 !half translation length
      if(mod(translation_times,2).ne.0.or.translation_times.lt.0) then
        write(6,*) "translation_times should be even number"
        flush(6)
        stop
      else if(translation_times.gt.4096) then
        write(6,*) "translation_times should be smaller than 4096"
        flush(6)
        stop
      end if
      ctstep = parameters(npr)
      npr=npr+1
!      read *, ctstep
      if(ctstep.le.0.0.or.ctstep.gt.3600.0) then
        stop
      end if
      totalcases = parameters(npr)
      npr=npr+1
!      read *, ncases
      if(totalcases.lt.1) then
        write(6,*) "History number should be set at least one"
        flush(6)
        stop
      end if
      initstep = parameters(npr)
      npr=npr+1
      haltstep = parameters(npr)
      npr=npr+1
      phantom = parameters(npr)
      npr=npr+1
      if(phantom.lt.PHANTOM_ONION .or.
     *   phantom.gt.PHANTOM_SQUARE2) then
        write(6,*) "phantom number you entered is not defined"
      end if
      beam = parameters(npr)
      npr=npr+1
      if(beam.lt.0 .or. beam.gt.1) then
        write(6,*) "beam type number you entered is not defined"
      end if
      print *,"--------------------"
      print *,"     SOURCE-OBJECT:",ctdiss
      print *,"   DETECTOR-OBJECT:",ctdisd
      print *,"             PITCH:",translation_pitch
      print *," TRANSLATION TIMES:",translation_times
      print *,"             STEPS:",ctstep
      print *,"    HISTORY NUMBER:",totalcases
      print *,"      INITIAL STEP:",initstep
      print *,"         HALT STEP:",haltstep
      print *,"      PHANTOM TYPE:",phantom
      print *,"         BEAM TYPE:",beam
      print *,"--------------------"
!-----------------------------------------------------------------------
! Preparation of Air region
!-----------------------------------------------------------------------
      halfosl=max(ctdiss,ctdisd)+10.0d0               !half one side length of air region
!-----------------------------------------------------------------------
! X-ray tube Sampling
!-----------------------------------------------------------------------
      write(6,*) "X-ray tube Sampling"
      flush(6)
      do cti=1,apch
        gross=gross+crt(2,cti)             !calculation of the gross area
      end do
      do cti=1,apch
        crt(2,cti)=crt(2,cti)/gross+gsum       !calculation of PDF and QDF
        gsum=crt(2,cti)
      end do
      if(crt(2,apch).lt.0.999) then
        write(6,*) "EGS5 failed X-ray tube sampling"
        flush(6)
        stop
      end if
!-----------------------------------------------------------------------
! Step 2: pegs5-call
!-----------------------------------------------------------------------
!     ---------------------------------
!     Define media before calling PEGS5
!     ---------------------------------
      write(6,*) "pegs5-call"
      flush(6)

      ph_use_file=.false.
      ph_bg_radius=1.0d0
      ph_cyl_y0=-0.75d0
      ph_cyl_dy=1.5d0
      ph_n_rcc=0
      ph_n_rpp=0
      ph_bg_med=2
      do i=1,MXMED
        ph_medarr(i)='                        '
        ph_chard(i)=0.05d0
        ph_insert_med(i)=2
      end do
      ph_rcc_cx=0.0d0; ph_rcc_cz=0.0d0; ph_rcc_r=0.0d0
      ph_rpp_x1=0.0d0; ph_rpp_x2=0.0d0
      ph_rpp_y1=0.0d0; ph_rpp_y2=0.0d0
      ph_rpp_z1=0.0d0; ph_rpp_z2=0.0d0

      open(60,FILE='phantom.nml',STATUS='old',IOSTAT=ios)
      if(ios.eq.0) then
        ios_geom=0
        ios_mat=0
        read(60,NML=GEOMETRY,IOSTAT=ios_geom)
        if(ios_geom.eq.0) then
          read(60,NML=MATERIALS,IOSTAT=ios_mat)
        end if
        close(60)
        if(ios_geom.eq.0 .and. ios_mat.eq.0) then
          ph_use_file=.true.
          nmed=ph_nmed
          do j=1,nmed
            medarr(j)=ph_medarr(j)
            chard(j)=ph_chard(j)
          end do
          write(6,*) 'Reading phantom config from phantom.nml'
          flush(6)
        else
          write(6,*) 'Failed to read phantom.nml, fallback to PAR_PNTM'
          write(6,*) ' GEOMETRY IOSTAT =',ios_geom,
     *               ' MATERIALS IOSTAT =',ios_mat
          flush(6)
          call configure_media_table(phantom,nmed,medarr,chard)
        end if
      else
        call configure_media_table(phantom,nmed,medarr,chard)
      end if
      if(nmed.gt.MXMED) then
        write(6,'(A,I4,A,I4,A/A)')
     *     ' nmed (',nmed,') larger than MXMED (',MXMED,')',
     *     ' MXMED in iclude/egs5_h.f must be increased.'
        flush(6)
        stop
      end if

!     ==============
      call block_set                 ! Initialize some general variables
!     ==============

      do j=1,nmed
        do i=1,24
          media(i,j)=medarr(j)(i:i)
        end do
      end do

      write(6,fmt="('chard =',5e12.5)") (chard(j),j=1,nmed)
      flush(6)

!     -----------------------------------
!     Run KEK PEGS5 before calling HATCH
!     -----------------------------------
      write(6,100)
100   FORMAT('PEGS5-call comes next'/)
      flush(6)

!     ==========
      !call pegs5
      call egs5mpi_pegscall
!     ==========


!-----------------------------------------------------------------------
! step 3-1: GEOM Generation
!-----------------------------------------------------------------------
      open(ifto_dummy,FILE='trash.'//rank_str//'.pic',STATUS='replace')

      !for counting time
      call system_clock(time_begin_c, CountPerSec, CountMax)



                                             ! -------------------------
      do stepi=initstep,haltstep-1!ctstep-1  ! Begining of Rotation loop
                                             ! -------------------------
      write(6,*) 'Read cg-related data'
      flush(6)
!-----------------------------------------------
!     Initialize CG related parameters
!-----------------------------------------------

      ctang=360e0/ctstep*stepi

      call chdir("./"//savepath)

      write (degfile,'(I3.3,F0.2,".",A,".csv")') int(ctang),
     *   ctang-int(ctang),rank_str
      flush(6)

      open(ifct,FILE=degfile,STATUS='replace')
      write (pictfile,'("egs5job",I0,".",A,".pic")') stepi,rank_str
      flush(6)
      open(ifto_original,FILE=pictfile,STATUS='replace')
      ncount = 0
      do i=1,maxch
        do j=1,maxtrans
          phs(i,j)=0.0
        end do
      end do

      call chdir("../")

!for MPI
      ! if(mpi_rank.eq.0) then
      !   write (mpi_degfile,'(I3.3,F0.2,".csv")') int(ctang),
      !  *   ctang-int(ctang)
      !   flush(6)
      !   open(mpi_ifct,FILE=mpi_degfile,STATUS='replace')
      !   do i=1,1000
      !     do j=1,150
      !       mpi_phs(i,j)=0.0
      !     end do
      !   end do
      ! end if



      write(6,*) 'Pre-calculation for CG data'
      flush(6)
!-----------------------------------------------
!     Pre-calculation for CG data
!-----------------------------------------------
      csrad=2*PI/ctstep*stepi !current angle
      xl=translation_pitch*cos(csrad)
      zl=translation_pitch*sin(csrad)

      !
      ! do transi=0,translation_times-1
      !
      open(ifti,FILE='egs5job.'//rank_str//'.inp',STATUS='replace')
      ! if(transi.eq.0) then
      !   ifto=ifto_original
      ! else
      !   ifto=ifto_dummy
      ! end if
      ifto = ifto_original
      nos=0        !Initialization for nos
      cti=1
      nor=1


      call write_detector_geometry(ifti,cti,geomkind,ctgeom,
     *  ctdisd,htl,ctx,cty,ctz,translation_times,xl,zl,
     *  csrad,halfosl)

      if(ph_use_file) then
        call write_phantom_geometry_cfg(ifti,cti,geomkind,ctgeom,nos,
     *    ph_bg_radius,ph_cyl_y0,ph_cyl_dy,
     *    ph_n_rcc,ph_rcc_cx,ph_rcc_cz,ph_rcc_r,
     *    ph_n_rpp,ph_rpp_x1,ph_rpp_x2,ph_rpp_y1,
     *    ph_rpp_y2,ph_rpp_z1,ph_rpp_z2)
      else
        call write_phantom_geometry(phantom,ifti,cti,geomkind,
     *    ctgeom,nos)
      end if

      call add_rpp(ifti,cti,geomkind,ctgeom,-(halfosl+1.0d0),
     *  halfosl+1.0d0,-(halfosl+1.0d0),halfosl+1.0d0,
     *  -(halfosl+1.0d0),halfosl+1.0d0)
      write(ifti,*) geomkind(GEOM_END)

      if(ph_use_file) then
        call write_zone_definitions_cfg(ifti,translation_times,nor,
     *    ph_bg_med,ph_n_rcc+ph_n_rpp)
        call write_media_assignment_cfg(ifti,translation_times,
     *    ph_bg_med,ph_n_rcc+ph_n_rpp,ph_insert_med)
      else
        call write_zone_definitions(ifti,phantom,translation_times,nor)
        call write_media_assignment(ifti,phantom,translation_times)
      end if
      close(unit=ifti)

!-----------------------------------------------------------
!Read CG data from generated egs5job.inp
!-----------------------------------------------------------
      write(6,*) "read CG"
      flush(6)
      open(ifti,FILE='egs5job.'//rank_str//'.inp',STATUS='old')
      write(6,fmt="(' CG data')")
      call geomgt(ifti,6)  ! Read in CG data
      write(6,fmt="(' End of CG data',/)")
      rewind ifti
      if(npreci.eq.3) write(ifto,fmt="('CSTA-FREE-TIME')")
      if(npreci.eq.2) write(ifto,fmt="('CSTA-TIME')")
      call geomgt(ifti,ifto)! Dummy call to write geom info for ifto
      write(ifto,170)
170   FORMAT('CEND')
      !--------------------------------
      !     Get nreg from cg input data
      !--------------------------------
      nreg=izonin
      !Read material for each region from egs5job.inp
      read(ifti,*) (med(i),i=1,nreg)
      !Set option except vacuum region
      do i=1,nreg-1
        if(med(i).ne.0) then
          iphter(i) = 0    ! Switches for PE-angle sampling
          iraylr(i) = 1    ! Rayleigh scattering
          iedgfl(i) = 1    ! K & L-edge fluorescence
          iauger(i) = 1    ! K & L-Auger
          lpolar(i) = 1    ! Linearly-polarized photon scattering
          incohr(i) = 1    ! S/Z rejection
          iprofr(i) = 1    ! Doppler broadening
          impacr(i) = 1    ! Electron impact ionization
        end if
      end do
      write(ifto,fmt="('MSTA')")
      write(ifto,fmt="(i4)") nreg
      write(ifto,fmt="(15i4)") (med(i),i=1,nreg)
      write(ifto,fmt="('MEND')")
      close(unit=ifti)

!     --------------------------------------------------------
!     Random number seeds.  Must be defined before call hatch
!     or defaults will be used.  inseed (1- 2^31)
!     --------------------------------------------------------
      luxlev = 1
      inseed=2
      write(6,180) inseed
180   FORMAT(/,' inseed=',I12,5X,
     *   ' (seed for generating unique sequences of Ranlux)')
      flush(6)


!     --------------------------------------------------------
!     Random number seeds.  Must be defined before call hatch
!     or defaults will be used.  inseed (1- 2^31)
!     --------------------------------------------------------
      luxlev = 1
      mpi_mainseed=1


!     =====================
	!call rluxinit
      call egs5mpi_rluxinit  ! Initialize the Ranlux random-number generator
!     =====================

!-----------------------------------------------------------------------
! step 3-2:  Determination-of-incident-particle-parameters
!-----------------------------------------------------------------------
! Define initial variables for incident particle
      iqin=0             ! Incident particle charge - photons
      xin=-ctdiss*sin(csrad)!+htl*cos(csrad)-transi*xl ! Source position
      !xin=-ctdis*sin(csrad)+htl*cos(csrad)*rnnow ! Source position
      yin=0.0d0
      zin=-ctdiss*cos(csrad)!-htl*sin(csrad)*rnnow
      uin=sin(csrad)
      vin=0
      win=cos(csrad)
      irin=0             ! Starting region (0: Automatic search in CG)
      wtin=1.0           ! Weight = 1 since no variance reduction used

	ncases= totalcases / mpi_size + 1
!-----------------------------------------
!     Get source region from cg input data
!-----------------------------------------
      if(irin.le.0.or.irin.gt.nreg) then
        call srzone(xin,yin,zin,iqin+2,0,irin)
        if(irin.le.0.or.irin.ge.nreg) then
          write(6,fmt="(' Stopped in MAIN. irin = ',i5)")irin
          flush(6)
          stop
        end if
        call rstnxt(iqin+2,0,irin)
      end if
!-----------------------------------------------------------------------
! step 3-3:   hatch-call
!-----------------------------------------------------------------------
      emaxe = 0.D0 ! dummy value to extract min(UE,UP+RM).
      write(6,190)
190   format(/' Call hatch to get cross-section data')
      flush(6)
!     ------------------------------
!     Open files (before HATCH call)
!     ------------------------------
      open(UNIT=KMPI,FILE='pgs5job.pegs5dat',
     *   STATUS='old')
      open(UNIT=KMPO,FILE='egs5job.'//rank_str//'.dummy',
     *   STATUS='unknown')
      write(6,200)
200   FORMAT(/,' HATCH-call comes next',/)
      flush(6)
!     ==========
      call hatch
!     ==========
!     ------------------------------
!     Close files (after HATCH call)
!     ------------------------------
      close(UNIT=KMPI)
      close(UNIT=KMPO)
      iblock=0
!-----------------------------------------------------------------------
! step 3-4:  Initialization-for-ausgab
!-----------------------------------------------------------------------
      ilines = 0
      nwrite = 10
      nlines = 10
      idin = -1
      totke = 0.
      wtsum = 0.
!     =========================
      call ecnsv1(0,nreg,totke)
      call ntally(0,nreg)
!     =========================
      write(6,210)
210   FORMAT(//,' Energy/Coordinates/Direction cosines/etc.',/,
     *        6X,'e',14X,'x',14X,'y',14X,'z',
     *        14X,'u',14X,'v',14X,'w',11X,'iq',3X,'ir',1X,'iarg',/)
      flush(6)
      tt=etime(tarray)
      tt0=tarray(1)
!-----------------------------------------------------------------------
! step 3-5:  Shower-call
!-----------------------------------------------------------------------
!     Write batch number
      write(ifto,fmt="('0    1')")
                                              ! -------------------------
      do i=1,ncases                           ! Start of shower call-loop
                                              ! -------------------------
!       ----------------------
!       Select incident energy
!       ----------------------
        call randomset(rnnow)

        do cti=1,apch
          if(rnnow.le.crt(2,cti)) then
            ekein=crt(1,cti)/1000
            exit
          end if
        end do

!       ----------------------
!       Select source position (for Parallel beam)
!       ----------------------
        if(beam.eq.0) then
          call randomset(rnnow)

          xin=-ctdiss*sin(csrad)+htl*cos(csrad)*(2 * rnnow - 1) ! Source position
          yin=0.0d0
          zin=-ctdiss*cos(csrad)-htl*sin(csrad)*(2 * rnnow - 1)
        end if

!       ----------------------
!       Select source angle (for Fan beam)
!       ----------------------
        if(beam.eq.1) then
          call randomset(rnnow)

          theta_rnd=translation_pitch*translation_times
     *        /(2*(ctdiss + ctdisd))
          uin=sin(csrad+(2*rnnow-1)*atan(theta_rnd))
          vin=0
          win=cos(csrad+(2*rnnow-1)*atan(theta_rnd))
        end if

!       ---------------------
!       calculation of totke
!       ---------------------
        wtin = 1.0
        wtsum = wtsum + wtin               ! Keep running sum of weights
        etot = ekein + iabs(iqin)*RM        ! Incident total energy (MeV)
        if(iqin.eq.1) then              ! Available K.E. (MeV) in system
          availke = ekein + 2.0*RM       ! for positron
        else                            ! Available K.E. (MeV) in system
          availke = ekein                ! for photon and electron
        end if
        totke = totke + availke                 ! Keep running sum of KE
!       ---------------------------------------------------
!       Print first NWRITE or NLINES, whichever comes first
!       ---------------------------------------------------
        if (ncount .le. nwrite .and. ilines .le. nlines) then
          ilines = ilines + 1
          write(6,220) etot,xin,yin,zin,uin,vin,win,iqin,irin,idin
220       FORMAT(7G15.7,3I5)
        end if
!       -----------------------------------------------------------
!       Compare maximum energy of material data and incident energy
!       -----------------------------------------------------------
        if(etot+(1-iabs(iqin))*RM.gt.emaxe) then
          write(6,fmt="(' Stopped in MAIN.',
     1    ' (Incident kinetic energy + RM) > min(UE,UP+RM).')")
          stop
        end if
!       ----------------------------------------------------
!       Verify the normalization of source direction cosines
!       ----------------------------------------------------
        if(abs(uin*uin+vin*vin+win*win-1.0).gt.1.e-6) then
          write(6,fmt="(' Following source direction cosines are not',
     1    ' normalized.',3e12.5)")uin,vin,win
          stop
        end if
        uf(1)=0.0
        vf(1)=0.0
        wf(1)=0.0  ! Needed if lpolar(i)=1
!       ==========================================================
        call shower (iqin,etot,xin,yin,zin,uin,vin,win,irin,wtin)
!       ==========================================================
!       If some energy is deposited inside detector add pulse-height
!       and efficiency.
        do l=1,translation_times
          if (depe(l).gt.0.D0) then
            if (depe(l).lt.(offset+deltae/2)) then
              ie = 1
            else
              ie = (depe(l)-(offset+deltae/2))/deltae+2
            end if
  !         Uncomment to display deposited energy
  !          write(6,*) "ie:", ie, "   depe:", depe
  !          flush(6)
            phs(ie,l)=phs(ie,l)+wtin
            depe(l)=0.D0
          end if
        end do

        ncount = ncount + 1         ! Count total number of actual cases
                                             ! -----------------------
      end do                                 ! End of CALL SHOWER loop
                                             ! -----------------------
      nlist=2   !Output from ecnsv1,ntally are suppressed
!     =============================
      call ecnsv1(nlist,nreg,totke)
      call ntally(nlist,nreg)
      call counters_out(1)
      call block_set
!     ====================
      !                                        ! -----------------------
      ! end do                                 ! End of Translation loop
      !                                        ! -----------------------
      call plotxyz(99,0,0,0.D0,0.D0,0.D0,0.D0,0,0.D0,0.D0) !Output bufferd plot data
      write(ifto_original,fmt="('9')")          ! Set end of batch for CG View
      tt=etime(tarray)
      tt1=tarray(1)
      cputime=tt1-tt0
      write(6,230) cputime
230   format(' Elapsed Time (sec)=',G15.5)
!-----------------------------------------------------------------------
! Step 4:  Output-of-results
!-----------------------------------------------------------------------
      write(6,240) ncount,ncases,totke
240   FORMAT(/,' Ncount=',I10,' (actual cases run)',/,
     *       ' Ncases=',I10,' (number of cases requested)',/,
     *       ' TotKE =',G15.5,' (total KE (MeV) in run)')

      if (totke .le. 0.D0) then
        write(6,250) totke,availke,ncount
250     FORMAT(//,' Stopped in MAIN with TotKE=',G15.5,/,
     *         ' AvailKE=',G15.5, /,' Ncount=',I10)
        stop
      end if
!     --------------------------
!     Pulse height distribution
!     --------------------------
      write(6,260)
260   FORMAT(/' Pulse height distribution ')
270   FORMAT(I5,',')
      do ie=1,maxch
        do cti=1,translation_times-1
          write(ifct,270,advance='no') phs(ie,cti)
        end do
        write(ifct,*) phs(ie,cti)
      end do
      close(unit=ifct)
      close(unit=ifto_original)

                                             ! --------------------
      end do                                 ! End of Rotation loop
                                             ! --------------------




      !for counting time
      call system_clock(time_end_c)
      print *,time_begin_c,time_end_c, CountPerSec,CountMax
      print *,real(time_end_c - time_begin_c)/CountPerSec,"sec"

      close(unit=ifto_dummy)

!--------------------------
!     EGS5-MPI FINALIZE
!--------------------------
      call egs5mpi_finalize

      stop
      end
!-------------------------last line of main code------------------------
!-------------------------geometry helper code--------------------------

      subroutine write_phantom_geometry_cfg(ifti,cti,geomkind,ctgeom,
     * nos,bg_radius,cyl_y0,cyl_dy,
     * n_rcc,rcc_cx,rcc_cz,rcc_r,
     * n_rpp,rpp_x1,rpp_x2,rpp_y1,rpp_y2,rpp_z1,rpp_z2)
      implicit none
      integer ifti,cti,nos,n_rcc,n_rpp,i
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 bg_radius,cyl_y0,cyl_dy
      real*8 rcc_cx(*),rcc_cz(*),rcc_r(*)
      real*8 rpp_x1(*),rpp_x2(*),rpp_y1(*),rpp_y2(*),rpp_z1(*),rpp_z2(*)

      nos=0
      if(bg_radius.gt.0.0d0) then
        call add_rcc(ifti,cti,geomkind,ctgeom,
     *    0.d0,cyl_y0,0.d0,0.d0,cyl_dy,0.d0,bg_radius)
        nos=nos+1
      end if
      do i=1,n_rcc
        call add_rcc(ifti,cti,geomkind,ctgeom,
     *    rcc_cx(i),cyl_y0,rcc_cz(i),0.d0,cyl_dy,0.d0,rcc_r(i))
        nos=nos+1
      end do
      do i=1,n_rpp
        call add_rpp(ifti,cti,geomkind,ctgeom,
     *    rpp_x1(i),rpp_x2(i),rpp_y1(i),rpp_y2(i),rpp_z1(i),rpp_z2(i))
        nos=nos+1
      end do

      return
      end

      subroutine write_zone_definitions_cfg(ifti,translation_times,
     * nor,bg_med,n_inserts)
      implicit none
      integer ifti,translation_times,nor,bg_med,n_inserts
      integer sample_body_start,end_body_id,transi,i,n_sample_zones

120   FORMAT('Z',I0.4,' +',I0)
130   FORMAT('Z',I0.4,' +',I0)
140   FORMAT(' -',I0)
150   FORMAT('Z',I0.4,' +',I0,' -',I0)

      do transi=0,translation_times-1
        write(ifti,120) nor,nor+1
        nor=nor+1
      end do

      sample_body_start=translation_times+3

      if(bg_med.eq.0) then
        n_sample_zones=n_inserts
        write(ifti,130,advance='no') nor,nor+1
        write(ifti,140,advance='no') 1
        do i=0,n_inserts-1
          if(i.lt.n_inserts-1) then
            write(ifti,140,advance='no') sample_body_start+i
          else
            write(ifti,140) sample_body_start+i
          end if
        end do
        nor=nor+1
        do i=0,n_inserts-1
          write(ifti,130) nor,sample_body_start+i
          nor=nor+1
        end do
      else
        n_sample_zones=n_inserts+1
        write(ifti,130,advance='no') nor,nor+1
        write(ifti,140,advance='no') 1
        write(ifti,140) sample_body_start
        nor=nor+1
        if(n_inserts.eq.0) then
          write(ifti,130) nor,sample_body_start
          nor=nor+1
        else
          write(ifti,130,advance='no') nor,sample_body_start
          do i=1,n_inserts
            if(i.lt.n_inserts) then
              write(ifti,140,advance='no') sample_body_start+i
            else
              write(ifti,140) sample_body_start+i
            end if
          end do
          nor=nor+1
          do i=1,n_inserts
            write(ifti,130) nor,sample_body_start+i
            nor=nor+1
          end do
        end if
      end if

      end_body_id=sample_body_start+n_sample_zones
      write(ifti,150) nor,end_body_id,translation_times+2
      write(ifti,*) 'END'

      return
      end

      subroutine write_media_assignment_cfg(ifti,translation_times,
     * bg_med,n_inserts,insert_med)
      implicit none
      integer ifti,translation_times,bg_med,n_inserts
      integer insert_med(*)
      integer transi,i

      do transi=0,translation_times-1
        write(ifti,fmt='(a)',advance='no') ' 1'
      end do
      write(ifti,fmt='(a)',advance='no') ' 2'
      if(bg_med.gt.0) then
        write(ifti,fmt='(I2)',advance='no') bg_med
      end if
      do i=1,n_inserts
        write(ifti,fmt='(I2)',advance='no') insert_med(i)
      end do
      write(ifti,fmt='(I2)') 0

      return
      end

      subroutine configure_media_table(phantom,nmed,medarr,chard)
      implicit none
      integer phantom,nmed,i
      integer,parameter :: PHANTOM_FOUR_METAL = 3
      integer,parameter :: PHANTOM_FOUR_METAL_TEST = 4
      integer,parameter :: PHANTOM_FOUR_TISSUES = 5
      integer,parameter :: PHANTOM_SQUARE = 8
      integer,parameter :: PHANTOM_SQUARE2 = 9
      character*24 medarr(*)
      real*8 chard(*)

      do i=1,9
        medarr(i)='                        '
        chard(i)=0.05d0
      end do

      medarr(1)='CDTE                    '
      medarr(2)='AIR-AT-NTP              '

      if(phantom.eq.PHANTOM_FOUR_METAL .or.
     *   phantom.eq.PHANTOM_FOUR_METAL_TEST) then
        nmed=7
        medarr(3)='AL                      '
        medarr(4)='CU                      '
        medarr(5)='TI                      '
        medarr(6)='C                       '
        medarr(7)='H2O                     '
      else if(phantom.eq.PHANTOM_FOUR_TISSUES .or.
     *        phantom.eq.PHANTOM_SQUARE .or.
     *        phantom.eq.PHANTOM_SQUARE2) then
        nmed=9
        medarr(3)='AL                      '
        medarr(4)='PMMA                    '
        medarr(5)='H2O                     '
        medarr(6)='PVC                     '
        medarr(7)='PLA                     '
        medarr(8)='C                       '
        medarr(9)='ABS                     '
      else
        nmed=7
        medarr(3)='AL                      '
        medarr(4)='PMMA                    '
        medarr(5)='H2O                     '
        medarr(6)='PVC                     '
        medarr(7)='TI                      '
      end if

      chard(1)=0.01d0
      if(phantom.eq.PHANTOM_SQUARE2) then
        chard(4)=0.0005d0
      end if

      return
      end

      subroutine write_detector_geometry(ifti,cti,geomkind,ctgeom,
     * ctdisd,htl,ctx,cty,ctz,translation_times,xl,zl,
     * csrad,halfosl)
      implicit none
      integer ifti,cti,translation_times,transi
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 ctdisd,htl,ctx,cty,ctz,xl,zl,csrad,halfosl

      call add_box(ifti,cti,geomkind,ctgeom,
     *  ctdisd*sin(csrad)+(htl+ctx/2.d0)*cos(csrad),
     *  -cty/2.d0,
     *  ctdisd*cos(csrad)-(htl+ctx/2.d0)*sin(csrad),
     *  -ctx*cos(csrad)*translation_times,
     *  0.d0,
     *  ctx*sin(csrad)*translation_times,
     *  0.d0,cty,0.d0,ctz*sin(csrad),0.d0,ctz*cos(csrad))

      do transi=0,translation_times-1
        call add_box(ifti,cti,geomkind,ctgeom,
     *   ctdisd*sin(csrad)+(htl+ctx/2.d0)*cos(csrad)-transi*xl,
     *   -cty/2.d0,
     *   ctdisd*cos(csrad)-(htl+ctx/2.d0)*sin(csrad)+transi*zl,
     *   -ctx*cos(csrad),0.d0,ctx*sin(csrad),
     *   0.d0,cty,0.d0,ctz*sin(csrad),0.d0,ctz*cos(csrad))
      end do

      call add_rpp(ifti,cti,geomkind,ctgeom,-halfosl,halfosl,
     * -halfosl,halfosl,-halfosl,halfosl)

      return
      end

      subroutine write_phantom_geometry(phantom,ifti,cti,geomkind,
     * ctgeom,nos)
      implicit none
      integer phantom,ifti,cti,nos
      integer,parameter :: PHANTOM_ONION = 0
      integer,parameter :: PHANTOM_TISSUE = 1
      integer,parameter :: PHANTOM_METAL = 2
      integer,parameter :: PHANTOM_FOUR_METAL = 3
      integer,parameter :: PHANTOM_FOUR_METAL_TEST = 4
      integer,parameter :: PHANTOM_FOUR_TISSUES = 5
      integer,parameter :: PHANTOM_SMALL = 6
      integer,parameter :: PHANTOM_SMALL_FOUR = 7
      integer,parameter :: PHANTOM_SQUARE = 8
      integer,parameter :: PHANTOM_SQUARE2 = 9
      character*3 geomkind(*)
      real ctgeom(30,*)

      if(phantom.eq.PHANTOM_ONION) then
        call build_single_rod_phantom(ifti,cti,geomkind,ctgeom,nos)
      else if(phantom.eq.PHANTOM_TISSUE .or.
     *        phantom.eq.PHANTOM_METAL) then
        call build_two_rods_phantom(ifti,cti,geomkind,ctgeom,nos)
      else if(phantom.eq.PHANTOM_FOUR_METAL .or.
     *        phantom.eq.PHANTOM_FOUR_METAL_TEST .or.
     *        phantom.eq.PHANTOM_FOUR_TISSUES) then
        call build_four_rods_phantom(ifti,cti,geomkind,ctgeom,nos)
      else if(phantom.eq.PHANTOM_SMALL) then
        call build_small_single_rod_phantom(ifti,cti,geomkind,
     *   ctgeom,nos)
      else if(phantom.eq.PHANTOM_SMALL_FOUR) then
        call build_small_four_rods_phantom(ifti,cti,geomkind,
     *   ctgeom,nos)
      else if(phantom.eq.PHANTOM_SQUARE) then
        call build_square_phantom(ifti,cti,geomkind,ctgeom,nos)
      else if(phantom.eq.PHANTOM_SQUARE2) then
        call build_square2_phantom(ifti,cti,geomkind,ctgeom,nos)
      else
        nos=0
      end if

      return
      end

      subroutine build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     * bg_radius,nrod,rod_x,rod_z,rod_r,nos)
      implicit none
      integer ifti,cti,nrod,nos,i
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 bg_radius,rod_x(*),rod_z(*),rod_r(*)
      real*8 cyl_y0,cyl_dy

      cyl_y0=-0.75d0
      cyl_dy=1.5d0
      call add_rcc(ifti,cti,geomkind,ctgeom,
     *  0.d0,cyl_y0,0.d0,0.d0,cyl_dy,0.d0,bg_radius)

      do i=1,nrod
        call add_rcc(ifti,cti,geomkind,ctgeom,
     *   rod_x(i),cyl_y0,rod_z(i),0.d0,cyl_dy,0.d0,rod_r(i))
      end do

      nos=nrod+1
      return
      end

      subroutine build_single_rod_phantom(ifti,cti,geomkind,ctgeom,
     * nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 rod_x(1),rod_z(1),rod_r(1)

      rod_x(1)=0.d0
      rod_z(1)=0.d0
      rod_r(1)=0.d0
      call build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     *  0.15d0,0,rod_x,rod_z,rod_r,nos)

      return
      end

      subroutine build_two_rods_phantom(ifti,cti,geomkind,ctgeom,nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 rod_x(2),rod_z(2),rod_r(2)

      rod_x(1)=0.5d0
      rod_x(2)=-0.5d0
      rod_z(1)=0.d0
      rod_z(2)=0.d0
      rod_r(1)=0.25d0
      rod_r(2)=0.25d0
      call build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     *  1.0d0,2,rod_x,rod_z,rod_r,nos)

      return
      end

      subroutine build_four_rods_phantom(ifti,cti,geomkind,ctgeom,
     * nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 rod_x(4),rod_z(4),rod_r(4)

      rod_x(1)=0.5d0
      rod_x(2)=0.d0
      rod_x(3)=-0.5d0
      rod_x(4)=0.d0
      rod_z(1)=0.d0
      rod_z(2)=0.5d0
      rod_z(3)=0.d0
      rod_z(4)=-0.5d0
      rod_r(1)=0.15d0
      rod_r(2)=0.15d0
      rod_r(3)=0.15d0
      rod_r(4)=0.15d0
      call build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     *  1.0d0,4,rod_x,rod_z,rod_r,nos)

      return
      end

      subroutine build_small_single_rod_phantom(ifti,cti,geomkind,
     * ctgeom,nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 rod_x(1),rod_z(1),rod_r(1)

      rod_x(1)=0.d0
      rod_z(1)=0.d0
      rod_r(1)=0.075d0
      call build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     *  0.25d0,1,rod_x,rod_z,rod_r,nos)

      return
      end

      subroutine build_small_four_rods_phantom(ifti,cti,geomkind,
     * ctgeom,nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 rod_x(4),rod_z(4),rod_r(4)

      rod_x(1)=0.125d0
      rod_x(2)=0.d0
      rod_x(3)=-0.125d0
      rod_x(4)=0.d0
      rod_z(1)=0.d0
      rod_z(2)=0.125d0
      rod_z(3)=0.d0
      rod_z(4)=-0.125d0
      rod_r(1)=0.05d0
      rod_r(2)=0.05d0
      rod_r(3)=0.05d0
      rod_r(4)=0.05d0
      call build_cylindrical_phantom(ifti,cti,geomkind,ctgeom,
     *  0.25d0,4,rod_x,rod_z,rod_r,nos)

      return
      end

      subroutine build_square_phantom(ifti,cti,geomkind,ctgeom,nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)

      call add_rcc(ifti,cti,geomkind,ctgeom,
     *  0.d0,-0.75d0,0.d0,0.d0,1.5d0,0.d0,0.7d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  0.1d0,0.5d0,-0.75d0,0.75d0,-0.4d0,-0.1d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  0.1d0,0.5d0,-0.75d0,0.75d0,0.1d0,0.4d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.5d0,-0.1d0,-0.75d0,0.75d0,0.1d0,0.4d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.5d0,-0.1d0,-0.75d0,0.75d0,-0.4d0,-0.1d0)
      nos=5

      return
      end

      subroutine build_square2_phantom(ifti,cti,geomkind,ctgeom,nos)
      implicit none
      integer ifti,cti,nos
      character*3 geomkind(*)
      real ctgeom(30,*)

      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.15d0,0.35d0,-0.75d0,0.75d0,0.d0,0.4d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.25d0,-0.2d0,-0.75d0,0.75d0,-0.4d0,0.4d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.325d0,-0.3d0,-0.75d0,0.75d0,-0.4d0,0.4d0)
      call add_rpp(ifti,cti,geomkind,ctgeom,
     *  -0.4125d0,-0.4d0,-0.75d0,0.75d0,-0.4d0,0.4d0)
      nos=4

      return
      end

      subroutine get_sample_media_sequence(phantom,media_ids,nmedia)
      implicit none
      integer phantom,nmedia
      integer media_ids(*)
      integer i
      integer,parameter :: PHANTOM_ONION = 0
      integer,parameter :: PHANTOM_TISSUE = 1
      integer,parameter :: PHANTOM_METAL = 2
      integer,parameter :: PHANTOM_FOUR_METAL = 3
      integer,parameter :: PHANTOM_FOUR_METAL_TEST = 4
      integer,parameter :: PHANTOM_FOUR_TISSUES = 5
      integer,parameter :: PHANTOM_SMALL = 6
      integer,parameter :: PHANTOM_SMALL_FOUR = 7
      integer,parameter :: PHANTOM_SQUARE = 8
      integer,parameter :: PHANTOM_SQUARE2 = 9

      do i=1,5
        media_ids(i)=0
      end do

      if(phantom.eq.PHANTOM_ONION) then
        nmedia=1
        media_ids(1)=5
      else if(phantom.eq.PHANTOM_TISSUE) then
        nmedia=3
        media_ids(1)=4
        media_ids(2)=6
        media_ids(3)=5
      else if(phantom.eq.PHANTOM_METAL) then
        nmedia=3
        media_ids(1)=4
        media_ids(2)=3
        media_ids(3)=7
      else if(phantom.eq.PHANTOM_FOUR_METAL) then
        nmedia=5
        media_ids(1)=3
        media_ids(2)=3
        media_ids(3)=6
        media_ids(4)=5
        media_ids(5)=4
      else if(phantom.eq.PHANTOM_FOUR_METAL_TEST) then
        nmedia=5
        media_ids(1)=2
        media_ids(2)=2
        media_ids(3)=2
        media_ids(4)=2
        media_ids(5)=2
      else if(phantom.eq.PHANTOM_FOUR_TISSUES .or.
     *        phantom.eq.PHANTOM_SQUARE) then
        nmedia=5
        media_ids(1)=4
        media_ids(2)=2
        media_ids(3)=5
        media_ids(4)=7
        media_ids(5)=9
      else if(phantom.eq.PHANTOM_SMALL) then
        nmedia=2
        media_ids(1)=6
        media_ids(2)=5
      else if(phantom.eq.PHANTOM_SMALL_FOUR) then
        nmedia=5
        media_ids(1)=6
        media_ids(2)=2
        media_ids(3)=3
        media_ids(4)=4
        media_ids(5)=5
      else if(phantom.eq.PHANTOM_SQUARE2) then
        nmedia=4
        media_ids(1)=4
        media_ids(2)=4
        media_ids(3)=4
        media_ids(4)=4
      else
        nmedia=0
      end if

      return
      end

      subroutine write_zone_definitions(ifti,phantom,translation_times,
     * nor)
      implicit none
      integer ifti,phantom,translation_times,nor
      integer sample_media_ids(5),nsample
      integer sample_body_start,end_body_id,transi,i
      integer,parameter :: PHANTOM_SQUARE2 = 9

120   FORMAT('Z',I0.4,' +',I0)
130   FORMAT('Z',I0.4,' +',I0)
140   FORMAT(' -',I0)
150   FORMAT('Z',I0.4,' +',I0,' -',I0)

      call get_sample_media_sequence(phantom,sample_media_ids,nsample)

      do transi=0,translation_times-1
        write(ifti,120) nor,nor+1
        nor=nor+1
      end do

      sample_body_start=translation_times+3
      write(ifti,130,advance='no') nor,nor+1
      write(ifti,140,advance='no') 1
      if(phantom.eq.PHANTOM_SQUARE2) then
        do i=0,nsample-1
          if(i.lt.nsample-1) then
            write(ifti,140,advance='no') sample_body_start+i
          else
            write(ifti,140) sample_body_start+i
          end if
        end do
      else
        write(ifti,140) sample_body_start
      end if
      nor=nor+1

      if(phantom.eq.PHANTOM_SQUARE2) then
        do i=0,nsample-1
          write(ifti,130) nor,sample_body_start+i
          nor=nor+1
        end do
      else if(nsample.eq.1) then
        write(ifti,130) nor,sample_body_start
        nor=nor+1
      else
        write(ifti,130,advance='no') nor,sample_body_start
        do i=1,nsample-1
          if(i.lt.nsample-1) then
            write(ifti,140,advance='no') sample_body_start+i
          else
            write(ifti,140) sample_body_start+i
          end if
        end do
        nor=nor+1
        do i=1,nsample-1
          write(ifti,130) nor,sample_body_start+i
          nor=nor+1
        end do
      end if

      end_body_id=sample_body_start+nsample
      write(ifti,150) nor,end_body_id,translation_times+2
      write(ifti,*) 'END'

      return
      end

      subroutine write_media_assignment(ifti,phantom,translation_times)
      implicit none
      integer ifti,phantom,translation_times
      integer sample_media_ids(5),nsample,transi,i

      call get_sample_media_sequence(phantom,sample_media_ids,nsample)

      do transi=0,translation_times-1
        write(ifti,fmt='(a)',advance='no') ' 1'
      end do
      write(ifti,fmt='(a)',advance='no') ' 2'
      do i=1,nsample
        write(ifti,fmt='(I2)',advance='no') sample_media_ids(i)
      end do
      write(ifti,fmt='(I2)') 0

      return
      end

      subroutine add_box(ifti,cti,geomkind,ctgeom,
     * x0,y0,z0,ax,ay,az,bx,by,bz,cx,cy,cz)
      implicit none
      integer ifti,cti,i
      integer,parameter :: GEOM_BOX = 6
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 x0,y0,z0,ax,ay,az,bx,by,bz,cx,cy,cz

      ctgeom(1,cti)=x0
      ctgeom(2,cti)=y0
      ctgeom(3,cti)=z0
      ctgeom(4,cti)=ax
      ctgeom(5,cti)=ay
      ctgeom(6,cti)=az
      ctgeom(7,cti)=bx
      ctgeom(8,cti)=by
      ctgeom(9,cti)=bz
      ctgeom(10,cti)=cx
      ctgeom(11,cti)=cy
      ctgeom(12,cti)=cz
      write(ifti,*) geomkind(GEOM_BOX),cti,(ctgeom(i,cti),i=1,12)
      cti=cti+1

      return
      end

      subroutine add_rcc(ifti,cti,geomkind,ctgeom,
     * x0,y0,z0,ax,ay,az,radius)
      implicit none
      integer ifti,cti,i
      integer,parameter :: GEOM_RCC = 2
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 x0,y0,z0,ax,ay,az,radius

      ctgeom(1,cti)=x0
      ctgeom(2,cti)=y0
      ctgeom(3,cti)=z0
      ctgeom(4,cti)=ax
      ctgeom(5,cti)=ay
      ctgeom(6,cti)=az
      ctgeom(7,cti)=radius
      write(ifti,*) geomkind(GEOM_RCC),cti,(ctgeom(i,cti),i=1,7)
      cti=cti+1

      return
      end

      subroutine add_rpp(ifti,cti,geomkind,ctgeom,
     * xmin,xmax,ymin,ymax,zmin,zmax)
      implicit none
      integer ifti,cti,i
      integer,parameter :: GEOM_RPP = 1
      character*3 geomkind(*)
      real ctgeom(30,*)
      real*8 xmin,xmax,ymin,ymax,zmin,zmax

      ctgeom(1,cti)=xmin
      ctgeom(2,cti)=xmax
      ctgeom(3,cti)=ymin
      ctgeom(4,cti)=ymax
      ctgeom(5,cti)=zmin
      ctgeom(6,cti)=zmax
      write(ifti,*) geomkind(GEOM_RPP),cti,(ctgeom(i,cti),i=1,6)
      cti=cti+1

      return
      end

!---------------------last line of geometry helper code-----------------
!-------------------------------ausgab.f--------------------------------
! Version:   080708-1600
! Reference: SLAC-265 (p.19-20, Appendix 2)
!-----------------------------------------------------------------------
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12

! ----------------------------------------------------------------------
! Required subroutine for use with the EGS5 Code System
! ----------------------------------------------------------------------
! A AUSGAB to:
!
!   1) Score energy deposition
!   2) Score particle information enter to detector from outside
!   3) Print out particle transport information
!   4) call plotxyz if imode=0

! ----------------------------------------------------------------------

      subroutine ausgab(iarg)
      implicit none

      include 'include/egs5_h.f'                ! Main EGS "header" file

      include 'include/egs5_epcont.f'    ! COMMONs required by EGS5 code
      include 'include/egs5_misc.f'
      include 'include/egs5_stack.f'
      include 'include/egs5_useful.f'
      include 'auxcommons/aux_h.f'   ! Auxiliary-code "header" file
      include 'auxcommons/etaly1.f'        ! Auxiliary-code COMMONs
      include 'auxcommons/lines.f'
      include 'auxcommons/ntaly1.f'
      include 'auxcommons/watch.f'
      common/totals/depe(4096),deltae,maxpict    ! Variables to score
      real*8 depe,deltae,spec,edepwt
      integer maxpict,iarg,ie,iql,irl,ntype

!     ------------------------
!     Set some local variables
!     ------------------------
      irl = ir(np)
      iql = iq(np)
      edepwt = edep*wt(np)

!     -----------------------------------------------------------
!     Keep track of energy deposition (for conservation purposes)
!     -----------------------------------------------------------
      if (iarg .lt. 5) then
        esum(iql+2,irl,iarg+1) = esum(iql+2,irl,iarg+1) + edepwt
        nsum(iql+2,irl,iarg+1) = nsum(iql+2,irl,iarg+1) + 1
      end if

!     -----------------------------------------------------------------
!     Print out particle transport information (if switch is turned on)
!     -----------------------------------------------------------------
      if(iarg .ge. 5) return

!     ----------------------------------------------
!     Score energy deposition inside CdTe detector
!     ----------------------------------------------
      if (med(irl) .eq. 1) then
        depe(irl) = depe(irl) + edepwt
      end if

!     ----------------------------------------------------------------
!     Print out stack information (for limited number cases and lines)
!     ----------------------------------------------------------------
      if (ncount .le. nwrite .and. ilines .le. nlines) then
        ilines = ilines + 1
        write(6,100) e(np),x(np),y(np),z(np),u(np),v(np),w(np),
     *               iql,irl,iarg
 100    FORMAT(7G15.7,3I5)
      end if

!     ------------------------------------
!     Output particle information for plot
!     ------------------------------------
!     if (transi.eq.0.and.ncount.le.maxpict) then
      if (ncount.le.maxpict) then
        call plotxyz(iarg,np,iq(np),x(np),y(np),z(np),e(np),ir(np),
     *       wt(np),time(np))
      end if

      return

      end
!--------------------------last line of ausgab.f------------------------
!-------------------------------howfar.f--------------------------------
! Version:   070627-1600
! Reference: T. Torii and T. Sugita, "Development of PRESTA-CG
! Incorporating Combinatorial Geometry in EGS4/PRESTA", JNC TN1410 2002-201,
! Japan Nuclear Cycle Development Institute (2002).
! Improved version is provided by T. Sugita. 7/27/2004
!-----------------------------------------------------------------------
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12

! ----------------------------------------------------------------------
! Required (geometry) subroutine for use with the EGS5 Code System
! ----------------------------------------------------------------------
! This is a CG-HOWFAR.
! ----------------------------------------------------------------------

      subroutine howfar
      implicit none
c
      include 'include/egs5_h.f'       ! Main EGS "header" file
      include 'include/egs5_epcont.f'  ! COMMONs required by EGS5 code
      include 'include/egs5_stack.f'
      include 'auxcommons/geom_common.f' ! geom-common file
c
c
      integer i,j,jjj,ir_np,nozone,jty,kno
      integer irnear,irnext,irlold,irlfg,itvlfg,ihitcg
      double precision xidd,yidd,zidd,x_np,y_np,z_np,u_np,v_np,w_np
      double precision tval,tval0,tval00,tval10,tvalmn,delhow
      double precision atvaltmp
      integer iq_np
c
      ir_np = ir(np)
      iq_np = iq(np) + 2
c
      if(ir_np.le.0) then
        write(6,*) 'Stopped in howfar with ir(np) <=0'
        stop
      end if
c
      if(ir_np.gt.izonin) then
        write(6,*) 'Stopped in howfar with ir(np) > izonin'
        stop
      end if
c
      if(ir_np.EQ.izonin) then
        idisc=1
        return
      end if
c
      tval=1.d+30
      itvalm=0
c
c     body check
      u_np=u(np)
      v_np=v(np)
      w_np=w(np)
      x_np=x(np)
      y_np=y(np)
      z_np=z(np)
c
      do i=1,nbbody(ir_np)
        nozone=ABS(nbzone(i,ir_np))
        jty=itblty(nozone)
        kno=itblno(nozone)
c     rpp check
        if(jty.eq.ityknd(1)) then
          if(kno.le.0.or.kno.gt.irppin) go to 280
          call rppcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     sph check
        elseif(jty.eq.ityknd(2)) then
          if(kno.le.0.or.kno.gt.isphin) go to 280
          call sphcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     rcc check
        elseif(jty.eq.ityknd(3)) then
          if(kno.le.0.or.kno.gt.irccin) go to 280
          call rcccg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     trc check
        elseif(jty.eq.ityknd(4)) then
          if(kno.le.0.or.kno.gt.itrcin) go to 280
          call trccg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     tor check
        elseif(jty.eq.ityknd(5)) then
          if(kno.le.0.or.kno.gt.itorin) go to 280
          call torcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     rec check
        elseif(jty.eq.ityknd(6)) then
          if(kno.le.0.or.kno.gt.irecin) go to 280
          call reccg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     ell check
        elseif(jty.eq.ityknd(7)) then
          if(kno.le.0.or.kno.gt.iellin) go to 280
          call ellcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     wed check
        elseif(jty.eq.ityknd(8)) then
          if(kno.le.0.or.kno.gt.iwedin) go to 280
          call wedcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     box check
        elseif(jty.eq.ityknd(9)) then
          if(kno.le.0.or.kno.gt.iboxin) go to 280
          call boxcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     arb check
        elseif(jty.eq.ityknd(10)) then
          if(kno.le.0.or.kno.gt.iarbin) go to 280
          call arbcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     hex check
        elseif(jty.eq.ityknd(11)) then
          if(kno.le.0.or.kno.gt.ihexin) go to 280
          call hexcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     haf check
        elseif(jty.eq.ityknd(12)) then
          if(kno.le.0.or.kno.gt.ihafin) go to 280
          call hafcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     tec check
        elseif(jty.eq.ityknd(13)) then
          if(kno.le.0.or.kno.gt.itecin) go to 280
          call teccg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c     gel check
        elseif(jty.eq.ityknd(14)) then
          if(kno.le.0.or.kno.gt.igelin) go to 280
          call gelcg1(kno,x_np,y_np,z_np,u_np,v_np,w_np)
c
c**** add new geometry in here
c
       end if
  280  continue
      end do
c
      irnear=ir_np
      if(itvalm.eq.0) then
        tval0=cgeps1
        xidd=x_np+tval0*u_np
        yidd=y_np+tval0*v_np
        zidd=z_np+tval0*w_np
  310   continue
          if(x_np.ne.xidd.or.y_np.ne.yidd.or.z_np.ne.zidd) goto 320
          tval0=tval0*10.d0
          xidd=x_np+tval0*u_np
          yidd=y_np+tval0*v_np
          zidd=z_np+tval0*w_np
          go to 310
  320   continue
c       write(*,*) 'srzone:1'
        call srzone(xidd,yidd,zidd,iq_np,ir_np,irnext)
c
        if(irnext.ne.ir_np) then
          tval=0.0d0
          irnear=irnext
        else
          tval00=0.0d0
          tval10=10.0d0*tval0
          irlold=ir_np
          irlfg=0
  330     continue
          if(irlfg.eq.1) go to 340
            tval00=tval00+tval10
            if(tval00.gt.1.0d+06) then
              write(6,9000) iq(np),ir(np),x(np),y(np),z(np),
     &                      u(np),v(np),w(np),tval00
 9000 format(' TVAL00 ERROR : iq,ir,x,y,z,u,v,w,tval=',
     &       2I3,1P7E12.5)
              stop
            end if
            xidd=x_np+tval00*u_np
            yidd=y_np+tval00*v_np
            zidd=z_np+tval00*w_np
            call srzold(xidd,yidd,zidd,irlold,irlfg)
            go to 330
  340     continue
c
          tval=tval00
          do j=1,10
            xidd=x_np+tval00*u_np
            yidd=y_np+tval00*v_np
            zidd=z_np+tval00*w_np
c           write(*,*) 'srzone:2'
            call srzone(xidd,yidd,zidd,iq_np,irlold,irnext)
            if(irnext.ne.irlold) then
              tval=tval00
              irnear=irnext
            end if
            tval00=tval00-tval0
          end do
          if(ir_np.eq.irnear) then
            write(0,*) 'ir(np),tval=',ir_np,tval
          end if
        end if
      else
        do j=1,itvalm-1
          do i=j+1,itvalm
            if(atval(i).lt.atval(j)) then
              atvaltmp=atval(i)
              atval(i)=atval(j)
              atval(j)=atvaltmp
            endif
          enddo
        enddo
        itvlfg=0
        tvalmn=tval
        do jjj=1,itvalm
          if(tvalmn.gt.atval(jjj)) then
            tvalmn=atval(jjj)
          end if
          delhow=cgeps2
          tval0=atval(jjj)+delhow
          xidd=x_np+tval0*u_np
          yidd=y_np+tval0*v_np
          zidd=z_np+tval0*w_np
  410     continue
          if(x_np.ne.xidd.or.y_np.ne.yidd.or.z_np.ne.zidd) go to 420
            delhow=delhow*10.d0
            tval0=atval(jjj)+delhow
            xidd=x_np+tval0*u_np
            yidd=y_np+tval0*v_np
            zidd=z_np+tval0*w_np
          go to 410
  420     continue
c         write(*,*) 'srzone:3'
          call srzone(xidd,yidd,zidd,iq_np,ir_np,irnext)
          if((irnext.ne.ir_np.or.atval(jjj).ge.1.).and.
     &        tval.gt.atval(jjj)) THEN
            tval=atval(jjj)
            irnear=irnext
            itvlfg=1
            goto 425
          end if
        end do
  425   continue
        if(itvlfg.eq.0) then
          tval0=cgmnst
          xidd=x_np+tval0*u_np
          yidd=y_np+tval0*v_np
          zidd=z_np+tval0*w_np
  430     continue
          if(x_np.ne.xidd.or.y_np.ne.yidd.or.z_np.ne.zidd) go to 440
            tval0=tval0*10.d0
            xidd=x_np+tval0*u_np
            yidd=y_np+tval0*v_np
            zidd=z_np+tval0*w_np
            go to 430
  440     continue
          if(tvalmn.gt.tval0) then
            tval=tvalmn
          else
            tval=tval0
          end if
        end if
      end if
      ihitcg=0
      if(tval.le.ustep) then
        ustep=tval
        ihitcg=1
      end if
      if(ihitcg.eq.1) THEN
        if(irnear.eq.0) THEN
          write(6,9200) iq(np),ir(np),x(np),y(np),z(np),
     &                  u(np),v(np),w(np),tval
 9200 format(' TVAL ERROR : iq,ir,x,y,z,u,v,w,tval=',2I3,1P7E12.5)
          idisc=1
          itverr=itverr+1
          if(itverr.ge.10000) then
            stop
          end if
          return
        end if
        irnew=irnear
        if(irnew.ne.ir_np) then
          call rstnxt(iq_np,ir_np,irnew)
        endif
      end if
      return
      end
!--------------------last line of subroutine howfar---------------------
