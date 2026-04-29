/* ADI program */

#include <algorithm>
#include <chrono>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>
#include <thrust/device_vector.h>
#include <thrust/for_each.h>
#include <thrust/functional.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/transform_reduce.h>


void sweep_Z(double *a, int d0, int d1, int d2)
{
    thrust::for_each(
        thrust::counting_iterator<int>(0),
        thrust::counting_iterator<int>((d0 - 2) * (d1 - 2)),
        [a, d0, d1, d2] __device__(int idx) {
            int s0 = idx / (d1 - 2) + 1;
            int s1 = idx % (d1 - 2) + 1;
            double *row = a + s0 * d1 * d2 + s1 * d2;
            for (int s2 = 1; s2 < d2 - 1; s2++)
                row[s2] = (row[s2 - 1] + row[s2 + 1]) / 2.0;
        });
}


__global__ void rotate_cyclic(const double *src, double *dst, int d0, int d1, int d2)
{
    int c = blockIdx.x * blockDim.x + threadIdx.x;
    int b = blockIdx.y * blockDim.y + threadIdx.y;
    int a = blockIdx.z;
    if (b >= d1 || c >= d2) return;
    dst[b * d2 * d0 + c * d0 + a] = src[a * d1 * d2 + b * d2 + c];
}

void do_rotate(double *src, double *dst, int d0, int d1, int d2)
{
    dim3 block(32, 32, 1);
    dim3 grid((d2 + 31) / 32, (d1 + 31) / 32, d0);
    rotate_cyclic<<<grid, block>>>(src, dst, d0, d1, d2);
}


__global__ void rotate_cyclic_inv(const double *src, double *dst, int d0, int d1, int d2)
{
    int c = blockIdx.x * blockDim.x + threadIdx.x;
    int b = blockIdx.y * blockDim.y + threadIdx.y;
    int a = blockIdx.z;
    if (b >= d1 || c >= d2) return;
    dst[c * d0 * d1 + a * d1 + b] = src[a * d1 * d2 + b * d2 + c];
}

void do_rotate_inv(double *src, double *dst, int d0, int d1, int d2)
{
    dim3 block(32, 32, 1);
    dim3 grid((d2 + 31) / 32, (d1 + 31) / 32, d0);
    rotate_cyclic_inv<<<grid, block>>>(src, dst, d0, d1, d2);
}

int main(int argc, char *argv[])
{
    const double maxeps = 0.01;
    const int itmax = 10;
    double eps = 0.0;
    int it;

    int nx = 256, ny = 256, nz = 256;
    switch (argc)
    {
    case 2: nx = ny = nz = std::stoi(argv[1]); break;
    case 4:
        nx = std::stoi(argv[1]);
        ny = std::stoi(argv[2]);
        nz = std::stoi(argv[3]);
        break;
    default: break;
    }

    auto start = std::chrono::steady_clock::now();

    auto a   = thrust::device_vector<double>(nx * ny * nz);
    auto tmp = thrust::device_vector<double>(nx * ny * nz);

    //init 
    {
        double *ptr = thrust::raw_pointer_cast(a.data());
        thrust::for_each(
            thrust::counting_iterator<int>(0),
            thrust::counting_iterator<int>(nx * ny * nz),
            [nx, ny, nz, ptr] __device__(int idx)
            {
                int i = idx / (ny * nz);
                int j = (idx / nz) % ny;
                int k = idx % nz;
                if (k == 0 || k == nz - 1 || j == 0 || j == ny - 1 || i == 0 || i == nx - 1)
                    ptr[idx] = 10.0 * i / (nx - 1) + 10.0 * j / (ny - 1) + 10.0 * k / (nz - 1);
                else
                    ptr[idx] = 0.0;
            });
    }

    double *cur = thrust::raw_pointer_cast(a.data());
    double *nxt = thrust::raw_pointer_cast(tmp.data());

    do_rotate(cur, nxt, nx, ny, nz);
    std::swap(cur, nxt);

    for (it = 1; it <= itmax; it++)
    {
        //X sweep        
        sweep_Z(cur, ny, nz, nx);
        do_rotate(cur, nxt, ny, nz, nx);
        std::swap(cur, nxt);

        //Y sweep
        sweep_Z(cur, nz, nx, ny);
        do_rotate(cur, nxt, nz, nx, ny);
        std::swap(cur, nxt);

        //Z sweep
        cudaMemcpy(nxt, cur, (size_t)nx * ny * nz * sizeof(double), cudaMemcpyDeviceToDevice);
        sweep_Z(cur, nx, ny, nz);
        // compute eps
        eps = thrust::transform_reduce(
            thrust::counting_iterator<int>(0),
            thrust::counting_iterator<int>(nx * ny * nz),
            [cur, nxt] __device__(int idx) -> double {
                return fabs(cur[idx] - nxt[idx]);
            },
            0.0,
            thrust::maximum<double>());
        
        //rotate for next iteration
        do_rotate(cur, nxt, nx, ny, nz);
        std::swap(cur, nxt);

        std::cout << " IT = " << std::setw(4) << it
                  << "   EPS = " << std::scientific << std::setprecision(7) << eps << "\n";
        if (eps < maxeps)
            break;
    }

    //rotate back to original layout
    do_rotate_inv(cur, nxt, ny, nz, nx);
    std::swap(cur, nxt);

    cudaDeviceSynchronize();
    auto end = std::chrono::steady_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cout << std::resetiosflags(std::ios::floatfield)
              << " ADI Benchmark Completed.\n"
              << " Size            = " << nx << " x " << ny << " x " << nz << "\n"
              << " Iterations      =       " << itmax << "\n"
              << " Time in seconds =       " << std::fixed << std::setprecision(2) << elapsed << "\n"
              << " Operation type  =   double precision\n"
              << " END OF ADI Benchmark\n";

    {
        std::vector<double> host(nx * ny * nz);
        cudaMemcpy(host.data(), cur, (size_t)nx * ny * nz * sizeof(double), cudaMemcpyDeviceToHost);
        std::ofstream out("adi3d_gpu_out", std::ios::binary);
        out.write(reinterpret_cast<const char *>(host.data()),
                  static_cast<std::streamsize>(nx * ny * nz * sizeof(double)));
    }

    return 0;
}
