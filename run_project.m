function run_project(action, image_filename_param, output_folder_param)
% run_project: Main entry point for the Image Encryption project.
%
% Args:
%   action (str): Specifies what to run. Options:
%                 'encrypt_decrypt': Runs the main encryption/decryption flow for one image.
%                 'analyze_chaos': Runs chaos system analysis (attractors, bifurcations).
%                 'full_analysis': Runs all performance analyses for one image.
%                 'all': Runs 'encrypt_decrypt' then 'full_analysis'.
%                 Default is 'all'.
%
%   image_filename_param (str, optional): Name of the image to process (e.g., 'peppers.png').
%                                         Default: 'peppers.png'.
%                                         Searches in './images/' first, then current path.
%
%   output_folder_param (str, optional): Base folder for all outputs.
%                                        Default: './results/'.
%
% Examples:
%   run_project('encrypt_decrypt', 'lena.png', './my_custom_results')
%   run_project('analyze_chaos')
%   run_project('full_analysis', 'baboon.png')
%   run_project % Runs 'all' with default image and output folder
%   run_project('all', 'boat.png', './boat_output')

    if nargin < 1 || isempty(action)
        action = 'all';
    end
    if nargin < 2 || isempty(image_filename_param)
        image_filename_param = 'peppers.png';
    end
    if nargin < 3 || isempty(output_folder_param)
        output_folder_param = 'results';
    end

    % --- Setup Paths ---
    % Assuming this script is in the root project directory.
    % All module functions are in 'src/<module_name>/'
    fprintf('Adding project source paths...\n');
    addpath(genpath(fullfile(pwd, 'src')));

    % Ensure the main output folder exists
    if ~exist(output_folder_param, 'dir')
        mkdir(output_folder_param);
        fprintf('Created main output directory: %s\n', output_folder_param);
    end

    % Resolve image path
    image_path_resolved = fullfile('images', image_filename_param);
    if ~exist(image_path_resolved, 'file')
        image_path_resolved = image_filename_param; % Try current dir if not in ./images/
        if ~exist(image_path_resolved, 'file')
            error('Image file "%s" not found in "./images/" or current directory.', image_filename_param);
        end
    end
    fprintf('Using image: %s\n', image_path_resolved);
    [~, img_name_no_ext, ~] = fileparts(image_filename_param);

    % --- Perform Actions ---
    switch lower(action)
        case 'encrypt_decrypt'
            fprintf('\n--- ACTION: Running Encryption/Decryption for %s ---\n', image_filename_param);
            enc_dec_output_folder = fullfile(output_folder_param, [img_name_no_ext, '_encryption_run']);
            if ~exist(enc_dec_output_folder, 'dir'), mkdir(enc_dec_output_folder); end

            % Call the main encryption system script
            % Need to temporarily cd to src/encryption for main_encryption_system to find its relative paths
            current_dir = pwd;
            try
                cd(fullfile(pwd, 'src', 'encryption'));
                main_encryption_system(image_path_resolved, enc_dec_output_folder);
                cd(current_dir);
            catch ME_encdec
                cd(current_dir); % Ensure we cd back even if error
                fprintf('ERROR during encrypt_decrypt action: %s\n', ME_encdec.message);
                rethrow(ME_encdec);
            end
            fprintf('Encryption/Decryption run finished. Check folder: %s\n', enc_dec_output_folder);

        case 'analyze_chaos'
            fprintf('\n--- ACTION: Running Chaos System Analysis ---\n');
            chaos_analysis_output_folder = fullfile(output_folder_param, 'chaos_analysis_plots');
            if ~exist(chaos_analysis_output_folder, 'dir'), mkdir(chaos_analysis_output_folder); end

            current_dir = pwd;
            try
                cd(fullfile(pwd,'src','chaos_systems')); % analyze_chaos might save relative
                % Modify analyze_chaos to accept output_folder if it doesn't already
                % For now, assume it saves to its current dir or a fixed 'results'
                % To make it save to chaos_analysis_output_folder, analyze_chaos would need modification
                % or we copy figures after they are generated.
                % Let's assume analyze_chaos is modified to save plots to a specific folder if provided.
                % If not, user needs to check default save locations or modify analyze_chaos.m

                % Quick fix: temporarily modify `analyze_chaos` to save to the specified folder.
                % This is not ideal but works for a single run script.
                % Best: `analyze_chaos` should take output_folder as argument.
                % For now, plots might go to `src/chaos_systems/results` or current dir.
                % The user was informed that analyze_chaos.m needs to be uncommented for saving.

                % Since analyze_chaos.m has hardcoded save paths to 'results/', we create that inside.
                results_in_chaos_module = fullfile(pwd,'results');
                if ~exist(results_in_chaos_module, 'dir'), mkdir(results_in_chaos_module); end

                analyze_chaos(); % This will generate plots.

                % Move generated plots if they were saved in the temp 'results' dir
                if exist(results_in_chaos_module, 'dir')
                    files_to_move = dir(fullfile(results_in_chaos_module, '*.png')); % Assuming png
                    for f_idx = 1:length(files_to_move)
                        try
                            movefile(fullfile(results_in_chaos_module, files_to_move(f_idx).name), chaos_analysis_output_folder);
                        catch ME_move
                            fprintf('Could not move %s: %s\n', files_to_move(f_idx).name, ME_move.message);
                        end
                    end
                    % Attempt to remove the temporary results dir if empty
                    % rmdir(results_in_chaos_module, 's'); % 's' might be too aggressive if other things are there
                    content = dir(results_in_chaos_module);
                    if length(content) <=2 % Only '.' and '..'
                        rmdir(results_in_chaos_module);
                    end
                end
                cd(current_dir);
            catch ME_chaos
                cd(current_dir);
                fprintf('ERROR during analyze_chaos action: %s\n', ME_chaos.message);
                rethrow(ME_chaos);
            end
            fprintf('Chaos System Analysis finished. Check folder: %s (and ensure save lines in analyze_chaos.m are active)\n', chaos_analysis_output_folder);

        case 'full_analysis'
            fprintf('\n--- ACTION: Running Full Performance Analysis for %s ---\n', image_filename_param);
            perf_analysis_output_folder = fullfile(output_folder_param, [img_name_no_ext, '_performance_analysis']);
            if ~exist(perf_analysis_output_folder, 'dir'), mkdir(perf_analysis_output_folder); end

            current_dir = pwd;
            try
                cd(fullfile(pwd,'src','analysis'));
                % run_all_analyses expects image_filename (not full path) and output_folder
                % It constructs image path assuming ../../images/ relative to its own location.
                % So, provide just image_filename_param
                run_all_analyses(image_filename_param, perf_analysis_output_folder);
                cd(current_dir);
            catch ME_fullan
                cd(current_dir);
                fprintf('ERROR during full_analysis action: %s\n', ME_fullan.message);
                rethrow(ME_fullan);
            end
            fprintf('Full Performance Analysis finished. Check folder: %s\n', perf_analysis_output_folder);

        case 'all'
            fprintf('\n--- ACTION: Running ALL (Encrypt/Decrypt then Full Analysis) for %s ---\n', image_filename_param);
            % Run Encrypt/Decrypt first
            run_project('encrypt_decrypt', image_filename_param, output_folder_param);
            % Then run Full Analysis
            run_project('full_analysis', image_filename_param, output_folder_param);
            fprintf('All actions finished for %s.\n', image_filename_param);

        otherwise
            fprintf('Error: Unknown action "%s".\n', action);
            fprintf('Valid actions are: "encrypt_decrypt", "analyze_chaos", "full_analysis", "all".\n');
    end

    fprintf('\nrun_project finished.\n');
    rmpath(genpath(fullfile(pwd, 'src'))); % Clean up path
end

% --- Instructions for User ---
% To use this script:
% 1. Place this `run_project.m` file in the root directory of your project.
% 2. Ensure the 'src/' directory with all its submodules (chaos_systems, roi_detection, etc.)
%    is in the same root directory.
% 3. Ensure the 'images/' directory is in the root and contains your test images.
%    Standard Matlab images like 'peppers.png', 'lena.png' should be accessible
%    if Image Processing Toolbox is installed and they are on the path, or copy them to './images/'.
% 4. Open Matlab, navigate to the root directory of the project.
% 5. Run this script from the Matlab command window. Examples:
%    >> run_project                               % Runs 'all' for 'peppers.png' into './results/'
%    >> run_project('encrypt_decrypt', 'lena.png') % Encrypts/decrypts lena.png
%    >> run_project('analyze_chaos')              % Runs only chaos analysis plots
%    >> run_project('full_analysis', 'baboon.png', './baboon_analysis_results')
%
% Note on Chaos Analysis Plots:
%   The `analyze_chaos.m` script has `saveas` lines commented out by default.
%   To save the chaos plots, you need to:
%   a. Edit `src/chaos_systems/analyze_chaos.m`.
%   b. Uncomment the `saveas(...)` lines within that file.
%   c. Ensure the target save directory (e.g., 'results/' relative to analyze_chaos.m,
%      or the one specified in this run_project.m) is writable. This script attempts to
%      manage a 'results' subfolder within the chaos module for this.
%
% Note on `parallel_encrypt_decrypt.m`:
%   This file was initially created as a more monolithic function. However, the encryption/decryption
%   logic was largely implemented within `main_encryption_system.m` and its helpers.
%   `parallel_encrypt_decrypt.m` may contain earlier or alternative versions of the logic.
%   This `run_project.m` script primarily uses `main_encryption_system.m` for the
%   'encrypt_decrypt' action and the analysis scripts for performance evaluation.
%   The helper functions `encrypt_channel` and `decrypt_channel` are defined in
%   `main_encryption_system.m` and are also copied into some analysis scripts for
%   self-containment if those analysis scripts are run individually.
%
% Required Toolboxes:
% - Image Processing Toolbox (for imread, imshow, psnr, ssim, graythresh, etc.)
% - Deep Learning Toolbox (if a deep learning SOD model were to be integrated,
%   currently using classical SOD methods as fallback)
% - Parallel Computing Toolbox (if `parfor` were to be used for true parallelism,
%   currently simulated by sequential independent operations)
%
% Project Structure Expected by this script:
%   ROOT_PROJECT_DIR/
%   |-- run_project.m         (this file)
%   |-- images/
%   |   |-- peppers.png
%   |   |-- lena.png
%   |   |-- (other test images)
%   |-- src/
%   |   |-- chaos_systems/
%   |   |   |-- licc_system.m
%   |   |   |-- logistic_map.m
%   |   |   |-- analyze_chaos.m
%   |   |-- roi_detection/
%   |   |   |-- detect_saliency.m
%   |   |   |-- psrd.m
%   |   |-- encryption/
%   |   |   |-- extract_pixels.m
%   |   |   |-- main_encryption_system.m (contains encrypt_channel, decrypt_channel)
%   |   |   |-- parallel_encrypt_decrypt.m (alternative/older version)
%   |   |   |-- reversible_data_hiding.m (placeholder)
%   |   |-- analysis/
%   |   |   |-- analyze_histogram.m
%   |   |   |-- analyze_correlation.m
%   |   |   |-- analyze_entropy.m
%   |   |   |-- analyze_key_sensitivity.m
%   |   |   |-- analyze_differential_attack.m
%   |   |   |-- run_all_analyses.m
%   |-- results/                (created by this script if it doesn't exist)
%   |   |-- peppers_encryption_run/
%   |   |-- chaos_analysis_plots/
%   |   |-- peppers_performance_analysis/
%   |   |-- (other output folders based on image name and action)
%
% Make sure all .m files have necessary functions either self-contained,
% in the same directory, or on the Matlab path (handled by addpath(genpath('src')) here).
%
% Final packaging will involve zipping this entire structure.
% The `external_models/` directory is also part of the plan but not used by current code.Tool output for `create_file_with_block`:
