!----------------------------egs5mpi.f---------------------------------
! Version: 120419-1300
!-----------------------------------------------------------------------
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12
      
      subroutine egs5mpi_init

      implicit none
      include "mpif.h"
      include 'mpi_include/egs5mpi_h.f'

      call mpi_init(mpi_err)
      call mpi_comm_size(MPI_COMM_WORLD,mpi_size,mpi_err)
      call mpi_comm_rank(MPI_COMM_WORLD,mpi_rank,mpi_err)

      return
      end

!--------------------last line of egs5mpi_init--------------------------

!--------------------egs5mpi_rluxinit-----------------------------------

      subroutine egs5mpi_rluxinit

      implicit none

      include "mpif.h"
      include 'mpi_include/egs5mpi_h.f'
      include 'include/randomm.f'

      real*8 tmp_rnd
      integer i,j
      
      write(6,'(a,I10)')
     &     " mpi_mainseed =", mpi_mainseed

      if(mpi_rank .eq. 0) then 
         inseed = mpi_mainseed
         call rluxinit
         
         do i=1, mpi_size
            call randomset(tmp_rnd)
            mpi_inseed(i) = 2147483647 * tmp_rnd
         end do
         
         i = 1
         do while(i .lt. mpi_size) 
            j = i + 1
            do while(j .le. mpi_size)
               if(mpi_inseed(i) .eq. mpi_inseed(j)) then
                  call randomset(tmp_rnd)
                  mpi_inseed(j) = 2147483647 * tmp_rnd
                  i = 1
                  j = i + 1
                  cycle
               end if
               j = j + 1
            end do
            i = i + 1
         end do
      end if
      
      call mpi_bcast(mpi_inseed(1), mpi_size, MPI_INTEGER,
     &     0, MPI_COMM_WORLD, mpi_err)
      
      write (6,'(/,a,/)') " random seed list"

      do i=1, mpi_size
         write(6,'(a,I6,a,I10)')
     &        " rank = ",i,", seed = ",mpi_inseed(i)
      end do
      
      write(6,'(/,a,I6)')
     &     " This process rank = ", mpi_rank
      
      write(6,'(a,I10,/)')
     &     " This process seed = ", mpi_inseed(mpi_rank + 1)

      inseed = mpi_inseed(mpi_rank + 1)
      call rluxinit
      
      return
      end
!--------------------last line of egs5mpi_rluxinit----------------------

!--------------------mpiegs5_pegscall-----------------------------------

      subroutine egs5mpi_pegscall

      implicit none
      
      include "mpif.h"
      include 'mpi_include/egs5mpi_h.f'

      if(mpi_rank .eq. 0) then
         call pegs5
      end if

      call mpi_barrier(MPI_COMM_WORLD, mpi_err)

      return
      end 
!--------------------last line of egs5mpi_pegscall----------------------

!--------------------egs5mpi_finalize-----------------------------------
      subroutine egs5mpi_finalize
      
      implicit none

      include "mpif.h"
      include 'mpi_include/egs5mpi_h.f'
      call mpi_finalize(mpi_err)

      return
      end

!--------------------last line of egs5mpi_finalize----------------------
!--------------------last line of egs5mpi.f-----------------------------

