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
#include <thrust/reduce.h>

void sweep_x(double *a, int nx, int ny, int nz)
{
    thrust::for_each(
        thrust::counting_iterator<int>(0),
        thrust::counting_iterator<int>((ny - 2) * (nz - 2)),
        [a, nx, ny, nz] __device__(int idx)
        {
            int j = idx / (nz - 2) + 1;
            int k = idx % (nz - 2) + 1;
            for (int i = 1; i < nx - 1; i++)
            {
                int f = i * ny * nz + j * nz + k;
                a[f] = (a[f - ny * nz] + a[f + ny * nz]) / 2.0;
            }
        });
}

void sweep_y(double *a, int nx, int ny, int nz)
{
    thrust::for_each(
        thrust::counting_iterator<int>(0),
        thrust::counting_iterator<int>((nx - 2) * (nz - 2)),
        [a, nx, ny, nz] __device__(int idx)
        {
            int i = idx / (nz - 2) + 1;
            int k = idx % (nz - 2) + 1;
            for (int j = 1; j < ny - 1; j++)
            {
                int f = i * ny * nz + j * nz + k;
                a[f] = (a[f - nz] + a[f + nz]) / 2.0;
            }
        });
}

void sweep_z(double *a, double *row_eps, int nx, int ny, int nz)
{
    thrust::for_each(
        thrust::counting_iterator<int>(0),
        thrust::counting_iterator<int>((nx - 2) * (ny - 2)),
        [a, row_eps, nx, ny, nz] __device__(int idx)
        {
            int i = idx / (ny - 2) + 1;
            int j = idx % (ny - 2) + 1;
            double *row = a + i * ny * nz + j * nz;
            double local_eps = 0.0;
            for (int k = 1; k < nz - 1; k++)
            {
                double tmp = (row[k - 1] + row[k + 1]) / 2.0;
                local_eps = fmax(local_eps, fabs(row[k] - tmp));
                row[k] = tmp;
            }
            row_eps[idx] = local_eps;
        });
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
    case 2:
        nx = ny = nz = std::stoi(argv[1]);
        break;
    case 4:
        nx = std::stoi(argv[1]);
        ny = std::stoi(argv[2]);
        nz = std::stoi(argv[3]);
        break;
    default:
        break;
    }

    auto start = std::chrono::steady_clock::now();

    auto a = thrust::device_vector<double>(nx * ny * nz);
    auto row_eps = thrust::device_vector<double>((nx - 2) * (ny - 2));

    // init
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
    double *eps_buf = thrust::raw_pointer_cast(row_eps.data());

    for (it = 1; it <= itmax; it++)
    {
        sweep_x(cur, nx, ny, nz);
        sweep_y(cur, nx, ny, nz);
        sweep_z(cur, eps_buf, nx, ny, nz);

        eps = thrust::reduce(row_eps.begin(), row_eps.end(), 0.0, thrust::maximum<double>());

        std::cout << " IT = " << std::setw(4) << it
                  << "   EPS = " << std::scientific << std::setprecision(7) << eps << "\n";
        if (eps < maxeps)
            break;
    }

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

#ifdef SAVE_OUTPUT
    {
        std::vector<double> host(nx * ny * nz);
        cudaMemcpy(host.data(), cur, (size_t)nx * ny * nz * sizeof(double), cudaMemcpyDeviceToHost);
        std::ofstream out("adi3d_gpu_out", std::ios::binary);
        out.write(reinterpret_cast<const char *>(host.data()),
                  static_cast<std::streamsize>(nx * ny * nz * sizeof(double)));
    }
#endif

    return 0;
}
