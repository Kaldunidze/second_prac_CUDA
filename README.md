# Постановка задачи
Задача состоит в максимально оптимизированном распараллеливании программы 3х мерного Якоби. 
Для данного кода на C++ была написана модифицированная версия использующая CUDA и изменена оригинальная чтобы она корректно вычисляла время выполнения и возвращала последнюю матрицу.

# Сборка
```bash
mkdir build
cmake ..
make
```

# Сравнение результатов между версией на CPU и GPU
```bash
make run_compare
```
запускает обе версии с параметром L размера матрицы 256 и сравнивает через compare.cpp возвращаемые массивы

#Результаты запуска текущей версии на polus

```
Sender: LSF System <lsfadmin@polus-c3-ib.bmc.hpc.cs.msu.ru>
Subject: Job 1538738: <./adi3d_gpu 900> in cluster <MSUCluster> Done

Job <./adi3d_gpu 900> was submitted from host <polus-ib.bmc.hpc.cs.msu.ru> by user <edu-cmc-nvidia26-04> in cluster <MSUCluster> at Wed Apr 29 20:53:47 2026
Job was executed on host(s) <polus-c3-ib.bmc.hpc.cs.msu.ru>, in queue <short>, as user <edu-cmc-nvidia26-04> in cluster <MSUCluster> at Wed Apr 29 20:53:47 2026
</home_edu/edu-cmc-nvidia26/edu-cmc-nvidia26-04> was used as the home directory.
</home_edu/edu-cmc-nvidia26/edu-cmc-nvidia26-04/second_prac_CUDA> was used as the working directory.
Started at Wed Apr 29 20:53:47 2026
Terminated at Wed Apr 29 20:53:56 2026
Results reported at Wed Apr 29 20:53:56 2026

Your job looked like:

------------------------------------------------------------
# LSBATCH: User input
./adi3d_gpu 900
------------------------------------------------------------

Successfully completed.

Resource usage summary:

    CPU time :                                   6.47 sec.
    Max Memory :                                 5575 MB
    Average Memory :                             4181.50 MB
    Total Requested Memory :                     -
    Delta Memory :                               -
    Max Swap :                                   -
    Max Processes :                              3
    Max Threads :                                6
    Run time :                                   13 sec.
    Turnaround time :                            9 sec.

The output (if any) follows:

 IT =    1   EPS = 1.4977753e+01
 IT =    2   EPS = 7.4833148e+00
 IT =    3   EPS = 3.7388765e+00
 IT =    4   EPS = 2.8020717e+00
 IT =    5   EPS = 2.0999896e+00
 IT =    6   EPS = 1.6321086e+00
 IT =    7   EPS = 1.3979074e+00
 IT =    8   EPS = 1.2004305e+00
 IT =    9   EPS = 1.0395964e+00
 IT =   10   EPS = 9.0896725e-01
 ADI Benchmark Completed.
 Size            = 900 x 900 x 900
 Iterations      =       10
 Time in seconds =       3.96
 Operation type  =   double precision
 END OF ADI Benchmark
```
