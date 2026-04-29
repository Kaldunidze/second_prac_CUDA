NVCC = nvcc
GXX = g++

ARCH = -arch=sm_60

NVCC_FLAGS = $(ARCH) -std=c++11 -O2 --expt-extended-lambda -Xcompiler=-Wall,-Wextra
GXX_FLAGS = -std=c++11 -O2 -fopenmp -Wall -Wextra

all: adi3d_cpu adi3d_gpu compare

adi3d_gpu: adi3d_gpu.cu
	$(NVCC) $(NVCC_FLAGS) $< -o $@ 

adi3d_cpu: adi3d_cpu.cpp
	$(GXX) $(GXX_FLAGS) $< -o $@ -lm

compare: compare.cpp
	$(GXX) $(GXX_FLAGS) $< -o $@


clean:
	rm -f adi3d_cpu adi3d_gpu compare *_out

run_compare: all
	./adi3d_cpu 256
	./adi3d_gpu 256
	./compare 256 adi3d_cpu_out adi3d_gpu_out