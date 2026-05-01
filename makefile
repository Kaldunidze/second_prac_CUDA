NVCC = nvcc
GXX = g++

ARCH = -arch=sm_60

NVCC_FLAGS = $(ARCH) -std=c++11 -O3 --expt-extended-lambda -Xcompiler=-Wall,-Wextra
GXX_FLAGS = -std=c++11 -O3 -fopenmp -Wall -Wextra

all: adi3d_cpu adi3d_gpu compare

adi3d_gpu: adi3d_gpu.cu
	$(NVCC) $(NVCC_FLAGS) $< -o $@ 

adi3d_cpu: adi3d_cpu.cpp
	$(GXX) $(GXX_FLAGS) $< -o $@ -lm

compare: compare.cpp
	$(GXX) $(GXX_FLAGS) $< -o $@


clean:
	rm -f adi3d_cpu adi3d_gpu adi3d_gpu_save adi3d_cpu_save compare *_out

run_compare: adi3d_cpu_save compare adi3d_gpu_save
	./adi3d_cpu_save 256
	./adi3d_gpu_save 256
	./compare 256 adi3d_cpu_out adi3d_gpu_out

adi3d_gpu_save: adi3d_gpu.cu
	$(NVCC) $(NVCC_FLAGS) -DSAVE_OUTPUT $< -o $@

adi3d_cpu_save: adi3d_cpu.cpp
	$(GXX) $(GXX_FLAGS) -DSAVE_OUTPUT $< -o $@ -lm