#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <cstdlib>
#include <iomanip>

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <L> <cpu_output_file> <gpu_output_file>" << std::endl;
        return 1;
    }

    int L = std::atoi(argv[1]);
    const char* cpu_file = argv[2];
    const char* gpu_file = argv[3];

    // Total elements in 3D array L*L*L
    size_t total_size = static_cast<size_t>(L) * L * L;
    size_t bytes = total_size * sizeof(double);

    // Epsilon for comparison (set slightly higher than MAXEPS check in jacobi)
    const double EPSILON = 1e-10;

    std::vector<double> cpu_data(total_size);
    std::vector<double> gpu_data(total_size);

    // Helper lambda to read binary file
    auto readBinary = [](const char* filename, std::vector<double>& buffer, size_t expected_bytes) {
        std::ifstream in(filename, std::ios::binary | std::ios::ate);
        if (!in.is_open()) {
            std::cerr << "Error: Cannot open file " << filename << std::endl;
            return false;
        }
        
        std::streamsize size = in.tellg();
        in.seekg(0, std::ios::beg);

        if (size != expected_bytes) {
            std::cerr << "Error: File size mismatch for " << filename 
                      << ". Expected " << expected_bytes << " bytes, got " << size << std::endl;
            return false;
        }

        if (!in.read(reinterpret_cast<char*>(buffer.data()), expected_bytes)) {
            std::cerr << "Error: Failed to read data from " << filename << std::endl;
            return false;
        }
        return true;
    };

    // Read both files
    if (!readBinary(cpu_file, cpu_data, bytes)) return 1;
    if (!readBinary(gpu_file, gpu_data, bytes)) return 1;

    // Compare
    long long diff_count = 0;
    double max_diff = 0.0;
    size_t max_idx = 0;

    std::cout << "Comparing binary arrays of size " << L << "^3..." << std::endl;

    for (size_t i = 0; i < total_size; ++i) {
        double diff = std::fabs(cpu_data[i] - gpu_data[i]);
        
        if (diff > max_diff) {
            max_diff = diff;
            max_idx = i;
        }
        
        if (diff > EPSILON) {
            diff_count++;
        }
    }

    std::cout << std::scientific << std::setprecision(10);
    std::cout << "Max difference found: " << max_diff << std::endl;
    std::cout << "Epsilon threshold:    " << EPSILON << std::endl;

    if (diff_count == 0) {
        std::cout << "SUCCESS: Results are identical within epsilon range." << std::endl;
        return 0;
    } else {
        std::cout << "FAILURE: " << diff_count << " elements differ." << std::endl;
        // Optional: Print the values at the point of maximum difference
        std::cout << "Worst case index: " << max_idx << std::endl;
        std::cout << "CPU Value: " << cpu_data[max_idx] << std::endl;
        std::cout << "GPU Value: " << gpu_data[max_idx] << std::endl;
        return 1;
    }
}