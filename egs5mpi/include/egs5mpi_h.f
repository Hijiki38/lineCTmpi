!-----------------------egs5mpi_h.f-------------------------------------
! Version: 120419-1300
!-----------------------------------------------------------------------
!23456789|123456789|123456789|123456789|123456789|123456789|123456789|12

      integer MAX_MPI_SIZE
      parameter(MAX_MPI_SIZE = 1024)

      COMMON/EGS5MPI/           !MPI parameter
     &     mpi_inseed(MAX_MPI_SIZE),
     &     mpi_size,
     &     mpi_rank,
     &     mpi_mainseed,
     &     mpi_err

      integer mpi_size,mpi_rank,mpi_mainseed,mpi_inseed,
     &        mpi_err
      

!--------------------last line of egs5_mpi_h.f---------------
