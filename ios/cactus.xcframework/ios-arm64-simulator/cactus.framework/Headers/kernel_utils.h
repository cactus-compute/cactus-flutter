#ifndef KERNEL_UTILS_H
#define KERNEL_UTILS_H

#include <arm_neon.h>
#include <algorithm>
#include <cmath>
#include <thread>
#include <vector>
#include <functional>

constexpr size_t NEON_VECTOR_SIZE = 16;

inline int8_t clamp_to_int8(float value) {
    int32_t clamped = static_cast<int32_t>(roundf(value));
    return static_cast<int8_t>(std::max(-128, std::min(127, clamped)));
}

inline int8_t clamp_to_int8(int32_t value) {
    return static_cast<int8_t>(std::max(-128, std::min(127, value)));
}

#if defined(__ARM_FEATURE_I8MM) || defined(__ARM_FEATURE_MATMUL_INT8)
inline int32x4_t accum_i8mm(int32x4_t acc, int8x16_t a, int8x16_t b) {
    acc = vsmmlalb_s32(acc, a, b);
    return vsmmlalt_s32(acc, a, b);
}
#elif defined(__ARM_FEATURE_DOTPROD)
inline int32x4_t accum_i8mm(int32x4_t acc, int8x16_t a, int8x16_t b) {
    return vdotq_s32(acc, a, b);
}
#else
inline int32x4_t accum_i8mm(int32x4_t acc, int8x16_t a, int8x16_t b) {
    int8x8_t a_low = vget_low_s8(a);
    int8x8_t a_high = vget_high_s8(a);
    int8x8_t b_low = vget_low_s8(b);
    int8x8_t b_high = vget_high_s8(b);
    
    int16x8_t prod_low = vmull_s8(a_low, b_low);
    int16x8_t prod_high = vmull_s8(a_high, b_high);
    
    int32x4_t sum_low = vpaddlq_s16(prod_low);
    int32x4_t sum_high = vpaddlq_s16(prod_high);
    
    acc = vaddq_s32(acc, sum_low);
    acc = vaddq_s32(acc, sum_high);
    
    return acc;
}
#endif

inline float16x8_t accum_f16_dot(float16x8_t acc, float16x8_t a_low, float16x8_t a_high, 
                                 float16x8_t b_low, float16x8_t b_high) {
    acc = vfmaq_f16(acc, a_low, b_low);
    return vfmaq_f16(acc, a_high, b_high);
}

inline float32x4_t accum_f32_dot(float32x4_t acc, float32x4_t a_low, float32x4_t a_high, 
                                  float32x4_t b_low, float32x4_t b_high) {
    acc = vfmaq_f32(acc, a_low, b_low);
    return vfmaq_f32(acc, a_high, b_high);
}

namespace CactusThreading {
    
    inline size_t get_optimal_thread_count(size_t total_work, size_t min_work_per_thread) {
        if (total_work < min_work_per_thread) return 1;
        return std::min(static_cast<size_t>(std::thread::hardware_concurrency()), 
                       std::max(static_cast<size_t>(1), total_work / min_work_per_thread));
    }
    
    struct Thresholds {
        static constexpr size_t ELEMENT_WISE = 5000;
        static constexpr size_t AXIS_REDUCE = 1000;
        static constexpr size_t ALL_REDUCE = 10000;
        static constexpr size_t SCALAR_BASIC = 20000;
        static constexpr size_t SCALAR_EXPENSIVE = 10000;
    };
    
    template<typename WorkFunc>
    void parallel_for(size_t total_work, size_t threshold, WorkFunc work_func) {
        const size_t num_threads = get_optimal_thread_count(total_work, threshold);
        
        if (num_threads == 1) {
            work_func(0, total_work);
            return;
        }
        
        std::vector<std::thread> threads;
        const size_t work_per_thread = total_work / num_threads;
        
        for (size_t t = 0; t < num_threads; ++t) {
            threads.emplace_back([&, t]() {
                const size_t start_idx = t * work_per_thread;
                const size_t end_idx = (t == num_threads - 1) ? total_work : (t + 1) * work_per_thread;
                work_func(start_idx, end_idx);
            });
        }
        
        for (auto& thread : threads) {
            thread.join();
        }
    }
    
    template<typename WorkFunc>
    void parallel_for_2d(size_t outer_size, size_t inner_size, size_t threshold, WorkFunc work_func) {
        const size_t total_work = outer_size * inner_size;
        parallel_for(total_work, threshold, [&](size_t start_idx, size_t end_idx) {
            for (size_t work_idx = start_idx; work_idx < end_idx; ++work_idx) {
                const size_t outer = work_idx / inner_size;
                const size_t inner = work_idx % inner_size;
                work_func(outer, inner);
            }
        });
    }
    
    template<typename WorkFunc, typename ResultType, typename CombineFunc>
    ResultType parallel_reduce(size_t total_work, size_t threshold, 
                              WorkFunc work_func, ResultType init_value, CombineFunc combine_func) {
        const size_t num_threads = get_optimal_thread_count(total_work, threshold);
        
        if (num_threads == 1) {
            return work_func(0, total_work);
        }
        
        std::vector<std::thread> threads;
        std::vector<ResultType> partial_results(num_threads, init_value);
        const size_t work_per_thread = total_work / num_threads;
        
        for (size_t t = 0; t < num_threads; ++t) {
            threads.emplace_back([&, t]() {
                const size_t start_idx = t * work_per_thread;
                const size_t end_idx = (t == num_threads - 1) ? total_work : (t + 1) * work_per_thread;
                partial_results[t] = work_func(start_idx, end_idx);
            });
        }
        
        for (auto& thread : threads) {
            thread.join();
        }
        
        ResultType result = init_value;
        for (const auto& partial : partial_results) {
            result = combine_func(result, partial);
        }
        return result;
    }
}

#endif // KERNEL_UTILS_H 