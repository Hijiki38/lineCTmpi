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
      integer,parameter :: maxparam = 9

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
     * ifto_original,ifto_dummy,nor,prmi,phantom,beam!,mpi_ifct

      !for counting time
      integer(int32) :: time_begin_c,time_end_c, CountPerSec, CountMax

      real,dimension(2,maxspec) :: crt
      real,dimension(30,maxtrans+100) :: ctgeom

      character*24 medarr(MXMED)
      character*3  geomkind(15)
      character*8  geomzone(100)
      character*22 degfile
      character*25 pictfile

      character(4) :: paramname(maxparam)

      integer totalcases,mpierr		!for MPI
      character*6 rank_str
      real*8 mpi_esum(MXREG)



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
      open(40,FILE='source270kv_theta60_cu0.3mm.csv',STATUS='old')
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
      phantom=1  ! Phantom Type (0:Onion, 1:Tissue, 2:Metal, 3:FourMetal, 4:FourMetalTest(wo/Ni), 5:FourTissues, 6:small, 7:smallfour)
      beam=1     ! Beam Type (0:Parallel, 1:Fan)
!-----------------------------------------------------------------------
! initiallization variables
!-----------------------------------------------------------------------

      do i=1,4096
        depe(i)=0.D0
      end do

      !ctdis=-1.0d0
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
      !ctdis = parameters(1)
      ctdiss = parameters(1)
      ctdisd = parameters(2)
      ctdisd = ctdisd - ctdiss
!      read *, ctdis
      !ctdis=ctdis/2
      if(ctdiss.le.0.0 .or. ctdisd.le.0.0) then
        write(6,*) "distance must be greater than 0!"
        flush(6)
        stop
      end if
      translation_pitch = parameters(3)

!      read *, translation_pitch
      if(translation_pitch.le.0.0) then
        write(6,*) "translation must be greater than 0!"
        flush(6)
        stop
      end if

      ctx = translation_pitch !adjust ctx, cty to translation pitch
      cty = translation_pitch
      !ctz = translation_pitch

      translation_times = parameters(4)
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
      ctstep = parameters(5)
!      read *, ctstep
      if(ctstep.le.0.0.or.ctstep.gt.3600.0) then
        stop
      end if
      totalcases = parameters(6)
!      read *, ncases
      if(totalcases.lt.1) then
        write(6,*) "History number should be set at least one"
        flush(6)
        stop
      end if
      initstep = parameters(7)
      phantom = parameters(8)
      if(phantom.lt.0 .or. phantom.gt.5) then
        write(6,*) "phantom number you entered is not defined"
      end if
      beam = parameters(9)
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
      !nmed=6
      nmed=7
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

!      medarr(1)='CDTE                    '
!      medarr(2)='AIR-AT-NTP              '
!      medarr(3)='AL                      '
!      medarr(4)='PMMA                    '
!      medarr(5)='H2O                     '
!      medarr(6)='PVC                     '
!      medarr(7)='TI                      '
!      medarr(8)='C                       '
!      medarr(9)='NI                      '

	if (phantom.eq.3) then
        medarr(1)='CDTE                    '
        medarr(2)='AIR-AT-NTP              '
        medarr(3)='AL                      '
        medarr(4)='CU                      '
        medarr(5)='TI                      '
        medarr(6)='C                       '
        medarr(7)='H2O                     '
	end if

      !medarr(1)='CDTE                    '
      !medarr(2)='AIR-AT-NTP              '
      !medarr(3)='I1                      '
      !medarr(4)='I2                      '
      !medarr(5)='I3                      '
      !medarr(6)='H2O                     '


      if (phantom.eq.5 .or. phantom.eq.8) then
        medarr(1)='CDTE                    '
        medarr(2)='AIR-AT-NTP              '
        medarr(3)='AL                      '
        medarr(4)='PMMA                    '
        medarr(5)='H2O                     '
        medarr(6)='PVC                     '
        medarr(7)='PLA                     '
        medarr(8)='C                       '
        medarr(9)='ABS                     '
      end if

      do j=1,nmed
        do i=1,24
          media(i,j)=medarr(j)(i:i)
        end do
      end do

      chard(1) = 0.01d0
      chard(2) = 0.05d0
      chard(3) = 0.05d0
      chard(4) = 0.05d0
      chard(5) = 0.05d0
      chard(6) = 0.05d0
      chard(7) = 0.05d0
      !chard(8) = 0.05d0
      !chard(9) = 0.05d0
      !chard(10) = 0.1d0

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
      do stepi=initstep,ctstep-1                    ! Begining of Rotation loop
                                             ! -------------------------
      write(6,*) 'Read cg-related data'
      flush(6)
!-----------------------------------------------
!     Initialize CG related parameters
!-----------------------------------------------

      ctang=360e0/ctstep*stepi

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


!110   FORMAT(a, i4, 12e12.6e2)
!-----------------------------------------------
!Detector Region(SUM)[geomkind is BOX]
!-----------------------------------------------
      ctgeom(1,cti)=ctdisd*sin(csrad)+(htl+ctx/2)*cos(csrad)
      ctgeom(2,cti)=-cty/2
      ctgeom(3,cti)=ctdisd*cos(csrad)-(htl+ctx/2)*sin(csrad)
      ctgeom(4,cti)=-ctx*cos(csrad)*translation_times
      ctgeom(5,cti)=0.0e0
      ctgeom(6,cti)=ctx*sin(csrad)*translation_times
      ctgeom(7,cti)=0.0e0
      ctgeom(8,cti)=cty
      ctgeom(9,cti)=0.0e0
      ctgeom(10,cti)=ctz*sin(csrad)
      ctgeom(11,cti)=0.0e0
      ctgeom(12,cti)=ctz*cos(csrad)
      write(ifti,*) geomkind(6),cti,(ctgeom(cto,cti),cto=1,12)
      cti=cti+1

!-----------------------------------------------
!Detector Region(8 MODULEs)[geomkind is BOX]
!-----------------------------------------------

      !do transi=0,translation_times-1,translation_times/8
      !  ctgeom(1,cti)=ctdisd*sin(csrad)+(htl+ctx/2)*cos(csrad)-transi*xl
      !  ctgeom(2,cti)=-cty/2
      !  ctgeom(3,cti)=ctdisd*cos(csrad)-(htl+ctx/2)*sin(csrad)+transi*zl
      !  ctgeom(4,cti)=-ctx*cos(csrad)*translation_times/8
      !  ctgeom(5,cti)=0.0e0
      !  ctgeom(6,cti)=ctx*sin(csrad)*translation_times/8
      !  ctgeom(7,cti)=0.0e0
      !  ctgeom(8,cti)=cty
      !  ctgeom(9,cti)=0.0e0
      !  ctgeom(10,cti)=ctz*sin(csrad)
      !  ctgeom(11,cti)=0.0e0
      !  ctgeom(12,cti)=ctz*cos(csrad)
      !  write(ifti,*) geomkind(6),cti,(ctgeom(cto,cti),cto=1,12)
      !  cti=cti+1
      !end do

!-----------------------------------------------
!Detector Region[geomkind is BOX]
!-----------------------------------------------
      do transi=0,translation_times-1
        ctgeom(1,cti)=ctdisd*sin(csrad)+(htl+ctx/2)*cos(csrad)-transi*xl
        !ctgeom(1,cti)=ctdisd*sin(csrad)+(htl+ctx/2-transi*xl)*cos(csrad)
        ctgeom(2,cti)=-cty/2
        ctgeom(3,cti)=ctdisd*cos(csrad)-(htl+ctx/2)*sin(csrad)+transi*zl
        !ctgeom(3,cti)=ctdisd*cos(csrad)-(htl+ctx/2-transi*xl)*sin(csrad)
        ctgeom(4,cti)=-ctx*cos(csrad)
        ctgeom(5,cti)=0.0e0
        ctgeom(6,cti)=ctx*sin(csrad)
        ctgeom(7,cti)=0.0e0
        ctgeom(8,cti)=cty
        ctgeom(9,cti)=0.0e0
        ctgeom(10,cti)=ctz*sin(csrad)
        ctgeom(11,cti)=0.0e0
        ctgeom(12,cti)=ctz*cos(csrad)
        write(ifti,*) geomkind(6),cti,(ctgeom(cto,cti),cto=1,12)
        cti=cti+1
      end do
!-----------------------------------------------
!Air Zone[geomkind is RPP]
!-----------------------------------------------
        do ctp=1,6
          ctgeom(ctp,cti)=halfosl*(-1)**ctp
        end do
      write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
      cti=cti+1

!SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1
!-----------------------------------------------
!Colimator Region[geomkind is RCC and so on..]
!-----------------------------------------------
!Making PB collimator
      ! ctgeom(1,cti)=(ctdis-1.5e0)*sin(csrad)+htl*cos(csrad)-transi*xl
      ! ctgeom(2,cti)=0.0e0
      ! ctgeom(3,cti)=(ctdis-1.5e0)*cos(csrad)-htl*sin(csrad)+transi*zl
      ! ctgeom(4,cti)=0.5e0*sin(csrad)
      ! ctgeom(5,cti)=0.0e0
      ! ctgeom(6,cti)=0.5e0*cos(csrad)
      ! ctgeom(7,cti)=1.389e0
      !   write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
      ! cti=cti+1
      ! nos=nos+1
      ! ctgeom(1,cti)=(ctdis-1.5e0)*sin(csrad)+htl*cos(csrad)-transi*xl
      ! ctgeom(2,cti)=0.0e0
      ! ctgeom(3,cti)=(ctdis-1.5e0)*cos(csrad)-htl*sin(csrad)+transi*zl
      ! ctgeom(4,cti)=0.5e0*sin(csrad)
      ! ctgeom(5,cti)=0.0e0
      ! ctgeom(6,cti)=0.5e0*cos(csrad)
      ! ctgeom(7,cti)=0.06e0
      !   write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
      ! cti=cti+1
      ! nos=nos+1
      ! ctgeom(1,cti)=(ctdis-1.0e0)*sin(csrad)+htl*cos(csrad)-transi*xl
      ! ctgeom(2,cti)=0.0e0
      ! ctgeom(3,cti)=(ctdis-1.0e0)*cos(csrad)-htl*sin(csrad)+transi*zl
      ! ctgeom(4,cti)=1.5e0*sin(csrad)
      ! ctgeom(5,cti)=0.0e0
      ! ctgeom(6,cti)=1.5e0*cos(csrad)
      ! ctgeom(7,cti)=1.389e0
      !   write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
      ! cti=cti+1
      ! nos=nos+1
      ! ctgeom(1,cti)=(ctdis-1.0e0)*sin(csrad)+htl*cos(csrad)-transi*xl
      ! ctgeom(2,cti)=0.0e0
      ! ctgeom(3,cti)=(ctdis-1.0e0)*cos(csrad)-htl*sin(csrad)+transi*zl
      ! ctgeom(4,cti)=1.5e0*sin(csrad)
      ! ctgeom(5,cti)=0.0e0
      ! ctgeom(6,cti)=1.5e0*cos(csrad)
      ! ctgeom(7,cti)=0.889e0
      !   write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
      ! cti=cti+1
      ! nos=nos+1

!-----------------------------------------------
!Sample Region[geomkind is RCC and so on..]
!-----------------------------------------------
! If you want to modify the geometry of the sample, change this part.

! ---- "Single rod Phantom" ----
      if(phantom.eq.0) then
        ctgeom(1,cti)=0.0e0 !ph1
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.15e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
      end if

! ---- "Two rods Phantom" ----
      if(phantom.eq.1 .or. phantom.eq.2) then
        ctgeom(1,cti)=0.0e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=1.0e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.5e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.5e0
        ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=-0.5e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
      end if

      ! ---- "Four rods Phantom" ----
      if(phantom.eq.3 .or. phantom.eq.4 .or. phantom.eq.5) then
        ctgeom(1,cti)=0.0e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=1.0e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.5e0 !ph1
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.15e0
        !ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.0e0 !ph2
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.5e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.15e0
        !ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=-0.5e0 !ph3
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.15e0
        !ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.0e0 !ph4
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=-0.5e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.15e0
        !ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
      end if

      ! ---- "Single rod Phantom small" ----
      if(phantom.eq.6) then
        ctgeom(1,cti)=0.0e0 
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.0e0 !ph1
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.075e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
      end if

      ! ---- "Four rods Phantom small" ----
      if(phantom.eq.7) then
        ctgeom(1,cti)=0.0e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.25e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.125e0 !ph1
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.05e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.0e0 !ph2
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.125e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.05e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=-0.125e0 !ph3
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.05e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.0e0 !ph4
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=-0.125e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ! ctgeom(7,cti)=0.15e0
        ctgeom(7,cti)=0.05e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
      end if

      ! ---- "Four rods Phantom square" ----
      if(phantom.eq.8) then
        ctgeom(1,cti)=0.0e0
        ctgeom(2,cti)=-0.75e0
        ctgeom(3,cti)=0.0e0
        ctgeom(4,cti)=0.0e0
        ctgeom(5,cti)=1.5e0
        ctgeom(6,cti)=0.0e0
        ctgeom(7,cti)=0.7e0 !radius
          write(ifti,*) geomkind(2),cti,(ctgeom(cto,cti),cto=1,7)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.1e0 !ph1
        ctgeom(2,cti)=0.5e0
        ctgeom(3,cti)=-0.75e0
        ctgeom(4,cti)=0.75e0
        ctgeom(5,cti)=-0.4e0
        ctgeom(6,cti)=-0.1e0
          write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=0.1e0 !ph2
        ctgeom(2,cti)=0.5e0
        ctgeom(3,cti)=-0.75e0
        ctgeom(4,cti)=0.75e0
        ctgeom(5,cti)=0.1e0
        ctgeom(6,cti)=0.4e0
          write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=-0.5e0 !ph3
        ctgeom(2,cti)=-0.1e0
        ctgeom(3,cti)=-0.75e0
        ctgeom(4,cti)=0.75e0
        ctgeom(5,cti)=0.1e0
        ctgeom(6,cti)=0.4e0
          write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
        cti=cti+1
        nos=nos+1
        ctgeom(1,cti)=-0.5e0 !ph4
        ctgeom(2,cti)=-0.1e0
        ctgeom(3,cti)=-0.75e0
        ctgeom(4,cti)=0.75e0
        ctgeom(5,cti)=-0.4e0
        ctgeom(6,cti)=-0.1e0
          write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
        cti=cti+1
        nos=nos+1
      end if

!SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1SAMPLE1


!-----------------------------------------------
!End Zone[geomkind is RPP]
!-----------------------------------------------
        do ctp=1,6
          ctgeom(ctp,cti)=(halfosl+1.0d0)*(-1)**ctp
        end do
      write(ifti,*) geomkind(1),cti,(ctgeom(cto,cti),cto=1,6)
      write(ifti,*) geomkind(15)

!-----------------------------------------------
!Definition of Detector Zone
!-----------------------------------------------
120   FORMAT('Z',I0.4,' +',I0)

      do transi=0,translation_times-1
        write(ifti,120) nor,nor+1 ! Z0001  +2
        nor=nor+1
      end do
!SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2
!-----------------------------------------------
!Definition of Air, Collimator and Sample Zone
!-----------------------------------------------
130   FORMAT('Z',I0.4,' +',I0)
140   FORMAT(' -',I0)
      write(ifti,130,advance='no') nor,nor+1 ! Z0513  +514  -1 -515
      !do transi=0,translation_times-1 !subtract detector zones
      !  write(ifti,140, advance='no') transi+1 ! 
      !end do

      write(ifti,140,advance='no') 1 !subtract detector zone
      write(ifti,140) nor+2 !subtract sample zone
      nor=nor+1

      if(phantom.eq.0) then
	     write(ifti,130) nor,nor+1
	     nor=nor+1
      else if(phantom.eq.6) then
        write(ifti,130,advance='no') nor,nor+1 !sample zone  Z0514  +515 -516 -517 -518 -519
        write(ifti,140) nor+2  !subtract rod 1

        nor=nor+1

        write(ifti,130) nor,nor+1 !rod1  Z0515 +516
        nor=nor+1
      else
        write(ifti,130,advance='no') nor,nor+1 !sample zone  Z0514  +515 -516 -517 -518 -519
        write(ifti,140,advance='no') nor+2  !subtract rod 1
        write(ifti,140,advance='no') nor+3 !subtract rod 2
        write(ifti,140,advance='no') nor+4 !subtract rod 3
        write(ifti,140) nor+5 !subtract rod 4

        nor=nor+1

        write(ifti,130) nor,nor+1 !rod1  Z0515 +516
        nor=nor+1
        write(ifti,130) nor,nor+1
        nor=nor+1
        !if(phantom.eq.3 .or. phantom.eq.4 .or. phantom.eq.5 .or. phantom.eq.7) then
        write(ifti,130) nor,nor+1 !rod 3
        nor=nor+1
        write(ifti,130) nor,nor+1 !rod 4
        nor=nor+1
        !end if
      end if
!SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2SAMPLE2


!-----------------------------------------------
!Definition of End Zone
!-----------------------------------------------
150   FORMAT('Z',I0.4,' +',I0' -',I0)
      write(ifti,150) nor,nor+1,translation_times+2  !Z0519 +520 -514
      write(ifti,*) geomkind(15)

!-----------------------------------------------
!Media number of Detector Zone
!-----------------------------------------------

      do transi=0,translation_times-1
        write(ifti,fmt='(a)',advance='no') " 1"
      end do

!SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3
!-----------------------------------------------
!Media number of Air
!-----------------------------------------------
      write(ifti,fmt='(a)',advance='no') " 2"

!-----------------------------------------------
!Media number of the Collimator
!-----------------------------------------------
      ! write(ifti,fmt='(a)',advance='no') " 5"
      ! write(ifti,fmt='(a)',advance='no') " 2"
      ! write(ifti,fmt='(a)',advance='no') " 5"
      ! write(ifti,fmt='(a)',advance='no') " 2"

!-----------------------------------------------
!Media number of the Sample
!-----------------------------------------------

      if(phantom.eq.0) then
        write(ifti,fmt='(a)',advance='no') " 5" !Ti
      else if(phantom.eq.1) then
        write(ifti,fmt='(a)',advance='no') " 4"
        write(ifti,fmt='(a)',advance='no') " 6"
        write(ifti,fmt='(a)',advance='no') " 5"
      else if(phantom.eq.2) then
        write(ifti,fmt='(a)',advance='no') " 4"
        write(ifti,fmt='(a)',advance='no') " 3"
        write(ifti,fmt='(a)',advance='no') " 7"
      else if(phantom.eq.3) then
        write(ifti,fmt='(a)',advance='no') " 3" !" 2" !back ground is Al
        write(ifti,fmt='(a)',advance='no') " 3"
        write(ifti,fmt='(a)',advance='no') " 6"
        write(ifti,fmt='(a)',advance='no') " 5"
        write(ifti,fmt='(a)',advance='no') " 4"
      else if(phantom.eq.4) then
        write(ifti,fmt='(a)',advance='no') " 2"
        write(ifti,fmt='(a)',advance='no') " 2"!" 3"
        write(ifti,fmt='(a)',advance='no') " 2"!" 4"
        write(ifti,fmt='(a)',advance='no') " 2"!" 5"
        write(ifti,fmt='(a)',advance='no') " 2"!" 6"
      else if(phantom.eq.5 .or. phantom.eq.8) then
        write(ifti,fmt='(a)',advance='no') " 4"
        write(ifti,fmt='(a)',advance='no') " 2"
        write(ifti,fmt='(a)',advance='no') " 5"
        write(ifti,fmt='(a)',advance='no') " 7"
        write(ifti,fmt='(a)',advance='no') " 9"
      else if(phantom.eq.6) then
        write(ifti,fmt='(a)',advance='no') " 6"
        write(ifti,fmt='(a)',advance='no') " 5"
      else if(phantom.eq.7) then
        write(ifti,fmt='(a)',advance='no') " 6"
        write(ifti,fmt='(a)',advance='no') " 2"
        write(ifti,fmt='(a)',advance='no') " 3"
        write(ifti,fmt='(a)',advance='no') " 4"
        write(ifti,fmt='(a)',advance='no') " 5"
      end if

!SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3SAMPLE3

      !medarr(1)='CDTE                    '
      !medarr(2)='AIR-AT-NTP              '
      !medarr(3)='I1                      '
      !medarr(4)='I2                      '
      !medarr(5)='I3                      '
      !medarr(6)='H2O                     '

      !medarr(1)='CDTE                    '
      !medarr(2)='AIR-AT-NTP              '
      !medarr(3)='AL                      '
      !medarr(4)='PMMA                    '
      !medarr(5)='H2O                     '
      !medarr(6)='PVC                     '
      !medarr(7)='TI                      '
      !medarr(8)='C                       '
      !medarr(9)='NI                      '
      !
      !! FOUR TISSUES
      ! medarr(1)='CDTE                    '
      ! medarr(2)='AIR-AT-NTP              '
      ! medarr(3)='AL                      '
      ! medarr(4)='PMMA                    '
      ! medarr(5)='H2O                     '
      ! medarr(6)='PVC                     '
      ! medarr(7)='PLA                     '
      ! medarr(8)='C                       '
      ! medarr(9)='ABS                     '

      !!FOUR Metal
      ! medarr(1)='CDTE                    '
      ! medarr(2)='AIR-AT-NTP              '
      ! medarr(3)='AL                      '
      ! medarr(4)='CU                      '
      ! medarr(5)='TI                      '
      ! medarr(6)='C                       '
      ! medarr(7)='H2O                     '

!-----------------------------------------------
!Media number of End Zone
!-----------------------------------------------
      write(ifti,*) "0"
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

          theta_rnd=translation_pitch*translation_times/(2*ctdisd)
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
