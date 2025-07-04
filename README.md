# Semantically Enhanced Selective Image Encryption Scheme - Matlab Implementation

This project provides a Matlab implementation for a semantically enhanced selective image encryption scheme, based on the concepts described in the paper "Semantically enhanced selective image encryption scheme with parallel computing" (Buyu Liu et al., Expert Systems With Applications 279 (2025) 127404).

The implementation focuses on reproducing the core cryptographic components, including chaos system analysis, ROI detection (using classical methods as a substitute for the paper's deep learning model), parallel encryption/decryption of ROIs, and various performance analyses.

## 1. Project Structure

The project is organized as follows:

```
ROOT_PROJECT_DIR/
|-- run_project.m         # Main script to run various parts of the project
|-- images/               # Directory for your test images (e.g., peppers.png, lena.png)
|-- results/              # Default output directory for encrypted images, analysis plots, etc.
|-- external_models/      # Placeholder for pre-trained deep learning models (not used in current version)
|-- src/                  # Source code directory
|   |-- chaos_systems/      # Matlab scripts for LICC and Logistic chaotic systems & analysis
|   |   |-- licc_system.m
|   |   |-- logistic_map.m
|   |   |-- analyze_chaos.m
|   |-- roi_detection/      # Scripts for ROI detection
|   |   |-- detect_saliency.m (uses classical methods like Spectral Residual)
|   |   |-- psrd.m            (Patch-based Salient Region Detection)
|   |-- encryption/         # Scripts for the encryption and decryption logic
|   |   |-- extract_pixels.m
|   |   |-- main_encryption_system.m (core encryption/decryption flow)
|   |   |-- parallel_encrypt_decrypt.m (older/alternative main function structure)
|   |   |-- reversible_data_hiding.m (simplified placeholder)
|   |-- analysis/           # Scripts for performance analysis
|   |   |-- analyze_histogram.m
|   |   |-- analyze_correlation.m
|   |   |-- analyze_entropy.m
|   |   |-- analyze_key_sensitivity.m
|   |   |-- analyze_differential_attack.m
|   |   |-- run_all_analyses.m (script to run all analyses for an image)
|-- README.md             (this file)
```

## 2. Matlab Environment Requirements

-   **Matlab Version**: R2019b or later recommended (due to function syntax and toolbox compatibility).
-   **Required Toolboxes**:
    -   Image Processing Toolbox: Essential for image reading/writing, color conversions, histogram analysis, PSNR, SSIM, `graythresh`, `imfilter`, `fspecial`, etc.
-   **Optional Toolboxes (for future enhancements)**:
    -   Deep Learning Toolbox: If you plan to integrate a deep learning-based Salient Object Detection (SOD) model (e.g., EDN-lite via ONNX import). The current implementation uses classical SOD.
    -   Parallel Computing Toolbox: If you wish to implement true parallelism for the encryption/decryption channels using `parfor`. The current implementation simulates parallelism through sequential independent operations.

## 3. How to Run the Project

The primary way to interact with the project is through the `run_project.m` script located in the root directory.

**Steps:**

1.  **Open Matlab.**
2.  **Navigate to the Root Project Directory** where `run_project.m` is located.
3.  **Add Test Images**: Place your desired test images (e.g., `peppers.png`, `lena.png`, `baboon.png` - standard color images are recommended) into the `images/` directory.
4.  **Run `run_project.m` from the Matlab Command Window**:

    You can specify an `action` and optionally an `image_filename` and an `output_folder`.

    ```matlab
    run_project(action, image_filename, output_folder)
    ```

    -   `action` (string, optional, default: `'all'`):
        -   `'encrypt_decrypt'`: Runs the main encryption/decryption flow for the specified image. Saves the encrypted and decrypted images.
        -   `'analyze_chaos'`: Runs the chaos system analysis (LICC attractors, bifurcation diagrams for LICC and Logistic map, initial value sensitivity tests). Plots are generated.
            *Note*: To save these plots, you need to edit `src/chaos_systems/analyze_chaos.m` and uncomment the `saveas(...)` lines. This script will attempt to create a `results` subfolder within `src/chaos_systems` for these plots and then move them to `output_folder_param/chaos_analysis_plots/`.
        -   `'full_analysis'`: Runs all implemented performance analyses (histogram, correlation, entropy, key sensitivity, differential attack) for the specified image. Results and plots are saved in subdirectories of the specified output folder.
        -   `'all'`: Executes `'encrypt_decrypt'` followed by `'full_analysis'`.

    -   `image_filename` (string, optional, default: `'peppers.png'`): The name of the image file located in the `images/` directory (or on the Matlab path).
    -   `output_folder` (string, optional, default: `'results/'`): The base directory where all output subfolders and files will be saved.

**Examples:**

```matlab
% Run all actions for peppers.png, output to 'results/' (default behavior)
run_project

% Run only encryption/decryption for 'lena.png', output to 'results/lena_enc_dec_run/'
run_project('encrypt_decrypt', 'lena.png')

% Run only chaos system analysis, plots saved to 'results/chaos_analysis_plots/'
% (Remember to uncomment saveas lines in src/chaos_systems/analyze_chaos.m)
run_project('analyze_chaos')

% Run full performance analysis for 'baboon.png', output to './my_analysis_results/baboon_performance_analysis/'
run_project('full_analysis', 'baboon.png', './my_analysis_results')

% Run all actions for 'boat.png', output to a custom top-level folder
run_project('all', 'boat.png', './custom_project_outputs')
```

### Path Management

The `run_project.m` script automatically adds the `src/` directory and its subdirectories to the Matlab path at the beginning of its execution and removes them at the end. This ensures that all module functions are accessible.

## 4. Understanding Outputs

-   **Encrypted/Decrypted Images**: Saved in the specified output folder, typically under a subfolder named `<image_name>_encryption_run/` or `<image_name>_performance_analysis/` (if generated as part of analysis).
-   **Chaos Analysis Plots**: Figures for LICC attractors, bifurcations, and sensitivity tests. Saved in `<output_folder>/chaos_analysis_plots/` (ensure `saveas` is active in `analyze_chaos.m`).
-   **Performance Analysis Results**:
    -   **Histograms**: PNG files showing histograms of original and encrypted ROI pixels (`<output_folder>/<image_name>_performance_analysis/histograms/`).
    -   **Correlations**: PNG files of scatter plots for adjacent pixel correlations. Correlation coefficient values are printed to the console and stored in a workspace variable `correlation_analysis_results`. Saved in `<output_folder>/<image_name>_performance_analysis/correlations/`.
    -   **Entropy**: Values printed to the console. Results stored in workspace variable `entropy_analysis_results`.
    -   **Key Sensitivity**: NPCR/UACI values printed. Comparison images saved in `<output_folder>/<image_name>_performance_analysis/key_sensitivity/`.
    -   **Differential Attack**: NPCR/UACI values printed. Cipher images C1 and C2 may be saved in `<output_folder>/<image_name>_performance_analysis/differential_attack/`.
-   **Console Output**: Progress messages, warnings, and numerical results (like entropy, correlation coefficients, NPCR/UACI) will be displayed in the Matlab command window.

## 5. Current Implementation Status & Simplifications

This implementation aims to reproduce the core concepts of the paper. However, certain aspects have been simplified or use placeholders due to practical constraints:

-   **Salient Object Detection (SOD)**: The paper uses a lightweight deep learning model (EDN-lite). This implementation uses classical algorithms like **Spectral Residual ('SR')** or a simplified **Frequency-Tuned ('FT')** method as a substitute (see `src/roi_detection/detect_saliency.m`). These methods are generally less accurate than modern deep learning approaches for complex scenes but provide a functional placeholder for ROI detection.
-   **Reversible Data Hiding (RDH)**: The paper describes embedding ROI side information using a method by Jia et al. (2019). The `src/encryption/reversible_data_hiding.m` file contains a **highly simplified placeholder** for PEE-like embedding and extraction. This RDH module is **not currently integrated** into the main encryption/decryption flow (`main_encryption_system.m`). Therefore, ROI information (`ROI_info` and `index_seg_shuffled`) is passed directly from the encryption phase to the decryption phase within the simulation, rather than being embedded into and extracted from the image. This is a significant deviation for practical application but allows testing of the core encryption logic.
-   **Parallel Computing**: The "parallel computing" aspect of the paper (encrypting three color channels in parallel) is simulated by processing each of the three derived pixel sequences (`seq0`, `seq1`, `seq2`) independently. True hardware parallelism using Matlab's Parallel Computing Toolbox (`parfor`) has not been implemented but could be an area for optimization.
-   **LICC System Equations**: The `z(i+1)` equation in the user-provided paper's description of LICC (Eq. 1) appeared problematic (`sin(pi)` term). This implementation uses a symmetric form for `z(i+1)` consistent with `x(i+1)` and `y(i+1)`, and adopts the parallel update structure as detailed in the cited LICC source paper by Wei & Li (2022). This ensures a functional hyperchaotic system.

## 6. Potential Areas for Further Development & Optimization (using Gemini CLI or other tools)

You can use AI-assisted tools like Gemini CLI to explore and enhance several aspects of this project:

1.  **Advanced Salient Object Detection**:
    -   Research and integrate a pre-trained lightweight SOD model (e.g., U2-Net-lite, MobileSal) into `detect_saliency.m`. You might need to convert models from Python frameworks (PyTorch, TensorFlow) to ONNX format if Matlab's Deep Learning Toolbox supports its import.
    -   *Gemini CLI Prompt Idea*: "Generate Matlab code to load an ONNX model for image saliency detection and get a binary mask, assuming the Deep Learning Toolbox is available."
2.  **Full Reversible Data Hiding Implementation**:
    -   Study the Jia et al. (2019) paper ("Reversible data hiding scheme based on the images texture") and implement the described algorithm for calculating local complexity (Ωp), fluctuation value (FΩ), prediction error (ep), and the specific histogram shifting/expansion embedding process (Algorithm 1 from the user's paper).
    -   Integrate this full RDH scheme into `main_encryption_system.m` to embed/extract `ROI_info` and `index_seg_shuffled`.
    -   *Gemini CLI Prompt Idea*: "Explain the PEE (Prediction Error Expansion) data hiding technique focusing on histogram shifting. Provide a conceptual Matlab function for embedding a bit into a prediction error `e` given peak points `pk1`, `pk2` and zero points `z1`, `z2`."
3.  **True Parallelism**:
    -   If you have the Parallel Computing Toolbox, modify the encryption/decryption loops (e.g., in `main_encryption_system.m` where `encrypt_channel` / `decrypt_channel` are called for seq0, seq1, seq2) to use `parfor` to potentially speed up processing on multi-core CPUs.
    -   *Gemini CLI Prompt Idea*: "Show how to convert a Matlab for-loop that processes three independent data sequences into a parfor-loop for parallel execution."
4.  **Enhanced Chaos Analysis**:
    -   Implement calculation for Lyapunov exponents of the LICC system to quantitatively assess its chaotic behavior.
    -   Perform more rigorous statistical tests (e.g., NIST test suite) on the generated chaotic sequences.
    -   *Gemini CLI Prompt Idea*: "Outline the steps to calculate the largest Lyapunov exponent for a 3D discrete chaotic system in Matlab."
5.  **Code Optimization and Robustness**:
    -   Profile the code (`profile viewer` in Matlab) to identify bottlenecks, especially in the encryption/decryption pixel iteration loops, and explore optimization techniques (e.g., vectorization where possible, pre-allocation improvements).
    -   Add more comprehensive error handling and input validation to all functions.
    -   *Gemini CLI Prompt Idea*: "Suggest ways to optimize a nested for-loop in Matlab that processes image pixels for encryption, considering vectorization or other performance enhancements."
6.  **User Interface**:
    -   Develop a simple GUI (e.g., using App Designer) to make the tool more user-friendly for selecting images, actions, and viewing results.

We hope this Matlab project provides a solid foundation for understanding and experimenting with the described image encryption scheme. Good luck with your further development and optimizations!
```
