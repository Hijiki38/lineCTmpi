!-----------------------------egs5_edge.f-------------------------------
! Version: 141215-1645
!-----------------------------------------------------------------------
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12

      common/EDGE/    ! Fluorescent photon/Auger electron transport data
     * eedge(4,100),ekx(10,100),dfkx(10,100),elx1(8,100),elx2(5,100),
     * elx3(7,100),dflx1(8,100),dflx2(5,100),dflx3(7,100),pm0(5,100),
     * pm1(5,100),pm2(5,100),pm3(5,100),ekaug(14,100),dfkaug(13,100),
     * el1aug(6,100),el2aug(6,100),el3aug(6,100),dfl1aug(6,100),
     * dfl2aug(6,100),dfl3aug(6,100),edgb(80,MXMED),
     * omegak(100),embind(100),
     * omegal1(100),omegal2(100),omegal3(100),f12(100),f13(100),
     * f23(100),
     * exray(10),eauger(10),
     * ebind,
     * ledgb(80,MXMED),
     * nepm(MXEPERMED),
     * nedgb(MXMED),
     * nauger,nxray,iz,
     * iextp

      real*8
     * eedge,ekx,dfkx,elx1,elx2,
     * elx3,dflx1,dflx2,dflx3,pm0,
     * pm1,pm2,pm3,ekaug,dfkaug,el1aug,
     * el2aug,el3aug,dfl1aug,dfl2aug,
     * dfl3aug,edgb,
     * omegak,embind,
     * omegal1,omegal2,omegal3,f12,f13,
     * f23,exray,eauger,
     * ebind

      integer
     * ledgb,
     * nepm,
     * nedgb,
     * nauger,nxray,iz,
     * iextp

      common/ EDGE2/iedgfl(MXREG),iauger(MXREG)
      integer 
     * iedgfl, iauger

!-------------------------last line of egs5_edge.f----------------------
